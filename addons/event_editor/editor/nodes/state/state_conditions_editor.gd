@tool
extends VBoxContainer
class_name StateConditionsEditor

const VAR_OPS := ["==", "!=", "<", "<=", ">", ">="]
const SCOPE_OPTIONS := ["global", "local"]
const SCOPE_LABELS := ["Global", "Local"]
const LOCAL_FLAG_OPTIONS := ["A", "B", "C", "D"]
const LOCAL_VAR_OPTIONS := ["A", "B", "C", "D"]

@export var flags_container: VBoxContainer
@export var add_flag_button: Button
@export var variables_container: VBoxContainer
@export var add_variable_button: Button

var _ev_command_node: StateNode
var _context: EventEditorManager
var _global_state: GlobalState
var _loading := false
var _available_flags: Array = []
var _available_variables: Array = []

func _ready() -> void:
	if add_flag_button != null and not add_flag_button.pressed.is_connected(_on_add_flag_pressed):
		add_flag_button.pressed.connect(_on_add_flag_pressed)
	if add_variable_button != null and not add_variable_button.pressed.is_connected(_on_add_variable_pressed):
		add_variable_button.pressed.connect(_on_add_variable_pressed)

func setup(ev_command_node: StateNode, context: EventEditorManager) -> void:
	_ev_command_node = ev_command_node
	_context = context
	_global_state = GlobalStateManager.get_global_state()
	_bind_global_state_signals()
	_refresh_options()
	_load_from_ev_command_node()

func apply_conditions() -> void:
	_apply_conditions()

func _bind_global_state_signals() -> void:
	if _global_state == null:
		return
	if not _global_state.flags_changed.is_connected(_on_global_flags_changed):
		_global_state.flags_changed.connect(_on_global_flags_changed)
	if not _global_state.variables_changed.is_connected(_on_global_variables_changed):
		_global_state.variables_changed.connect(_on_global_variables_changed)

func _refresh_options() -> void:
	if _global_state == null:
		_available_flags = []
		_available_variables = []
		return
	_available_flags = GlobalStateManager.get_flag_names()
	_available_variables = GlobalStateManager.get_variable_names()

func _load_from_ev_command_node() -> void:
	if _ev_command_node == null:
		return
	_loading = true
	_clear_rows(flags_container)
	_clear_rows(variables_container)

	var conditions := _ev_command_node.get_conditions()
	var flags = conditions.get("flags", [])
	var variables = conditions.get("variables", [])

	for f in flags:
		var scope := str(f.get("scope", "global"))
		var name := str(f.get("name", f.get("flag", "")))
		var value := bool(f.get("value", true))
		_add_flag_row(scope, name, value)
	for v in variables:
		var scope := str(v.get("scope", "global"))
		var name := str(v.get("name", v.get("var", "")))
		_add_variable_row(scope, name, str(v.get("op", "==")), v.get("value", 0))

	_loading = false
	_apply_conditions()

func _on_add_flag_pressed() -> void:
	_add_flag_row("global", "", true)
	_apply_conditions()

func _on_add_variable_pressed() -> void:
	_add_variable_row("global", "", "==", 0)
	_apply_conditions()

func _on_global_flags_changed() -> void:
	_available_flags = GlobalStateManager.get_flag_names()
	_refresh_row_options(flags_container, _available_flags)

func _on_global_variables_changed() -> void:
	_available_variables = GlobalStateManager.get_variable_names()
	_refresh_row_options(variables_container, _available_variables)

func _add_flag_row(scope: String, selected_name: String, value: bool) -> void:
	if flags_container == null:
		return
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scope_select := OptionButton.new()
	for label in SCOPE_LABELS:
		scope_select.add_item(label)
	scope_select.select(max(0, SCOPE_OPTIONS.find(scope)))
	var flag_select := OptionButton.new()
	flag_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill_option_items(flag_select, _get_flag_options_for_scope(scope))
	_select_option_by_text(flag_select, selected_name)
	var value_check := CheckBox.new()
	value_check.text = "On"
	value_check.button_pressed = value
	var remove_btn := Button.new()
	remove_btn.icon = load("res://addons/event_editor/icons/Remove.svg")
	remove_btn.focus_mode = Control.FOCUS_NONE
	var lbl := Label.new()
	lbl.text = "is"
	row.add_child(scope_select)
	row.add_child(flag_select)
	row.add_child(lbl)
	row.add_child(value_check)
	row.add_child(remove_btn)
	flags_container.add_child(row)

	scope_select.item_selected.connect(func(_idx):
		var scope_value := _scope_from_index(scope_select.selected)
		_fill_option_items(flag_select, _get_flag_options_for_scope(scope_value))
		_select_option_by_text(flag_select, "")
		_apply_conditions()
	)
	flag_select.item_selected.connect(_on_row_changed)
	value_check.toggled.connect(_on_row_changed)
	remove_btn.pressed.connect(func():
		flags_container.remove_child(row)
		row.queue_free()
		_apply_conditions()
	)

func _add_variable_row(scope: String, selected_name: String, op: String, value) -> void:
	if variables_container == null:
		return
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scope_select := OptionButton.new()
	for label in SCOPE_LABELS:
		scope_select.add_item(label)
	scope_select.select(max(0, SCOPE_OPTIONS.find(scope)))
	var var_select := OptionButton.new()
	var_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill_option_items(var_select, _get_var_options_for_scope(scope))
	_select_option_by_text(var_select, selected_name)
	var op_select := OptionButton.new()
	for label in VAR_OPS:
		op_select.add_item(label)
	op_select.select(max(0, VAR_OPS.find(op)))
	var value_spin := SpinBox.new()
	value_spin.min_value = -999999
	value_spin.max_value = 999999
	value_spin.step = 1
	value_spin.value = int(value)
	value_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var remove_btn := Button.new()
	remove_btn.text = "-"
	remove_btn.focus_mode = Control.FOCUS_NONE
	row.add_child(scope_select)
	row.add_child(var_select)
	row.add_child(op_select)
	row.add_child(value_spin)
	row.add_child(remove_btn)
	variables_container.add_child(row)

	scope_select.item_selected.connect(func(_idx):
		var scope_value := _scope_from_index(scope_select.selected)
		_fill_option_items(var_select, _get_var_options_for_scope(scope_value))
		_select_option_by_text(var_select, "")
		_apply_conditions()
	)
	var_select.item_selected.connect(_on_row_changed)
	op_select.item_selected.connect(_on_row_changed)
	value_spin.value_changed.connect(_on_row_value_changed)
	remove_btn.pressed.connect(func():
		variables_container.remove_child(row)
		row.queue_free()
		_apply_conditions()
	)

func _on_row_changed(_idx := 0) -> void:
	_apply_conditions()

func _on_row_value_changed(_value := 0.0) -> void:
	_apply_conditions()

func _apply_conditions() -> void:
	if _loading or _ev_command_node == null:
		return
	var result := {}

	var flags := []
	for row in flags_container.get_children():
		var scope_select := row.get_child(0) as OptionButton
		var flag_select := row.get_child(1) as OptionButton
		var value_check := row.get_child(3) as CheckBox
		if scope_select == null or flag_select == null or value_check == null:
			continue
		var flag_name := flag_select.get_item_text(flag_select.selected) if flag_select.item_count > 0 else ""
		if flag_name == "":
			continue
		flags.append({
			"scope": _scope_from_index(scope_select.selected),
			"name": flag_name,
			"value": value_check.button_pressed
		})
	if flags.size() > 0:
		result["flags"] = flags

	var vars := []
	for row in variables_container.get_children():
		var scope_select := row.get_child(0) as OptionButton
		var var_select := row.get_child(1) as OptionButton
		var op_select := row.get_child(2) as OptionButton
		var value_spin := row.get_child(3) as SpinBox
		if scope_select == null or var_select == null or op_select == null or value_spin == null:
			continue
		var var_name := var_select.get_item_text(var_select.selected) if var_select.item_count > 0 else ""
		if var_name == "":
			continue
		vars.append({
			"scope": _scope_from_index(scope_select.selected),
			"name": var_name,
			"op": op_select.get_item_text(op_select.selected),
			"value": int(value_spin.value)
		})
	if vars.size() > 0:
		result["variables"] = vars

	_ev_command_node.set_conditions(result)

func _clear_rows(container: VBoxContainer) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _fill_option_items(option: OptionButton, items: Array) -> void:
	option.clear()
	for item in items:
		option.add_item(str(item))

func _select_option_by_text(option: OptionButton, text: String) -> void:
	if option == null:
		return
	if text == "":
		if option.item_count > 0:
			option.select(0)
		return
	for i in option.item_count:
		if option.get_item_text(i) == text:
			option.select(i)
			return
	if option.item_count > 0:
		option.select(0)

func _refresh_row_options(container: VBoxContainer, items: Array) -> void:
	if container == null:
		return
	for row in container.get_children():
		var scope_select := row.get_child(0) as OptionButton
		var option := row.get_child(1) as OptionButton
		if scope_select == null or option == null:
			continue
		var scope := _scope_from_index(scope_select.selected)
		var prev := option.get_item_text(option.selected) if option.item_count > 0 else ""
		if scope == "local":
			continue
		_fill_option_items(option, items)
		_select_option_by_text(option, prev)

func _scope_from_index(index: int) -> String:
	if index < 0 or index >= SCOPE_OPTIONS.size():
		return "global"
	return SCOPE_OPTIONS[index]

func _get_flag_options_for_scope(scope: String) -> Array:
	if scope == "local":
		return LOCAL_FLAG_OPTIONS
	return _available_flags

func _get_var_options_for_scope(scope: String) -> Array:
	if scope == "local":
		return LOCAL_VAR_OPTIONS
	return _available_variables
