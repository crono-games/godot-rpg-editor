@tool
extends PositionPickerBase
class_name PositionPicker2D

var _map_size := Vector2(20, 20)
var _map_preview_root: Node2D = null
var _preview := MapPreview2D.new()

@export var camera_2d: Camera2D

func _ready() -> void:
	super._ready()
	update_preview()
	add_child(_preview)


func update_preview() -> void:
	_preview.set_scene_root_provider(_scene_root_provider)
	_preview.set_map_size_provider(_map_size_provider)
	_preview.set_default_map_size(_default_map_size)
	_preview.pixels_per_cell = _pixels_per_cell
	if not _preview.rebuild_preview(sub_viewport, camera_2d):
		return
	_map_size = _preview.map_size
	_pixels_per_cell = _preview.pixels_per_cell
	PickerPreviewSync.sync_grid_to_viewport(grid_selector, sub_viewport, _map_size, _pixels_per_cell)

func clear_previous_preview() -> void:
	_preview.clear_preview()

func _get_selected_position():
	if grid_selector == null:
		return Vector2.ZERO
	var cell := grid_selector.get_selected_cell()
	return PositionGridMapping.cell_to_world_2d(cell, _preview.map_origin, _pixels_per_cell)

func set_selected_position_world(pos: Vector3) -> void:
	if grid_selector == null:
		return
	var cell := PositionGridMapping.world_to_cell_2d(Vector2(pos.x, pos.z), _preview.map_origin, _pixels_per_cell)
	grid_selector.set_selected_cell(cell)

func _set_map(map_id: String) -> void:
	_selected_map_id = map_id
	if _map_preview_root != null and _map_preview_root.is_inside_tree():
		_map_preview_root.queue_free()
	_map_preview_root = null
	var scene_path := "%s%s.tscn" % [_map_repo.maps_path, map_id]
	var packed := load(scene_path)
	if packed is PackedScene:
		var map_node := (packed as PackedScene).instantiate()
		if map_node is Node2D:
			_map_preview_root = map_node as Node2D
	if _map_preview_root != null:
		set_scene_root_provider(func():
			return _map_preview_root
		)
		update_preview()
