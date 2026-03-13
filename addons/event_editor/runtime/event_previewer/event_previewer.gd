@tool
extends Control
class_name EventPreviewer

signal play_requested(map_id: String, event_id: String, scene_root: Node)
signal preview_ready(scene_root: Node)
signal event_selection_changed(event_id: String)

var is_playing: bool = false
var _stop_requested: bool = false

var _session := EventPreviewSession.new()
var _state_selector := EventStateSelector.new()
var _preview_state_ctx := EventRuntimeContext.new()
var map_id: String = ""
var scene_root_provider: Callable
var map_data_provider: Callable
var selected_node_provider: Callable
var event_runner: Object

@export var preview_viewport: SubViewport
@export var play_button: Button
@export var stop_button: Button
@export var event_selector: OptionButton
@export var preview_button: Button
@export var preview_from_node_check: CheckButton
@export var sub_viewport_container: SubViewportContainer

func _ready() -> void:
	_session.preview_ready.connect(_on_preview_ready)
	_session.selection_changed.connect(_on_session_selection_changed)

func refresh_from_scene_root(scene_root: Node, preferred_event_id: String = "") -> void:
	if scene_root == null:
		return
	if preview_viewport == null or not preview_viewport.is_inside_tree():
		return
	_clear_preview_viewport()
	_session.clear()
	var scne = _duplicate_scene_root(scene_root)
	if scne == null:
		return
	_session.build_from_scene_root(scne, preferred_event_id)
	call_deferred("_add_preview_to_viewport", scne)
	_apply_initial_graphics_from_map_data()
	_populate_event_selector()
	if _session.selected_event_id != "":
		_session.set_event_camera(_session.selected_event_id)

func _add_preview_to_viewport(root: Node) -> void:
	if preview_viewport == null or root == null:
		return
	if not is_instance_valid(preview_viewport) or not is_instance_valid(root):
		return
	if root.get_parent() == null:
		preview_viewport.add_child(root)

func _clear_preview_viewport() -> void:
	if preview_viewport == null:
		return
	for child in preview_viewport.get_children():
		if child is Node:
			preview_viewport.remove_child(child)
			(child as Node).queue_free()

func _populate_event_selector() -> void:
	if event_selector == null:
		return
	var prev_id := _get_selected_event_id()
	var events: Array = EventEditorManager.get_event_refs_for_active_map()
	var was_blocked := event_selector.is_blocking_signals()
	event_selector.set_block_signals(true)
	event_selector.clear()
	var selected_idx := -1
	for i in events.size():
		var event_inst = events[i]
		var event_id := str(event_inst.get("id"))
		event_selector.add_item(event_inst.name, i)
		event_selector.set_item_metadata(i, event_id)
		if prev_id != "" and event_id == prev_id:
			selected_idx = i
		elif prev_id == "" and _session.selected_event_id != "" and event_id == _session.selected_event_id:
			selected_idx = i
	if selected_idx < 0 and event_selector.item_count > 0:
		selected_idx = 0
	if selected_idx >= 0:
		event_selector.select(selected_idx)
	event_selector.set_block_signals(was_blocked)


func _on_preview_button_pressed() -> void:
	if _session.selected_event_node == null or _session.preview_scene == null:
		return

	var event_id := _get_selected_event_id()
	if event_id != "":
		_session.set_event_camera(event_id)

func _on_play_button_pressed() -> void:
	if is_playing or _session.preview_scene == null:
		return

	_stop_requested = false
	is_playing = true
	_session.restore_original_states()

	var map_data = get_map_data()
	if map_data == null:
		is_playing = false
		return

	var run_data: Dictionary = map_data
	if _is_preview_from_node_enabled():
		var selected_node := get_selected_node_snapshot()
		if _can_preview_selected_node(selected_node):
			run_data = _build_single_node_preview_data(map_data, _session.selected_event_id, selected_node)

	emit_signal("play_requested", map_id, _session.selected_event_id, _session.preview_scene)
	if event_runner != null and event_runner.has_method("reset_event_execution_state"):
		event_runner.call("reset_event_execution_state", _session.selected_event_id)
	await run_event_auto_preview(run_data, _session.preview_scene, _session.selected_event_id)
	if _stop_requested:
		_session.restore_original_states()
		if event_runner != null and event_runner.has_method("reset_event_execution_state"):
			event_runner.call("reset_event_execution_state", _session.selected_event_id)
	is_playing = false

func _on_stop_button_pressed() -> void:
	_stop_requested = true
	is_playing = false
	if event_runner != null and event_runner.has_method("reset_event_execution_state"):
		event_runner.call("reset_event_execution_state", _session.selected_event_id)
	_session.restore_original_states()

func get_selected_event() -> Node:
	var event_id := _get_selected_event_id()
	if event_id == "":
		return null
	return _session.get_event_by_id(event_id)

func _on_event_selector_item_selected(index: int) -> void:
	var event_id := _get_selected_event_id(index)
	if event_id == "":
		return
	_session.select_event_by_id(event_id)
	_session.set_event_camera(event_id)

# ==================================================
# Public API (dependency injection)
# ==================================================

func set_scene_root_provider(provider: Callable) -> void:
	scene_root_provider = provider

func set_map_data_provider(provider: Callable) -> void:
	map_data_provider = provider

func set_selected_node_provider(provider: Callable) -> void:
	selected_node_provider = provider

func set_event_runner(runner: Object) -> void:
	event_runner = runner

func set_map_id(id: String) -> void:
	map_id = id

# ==================================================
# Session signals
# ==================================================

func _on_preview_ready(scene_root: Node) -> void:
	emit_signal("preview_ready", scene_root)

func _on_session_selection_changed(event_id: String) -> void:
	emit_signal("event_selection_changed", event_id)

func _duplicate_scene_root(scene_root: Node) -> Node:
	var dup := scene_root.duplicate(DUPLICATE_USE_INSTANTIATION | DUPLICATE_SIGNALS) as Node
	return dup

func _get_selected_event_id(index: int = -1) -> String:
	if event_selector == null or event_selector.item_count == 0:
		return ""
	var idx := index
	if idx < 0:
		idx = event_selector.get_selected_id()
		if idx < 0:
			idx = event_selector.selected
	if idx < 0 or idx >= event_selector.item_count:
		return ""
	return str(event_selector.get_item_metadata(idx)).strip_edges()

func get_scene_root() -> Node:
	if scene_root_provider != null and scene_root_provider.is_valid():
		return scene_root_provider.call() as Node
	if Engine.is_editor_hint():
		return EditorInterface.get_edited_scene_root() as Node
	return null

func get_map_data() -> Dictionary:
	if map_data_provider != null and map_data_provider.is_valid():
		return map_data_provider.call()
	if map_id == "":
		return {}
	var persistence := GraphPersistenceService.new()
	return persistence.load_map(map_id)

func get_selected_node_snapshot() -> Dictionary:
	if selected_node_provider != null and selected_node_provider.is_valid():
		var snapshot = selected_node_provider.call()
		if typeof(snapshot) == TYPE_DICTIONARY:
			return snapshot
	return {}

func _is_preview_from_node_enabled() -> bool:
	if preview_from_node_check == null:
		return false
	return preview_from_node_check.button_pressed

func run_event(map_data: Dictionary, scene_root: Node, event_id: String) -> void:
	if event_runner == null:
		push_warning("EventPreviewer: no event_runner set.")
		return
	if event_runner.has_method("run_event"):
		await event_runner.run_event(map_data, scene_root, event_id)
	elif event_runner.has_method("_run_event"):
		await event_runner._run_event(map_data, scene_root, event_id)
	else:
		push_warning("EventPreviewer: event_runner has no run_event/_run_event.")

func run_event_auto_preview(map_data: Dictionary, scene_root: Node, event_id: String) -> void:
	var preview_data := _with_auto_state_triggers(map_data, event_id)
	await run_event(preview_data, scene_root, event_id)

func apply_state_properties(event_id: String, params: Dictionary) -> void:
	if _session == null or _session.preview_scene == null or event_id == "":
		return
	var is_default_state := bool(params.get("is_default", false)) or str(params.get("state_id", "")) == "default"
	if not is_default_state:
		return
	var target := _session.get_event_by_id(event_id)
	if target == null:
		return
	var properties = params.get("properties", {})
	if typeof(properties) != TYPE_DICTIONARY:
		return
	var graphics = properties.get("graphics", {})
	if typeof(graphics) != TYPE_DICTIONARY:
		return
	_apply_graphics_to_event(target, graphics)

func _with_auto_state_triggers(map_data: Dictionary, event_id: String) -> Dictionary:
	if typeof(map_data) != TYPE_DICTIONARY:
		return map_data
	var out := map_data.duplicate(true)
	var events = out.get("events", {})
	if typeof(events) != TYPE_DICTIONARY or not events.has(event_id):
		return out
	var event_data = events[event_id]
	if typeof(event_data) != TYPE_DICTIONARY:
		return out
	var flow = event_data.get("flow", {})
	if typeof(flow) != TYPE_DICTIONARY:
		return out
	var nodes = flow.get("nodes", {})
	if typeof(nodes) != TYPE_DICTIONARY:
		return out
	for node_id in nodes.keys():
		var node = nodes[node_id]
		if typeof(node) != TYPE_DICTIONARY:
			continue
		if str(node.get("type", "")) != "state":
			continue
		var params = node.get("params", {})
		if typeof(params) != TYPE_DICTIONARY:
			params = {}
		params["trigger_mode"] = "auto"
		node["params"] = params
		nodes[node_id] = node
	flow["nodes"] = nodes
	event_data["flow"] = flow
	events[event_id] = event_data
	out["events"] = events
	return out

func _can_preview_selected_node(node_snapshot: Dictionary) -> bool:
	if typeof(node_snapshot) != TYPE_DICTIONARY or node_snapshot.is_empty():
		return false
	if _session.selected_event_id == "":
		return false
	var node_type := str(node_snapshot.get("type", "")).strip_edges()
	return node_type != "" and node_type != "state"

func _build_single_node_preview_data(map_data: Dictionary, event_id: String, node_snapshot: Dictionary) -> Dictionary:
	if typeof(map_data) != TYPE_DICTIONARY:
		return map_data
	var out := map_data.duplicate(true)
	var events = out.get("events", {})
	if typeof(events) != TYPE_DICTIONARY or not events.has(event_id):
		return out

	var node_id := str(node_snapshot.get("id", "")).strip_edges()
	if node_id == "":
		node_id = "preview_node"

	var node_type := str(node_snapshot.get("type", "")).strip_edges()
	var params = node_snapshot.get("params", {})
	if typeof(params) != TYPE_DICTIONARY:
		params = {}

	var preview_node := {
		"type": node_type,
		"params": (params as Dictionary).duplicate(true)
	}
	var flow := {
		"nodes": {node_id: preview_node},
		"edges": []
	}

	var event_data = events[event_id]
	if typeof(event_data) != TYPE_DICTIONARY:
		event_data = {}
	event_data["flow"] = flow
	events[event_id] = event_data
	out["events"] = events
	return out

func _apply_graphics_to_event(event_node: Node, graphics: Dictionary) -> void:
	var texture_path := str(graphics.get("texture", "")).strip_edges()
	var hframes := maxi(1, int(graphics.get("hframes", 1)))
	var vframes := maxi(1, int(graphics.get("vframes", 1)))
	var total := maxi(1, hframes * vframes)
	var frame := clampi(int(graphics.get("frame", 0)), 0, total - 1)
	var offset_x := float(graphics.get("offset_x", 0.0))
	var offset_y := float(graphics.get("offset_y", 0.0))
	var offset := Vector2(offset_x, offset_y)
	var offset_value = graphics.get("offset", null)
	if offset_value is Vector2:
		offset = offset_value
	elif offset_value is Dictionary:
		var od := offset_value as Dictionary
		offset = Vector2(float(od.get("x", offset_x)), float(od.get("y", offset_y)))

	var sprite_node: Node = null
	if event_node.has_node("Sprite2D"):
		sprite_node = event_node.get_node("Sprite2D")
	elif event_node.has_node("Sprite3D"):
		sprite_node = event_node.get_node("Sprite3D")
	else:
		var exported = event_node.get("sprite")
		if exported is Node:
			sprite_node = exported
	if sprite_node == null:
		return

	var tex: Texture2D = null
	if texture_path != "":
		var loaded = load(texture_path)
		if loaded is Texture2D:
			tex = loaded

	if sprite_node is Sprite2D:
		var s2d := sprite_node as Sprite2D
		s2d.texture = tex
		s2d.visible = tex != null
		s2d.hframes = hframes
		s2d.vframes = vframes
		s2d.frame = frame
		s2d.offset = offset
	elif sprite_node is Sprite3D:
		var s3d := sprite_node as Sprite3D
		s3d.texture = tex
		s3d.visible = tex != null
		s3d.hframes = hframes
		s3d.vframes = vframes
		s3d.frame = frame
		if s3d.has_method("set_offset"):
			s3d.offset = offset

func _apply_initial_graphics_from_map_data() -> void:
	var map_data := get_map_data()
	if typeof(map_data) != TYPE_DICTIONARY:
		return
	var events := _session.get_event_list()
	for ev in events:
		if not (ev is Node):
			continue
		var event_node := ev as Node
		var event_id := str(event_node.get("id")).strip_edges()
		if event_id == "":
			continue
		var graphics := _resolve_event_graphics_from_map_data(map_data, event_id)
		if not graphics.is_empty():
			_apply_graphics_to_event(event_node, graphics)

func _resolve_event_graphics_from_map_data(map_data: Dictionary, event_id: String) -> Dictionary:
	var graph := EventGraphRuntime.new(map_data, event_id)
	var state_id := _state_selector.select_initial_state(graph, _preview_state_ctx, event_id)
	if state_id == "":
		state_id = graph.get_start_node_id()
	if state_id == "":
		return {}
	var state_node := graph.get_node(state_id)
	if state_node.is_empty():
		return {}
	var params = state_node.get("params", {})
	if typeof(params) != TYPE_DICTIONARY:
		return {}
	var properties = params.get("properties", {})
	if typeof(properties) != TYPE_DICTIONARY:
		return {}
	var graphics = properties.get("graphics", {})
	if typeof(graphics) != TYPE_DICTIONARY:
		return {}
	return (graphics as Dictionary).duplicate(true)
