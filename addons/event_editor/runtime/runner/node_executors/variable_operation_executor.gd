class_name VariableOperationExecutor
extends RefCounted

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, ctx: EventRuntimeContext, _scene_root: Node) -> String:
	var params = node.get("params", {})
	var var_name := str(params.get("variable_name", ""))
	var op := str(params.get("operator", "+"))
	var value = params.get("value", 0)
	var mode := str(params.get("mode", "ticks"))
	if mode == "seconds":
		value = float(ctx.last_delta)
	if var_name != "":
		var current = ctx.get_variable(var_name, 0)
		var result = _apply_op(current, value, op)
		ctx.set_variable(var_name, result)
	return graph.get_next(node_id, 0)

func _apply_op(current, value, op: String):
	match op:
		"+", "add", "Add":
			return current + value
		"-", "sub", "Sub":
			return current - value
		"*", "mul", "Multiply":
			return current * value
		"/", "div", "Divide":
			if value == 0:
				return current
			return current / value
		"=":
			return value
		_:
			return current
