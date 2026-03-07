class_name GraphConnectionPolicy
extends RefCounted

func can_connect(
	_graph: EventGraphModel,
	_from_node: String,
	_from_port: int,
	_to_node: String,
	_to_port: int = 0,
) -> bool:
	return false
