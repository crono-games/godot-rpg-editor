class_name JumpToLabelExecutor
extends RefCounted

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, _ctx: EventRuntimeContext, _scene_root: Node) -> String:
	var params = node.get("params", {})
	var target := str(params.get("target_label", "")).strip_edges()
	if target == "":
		return graph.get_next(node_id, 0)
	var target_id := graph.get_label_node_id(target)
	if target_id == "":
		return graph.get_next(node_id, 0)
	return target_id
