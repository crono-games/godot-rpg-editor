class_name MoveExecutor
extends RefCounted

const GRID_SIZE := 1.0
const STEP_TIME := 0.5
const JUMP_HEIGHT := 0.5
const JUMP_TIME := STEP_TIME * 2.0
const DEBUG_MOVE := false
const META_MOVE_TWEEN := "_move_tween"

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, ctx: EventRuntimeContext, scene_root: Node) -> String:
	if scene_root == null:
		return graph.get_next(node_id, 0)

	var params = node.get("params", {})
	var route = params.get("route", [])
	var wait_for_completion := bool(params.get("wait_for_completion", true))
	var planned_positions := {}
	var timeline: Tween = null
	var touched_targets := {}
	for step in route:
		var action := str(step.get("action_type", "")).to_lower()
		if action == "wait":
			var duration := int(step.get("duration", 1))
			if wait_for_completion:
				await _wait_frames(scene_root, duration)
			else:
				if timeline == null:
					timeline = scene_root.get_tree().create_tween()
				timeline.tween_interval(maxf(0.0, float(duration) / 60.0))
			continue

		var target_id := str(step.get("target_id", ""))
		var target_name := str(step.get("target_name", step.get("target", "")))
		var dir = step.get("direction", {})
		var vec := Vector3(
			float(dir.get("x", 0)),
			float(dir.get("y", 0)),
			float(dir.get("z", 0))
		)
		if vec == Vector3.ZERO and action != "jump":
			continue

		var target := TargetResolver.resolve_target(ctx, scene_root, target_id, target_name, false)
		if target == null:
			var label := target_id if target_id != "" else target_name
			continue

		var step_size := _resolve_step_size(target)
		var delta := vec * step_size
		if action == "turn":
			_apply_turn(target, vec)
			continue
		if action == "jump":
			var jump_height := float(step.get("jump_height", JUMP_HEIGHT))
			var jump_time := float(step.get("jump_time", JUMP_TIME))
			jump_height = maxf(0.0, jump_height)
			jump_time = maxf(0.01, jump_time)
			if wait_for_completion:
				_set_anim_moving(target, vec, jump_time)
				await _tween_jump(target, _node_pos3(target) + delta, jump_height, jump_time)
				var jump_key_sync := str(target.get_instance_id())
				touched_targets[jump_key_sync] = target
			else:
				if timeline == null:
					timeline = scene_root.get_tree().create_tween()
				var jump_key := str(target.get_instance_id())
				var jump_from: Vector3 = planned_positions.get(jump_key, _node_pos3(target))
				var jump_to := jump_from + delta
				planned_positions[jump_key] = jump_to
				if not touched_targets.has(jump_key):
					_stop_active_move_tween(target)
					touched_targets[jump_key] = target
				timeline.tween_callback(func():
					_set_anim_moving(target, vec, jump_time)
				)
				_append_jump_tween(timeline, target, jump_from, jump_to, jump_height, jump_time)
			continue
		if wait_for_completion:
			var next_pos_sync := _node_pos3(target) + delta
			if _is_move_blocked_2d(target, next_pos_sync, scene_root):
				continue
			_set_anim_moving(target, vec, STEP_TIME)
			await _tween_move(target, next_pos_sync)
			var key_sync := str(target.get_instance_id())
			touched_targets[key_sync] = target
		else:
			if timeline == null:
				timeline = scene_root.get_tree().create_tween()
			var key := str(target.get_instance_id())
			var from_pos: Vector3 = planned_positions.get(key, _node_pos3(target))
			var next_pos := from_pos + delta
			if _is_move_blocked_2d(target, next_pos, scene_root):
				continue
			planned_positions[key] = next_pos
			if not touched_targets.has(key):
				_stop_active_move_tween(target)
				touched_targets[key] = target
			timeline.tween_callback(func():
				_set_anim_moving(target, vec, STEP_TIME)
			)
			timeline.tween_property(target, "position", _pos_value_for(target, next_pos), STEP_TIME)

	if wait_for_completion:
		for target in touched_targets.values():
			if target != null:
				_set_anim_idle(target)
	elif timeline != null:
		for target in touched_targets.values():
			if target != null:
				target.set_meta(META_MOVE_TWEEN, timeline)
		timeline.finished.connect(func():
			for target in touched_targets.values():
				if target != null and target.has_meta(META_MOVE_TWEEN):
					target.remove_meta(META_MOVE_TWEEN)
				_set_anim_idle(target)
		)

	return graph.get_next(node_id, 0)

func _wait_frames(scene_root: Node, frames: int) -> void:
	if scene_root == null or not scene_root.is_inside_tree():
		return
	for i in frames:
		await scene_root.get_tree().process_frame

func _tween_move(node: Node, to_pos: Vector3) -> void:
	if node == null or not node.is_inside_tree():
		return
	var tween := node.get_tree().create_tween()
	tween.tween_property(node, "position", _pos_value_for(node, to_pos), STEP_TIME)
	await tween.finished

func _stop_active_move_tween(node: Node) -> void:
	if node == null:
		return
	if not node.has_meta(META_MOVE_TWEEN):
		return
	var tw = node.get_meta(META_MOVE_TWEEN)
	if tw is Tween and is_instance_valid(tw):
		(tw as Tween).kill()
	node.remove_meta(META_MOVE_TWEEN)

func _tween_jump(node: Node, to_pos: Vector3, height: float, total_time: float) -> void:
	if node == null or not node.is_inside_tree():
		return
	var from_pos := _node_pos3(node)
	var mid := from_pos.lerp(to_pos, 0.5)
	mid.y = maxf(from_pos.y, to_pos.y) + height
	var half := maxf(0.001, total_time * 0.5)
	var tween := node.get_tree().create_tween()
	tween.tween_property(node, "position", _pos_value_for(node, mid), half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", _pos_value_for(node, to_pos), half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

func _append_jump_tween(timeline: Tween, node: Node, from_pos: Vector3, to_pos: Vector3, height: float, total_time: float) -> void:
	if timeline == null or node == null:
		return
	var mid := from_pos.lerp(to_pos, 0.5)
	mid.y = maxf(from_pos.y, to_pos.y) + height
	var half := maxf(0.001, total_time * 0.5)
	timeline.tween_property(node, "position", _pos_value_for(node, mid), half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	timeline.tween_property(node, "position", _pos_value_for(node, to_pos), half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _apply_turn(target: Node, direction: Vector3) -> void:
	if target == null or direction == Vector3.ZERO:
		return
	if target.has_method("play_animation"):
		target.call("play_animation", "idle", _anim_direction_for(target, direction))
		return
	if target is Node3D:
		(target as Node3D).rotation.y = atan2(direction.x, direction.z)

func _resolve_step_size(target: Node) -> float:
	if target != null and target.has_method("get"):
		var gs = target.get("grid_size")
		if gs != null:
			return maxf(0.001, float(gs))
	return GRID_SIZE

func _set_anim_moving(target: Node, direction: Vector3, step_time: float) -> void:
	if target == null:
		return
	if target.has_method("update_animation"):
		target.call("update_animation", _anim_direction_for(target, direction))
	_sync_anim_speed_to_step(target, step_time)

func _set_anim_idle(target: Node) -> void:
	if target == null:
		return
	if target.has_method("update_animation"):
		target.call("update_animation", _anim_direction_for(target, Vector3.ZERO))
	_reset_anim_speed(target)

func _node_pos3(node: Node) -> Vector3:
	if node is Node3D:
		return (node as Node3D).position
	if node is Node2D:
		var p := (node as Node2D).position
		return Vector3(p.x, 0.0, p.y)
	return Vector3.ZERO

func _pos_value_for(node: Node, pos3: Vector3):
	if node is Node3D:
		return pos3
	return Vector2(pos3.x, pos3.z)

func _anim_direction_for(node: Node, dir3: Vector3):
	if node is Node2D:
		return Vector2(dir3.x, dir3.z)
	return dir3

func _is_move_blocked_2d(target: Node, next_pos3: Vector3, scene_root: Node) -> bool:
	if not (target is Node2D):
		return false
	var t2d := target as Node2D
	var from_pos3 := _node_pos3(target)
	if _is_world_blocked_2d(target, from_pos3, next_pos3):
		return true
	var grid_size := _resolve_step_size(target)
	var centered := true
	if target.has_method("get") and target.get("grid_centered") != null:
		centered = bool(target.get("grid_centered"))
	var target_cell := GridUtils.world_to_cell(next_pos3, grid_size, centered)

	if scene_root == null or not scene_root.is_inside_tree():
		return false
	var all_nodes := scene_root.get_tree().get_nodes_in_group("EventInstance")
	for n in all_nodes:
		if not (n is Node2D):
			continue
		if n == target:
			continue
		if n.has_method("blocks_player_movement") and not bool(n.call("blocks_player_movement")):
			continue
		var ncell := GridUtils.world_to_cell(_node_pos3(n), grid_size, centered)
		if ncell == target_cell:
			return true

	for p in scene_root.get_tree().get_nodes_in_group("player"):
		if not (p is Node2D):
			continue
		if p == target:
			continue
		var pcell := GridUtils.world_to_cell(_node_pos3(p), grid_size, centered)
		if pcell == target_cell:
			return true
	return false

func _is_world_blocked_2d(target: Node, from_pos3: Vector3, next_pos3: Vector3) -> bool:
	if target == null or not target.has_method("get"):
		return false
	var hb_area_ref = target.get("hitbox_area")
	var hb_shape_ref = target.get("hitbox")
	if not (hb_area_ref is Area2D):
		return false
	if not (hb_shape_ref is CollisionShape2D):
		return false
	var hb_area := hb_area_ref as Area2D
	var hb_shape := hb_shape_ref as CollisionShape2D
	if hb_shape.shape == null:
		return false
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = hb_shape.shape
	params.transform = hb_shape.global_transform
	params.motion = Vector2(next_pos3.x - from_pos3.x, next_pos3.z - from_pos3.z)
	params.collision_mask = hb_area.collision_mask
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = [hb_area.get_rid()]
	var state := hb_area.get_world_2d().direct_space_state
	var result = state.cast_motion(params)
	return result == null or result.size() == 0 or float(result[0]) < 1.0

func _sync_anim_speed_to_step(target: Node, step_time: float) -> void:
	if step_time <= 0.0 or target == null:
		return
	var ap = target.get("animation_player")
	if not (ap is AnimationPlayer):
		return
	var player := ap as AnimationPlayer
	var cycles_per_step := maxf(0.0, float(target.get("max_anim_cycles_per_step")))
	if cycles_per_step <= 0.0:
		cycles_per_step = 1.0
	var anim_name := StringName(player.current_animation)
	if anim_name == StringName(""):
		return
	var anim := player.get_animation(anim_name)
	if anim == null:
		return
	var len := maxf(0.001, anim.length)
	player.speed_scale = (len * cycles_per_step) / step_time

func _reset_anim_speed(target: Node) -> void:
	if target == null:
		return
	var ap = target.get("animation_player")
	if ap is AnimationPlayer:
		(ap as AnimationPlayer).speed_scale = 1.0
