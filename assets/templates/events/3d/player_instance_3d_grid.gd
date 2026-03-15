@tool
extends PlayerActor3DBase
class_name PlayerInstance3DGrid

@export var grid_size: float = 1.0
@export var grid_centered := true
@export var collide_with_world := true
@export var trigger_area: Area3D
@export var hitbox_area: Area3D

var _move_tween: Tween

func _ready() -> void:
	_common_ready("Grid", true)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _is_dialog_input_locked():
		_on_input_blocked()
		return

	var dir := _get_input_direction()
	_step_grid(dir)

func snap_to_grid() -> void:
	_snap_to_grid()

func _step_grid(dir: Vector3) -> void:
	if _moving:
		return
	if dir == Vector3.ZERO:
		update_animation(Vector3.ZERO)
		return
	var cardinal := _as_cardinal(dir)
	if cardinal == Vector3.ZERO:
		update_animation(Vector2.ZERO)
		return
	var target := position + cardinal * grid_size
	var target_global := global_position + cardinal * grid_size
	var blocked := _get_blocking_event_grid(target_global)
	if blocked != null:
		_emit_bump_event(blocked)
		update_animation(cardinal)
		update_animation(Vector2.ZERO)
		return
	if _is_world_blocked(target):
		update_animation(cardinal)
		update_animation(Vector2.ZERO)
		return
	var duration := 0.1
	if move_speed > 0.0:
		duration = maxf(0.01, grid_size / move_speed)
	_moving = true
	update_animation(cardinal)
	_stop_tween()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_LINEAR)
	_move_tween.finished.connect(func():
		_moving = false
		_snap_to_grid()
		update_animation(Vector2.ZERO)
		move_finished.emit(self)
	)

func _get_blocking_event_grid(next_global_pos: Vector3) -> Node:
	if not collide_with_events or debug_noclip:
		return null
	var radius := maxf(2.0, grid_size * 0.45)
	for node in get_tree().get_nodes_in_group("EventInstance"):
		if node == self:
			continue
		if not (node is Node3D):
			continue
		if node.has_method("blocks_player_movement") and not bool(node.call("blocks_player_movement")):
			continue
		var node_pos := (node as Node3D).global_position
		if _is_same_grid_cell(node_pos, next_global_pos) or node_pos.distance_to(next_global_pos) <= radius:
			return node
	return null

func _is_same_grid_cell(a: Vector3, b: Vector3) -> bool:
	return GridUtils.is_same_cell(_v2_to_grid3(a), _v2_to_grid3(b), grid_size, grid_centered)

func _is_world_blocked(next_pos: Vector3) -> bool:
	if not collide_with_world or debug_noclip:
		return false
	var world := get_world_3d()
	if world == null:
		return false
	var space := world.direct_space_state
	if space == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + (next_pos - position))
	q.collide_with_bodies = true
	q.collide_with_areas = false
	if area != null and is_instance_valid(area):
		q.exclude = [area.get_rid()]
	var hit := space.intersect_ray(q)
	return not hit.is_empty()

func _on_input_blocked() -> void:
	_stop_tween()
	_moving = false
	update_animation(Vector2.ZERO)

func _stop_tween() -> void:
	if _move_tween != null and _move_tween.is_running():
		_move_tween.kill()
	_move_tween = null

func _snap_to_grid() -> void:
	if grid_size <= 0.0:
		return
	var snapped := GridUtils.snap_world_to_grid(_v2_to_grid3(position), grid_size, grid_centered)
	position = Vector3(snapped.x, 0, snapped.z)

func _v2_to_grid3(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.y)

func _as_cardinal(v: Vector3) -> Vector3:
	if v == Vector3.ZERO:
		return Vector3.ZERO
	if absf(v.x) >= absf(v.y):
		return Vector3.RIGHT if v.x > 0.0 else Vector3.LEFT
	return Vector3.DOWN if v.y > 0.0 else Vector3.UP
