@tool
extends Node
class_name MapPreview2D

var scene_preview: Node2D = null
var map_size := Vector2(20, 20)
var map_origin := Vector2.ZERO
var pixels_per_cell := 32.0

var _scene_root_provider: Callable
var _map_size_provider: Callable
var _default_map_size := Vector2(20, 20)

func set_scene_root_provider(provider: Callable) -> void:
	_scene_root_provider = provider

func set_map_size_provider(provider: Callable) -> void:
	_map_size_provider = provider

func set_default_map_size(size: Vector2) -> void:
	_default_map_size = size

func clear_preview() -> void:
	if scene_preview != null and scene_preview.is_inside_tree():
		scene_preview.queue_free()
	scene_preview = null

func rebuild_preview(sub_viewport: SubViewport, camera_2d: Camera2D) -> bool:
	clear_preview()
	if not _duplicate_scene():
		return false
	if sub_viewport != null:
		sub_viewport.add_child(scene_preview)

	map_size = _resolve_map_size()
	map_origin = _resolve_map_origin()
	pixels_per_cell = _resolve_pixels_per_cell()

	if scene_preview != null:
		scene_preview.position = -map_origin  # alinea top-left del mapa a (0,0) del viewport

	if sub_viewport != null:
		sub_viewport.size = Vector2i(map_size * pixels_per_cell)

	if camera_2d != null and sub_viewport != null:
		# Keep camera behavior consistent across pickers/scenes.
		# Some popup scenes had ANCHOR_MODE_FIXED_TOP_LEFT, which offsets preview alignment.
		camera_2d.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
		camera_2d.offset = Vector2.ZERO
		camera_2d.position = Vector2(sub_viewport.size) * 0.5
		camera_2d.zoom = Vector2.ONE

		_force_camera_2d(sub_viewport, camera_2d)
	return true

func _duplicate_scene() -> bool:
	var scene_root: Node2D = null
	if _scene_root_provider != null and _scene_root_provider.is_valid():
		scene_root = _scene_root_provider.call()
	if scene_root == null:
		return false
	scene_preview = scene_root.duplicate(DUPLICATE_USE_INSTANTIATION | DUPLICATE_SIGNALS)
	return scene_preview != null

func _resolve_map_size() -> Vector2:
	var tilemap := _find_tilemap(scene_preview)
	if tilemap != null:
		var used: Rect2i = tilemap.get_used_rect()
		if used.size != Vector2i.ZERO:
			return Vector2(used.size.x, used.size.y)
	if _map_size_provider != null and _map_size_provider.is_valid():
		var provided = _map_size_provider.call()
		if provided is Vector2:
			return provided
	return _default_map_size

func _resolve_map_origin() -> Vector2:
	var tilemap := _find_tilemap(scene_preview)
	if tilemap == null:
		return Vector2.ZERO
	var used: Rect2i = tilemap.get_used_rect()
	if used.size == Vector2i.ZERO:
		return Vector2.ZERO

	var cell_center := tilemap.to_global(tilemap.map_to_local(used.position))
	var half_cell := Vector2(_resolve_pixels_per_cell(), _resolve_pixels_per_cell()) * 0.5
	var top_left := cell_center - half_cell
	return Vector2(top_left.x, top_left.y)

func _resolve_pixels_per_cell() -> float:
	var tilemap := _find_tilemap(scene_preview)
	if tilemap != null and tilemap.tile_set != null:
		var tile_size := tilemap.tile_set.tile_size
		if tile_size.x > 0:
			return float(tile_size.x)
	return pixels_per_cell

func _find_tilemap(root: Node) -> TileMapLayer:
	if root == null:
		return null
	if root is TileMapLayer:
		return root as TileMapLayer
	for child in root.get_children():
		if child is Node:
			var found := _find_tilemap(child)
			if found != null:
				return found
	return null

func _force_camera_2d(sub_viewport: SubViewport, camera_2d: Camera2D) -> void:
	if sub_viewport == null or camera_2d == null:
		return
	var stack: Array[Node] = [sub_viewport]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node is Camera2D and node != camera_2d:
			(node as Camera2D).enabled = false
		for child in node.get_children():
			if child is Node:
				stack.push_back(child)
	camera_2d.enabled = true
