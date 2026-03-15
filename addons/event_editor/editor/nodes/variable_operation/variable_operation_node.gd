@tool
extends EventCommandNode
class_name VariableOperationNode

@export var variable_selector: OptionButton
@export var operation_selector: OptionButton
@export var spinbox: SpinBox
@export var mode_selector: OptionButton

var available_variables: Array = []
var selected_variable: String = ""
var operator: String = "+"
var value := 0
var mode: String = "ticks"
var _global_state: GlobalState


func _ready() -> void:
	super._ready()
	size = Vector2.ZERO
	variable_selector.connect("item_selected", Callable(self, "_on_variable_selected"))
	operation_selector.connect("item_selected", Callable(self, "_on_operator_selected"))
	spinbox.connect("value_changed", Callable(self, "_on_value_changed"))
	mode_selector.connect("item_selected", Callable(self, "_on_mode_selected"))

func _on_changed() -> void:
	variable_selector.clear()
	var vars := get_variable_options()
	for i in vars.size():
		variable_selector.add_item(vars[i])

	var vidx := get_selected_index()
	if vidx >= 0 and vidx < variable_selector.get_item_count():
		variable_selector.select(vidx)

	var op := operator
	var op_idx := -1
	for i in operation_selector.item_count:
		if operation_selector.get_item_text(i) == op:
			op_idx = i
			break
	if op_idx != -1:
		operation_selector.select(op_idx)

	spinbox.value = value
	var mode_idx := 0
	if mode == "seconds":
		mode_idx = 1
	if mode_selector.item_count > 0:
		mode_selector.select(mode_idx)

func _on_variable_selected(id: int) -> void:
	set_selected_by_index(id)

func _on_operator_selected(id: int) -> void:
	var op := operation_selector.get_item_text(id)
	set_operator(op)

func _on_value_changed(v) -> void:
	set_value(v)

func _on_mode_selected(id: int) -> void:
	var mode := mode_selector.get_item_text(id).to_lower()
	if mode == "seconds":
		set_mode("seconds")
	else:
		set_mode("ticks")

#region User Intention


func import_params(params: Dictionary) -> void:
	selected_variable = params.get("variable_name", "")
	operator = params.get("operator", "+")
	value = params.get("value", 0)
	mode = params.get("mode", "ticks")
	emit_changed()

func export_params() -> Dictionary:
	return {
		"variable_name": selected_variable,
		"operator": operator,
		"value": value,
		"mode": mode
	}

func load_from_data(data: NodeData) -> void:
	_data = data
	var ctx := EventEditorManager
	if ctx != null:
		_global_state = GlobalStateManager.get_global_state()
		if _global_state != null and not _global_state.variables_changed.is_connected(_on_global_state_variables_changed):
			_global_state.variables_changed.connect(_on_global_state_variables_changed)
		_on_variables_changed(GlobalStateManager.get_variable_names())
	else:
		available_variables = []
	emit_changed()

func _on_variables_changed(vars: Array) -> void:
	available_variables = vars.duplicate(true)
	if available_variables.size() == 0:
		selected_variable = ""
		emit_changed()
		return
	if available_variables.find(selected_variable) == -1:
		selected_variable = available_variables[0]
		emit_changed()
		request_apply_changes()
	else:
		emit_changed()

func _on_global_state_variables_changed() -> void:
	_on_variables_changed(GlobalStateManager.get_variable_names())

func get_variable_options() -> Array:
	return available_variables.duplicate(true)

func get_selected_index() -> int:
	var idx = available_variables.find(selected_variable)
	if idx == -1 and available_variables.size() > 0:
		return 0
	return idx

func set_selected_by_index(index: int) -> void:
	if index < 0 or index >= available_variables.size():
		return
	selected_variable = available_variables[index]
	emit_changed()
	request_apply_changes()

func set_operator(op: String) -> void:
	operator = op
	emit_changed()
	request_apply_changes()

func set_value(v) -> void:
	value = v
	emit_changed()
	request_apply_changes()

func set_mode(m: String) -> void:
	if mode == m:
		return
	mode = m
	emit_changed()
	request_apply_changes()
