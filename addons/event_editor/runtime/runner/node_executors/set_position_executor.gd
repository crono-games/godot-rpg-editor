class_name SetPositionExecutor
extends RefCounted

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, ctx: EventRuntimeContext, scene_root: Node) -> String:
	if scene_root == null:
		return graph.get_next(node_id, 0)

	var params = node.get("params", {})
	var target_id := str(params.get("target_id", ""))
	var target_name := str(params.get("target_name", params.get("target", "")))
	var pos = params.get("target_position", params.get("world_position", Vector3.ZERO))
	var position_mode := str(params.get("position_mode", "world")).to_lower()

	var normalized_id := target_id.strip_edges().to_lower()
	var normalized_name := target_name.strip_edges().to_lower()
	var allow_current := normalized_id == TargetResolver.TARGET_CURRENT or normalized_name == TargetResolver.TARGET_CURRENT
	if target_id.strip_edges() == "" and target_name.strip_edges() == "":
		return graph.get_next(node_id, 0)
	var target := TargetResolver.resolve_target(ctx, scene_root, target_id, target_name, allow_current)
	if target == null:
		target = _resolve_target_fallback(scene_root, target_id, target_name)
	if target == null:
		var label := target_id if target_id != "" else target_name
		return graph.get_next(node_id, 0)

	pos = _parse_position(pos)
	pos = PositionModeResolver.resolve_runtime_position(target, pos, position_mode)
	var env := ctx.get_scene_event_environment()
	if env != null:
		var resolved_id := target_id
		if resolved_id == "" and target.has_method("get"):
			resolved_id = str(target.get("id"))
		if resolved_id != "" and not env.set_event_position(resolved_id, pos):
			_apply_position(target, pos)
		elif resolved_id == "":
			_apply_position(target, pos)
	else:
		_apply_position(target, pos)

	_resync_followers_if_player_target(scene_root, target)
	return graph.get_next(node_id, 0)

func _parse_position(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Vector2:
		return Vector3(value.x, value.y, 0)
	if value is Dictionary:
		var y2d := float(value.get("y", value.get("z", 0)))
		return Vector3(
			float(value.get("x", 0)),
			y2d,
			float(value.get("z", 0))
		)
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is String:
		var parts = value.split(",")
		if parts.size() >= 3:
			return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	return Vector3.ZERO

func _apply_position(target: Node, pos: Vector3) -> void:
	if target == null:
		return
	if target is Node3D:
		(target as Node3D).position = pos
	elif target is Node2D:
		(target as Node2D).position = _to_2d_position(pos)

func _to_2d_position(pos: Vector3) -> Vector2:
	return Vector2(pos.x, pos.y)

func _resync_followers_if_player_target(scene_root: Node, target: Node) -> void:
	if scene_root == null or target == null:
		return
	if not target.is_in_group("player"):
		return
	var tree := scene_root.get_tree()
	if tree == null:
		return
	var controllers := tree.get_nodes_in_group("follower_controller")
	for c in controllers:
		if c == null or not is_instance_valid(c):
			continue
		if c.has_method("force_resync_after_warp"):
			c.call("force_resync_after_warp")

func _resolve_target_fallback(scene_root: Node, target_id: String, target_name: String) -> Node:
	if scene_root == null or not is_instance_valid(scene_root):
		return null
	var id := target_id.strip_edges()
	var name := target_name.strip_edges()
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node.is_in_group("EventInstance") or node.is_in_group("player"):
			var node_id := ""
			if node.has_method("get"):
				node_id = str(node.get("id"))
			if id != "" and (node_id == id or node.name == id):
				return node
			if name != "" and (node.name == name or node_id == name):
				return node
		for child in node.get_children():
			if child is Node:
				stack.push_back(child)
	return null
