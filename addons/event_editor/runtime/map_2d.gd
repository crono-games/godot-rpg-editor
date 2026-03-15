@tool
extends Node2D
class_name Map2D

@export_storage var map_id: String = ""

@export var camera_limits_enabled: bool = true
@export var camera_limits: Rect2 = Rect2()

@export var event_container: Node2D

var _bounds_cache: Rect2
var _bounds_dirty: bool = true

func _ready() -> void:
	_ensure_map_id_from_scene_path()

func _ensure_map_id_from_scene_path() -> void:
	if not map_id.is_empty():
		return

	var scene_path := scene_file_path
	if scene_path.is_empty():
		return

	map_id = scene_path.get_file().get_basename()

func mark_bounds_dirty() -> void:
	_bounds_dirty = true

func get_world_bounds() -> Rect2:
	if _bounds_dirty:
		var auto_bounds := MapBoundsService.compute_world_bounds_from_tilemaps(self)

		_bounds_cache = MapBoundsService.resolve_bounds(
			auto_bounds,
			camera_limits,
			camera_limits_enabled
		)

		_bounds_dirty = false

	return _bounds_cache

func has_world_bounds() -> bool:
	return get_world_bounds().size != Vector2.ZERO

func is_position_inside_bounds(pos: Vector2) -> bool:
	return MapBoundsService.contains_point(
		get_world_bounds(),
		pos
	)

func apply_camera_limits(camera: Camera2D) -> bool:
	if camera == null:
		return false
	var bounds := get_world_bounds()
	if bounds.size == Vector2.ZERO:
		return false

	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)

	return true


func get_event_container() -> Node2D:
	return get_node_or_null("EventContainer") as Node2D

func get_animation_container() -> Node2D:
	return get_node_or_null("AnimationContainer") as Node2D
