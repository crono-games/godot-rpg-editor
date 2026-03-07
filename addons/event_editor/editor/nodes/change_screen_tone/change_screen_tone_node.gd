@tool
extends EventCommandNode
class_name ChangeScreenToneNode

@export var color_picker: ColorPickerButton
@export var duration_spin: SpinBox

var color := Color(1, 1, 1, 1)
var duration_frames := 0
var wait_for_completion := false


func _ready() -> void:
	if color_picker != null:
		color_picker.connect("color_changed", Callable(self, "_on_color_changed"))
	if duration_spin != null:
		duration_spin.connect("value_changed", Callable(self, "_on_duration_changed"))

func _on_changed() -> void:
	if color_picker != null:
		color_picker.color = color
	if duration_spin != null:
		duration_spin.value = duration_frames

func _on_color_changed(c: Color) -> void:
	set_color(c)

func _on_duration_changed(v: float) -> void:
	set_duration_frames(int(round(v)))

func _on_wait_completion_toggled(value: bool) -> void:
	set_wait_for_completion(value)

#region User Intention
func load_from_data(data: NodeData) -> void:
	pass

func import_params(params: Dictionary) -> void:
	var c = params.get("color", {})
	var r = float(c.get("r", 255.0)) / 255.0
	var g = float(c.get("g", 255.0)) / 255.0
	var b := float(c.get("b", 255.0)) / 255.0
	var a = float(c.get("a", 255.0)) / 255.0
	color = Color(r, g, b, a)
	if params.has("duration_frames"):
		duration_frames = maxi(0, int(params.get("duration_frames", 0)))
	else:
		duration_frames = maxi(0, int(params.get("duration", 0)))
	emit_changed()

func export_params() -> Dictionary:
	return {
		"color": {
			"r": int(round(color.r * 255.0)),
			"g": int(round(color.g * 255.0)),
			"b": int(round(color.b * 255.0)),
			"a": int(round(color.a * 255.0))
		},
		"duration_frames": duration_frames
	}

func set_color(c: Color) -> void:
	if color == c:
		return
	color = c
	emit_changed()
	request_apply_changes()

func set_color_channel(r: int, g: int, b: int, a: int) -> void:
	var nr = clamp(float(r) / 255.0, 0.0, 1.0)
	var ng = clamp(float(g) / 255.0, 0.0, 1.0)
	var nb = clamp(float(b) / 255.0, 0.0, 1.0)
	var na = clamp(float(a) / 255.0, 0.0, 1.0)
	set_color(Color(nr, ng, nb, na))

func set_duration_frames(v: int) -> void:
	var next := maxi(0, v)
	if duration_frames == next:
		return
	duration_frames = next
	emit_changed()
	request_apply_changes()

func set_wait_for_completion(value: bool) -> void:
	wait_for_completion = value
	emit_changed()
	request_apply_changes()
