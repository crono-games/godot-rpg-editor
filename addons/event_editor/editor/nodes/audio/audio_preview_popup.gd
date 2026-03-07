@tool
extends PopupPanel
class_name AudioPreviewPopup

signal settings_changed(volume_db: float, pitch_scale: float)
signal stream_path_changed(stream_path: String)

@export var title_label: Label
@export var path_label: Label
@export var volume_spin: SpinBox
@export var pitch_spin: SpinBox
@export var play_button: Button
@export var stop_button: Button
@export var pick_button: Button
@export var file_dialog: FileDialog
@export var preview_player: AudioStreamPlayer

var _stream_path := ""
var _is_syncing := false

func open_for(stream_path: String, volume_db: float, pitch_scale: float) -> void:
	_stream_path = stream_path
	_is_syncing = true
	path_label.text = stream_path if stream_path != "" else "(No audio selected)"
	volume_spin.value = volume_db
	pitch_spin.value = pitch_scale
	_is_syncing = false
	popup_centered()

func set_stream_path(stream_path: String) -> void:
	_stream_path = stream_path
	if path_label != null:
		path_label.text = stream_path if stream_path != "" else "(No audio selected)"

func _on_volume_changed(value: float) -> void:
	if _is_syncing:
		return
	settings_changed.emit(value, pitch_spin.value)
	_apply_preview_params()

func _on_pitch_changed(value: float) -> void:
	if _is_syncing:
		return
	settings_changed.emit(volume_spin.value, value)
	_apply_preview_params()

func _on_play_pressed() -> void:
	if _stream_path == "":
		return
	var stream := load(_stream_path)
	if not (stream is AudioStream):
		return
	preview_player.stream = stream
	_apply_preview_params()
	preview_player.play()

func _on_stop_pressed() -> void:
	preview_player.stop()

func _on_pick_pressed() -> void:
	if file_dialog != null:
		file_dialog.popup()

func _on_file_selected(path: String) -> void:
	_stream_path = path
	if path_label != null:
		path_label.text = _stream_path
	stream_path_changed.emit(_stream_path)

func _apply_preview_params() -> void:
	if preview_player == null:
		return
	preview_player.volume_db = volume_spin.value
	preview_player.pitch_scale = maxf(0.01, pitch_spin.value)
