class_name LabelExecutor
extends RefCounted

func run(node_id: String, _node: Dictionary, graph: EventGraphRuntime, _ctx: EventRuntimeContext, _scene_root: Node) -> String:
	return graph.get_next(node_id, 0)
