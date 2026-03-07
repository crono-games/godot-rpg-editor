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
		return graph.get_next(node_id, 0)

	var tex = load(graphics_path)
	if tex == null:
		return graph.get_next(node_id, 0)

	if target.has_node("Sprite3D"):
		var sprite := target.get_node("Sprite3D")
		if sprite is Sprite3D:
			sprite.texture = tex
	if target.has_node("Sprite2D"):
		var sprite2d := target.get_node("Sprite2D")
		if sprite2d is Sprite2D:
			sprite2d.texture = tex
	var sprite_ref = target.get("sprite")
	if sprite_ref is Sprite3D:
		(sprite_ref as Sprite3D).texture = tex
	elif sprite_ref is Sprite2D:
		(sprite_ref as Sprite2D).texture = tex

	return graph.get_next(node_id, 0)
