@tool
extends EventCommandNode
class_name WaitNode

@export var duration_spin: SpinBox
@export var lock_movement_check_box: CheckBox

var duration_frames: int = 30

func _ready() -> void:
	super._ready()
	size = Vector2.ZERO
	if duration_spin != null:
		duration_spin.min_value = 0
		duration_spin.step = 1
		duration_spin.rounded = true
		if not duration_spin.value_changed.is_connected(_on_duration_changed):
			duration_spin.value_changed.connect(_on_duration_changed)

func _on_changed() -> void:
	if duration_spin != null:
		duration_spin.value = duration_frames

func _on_duration_changed(value: float) -> void:
	set_duration_frames(int(round(value)))

#region User Intention

func import_params(params: Dictionary) -> void:
	if params.has("duration_frames"):
		duration_frames = maxi(0, int(params.get("duration_frames", 30)))
	elif params.has("duration_seconds"):
		duration_frames = maxi(0, int(round(float(params.get("duration_seconds", 0.5)) * 60.0)))
	else:
		duration_frames = maxi(0, int(params.get("duration", 30)))
	emit_changed()

func export_params() -> Dictionary:
	return {
		"duration_frames": duration_frames
	}

func load_from_data(data: NodeData) -> void:
	_data = data
	import_params(data.params)

func set_duration_frames(value: int) -> void:
	duration_frames = maxi(0, value)
	emit_changed()
	request_apply_changes()
