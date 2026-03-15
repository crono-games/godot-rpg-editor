class_name EventGraphRunner
extends RefCounted

var _context := EventRuntimeContext.new()
var _executors := {}
var _max_steps := 1000
var _max_visits_per_node := 100
var _scene_env: EventEnvironment = null
var _state_property_applier := StatePropertyApplier.new()
var _state_selector := EventStateSelector.new()
var _last_auto_state_run_by_event := {}
var _payload_validator := NodePayloadValidator.new()
var _command_executor := CommandExecutor2D.new()
var _running_events := {}

func _init() -> void:
	_executors = {
		"move": _command_executor,
		"move_along_path": _command_executor,
		"flag_condition": _command_executor,
		"set_flag": _command_executor,
		"set_local_flag": _command_executor,
		"set_variable": _command_executor,
		"variable_operation": _command_executor,
		"variable_condition": _command_executor,
		"condition": _command_executor,
		"state": StateExecutor.new(),
		"change_graphics": _command_executor,
		"set_visibility": _command_executor,
		"change_screen_tone": _command_executor,
		"teleport_player": _command_executor,
		"set_position": _command_executor,
		"set_followers": _command_executor,
		"show_dialogue": _command_executor,
		"choice": ChoiceExecutor.new(),
		"wait": _command_executor,
		"play_bgm": _command_executor,
		"play_se": _command_executor,
		"play_animation": _command_executor,
		"play_visual_fx": _command_executor,
		"show_picture": _command_executor,
		"move_picture": _command_executor,
		"erase_picture": _command_executor,
		"label": _command_executor,
		"jump_to_label": _command_executor,
		"screen_shake": _command_executor
	}

func set_context(ctx: EventRuntimeContext) -> void:
	_context = ctx

func register_executor(type: String, executor: RefCounted) -> void:
	_executors[type] = executor

func run_event(map_data: Dictionary, scene_root: Node, event_id: String) -> void:
	if map_data.is_empty():
		return
	if _running_events.get(event_id, false):
		return
	_running_events[event_id] = true
	_prepare_scene_environment(scene_root)

	var graph := EventGraphRuntime.new(map_data, event_id)
	_context.set_current_event(event_id)
	var current := _context.get_current_state(event_id)
	if current == "":
		current = graph.get_start_node_id()
	var entry_state_id := ""
	if current != "":
		var start_node := graph.get_node(current)
		if start_node != null and str(start_node.get("type", "")) == "state":
			entry_state_id = current
	var steps := 0
	var visits := {}

	while current != "" and steps < _max_steps:
		var loop_node := graph.get_node(current)
		# Do not execute another state page in the same trigger/run.
		# State changes (flags/vars) should apply for the next trigger.
		if entry_state_id != "" and current != entry_state_id:
			if loop_node != null and str(loop_node.get("type", "")) == "state":
				_context.set_current_state(event_id, current)
				_state_property_applier.apply_state_node(loop_node, event_id, _context)
				break

		# Keep scoped event id stable during concurrent/awaited runs.
		_context.set_current_event(event_id)
		# Persist current state node per event
		var node_for_state := loop_node
		if node_for_state != null and node_for_state.get("type", "") == "state":
			_context.set_current_state(event_id, current)
			_state_property_applier.apply_state_node(node_for_state, event_id, _context)

		steps += 1
		visits[current] = int(visits.get(current, 0)) + 1
		if visits[current] > _max_visits_per_node:
			break
		var node := graph.get_node(current)
		if node == null:
			break

		var node_type := str(node.get("type", ""))
		var executor = _executors.get(node_type, null)
		if executor == null:
			current = graph.get_next(current, 0)
			continue
		var validation := _payload_validator.validate(current, node)
		if not bool(validation.get("ok", false)):
			current = graph.get_next(current, 0)
			continue
		var warnings: Array = validation.get("warnings", [])
		if warnings.size() > 0:
			pass
		var safe_node: Dictionary = validation.get("node", node)

		current = await executor.run(current, safe_node, graph, _context, scene_root)

	_running_events[event_id] = false

func reset_event_execution_state(event_id: String) -> void:
	if event_id == "":
		return
	_context.current_state_by_event.erase(event_id)
	_context.last_trigger_by_event.erase(event_id)
	_last_auto_state_run_by_event.erase(event_id)
	_running_events.erase(event_id)

func initialize_event_states(map_data: Dictionary, scene_root: Node, force_reselect: bool = true) -> void:
	if map_data.is_empty() or scene_root == null:
		return
	_prepare_scene_environment(scene_root)
	var events = map_data.get("events", {})
	for event_id in events.keys():
		_initialize_event_state(map_data, scene_root, str(event_id), force_reselect)

func refresh_event_states(map_data: Dictionary, scene_root: Node) -> void:
	if map_data.is_empty() or scene_root == null:
		return
	_prepare_scene_environment(scene_root)
	var events = map_data.get("events", {})
	for event_id in events.keys():
		_initialize_event_state(map_data, scene_root, str(event_id), true)
		_run_auto_state_if_needed(map_data, scene_root, str(event_id))

func run_auto_parallel(map_data: Dictionary, scene_root: Node, delta: float) -> void:
	if map_data.is_empty() or scene_root == null:
		return
	_prepare_scene_environment(scene_root)
	_context.set_last_delta(delta)
	var events = map_data.get("events", {})
	for event_id in events.keys():
		var graph := EventGraphRuntime.new(map_data, str(event_id))
		var current := _context.get_current_state(str(event_id))
		if current == "":
			current = graph.get_start_node_id()
		if current == "":
			continue
		var node := graph.get_node(current)
		if node == null or str(node.get("type", "")) != "state":
			continue
		var params = node.get("params", {})
		var trigger := str(params.get("trigger_mode", "action")).to_lower()
		if trigger == "auto":
			var last_auto_state := str(_last_auto_state_run_by_event.get(str(event_id), ""))
			if last_auto_state == current:
				continue
			_last_auto_state_run_by_event[str(event_id)] = current
			run_event(map_data, scene_root, str(event_id))
		elif trigger == "parallel":
			run_event(map_data, scene_root, str(event_id))

func _initialize_event_state(map_data: Dictionary, scene_root: Node, event_id: String, force_reselect: bool = false) -> void:
	_context.set_current_event(event_id)
	var graph := EventGraphRuntime.new(map_data, event_id)
	var current := _context.get_current_state(event_id)
	if force_reselect:
		current = ""
	if current == "":
		current = _state_selector.select_initial_state(graph, _context, event_id)
	if current == "":
		current = graph.get_start_node_id()
	if current == "":
		return
	var event_instance := _find_event_instance_by_id(scene_root, event_id)
	var event_name = event_instance.name if event_instance != null else ""
	_context.set_current_state(event_id, current)

	# Allow `auto` to run once when entering a new state.
	if str(_last_auto_state_run_by_event.get(event_id, "")) != current:
		_last_auto_state_run_by_event.erase(event_id)
	var node_for_state := graph.get_node(current)
	if node_for_state != null and node_for_state.get("type", "") == "state":
		_state_property_applier.apply_state_node(node_for_state, event_id, _context)

func _run_auto_state_if_needed(map_data: Dictionary, scene_root: Node, event_id: String) -> void:
	var graph := EventGraphRuntime.new(map_data, event_id)
	var current := _context.get_current_state(event_id)
	if current == "":
		return
	var node := graph.get_node(current)
	if node == null:
		return
	if str(node.get("type", "")) != "state":
		return
	var params = node.get("params", {})
	var trigger := str(params.get("trigger_mode", "action")).to_lower()
	if trigger == "auto" or trigger == "parallel":
		run_event(map_data, scene_root, event_id)

func _find_event_instance_by_id(root: Node, event_id: String) -> Node:
	_prepare_scene_environment(root)
	return _context.get_event_by_id(event_id)

func _prepare_scene_environment(scene_root: Node) -> void:
	if scene_root == null or not is_instance_valid(scene_root):
		return
	if _scene_env == null:
		_scene_env = _create_scene_environment(scene_root)
		_context.set_scene_event_environment(_scene_env)
		return
	var expected_2d := scene_root is Node2D
	var has_2d := _scene_env is SceneEventEnvironment2D
	if expected_2d != has_2d:
		_scene_env = _create_scene_environment(scene_root)
		_context.set_scene_event_environment(_scene_env)
	else:
		_scene_env.set_root(scene_root)

func invalidate_scene_environment() -> void:
	if _scene_env == null:
		return
	_scene_env.mark_dirty()

func ensure_scene_environment(scene_root: Node) -> EventEnvironment:
	_prepare_scene_environment(scene_root)
	return _scene_env

func _create_scene_environment(scene_root: Node) -> EventEnvironment:
	if scene_root is Node2D:
		return SceneEventEnvironment2D.new(scene_root)
	return SceneEventEnvironment3D.new(scene_root)
