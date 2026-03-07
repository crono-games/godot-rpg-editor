@tool
extends Node
class_name GraphController
# Central coordinator for graph editing:
# owns model/view sync, graph persistence and state-node conventions.

# ================================
# Dependencies (composition root)
# ================================

signal graph_dirty
signal state_properties_updated(event_id: String, state_id: String, params: Dictionary)

var _event_editor_manager: EventEditorManager
var _graph_model: EventGraphModel
var _connection_policy: GraphConnectionPolicy
var _persistence_service: GraphPersistenceService
var _scene_root_provider: Callable

# ================================
# UI References
# ================================

@export var view: EventGraph
@export var context_menu_panel: ContextMenuPanel

var _id_generator: GraphIdGenerator
var _undo_redo : UndoRedo

## Graph-specific id generator — inject from composition root using `set_id_generator()`.

# ================================
# Internal State
# ================================

var _is_building := false
var _synchronizer: GraphSynchronizer
var _edit_service: GraphEditService
var _current_event_id := ""
var _dirty := false
var _last_popup_graph_position := Vector2.ZERO
var _has_popup_graph_position := false
var _clipboard_nodes: Array = []
var _clipboard_edges: Array = []
var _clipboard_anchor := Vector2.ZERO
var _graph_shortcuts_bound := false

# ================================
# Lifecycle
# ================================

func _enter_tree():
	if _undo_redo == null:
		_undo_redo = UndoRedo.new()

	if _graph_model == null:
		_graph_model = EventGraphModel.new(_id_generator)

	if _connection_policy == null:
		_connection_policy = DefaultGraphConnectionPolicy.new()

	if _persistence_service == null:
		_persistence_service = GraphPersistenceService.new()

	if _synchronizer == null:
		_synchronizer = GraphSynchronizer.new(_graph_model, view)
	if _edit_service == null:
		_rebuild_edit_service()
	_bind_graph_shortcut_signals()

func set_context(context: EventEditorManager) -> void:
	if _event_editor_manager != null and _event_editor_manager.active_event_changed.is_connected(_on_event_selected):
		_event_editor_manager.active_event_changed.disconnect(_on_event_selected)
	_event_editor_manager = context
	context.active_event_changed.connect(_on_event_selected)

	if view != null:
		view.event_manager = _event_editor_manager

#func sync_with_event_editor_manager_selection() -> void:
	#if _event_editor_manager.active_event_id == "":
		#return
	#_on_event_selected(_event_editor_manager.active_event_id)

func set_scene_root_provider(provider: Callable) -> void:
	_scene_root_provider = provider

	# Dependency-injection helpers (can be used before _enter_tree)
func set_id_generator(gen: GraphIdGenerator) -> void:
	_id_generator = gen

func set_persistence_service(ps: GraphPersistenceService) -> void:
	_persistence_service = ps

func set_connection_policy(policy: GraphConnectionPolicy) -> void:
	_connection_policy = policy
	_rebuild_edit_service()

func set_undo_redo(ur: UndoRedo) -> void:
	_undo_redo = ur
	_rebuild_edit_service()

func _rebuild_edit_service() -> void:
	if _graph_model == null or view == null or _undo_redo == null or _connection_policy == null:
		return
	_edit_service = GraphEditService.new(_graph_model, view, _undo_redo, _connection_policy)

# ==================================================
# API (user intentions)
# ==================================================


func _on_request_create_node(type: String) -> void:
	var pos := _last_popup_graph_position if _has_popup_graph_position else view.get_mouse_position_in_graph()
	_has_popup_graph_position = false
	_ensure_id_generator_ready()
	_edit_service.create_node(
		type,
		pos,
		_id_generator,
		Callable(self, "_build_state_params_for_new_node"),
		_on_node_created,
		_mark_dirty
	)

func _on_request_delete_nodes(node_ids: Array = []) -> void:
	var ids := _coerce_node_id_array(node_ids)
	if ids.is_empty() and view != null:
		ids = view.get_selected_node_ids()
	_edit_service.delete_nodes(
		ids,
		_is_default_state_node,
		_snapshot_node,
		_restore_node,
		_on_node_removed,
		_on_node_created,
		_mark_dirty
	)


func _on_request_duplicate_nodes(node_ids: Array = []) -> void:
	var ids := _coerce_node_id_array(node_ids)
	if ids.is_empty() and view != null:
		ids = view.get_selected_node_ids()
	_ensure_id_generator_ready()
	_edit_service.duplicate_nodes(
		ids,
		_on_node_created,
		_on_node_removed,
		_mark_dirty
	)


func _on_node_moved(node_id: String, new_pos: Vector2) -> void:
	_edit_service.move_node(
		node_id,
		new_pos,
		_is_building,
		_mark_dirty,
		Callable(self, "_apply_node_view_position")
	)


func _on_connection_to_empty(from_node: StringName, from_port: int, release_position: Vector2) -> void:
	# Delegate pending connection storage to the synchronizer
	if _synchronizer != null:
		_synchronizer.set_pending_connection(_normalize_node_id(from_node), from_port, release_position)

func _on_request_connect(from_node, from_port, to_node, to_port) -> void:
	var from_id := _normalize_node_id(from_node)
	var to_id := _normalize_node_id(to_node)
	_edit_service.connect_nodes(from_id, from_port, to_id, to_port, _mark_dirty)


func _on_connection_delete_requested(from_node, from_port, to_node, to_port) -> void:
	var from_id := _normalize_node_id(from_node)
	var to_id := _normalize_node_id(to_node)
	_edit_service.disconnect_nodes(from_id, from_port, to_id, to_port, _mark_dirty)


func _snapshot_node(node_id: String) -> Dictionary:
	var data := _graph_model.get_node(node_id)
	if data == null:
		return {}

	return {
		"id": data.id,
		"type": data.type,
		"position": data.position,
		"params": data.params.duplicate(true)
	}

func _restore_node(snapshot: Dictionary) -> void:
	var node := NodeData.new(
		snapshot.id,
		snapshot.type,
		snapshot.position
	)
	node.params = snapshot.params.duplicate(true)
	_graph_model.add_node(node)


# ==================================================
# Model -> View synchronization
# ==================================================

func _on_node_created(node_id: String) -> void:
	if _synchronizer == null or _graph_model == null:
		return
	var data := _graph_model.get_node(node_id)
	if data == null:
		return
	var node_view := _synchronizer.on_node_created(node_id)
	_bind_node_view_with_data(node_view, data)


func _on_node_request_apply(ev_command_node: EventCommandNode) -> void:
	var node_id := ev_command_node.get_node_id()
	var data := _graph_model.get_node(node_id)

	var before := data.params.duplicate(true)
	var after := ev_command_node.export_params()
	_undo_redo.create_action("Edit Node")

	_undo_redo.add_do_method(
		_apply_node_params.bind(node_id, after)
	)

	_undo_redo.add_undo_method(
		_apply_node_params.bind(node_id, before)
	)

	_undo_redo.commit_action()


func _apply_node_params(node_id: String, params: Dictionary) -> void:
	var data := _graph_model.get_node(node_id)
	data.params = params.duplicate(true)

	var event_command_node = _synchronizer.get_node_view(node_id)
	if event_command_node != null:
		event_command_node.import_params(data.params)

	if data.type == "state" and _event_editor_manager != null:
		var state_id := str(data.params.get("state_id", node_id))
		emit_signal("state_properties_updated", _event_editor_manager.active_event_id, state_id, data.params.duplicate(true))

	_mark_dirty()
	_update_states_in_event_editor_manager()

func _normalize_node_id(node_ref) -> String:
	if _synchronizer != null:
		return _synchronizer.resolve_node_id(node_ref)
	return str(node_ref)

func _is_default_state_node(node_id: String) -> bool:
	var data := _graph_model.get_node(node_id)
	return data != null and data.type == "state" and data.params.get("is_default", false)

func _on_node_removed(node_id: String) -> void:
	# Delegate removal to the synchronizer
	_synchronizer.on_node_removed(node_id)

# ==================================================
# Build / Rebuild
# ==================================================

func _on_event_selected(event_id: String) -> void:
	if _event_editor_manager == null:
		return
	if _persistence_service == null:
		return
	_load_selected_event_graph(event_id, _event_editor_manager.active_map_id)

func reload_graph(event_id):
	_load_selected_event_graph(event_id, _event_editor_manager.active_map_id)


func rebuild() -> void:
	_is_building = true
	# Delegate rebuild to the synchronizer
	_synchronizer.rebuild()
	_bind_node_views_after_rebuild()
	_update_states_in_event_editor_manager()
	_is_building = false

func _bind_node_views_after_rebuild() -> void:
	if _graph_model == null or _synchronizer == null:
		return
	for node_id in _graph_model.get_node_ids():
		var data := _graph_model.get_node(node_id)
		if data == null:
			continue
		var node_view := _synchronizer.get_node_view(node_id)
		if node_view == null:
			continue
		_bind_node_view_with_data(node_view, data)


func _clear_view() -> void:
	# moved to GraphSynchronizer
	pass

# ==================================================
# UI / Popups
# ==================================================


func popup_request(at_position: Vector2) -> void:
	if context_menu_panel == null:
		return
	if _synchronizer != null and view != null and view.has_method("was_last_popup_from_connection"):
		var from_connection := bool(view.call("was_last_popup_from_connection"))
		# Clear stale pending links when opening context menu manually.
		if not from_connection:
			_synchronizer.clear_pending_connection()
	if view == null:
		context_menu_panel.position = at_position
		context_menu_panel.popup()
		return

	_last_popup_graph_position = view.get_graph_position_from_local(at_position)
	_has_popup_graph_position = true

	var parent_item := context_menu_panel.get_parent() as CanvasItem
	if parent_item != null:
		var view_global := view.get_global_transform_with_canvas() * at_position
		var parent_local := parent_item.get_global_transform_with_canvas().affine_inverse() * view_global
		context_menu_panel.position = parent_local
	else:
		context_menu_panel.position = at_position
	context_menu_panel.popup()

# ==================================================
# Undo / Redo
# ==================================================


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_undo"):
		if _undo_redo.has_undo():
			_undo_redo.undo()
			get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_redo"):
		if _undo_redo.has_redo():
			_undo_redo.redo()
			get_viewport().set_input_as_handled()


func undo():
	_undo_redo.undo()

func redo():
	_undo_redo.redo()

func _post_load_graph() -> void:
	_ensure_id_generator_ready()
	var changed := _ensure_default_state_node(_id_generator)
	_ensure_state_labels()
	if changed:
		_dirty = true
	_update_states_in_event_editor_manager()
	if _id_generator != null:
		_id_generator.reset_from_model(_graph_model)

func get_selected_node_snapshot() -> Dictionary:
	if view == null or _graph_model == null:
		return {}
	var selected := view.get_selected_node_ids()
	if selected.is_empty():
		return {}
	var node_id := str(selected[0])
	var data := _graph_model.get_node(node_id)
	if data == null:
		return {}
	return {
		"id": node_id,
		"type": str(data.type),
		"params": data.params.duplicate(true)
	}

func _save_current_graph() -> void:
	if _event_editor_manager == null:
		return
	if _persistence_service == null:
		return
	if not _should_save_current():
		return
	_save_event_graph(_current_event_id, _event_editor_manager.active_map_id)

func save_current_graph() -> void:
	_save_current_graph()

func _mark_dirty() -> void:
	_dirty = true
	emit_signal("graph_dirty")
	_update_states_in_event_editor_manager()

func _update_states_in_event_editor_manager() -> void:
	if _event_editor_manager == null:
		return
	_event_editor_manager.set_states(_build_state_catalog())

func _sync_view_positions_to_model() -> bool:
	if _synchronizer != null:
		return _synchronizer.sync_view_positions_to_model()
	return false

func _apply_node_view_position(node_id: String, pos: Vector2) -> void:
	if _synchronizer == null:
		return
	var node_view := _synchronizer.get_node_view(node_id)
	if node_view != null:
		node_view.position_offset = pos

func _load_selected_event_graph(next_event_id: String, map_id: String) -> void:
	if next_event_id == "":
		return
	if _should_save_before_loading_event(next_event_id):
		_save_event_graph(_current_event_id, map_id)
	_load_event_graph(next_event_id, map_id)
	_current_event_id = next_event_id
	rebuild()

func _save_event_graph(event_id: String, map_id: String) -> void:
	if map_id == "" or event_id == "":
		return
	var moved := _sync_view_positions_to_model()
	if moved:
		_dirty = true
	if not _should_save_current():
		return
	_persistence_service.save_event(map_id, event_id, _graph_model)
	_dirty = false

func _load_event_graph(event_id: String, map_id: String) -> void:
	_graph_model.clear()
	if map_id == "" or event_id == "":
		return
	_persistence_service.load_event(map_id, event_id, _graph_model)
	_post_load_graph()
	_dirty = false

func _should_save_before_loading_event(next_event_id: String) -> bool:
	if _current_event_id == "":
		return false
	if _current_event_id == next_event_id:
		return false
	return _dirty

func _should_save_current() -> bool:
	if _current_event_id == "":
		return false
	return _dirty

func _bind_node_view_with_data(event_command_node: EventCommandNode, data: NodeData) -> void:
	if event_command_node == null:
		return
	if _scene_root_provider != null and event_command_node.has_method("set_scene_root_provider"):
		event_command_node.set_scene_root_provider(_scene_root_provider)
	if event_command_node.has_method("load_from_data"):
		event_command_node.load_from_data(data)
	if not event_command_node.request_apply.is_connected(_on_node_request_apply):
		event_command_node.request_apply.connect(_on_node_request_apply)

func _build_state_catalog() -> Array:
	if _graph_model == null:
		return []
	var states := []
	for node_id in _graph_model.get_node_ids():
		var node := _graph_model.get_node(node_id)
		if node == null or node.type != "state":
			continue
		var params := node.params
		var state_name := str(params.get("name", ""))
		var state_id := str(params.get("state_id", ""))
		var id_value := state_id if state_id != "" else str(node_id)
		var label := state_name if state_name != "" else id_value
		states.append({
			"id": id_value,
			"label": label
		})
	return states

func _build_state_params_for_new_node(id: String) -> Dictionary:
	var number := _extract_state_number(id)
	var name := "New State %d" % number if number > 0 else "New State"
	return {
		"state_id": id,
		"name": name,
		"trigger_mode": "action"
	}

func _ensure_default_state_node(id_generator: GraphIdGenerator) -> bool:
	var first_state_id := ""
	for node_id in _graph_model.get_node_ids():
		var node := _graph_model.get_node(node_id)
		if node == null or node.type != "state":
			continue
		if node.params.get("is_default", false):
			return false
		if first_state_id == "":
			first_state_id = node_id

	if first_state_id != "":
		var existing := _graph_model.get_node(first_state_id)
		existing.params = existing.params.duplicate(true)
		existing.params["is_default"] = true
		if not existing.params.has("state_id"):
			existing.params["state_id"] = "default"
		if not existing.params.has("name"):
			existing.params["name"] = "Default"
		if not existing.params.has("trigger_mode"):
			existing.params["trigger_mode"] = "action"
		_ensure_state_labels()
		return true

	if id_generator == null:
		return false
	var id := id_generator.next_node_id("state")
	var node := NodeData.new(id, "state", Vector2.ZERO)
	node.params = {
		"is_default": true,
		"state_id": "default",
		"name": "Default",
		"trigger_mode": "action"
	}
	_graph_model.add_node(node)
	return true

func _ensure_state_labels() -> void:
	var counter := 1
	for node_id in _graph_model.get_node_ids():
		var node := _graph_model.get_node(node_id)
		if node == null or node.type != "state":
			continue
		var params := node.params.duplicate(true)
		var changed := false
		if not params.has("state_id") or str(params.get("state_id", "")) == "":
			params["state_id"] = str(node_id)
			changed = true
		if not params.has("name") or str(params.get("name", "")) == "":
			params["name"] = "New State %d" % counter
			changed = true
		counter += 1
		if not changed:
			continue
		node.params = params
		var node_view := _synchronizer.get_node_view(node_id)
		if node_view != null and node_view.view_model != null:
			node_view.view_model.import_params(node.params)

func _extract_state_number(id: String) -> int:
	var parts := id.split("_")
	if parts.size() >= 2 and parts[0] == "state":
		return int(parts[1])
	return 0

func _copy_selected_nodes_to_clipboard() -> void:
	if view == null or _graph_model == null:
		return
	
	var selected_ids := view.get_selected_node_ids()
	if selected_ids.is_empty():
		return
	_clipboard_nodes.clear()
	_clipboard_edges.clear()
	_clipboard_anchor = Vector2.ZERO

	var id_set := {}
	var sum := Vector2.ZERO
	var count := 0
	for node_id in selected_ids:
		var data := _graph_model.get_node(node_id)
		if data == null:
			continue
		id_set[str(node_id)] = true
		sum += data.position
		count += 1
	if count == 0:
		return
	_clipboard_anchor = sum / float(count)
	for node_id in selected_ids:
		var data := _graph_model.get_node(node_id)
		if data == null:
			continue
		_clipboard_nodes.append({
			"source_id": str(node_id),
			"type": str(data.type),
			"params": data.params.duplicate(true),
			"offset": data.position - _clipboard_anchor
		})

	for edge in _graph_model.get_edges():
		var from_id := str(edge.from_node)
		var to_id := str(edge.to_node)
		if not id_set.has(from_id) or not id_set.has(to_id):
			continue
		_clipboard_edges.append({
			"from_node": from_id,
			"from_port": int(edge.from_port),
			"to_node": to_id,
			"to_port": int(edge.to_port)
		})

func _paste_nodes_from_clipboard() -> void:
	if _clipboard_nodes.is_empty():
		return
	if _graph_model == null or _undo_redo == null or _edit_service == null:
		return
	_ensure_id_generator_ready()

	var paste_origin := _clipboard_anchor + Vector2(40, 40)
	if view != null:
		paste_origin = view.get_mouse_position_in_graph()
	_edit_service.paste_nodes(
		_clipboard_nodes,
		_clipboard_edges,
		paste_origin,
		_id_generator,
		Callable(self, "_normalize_pasted_node"),
		Callable(self, "_on_node_created"),
		Callable(self, "_on_node_removed"),
		Callable(self, "_clear_node_selection"),
		Callable(self, "_select_node_view"),
		Callable(self, "_mark_dirty")
	)

func _clear_node_selection() -> void:
	if view == null:
		return
	for child in view.get_children():
		if child is GraphElement:
			(child as GraphElement).selected = false

func _select_node_view(node_id: String) -> void:
	if _synchronizer == null:
		return
	var node_view := _synchronizer.get_node_view(node_id)
	if node_view != null:
		node_view.selected = true

func _normalize_pasted_node(node: NodeData) -> void:
	if node == null:
		return
	if str(node.type) != "state":
		return
	if not bool(node.params.get("is_default", false)):
		return
	node.params["is_default"] = false
	node.params["state_id"] = str(node.id)
	var state_name := str(node.params.get("name", "State"))
	if not state_name.ends_with(" (Copy)"):
		node.params["name"] = "%s (Copy)" % state_name

func _bind_graph_shortcut_signals() -> void:
	if _graph_shortcuts_bound or view == null:
		return
	_graph_shortcuts_bound = true

	if view.has_signal("copy_nodes_request") and not view.is_connected("copy_nodes_request", Callable(self, "_on_copy_nodes_request")):
		view.connect("copy_nodes_request", Callable(self, "_on_copy_nodes_request"))
	if view.has_signal("paste_nodes_request") and not view.is_connected("paste_nodes_request", Callable(self, "_on_paste_nodes_request")):
		view.connect("paste_nodes_request", Callable(self, "_on_paste_nodes_request"))
	if view.has_signal("cut_nodes_request") and not view.is_connected("cut_nodes_request", Callable(self, "_on_cut_nodes_request")):
		view.connect("cut_nodes_request", Callable(self, "_on_cut_nodes_request"))

func _on_copy_nodes_request() -> void:
	_copy_selected_nodes_to_clipboard()

func _on_paste_nodes_request() -> void:
	_paste_nodes_from_clipboard()

func _on_cut_nodes_request() -> void:
	_copy_selected_nodes_to_clipboard()
	_on_request_delete_nodes()

func _coerce_node_id_array(value) -> Array:
	var out: Array = []
	if value is Array:
		for id in value:
			out.append(str(id))
	elif value is PackedStringArray:
		for id in value:
			out.append(str(id))
	elif value is String:
		out.append(str(value))
	return out

func _ensure_id_generator_ready() -> void:
	if _graph_model == null:
		return
	if _id_generator == null:
		_id_generator = GraphIdGenerator.new()
	_id_generator.reset_from_model(_graph_model)
