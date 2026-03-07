class_name VariableConditionExecutor
extends RefCounted

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, ctx: EventRuntimeContext, _scene_root: Node) -> String:
	var params = node.get("params", {})
	var var_name := str(params.get("var_name", ""))
	var cond = params.get("condition_param", {})
	var op := str(cond.get("operator", "=="))
	var expected = cond.get("value", 0)
	var actual = ctx.get_variable(var_name, 0)
	var ok := _compare(actual, expected, op)
	var port := 0 if ok else 1
	return graph.get_next(node_id, port)

func _compare(a, b, op: String) -> bool:
	match op:
		"==": return a == b
		"!=": return a != b
		">": return a > b
		">=": return a >= b
		"<": return a < b
		"<=": return a <= b
		_: return false
