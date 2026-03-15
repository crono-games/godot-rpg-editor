@icon("res://addons/event_editor/icons/CharacterBody2D.svg")
@tool
extends PlayerActor2DBase
class_name PlayerInstanceGrid

@export var grid_size: float = 16.0
@export var grid_centered := true
@export var collide_with_world := true

var _move_tween: Tween
var _move_progress := 0.0
var _input_dir := Vector2.ZERO
var _input_time := 0.0

const MOVE_BUFFER := 0.12

func _ready() -> void:
	_common_ready("Grid", true)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _is_dialog_input_locked():
		_on_input_blocked()
		return
	_process_grid_move(delta)

func _process_grid_move(delta: float):
	_update_input(delta)
	if _moving:
		return
	if _input_dir == Vector2.ZERO:
		update_animation(Vector2.ZERO)
		return
	if _input_time >= MOVE_BUFFER:
		_attempt_move(_input_dir)

func _update_input(delta: float) -> void:
	var dir := _get_input_direction()
	if dir != _input_dir:
		_input_dir = dir
		_input_time = 0.0
		if dir != Vector2.ZERO:
			update_animation(dir)
	else:
		_input_time += delta

func _attempt_move(dir: Vector2) -> void:
	if _moving:
		return
	if not _can_move(dir):
		return
	_input_time = 0.0
	_perform_move(dir)

func _can_move(dir: Vector2) -> bool:
	var target := global_position + dir * grid_size
	var blocked := _get_blocking_event(target)
	if blocked:
		_emit_bump_event(blocked)
		return false

	if _is_world_blocked(dir):
		return false

	return true

func _perform_move(dir: Vector2):
	var target := global_position + dir * grid_size
	var duration := _get_move_duration()
	_moving = true
	update_animation(dir)
	_stop_tween()
	_move_tween = create_tween()
	_move_tween.tween_property(
		self,
		"global_position",
		target,
		duration
	).set_trans(Tween.TRANS_LINEAR)
	_move_tween.finished.connect(_on_move_finished)

func _on_move_finished():
	_moving = false
	_snap_to_grid()
	move_finished.emit(self)
	if _input_dir != Vector2.ZERO:
		_attempt_move(_input_dir)
	else:
		update_animation(Vector2.ZERO)

func _get_move_duration() -> float:
	if move_speed <= 0.0:
		return 0.1
	return maxf(0.01, grid_size / move_speed)

func _get_blocking_event(next_global_pos: Vector2) -> Node:
	if not collide_with_events or debug_noclip:
		return null
	var radius := maxf(2.0, grid_size * 0.45)
	for node in get_tree().get_nodes_in_group("event_instance"):
		if node == self:
			continue
		if not (node is Node2D):
			continue
		if node.has_method("blocks_player_movement") and not node.call("blocks_player_movement"):
			continue
		var node_pos := (node as Node2D).global_position
		if node_pos.distance_to(next_global_pos) <= radius:
			return node
	return null

func _is_world_blocked(dir: Vector2) -> bool:
	if not collide_with_world or debug_noclip:
		return false

	var target := global_position + dir * grid_size

	if current_map and not current_map.is_position_inside_bounds(target):
		return true

	var space := get_world_2d().direct_space_state
	var from := global_position
	var to := target

	var q := PhysicsRayQueryParameters2D.create(from, to)
	q.collide_with_bodies = true
	q.collide_with_areas = false

	if area and is_instance_valid(area):
		q.exclude = [area.get_rid()]

	var hit := space.intersect_ray(q)

	return not hit.is_empty()


func _stop_tween() -> void:
	if _move_tween and _move_tween.is_running():
		_move_tween.kill()
	_move_tween = null

func _snap_to_grid() -> void:
	if grid_size <= 0:
		return
	var snapped := GridUtils.snap_world_to_grid(
		Vector3(global_position.x, 0, global_position.y), grid_size, grid_centered)
	global_position = Vector2(snapped.x, snapped.z)

func _on_input_blocked() -> void:
	_stop_tween()
	_moving = false
	update_animation(Vector2.ZERO)
