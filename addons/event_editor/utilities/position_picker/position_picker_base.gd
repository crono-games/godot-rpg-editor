@tool
extends Window
class_name PositionPickerBase

signal position_confirmed(pos)
signal map_position_confirmed(map_id: String, pos)

var _scene_root_provider: Callable
var _map_size_provider: Callable
var _default_map_size := Vector2(20, 20)
var _pixels_per_cell := 8.0
var _map_repo := MapRepository.new()
var _selected_map_id := ""

@export var show_map_list := false
@export var grid_selector: GridSelector
@export var item_list: ItemList
@export var sub_viewport: SubViewport

func set_show_map_list(value: bool) -> void:
	show_map_list = value
	if item_list == null:
		return
	item_list.visible = show_map_list
	if show_map_list:
		if not item_list.item_selected.is_connected(_on_map_selected):
			item_list.item_selected.connect(_on_map_selected)
		_reload_maps()

func set_selected_map(map_id: String) -> void:
	if map_id == "":
		return
	_selected_map_id = map_id
	if item_list != null:
		for i in range(item_list.item_count):
			if item_list.get_item_text(i) == map_id:
				item_list.select(i)
				break
	_set_map(map_id)

func set_scene_root_provider(provider: Callable) -> void:
	_scene_root_provider = provider

func set_map_size_provider(provider: Callable) -> void:
	_map_size_provider = provider

func set_default_map_size(size: Vector2) -> void:
	_default_map_size = size

func set_pixels_per_cell(value: float) -> void:
	_pixels_per_cell = max(1.0, value)

func _ready() -> void:
	if item_list != null:
		set_show_map_list(show_map_list)
	if grid_selector != null:
		grid_selector.position_chosen.connect(_on_position_chosen)

func _on_position_chosen(_coords: Vector2i) -> void:
	var pos = _get_selected_position()
	position_confirmed.emit(pos)
	if show_map_list:
		map_position_confirmed.emit(_selected_map_id, pos)
	hide()

func _on_map_selected(index: int) -> void:
	if item_list == null:
		return
	var map_id := item_list.get_item_text(index)
	_set_map(map_id)

func _reload_maps() -> void:
	if item_list == null:
		return
	item_list.clear()
	var maps := _map_repo.get_maps()
	for i in maps.size():
		item_list.add_item(maps[i])
	if maps.size() > 0:
		var selected_idx := 0
		if _selected_map_id != "":
			var idx := maps.find(_selected_map_id)
			if idx >= 0:
				selected_idx = idx
		item_list.select(selected_idx)
		_set_map(maps[selected_idx])

func _get_map_size() -> Vector2:
	if _map_size_provider != null and _map_size_provider.is_valid():
		var provided = _map_size_provider.call()
		if provided is Vector2:
			return provided
	return _default_map_size

func _set_map(_map_id: String) -> void:
	push_error("PositionPickerBase._set_map must be implemented by subclasses")

func update_preview() -> void:
	push_error("PositionPickerBase.update_preview must be implemented by subclasses")

func clear_previous_preview() -> void:
	push_error("PositionPickerBase.clear_previous_preview must be implemented by subclasses")

func _get_selected_position():
	push_error("PositionPickerBase._get_selected_position must be implemented by subclasses")
	return Vector3.ZERO

func set_selected_position_world(pos: Vector3) -> void:
	if grid_selector != null:
		grid_selector.set_selected_position(pos)
