class_name EventMovementService
extends RefCounted

const CARDINAL_DIRS := [
	Vector3(1, 0, 0),
	Vector3(-1, 0, 0),
	Vector3(0, 0, 1),
	Vector3(0, 0, -1)
]
const ACTION_PAUSE_SECONDS := 0.35
const DIALOGUE_PAUSE_GROUP := "dialogue_runner"

class EventMovementState:
	var event_id: String
	var direction: Vector3
	var current_pos: Vector3
	var next_pos: Vector3
	var current_cell: Vector2i
	var next_cell: Vector2i
	var grid_size: float
	var grid_centered: bool
	
	func _init(id: String, pos: Vector3) -> void:
		event_id = id
		direction = Vector3.ZERO
		current_pos = pos
		next_pos = pos
		grid_size = 1.0
		grid_centered = true

class MovementConfig:
	var movement_type: String
	var frequency: int
	var speed: int
	var interval: float
	var step_time: float
	
	func _init(props: Dictionary) -> void:
		movement_type = str(props.get("movement_type", "fixed")).to_lower()
		frequency = clampi(int(props.get("movement_frequency", 2)), 1, 5)
		speed = clampi(int(props.get("movement_speed", 3)), 1, 6)
		interval = 0.0
		step_time = 0.0

var _accum_by_event: Dictionary = {}
var _action_pause_by_event: Dictionary = {}
var _last_dir_by_event: Dictionary = {}
var _moving_by_event: Dictionary = {}

## Clears all accumulated time and state data for events.
## Called when resetting or unloading a map.
func clear() -> void:
	_accum_by_event.clear()
	_action_pause_by_event.clear()
	_last_dir_by_event.clear()
	_moving_by_event.clear()

## Main update function for NPC movement.
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

func _process_event(map_data: Dictionary, ctx: EventRuntimeContext, event_id: String, delta: float, player_group: String, player: Node, active_radius_tiles: float) -> void:
	var event := _resolve_event_node(map_data, ctx, event_id)
	if not _is_valid_event_node(event):
		return
	
	if EventNodeResolver.is_player_node(event, player_group, player) or not _is_event_active(event, player, active_radius_tiles):
		return
	
	var scene_root := ctx.get_scene_event_environment()
	if _is_dialogue_running(scene_root) and player != null and _is_player_adjacent(event, player):
		var event_pos := EventNodeResolver.node_to_pos3(event)
		var player_pos := EventNodeResolver.node_to_pos3(player)
		var dir_to_player := player_pos - event_pos
		var anim_dir = EventNodeResolver.dir3_to_animation_dir(event, dir_to_player)
		
		if event.has_method("play_animation"):
			event.call("play_animation", "idle", anim_dir)
		return
	
	if _should_pause_for_action(ctx, event_id, delta):
		return
	
	if _is_currently_moving(event):
		return
	
	var config := _load_movement_config(map_data, ctx, event_id)
	if config == null:
		return
	
	if not _check_time_interval(event_id, delta, config):
		return
	
	var state := EventMovementState.new(event_id, EventNodeResolver.node_to_pos3(event))
	_resolve_grid_props(event, state)
	
	if not _calculate_valid_move(event_id, event, ctx, player, config, state):
		return
	
	var duration := _duration_from_speed(config.speed)
	if config.step_time > 0:
		duration = config.step_time
	_apply_move(event, state.next_pos, state.direction, duration)

func _is_valid_event_node(event: Node) -> bool:
	return event != null and (event is Node2D or event is Node3D)

func _is_currently_moving(event: Node) -> bool:
	if event == null or not event.has_method("get"):
		return false
	var event_id := str(event.get("id"))
	return _is_moving(event_id)

## Resolves an event node from cache or map data using fallback.
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

## Loads and validates movement configuration from the event's graph definition.
func _load_movement_config(map_data: Dictionary, ctx: EventRuntimeContext, event_id: String) -> MovementConfig:
	var graph := EventGraphRuntime.new(map_data, event_id)
	var state_id := ctx.get_current_state(event_id)
	if state_id == "":
		state_id = graph.get_start_node_id()
	if state_id == "":
		return null
	
	var state_node := graph.get_node(state_id)
	if state_node == null or str(state_node.get("type", "")) != "state":
		return null
	
	var params: Dictionary = state_node.get("params", {})
	var props: Dictionary = params.get("properties", {})
	
	var config = MovementConfig.new(props)
	
	# Skip fixed movement
	if config.movement_type == "" or config.movement_type == "fixed":
		return null
	
	config.interval = _interval_from_frequency(config.frequency)
	if props.has("movement_interval"):
		config.interval = maxf(0.01, float(props.get("movement_interval", config.interval)))
	
	config.step_time = _duration_from_speed(config.speed)
	if props.has("movement_step_time"):
		config.step_time = maxf(0.01, float(props.get("movement_step_time", config.step_time)))
	
	return config

## Checks if a dialogue is currently running in the scene.
## Searches for active DialogueRunner nodes and verifies their state is not IDLE.
## Returns true if any dialogue is in progress (TYPING, WAITING, or CHOOSING states).
func _is_dialogue_running(scene_env: EventEnvironment) -> bool:
	if scene_env == null:
		return false
	
	var scene_root: Node = null
	if scene_env.has_method("get_root"):
		scene_root = scene_env.call("get_root")
	
	if scene_root == null:
		return false
	
	## Check if any DialogueRunner is active (not in IDLE state)
	## DialogueRunner.State.IDLE == 0, so any non-zero state means active dialogue
	for dialogue_runner in scene_root.get_tree().get_nodes_in_group(DIALOGUE_PAUSE_GROUP):
		if dialogue_runner == null or not is_instance_valid(dialogue_runner):
			continue
		
		if dialogue_runner.has_meta("state"):
			var state_val = dialogue_runner.get_meta("state")
			if state_val != 0:
				return true
		elif "state" in dialogue_runner:
			if dialogue_runner.state != 0:
				return true
	
	return false

## Makes an event look at the target node during dialogue.
## Only attempts animation if the event supports it.
func _make_event_look_at_target(event: Node, target: Node) -> void:
	if event == null or target == null:
		return
	if not event.has_method("update_animation"):
		return
	
	var event_pos := EventNodeResolver.node_to_pos3(event)
	var target_pos := EventNodeResolver.node_to_pos3(target)
	var direction := target_pos - event_pos
	
	var anim_dir = EventNodeResolver.dir3_to_animation_dir(event, direction)
	event.call("update_animation", anim_dir)

## Checks if enough time has elapsed to process the next movement step.
## Manages movement interval accumulation for each event based on frequency.
## Returns true if movement should be processed this frame, false otherwise.
func _check_time_interval(event_id: String, delta: float, config: MovementConfig) -> bool:
	var accum := float(_accum_by_event.get(event_id, 0.0)) + delta
	if accum < config.interval:
		_accum_by_event[event_id] = accum
		return false
	_accum_by_event[event_id] = 0.0
	return true

## Resolves and caches grid properties in the movement state.
## Retrieves grid_size and grid_centered from the event, and calculates current cell position.
func _resolve_grid_props(event: Node, state: EventMovementState) -> void:
	state.grid_size = EventNodeResolver.resolve_grid_size(event)
	state.grid_centered = EventNodeResolver.resolve_grid_centered(event)
	state.current_cell = GridUtils.world_to_cell(state.current_pos, state.grid_size, state.grid_centered)

## Calculates a valid movement step for the event.
## Determines direction, checks for player adjacency, and validates the target path.
## Returns true if a valid move was planned, false if no valid direction exists.
func _calculate_valid_move(event_id: String, event: Node, ctx: EventRuntimeContext, player: Node, config: MovementConfig, state: EventMovementState) -> bool:
	# Pick initial direction
	state.direction = _pick_direction(config.movement_type, event, ctx, event_id)
	
	# Override if player is adjacent (evade behavior)
	if _is_player_adjacent(event, player):
		var away := _pick_away_from_player(event, player)
		if away != Vector3.ZERO:
			state.direction = away
	
	if state.direction == Vector3.ZERO:
		return false
	
	# Calculate next position
	state.next_cell = state.current_cell + Vector2i(int(state.direction.x), int(state.direction.z))
	state.next_pos = GridUtils.cell_to_world(state.next_cell, state.current_pos.y, state.grid_size, state.grid_centered)
	
	# Validate and resolve collisions
	return _validate_and_resolve_path(event_id, event, ctx, player, config, state)

func _validate_and_resolve_path(event_id: String, event: Node, ctx: EventRuntimeContext, player: Node, config: MovementConfig, state: EventMovementState) -> bool:
	# Check for blocking
	var max_retries := 3
	var retry_count := 0
	
	while retry_count < max_retries:
		if _path_is_clear(event_id, event, ctx, player, state):
			return true
		
		# Try to reroll direction
		if config.movement_type != "random":
			return false
		
		var new_dir := _pick_random_dir(event_id)
		if new_dir == state.direction:
			retry_count += 1
			continue
		
		state.direction = new_dir
		state.next_cell = state.current_cell + Vector2i(int(state.direction.x), int(state.direction.z))
		state.next_pos = GridUtils.cell_to_world(state.next_cell, state.current_pos.y, state.grid_size, state.grid_centered)
		retry_count += 1
	
	return false

func _path_is_clear(event_id: String, event: Node, ctx: EventRuntimeContext, player: Node, state: EventMovementState) -> bool:
	if _is_event_cell_occupied(ctx, event_id, state.next_cell, state.grid_size, state.grid_centered):
		return false
	
	if _is_player_cell_occupied(player, state.next_cell, state.grid_size, state.grid_centered):
		return false
	
	if _is_world_blocked_for_event(event, state.current_pos, state.next_pos):
		return false
	
	return true


func _pick_direction(movement_type: String, event: Node, ctx: EventRuntimeContext, event_id: String = "") -> Vector3:
	match movement_type:
		"random":
			return _pick_random_dir(event_id)
		"approach":
			return _pick_approach_direction(event, ctx)
		_:
			return Vector3.ZERO

func _pick_approach_direction(event: Node, ctx: EventRuntimeContext) -> Vector3:
	var env := ctx.get_scene_event_environment()
	if env == null:
		return Vector3.ZERO
	
	var player := env.get_player("player")
	if player == null:
		return Vector3.ZERO
	
	var d := EventNodeResolver.node_to_pos3(player) - EventNodeResolver.node_to_pos3(event)
	if absf(d.x) >= absf(d.z):
		return Vector3(1, 0, 0) if d.x > 0 else Vector3(-1, 0, 0)
	return Vector3(0, 0, 1) if d.z > 0 else Vector3(0, 0, -1)

func _pick_away_from_player(event: Node, player: Node) -> Vector3:
	if event == null or player == null:
		return Vector3.ZERO
	var grid_size := EventNodeResolver.resolve_grid_size(event)
	var grid_centered := EventNodeResolver.resolve_grid_centered(event)
	var event_cell := GridUtils.world_to_cell(EventNodeResolver.node_to_pos3(event), grid_size, grid_centered)
	var player_cell := GridUtils.world_to_cell(EventNodeResolver.node_to_pos3(player), grid_size, grid_centered)
	var dx := event_cell.x - player_cell.x
	var dy := event_cell.y - player_cell.y
	if abs(dx) >= abs(dy):
		return Vector3(1, 0, 0) if dx > 0 else Vector3(-1, 0, 0)
	return Vector3(0, 0, 1) if dy > 0 else Vector3(0, 0, -1)

func _pick_random_dir(event_id: String) -> Vector3:
	var last := _last_dir_by_event.get(event_id, Vector3.ZERO)
	var dir = CARDINAL_DIRS[randi() % CARDINAL_DIRS.size()]
	var tries := 0
	while tries < 4 and dir == last:
		dir = CARDINAL_DIRS[randi() % CARDINAL_DIRS.size()]
		tries += 1
	_last_dir_by_event[event_id] = dir
	return dir

# ============= COLLISION & BLOCKING CHECKS =============

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
		var p := EventNodeResolver.node_to_pos3(node)
		var cell := GridUtils.world_to_cell(p, grid_size, grid_centered)
		if cell == next_cell:
			return true
	return false

func _is_player_cell_occupied(player: Node, next_cell: Vector2i, grid_size: float, grid_centered: bool) -> bool:
	if player == null:
		return false
	var p := EventNodeResolver.node_to_pos3(player)
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
		var resolved := EventNodeResolver.resolve_hitbox_shape(hitbox_area)
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


func _is_player_adjacent(event: Node, player: Node) -> bool:
	if player == null:
		return false
	var grid_size := EventNodeResolver.resolve_grid_size(event)
	var grid_centered := EventNodeResolver.resolve_grid_centered(event)
	var event_cell := GridUtils.world_to_cell(EventNodeResolver.node_to_pos3(event), grid_size, grid_centered)
	var player_cell := GridUtils.world_to_cell(EventNodeResolver.node_to_pos3(player), grid_size, grid_centered)
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
	if event == null or not event.has_method("get"):
		return
	var event_id := str(event.get("id"))
	_moving_by_event[event_id] = true
	
	if event.has_method("update_animation"):
		event.call("update_animation", EventNodeResolver.dir3_to_animation_dir(event, dir))
	if event.has_method("_sync_anim_speed_to_step"):
		event.call("_sync_anim_speed_to_step", duration)
	var tween := event.get_tree().create_tween()
	tween.tween_property(event, "position", EventNodeResolver.pos3_to_node_value(event, next_pos), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		if event != null and is_instance_valid(event):
			if event.has_method("_reset_anim_speed"):
				event.call("_reset_anim_speed")
			if event.has_method("update_animation"):
				event.call("update_animation", EventNodeResolver.dir3_to_animation_dir(event, Vector3.ZERO))
			_moving_by_event[event_id] = false
	)

## Checks if an event is currently moving (internal tracking state).
## Returns true if the event has an active movement tween.
func _is_moving(event_id: String) -> bool:
	return bool(_moving_by_event.get(event_id, false))

func _is_event_active(event: Node, player: Node, active_radius_tiles: float) -> bool:
	if active_radius_tiles <= 0.0:
		return true
	if player == null:
		return false
	var pe := EventNodeResolver.node_to_pos3(event)
	var pp := EventNodeResolver.node_to_pos3(player)
	var distance_world := Vector2(pe.x, pe.z).distance_to(Vector2(pp.x, pp.z))
	var cell_size := EventNodeResolver.resolve_grid_size(event)
	var distance_tiles := distance_world / maxf(0.001, cell_size)
	return distance_tiles <= active_radius_tiles

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
