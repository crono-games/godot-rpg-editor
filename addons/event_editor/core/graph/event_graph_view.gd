@tool
extends GraphEdit
class_name EventGraph

signal node_move_ended(node_id: String, new_pos: Vector2)
signal connection_delete_requested(
	from_node: String,
	from_port: int,
	to_node: String,
	to_port: int
)

var _moving_nodes := {}
var event_manager: EventEditorManager = null
var _last_popup_from_connection := false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_last_popup_from_connection = false
		var last_popup_position = get_local_mouse_position()
		emit_signal("popup_request", last_popup_position)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_track_selected_nodes()
			else:
				_emit_moved_nodes()
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_DELETE:
			_try_delete_connection()

func create_graph_node(node_data: NodeData) -> EventCommandNode:
	var scene := EventNodeRegistry.get_scene_for_type(node_data.type)
	if scene:
		var ev_command_node: EventCommandNode = scene.instantiate()
		ev_command_node.name = node_data.id
		ev_command_node.position_offset = node_data.position
		ev_command_node.bind_data(node_data, node_data.id)
		if event_manager != null and ev_command_node.has_method("bind_event_manager"):
			ev_command_node.bind_event_manager(event_manager)
		add_child(ev_command_node)
		return ev_command_node
	return null

func _emit_moved_nodes():
	for child in get_children():
		if not (child is GraphElement):
			continue

		if not _moving_nodes.has(child.name):
			continue

		var old_pos = _moving_nodes[child.name]
		var new_pos = child.position_offset

		if old_pos != new_pos:
			emit_signal("node_move_ended", child.name, new_pos)

	_moving_nodes.clear()


func _track_selected_nodes():
	_moving_nodes.clear()

	for child in get_children():
		if child is GraphElement and child.selected:
			_moving_nodes[child.name] = child.position_offset

func _try_delete_connection():
	var pos := get_local_mouse_position()
	var conn := get_closest_connection_at_point(pos)
	if conn.is_empty():
		return
	emit_signal("connection_delete_requested", conn.from_node, conn.from_port, conn.to_node, conn.to_port)

func _on_connection_to_empty(from_node: StringName, from_port: int, release_position: Vector2) -> void:
	_last_popup_from_connection = true
	emit_signal("popup_request", release_position)

func get_mouse_position_in_graph() -> Vector2:
	var local := get_local_mouse_position()
	return get_graph_position_from_local(local)

func get_graph_position_from_local(local_pos: Vector2) -> Vector2:
	return (local_pos + scroll_offset) / zoom

func get_selected_node_ids() -> Array[String]:
	var out: Array[String] = []
	for child in get_children():
		if child is GraphElement and child.selected:
			out.append(str(child.name))
	return out

func was_last_popup_from_connection() -> bool:
	return _last_popup_from_connection
