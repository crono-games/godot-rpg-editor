@tool
extends Node
# Runtime-only map orchestrator singleton.
# Responsibilities:
# - resolve current runtime map_id + map JSON
# - hold runtime map_data and run events through EventGraphRunner
# - bind action/touch triggers and per-frame NPC auto/parallel updates
# Not used by editor graph UI bindings.

@export var map_json_path: String = ""
@export var auto_bind_touch := true
@export var auto_run_event_id: String = ""
@export var player_group: String = "player"
@export var auto_parallel_interval := 1.0 / 60.0
@export var auto_parallel_use_delta := false
@export var auto_map_from_scene := true
@export var player_scene_path: String = "res://assets/templates/events/2d/player_instance_grid.tscn"
@export var npc_active_radius_tiles := 12.0
@export var action_input := "ui_accept"
@export var action_max_distance := 1.25
@export var action_max_distance_2d_pixels := 40.0
@export var action_min_facing_dot := 0.15
@export var action_forward_width_2d_pixels := 10.0
@export var use_relaxed_action_fallback := false

const global_state_path = "res://addons/event_editor/data/runtime/global_state.json"
const DEBUG_ACTION_TRIGGER := false
signal map_bound(map_id: String, map_json_path: String, event_count: int)

var _runner := EventGraphRunner.new()
var _runtime_context := EventRuntimeContext.new()
var _map_data: Dictionary = {}
var _current_map_id: String = ""
var _refreshing := false


var _interval := 1.0 / 60.0
var _use_delta := false
var _auto_timer: Timer = null
var _accum := 0.0
var _tick_callback: Callable

var _map_loader := MapRepository.new()
var _teleport := TeleportOrchestrator.new()
var _npc_movement := NpcMovementService.new()
var _trigger_service := EventTriggerService.new()

func _ready() -> void:
	add_to_group("map_manager")
	_runner.set_context(_runtime_context)
	_teleport.configure(player_group, player_scene_path)
	_load_global_state()

	if not _runtime_context.changed.is_connected(_on_runtime_state_changed):
		_runtime_context.changed.connect(_on_runtime_state_changed)
	if not get_tree().scene_changed.is_connected(_on_scene_changed):
		get_tree().scene_changed.connect(_on_scene_changed)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	if not get_tree().node_removed.is_connected(_on_node_removed):
		get_tree().node_removed.connect(_on_node_removed)

	configure(self, auto_parallel_interval, auto_parallel_use_delta, _on_tick_runtime)
	_on_scene_changed()
	call_deferred("_deferred_initial_refresh")

func _deferred_initial_refresh() -> void:
	# In some boot orders current_scene is still null during _ready.
	if get_tree().current_scene == null:
		await get_tree().process_frame
	_on_scene_changed()

func run_event(event_id: String) -> void:
	if _map_data.is_empty():
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	_runner.run_event(_map_data, scene_root, event_id)

func get_current_map_id() -> String:
	_ensure_map_binding()
	return _current_map_id

func get_current_scene_event_refs() -> Array:
	var scene_root := get_tree().current_scene
	if scene_root != null:
		return _map_loader.get_events_from_root(scene_root)
	if _current_map_id != "":
		return _map_loader.get_events_for_map(_current_map_id)
	return []

func get_current_event_instances() -> Array:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return []
	var out: Array = []
	for node in get_tree().get_nodes_in_group("EventInstance"):
		if node is Node and _teleport.is_node_in_scene(node, scene_root):
			out.append(node)
	return out

func get_event_instance(event_id: String) -> Node:
	var scene_root := get_tree().current_scene
	return _trigger_service.find_event_instance_by_id(
		get_tree(),
		scene_root,
		event_id,
		player_group,
		Callable(_teleport, "is_node_in_scene")
	)

func refresh_map_binding() -> void:
	_on_scene_changed()

func get_scene_root() -> Node:
	return get_tree().current_scene

func get_runtime_context() -> EventRuntimeContext:
	return _runtime_context

func request_map_change(map_id: String, pos: Vector3, fade_in: bool = false, fade_frames: int = 0, facing_dir: String = "keep") -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var current_map := get_current_map_id()

	if map_id == "" or map_id == current_map:
		_teleport.move_player_to(scene_root, pos)
		if fade_in and fade_frames > 0:
			await _teleport.fade_in(scene_root, fade_frames)
		return

	var scene_path := "res://maps/%s.tscn" % map_id
	if not ResourceLoader.exists(scene_path):
		return

	var source_player_scene_path := ""
	var current_player := _teleport.get_player(scene_root)
	if current_player != null and current_player is Node:
		source_player_scene_path = str((current_player as Node).scene_file_path)
	_teleport.begin_pending(scene_path, pos, fade_in, fade_frames, source_player_scene_path, facing_dir)
	get_tree().change_scene_to_file(scene_path)

func _on_scene_changed() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var map_root := _resolve_runtime_map_root(scene_root)

	_map_data = {}
	_current_map_id = ""
	_npc_movement.clear()
	#_trigger_service.clear_all_touch_bindings()
	_refresh_map_binding(map_root)
	_map_data = _map_loader.load_map_data(map_json_path)
	if not _map_data.is_empty():
		# Apply state-selected properties (default/conditional page) on map enter.
		_runner.initialize_event_states(_map_data, scene_root, true)

		if auto_bind_touch:
			_trigger_service.bind_touch_triggers(
				_map_data,
				scene_root,
				player_group,
				_runtime_context,
				Callable(_runner, "run_event"),
				Callable(_teleport, "is_node_in_scene")
			)
		_connect_player_bump_signal(scene_root)
		if auto_run_event_id != "":
			_runner.run_event(_map_data, scene_root, auto_run_event_id)

	if _teleport.has_pending():
		if _teleport.should_clear_pending_for_scene(scene_root):
			_teleport.clear_pending()
		else:
			call_deferred("_apply_pending_teleport", scene_root)
	
	var event_count := 0
	var events = _map_data.get("events", {})
	if typeof(events) == TYPE_DICTIONARY:
		event_count = events.size()
	emit_signal("map_bound", _current_map_id, map_json_path, event_count)

func _refresh_map_binding(scene_root: Node) -> void:
	if scene_root == null:
		return
	if auto_map_from_scene:
		_current_map_id = _map_loader.resolve_map_id_from_scene(scene_root, _derive_map_id_from_json_path(map_json_path))
		if _current_map_id != "":
			map_json_path = _map_loader.map_json_path_from_map_id(_current_map_id)
		else:
			map_json_path = _map_loader.resolve_map_json_path(scene_root, map_json_path)
			_current_map_id = _derive_map_id_from_json_path(map_json_path)
	else:
		_current_map_id = _derive_map_id_from_json_path(map_json_path)

func _derive_map_id_from_json_path(path: String) -> String:
	if path == "":
		return ""
	return path.get_file().get_basename()

func _ensure_map_binding() -> void:
	if _current_map_id != "" or not _map_data.is_empty():
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	_refresh_map_binding(_resolve_runtime_map_root(scene_root))
	if map_json_path != "":
		_map_data = _map_loader.load_map_data(map_json_path)

func _resolve_runtime_map_root(scene_root: Node) -> Node:
	if scene_root == null:
		return null
	var map_id := _extract_map_id(scene_root)
	if map_id != "":
		return scene_root

	var selected: Node = null
	for node in get_tree().get_nodes_in_group("map2d"):
		if not (node is Node):
			continue
		if not _teleport.is_node_in_scene(node, scene_root):
			continue
		var candidate := node as Node
		if _extract_map_id(candidate) != "":
			return candidate
		if selected == null:
			selected = candidate
	if selected != null:
		return selected
	return scene_root

func _extract_map_id(node: Node) -> String:
	if node == null:
		return ""
	if not node.has_method("get"):
		return ""
	var value = node.get("map_id")
	var map_id := str(value).strip_edges()
	if map_id == "" or map_id == "Null":
		return ""
	return map_id

func _apply_pending_teleport(scene_root: Node) -> void:
	await _teleport.apply_pending(scene_root)

func _load_global_state() -> void:
	var gs := _map_loader.load_global_state(global_state_path)
	if gs != null:
		_runtime_context.apply_global_state(gs)

func _on_runtime_state_changed() -> void:
	if _map_data.is_empty() or _refreshing:
		return
	_refreshing = true
	call_deferred("_deferred_refresh")

func _deferred_refresh() -> void:
	var scene_root := get_tree().current_scene
	if scene_root != null:
		_runner.refresh_event_states(_map_data, scene_root)
	_refreshing = false

func _on_tick_runtime(step: float) -> void:
	if _map_data.is_empty():
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	_npc_movement.process(_map_data, _runtime_context, step, player_group, npc_active_radius_tiles)
	_runner.run_auto_parallel(_map_data, scene_root, step)

func _input(event: InputEvent) -> void:
	if _map_data.is_empty():
		return
	if action_input == "":
		return
	if event == null:
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if not event.is_action_pressed(action_input):
		return
	_try_run_action_trigger()

func _on_node_added(node: Node) -> void:
	var scene_root := get_tree().current_scene
	if not _teleport.is_node_in_scene(node, scene_root):
		return
	_runner.invalidate_scene_environment()
	if node.is_in_group(player_group) and node.has_signal("event_bumped"):
		var cb := Callable(self, "_on_player_event_bumped")
		if not node.is_connected("event_bumped", cb):
			node.connect("event_bumped", cb)
	if _teleport.has_pending() and node.is_in_group(player_group):
		call_deferred("_apply_pending_teleport", scene_root)

func _on_node_removed(_node: Node) -> void:
	_runner.invalidate_scene_environment()

## Touch Bump is emitted by the player movement resolver when movement is blocked by a non-passable event.

func _on_player_event_bumped(event_id: String, _event_node: Node) -> void:
	if _map_data.is_empty():
		return
	if not _event_allows_touch_trigger(event_id):
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	_runtime_context.set_last_trigger_for_event(event_id, "touch_bump")
	_runner.run_event(_map_data, scene_root, event_id)

func _event_allows_touch_trigger(event_id: String) -> bool:
	return _trigger_service.event_allows_touch_trigger(_map_data, event_id, _runtime_context)

func _connect_player_bump_signal(scene_root: Node) -> void:
	if scene_root == null:
		return
	var player := _teleport.get_player(scene_root)
	if player == null or not player.has_signal("event_bumped"):
		return
	var cb := Callable(self, "_on_player_event_bumped")
	if not player.is_connected("event_bumped", cb):
		player.connect("event_bumped", cb)

func _try_run_action_trigger() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var player := get_player(scene_root)
	if player == null:
		return
	var facing_tile = player.get_facing_direction()
	
	if player.get_area_in_front(player.get_facing_direction()) == null:
		return
	var event = player.get_area_in_front(player.get_facing_direction()).get_parent()
	if event is EventInstance2D:
		var event_id = event.id
		_runtime_context.set_last_trigger_for_event(event_id, "action")
		_runner.run_event(_map_data, scene_root, event_id)

## Helpers for Action Trigger

func get_area_in_front(player: Node2D, direction: Vector2, grid_size: int, mask := 0) -> Area2D:
	
	var cell := Vector2i(player.global_position / grid_size)
	var next_cell := cell + Vector2i(direction)
	
	return get_area_at_cell(player.get_world_2d(), next_cell, grid_size, mask)

func get_area_under_player(player: Node2D, grid_size: int, mask := 0) -> Area2D:
	
	var cell := Vector2i(player.global_position / grid_size)
	
	return get_area_at_cell(player.get_world_2d(), cell, grid_size, mask)

func get_area_at_cell(world: World2D, cell: Vector2i, grid_size: int, mask := 0) -> Area2D:
	
	var space_state = world.direct_space_state
	
	var world_pos = (Vector2(cell) * grid_size) + Vector2(grid_size * 0.5, grid_size * 0.5)
	
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	if mask != 0:
		query.collision_mask = mask
	
	var result = space_state.intersect_point(query)
	
	if result.size() > 0:
		return result[0].collider
	
	return null

func get_player(scene_root: Node) -> Node:
	return find_player_in_scene(scene_root)

func find_player_in_scene(scene_root: Node) -> Node:
	if scene_root == null or not is_instance_valid(scene_root):
		return null
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node.is_in_group(player_group) and (node is Node2D or node is Node3D):
			return node
		for child in node.get_children():
			if child is Node:
				stack.push_back(child)
	return null

##Timers used in parallel process.

func _process(delta: float) -> void:
	if not _use_delta:
		return
	if _tick_callback.is_null():
		return
	_accum += delta
	if _accum < _interval:
		return
	var step := _accum
	_accum = 0.0
	_tick_callback.call(step)


func configure(owner: Node, interval: float, use_delta: bool, tick_callback: Callable) -> void:
	_interval = max(0.0001, interval)
	_use_delta = use_delta
	_tick_callback = tick_callback
	_accum = 0.0
	_setup_timer(owner)

func set_enabled(owner: Node, enabled: bool) -> void:
	if _use_delta:
		if owner != null:
			owner.set_process(enabled)
		return
	if _auto_timer == null:
		return
	if enabled:
		_auto_timer.start()
	else:
		_auto_timer.stop()


func _setup_timer(owner: Node) -> void:
	if _use_delta:
		if owner != null:
			owner.set_process(true)
		return
	if owner == null:
		return
	if _auto_timer != null and is_instance_valid(_auto_timer):
		_auto_timer.queue_free()
	_auto_timer = Timer.new()
	_auto_timer.wait_time = _interval
	_auto_timer.one_shot = false
	owner.add_child(_auto_timer)
	_auto_timer.timeout.connect(_on_timer_timeout)
	_auto_timer.start()

func _on_timer_timeout() -> void:
	if _tick_callback.is_null():
		return
	_tick_callback.call(_interval)
