class_name GraphSynchronizer
extends RefCounted

var _model: EventGraphModel
var _event_graph: EventGraph
var _graph_nodes := {}
var _is_building := false

class PendingConnection:
	var from_node: String
	var from_port: int
	var release_pos: Vector2
	func _init(f, fp, pos):
		from_node = f
		from_port = fp
		release_pos = pos

var _pending_connection: PendingConnection = null

func _init(model: EventGraphModel, event_graph: EventGraph) -> void:
	_model = model
	_event_graph = event_graph

func rebuild() -> void:
	_is_building = true
	_clear_view()
	_graph_nodes.clear()

	for id in _model.get_node_ids():
		_on_node_created_internal(id)

	for e in _model.get_edges():
		_event_graph.connect_node(e.from_node, e.from_port, e.to_node, e.to_port)

	_is_building = false

func _clear_view() -> void:
	_event_graph.clear_connections()
	var to_remove := []
	for c in _event_graph.get_children():
		if c is GraphElement:
			to_remove.append(c)
	for c in to_remove:
		if c.get_parent() == _event_graph:
			_event_graph.remove_child(c)
		c.free()

func on_node_created(node_id: String) -> EventCommandNode:
	## Creates the node view and stores it
	return _on_node_created_internal(node_id)

func _on_node_created_internal(node_id: String) -> EventCommandNode:
	var data := _model.get_node(node_id)

	var _graph_node := _event_graph.create_graph_node(data)
	_graph_nodes[node_id] = _graph_node

	## Handle pending connection if exists
	if _pending_connection:
		var from = str(_pending_connection.from_node)
		var from_port = _pending_connection.from_port

		if not _model.has_node(from):
			_pending_connection = null
		else:
			if _model.has_node(node_id) and _model.has_node(from):
				## try connect from -> node at port 0
				_model.add_edge(from, from_port, node_id, 0)
				_event_graph.connect_node(from, from_port, node_id, 0)
			_pending_connection = null

	return _graph_node

func on_node_removed(node_id: String) -> void:
	if not _graph_nodes.has(node_id):
		return

	var node_view = _graph_nodes[node_id]
	if node_view != null:
		if node_view.get_parent() == _event_graph:
			_event_graph.remove_child(node_view)
		node_view.free()
	_graph_nodes.erase(node_id)

	if _pending_connection and str(_pending_connection.from_node) == str(node_id):
		_pending_connection = null

func get_node_view(node_id: String) -> EventCommandNode:
	return _graph_nodes.get(node_id, null)

func resolve_node_id(node_ref) -> String:
	if node_ref is String:
		return node_ref
	if node_ref is StringName:
		return str(node_ref)
	if node_ref is Node:
		for id in _graph_nodes.keys():
			if _graph_nodes[id] == node_ref:
				return id
		return node_ref.name
	return str(node_ref)

func sync_view_positions_to_model() -> bool:
	var changed := false
	for id in _graph_nodes.keys():
		var view = _graph_nodes.get(id, null)
		if view == null:
			continue
		var model_node := _model.get_node(id)
		if model_node == null:
			continue
		var pos = view.position_offset
		if model_node.position != pos:
			_model.move_node(id, pos)
			changed = true
	return changed

func set_pending_connection(from_node: String, from_port: int, release_pos: Vector2) -> void:
	_pending_connection = PendingConnection.new(from_node, from_port, release_pos)

func clear_pending_connection() -> void:
	_pending_connection = null
