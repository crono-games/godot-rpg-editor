@tool
extends ConfirmationDialog

var scene_preview : Node3D

@onready var preview_viewport : SubViewport = %SubViewport
@onready var grid_selector : GridSelector = %GridSelector
@onready var camera : Camera3D = %Camera3D

func _ready() -> void:
	update_preview()

func update_preview() -> void:
	clear_previous_preview()
	if not duplicate_scene():
		return
	add_to_preview_viewport()
	set_viewport_size()
	set_camera_position_centered()
	grid_selector.setup(get_map_size())

func clear_previous_preview():
	if scene_preview and scene_preview.is_inside_tree():
		scene_preview.queue_free()
	scene_preview = null

func duplicate_scene() -> Node3D:
	var scene_root = EditorInterface.get_edited_scene_root() as Node3D 
	if not scene_root:
		return
	scene_preview = scene_root.duplicate(DUPLICATE_USE_INSTANTIATION | DUPLICATE_SIGNALS)
	return scene_preview

func add_to_preview_viewport() -> void:
	camera.add_sibling(scene_preview)

func set_viewport_size():
	preview_viewport.size = get_map_size() * 32

func set_camera_position_centered() -> void:
	camera.size = get_map_size().y
	camera.global_position = Vector3(get_map_size().x, 100, get_map_size().y) * 0.5

func get_map_size() -> Vector2:
	var grid_map : GridMap = scene_preview.get_node("GridMap")
	var bounds = get_gridmap_bounds(grid_map)
	return bounds.size

func get_gridmap_bounds(gridmap: GridMap) -> Rect2:
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
