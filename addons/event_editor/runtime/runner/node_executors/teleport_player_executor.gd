class_name TeleportPlayerExecutor
extends RefCounted

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, ctx: EventRuntimeContext, scene_root: Node) -> String:
	var params = node.get("params", {})
	var map_id := str(params.get("map_id", ""))
	var pos := _parse_target_position(params.get("target_position", Vector3.ZERO))
	var position_mode := str(params.get("position_mode", "world")).to_lower()
	var auto_fade = params.get("auto_fade", true)
	var fade_frames := int(params.get("fade_frames", 30))
	var facing_dir := str(params.get("facing_dir", "keep")).to_lower()

	if scene_root == null:
		return graph.get_next(node_id, 0)

	var map_manager := MapEventManager
	var player := _resolve_player(scene_root, map_manager, ctx)

	if auto_fade:
		await _fade(scene_root, true, fade_frames)

	var current_map_id := ""
	if map_manager != null and map_manager.has_method("get_current_map_id"):
		current_map_id = str(map_manager.get_current_map_id())

	if map_id == "" or map_id == current_map_id:
		var scene := scene_root
		if player == null or not is_instance_valid(player):
			if map_manager != null and map_manager.has_method("get_scene_root"):
				scene = map_manager.get_scene_root()
			player = _resolve_player(scene, map_manager, ctx)
		if player == null or not is_instance_valid(player):
			return graph.get_next(node_id, 0)
		pos = PositionModeResolver.resolve_runtime_position(player, pos, position_mode)
		_apply_position(player, pos)
		_apply_facing(player, facing_dir)
		if auto_fade:
			await _fade(scene, false, fade_frames)
		return graph.get_next(node_id, 0)

	if map_manager != null and map_manager.has_method("request_map_change"):
		map_manager.request_map_change(map_id, pos, auto_fade, fade_frames, facing_dir)
	return graph.get_next(node_id, 0)

func _resolve_player(scene_root: Node, map_manager, ctx: EventRuntimeContext) -> Node:
	var env := ctx.get_scene_event_environment()
	if env != null:
		var env_player := env.get_player("PlayerInstance")
		if env_player != null and is_instance_valid(env_player):
			return env_player
	if map_manager != null and map_manager.has_method("get_player"):
		var p = map_manager.get_player(scene_root)
		if p is Node2D or p is Node3D:
			return p
	return _find_player(scene_root)

func _find_player(root: Node) -> Node:
	if root == null or not is_instance_valid(root):
		return null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node.is_in_group("PlayerInstance") and (node is Node2D or node is Node3D):
			return node
		for child in node.get_children():
			if child is Node:
				stack.push_back(child)
	return null

func _apply_position(target: Node, pos: Vector3) -> void:
	if target == null:
		return
	if target is Node3D:
		(target as Node3D).position = pos
	elif target is Node2D:
		(target as Node2D).position = _to_2d_position(pos)

func _to_2d_position(pos: Vector3) -> Vector2:
	return Vector2(pos.x, pos.y)

func _apply_facing(target: Node, facing_dir: String) -> void:
	if target == null:
		return
	var dir := facing_dir.strip_edges().to_lower()
	if dir == "" or dir == "keep":
		return
	var v2 := Vector2.DOWN
	match dir:
		"up":
			v2 = Vector2.UP
		"left":
			v2 = Vector2.LEFT
		"right":
			v2 = Vector2.RIGHT
		_:
			v2 = Vector2.DOWN
	if target.has_method("set"):
		target.set("_last_dir", v2)
		target.set("last_dir", v2)
	if target.has_method("play_animation"):
		target.call("play_animation", "idle", v2)


func _fade(scene_root: Node, fade_out: bool, frames: int) -> void:
	var frames_clamped = max(0, frames)
	var duration := float(frames_clamped) / 60.0
	var node := {
		"params": {
			"color": {
				"r": 0,
				"g": 0,
				"b": 0,
				"a": 255
			},
			"duration": frames_clamped
		}
	}
	if not fade_out:
		node["params"]["color"]["a"] = 0
	var executor := ChangeScreenToneExecutor.new()
	await executor.run("", node, EventGraphRuntime.new({}, ""), EventRuntimeContext.new(), scene_root)

func _parse_target_position(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Vector2:
		return Vector3(value.x, value.y, 0)
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		var x := float(value.get("x", 0))
		var y := float(value.get("y", value.get("z", 0)))
		var z := float(value.get("z", 0))
		return Vector3(x, y, z)
	if value is String:
		var parts = value.split(",")
		if parts.size() >= 3:
			return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	return Vector3.ZERO
