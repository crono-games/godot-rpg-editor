class_name SetVisibilityExecutor
extends RefCounted

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, ctx: EventRuntimeContext, scene_root: Node) -> String:
	var params: Dictionary = node.get("params", {})
	var target_id := str(params.get("target_id", "")).strip_edges()
	var target_name := str(params.get("target_name", params.get("target", ""))).strip_edges()
	var visible := bool(params.get("visible", true))
	var disable_collision := bool(params.get("disable_collision", false))

	var allow_current := target_id == "" and target_name == ""
	var target := TargetResolver.resolve_target(ctx, scene_root, target_id, target_name, allow_current)
	if target == null:
		return graph.get_next(node_id, 0)

	_apply_visibility(target, visible)
	_apply_collision_enabled(target, not disable_collision)
	return graph.get_next(node_id, 0)

func _apply_visibility(target: Node, visible: bool) -> void:
	if target == null:
		return
	if target.has_method("set") and target.get("sprite") != null:
		var s = target.get("sprite")
		if s is CanvasItem:
			(s as CanvasItem).visible = visible
	if target.has_node("Sprite2D"):
		var s2 := target.get_node("Sprite2D")
		if s2 is CanvasItem:
			(s2 as CanvasItem).visible = visible
	if target.has_node("Sprite3D"):
		var s3 := target.get_node("Sprite3D")
		if s3 is Node3D:
			(s3 as Node3D).visible = visible

func _apply_collision_enabled(target: Node, enabled: bool) -> void:
	if target == null:
		return
	# Disable concrete collision shapes first.
	_set_shapes_disabled_recursive(target, not enabled)
	# For trigger areas, also stop overlap processing when disabled.
	if target.has_node("TriggerArea"):
		var trigger_area := target.get_node("TriggerArea")
		if trigger_area is Area2D:
			(trigger_area as Area2D).call_deferred("set_monitoring", enabled)
			(trigger_area as Area2D).call_deferred("set_monitorable", enabled)
	if target.has_node("HitboxArea"):
		var hitbox_area := target.get_node("HitboxArea")
		if hitbox_area is Area2D:
			(hitbox_area as Area2D).call_deferred("set_monitoring", enabled)
			(hitbox_area as Area2D).call_deferred("set_monitorable", enabled)

func _set_shapes_disabled_recursive(root: Node, disabled: bool) -> void:
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is CollisionShape2D:
			(n as CollisionShape2D).call_deferred("set_disabled", disabled)
		elif n is CollisionShape3D:
			(n as CollisionShape3D).call_deferred("set_disabled", disabled)
		for c in n.get_children():
			if c is Node:
				stack.push_back(c)
