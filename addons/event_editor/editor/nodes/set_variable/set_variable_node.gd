@tool
extends EventCommandNode
class_name SetVariableNode

@export var variable_selector: OptionButton
@export var spinbox: SpinBox

var available_variables: Array[String] = []
var selected_variable: String = ""
var value := 0
var _context: EventEditorManager
var _global_state: GlobalState

func _ready() -> void:
	super._ready()
	set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)
	variable_selector.connect("item_selected", Callable(self, "_on_variable_selected"))
	spinbox.connect("value_changed", Callable(self, "_on_value_changed"))

func _on_changed() -> void:
	variable_selector.clear()
	var items := get_variable_options()
	for i in items.size():
		variable_selector.add_item(items[i])

	var idx := get_selected_index()
	if idx >= 0 and idx < variable_selector.get_item_count():
		variable_selector.select(idx)

	spinbox.value = value

func _on_variable_selected(id: int) -> void:
	set_selected_by_index(id)

func _on_value_changed(v) -> void:
	set_value(v)

#region User Intention


func import_params(params: Dictionary) -> void:
	selected_variable = params.get("variable_name", "")
	value = params.get("value", 0)
	emit_changed()

func export_params() -> Dictionary:
	return {
		"variable_name": selected_variable,
		"value": value
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

func set_value(v) -> void:
	value = v
	emit_changed()
	request_apply_changes()
