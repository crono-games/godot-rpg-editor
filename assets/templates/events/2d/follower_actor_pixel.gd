@tool
extends EventInstance2D
class_name FollowerActorPixel2D

@export var auto_register_as_follower := false
@export var follow_index := 0
@export var follow_speed := 60.0
@export var min_stop_distance := 2.0
@export var pixel_step := 1.0
@export var diagonal_axis_lock_threshold := 0.06
@export var idle_grace_time := 0.08

var is_follower := true
var _idle_grace_left := 0.0
var _accum := 0.0
var _last_anim_dir := Vector2.DOWN

func _ready() -> void:
	# Default behavior: candidate in scene, inactive until SetFollowers(add).
	# Optional auto mode kept for quick tests.
	if auto_register_as_follower:
		is_follower = true
		passability = "Passable"
		if not is_in_group("follower_actor"):
			add_to_group("follower_actor")
	else:
		is_follower = false
		if is_in_group("follower_actor"):
			remove_from_group("follower_actor")

func follow_to_world(
	target_global: Vector2,
	delta: float,
	avoid_global: Vector2 = Vector2.INF,
	avoid_distance: float = 0.0,
	leader_dir: Vector2 = Vector2.ZERO
) -> void:
	var to_target := target_global - global_position
	var dist := to_target.length()
	if dist <= min_stop_distance:
		_accum = 0.0
		_idle_grace_left = maxf(0.0, _idle_grace_left - delta)
		if _idle_grace_left > 0.0:
			play_animation("move", _last_anim_dir)
		else:
			play_animation("idle", _last_anim_dir)
		return

	var dir := to_target / maxf(0.0001, dist)
	_accum += maxf(0.0, follow_speed) * maxf(0.0, delta)
	var step_px := maxf(0.0001, pixel_step)

	var moved_vec := Vector2.ZERO
	while _accum >= step_px:
		if dist <= min_stop_distance:
			break
		var step := dir * minf(step_px, dist)
		global_position += step
		moved_vec += step
		if avoid_distance > 0.0 and avoid_global != Vector2.INF:
			var to_avoid := global_position - avoid_global
			var d := to_avoid.length()
			if d > 0.0001 and d < avoid_distance:
				global_position = avoid_global + (to_avoid / d) * avoid_distance
		_accum -= step_px
		to_target = target_global - global_position
		dist = to_target.length()
		if dist > 0.0001:
			dir = to_target / dist

	var moved_this_frame := moved_vec.length_squared() > 0.000001
	if moved_this_frame:
		_idle_grace_left = idle_grace_time
		var anim_dir := _stable_main_direction(moved_vec, leader_dir)
		if anim_dir != Vector2.ZERO:
			_last_anim_dir = anim_dir
		play_animation("move", _last_anim_dir)
		return

	_idle_grace_left = maxf(0.0, _idle_grace_left - delta)
	if _idle_grace_left > 0.0:
		play_animation("move", _last_anim_dir)
	else:
		play_animation("idle", _last_anim_dir)

func stop_follow() -> void:
	_accum = 0.0
	_idle_grace_left = 0.0
	play_animation("idle", _last_anim_dir)

func get_facing_direction_2d() -> Vector2:
	return _last_anim_dir

func _stable_main_direction(vec: Vector2, leader_dir: Vector2 = Vector2.ZERO) -> Vector2:
	if vec.length_squared() <= 0.000001:
		return Vector2.ZERO
	var ax := absf(vec.x)
	var ay := absf(vec.y)
	var switch_margin := maxf(0.0, diagonal_axis_lock_threshold)
	var diff := absf(ax - ay)
	if diff <= switch_margin and leader_dir.length_squared() > 0.000001:
		var lax := absf(leader_dir.x)
		var lay := absf(leader_dir.y)
		if lax >= lay:
			return Vector2.RIGHT if leader_dir.x > 0.0 else Vector2.LEFT
		return Vector2.DOWN if leader_dir.y > 0.0 else Vector2.UP

	if _last_anim_dir == Vector2.LEFT or _last_anim_dir == Vector2.RIGHT:
		if ay > ax + switch_margin:
			return Vector2.DOWN if vec.y > 0.0 else Vector2.UP
		return Vector2.RIGHT if vec.x > 0.0 else Vector2.LEFT
	if _last_anim_dir == Vector2.UP or _last_anim_dir == Vector2.DOWN:
		if ax > ay + switch_margin:
			return Vector2.RIGHT if vec.x > 0.0 else Vector2.LEFT
		return Vector2.DOWN if vec.y > 0.0 else Vector2.UP

	if ax >= ay:
		return Vector2.RIGHT if vec.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if vec.y > 0.0 else Vector2.UP
