class_name MoveAlongPathExecutor
extends RefCounted

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, ctx: EventRuntimeContext, scene_root: Node) -> String:

	if scene_root == null:
		return graph.get_next(node_id, 0)
	var params: Dictionary = node.get("params", {})
	var points := _parse_points(params.get("points", []))
	if points.is_empty():
		return graph.get_next(node_id, 0)
	var speed := maxf(1.0, float(params.get("speed_px_per_sec", params.get("speed", 64.0))))
	var loop := bool(params.get("loop", false))
	var wait_for_completion := bool(params.get("wait_for_completion", true))
	var return_back_on_finish := bool(params.get("return_back_on_finish", false))
	var snap_to_first := bool(params.get("snap_to_first_point", false))
	var curve_enabled := bool(params.get("curve_enabled", false))
	var curve_subdivisions := maxi(1, int(params.get("curve_subdivisions", 6)))
	var avoid_player := bool(params.get("avoid_player", true))
	var avoid_radius_px := maxf(4.0, float(params.get("avoid_radius_px", 14.0)))
	var sidestep_px := maxf(8.0, float(params.get("sidestep_px", 20.0)))
	if curve_enabled:
		points = _build_catmull_rom_points(points, curve_subdivisions)
	if return_back_on_finish:
		points = _append_return_path(points)

	var target_id := str(params.get("target_id", ""))
	var target_name := str(params.get("target_name", params.get("target", "")))
	var allow_current := target_id.strip_edges() == "" and target_name.strip_edges() == ""
	var target := TargetResolver.resolve_target(ctx, scene_root, target_id, target_name, allow_current)
	if target == null:
		return graph.get_next(node_id, 0)
	if snap_to_first and points.size() > 0:
		_set_target_position(target, points[0])
	var tween := _play_once(target, points, speed, loop, scene_root, avoid_player, avoid_radius_px, sidestep_px)
	if tween == null:
		return graph.get_next(node_id, 0)
	if loop:
		return graph.get_next(node_id, 0)
	if wait_for_completion:
		await tween.finished
	return graph.get_next(node_id, 0)

func _play_once(
	target: Node,
	points: Array[Vector2],
	speed: float,
	loop: bool,
	scene_root: Node,
	avoid_player: bool,
	avoid_radius_px: float,
	sidestep_px: float
) -> Tween:
	if target == null:
		return null
	_kill_existing_path_tween(target)
	var tree := target.get_tree()
	if tree == null:
		return null
	var tween := tree.create_tween()
	target.set_meta("_move_along_path_tween", tween)
	if loop:
		tween.set_loops()
	var route: Array[Vector2] = points.duplicate()
	if loop and route.size() > 1 and route[route.size() - 1].distance_to(route[0]) > 0.001:
		route.append(route[0])
	if avoid_player:
		route = _build_route_with_player_detours(route, target, scene_root, avoid_radius_px, sidestep_px)
	var from := _current_position_2d(target)
	for p in route:
		var delta := p - from
		if delta.length_squared() > 0.000001:
			var anim_dir = _to_anim_direction(target, delta.normalized())
			tween.tween_callback(func():
				_apply_move_animation(target, anim_dir)
			)
		var duration := from.distance_to(p) / maxf(1.0, speed)
		tween.tween_property(target, "position", _to_target_position(target, p), maxf(0.001, duration))
		from = p
	if not loop:
		tween.tween_callback(func():
			_apply_idle_animation(target)
		)
		tween.finished.connect(func():
			if is_instance_valid(target) and target.has_meta("_move_along_path_tween"):
				var current = target.get_meta("_move_along_path_tween")
				if current == tween:
					target.remove_meta("_move_along_path_tween")
		, CONNECT_ONE_SHOT)
	return tween

func _kill_existing_path_tween(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_meta("_move_along_path_tween"):
		return
	var existing = target.get_meta("_move_along_path_tween")
	if existing is Tween and is_instance_valid(existing):
		(existing as Tween).kill()
	target.remove_meta("_move_along_path_tween")

func _current_position_2d(target: Node) -> Vector2:
	if target is Node2D:
		return (target as Node2D).position
	if target is Node3D:
		var p := (target as Node3D).position
		return Vector2(p.x, p.z)
	return Vector2.ZERO

func _set_target_position(target: Node, p: Vector2) -> void:
	if target is Node2D:
		(target as Node2D).position = p
		return
	if target is Node3D:
		var n3 := target as Node3D
		var current := n3.position
		n3.position = Vector3(p.x, current.y, p.y)

func _to_target_position(target: Node, p: Vector2):
	if target is Node2D:
		return p
	if target is Node3D:
		var current := (target as Node3D).position
		return Vector3(p.x, current.y, p.y)
	return p

func _to_anim_direction(target: Node, dir2: Vector2):
	if target is Node3D:
		return Vector3(dir2.x, 0.0, dir2.y)
	return dir2

func _apply_move_animation(target: Node, direction) -> void:
	if target == null:
		return
	if target.has_method("update_animation"):
		target.call("update_animation", direction)

func _apply_idle_animation(target: Node) -> void:
	if target == null:
		return
	if target is Node3D:
		_apply_move_animation(target, Vector3.ZERO)
		return
	_apply_move_animation(target, Vector2.ZERO)

func _parse_points(raw) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if raw is Array:
		for item in raw:
			if item is Vector2:
				out.append(item)
			elif item is Vector3:
				out.append(Vector2(item.x, item.y))
			elif item is Dictionary:
				out.append(Vector2(float(item.get("x", 0.0)), float(item.get("y", item.get("z", 0.0)))))
	return out

func _build_catmull_rom_points(control: Array[Vector2], subdivisions: int) -> Array[Vector2]:
	if control.size() < 3:
		return control.duplicate()
	var out: Array[Vector2] = []
	var steps := maxi(1, subdivisions)
	for i in range(control.size() - 1):
		var p0 := control[maxi(i - 1, 0)]
		var p1 := control[i]
		var p2 := control[i + 1]
		var p3 := control[mini(i + 2, control.size() - 1)]
		if i == 0:
			out.append(p1)
		for s in range(1, steps + 1):
			var t := float(s) / float(steps)
			var t2 := t * t
			var t3 := t2 * t
			var q := 0.5 * (
				(2.0 * p1) +
				(-p0 + p2) * t +
				(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
				(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
			)
			out.append(q)
	return out

func _append_return_path(points: Array[Vector2]) -> Array[Vector2]:
	if points.size() <= 1:
		return points
	var out: Array[Vector2] = points.duplicate()
	for i in range(points.size() - 2, -1, -1):
		out.append(points[i])
	return out

func _build_route_with_player_detours(
	route: Array[Vector2],
	target: Node,
	scene_root: Node,
	avoid_radius_px: float,
	sidestep_px: float
) -> Array[Vector2]:
	var player := _find_player(scene_root, target)
	if player == null:
		return route
	var player_pos := _current_position_2d(player)
	var out: Array[Vector2] = []
	var from := _current_position_2d(target)
	for to in route:
		var detour = _compute_detour_point(from, to, player_pos, avoid_radius_px, sidestep_px)
		if detour != null:
			var d := detour as Vector2
			if out.is_empty() or out[out.size() - 1].distance_to(d) > 0.5:
				out.append(d)
		out.append(to)
		from = to
	return out

func _compute_detour_point(
	from: Vector2,
	to: Vector2,
	player_pos: Vector2,
	avoid_radius_px: float,
	sidestep_px: float
) -> Variant:
	var seg := to - from
	var seg_len_sq := seg.length_squared()
	if seg_len_sq <= 0.001:
		return null
	var t := clampf((player_pos - from).dot(seg) / seg_len_sq, 0.0, 1.0)
	var closest := from + seg * t
	if closest.distance_to(player_pos) > avoid_radius_px:
		return null
	var dir := seg.normalized()
	var perp := Vector2(-dir.y, dir.x)
	if perp.length_squared() <= 0.001:
		return null
	var side := -1.0 if (player_pos - closest).dot(perp) > 0.0 else 1.0
	var detour := closest + perp * side * sidestep_px
	return Vector2(round(detour.x), round(detour.y))

func _find_player(scene_root: Node, target: Node) -> Node:
	if scene_root == null:
		return null
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node != target and node.is_in_group("player") and (node is Node2D or node is Node3D):
			return node
		for child in node.get_children():
			if child is Node:
				stack.push_back(child)
	return null
