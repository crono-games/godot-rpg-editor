class_name PlayVisualFxExecutor
extends RefCounted

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, ctx: EventRuntimeContext, scene_root: Node) -> String:
	if scene_root == null:
		return graph.get_next(node_id, 0)
	var params: Dictionary = node.get("params", {})
	var fx_id := str(params.get("fx_id", "")).strip_edges()
	var wait_for_completion := bool(params.get("wait_for_completion", false))
	if fx_id == "":
		return graph.get_next(node_id, 0)

	var fx_source := _find_fx_source(scene_root)
	if fx_source == null:
		return graph.get_next(node_id, 0)

	var options := {
		"wait_for_completion": wait_for_completion,
	}
	if wait_for_completion:
		await _play_fx_and_wait(fx_source, fx_id, options)
	else:
		_play_fx(fx_source, fx_id, options)
	return graph.get_next(node_id, 0)


func _find_fx_source(scene_root: Node) -> Node:
	if scene_root == null:
		return null
	var tree := scene_root.get_tree()
	if tree != null:
		for n in tree.get_nodes_in_group("animation_container"):
			if n is Node:
				return n
	for c in scene_root.get_children():
		if c is Node and (c as Node).name == "AnimationContainer":
			return c
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n.name == "AnimationContainer":
			return n
		if n.has_method("get_available_fx_ids"):
			return n
		if n is AnimatedSprite2D:
			var sprite := n as AnimatedSprite2D
			if sprite.sprite_frames != null and sprite.sprite_frames.get_animation_names().size() > 0:
				return n
		if n is AnimationPlayer:
			if (n as AnimationPlayer).get_animation_list().size() > 0:
				return n
		for child in n.get_children():
			if child is Node:
				stack.push_back(child)
	return null

func _play_fx(source: Node, fx_id: String, options: Dictionary) -> void:
	if source == null or fx_id == "":
		return
	if source.has_method("play_fx"):
		source.call("play_fx", fx_id, options)
		return
	if source.has_method("play"):
		source.call("play", fx_id, options)
		return
	var stack: Array[Node] = [source]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is AnimatedSprite2D:
			var sprite := n as AnimatedSprite2D
			if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(fx_id):
				sprite.play(fx_id)
				return
		elif n is AnimationPlayer:
			var player := n as AnimationPlayer
			if player.has_animation(StringName(fx_id)):
				player.play(fx_id)
				return
		for child in n.get_children():
			if child is Node:
				stack.push_back(child)

func _play_fx_and_wait(source: Node, fx_id: String, options: Dictionary) -> void:
	if source == null or fx_id == "":
		return
	if source.has_method("play_fx_and_wait"):
		await source.call("play_fx_and_wait", fx_id, options)
		return
	_play_fx(source, fx_id, options)
	var stack: Array[Node] = [source]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is AnimatedSprite2D:
			var sprite := n as AnimatedSprite2D
			if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(fx_id):
				await sprite.animation_finished
				return
		elif n is AnimationPlayer:
			var player := n as AnimationPlayer
			if player.has_animation(StringName(fx_id)):
				var anim := player.get_animation(StringName(fx_id))
				if anim != null:
					var speed := maxf(0.0001, absf(player.speed_scale))
					await player.get_tree().create_timer(anim.length / speed).timeout
				return
		for child in n.get_children():
			if child is Node:
				stack.push_back(child)
