class_name WaitExecutor
extends RefCounted

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, _ctx: EventRuntimeContext, scene_root: Node) -> String:
	var params: Dictionary = node.get("params", {})
	var duration_frames := int(params.get("duration_frames", 0))
	if duration_frames <= 0 and params.has("duration_seconds"):
		duration_frames = int(round(float(params.get("duration_seconds", 0.0)) * 60.0))
	if duration_frames <= 0:
		duration_frames = int(params.get("duration", 0))
	if duration_frames > 0 and scene_root != null and scene_root.is_inside_tree() and scene_root.get_tree() != null:
		await scene_root.get_tree().create_timer(float(duration_frames) / 60.0).timeout
	return graph.get_next(node_id, 0)
