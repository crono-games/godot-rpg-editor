@tool
extends EventCommandNode
class_name ScreenShakeNode

@export var duration_spin: SpinBox
@export var strength_x_spin: SpinBox
@export var strength_y_spin: SpinBox

var duration_frames := 20
var strength_x := 6.0
var strength_y := 4.0
var wait_for_completion := false


func _on_changed() -> void:
	super._ready()
	duration_spin.value = duration_frames
	strength_x_spin.value = strength_x
	strength_y_spin.value = strength_y

func _on_duration_changed(value: float) -> void:
	set_duration_frames(int(value))

func _on_strength_x_changed(value: float) -> void:
	set_strength_x(value)

func _on_strength_y_changed(value: float) -> void:
	set_strength_y(value)

func _on_wait_completion_toggled(value: bool) -> void:
	set_wait_for_completion(value)

#region User Intention

func import_params(params: Dictionary) -> void:
	duration_frames = int(params.get("duration_frames", 20))
	strength_x = float(params.get("strength_x", 6.0))
	strength_y = float(params.get("strength_y", 4.0))
	emit_changed()

func export_params() -> Dictionary:
	return {
		"duration_frames": duration_frames,
		"strength_x": strength_x,
		"strength_y": strength_y,
		"wait_for_completion" : wait_for_completion
	}

func load_from_data(data: NodeData) -> void:
	_data = data
	import_params(data.params)

func set_duration_frames(value: int) -> void:
	var next := maxi(0, value)
	if duration_frames == next:
		return
	duration_frames = next
	emit_changed()
	request_apply_changes()

func set_strength_x(value: float) -> void:
	var next := maxf(0.0, value)
	if is_equal_approx(strength_x, next):
		return
	strength_x = next
	emit_changed()
	request_apply_changes()

func set_strength_y(value: float) -> void:
	var next := maxf(0.0, value)
	if is_equal_approx(strength_y, next):
		return
	strength_y = next
	emit_changed()
	request_apply_changes()

func set_wait_for_completion(value: bool) -> void:
	wait_for_completion = value
	emit_changed()
	request_apply_changes()
