@tool
extends EventCommandNode
class_name VariableConditionNode

@export var variable_selector: OptionButton
@export var operator_selector: OptionButton
@export var spinbox: SpinBox

var available_variables: Array = []
var selected_variable: String = ""
var operator: String = "=="
var value := 0
var _context: EventEditorManager
var _global_state: GlobalState


func _ready() -> void:
	super._ready()
	size = Vector2.ZERO
	set_slot(0, true, 0, Color.WHITE, false, 0, Color.WHITE)
	set_slot(1, false, 0, Color.WHITE, true, 0, Color(0, 1, 0, 1))
	set_slot(2, false, 0, Color.WHITE, true, 0, Color(1, 0, 0, 1))
	variable_selector.connect("item_selected", Callable(self, "_on_variable_selected"))
	operator_selector.connect("item_selected", Callable(self, "_on_operator_selected"))
	spinbox.connect("value_changed", Callable(self, "_on_value_changed"))

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
	for i in operator_selector.item_count:
		if operator_selector.get_item_text(i) == op:
			op_idx = i
			break
	if op_idx != -1:
		operator_selector.select(op_idx)

	spinbox.value = value

func _on_variable_selected(id: int) -> void:
	set_selected_by_index(id)

func _on_operator_selected(id: int) -> void:
	var op := operator_selector.get_item_text(id)
	set_operator(op)

func _on_value_changed(v) -> void:
	set_value(v)

#region User Intention

func import_params(params: Dictionary) -> void:
	selected_variable = params.get("var_name", "")
	var cond = params.get("condition_param", {})
	operator = cond.get("operator", "==")
	value = cond.get("value", 0)
	emit_changed()

func export_params() -> Dictionary:
	return {
		"var_name": selected_variable,
		"condition_param": {"operator": operator, "value": value}
	}

func load_from_data(data: NodeData) -> void:
	_data = data
	var ctx := EventEditorManager
	if ctx != null:
		_context = ctx
		if not _context.variables_changed.is_connected(_on_variables_changed):
			_context.variables_changed.connect(_on_variables_changed)
		_global_state = _context.get_global_state()
		if _global_state != null and not _global_state.variables_changed.is_connected(_on_global_state_variables_changed):
			_global_state.variables_changed.connect(_on_global_state_variables_changed)
		_on_variables_changed(_context.get_variables())
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
	if _context == null:
		return
	_on_variables_changed(_context.get_variables())

func get_variable_options() -> Array:
	if available_variables.size() == 0 and _context != null:
		var fresh := _context.get_variables()
		if fresh.size() > 0:
			available_variables = fresh.duplicate(true)
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
