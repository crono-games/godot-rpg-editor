@tool
extends VBoxContainer
class_name StateGraphicsEditor

const GRAPHICS_SLICE_HELPER = preload("res://addons/event_editor/utilities/graphics_slice_helper.gd")

@export var graphics_button: TextureButton
@export var graphics_dialog: FileDialog

@export var h_frames_spin: SpinBox
@export var v_frames_spin: SpinBox
@export var autoslice_check_box: CheckBox
@export var frame_spin_box: SpinBox
@export var offset_x_spin: SpinBox
@export var offset_y_spin: SpinBox

var _ev_command_node: StateNode
var _default_tex : Texture2D
var _updating_controls := false

func _ready() -> void:
	_default_tex = graphics_button.texture_normal
	if graphics_button != null and not graphics_button.gui_input.is_connected(_on_graphics_button_gui_input):
		graphics_button.gui_input.connect(_on_graphics_button_gui_input)
	if graphics_dialog != null and not graphics_dialog.file_selected.is_connected(_on_graphics_selected):
		graphics_dialog.file_selected.connect(_on_graphics_selected)
	if graphics_dialog != null and not graphics_dialog.files_selected.is_connected(_on_graphics_files_selected):
		graphics_dialog.files_selected.connect(_on_graphics_files_selected)
	if h_frames_spin != null and not h_frames_spin.value_changed.is_connected(_on_h_frames_changed):
		h_frames_spin.value_changed.connect(_on_h_frames_changed)
		h_frames_spin.min_value = 1
		h_frames_spin.step = 1
		h_frames_spin.rounded = true
	if v_frames_spin != null and not v_frames_spin.value_changed.is_connected(_on_v_frames_changed):
		v_frames_spin.value_changed.connect(_on_v_frames_changed)
		v_frames_spin.min_value = 1
		v_frames_spin.step = 1
		v_frames_spin.rounded = true
	if autoslice_check_box != null and not autoslice_check_box.toggled.is_connected(_on_autoslice_toggled):
		autoslice_check_box.toggled.connect(_on_autoslice_toggled)
	if frame_spin_box != null and not frame_spin_box.value_changed.is_connected(_on_frame_changed):
		frame_spin_box.value_changed.connect(_on_frame_changed)
		frame_spin_box.min_value = 0
		frame_spin_box.step = 1
		frame_spin_box.rounded = true

func setup(ev_command_node: StateNode) -> void:
	_ev_command_node = ev_command_node
	_update_graphics_button()
	_update_frames_controls()

func _on_graphics_pressed() -> void:
	if graphics_dialog == null:
		return
	graphics_dialog.popup_centered_ratio(0.8)

func _on_graphics_button_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		_clear_graphics()
		accept_event()
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_on_graphics_pressed()
		accept_event()

func _on_graphics_selected(path: String) -> void:
	if _ev_command_node == null:
		return
	var gfx := _get_graphics_dict()
	gfx["texture"] = path
	if bool(gfx.get("autoslice", false)):
		var tex := load(path)
		if tex is Texture2D:
			var suggestion := GRAPHICS_SLICE_HELPER.suggest_auto_grid(Vector2i(tex.get_size().x, tex.get_size().y))
			gfx["hframes"] = suggestion.x
			gfx["vframes"] = suggestion.y
	gfx["frame"] = 0
	_ev_command_node.set_property("graphics", gfx)
	_update_graphics_button()
	_update_frames_controls()

func _on_graphics_files_selected(paths: PackedStringArray) -> void:
	if paths.size() == 0:
		return
	_on_graphics_selected(paths[0])

func _clear_graphics() -> void:
	if _ev_command_node == null:
		return
	_ev_command_node.remove_property("graphics")
	_update_graphics_button()
	_update_frames_controls()

func _on_h_frames_changed(value: float) -> void:
	if _updating_controls:
		return
	_set_graphics_int("hframes", maxi(1, int(round(value))))

func _on_v_frames_changed(value: float) -> void:
	if _updating_controls:
		return
	_set_graphics_int("vframes", maxi(1, int(round(value))))

func _on_frame_changed(value: float) -> void:
	if _updating_controls:
		return
	_set_graphics_int("frame", maxi(0, int(round(value))))

func _set_graphics_int(key: String, value: int) -> void:
	if _ev_command_node == null:
		return
	var gfx := _get_graphics_dict()
	gfx[key] = value
	var total := maxi(1, int(gfx.get("hframes", 1)) * int(gfx.get("vframes", 1)))
	gfx["frame"] = clampi(int(gfx.get("frame", 0)), 0, total - 1)
	_ev_command_node.set_property("graphics", gfx)
	_update_graphics_button()
	_update_frames_controls()

func _on_autoslice_toggled(enabled: bool) -> void:
	if _ev_command_node == null:
		return
	var gfx := _get_graphics_dict()
	gfx["autoslice"] = enabled
	if enabled:
		var path := str(gfx.get("texture", "")).strip_edges()
		if path != "":
			var tex := load(path)
			if tex is Texture2D:
				var suggestion := GRAPHICS_SLICE_HELPER.suggest_auto_grid(Vector2i(tex.get_size().x, tex.get_size().y))
				gfx["hframes"] = suggestion.x
				gfx["vframes"] = suggestion.y
				gfx["frame"] = 0
	_ev_command_node.set_property("graphics", gfx)
	_update_graphics_button()
	_update_frames_controls()

func _get_graphics_dict() -> Dictionary:
	if _ev_command_node == null:
		return {}
	var props := _ev_command_node.properties
	var gfx = props.get("graphics", {})
	if typeof(gfx) != TYPE_DICTIONARY:
		return {}
	return (gfx as Dictionary).duplicate(true)

func _update_frames_controls() -> void:
	if _ev_command_node == null:
		return
	_updating_controls = true
	var gfx := _get_graphics_dict()
	var h := maxi(1, int(gfx.get("hframes", 1)))
	var v := maxi(1, int(gfx.get("vframes", 1)))
	var total := maxi(1, h * v)
	var frame := clampi(int(gfx.get("frame", 0)), 0, total - 1)
	var autoslice_enabled := bool(gfx.get("autoslice", false))
	if h_frames_spin != null:
		h_frames_spin.value = h
		h_frames_spin.editable = not autoslice_enabled
	if v_frames_spin != null:
		v_frames_spin.value = v
		v_frames_spin.editable = not autoslice_enabled
	if frame_spin_box != null:
		frame_spin_box.max_value = total - 1
		frame_spin_box.value = frame
		frame_spin_box.editable = true
	if autoslice_check_box != null:
		autoslice_check_box.button_pressed = autoslice_enabled
	_updating_controls = false

func _update_graphics_button() -> void:
	if graphics_button == null or _ev_command_node == null:
		return
	var props := _ev_command_node.properties
	var gfx = props.get("graphics", {})
	var path := str(gfx.get("texture", ""))
	if path == "":
		graphics_button.texture_normal = _default_tex
		graphics_button.tooltip_text = "Left click: choose graphics \nRight click: clear graphics"
		return
	var tex := load(path)
	if tex is Texture2D:
		var h := maxi(1, int(gfx.get("hframes", 1)))
		var v := maxi(1, int(gfx.get("vframes", 1)))
		var frame := int(gfx.get("frame", 0))
		graphics_button.texture_normal = GRAPHICS_SLICE_HELPER.build_atlas_preview(tex, h, v, frame)
	graphics_button.tooltip_text = "Left click: choose graphics \nRight click: clear graphics"
