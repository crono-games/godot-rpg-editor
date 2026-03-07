class_name GraphEditService
extends RefCounted

var _model: EventGraphModel
var _view: EventGraph
var _undo_redo: UndoRedo
var _connection_policy: GraphConnectionPolicy

func _init(model: EventGraphModel, view: EventGraph, undo_redo: UndoRedo, connection_policy: GraphConnectionPolicy) -> void:
	_model = model
	_view = view
	_undo_redo = undo_redo
	_connection_policy = connection_policy

func create_node(
	type: String,
	position: Vector2,
	id_generator: GraphIdGenerator,
	build_state_params: Callable,
	on_node_created: Callable,
	mark_dirty: Callable
) -> void:
	var id := id_generator.next_unique_node_id(type, _model)
	var node := NodeData.new(id, type, position)
	if type == "state":
		node.params = build_state_params.call(id)

	_undo_redo.create_action("Create Node")
	_undo_redo.add_do_method(func():
		_model.add_node(node)
		on_node_created.call(node.id)
		mark_dirty.call()
	)
	_undo_redo.add_undo_method(func():
		for e in _model.get_edges_for_node(id):
			_model.remove_edge(e.from_node, e.from_port, e.to_node, e.to_port)
			_view.disconnect_node(e.from_node, e.from_port, e.to_node, e.to_port)
		_model.remove_node(id)
		mark_dirty.call()
	)
	_undo_redo.commit_action()

func delete_nodes(
	node_ids: Array,
	is_default_state_node: Callable,
	snapshot_node: Callable,
	restore_node: Callable,
	on_node_removed: Callable,
	on_node_created: Callable,
	mark_dirty: Callable
) -> void:
	var deletable_ids := []
	for id in node_ids:
		if is_default_state_node.call(id):
			continue
		deletable_ids.append(id)
	if deletable_ids.is_empty():
		return

	var snapshots := []
	for id in deletable_ids:
		if _model.has_node(id):
			var snap = snapshot_node.call(id)
			if not snap.is_empty():
				snapshots.append(snap)
	var edge_snapshots := _snapshot_edges_for_nodes(deletable_ids)

	_undo_redo.create_action("Delete nodes")
	for id in deletable_ids:
		_undo_redo.add_do_method(func():
			_model.remove_node(id)
			on_node_removed.call(id)
		)

	for snap in snapshots:
		_undo_redo.add_undo_method(func():
			restore_node.call(snap)
			on_node_created.call(snap.id)
		)
	for e in edge_snapshots:
		_undo_redo.add_undo_method(func():
			if not _model.has_node(e.from_node) or not _model.has_node(e.to_node):
				return
			_model.add_edge(e.from_node, e.from_port, e.to_node, e.to_port)
			_view.connect_node(e.from_node, e.from_port, e.to_node, e.to_port)
		)

	_undo_redo.add_do_method(mark_dirty)
	_undo_redo.add_undo_method(mark_dirty)
	_undo_redo.commit_action()

func duplicate_nodes(
	node_ids: Array,
	on_node_created: Callable,
	on_node_removed: Callable,
	mark_dirty: Callable
) -> void:
	_undo_redo.create_action("Duplicate nodes")
	for id in node_ids:
		if not _model.has_node(id):
			continue
		var created_id := ""
		_undo_redo.add_do_method(func():
			created_id = _model.duplicate_node(id, Vector2(40, 40))
			_normalize_duplicated_node(created_id)
			on_node_created.call(created_id)
		)
		_undo_redo.add_undo_method(func():
			on_node_removed.call(created_id)
			_model.remove_node(created_id)
		)
	_undo_redo.add_do_method(mark_dirty)
	_undo_redo.add_undo_method(mark_dirty)
	_undo_redo.commit_action()

func move_node(
	node_id: String,
	new_pos: Vector2,
	is_building: bool,
	mark_dirty: Callable,
	apply_view_position: Callable
) -> void:
	if is_building:
		return
	var data := _model.get_node(node_id)
	if data == null:
		return
	var before := data.position
	var after := new_pos
	if before == after:
		return

	_undo_redo.create_action("Move node", UndoRedo.MERGE_ENDS)
	_undo_redo.add_do_method(func():
		_model.move_node(node_id, after)
		if apply_view_position != null:
			apply_view_position.call(node_id, after)
	)
	_undo_redo.add_undo_method(func():
		_model.move_node(node_id, before)
		if apply_view_position != null:
			apply_view_position.call(node_id, before)
	)
	_undo_redo.add_do_method(mark_dirty)
	_undo_redo.add_undo_method(mark_dirty)
	_undo_redo.commit_action()

func connect_nodes(
	from_id: String,
	from_port: int,
	to_id: String,
	to_port: int,
	mark_dirty: Callable
) -> void:
	if not _connection_policy.can_connect(_model, from_id, from_port, to_id, to_port):
		return
	# Keep one incoming edge per input port: replace previous edge on this input.
	for incoming in _model.get_incoming_edges(to_id):
		if int(incoming.to_port) != int(to_port):
			continue
		_model.remove_edge(incoming.from_node, incoming.from_port, incoming.to_node, incoming.to_port)
		_view.disconnect_node(incoming.from_node, incoming.from_port, incoming.to_node, incoming.to_port)
	_model.add_edge(from_id, from_port, to_id, to_port)
	_view.connect_node(from_id, from_port, to_id, to_port)
	mark_dirty.call()

func disconnect_nodes(
	from_id: String,
	from_port: int,
	to_id: String,
	to_port: int,
	mark_dirty: Callable
) -> void:
	_undo_redo.create_action("Delete connection")
	_undo_redo.add_do_method(_model.remove_edge.bind(from_id, from_port, to_id, to_port))
	_undo_redo.add_do_method(_view.disconnect_node.bind(from_id, from_port, to_id, to_port))
	_undo_redo.add_undo_method(_model.add_edge.bind(from_id, from_port, to_id, to_port))
	_undo_redo.add_undo_method(_view.connect_node.bind(from_id, from_port, to_id, to_port))
	_undo_redo.add_do_method(mark_dirty)
	_undo_redo.add_undo_method(mark_dirty)
	_undo_redo.commit_action()

func _snapshot_edges_for_nodes(node_ids: Array) -> Array:
	var keep := {}
	for id in node_ids:
		keep[str(id)] = true

	var out := []
	var seen := {}
	for e in _model.get_edges():
		var from_id := str(e.from_node)
		var to_id := str(e.to_node)
		if not keep.has(from_id) and not keep.has(to_id):
			continue
		var key := "%s:%d>%s:%d" % [from_id, int(e.from_port), to_id, int(e.to_port)]
		if seen.has(key):
			continue
		seen[key] = true
		out.append({
			"from_node": from_id,
			"from_port": int(e.from_port),
			"to_node": to_id,
			"to_port": int(e.to_port)
		})
	return out

func _normalize_duplicated_node(node_id: String) -> void:
	var node := _model.get_node(node_id)
	if node == null:
		return
	if str(node.type) != "state":
		return
	if not bool(node.params.get("is_default", false)):
		return
	node.params = node.params.duplicate(true)
	node.params["is_default"] = false
	node.params["state_id"] = str(node_id)
	var base_name := str(node.params.get("name", "State"))
	if not base_name.ends_with(" (Copy)"):
		node.params["name"] = "%s (Copy)" % base_name

func paste_nodes(
	clipboard_nodes: Array,
	clipboard_edges: Array,
	paste_origin: Vector2,
	id_generator: GraphIdGenerator,
	normalize_pasted_node: Callable,
	on_node_created: Callable,
	on_node_removed: Callable,
	clear_selection: Callable,
	select_node: Callable,
	mark_dirty: Callable
) -> void:
	if clipboard_nodes.is_empty():
		return
	if id_generator == null:
		return

	var created_ids: Array[String] = []
	var id_map: Dictionary = {}
	_undo_redo.create_action("Paste nodes")
	_undo_redo.add_do_method(func():
		if clear_selection != null:
			clear_selection.call()
		created_ids.clear()
		id_map.clear()

		for item in clipboard_nodes:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var row := item as Dictionary
			var node_type := str(row.get("type", ""))
			if node_type == "":
				continue
			var new_id := id_generator.next_unique_node_id(node_type, _model)
			var offset := row.get("offset", Vector2.ZERO)
			var node := NodeData.new(new_id, node_type, paste_origin + offset)
			var params_value = row.get("params", {})
			node.params = params_value.duplicate(true) if typeof(params_value) == TYPE_DICTIONARY else {}
			if normalize_pasted_node != null:
				normalize_pasted_node.call(node)
			_model.add_node(node)
			id_map[str(row.get("source_id", ""))] = new_id
			created_ids.append(new_id)
			on_node_created.call(new_id)

		for e in clipboard_edges:
			if typeof(e) != TYPE_DICTIONARY:
				continue
			var edge := e as Dictionary
			var from_id := str(id_map.get(str(edge.get("from_node", "")), ""))
			var to_id := str(id_map.get(str(edge.get("to_node", "")), ""))
			if from_id == "" or to_id == "":
				continue
			var from_port := int(edge.get("from_port", 0))
			var to_port := int(edge.get("to_port", 0))
			_model.add_edge(from_id, from_port, to_id, to_port)
			_view.connect_node(from_id, from_port, to_id, to_port)

		if select_node != null:
			for new_id in created_ids:
				select_node.call(new_id)

		mark_dirty.call()
	)
	_undo_redo.add_undo_method(func():
		for new_id in created_ids:
			on_node_removed.call(new_id)
			_model.remove_node(new_id)
		mark_dirty.call()
	)
	_undo_redo.commit_action()
