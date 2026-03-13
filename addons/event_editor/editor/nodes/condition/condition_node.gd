@tool
extends EventCommandNode
class_name ConditionNode

@export var subject_selector: OptionButton
@export var property_selector: OptionButton
@export var operator_selector: OptionButton
@export var value_input: LineEdit
@export var target_selector: OptionButton

const SUBJECT_OPTIONS := ["player"]
const PROPERTY_OPTIONS := ["facing_dir", "distance_to_event"]
const OPS_TEXT := ["==", "!=", ">", ">=", "<", "<="]

var subject: String = "player"
var property_name: String = "facing_dir"
var operator: String = "=="
var value_text: String = "down"
var target_id: String = ""
var target_name: String = ""

var _event_refs: Array = []

func _ready() -> void:
	super._ready()
	_setup_static_options()
	if subject_selector != null and not subject_selector.item_selected.is_connected(_on_subject_selected):
		subject_selector.item_selected.connect(_on_subject_selected)
	if property_selector != null and not property_selector.item_selected.is_connected(_on_property_selected):
		property_selector.item_selected.connect(_on_property_selected)
	if operator_selector != null and not operator_selector.item_selected.is_connected(_on_operator_selected):
		operator_selector.item_selected.connect(_on_operator_selected)
	if value_input != null and not value_input.text_changed.is_connected(_on_value_changed):
		value_input.text_changed.connect(_on_value_changed)
	if target_selector != null and not target_selector.item_selected.is_connected(_on_target_selected):
		target_selector.item_selected.connect(_on_target_selected)

func _on_changed() -> void:
	_setup_static_options()
	_rebuild_target_options()
	_select_metadata(subject_selector, subject)
	_select_metadata(property_selector, property_name)
	_select_metadata(operator_selector, operator)
	if value_input != null and value_input.text != value_text:
		value_input.text = value_text
	_update_visibility()

func import_params(params: Dictionary) -> void:
	subject = str(params.get("subject", "player")).to_lower()
	property_name = str(params.get("property", "facing_dir")).to_lower()
	operator = str(params.get("operator", "=="))
	value_text = str(params.get("value", "down"))
	target_id = str(params.get("target_id", ""))
	target_name = str(params.get("target_name", ""))
	emit_changed()

func export_params() -> Dictionary:
	return {
		"subject": subject,
		"property": property_name,
		"operator": operator,
		"value": value_text,
		"target_id": target_id,
		"target_name": target_name
	}

func load_from_data(data: NodeData) -> void:
	_data = data
	if EventEditorManager != null:
		_event_manager = EventEditorManager
		_event_refs = _event_manager.get_event_refs_for_active_map()
	else:
		_event_refs = []
	import_params(data.params)

func _setup_static_options() -> void:
	_fill_option(subject_selector, SUBJECT_OPTIONS)
	_fill_option(property_selector, PROPERTY_OPTIONS)
	_fill_option(operator_selector, OPS_TEXT)

func _fill_option(option: OptionButton, ids: Array) -> void:
	if option == null:
		return
	option.clear()
	for id in ids:
		var idx := option.item_count
		var label := str(id).replace("_", " ").capitalize()
		if str(id) in OPS_TEXT:
			label = str(id)
		option.add_item(label)
		option.set_item_metadata(idx, str(id))

func _rebuild_target_options() -> void:
	if target_selector == null:
		return
	target_selector.clear()
	for ev in _event_refs:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var id := str(ev.get("id", ""))
		if id == "":
			continue
		var idx := target_selector.item_count
		target_selector.add_item(str(ev.get("name", id)))
		target_selector.set_item_metadata(idx, id)
		if id == target_id:
			target_selector.select(idx)
	if target_selector.item_count > 0 and target_selector.selected < 0:
		target_selector.select(0)
		target_id = str(target_selector.get_item_metadata(0))
		target_name = target_selector.get_item_text(0)

func _select_metadata(option: OptionButton, wanted: String) -> void:
	if option == null:
		return
	for i in range(option.item_count):
		if str(option.get_item_metadata(i)).to_lower() == wanted.to_lower():
			option.select(i)
			return
	if option.item_count > 0:
		option.select(0)

func _update_visibility() -> void:
	var needs_target := property_name == "distance_to_event"
	if target_selector != null:
		target_selector.visible = needs_target

func _on_available_events_changed(events: Array) -> void:
	_event_refs = events.duplicate(true)
	emit_changed()

func _on_subject_selected(index: int) -> void:
	if subject_selector == null:
		return
	subject = str(subject_selector.get_item_metadata(index)).to_lower()
	emit_changed()
	request_apply_changes()

func _on_property_selected(index: int) -> void:
	if property_selector == null:
		return
	property_name = str(property_selector.get_item_metadata(index)).to_lower()
	if property_name == "facing_dir" and value_text == "":
		value_text = "down"
	emit_changed()
	request_apply_changes()

func _on_operator_selected(index: int) -> void:
	if operator_selector == null:
		return
	operator = str(operator_selector.get_item_metadata(index))
	emit_changed()
	request_apply_changes()

func _on_value_changed(text: String) -> void:
	value_text = text
	emit_changed()
	request_apply_changes()

func _on_target_selected(index: int) -> void:
	if target_selector == null:
		return
	target_id = str(target_selector.get_item_metadata(index))
	target_name = target_selector.get_item_text(index)
	emit_changed()
	request_apply_changes()
