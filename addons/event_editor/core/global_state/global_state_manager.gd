@tool
extends Node

signal global_state_changed

var _global_state: GlobalState
var _save_timer: Timer

const GLOBAL_STATE_PATH := "res://addons/event_editor/data/runtime/global_state.json"
const SAVE_DELAY := 0.5

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	add_child(_save_timer)
	_save_timer.timeout.connect(_on_save_timeout)

func get_global_state() -> GlobalState:
	return _global_state

func set_global_state(state: GlobalState) -> void:
	if _global_state != null and _global_state.changed.is_connected(_on_state_changed):
		_global_state.changed.disconnect(_on_state_changed)
	_global_state = state
	if _global_state != null and not _global_state.changed.is_connected(_on_state_changed):
		_global_state.changed.connect(_on_state_changed)
	emit_signal("global_state_changed")

func ensure_global_state() -> GlobalState:
	if _global_state == null:
		_global_state = GlobalState.new()
	return _global_state

func get_flag_names() -> Array:
	if _global_state == null:
		return []
	var names := []
	for entry in _global_state.get_flags().values():
		if entry == null:
			continue
		var label := str(entry.name)
		if label == "":
			label = str(entry.id)
		names.append(label)
	names.sort()
	return names

func get_variable_names() -> Array:
	if _global_state == null:
		return []
	var names := []
	for entry in _global_state.get_variables().values():
		if entry == null:
			continue
		var label := str(entry.name)
		if label == "":
			label = str(entry.id)
		names.append(label)
	names.sort()
	return names

func load_global_state(path: String = GLOBAL_STATE_PATH) -> void:
	var state := ensure_global_state()
	state.load_from_file(path)

func save_global_state(path: String = GLOBAL_STATE_PATH) -> void:
	if _global_state == null:
		return
	_global_state.save_to_file(path)

func _on_state_changed() -> void:
	if _save_timer != null:
		_save_timer.start()

func _on_save_timeout() -> void:
	save_global_state()
