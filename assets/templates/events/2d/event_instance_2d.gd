@tool
extends Node2D
class_name EventInstance2D

@export_storage var id: String = ""

@export_enum("Passable", "Block") var passability := "Passable"
@export var grid_size: float = 16.0
@export var grid_centered := true
@export var max_anim_cycles_per_step := 1.0

var _trigger_area_size := Vector2(16.0, 16.0)
@export var trigger_area_size: Vector2:
	get:
		return _trigger_area_size
	set(value):
		_trigger_area_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_apply_trigger_area_shape()
var _trigger_area_offset := Vector2.ZERO
@export var trigger_area_offset: Vector2:
	get:
		return _trigger_area_offset
	set(value):
		_trigger_area_offset = value
		_apply_trigger_area_shape()

@export var camera: Camera2D
@export var animation_player: AnimationPlayer
@export var sprite: Sprite2D 
@export var trigger_area: Area2D
@export var hitbox_area: Area2D

var editor_preview_enabled := false
var _anim_step_time := 0.11
var _collision_shape: CollisionShape2D
var _last_dir := Vector2.DOWN

func _enter_tree():
	add_to_group("event_instance")

func _ready() -> void:
	_apply_trigger_area_shape()

func update_animation(direction) -> void:
	if not _can_play_animation():
		return
	if direction == Vector2.ZERO:
		play_animation("idle", _last_dir)
	else:
		play_animation("move", direction)
		_last_dir = get_main_direction(direction)

func play_animation(base: String, vec: Vector2) -> void:
	if not _can_play_animation():
		return
	var dir = get_main_direction(vec)
	if dir == Vector2.ZERO:
		dir = _last_dir
	else:
		_last_dir = dir
	var dir_str = dir_to_string(dir)
	var anim_name = base + "_" + dir_str

	if str(animation_player.current_animation) != anim_name:
		animation_player.play(anim_name)

func get_main_direction(vec: Vector2) -> Vector2:
	if vec.length_squared() <= 0.000001:
		return Vector2.ZERO
	if abs(vec.x) > abs(vec.y):
		return Vector2.RIGHT if vec.x > 0 else Vector2.LEFT
	else:
		return Vector2.DOWN if vec.y > 0 else Vector2.UP

func dir_to_string(dir: Vector2) -> String:
	match dir:
		Vector2.DOWN:    return "down"
		Vector2.UP:  return "up"
		Vector2.LEFT:  return "left"
		Vector2.RIGHT: return "right"
		_:             return "down"

func blocks_player_movement() -> bool:
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

##Used to update triggers area.

func _apply_trigger_area_shape() -> void:
	var shape_node := _resolve_trigger_shape_node()
	if shape_node == null:
		return
	var shape := _unique_trigger_shape(shape_node)
	if shape == null or not (shape is RectangleShape2D):
		shape = RectangleShape2D.new()
		shape.resource_local_to_scene = true
		shape_node.shape = shape
	(shape as RectangleShape2D).size = _trigger_area_size
	shape_node.position = _trigger_area_offset

func _resolve_trigger_shape_node() -> CollisionShape2D:
	if _collision_shape != null and is_instance_valid(_collision_shape):
		return _collision_shape
	if trigger_area != null and is_instance_valid(trigger_area):
		var node := trigger_area.get_node_or_null("CollisionShape2D")
		if node is CollisionShape2D:
			_collision_shape = node
			return node
	return null

func _unique_trigger_shape(shape_node: CollisionShape2D) -> Shape2D:
	if shape_node == null:
		return null
	var shape := shape_node.shape
	if shape == null:
		return null
	if not shape.resource_local_to_scene:
		shape = shape.duplicate(true)
		shape.resource_local_to_scene = true
		shape_node.shape = shape
	return shape
