class_name ConditionEvaluator
extends RefCounted

func evaluate(params: Dictionary, ctx: EventRuntimeContext, scene_root: Node) -> bool:
	var subject := str(params.get("subject", "player")).to_lower()
	var property_name := str(params.get("property", "facing_dir")).to_lower()
	var op := str(params.get("operator", "=="))
	var value_raw := params.get("value", "")

	if subject != "player":
		return false

	var player := _resolve_player(ctx, scene_root)
	if player == null:
		return false

	match property_name:
		"facing_dir":
			var actual := _facing_to_text(_resolve_facing(player))
			var expected := str(value_raw).strip_edges().to_lower()
			return _compare_text(actual, expected, op)
		"distance_to_event":
			var target_id := str(params.get("target_id", ""))
			var target_name := str(params.get("target_name", ""))
			var target := TargetResolver.resolve_target(ctx, scene_root, target_id, target_name, false)
			if target == null:
				return false
			var distance := _distance(player, target)
			var expected_num := _to_number(value_raw, 0.0)
			return _compare_number(distance, expected_num, op)
		_:
			return false

func _resolve_player(ctx: EventRuntimeContext, scene_root: Node) -> Node:
	if ctx != null:
		var env := ctx.get_scene_event_environment()
		if env != null:
			var p := env.get_player("player")
			if p != null:
				return p
	return _find_player(scene_root)

func _find_player(root: Node) -> Node:
	if root == null:
		return null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n := stack.pop_back()
		if n.is_in_group("player") and (n is Node2D or n is Node3D):
			return n
		for c in n.get_children():
			if c is Node:
				stack.push_back(c)
	return null

func _resolve_facing(player: Node) -> Vector2:
	if player == null:
		return Vector2.ZERO
	if player.has_method("get_facing_direction"):
		var v = player.call("get_facing_direction")
		if v is Vector3:
			return Vector2(v.x, v.z)
		if v is Vector2:
			return v
	if player.has_method("get"):
		var d = player.get("_last_dir")
		if d is Vector2:
			return d
		if d is Vector3:
			return Vector2(d.x, d.z)
	return Vector2.ZERO

func _facing_to_text(dir: Vector2) -> String:
	if dir.length_squared() <= 0.00001:
		return "down"
	var d := dir.normalized()
	if absf(d.x) >= absf(d.y):
		return "right" if d.x > 0.0 else "left"
	return "down" if d.y > 0.0 else "up"

func _distance(a: Node, b: Node) -> float:
	var p0 := _node_pos3(a)
	var p1 := _node_pos3(b)
	return p0.distance_to(p1)

func _node_pos3(node: Node) -> Vector3:
	if node is Node3D:
		return (node as Node3D).global_position
	if node is Node2D:
		var p := (node as Node2D).global_position
		return Vector3(p.x, p.y, 0.0)
	return Vector3.ZERO

func _compare_text(actual: String, expected: String, op: String) -> bool:
	match op:
		"!=":
			return actual != expected
		_:
			return actual == expected

func _compare_number(a: float, b: float, op: String) -> bool:
	match op:
		"==": return is_equal_approx(a, b)
		"!=": return not is_equal_approx(a, b)
		">": return a > b
		">=": return a >= b
		"<": return a < b
		"<=": return a <= b
		_: return false

func _to_number(value, default_value: float) -> float:
	if value is float or value is int:
		return float(value)
	if value is String:
		var s := (value as String).strip_edges()
		if s.is_valid_float():
			return s.to_float()
		if s.is_valid_int():
			return float(s.to_int())
	return default_value
