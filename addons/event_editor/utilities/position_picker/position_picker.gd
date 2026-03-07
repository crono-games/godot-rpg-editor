@tool
extends PositionPickerBase
class_name PositionPicker

var scene_preview: Node3D
var _base_camera_size := 1.0
var _map_size := Vector2(20, 20)
var _map_origin := Vector2.ZERO
var _map_preview_root: Node3D = null

@export var camera: Camera3D

func _ready() -> void:
	super._ready()
	if grid_selector != null:
		grid_selector.view_changed.connect(_on_view_changed)
	update_preview()

func update_preview() -> void:
	clear_previous_preview()
	if not _duplicate_scene():
		return
	_add_to_preview_viewport()
	_map_size = _get_map_size()
	_map_origin = _get_map_origin()
	_set_viewport_size()
	_reset_view()
	if grid_selector != null:
		grid_selector.cell_size = int(_pixels_per_cell)
		grid_selector.setup(_map_size)

func clear_previous_preview() -> void:
	if scene_preview and scene_preview.is_inside_tree():
		scene_preview.queue_free()
	scene_preview = null

func _duplicate_scene() -> bool:
	var scene_root: Node3D = null
	if _scene_root_provider != null and _scene_root_provider.is_valid():
		scene_root = _scene_root_provider.call()
	if not scene_root:
		return false
	scene_preview = scene_root.duplicate(DUPLICATE_USE_INSTANTIATION | DUPLICATE_SIGNALS)
	return scene_preview != null

func _add_to_preview_viewport() -> void:
	if sub_viewport != null:
		sub_viewport.add_child(scene_preview)
	_force_picker_camera()

func _set_viewport_size() -> void:
	if sub_viewport != null:
		sub_viewport.size = _map_size * _pixels_per_cell

func _reset_view() -> void:
	_base_camera_size = max(1.0, _map_size.y)
	_apply_view()

func _apply_view() -> void:
	if camera != null:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = _base_camera_size
		camera.global_position = Vector3(_map_origin.x + _map_size.x * 0.5, 100, _map_origin.y + _map_size.y * 0.5)
		camera.rotation_degrees = Vector3(-90, 0, 0)
		_force_picker_camera()
	if grid_selector != null:
		var pixels_per_unit := 1.0
		if sub_viewport != null and camera != null:
			pixels_per_unit = float(sub_viewport.size.y) / (camera.size * 2.0)
		var grid_zoom := pixels_per_unit / float(grid_selector.cell_size)
		var world_center := Vector2(camera.global_position.x, camera.global_position.z)
		var local_center := world_center - _map_origin
		var viewport_center := Vector2(sub_viewport.size.x * 0.5, sub_viewport.size.y * 0.5)
		var grid_offset := viewport_center - local_center * (grid_zoom * grid_selector.cell_size)
		grid_selector.set_view(grid_zoom, grid_offset)

func _on_view_changed(_zoom_value: float, _offset_value: Vector2) -> void:
	_apply_view()

func _get_selected_position():
	if grid_selector == null:
		return Vector3.ZERO
	var cell = grid_selector.get_selected_cell()
	var pos := Vector3(
		_map_origin.x + float(cell.x) + 0.5,
		0.0,
		_map_origin.y + float(cell.y) + 0.5
	)
	return _snap_to_ground(pos)

func set_selected_position_world(pos: Vector3) -> void:
	if grid_selector == null:
		return
	var cell_x := int(floor(pos.x - _map_origin.x))
	var cell_y := int(floor(pos.z - _map_origin.y))
	grid_selector.set_selected_cell(Vector2i(cell_x, cell_y))

func _snap_to_ground(pos: Vector3) -> Vector3:
	if scene_preview == null:
		return pos
	var space_state := scene_preview.get_world_3d().direct_space_state
	if space_state == null:
		return pos
	var origin := Vector3(pos.x, pos.y + 100.0, pos.z)
	var target := Vector3(pos.x, pos.y - 100.0, pos.z)
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space_state.intersect_ray(query)
	if hit.has("position"):
		var hit_pos: Vector3 = hit["position"]
		return Vector3(pos.x, hit_pos.y, pos.z)
	return pos

func _set_map(map_id: String) -> void:
	_selected_map_id = map_id
	if _map_preview_root != null and _map_preview_root.is_inside_tree():
		_map_preview_root.queue_free()
	_map_preview_root = _map_repo.instantiate_map_3d(map_id)
	if _map_preview_root != null:
		set_scene_root_provider(func():
			return _map_preview_root
		)
		update_preview()

func _get_map_size() -> Vector2:
	var base := super._get_map_size()
	if _map_size_provider != null and _map_size_provider.is_valid():
		return base
	var grid_map := _find_gridmap(scene_preview)
	if grid_map != null:
		var bounds = _get_gridmap_bounds(grid_map)
		if bounds.size != Vector2.ZERO:
			return bounds.size
	return base

func _get_map_origin() -> Vector2:
	var grid_map := _find_gridmap(scene_preview)
	if grid_map != null:
		var bounds = _get_gridmap_bounds(grid_map)
		return bounds.position
	return Vector2.ZERO

func _find_gridmap(root: Node) -> GridMap:
	if root is GridMap:
		return root
	for child in root.get_children():
		var found := _find_gridmap(child)
		if found != null:
			return found
	return null

func _get_gridmap_bounds(gridmap: GridMap) -> Rect2:
	var used_cells = gridmap.get_used_cells()
	if used_cells.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var min_x = INF
	var max_x = -INF
	var min_z = INF
	var max_z = -INF
	for cell in used_cells:
		min_x = min(min_x, cell.x)
		max_x = max(max_x, cell.x)
		min_z = min(min_z, cell.z)
		max_z = max(max_z, cell.z)
	var width = max_x - min_x + 1
	var height = max_z - min_z + 1
	return Rect2(Vector2(min_x, min_z), Vector2(width, height))

func _force_picker_camera() -> void:
	if sub_viewport == null or camera == null:
		return
	var stack: Array[Node] = [sub_viewport]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node is Camera3D and node != camera:
			(node as Camera3D).current = false
		for child in node.get_children():
			if child is Node:
				stack.push_back(child)
	camera.current = true
