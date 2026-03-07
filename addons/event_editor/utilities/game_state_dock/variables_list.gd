@tool
extends VBoxContainer

class_name VariableList

@export var grid: GridContainer
@export var add_button: Button

var _state: GlobalState
var _last_ids: Array = []

func _ready() -> void:
	_apply_state()

func _refresh_ui():
	var t0 := Time.get_ticks_msec()
	for c in grid.get_children():
		c.queue_free()

	if _state == null:
		return

	var ids := _state.get_variables().keys()
	_last_ids = ids.duplicate()

	for id in ids:
		_add_var_row(id)

func _add_var_row(id: String):
	var data: GlobalStateEntry = _state.get_variables().get(id)
	if data == null:
		return
	
	var name_edit := LineEdit.new()
	var remove_button := Button.new()
	
	name_edit.custom_minimum_size.x = 128
	name_edit.placeholder_text = "Variable name"
	name_edit.text = data.name

	var spin := SpinBox.new()
	spin.min_value = -999999
	spin.max_value = 999999
	spin.value = int(data.value)
	remove_button.text = "Delete"
	remove_button.focus_mode = Control.FOCUS_NONE

	grid.add_child(name_edit)
	grid.add_child(spin)
	grid.add_child(remove_button)
	
	name_edit.text_changed.connect(_text_changed.bind(id))
	spin.value_changed.connect(_value_changed.bind(id))
	remove_button.pressed.connect(_on_remove_pressed.bind(id))


func _text_changed(new_text, id):
	if _state == null:
		return
	_state.set_variable_name(id, new_text)

func _value_changed(value: int, id) -> void:
	if _state == null:
		return
	_state.set_variable_value(id, value)

func _on_add_pressed() -> void:
	if _state == null:
		return
	_state.create_variable()
	_refresh_ui()

func _on_remove_pressed(id: String) -> void:
	if _state == null:
		return
	_state.remove_variable(id)
	_refresh_ui()


func set_global_state(state: GlobalState) -> void:
	if _state != null and _state.changed.is_connected(_on_state_changed):
		_state.changed.disconnect(_on_state_changed)

	_state = state
	_apply_state()


func _apply_state() -> void:
	if _state == null:
		return

	if not _state.changed.is_connected(_on_state_changed):
		_state.changed.connect(_on_state_changed)

	_refresh_ui()


func _on_state_changed() -> void:
	if _state == null:
		return
	var ids := _state.get_variables().keys()
	if _should_rebuild(ids):
		_refresh_ui()


func _should_rebuild(ids: Array) -> bool:
	if ids.size() != _last_ids.size():
		return true
	var sorted_ids := ids.duplicate()
	var sorted_last := _last_ids.duplicate()
	sorted_ids.sort()
	sorted_last.sort()
	return sorted_ids != sorted_last
