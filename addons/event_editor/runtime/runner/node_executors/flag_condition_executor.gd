class_name FlagConditionExecutor
extends RefCounted

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, ctx: EventRuntimeContext, _scene_root: Node) -> String:
	var params = node.get("params", {})
	var flag_name := str(params.get("flag_name", ""))
	var scope := str(params.get("scope", "global")).to_lower()
	var event_id := ctx.current_event_id
	var is_true := false
	if scope == "local":
		is_true = ctx.get_local_flag(event_id, flag_name)
	else:
		is_true = ctx.get_flag(flag_name)
	var port := 0 if is_true else 1
	return graph.get_next(node_id, port)
