@tool
extends EventCommandNode
class_name MovePictureNode

@export var picture_id_spin: SpinBox
@export var x_spin: SpinBox
@export var y_spin: SpinBox
@export var duration_spin: SpinBox
@export var wait_check: CheckBox
@export var center_button: Button

var picture_id: int = 1
var target_position: Vector2 = Vector2.ZERO
var duration_frames: int = 30
var wait_for_completion: bool = true

func _ready() -> void:
	super._ready()
	if picture_id_spin != null and not picture_id_spin.value_changed.is_connected(_on_picture_id_changed):
		picture_id_spin.value_changed.connect(_on_picture_id_changed)
	if x_spin != null and not x_spin.value_changed.is_connected(_on_x_changed):
		x_spin.value_changed.connect(_on_x_changed)
	if y_spin != null and not y_spin.value_changed.is_connected(_on_y_changed):
		y_spin.value_changed.connect(_on_y_changed)
	if duration_spin != null and not duration_spin.value_changed.is_connected(_on_duration_changed):
		duration_spin.value_changed.connect(_on_duration_changed)
	if wait_check != null and not wait_check.toggled.is_connected(_on_wait_toggled):
		wait_check.toggled.connect(_on_wait_toggled)
	if center_button != null and not center_button.pressed.is_connected(_on_center_pressed):
		center_button.pressed.connect(_on_center_pressed)

func _on_changed() -> void:
	if picture_id_spin != null:
		picture_id_spin.value = picture_id
	if x_spin != null:
		x_spin.value = target_position.x
	if y_spin != null:
		y_spin.value = target_position.y
	if duration_spin != null:
		duration_spin.value = duration_frames
	if wait_check != null:
		wait_check.button_pressed = wait_for_completion

func _on_picture_id_changed(value: float) -> void:
	set_picture_id(int(round(value)))

func _on_x_changed(value: float) -> void:
	set_target_position(Vector2(value, target_position.y))

func _on_y_changed(value: float) -> void:
	set_target_position(Vector2(target_position.x, value))

func _on_duration_changed(value: float) -> void:
	set_duration_frames(int(round(value)))

func _on_wait_toggled(value: bool) -> void:
	set_wait_for_completion(value)

func _on_center_pressed() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or root.get_viewport() == null:
		return
	set_target_position(root.get_viewport().get_visible_rect().size * 0.5)

#region User Intention

func import_params(params: Dictionary) -> void:
	picture_id = maxi(1, int(params.get("picture_id", 1)))
	target_position = _parse_position(params.get("target_position", Vector2.ZERO))
	duration_frames = maxi(0, int(params.get("duration_frames", params.get("duration", 30))))
	wait_for_completion = bool(params.get("wait_for_completion", true))
	emit_changed()

func export_params() -> Dictionary:
	return {
		"picture_id": picture_id,
		"target_position": {
			"x": int(round(target_position.x)),
			"y": int(round(target_position.y))
		},
		"duration_frames": duration_frames,
		"wait_for_completion": wait_for_completion
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

func set_target_position(value: Vector2) -> void:
	var next := Vector2(round(value.x), round(value.y))
	if target_position == next:
		return
	target_position = next
	emit_changed()
	request_apply_changes()

func set_duration_frames(value: int) -> void:
	var next := maxi(0, value)
	if duration_frames == next:
		return
	duration_frames = next
	emit_changed()
	request_apply_changes()

func set_wait_for_completion(value: bool) -> void:
	if wait_for_completion == value:
		return
	wait_for_completion = value
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
