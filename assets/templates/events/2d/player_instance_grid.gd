@tool
extends PlayerActor2DBase
class_name PlayerInstanceGrid

@export var grid_size: float = 16.0
@export var grid_centered := true
@export var collide_with_world := true
@export var trigger_area: Area2D
@export var hitbox_area: Area2D

var _move_tween: Tween
var _input_dir := Vector2.ZERO
var _input_time := 0.0

const MOVE_BUFFER := 0.12


func _ready() -> void:
	_common_ready("Grid", true)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _is_dialog_input_locked():
		_on_input_blocked()
		return

	process_grid_move(_delta)

func process_grid_move(delta):

	update_input(delta)

	if _input_dir == Vector2.ZERO:
		if not _moving:
			update_animation(Vector2.ZERO)
		return

	if _input_time >= MOVE_BUFFER:
		try_move(_input_dir)

func snap_to_grid() -> void:
	_snap_to_grid()

func update_input(delta):

	var dir := _get_input_direction()
	
	if dir != _input_dir:
		_input_dir = dir
		_input_time = 0.0
		if _input_dir != Vector2.ZERO:
			update_animation(_as_cardinal(_input_dir))
	else:
		_input_time += delta

func try_move(dir: Vector2) -> void:
	if _moving:
		return
	
	var cardinal := _as_cardinal(dir)
	
	if cardinal == Vector2.ZERO:
		update_animation(Vector2.ZERO)
		return
	
	if not _can_move(cardinal):
		update_animation(Vector2.ZERO)
		return
	
	_perform_move(cardinal)

func _can_move(dir: Vector2) -> bool:

	var target := position + dir * grid_size
	var target_global := global_position + dir * grid_size
	
	var blocked := _get_blocking_event_grid(target_global)
	if blocked:
		_emit_bump_event(blocked)
		return false
	
	if _is_world_blocked(target):
		return false
	
	return true

func _perform_move(dir: Vector2):

	var target := position + dir * grid_size
	var duration := _get_move_duration()

	_moving = true
	update_animation(dir)
	_sync_anim_speed_to_step(duration)

	_stop_tween()

	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", target, duration)\
		.set_trans(Tween.TRANS_LINEAR)

	_move_tween.finished.connect(_on_move_finished)

func _on_move_finished():
	_moving = false
	_snap_to_grid()
	_reset_anim_speed()
	update_animation(Vector2.ZERO)
	move_finished.emit(self)

func _get_move_duration() -> float:
	if move_speed <= 0.0:
		return 0.1
	
	return maxf(0.01, grid_size / move_speed)

func _get_blocking_event_grid(next_global_pos: Vector2) -> Node:
	if not collide_with_events or debug_noclip:
		return null
	var radius := maxf(2.0, grid_size * 0.45)
	for node in get_tree().get_nodes_in_group("event_instance"):
		if node == self:
			continue
		if not (node is Node2D):
			continue
		if node.has_method("blocks_player_movement") and not bool(node.call("blocks_player_movement")):
			continue
		var node_pos := (node as Node2D).global_position
		if _is_same_grid_cell(node_pos, next_global_pos) or node_pos.distance_to(next_global_pos) <= radius:
			return node
	return null

func _is_same_grid_cell(a: Vector2, b: Vector2) -> bool:
	return GridUtils.is_same_cell(_v2_to_grid3(a), _v2_to_grid3(b), grid_size, grid_centered)

func _is_world_blocked(next_pos: Vector2) -> bool:
	if not collide_with_world or debug_noclip:
		return false
	var world := get_world_2d()
	if world == null:
		return false
	var space := world.direct_space_state
	if space == null:
		return false
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + (next_pos - position))
	q.collide_with_bodies = true
	q.collide_with_areas = false
	if area != null and is_instance_valid(area):
		q.exclude = [area.get_rid()]
	var hit := space.intersect_ray(q)
	return not hit.is_empty()

func get_area_in_front(direction: Vector2) -> Area2D:

	var space_state = get_world_2d().direct_space_state
	
	var grid_pos = global_position / grid_size
	grid_pos = grid_pos.floor()
	
	var next_cell = grid_pos + direction
	
	var world_pos = (next_cell * grid_size) + Vector2(grid_size * 0.5, grid_size * 0.5)
	
	var query = PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var result = space_state.intersect_point(query)
	
	if result.size() > 0:
		return result[0].collider
	
	return null

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
	position = Vector2(snapped.x, snapped.z)

func _v2_to_grid3(v: Vector2) -> Vector3:
	return Vector3(v.x, 0.0, v.y)

func _as_cardinal(v: Vector2) -> Vector2:
	if v == Vector2.ZERO:
		return Vector2.ZERO
	if absf(v.x) >= absf(v.y):
		return Vector2.RIGHT if v.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if v.y > 0.0 else Vector2.UP
