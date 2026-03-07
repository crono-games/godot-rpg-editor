class_name PlayAnimationExecutor
extends RefCounted

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, ctx: EventRuntimeContext, scene_root: Node) -> String:
	var params: Dictionary = node.get("params", {})
	var animation_id := str(params.get("animation_id", "")).strip_edges()
	var fallback_animation := str(params.get("fallback_animation", "")).strip_edges()
	var target_id := str(params.get("target_id", TargetResolver.TARGET_CURRENT)).strip_edges()
	var target_name := str(params.get("target_name", params.get("target", ""))).strip_edges()
	if target_id == "":
		target_id = TargetResolver.TARGET_CURRENT
	var wait_for_completion := bool(params.get("wait_for_completion", false))

	var target := TargetResolver.resolve_target(ctx, scene_root, target_id, target_name, true)
	var player := _resolve_animation_player(target)
	if player == null or animation_id == "":
		return graph.get_next(node_id, 0)
	animation_id = _resolve_animation_name(target, animation_id)
	if not player.has_animation(StringName(animation_id)):
		var fallback := fallback_animation
		if fallback == "" and target != null and target.has_meta("default_animation"):
			fallback = str(target.get_meta("default_animation", ""))
		if fallback != "":
			fallback = _resolve_animation_name(target, fallback)
			if player.has_animation(StringName(fallback)):
				animation_id = fallback
			else:
				return graph.get_next(node_id, 0)
		else:
			return graph.get_next(node_id, 0)

	player.play(animation_id)
	if wait_for_completion:
		var anim := player.get_animation(StringName(animation_id))
		if anim != null and scene_root != null and scene_root.is_inside_tree():
			var duration := maxf(0.0, anim.length / maxf(0.0001, absf(player.speed_scale)))
			if duration > 0.0:
				await scene_root.get_tree().create_timer(duration).timeout
	return graph.get_next(node_id, 0)

func _resolve_animation_player(target: Node) -> AnimationPlayer:
	if target == null:
		return null
	if target.has_method("get"):
		var direct = target.get("animation_player")
		if direct is AnimationPlayer:
			return direct as AnimationPlayer
	if target.has_node("AnimationPlayer"):
		var from_child := target.get_node("AnimationPlayer")
		if from_child is AnimationPlayer:
			return from_child as AnimationPlayer
	return null

func _resolve_animation_name(target: Node, logical_id: String) -> String:
	if target != null and target.has_method("resolve_animation_name"):
		return str(target.call("resolve_animation_name", logical_id))
	return logical_id
