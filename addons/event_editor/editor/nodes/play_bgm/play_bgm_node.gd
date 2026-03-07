@tool
extends EventCommandNode
class_name PlayBGMNode

@export var path_line: LineEdit
@export var loop_check: CheckBox
@export var advanced_popup: AudioPreviewPopup

var stream_path := ""
var volume_db := 0.0
var pitch_scale := 1.0
var loop := true

func _ready() -> void:
	super._ready()

func _on_changed() -> void:
	path_line.text = stream_path
	loop_check.button_pressed = loop
	if advanced_popup != null:
		advanced_popup.set_stream_path(stream_path)

func _on_popup_stream_changed(path: String) -> void:
	set_stream_path(path)
	if advanced_popup != null:
		advanced_popup.set_stream_path(path)

func _on_advanced_pressed() -> void:
	advanced_popup.open_for(stream_path, volume_db, pitch_scale)

func _on_popup_settings_changed(volume_db: float, pitch_scale: float) -> void:
	set_volume_db(volume_db)
	set_pitch_scale(pitch_scale)

func _on_loop_toggled(pressed: bool) -> void:
	set_loop(pressed)

#region User Intention

func import_params(params: Dictionary) -> void:
	stream_path = str(params.get("stream_path", ""))
	volume_db = float(params.get("volume_db", 0.0))
	pitch_scale = float(params.get("pitch_scale", 1.0))
	loop = bool(params.get("loop", true))
	emit_changed()

func export_params() -> Dictionary:
	return {
		"stream_path": stream_path,
		"volume_db": volume_db,
		"pitch_scale": pitch_scale,
		"loop": loop
	}

func load_from_data(data: NodeData) -> void:
	_data = data
	import_params(data.params)

func set_stream_path(value: String) -> void:
	if stream_path == value:
		return
	stream_path = value
	emit_changed()
	request_apply_changes()

func set_volume_db(value: float) -> void:
	if is_equal_approx(volume_db, value):
		return
	volume_db = value
	emit_changed()
	request_apply_changes()

func set_pitch_scale(value: float) -> void:
	var clamped := maxf(0.01, value)
	if is_equal_approx(pitch_scale, clamped):
		return
	pitch_scale = clamped
	emit_changed()
	request_apply_changes()

func set_loop(value: bool) -> void:
	if loop == value:
		return
	loop = value
	emit_changed()
	request_apply_changes()
