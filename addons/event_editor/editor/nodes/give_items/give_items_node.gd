@tool
extends EventCommandNode
class_name GiveItemsNode

@export var item_id_edit: LineEdit
@export var amount_spin: SpinBox
@export var operation_select: OptionButton
@export var show_message_check: CheckBox
@export var inventory_variable_edit: LineEdit

const OP_ADD := "add"
const OP_REMOVE := "remove"
const OP_SET := "set"

var item_id: String = ""
var amount: int = 1
var operation: String = OP_ADD
var show_message: bool = false
var inventory_variable: String = "inventory"


func _ready() -> void:
	super._ready()
	if item_id_edit != null and not item_id_edit.text_changed.is_connected(_on_item_id_changed):
		item_id_edit.text_changed.connect(_on_item_id_changed)
	if amount_spin != null:
		amount_spin.step = 1
		amount_spin.rounded = true
		if not amount_spin.value_changed.is_connected(_on_amount_changed):
			amount_spin.value_changed.connect(_on_amount_changed)
	if operation_select != null and not operation_select.item_selected.is_connected(_on_operation_selected):
		operation_select.item_selected.connect(_on_operation_selected)
	if show_message_check != null and not show_message_check.toggled.is_connected(_on_show_message_toggled):
		show_message_check.toggled.connect(_on_show_message_toggled)
	if inventory_variable_edit != null and not inventory_variable_edit.text_changed.is_connected(_on_inventory_variable_changed):
		inventory_variable_edit.text_changed.connect(_on_inventory_variable_changed)

func _on_changed() -> void:
	if item_id_edit != null and item_id_edit.text != item_id:
		item_id_edit.text = item_id
	if amount_spin != null and int(amount_spin.value) != amount:
		amount_spin.value = amount
	if operation_select != null:
		operation_select.clear()
		var options := get_operation_options()
		for option in options:
			operation_select.add_item(str(option.get("label", option.get("id", ""))))
		var selected := get_selected_operation_index()
		if selected >= 0 and selected < operation_select.item_count:
			operation_select.select(selected)
	if show_message_check != null:
		show_message_check.button_pressed = show_message
	if inventory_variable_edit != null and inventory_variable_edit.text != inventory_variable:
		inventory_variable_edit.text = inventory_variable

func _on_item_id_changed(value: String) -> void:
	set_item_id(value)

func _on_amount_changed(value: float) -> void:
	set_amount(int(round(value)))

func _on_operation_selected(index: int) -> void:
	set_operation_by_index(index)

func _on_show_message_toggled(value: bool) -> void:
	set_show_message(value)

func _on_inventory_variable_changed(value: String) -> void:
	set_inventory_variable(value)

#region User Intention

func import_params(params: Dictionary) -> void:
	item_id = str(params.get("item_id", item_id)).strip_edges()
	amount = int(params.get("amount", amount))
	operation = str(params.get("operation", operation)).to_lower()
	if operation != OP_ADD and operation != OP_REMOVE and operation != OP_SET:
		operation = OP_ADD
	show_message = bool(params.get("show_message", show_message))
	inventory_variable = str(params.get("inventory_variable", inventory_variable)).strip_edges()
	if inventory_variable == "":
		inventory_variable = "inventory"
	emit_changed()

func export_params() -> Dictionary:
	return {
		"item_id": item_id,
		"amount": amount,
		"operation": operation,
		"show_message": show_message,
		"inventory_variable": inventory_variable
	}

func load_from_data(data: NodeData) -> void:
	_data = data
	import_params(data.params)

func get_operation_options() -> Array:
	return [
		{"id": OP_ADD, "label": "Add"},
		{"id": OP_REMOVE, "label": "Remove"},
		{"id": OP_SET, "label": "Set"}
	]

func get_selected_operation_index() -> int:
	var options := get_operation_options()
	for i in options.size():
		if str(options[i].get("id", "")) == operation:
			return i
	return 0

func set_item_id(value: String) -> void:
	var normalized := value.strip_edges()
	if item_id == normalized:
		return
	item_id = normalized
	emit_changed()
	request_apply_changes()

func set_amount(value: int) -> void:
	if amount == value:
		return
	amount = value
	emit_changed()
	request_apply_changes()

func set_operation_by_index(index: int) -> void:
	var options := get_operation_options()
	if index < 0 or index >= options.size():
		return
	var op := str(options[index].get("id", OP_ADD))
	if operation == op:
		return
	operation = op
	emit_changed()
	request_apply_changes()

func set_show_message(value: bool) -> void:
	if show_message == value:
		return
	show_message = value
	emit_changed()
	request_apply_changes()

func set_inventory_variable(value: String) -> void:
	var normalized := value.strip_edges()
	if normalized == "":
		normalized = "inventory"
	if inventory_variable == normalized:
		return
	inventory_variable = normalized
	emit_changed()
	request_apply_changes()
