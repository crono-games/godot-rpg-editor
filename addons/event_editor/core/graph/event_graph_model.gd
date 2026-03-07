class_name EventGraphModel
extends RefCounted

# ================================
# Dependencies
# ================================

var _id_generator: GraphIdGenerator

# ================================
# State
# ================================

var _nodes :Dictionary[String, NodeData]= {}   # node_id -> NodeData
var _edges : Array[EdgeData]= []   # Array[EdgeData]

var version := 1

# ================================
# Lifecycle
# ================================

func _init(id_generator: GraphIdGenerator):
	_id_generator = id_generator

func add_node(node: NodeData) -> void:
	#assert(not _nodes.has(node.id))
	var key := str(node.id)
	node.id = key
	_nodes[key] = node

func duplicate_node(source_id, offset: Vector2) -> String:
	var src_key := str(source_id)
	assert(_nodes.has(src_key))

	var src = _nodes[src_key]
	if _id_generator == null:
		_id_generator = GraphIdGenerator.new()
		_id_generator.reset_from_model(self)
	var new_id := _id_generator.next_unique_node_id(src.type, self)

	var node := NodeData.new(
		new_id,
		src.type,
		src.position + offset
	)
	node.params = src.params.duplicate(true)

	_nodes[new_id] = node
	return new_id

func move_node(id, new_pos: Vector2) -> void:
	var key := str(id)
	assert(_nodes.has(key))
	_nodes[key].position = new_pos

func remove_node(id) -> void:
	var key := str(id)
	if not _nodes.has(key):
		return

	for i in range(_edges.size() - 1, -1, -1):
		var e = _edges[i]
		if e.from_node == key or e.to_node == key:
			_edges.remove_at(i)

	_nodes.erase(key)

func add_edge(from, from_port, to, to_port) -> void:
	_edges.append(EdgeData.new(str(from), from_port, str(to), to_port))

func remove_edge(from_node, from_port, to_node, to_port) -> void:
	var f_key := str(from_node)
	var t_key := str(to_node)
	for i in range(_edges.size() - 1, -1, -1):
		var e = _edges[i]
		if e.from_node == f_key \
		and e.from_port == from_port \
		and e.to_node == t_key \
		and e.to_port == to_port:
			_edges.remove_at(i)
			return

func clear() -> void:
	_nodes.clear()
	_edges.clear()


# ==================================================
# Helpers
# ==================================================

func has_node(id) -> bool:
	return _nodes.has(str(id))

func get_node(id) -> NodeData:
	var key := str(id)
	return _nodes.get(key, null)

func get_node_list() -> Array[NodeData]:
	return _nodes.values()

func get_node_ids() -> Array:
	return _nodes.keys()

func get_nodes() -> Dictionary: #DEBUG
	return _nodes.duplicate()

func get_edges() -> Array:
	return _edges.duplicate()

func get_edges_for_node(node_id) -> Array[EdgeData]:
	var key := str(node_id)
	var result: Array[EdgeData] = []

	for edge in _edges:
		if edge.from_node == key:
			result.append(edge)

	return result

func get_first_edge(node_id) -> EdgeData:
	var key := str(node_id)
	for edge in _edges:
		if edge.from_node == key:
			return edge
	return null

func get_incoming_edges(node_id) -> Array[EdgeData]:
	var key := str(node_id)
	var result: Array[EdgeData] = []
	for e in _edges:
		if e.to_node == key:
			result.append(e)
	return result

func has_outgoing(node_id) -> bool:
	return get_first_edge(node_id) != null
