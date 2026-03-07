@tool
extends EventCommandNode
class_name ShowPictureNode

@export var texture_name: LineEdit
@export var button_load: Button
@export var button_pick_position: Button
@export var file_dialog: FileDialog
@export var picture_id_spin: SpinBox
@export var x_spin: SpinBox
@export var y_spin: SpinBox
@export var centered_check: CheckBox
@export var z_index_spin: SpinBox

var picture_id: int = 1
var texture_path: String = ""
var screen_position: Vector2 = Vector2.ZERO
var centered: bool = false
var zindex: int = 0

func _ready() -> void:
	super._ready()
	if button_load != null and not button_load.pressed.is_connected(_on_load_pressed):
		button_load.pressed.connect(_on_load_pressed)
	if button_pick_position != null and not button_pick_position.pressed.is_connected(_on_pick_position_pressed):
		button_pick_position.pressed.connect(_on_pick_position_pressed)
	if file_dialog != null and not file_dialog.file_selected.is_connected(_on_file_selected):
		file_dialog.file_selected.connect(_on_file_selected)
	if texture_name != null and not texture_name.text_submitted.is_connected(_on_texture_submitted):
		texture_name.text_submitted.connect(_on_texture_submitted)
	if picture_id_spin != null and not picture_id_spin.value_changed.is_connected(_on_picture_id_changed):
		picture_id_spin.value_changed.connect(_on_picture_id_changed)
	if x_spin != null and not x_spin.value_changed.is_connected(_on_x_changed):
		x_spin.value_changed.connect(_on_x_changed)
	if y_spin != null and not y_spin.value_changed.is_connected(_on_y_changed):
		y_spin.value_changed.connect(_on_y_changed)
	if centered_check != null and not centered_check.toggled.is_connected(_on_centered_toggled):
		centered_check.toggled.connect(_on_centered_toggled)
	if z_index_spin != null and not z_index_spin.value_changed.is_connected(_on_z_index_changed):
		z_index_spin.value_changed.connect(_on_z_index_changed)

func _on_changed() -> void:
	if texture_name != null:
		texture_name.text = texture_path
	if picture_id_spin != null:
		picture_id_spin.value = picture_id
	if x_spin != null:
		x_spin.value = screen_position.x
	if y_spin != null:
		y_spin.value = screen_position.y
	if centered_check != null:
		centered_check.button_pressed = centered
	if z_index_spin != null:
		z_index_spin.value = zindex

func _on_load_pressed() -> void:
	if file_dialog != null:
		file_dialog.popup()

func _on_pick_position_pressed() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or root.get_viewport() == null:
		return
	var size := root.get_viewport().get_visible_rect().size
	set_screen_position(size * 0.5)

func _on_file_selected(path: String) -> void:
	set_texture_path(path)

func _on_texture_submitted(value: String) -> void:
	set_texture_path(value)

func _on_picture_id_changed(value: float) -> void:
	set_picture_id(int(round(value)))

func _on_x_changed(value: float) -> void:
	set_screen_position(Vector2(value, screen_position.y))

func _on_y_changed(value: float) -> void:
	set_screen_position(Vector2(screen_position.x, value))

func _on_centered_toggled(value: bool) -> void:
	set_centered(value)

func _on_z_index_changed(value: float) -> void:
	set_z_index(int(round(value)))

#region User Intention


func import_params(params: Dictionary) -> void:
	picture_id = maxi(1, int(params.get("picture_id", 1)))
	texture_path = str(params.get("texture_path", params.get("texture", ""))).strip_edges()
	screen_position = _parse_position(params.get("screen_position", Vector2.ZERO))
	centered = bool(params.get("centered", false))
	zindex = int(params.get("z_index", 0))
	emit_changed()

func export_params() -> Dictionary:
	return {
		"picture_id": picture_id,
		"texture_path": texture_path,
		"screen_position": {
			"x": int(round(screen_position.x)),
			"y": int(round(screen_position.y))
		},
		"centered": centered,
		"z_index": zindex
	}

func load_from_data(data: NodeData) -> void:
	_data = data
	import_params(data.params)

func set_picture_id(value: int) -> void:
	var next := maxi(1, value)
	if picture_id == next:
		return
	picture_id = next
	emit_changed()
	request_apply_changes()

func set_texture_path(value: String) -> void:
	var next := value.strip_edges()
	if texture_path == next:
		return
	texture_path = next
	emit_changed()
	request_apply_changes()

func set_screen_position(value: Vector2) -> void:
	var next := Vector2(round(value.x), round(value.y))
	if screen_position == next:
		return
	screen_position = next
	emit_changed()
	request_apply_changes()

func set_centered(value: bool) -> void:
	if centered == value:
		return
	centered = value
	emit_changed()
	request_apply_changes()

func set_z_index(value: int) -> void:
	if zindex == value:
		return
	zindex = value
	emit_changed()
	request_apply_changes()

func _parse_position(value) -> Vector2:
	if value is Vector2:
		return Vector2(round(value.x), round(value.y))
	if value is Dictionary:
		return Vector2(
			round(float(value.get("x", 0.0))),
			round(float(value.get("y", 0.0)))
		)
	if value is Array and value.size() >= 2:
		return Vector2(round(float(value[0])), round(float(value[1])))
	return Vector2.ZERO
