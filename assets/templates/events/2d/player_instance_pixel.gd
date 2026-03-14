@tool
extends PlayerActor2DBase
class_name PlayerInstancePixel2D

const DIAG := 0.70710678

@export var speed := 60.0
@export var walk_speed := 60.0
@export var run_speed := 90.0

@export var pixel_step := 1.0
@export var corner_correction := 2
@export var trigger_area: Area2D
@export var hitbox_area: Area2D
@export var hitbox: CollisionShape2D

var collide_with_world := true
var _accum := 0.0
var _last_debug_ms := 0

func _ready() -> void:
	area = trigger_area
	_common_ready("Free", false)
	_resolve_runtime_links()

func _physics_process(delta: float) -> void:
	if not get_parent() is Node2D:
		return
	if _is_dialog_input_locked():
		_moving = false
		update_animation(Vector2.ZERO)
		return

	var dir := _get_input_direction()
	if dir == Vector2.ZERO:
		_moving = false
		update_animation(Vector2.ZERO)
		return
	if not Engine.is_editor_hint():
		if Input.is_action_pressed("ui_run"):
			speed = run_speed
		if Input.is_action_just_released("ui_run"):
			speed = walk_speed

	_last_dir = _main_dir(dir)
	update_animation(dir)
	move_pixel(dir, delta)

func move_pixel(dir: Vector2, delta: float) -> void:
	dir = dir.sign()
	_moving = dir != Vector2.ZERO

	var spd := speed
	if dir.x != 0 and dir.y != 0:
		spd *= DIAG

	_accum += spd * delta
	var moved_any := false
	while _accum >= pixel_step:
		if _step(dir):
			moved_any = true
		_accum -= pixel_step

	if moved_any:
		_moving = true

func _step(dir: Vector2) -> bool:
	var motion := dir * maxf(0.0001, pixel_step)

	if _try_motion(motion):
		return true

	if dir.x != 0:
		var mx := Vector2(motion.x, 0.0)
		if _try_motion(mx):
			return true

	if dir.y != 0:
		var my := Vector2(0.0, motion.y)
		if _try_motion(my):
			return true

	return _corner_correct(dir)

func _try_motion(motion: Vector2) -> bool:
	var blocked_event := _find_blocking_event(motion)
	if blocked_event != null:
		_emit_bump_event(blocked_event)
		return false
	var safe := _safe_fraction(motion)
	if safe >= 1.0:
		global_position += motion
		return true
	return false

func _safe_fraction(motion: Vector2) -> float:
	var params = _make_shape_query(motion)
	if params == null:
		return 0.0
	var result = get_world_2d().direct_space_state.cast_motion(params)
	if result != null and result.size() > 0:
		return float(result[0])
	return 0.0

func _corner_correct(dir: Vector2) -> bool:
	var perp := Vector2(-dir.y, dir.x)
	for i in range(1, corner_correction + 1):
		var offset := perp * float(i)
		if _try_motion(offset + dir * pixel_step):
			return true
		if _try_motion(-offset + dir * pixel_step):
			return true
	return false

func _find_blocking_event(motion: Vector2) -> Node:
	var params = _make_event_query(Vector2.ZERO)
	if params == null:
		return null
	params.transform.origin += motion
	var hits := get_world_2d().direct_space_state.intersect_shape(params, 16)
	for hit in hits:
		if not (hit is Dictionary):
			continue
		var collider = hit.get("collider", null)
		var node := _resolve_blocking_event_actor(collider)
		if node == null:
			continue
		if node == self:
			continue
		if str(node.get("id")) == "":
			continue
		if node.has_method("blocks_player_movement") and not bool(node.call("blocks_player_movement")):
			continue
		return node
	return null

func _make_shape_query(motion: Vector2):
	if hitbox == null or not is_instance_valid(hitbox):
		return null
	if hitbox_area == null or not is_instance_valid(hitbox_area):
		return null
	if hitbox.shape == null:
		return null
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = hitbox.shape
	params.transform = hitbox.global_transform
	params.motion = motion
	params.collision_mask = hitbox_area.collision_mask
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = [hitbox_area.get_rid()]
	return params

func _make_event_query(motion: Vector2):
	if hitbox == null or not is_instance_valid(hitbox):
		return null
	if hitbox_area == null or not is_instance_valid(hitbox_area):
		return null
	if hitbox.shape == null:
		return null
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = hitbox.shape
	params.transform = hitbox.global_transform
	params.motion = motion
	params.collision_mask = hitbox_area.collision_mask
	params.collide_with_bodies = false
	params.collide_with_areas = true
	params.exclude = _collect_self_area_rids()
	return params

func _resolve_blocking_event_actor(collider: Variant) -> Node:
	if not (collider is Node):
		return null
	var n: Node = collider
	while n != null:
		if n == self or self.is_ancestor_of(n) or n.is_ancestor_of(self):
			return null
		if n.is_in_group("event_instance"):
			return n
		n = n.get_parent()
	return null

func _collect_self_area_rids() -> Array:
	var rids: Array = []
	if hitbox_area != null and is_instance_valid(hitbox_area):
		rids.append(hitbox_area.get_rid())
	if trigger_area != null and is_instance_valid(trigger_area):
		rids.append(trigger_area.get_rid())
	for child in get_children():
		if child is Area2D and is_instance_valid(child):
			rids.append((child as Area2D).get_rid())
	return rids

func _resolve_runtime_links() -> void:
	if trigger_area == null or not is_instance_valid(trigger_area):
		var t := get_node_or_null("TriggerArea")
		if t is Area2D:
			trigger_area = t as Area2D
	if hitbox_area == null or not is_instance_valid(hitbox_area):
		var hb := get_node_or_null("HitboxArea")
		if hb is Area2D:
			hitbox_area = hb as Area2D
	if hitbox == null or not is_instance_valid(hitbox):
		var hs := get_node_or_null("HitboxArea/HitboxShape")
		if hs is CollisionShape2D:
			hitbox = hs as CollisionShape2D
