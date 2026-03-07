class_name EventTriggerService
extends RefCounted

var _pending_by_event: Dictionary = {}

func bind_touch_triggers(
	map_data: Dictionary,
	scene_root: Node,
	player_group: String,
	runtime_context: EventRuntimeContext,
	run_event_callback: Callable,
	is_node_in_scene: Callable
) -> void:
	if map_data.is_empty() or scene_root == null:
		return
	if run_event_callback == null or not run_event_callback.is_valid():
		return

	var events = map_data.get("events", {})
	for event_id_key in events.keys():
		var event_id := str(event_id_key)
		var trigger := _resolve_event_trigger(map_data, event_id, runtime_context)
		if trigger == "":
			continue
		if trigger != "touch_overlap" and trigger != "event_touch_overlap":
			continue
		var event_instance := find_event_instance_by_id(
			scene_root.get_tree(),
			scene_root,
			event_id,
			player_group,
			is_node_in_scene
		)
		if event_instance == null:
			continue
		bind_touch(
			event_instance,
			_on_body_entered,
			_on_area_entered,
			[map_data, scene_root, event_id, trigger, player_group, runtime_context, run_event_callback]
		)

func resolve_action_event_id():
	pass

func event_allows_touch_trigger(map_data: Dictionary, event_id: String, runtime_context: EventRuntimeContext) -> bool:
	if event_id == "":
		return false
	var graph := EventGraphRuntime.new(map_data, event_id)
	var state_id := runtime_context.get_current_state(event_id)
	if state_id == "":
		state_id = graph.get_start_node_id()
	if state_id == "":
		return false
	var state_node := graph.get_node(state_id)
	if state_node == null or str(state_node.get("type", "")) != "state":
		return false
	var params = state_node.get("params", {})
	var trigger := _normalize_trigger_mode(str(params.get("trigger_mode", "")))
	return trigger == "touch_bump"

func find_event_instance_by_id(
	scene_tree: SceneTree,
	scene_root: Node,
	event_id: String,
	player_group: String,
	is_node_in_scene: Callable
) -> Node:
	if scene_root == null or event_id == "":
		return null
	for node in scene_tree.get_nodes_in_group("EventInstance"):
		if not (node is Node):
			continue
		if is_node_in_scene.is_valid() and not bool(is_node_in_scene.call(node, scene_root)):
			continue
		if node.is_in_group(player_group):
			continue
		if str(node.get("id")) == event_id:
			return node
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var current := stack.pop_back()
		if current != null and current.has_method("get"):
			if current.is_in_group(player_group):
				for child in current.get_children():
					if child is Node:
						stack.push_back(child)
				continue
			if str(current.get("id")) == event_id:
				return current
		for child in current.get_children():
			if child is Node:
				stack.push_back(child)
	return null

func _on_body_entered(
	body: Node,
	map_data: Dictionary,
	scene_root: Node,
	event_id: String,
	trigger: String,
	player_group: String,
	runtime_context: EventRuntimeContext,
	run_event_callback: Callable
) -> void:
	var trigger_actor := body
	if trigger == "touch_overlap":
		trigger_actor = _resolve_player_group_node(body, player_group)
		if trigger_actor == null:
			return
	if trigger == "touch_overlap" and not _node_matches_player_group(trigger_actor, player_group):
		return
	if _is_touch_pending(event_id):
		return
	await _stabilize_before_touch(trigger_actor, event_id)
	runtime_context.set_last_trigger_for_event(event_id, trigger)
	run_event_callback.call(map_data, scene_root, event_id)

func _on_area_entered(
	area: Node,
	map_data: Dictionary,
	scene_root: Node,
	event_id: String,
	trigger: String,
	player_group: String,
	runtime_context: EventRuntimeContext,
	run_event_callback: Callable
) -> void:
	var trigger_actor := area
	if trigger == "touch_overlap":
		trigger_actor = _resolve_player_group_node(area, player_group)
		if trigger_actor == null:
			return
	if trigger == "touch_overlap" and not _node_matches_player_group(trigger_actor, player_group):
		return
	if _is_touch_pending(event_id):
		return
	await _stabilize_before_touch(trigger_actor, event_id)
	runtime_context.set_last_trigger_for_event(event_id, trigger)
	run_event_callback.call(map_data, scene_root, event_id)

func _resolve_player_facing(player: Node) -> Vector3:
	if player == null:
		return Vector3.ZERO
	var facing := Vector3.ZERO
	if player.has_method("get_facing_direction"):
		var v = player.call("get_facing_direction")
		if v is Vector3:
			facing = v
	if facing == Vector3.ZERO and player.has_method("get"):
		var v2 = player.get("_last_dir")
		if v2 is Vector3:
			facing = v2
		elif v2 is Vector2:
			var vv := v2 as Vector2
			facing = Vector3(vv.x, 0.0, vv.y)
	facing.y = 0.0
	if facing.length_squared() <= 0.000001:
		return Vector3.ZERO
	return facing.normalized()

func _normalize_trigger_mode(raw_trigger: String) -> String:
	var trigger := str(raw_trigger).to_lower()
	match trigger:
		"touch", "player_touch":
			return "touch_overlap"
		"event_touch":
			return "event_touch_overlap"
		"bump", "player_bump":
			return "touch_bump"
		_:
			return trigger

func _node_world_pos3(node: Node) -> Vector3:
	if node is Node3D:
		return (node as Node3D).global_position
	if node is Node2D:
		var p := (node as Node2D).global_position
		return Vector3(p.x, p.y, 0.0)
	return Vector3.ZERO

func _resolve_event_trigger(map_data: Dictionary, event_id: String, runtime_context: EventRuntimeContext) -> String:
	if event_id == "":
		return ""
	var graph := EventGraphRuntime.new(map_data, event_id)
	var current := runtime_context.get_current_state(event_id)
	if current == "":
		current = graph.get_start_node_id()
	if current == "":
		return ""
	var node := graph.get_node(current)
	if node == null:
		return ""
	var params = node.get("params", {})
	return _normalize_trigger_mode(str(params.get("trigger_mode", "")))

func _node_matches_player_group(node: Node, player_group: String) -> bool:
	if node == null:
		return false
	var n: Node = node
	while n != null:
		if n.is_in_group(player_group):
			return true
		n = n.get_parent()
	return false

func _resolve_player_group_node(node: Node, player_group: String) -> Node:
	if node == null:
		return null
	var n: Node = node
	while n != null:
		if n.is_in_group(player_group):
			return n
		n = n.get_parent()
	return null

func _is_touch_pending(event_id: String) -> bool:
	return bool(_pending_by_event.get(event_id, false))

func _stabilize_before_touch(actor: Node, event_id: String) -> void:
	if event_id == "":
		return
	if actor == null:
		return
	if not _uses_grid_resolution(actor):
		return
	if not _is_actor_moving(actor):
		_snap_actor_to_grid(actor)
		return

	_pending_by_event[event_id] = true
	if actor.has_signal("move_finished"):
		await actor.move_finished
	else:
		await Engine.get_main_loop().process_frame
	_snap_actor_to_grid(actor)
	_pending_by_event[event_id] = false



func _is_actor_moving(actor: Node) -> bool:
	if actor == null:
		return false
	if actor.has_method("is_moving"):
		return bool(actor.call("is_moving"))
	return false

func _snap_actor_to_grid(actor: Node) -> void:
	if actor == null:
		return
	if actor.has_method("snap_to_grid"):
		actor.call("snap_to_grid")

func _uses_grid_resolution(actor: Node) -> bool:
	if actor == null:
		return false
	if actor.has_method("get_trigger_resolution_mode"):
		var mode := str(actor.call("get_trigger_resolution_mode")).to_lower()
		return mode == "grid"
	var raw_mode = actor.get("trigger_resolution_mode")
	if raw_mode == null:
		return actor.has_method("is_moving")
	var mode_text := str(raw_mode).to_lower()
	return mode_text == "grid"

func bind_touch(event_instance: Node, body_handler: Callable, area_handler: Callable, bind_args: Array = []) -> void:
	if event_instance == null:
		return

	var touch_area := _resolve_touch_area(event_instance)
	if touch_area == null:
		return

	var body_cb := body_handler.bindv(bind_args)
	var area_cb := area_handler.bindv(bind_args)

	if touch_area.has_signal("body_entered") and not touch_area.body_entered.is_connected(body_cb):
		touch_area.body_entered.connect(body_cb)

	if touch_area.has_signal("area_entered") and not touch_area.area_entered.is_connected(area_cb):
		touch_area.area_entered.connect(area_cb)

func _resolve_touch_area(event_instance: Node) -> Node:
	if event_instance == null:
		return null

	# 1 direct area
	if event_instance is Area2D or event_instance is Area3D:
		var resolved := _call_trigger_method(event_instance)
		return resolved if resolved != null else event_instance

	# 2 trigger method
	var method_area := _call_trigger_method(event_instance)
	if method_area != null:
		return method_area

	# 3 known properties
	for prop in ["trigger_area", "area"]:
		var ref := event_instance.get(prop)
		if ref is Area2D or ref is Area3D:
			return ref

	# 4 children fallback
	for child in event_instance.get_children():
		if child is Area2D or child is Area3D:
			return child

	return null

func _call_trigger_method(node: Node) -> Node:
	if node.has_method("get_trigger_area"):
		var result = node.call("get_trigger_area")
		if result is Area2D or result is Area3D:
			return result
	return null
