class_name ConditionExecutor
extends RefCounted

var _evaluator := ConditionEvaluator.new()

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, ctx: EventRuntimeContext, scene_root: Node) -> String:
	var params := node.get("params", {})
	var ok := _evaluator.evaluate(params, ctx, scene_root)
	var port := 0 if ok else 1
	return graph.get_next(node_id, port)
