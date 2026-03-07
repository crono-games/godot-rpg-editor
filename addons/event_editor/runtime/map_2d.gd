@tool
extends Node2D
class_name Map2D

@export_storage var map_id: String = ""
@export var camera_limits_enabled: bool = true
@export var camera_limits: Rect2 = Rect2(0.0, 0.0, 0.0, 0.0)
@export var event_container: Node2D

func _ready() -> void:
	_ensure_map_id_from_scene_path()

func _ensure_map_id_from_scene_path() -> void:
	if map_id.strip_edges() != "":
		return
	var scene_path := str(get("scene_file_path"))
	if scene_path == "" and has_method("get_scene_file_path"):
		scene_path = str(get_scene_file_path())
	if scene_path == "":
		return
	map_id = scene_path.get_file().get_basename()

func get_event_container() -> Node2D:
	return get_node_or_null("EventContainer") as Node2D

func get_animation_container() -> Node2D:
	return get_node_or_null("AnimationContainer") as Node2D

func compute_world_bounds_from_tilemaps() -> Rect2:
	var has_any := false
	var out := Rect2()
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node is TileMapLayer:
			var layer_rect := _compute_layer_world_bounds(node as TileMapLayer)
			if layer_rect.size.x > 0.0 and layer_rect.size.y > 0.0:
				if not has_any:
					out = layer_rect
					has_any = true
				else:
					out = out.merge(layer_rect)
		for child in node.get_children():
			if child is Node:
				stack.push_back(child)
	return out if has_any else Rect2()

func get_effective_world_bounds() -> Rect2:
	var auto_bounds := compute_world_bounds_from_tilemaps()
	if auto_bounds.size.x > 0.0 and auto_bounds.size.y > 0.0:
		camera_limits = auto_bounds
		camera_limits_enabled = true
		return auto_bounds
	if camera_limits_enabled and camera_limits.size.x > 0.0 and camera_limits.size.y > 0.0:
		return camera_limits
	return Rect2()

func has_effective_world_bounds() -> bool:
	var bounds := get_effective_world_bounds()
	return bounds.size.x > 0.0 and bounds.size.y > 0.0

func apply_camera_limits_to(camera: Camera2D) -> bool:
	if camera == null:
		return false
	var bounds := get_effective_world_bounds()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return false
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.position.x + bounds.size.x)
	camera.limit_bottom = int(bounds.position.y + bounds.size.y)
	return true

func validate_structure() -> PackedStringArray:
	var issues := PackedStringArray()
	if get_event_container() == null:
		issues.append("Missing required child: EventContainer")
	if get_animation_container() == null:
		issues.append("Missing required child: AnimationContainer")
	if compute_world_bounds_from_tilemaps().size == Vector2.ZERO:
		issues.append("No TileMapLayer with used cells found (camera/player bounds fallback disabled).")
	return issues

func _compute_layer_world_bounds(layer: TileMapLayer) -> Rect2:
	if layer == null or layer.tile_set == null:
		return Rect2()
	var used := layer.get_used_cells()
	if used.is_empty():
		return Rect2()
	var tile_size := Vector2(layer.tile_set.tile_size)
	if tile_size == Vector2.ZERO:
		tile_size = Vector2(16.0, 16.0)
	var half := tile_size * 0.5
	var has_any := false
	var out := Rect2()
	for c in used:
		var cell := c as Vector2i
		var local_center := layer.map_to_local(cell)
		var world_center := layer.to_global(local_center)
		var r := Rect2(world_center - half, tile_size)
		if not has_any:
			out = r
			has_any = true
		else:
			out = out.merge(r)
	return out if has_any else Rect2()
