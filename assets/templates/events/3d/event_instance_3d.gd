@tool
extends Node3D
class_name EventInstance3D

@export_storage var id: String = ""
@export var is_follower := false

@export_enum("Passable", "Block") var passability := "Passable"
@export var grid_size: float = 1.0
@export var grid_centered := true
@export var anim_step_time := 0.11
@export var max_anim_cycles_per_step := 1.0
@export var editor_preview_enabled := false
var _trigger_area_size := Vector3(1.0, 1.0, 1.0)
@export var trigger_area_size: Vector3:
	get:
		return _trigger_area_size
	set(value):
		_trigger_area_size = Vector3(maxf(value.x, 1.0), maxf(value.y, 1.0), maxf(value.z, 1.0) )
		_apply_trigger_area_shape()
var _trigger_area_offset := Vector3.ZERO
@export var trigger_area_offset: Vector3:
	get:
		return _trigger_area_offset
	set(value):
		_trigger_area_offset = value
		_apply_trigger_area_shape()

@export var camera: Camera3D
@export var animation_player: AnimationPlayer
@export var sprite: Sprite3D 
@export var trigger_area: Area3D
@export var hitbox_area: Area3D

var collision_shape_3D: CollisionShape3D
var _last_dir := Vector3.DOWN

func _enter_tree():
	add_to_group("event_instance")

func _ready() -> void:
	_apply_trigger_area_shape()

func update_animation(direction) -> void:
	if not _can_play_animation():
		return
	if direction == Vector3.ZERO:
		play_animation("idle", _last_dir)
	else:
		play_animation("move", direction)
		_last_dir = get_main_direction(direction)

func play_animation(base: String, vec: Vector3) -> void:
	if not _can_play_animation():
		return
	var dir = get_main_direction(vec)
	if dir == Vector3.ZERO:
		dir = _last_dir
	else:
		_last_dir = dir
	var dir_str = dir_to_string(dir)
	var anim_name = base + "_" + dir_str

	if str(animation_player.current_animation) != anim_name:
		animation_player.play(anim_name)

func get_main_direction(vec: Vector3) -> Vector3:
	if vec.length_squared() <= 0.000001:
		return Vector3.ZERO
	if abs(vec.x) > abs(vec.y):
		return Vector3.RIGHT if vec.x > 0 else Vector3.LEFT
	else:
		return Vector3.DOWN if vec.y > 0 else Vector3.UP

func dir_to_string(dir: Vector3) -> String:
	match dir:
		Vector3.DOWN:    return "down"
		Vector3.UP:  return "up"
		Vector3.LEFT:  return "left"
		Vector3.RIGHT: return "right"
		_:             return "down"

func blocks_player_movement() -> bool:
	if is_follower:
		return false
	return passability == "Block" and has_visible_graphics()

func has_visible_graphics() -> bool:
	if sprite == null or not is_instance_valid(sprite):
		return false
	if not sprite.visible:
		return false
	return sprite.texture != null

func get_trigger_area() -> Variant:
	if trigger_area != null and is_instance_valid(trigger_area):
		return trigger_area
	return null

func set_preview_mode(enabled: bool) -> void:
	editor_preview_enabled = enabled

func _can_play_animation() -> bool:
	if animation_player == null:
		return false
	if Engine.is_editor_hint() and not editor_preview_enabled:
		return false
	return true

func _apply_trigger_area_shape() -> void:
	var shape_node := _resolve_trigger_shape_node()
	if shape_node == null:
		return
	var shape := _ensure_unique_trigger_shape(shape_node)
	if shape == null or not (shape is BoxShape3D):
		shape = BoxShape3D.new()
		shape.resource_local_to_scene = true
		shape_node.shape = shape
	(shape as BoxShape3D).size = _trigger_area_size
	shape_node.position = _trigger_area_offset

func _resolve_trigger_shape_node() -> CollisionShape3D:
	if collision_shape_3D != null and is_instance_valid(collision_shape_3D):
		return collision_shape_3D
	if trigger_area != null and is_instance_valid(trigger_area):
		var node := trigger_area.get_node_or_null("CollisionShape3D")
		if node is CollisionShape3D:
			collision_shape_3D = node
			return node
	return null

func _ensure_unique_trigger_shape(shape_node: CollisionShape3D) -> Shape3D:
	if shape_node == null:
		return null
	var shape := shape_node.shape
	if shape == null:
		return null
	# Prevent shared subresource edits across multiple EventInstance3D nodes.
	if not shape.resource_local_to_scene:
		shape = shape.duplicate(true)
		shape.resource_local_to_scene = true
		shape_node.shape = shape
	return shape
