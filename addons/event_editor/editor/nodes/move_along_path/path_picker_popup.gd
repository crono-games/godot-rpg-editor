@tool
extends ConfirmationDialog
class_name PathPickerPopup

signal points_confirmed(points: Array)

var _scene_root_provider: Callable
var _map_size_provider: Callable
var _default_map_size := Vector2(20, 20)
var _pixels_per_cell := 32.0
var _map_preview_2d := MapPreview2D.new()
#var _map_preview_3d := MapPreview3D.new()

var _points: Array[Vector2] = []

@export var sub_viewport: SubViewport
@export var camera_2d: Camera2D
@export var preview_container: Control
@export var scroll: ScrollContainer
@export var overlay: PathOverlay2D
@export var points_list: ItemList
@export var show_grid_check: CheckBox
@export var mode_selector: OptionButton
@export var zoom_label: Label
@export var curve_check: CheckBox
@export var curve_subdivisions_spin: SpinBox

var _zoom := 1.0
const STATIC_ZOOM := 1.25
var _curve_enabled := false
var _curve_subdivisions := 6
func _ready() -> void:
	add_child(_map_preview_2d)
	if has_method("get_ok_button"):
		var ok := get_ok_button()
		if ok != null:
			ok.visible = false
	if has_method("get_cancel_button"):
		var cancel := get_cancel_button()
		if cancel != null:
			cancel.visible = false
	if overlay != null:
		if not overlay.point_selected.is_connected(_on_overlay_point_selected):
			overlay.point_selected.connect(_on_overlay_point_selected)
		if not overlay.points_changed.is_connected(_on_overlay_points_changed):
			overlay.points_changed.connect(_on_overlay_points_changed)
		if not overlay.pan_requested.is_connected(_on_overlay_pan_requested):
			overlay.pan_requested.connect(_on_overlay_pan_requested)
	if show_grid_check != null and not show_grid_check.toggled.is_connected(_on_show_grid_toggled):
		show_grid_check.toggled.connect(_on_show_grid_toggled)
	if points_list != null and not points_list.item_selected.is_connected(_on_points_list_selected):
		points_list.item_selected.connect(_on_points_list_selected)
	if mode_selector != null and not mode_selector.item_selected.is_connected(_on_mode_selected):
		mode_selector.item_selected.connect(_on_mode_selected)
		if mode_selector.item_count == 0:
			mode_selector.add_item("Add")
			mode_selector.add_item("Move")
			mode_selector.add_item("Delete")
		mode_selector.select(0)
		_apply_mode("add")
	if zoom_label != null:
		zoom_label.visible = false
	if curve_check != null and not curve_check.toggled.is_connected(_on_curve_toggled):
		curve_check.toggled.connect(_on_curve_toggled)
		curve_check.button_pressed = _curve_enabled
	if curve_subdivisions_spin != null and not curve_subdivisions_spin.value_changed.is_connected(_on_curve_subdivisions_changed):
		curve_subdivisions_spin.value_changed.connect(_on_curve_subdivisions_changed)
		curve_subdivisions_spin.value = _curve_subdivisions
	_update_zoom_label()

func set_scene_root_provider(provider: Callable) -> void:
	_scene_root_provider = provider

func set_map_size_provider(provider: Callable) -> void:
	_map_size_provider = provider

func set_default_map_size(size: Vector2) -> void:
	_default_map_size = size

func set_pixels_per_cell(value: float) -> void:
	_pixels_per_cell = maxf(1.0, value)

func open_with_points(points: Array) -> void:
	_points = []
	for p in points:
		if p is Vector2:
			_points.append(p)
	_rebuild_preview()
	_refresh_list()
	popup()
	if overlay != null:
		overlay.grab_focus()

func _rebuild_preview() -> void:
	_map_preview_2d.set_scene_root_provider(_scene_root_provider)
	_map_preview_2d.set_map_size_provider(_map_size_provider)
	_map_preview_2d.set_default_map_size(_default_map_size)
	_map_preview_2d.pixels_per_cell = _pixels_per_cell
	if not _map_preview_2d.rebuild_preview(sub_viewport, camera_2d):
		return
	_pixels_per_cell = _map_preview_2d.pixels_per_cell
	if overlay != null:
		overlay.set_data(_points, _map_preview_2d.map_origin, _map_preview_2d.map_size, _pixels_per_cell)
		if show_grid_check != null:
			overlay.set_show_grid(show_grid_check.button_pressed)
		_sync_curve_preview()
	_apply_zoom()

func _refresh_list() -> void:
	if points_list == null:
		return
	points_list.clear()
	for i in _points.size():
		var p := _points[i]
		points_list.add_item("%d: (%d, %d)" % [i + 1, int(round(p.x)), int(round(p.y))])

func _on_overlay_point_selected(index: int) -> void:
	if points_list == null:
		return
	if index < 0 or index >= points_list.item_count:
		points_list.deselect_all()
		return
	points_list.select(index)

func _on_points_list_selected(index: int) -> void:
	if overlay != null:
		overlay.set_selected_index(index)

func _on_show_grid_toggled(value: bool) -> void:
	if overlay != null:
		overlay.set_show_grid(value)

func _on_remove_pressed() -> void:
	if points_list == null:
		return
	var selected := points_list.get_selected_items()
	if selected.is_empty():
		return
	var index := int(selected[0])
	if index < 0 or index >= _points.size():
		return
	_points.remove_at(index)
	_refresh_list()
	_rebuild_preview()

func _on_clear_pressed() -> void:
	_points.clear()
	_refresh_list()
	_rebuild_preview()

func _on_cancel_pressed() -> void:
	hide()

func _on_apply_pressed() -> void:
	points_confirmed.emit(_build_output_points())
	hide()

func set_curve_enabled(value: bool) -> void:
	_curve_enabled = value
	if curve_check != null:
		curve_check.button_pressed = _curve_enabled

func get_curve_enabled() -> bool:
	return _curve_enabled

func set_curve_subdivisions(value: int) -> void:
	_curve_subdivisions = maxi(1, value)
	if curve_subdivisions_spin != null:
		curve_subdivisions_spin.value = _curve_subdivisions

func get_curve_subdivisions() -> int:
	return _curve_subdivisions

func _on_overlay_points_changed(points: Array) -> void:
	_points = []
	for p in points:
		if p is Vector2:
			_points.append(p)
	_refresh_list()
	_sync_curve_preview()

func _on_overlay_pan_requested(delta: Vector2) -> void:
	if scroll == null:
		return
	scroll.scroll_horizontal -= int(round(delta.x))
	scroll.scroll_vertical -= int(round(delta.y))
	_clamp_scroll()

func _on_mode_selected(index: int) -> void:
	if mode_selector == null:
		return
	var mode := str(mode_selector.get_item_text(index)).to_lower()
	_apply_mode(mode)

func _on_curve_toggled(value: bool) -> void:
	_curve_enabled = value
	_sync_curve_preview()

func _on_curve_subdivisions_changed(value: float) -> void:
	_curve_subdivisions = maxi(1, int(round(value)))
	_sync_curve_preview()

func _apply_mode(mode: String) -> void:
	if overlay != null:
		overlay.set_interaction_mode(mode)

func _apply_zoom() -> void:
	if preview_container == null:
		return
	_zoom = STATIC_ZOOM
	var base_size := _map_preview_2d.map_size * _pixels_per_cell
	preview_container.custom_minimum_size = base_size * _zoom
	preview_container.size = preview_container.custom_minimum_size
	preview_container.scale = Vector2.ONE * _zoom
	_update_zoom_label()
	_clamp_scroll()

func _update_zoom_label() -> void:
	if zoom_label != null:
		zoom_label.text = "%d%%" % int(round(_zoom * 100.0))

func _clamp_scroll() -> void:
	if scroll == null:
		return
	var hbar := scroll.get_h_scroll_bar()
	var vbar := scroll.get_v_scroll_bar()
	if hbar != null:
		scroll.scroll_horizontal = clampi(scroll.scroll_horizontal, 0, int(hbar.max_value))
	if vbar != null:
		scroll.scroll_vertical = clampi(scroll.scroll_vertical, 0, int(vbar.max_value))

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode != KEY_DELETE and key.keycode != KEY_BACKSPACE:
		return
	var index := -1
	if points_list != null:
		var sel := points_list.get_selected_items()
		if not sel.is_empty():
			index = int(sel[0])
	if index < 0 and overlay != null:
		index = overlay.selected_index
	if index < 0 or index >= _points.size():
		return
	_points.remove_at(index)
	_refresh_list()
	_rebuild_preview()

func _build_output_points() -> Array:
	if not _curve_enabled:
		return _points.duplicate(true)
	return _build_catmull_rom_points(_points, _curve_subdivisions)

func _build_catmull_rom_points(control: Array[Vector2], subdivisions: int) -> Array:
	if control.size() < 3:
		return control.duplicate(true)
	var out: Array = []
	var steps := maxi(1, subdivisions)
	for i in range(control.size() - 1):
		var p0 := control[maxi(i - 1, 0)]
		var p1 := control[i]
		var p2 := control[i + 1]
		var p3 := control[mini(i + 2, control.size() - 1)]
		if i == 0:
			out.append(Vector2(round(p1.x), round(p1.y)))
		for s in range(1, steps + 1):
			var t := float(s) / float(steps)
			var t2 := t * t
			var t3 := t2 * t
			var q := 0.5 * (
				(2.0 * p1) +
				(-p0 + p2) * t +
				(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
				(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
			)
			out.append(Vector2(round(q.x), round(q.y)))
	return out

func _sync_curve_preview() -> void:
	if overlay == null:
		return
	if not _curve_enabled:
		overlay.set_curve_preview([])
		return
	overlay.set_curve_preview(_build_catmull_rom_points(_points, _curve_subdivisions))
