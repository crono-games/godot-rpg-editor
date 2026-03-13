class_name ChangeGraphicsExecutor
extends RefCounted

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, ctx: EventRuntimeContext, scene_root: Node) -> String:
	if scene_root == null:
		return graph.get_next(node_id, 0)

	var params = node.get("params", {})
	var target_id := str(params.get("target_id", ""))
	var target_name := str(params.get("target_name", params.get("target", "")))
	var graphics_path := str(params.get("graphics", ""))

	if graphics_path == "":
		return graph.get_next(node_id, 0)

	var target := TargetResolver.resolve_target(ctx, scene_root, target_id, target_name, false)
	if target == null:
		var label := target_id if target_id != "" else target_name

		if label != "":
			push_warning("ChangeGraphicsExecutor: target not found -> %s" % label)
		return graph.get_next(node_id, 0)

	var tex = load(graphics_path)
	if tex == null:
		return graph.get_next(node_id, 0)
	var sprite = target.get("sprite")
	if sprite is Sprite3D:
		(sprite as Sprite3D).texture = tex
	elif sprite is Sprite2D:
		(sprite as Sprite2D).texture = tex

	return graph.get_next(node_id, 0)
