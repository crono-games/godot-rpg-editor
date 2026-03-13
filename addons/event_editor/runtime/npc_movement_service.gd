class_name NpcMovementService
extends RefCounted

const CARDINAL_DIRS := [
	Vector3(1, 0, 0),
	Vector3(-1, 0, 0),
	Vector3(0, 0, 1),
	Vector3(0, 0, -1)
]
const META_MOVING := "_npc_moving"
const DEBUG_NPC_MOVE := false
const ACTION_PAUSE_SECONDS := 0.35

var _accum_by_event: Dictionary = {}
var _action_pause_by_event: Dictionary = {}
var _last_dir_by_event: Dictionary = {}

func clear() -> void:
	_accum_by_event.clear()

func process(map_data: Dictionary, ctx: EventRuntimeContext, delta: float, player_group: String = "player", active_radius_tiles: float = 12.0) -> void:
	if map_data.is_empty() or ctx == null:
		return
	var events = map_data.get("events", {})
	var player: Node = null
	var env := ctx.get_scene_event_environment()
	if env != null:
		player = env.get_player(player_group)
	for event_id in events.keys():
		_process_event(map_data, ctx, str(event_id), delta, player_group, player, active_radius_tiles)

##TODO Needs Refactor.

func _process_event(map_data: Dictionary, ctx: EventRuntimeContext, event_id: String, delta: float, player_group: String, player: Node, active_radius_tiles: float) -> void:
	var event := _resolve_event_node(map_data, ctx, event_id)
	if event == null or not (event is Node2D or event is Node3D):
		if DEBUG_NPC_MOVE:
			print("NpcMovementService: skip event_id=", event_id, " reason=no_scene_node")
		return
	if _is_player_node(event, player_group, player):
		return
	if not _is_event_active(event, player, active_radius_tiles):
		return
	if _should_pause_for_action(ctx, event_id, delta):
		return


	if event.has_meta(META_MOVING) and bool(event.get_meta(META_MOVING)):
		return
	var graph := EventGraphRuntime.new(map_data, event_id)
	var state_id := ctx.get_current_state(event_id)
	if state_id == "":
		state_id = graph.get_start_node_id()
	if state_id == "":
		if DEBUG_NPC_MOVE:
			print("NpcMovementService: skip event_id=", event_id, " reason=no_state")
		return
	var state_node := graph.get_node(state_id)
	if state_node == null or str(state_node.get("type", "")) != "state":
		if DEBUG_NPC_MOVE:
			print("NpcMovementService: skip event_id=", event_id, " reason=state_node_invalid state_id=", state_id)
		return
	var params: Dictionary = state_node.get("params", {})
	var props: Dictionary = params.get("properties", {})
	var movement_type := str(props.get("movement_type", "fixed")).to_lower()
	if movement_type == "" or movement_type == "fixed":
		if DEBUG_NPC_MOVE:
			print("NpcMovementService: skip event_id=", event_id, " reason=fixed")
		return

	var frequency := clampi(int(props.get("movement_frequency", 3)), 1, 5)
	var speed := clampi(int(props.get("movement_speed", 4)), 1, 6)
	var interval := _interval_from_frequency(frequency)
	if props.has("movement_interval"):
		interval = maxf(0.01, float(props.get("movement_interval", interval)))
	var accum := float(_accum_by_event.get(event_id, 0.0)) + delta
	if accum < interval:
		_accum_by_event[event_id] = accum
		return
	_accum_by_event[event_id] = 0.0

	var dir := _pick_direction(movement_type, event, ctx, player_group, event_id)
	if _is_player_adjacent(event, player):
		var away := _pick_away_from_player(event, player)
		if away != Vector3.ZERO:
			dir = away
	if dir == Vector3.ZERO:
		if DEBUG_NPC_MOVE:
			print("NpcMovementService: skip event_id=", event_id, " reason=zero_dir type=", movement_type)
		return

	var grid_size := _resolve_grid_size(event)
	var grid_centered := _resolve_grid_centered(event)
	var current_cell := GridUtils.world_to_cell(_node_pos3(event), grid_size, grid_centered)
	var next_cell := current_cell + Vector2i(int(dir.x), int(dir.z))
	var current_pos3 := _node_pos3(event)
	var next := GridUtils.cell_to_world(next_cell, current_pos3.y, grid_size, grid_centered)
	if _is_event_cell_occupied(ctx, event_id, next_cell, grid_size, grid_centered):
		if DEBUG_NPC_MOVE:
			print("NpcMovementService: skip event_id=", event_id, " reason=cell_occupied cell=", next_cell)
		dir = _reroll_direction(movement_type, event, ctx, player_group, event_id, dir)
		if dir == Vector3.ZERO:
			return
		next_cell = current_cell + Vector2i(int(dir.x), int(dir.z))
		next = GridUtils.cell_to_world(next_cell, current_pos3.y, grid_size, grid_centered)
	if _is_player_cell_occupied(player, next_cell, grid_size, grid_centered):
		if DEBUG_NPC_MOVE:
			print("NpcMovementService: skip event_id=", event_id, " reason=player_occupied cell=", next_cell)
		dir = _reroll_direction(movement_type, event, ctx, player_group, event_id, dir)
		if dir == Vector3.ZERO:
			return
		next_cell = current_cell + Vector2i(int(dir.x), int(dir.z))
		next = GridUtils.cell_to_world(next_cell, current_pos3.y, grid_size, grid_centered)
	if _is_world_blocked_for_event(event, current_pos3, next):
		if DEBUG_NPC_MOVE:
			print("NpcMovementService: skip event_id=", event_id, " reason=world_blocked")
		dir = _reroll_direction(movement_type, event, ctx, player_group, event_id, dir)
		if dir == Vector3.ZERO:
			return
		next_cell = current_cell + Vector2i(int(dir.x), int(dir.z))
		next = GridUtils.cell_to_world(next_cell, current_pos3.y, grid_size, grid_centered)
		if _is_event_cell_occupied(ctx, event_id, next_cell, grid_size, grid_centered):
			return
		if _is_player_cell_occupied(player, next_cell, grid_size, grid_centered):
			return
		if _is_world_blocked_for_event(event, current_pos3, next):
			return

	var duration := _duration_from_speed(speed)
	if props.has("movement_step_time"):
		duration = maxf(0.01, float(props.get("movement_step_time", duration)))
	_apply_move(event, next, dir, duration)

func _resolve_event_node(map_data: Dictionary, ctx: EventRuntimeContext, event_id: String) -> Node:
	var event := ctx.get_event_by_id(event_id)
	if event != null:
		return event
	var events: Dictionary = map_data.get("events", {})
	var event_data: Dictionary = events.get(event_id, {})
	var fallback_name := str(event_data.get("name", ""))
	if fallback_name != "":
		return ctx.get_event_by_name(fallback_name)
	return null

func _is_player_node(node: Node, player_group: String, player_ref: Node) -> bool:
	if node == null:
		return false
	if player_ref != null and node == player_ref:
		return true
	if node.is_in_group(player_group):
		return true
	var name_l := String(node.name).to_lower()
	if name_l.contains("player"):
		return true
	if node.has_method("get"):
		var node_id := str(node.get("id"))
		if player_ref != null and player_ref.has_method("get") and node_id != "" and node_id == str(player_ref.get("id")):
			return true
	return false

func _pick_direction(movement_type: String, event: Node, ctx: EventRuntimeContext, player_group: String, event_id: String = "") -> Vector3:
	match movement_type:
		"random":
			return _pick_random_dir(event_id)
		"approach":
			var env := ctx.get_scene_event_environment()
			if env == null:
				return Vector3.ZERO
			var player := env.get_player(player_group)
			if player == null:
				return Vector3.ZERO
			var d := _node_pos3(player) - _node_pos3(event)
			if absf(d.x) >= absf(d.z):
				return Vector3(1, 0, 0) if d.x > 0 else Vector3(-1, 0, 0)
			return Vector3(0, 0, 1) if d.z > 0 else Vector3(0, 0, -1)
		_:
			return Vector3.ZERO

func _pick_away_from_player(event: Node, player: Node) -> Vector3:
	if event == null or player == null:
		return Vector3.ZERO
	var grid_size := _resolve_grid_size(event)
	var grid_centered := _resolve_grid_centered(event)
	var event_cell := GridUtils.world_to_cell(_node_pos3(event), grid_size, grid_centered)
	var player_cell := GridUtils.world_to_cell(_node_pos3(player), grid_size, grid_centered)
	var dx := event_cell.x - player_cell.x
	var dy := event_cell.y - player_cell.y
	if abs(dx) >= abs(dy):
		return Vector3(1, 0, 0) if dx > 0 else Vector3(-1, 0, 0)
	return Vector3(0, 0, 1) if dy > 0 else Vector3(0, 0, -1)

func _reroll_direction(movement_type: String, event: Node, ctx: EventRuntimeContext, player_group: String, event_id: String, current_dir: Vector3) -> Vector3:
	if movement_type != "random":
		return current_dir
	var tried := 0
	var dir := current_dir
	while tried < 3:
		dir = _pick_random_dir(event_id)
		if dir != current_dir:
			return dir
		tried += 1
	return dir

func _pick_random_dir(event_id: String) -> Vector3:
	var last := _last_dir_by_event.get(event_id, Vector3.ZERO)
	var dir = CARDINAL_DIRS[randi() % CARDINAL_DIRS.size()]
	var tries := 0
	while tries < 4 and dir == last:
		dir = CARDINAL_DIRS[randi() % CARDINAL_DIRS.size()]
		tries += 1
	_last_dir_by_event[event_id] = dir
	return dir

func _resolve_grid_size(event: Node) -> float:
	if event.has_method("get") and event.get("grid_size") != null:
		return maxf(0.01, float(event.get("grid_size")))
	return 1.0

func _resolve_grid_centered(event: Node) -> bool:
	if event.has_method("get") and event.get("grid_centered") != null:
		return bool(event.get("grid_centered"))
	return true

func _is_event_cell_occupied(ctx: EventRuntimeContext, moving_event_id: String, next_cell: Vector2i, grid_size: float, grid_centered: bool) -> bool:
	var env := ctx.get_scene_event_environment()
	if env == null:
		return false
	var scene_root: Node = null
	if env.has_method("get_root"):
		scene_root = env.call("get_root")
	if scene_root == null:
		return false
	for node in scene_root.get_tree().get_nodes_in_group("event_instance"):
		if not (node is Node2D or node is Node3D):
			continue
		var nid := ""
		if node.has_method("get"):
			nid = str(node.get("id"))
		if nid == moving_event_id:
			continue
		if node.has_method("blocks_player_movement") and not bool(node.call("blocks_player_movement")):
			continue
		var p := _node_pos3(node)
		var cell := GridUtils.world_to_cell(p, grid_size, grid_centered)
		if cell == next_cell:
			return true
	return false

func _is_player_cell_occupied(player: Node, next_cell: Vector2i, grid_size: float, grid_centered: bool) -> bool:
	if player == null:
		return false
	var p := _node_pos3(player)
	var player_cell := GridUtils.world_to_cell(p, grid_size, grid_centered)
	return player_cell == next_cell

func _is_world_blocked_for_event(event: Node, current_pos3: Vector3, next_pos3: Vector3) -> bool:
	if not (event is Node2D):
		return false
	if not event.has_method("get"):
		return false
	var hitbox_area = event.get("hitbox_area")
	var hitbox = event.get("hitbox")
	if not (hitbox_area is Area2D):
		return false
	if not (hitbox is CollisionShape2D):
		var resolved := _resolve_hitbox_shape(hitbox_area)
		if resolved != null:
			hitbox = resolved
	if not (hitbox is CollisionShape2D):
		return false
	var hb_area := hitbox_area as Area2D
	var hb_shape := hitbox as CollisionShape2D
	if hb_shape.shape == null:
		return false
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = hb_shape.shape
	params.transform = hb_shape.global_transform
	params.motion = Vector2(next_pos3.x - current_pos3.x, next_pos3.z - current_pos3.z)
	params.collision_mask = hb_area.collision_mask
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = [hb_area.get_rid()]
	var state := hb_area.get_world_2d().direct_space_state
	var result = state.cast_motion(params)
	return result == null or result.size() == 0 or float(result[0]) < 1.0

func _resolve_hitbox_shape(hitbox_area: Area2D) -> CollisionShape2D:
	if hitbox_area == null:
		return null
	var direct := hitbox_area.get_node_or_null("HitboxShape")
	if direct is CollisionShape2D:
		return direct
	var generic := hitbox_area.get_node_or_null("CollisionShape2D")
	if generic is CollisionShape2D:
		return generic
	for child in hitbox_area.get_children():
		if child is CollisionShape2D:
			return child
	return null

func _is_player_adjacent(event: Node, player: Node) -> bool:
	if player == null:
		return false
	var grid_size := _resolve_grid_size(event)
	var grid_centered := _resolve_grid_centered(event)
	var event_cell := GridUtils.world_to_cell(_node_pos3(event), grid_size, grid_centered)
	var player_cell := GridUtils.world_to_cell(_node_pos3(player), grid_size, grid_centered)
	var dx := abs(event_cell.x - player_cell.x)
	var dy := abs(event_cell.y - player_cell.y)
	return dx + dy <= 1

func _should_pause_for_action(ctx: EventRuntimeContext, event_id: String, delta: float) -> bool:
	if event_id == "":
		return false
	if delta <= 0.0:
		return false
	var remaining := float(_action_pause_by_event.get(event_id, 0.0))
	if remaining > 0.0:
		remaining = maxf(0.0, remaining - delta)
		_action_pause_by_event[event_id] = remaining
		return remaining > 0.0
	var last := ""
	if ctx != null:
		last = ctx.get_last_trigger_for_event(event_id)
	if last == "action":
		_action_pause_by_event[event_id] = ACTION_PAUSE_SECONDS
		return true
	if last == "":
		_action_pause_by_event.erase(event_id)
	return false

func _apply_move(event: Node, next_pos: Vector3, dir: Vector3, duration: float) -> void:
	event.set_meta(META_MOVING, true)
	if event.has_method("update_animation"):
		event.call("update_animation", _anim_direction_for(event, dir))
	if event.has_method("_sync_anim_speed_to_step"):
		event.call("_sync_anim_speed_to_step", duration)
	var tween := event.get_tree().create_tween()
	tween.tween_property(event, "position", _pos_value_for(event, next_pos), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		if event != null and is_instance_valid(event):
			if event.has_method("_reset_anim_speed"):
				event.call("_reset_anim_speed")
			if event.has_method("update_animation"):
				event.call("update_animation", _anim_direction_for(event, Vector3.ZERO))
			event.set_meta(META_MOVING, false)
	)

func _is_event_active(event: Node, player: Node, active_radius_tiles: float) -> bool:
	if active_radius_tiles <= 0.0:
		return true
	if player == null:
		return false
	var pe := _node_pos3(event)
	var pp := _node_pos3(player)
	var distance_world := Vector2(pe.x, pe.z).distance_to(Vector2(pp.x, pp.z))
	var cell_size := _resolve_grid_size(event)
	var distance_tiles := distance_world / maxf(0.001, cell_size)
	return distance_tiles <= active_radius_tiles

func _node_pos3(node: Node) -> Vector3:
	if node is Node3D:
		return (node as Node3D).position
	if node is Node2D:
		var p := (node as Node2D).position
		return Vector3(p.x, 0.0, p.y)
	return Vector3.ZERO

func _pos_value_for(node: Node, pos3: Vector3):
	if node is Node3D:
		return pos3
	return Vector2(pos3.x, pos3.z)

func _anim_direction_for(node: Node, dir3: Vector3):
	if node is Node2D:
		return Vector2(dir3.x, dir3.z)
	return dir3

func _interval_from_frequency(frequency: int) -> float:
	match frequency:
		1: return 1.20
		2: return 0.80
		3: return 0.50
		4: return 0.35
		5: return 0.22
		_: return 0.50

func _duration_from_speed(speed: int) -> float:
	match speed:
		1: return 0.55
		2: return 0.40
		3: return 0.28
		4: return 0.20
		5: return 0.14
		6: return 0.10
		_: return 0.20
