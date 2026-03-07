@tool
extends VBoxContainer
class_name FlagList

@export var grid: GridContainer
@export var add_button: Button

var _state: GlobalState
var _last_ids: Array = []

func _ready():
	_apply_state()

func _refresh_ui():
	for c in grid.get_children():
		c.queue_free()

	if _state == null:
		return

	var ids := _state.get_flags().keys()
	_last_ids = ids.duplicate()

	for id in ids:
		_add_flag_row(id)

func _add_flag_row(id: String):
	var data: GlobalStateEntry = _state.get_flags().get(id)
	if data == null:
		return
	
	var name_edit := LineEdit.new()
	var checkbox := CheckBox.new()
	var remove_button := Button.new()

	name_edit.custom_minimum_size.x = 128
	name_edit.placeholder_text = "Flag Name"
	name_edit.text = data.name
		
	checkbox.text = "On"
	checkbox.button_pressed = bool(data.value)
	remove_button.text = "Delete"
	remove_button.focus_mode = Control.FOCUS_NONE

	grid.add_child(name_edit)
	grid.add_child(checkbox)
	grid.add_child(remove_button)
	name_edit.text_changed.connect(_text_changed.bind(id))
	checkbox.toggled.connect(_checkbox_toggled.bind(id))
	remove_button.pressed.connect(_on_remove_pressed.bind(id))

func _text_changed(new_text, id):
	if _state == null:
		return
	_state.set_flag_name(id, new_text)

func _checkbox_toggled(toggled_on: bool, id) -> void:
	if _state == null:
		return
	_state.set_flag_value(id, toggled_on)

func _on_add_pressed():
	if _state == null:
		return
	var label := "New Flag %d" % (_state.get_flag_count() + 1)
	_state.create_flag(label)
	_refresh_ui()

func _on_remove_pressed(id: String) -> void:
	if _state == null:
		return
	_state.remove_flag(id)
	_refresh_ui()

func generate_unique_id():
	return randi()


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
	var ids := _state.get_flags().keys()
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
	 
