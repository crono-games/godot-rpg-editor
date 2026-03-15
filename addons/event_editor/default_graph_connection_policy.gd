class_name DefaultGraphConnectionPolicy
extends GraphConnectionPolicy

func can_connect(graph, from, from_port, to, to_port = 0) -> bool:
	if from == to:
		return false

	if not graph.has_node(from) or not graph.has_node(to):
		return false

	var from_node = graph.get_node(from)
	var to_node = graph.get_node(to)
	if from_node == null or to_node == null:
		return false

	if not to_node.get_input_ports().has(to_port):
		return false

	if not from_node.get_output_ports().has(from_port):
		return false

	return true



func _can_connect_flow(graph : EventGraphModel, from, from_port, to, to_port) -> bool:
	if not graph.has_node(from) or not graph.has_node(to):
		return false

	if _is_input_port_occupied(graph, to, to_port):
		return false

	if not _can_output_port_connect(graph, from, from_port):
		return false

	return true

func _is_input_port_occupied(graph : EventGraphModel, node_id, port) -> bool:
	for e in graph.get_edges():
		if e.to_node == node_id and e.to_port == port:
			return true
	return false

func _can_output_port_connect(graph : EventGraphModel, node_id, port) -> bool:
	for e in graph.get_edges():
		if e.from_node == node_id and e.from_port == port:
			return false
	return true
