class_name SetVariableExecutor
extends RefCounted

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, ctx: EventRuntimeContext, _scene_root: Node) -> String:
	var params = node.get("params", {})
	var var_name := str(params.get("variable_name", ""))
	var value = params.get("value", 0)
	if var_name != "":
		ctx.set_variable(var_name, value)
	return graph.get_next(node_id, 0)
