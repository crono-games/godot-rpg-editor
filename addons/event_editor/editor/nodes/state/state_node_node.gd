# state_node_view.gd
@tool
extends EventCommandNode
class_name StateNode

signal trigger_mode_changed(mode: String)

const STATE_PROPERTIES_POPUP_SCENE = preload("res://addons/event_editor/editor/nodes/state/state_properties_popup.tscn")
const TRIGGER_OPTIONS := ["action", "auto", "touch_overlap", "touch_bump", "parallel"]
const TRIGGER_LABELS := ["Action", "Auto", "Touch", "Bump", "Parallel"]

@export var trigger_select: OptionButton
@export var properties_button: Button

var title_edit: LineEdit = null
var _properties_popup: StatePropertiesPopup

var state_id: String = ""
var display_name: String = ""

var trigger_mode: String = "action"

var properties: Dictionary = {}

var conditions: Dictionary = {}

@onready var titlebar := get_titlebar_hbox()
@onready var title_label : Label = titlebar.get_child(0) if titlebar != null else null

func _ready() -> void:
	super._ready()
	if title_edit == null:
		title_edit = LineEdit.new()
	_set_title_bar()
	_setup_trigger_options()
	emit_changed()

func _set_title_bar():
	if title_edit == null:
		return

	title_edit.flat = true
	if title_edit.text == "":
		title_edit.text = title
	if title_label != null:
		title_label.tooltip_text = title
		title_label.visible = false
	if not title_edit.is_connected("text_submitted", Callable(self, "_commit_title")):
		title_edit.text_submitted.connect(_commit_title)
	if not title_edit.is_connected("focus_exited", Callable(self, "_commit_title")):
		title_edit.focus_exited.connect(_commit_title)
	if titlebar != null:
		titlebar.add_child(title_edit)

func _commit_title(_text := ""):
	if title_edit == null:
		return
	title = title_edit.text
	title_edit.tooltip_text = title
	title_edit.release_focus()

func _on_changed() -> void:
	# Header
	var display := display_name
	if display == "":
		display = title
	if title_edit != null and title_edit.text != display:
		title_edit.text = display
	if title != display:
		title = display
	if title_label != null:
		title_label.tooltip_text = display

	# Trigger
	var idx = _trigger_to_index(trigger_mode)
	if idx != -1 and trigger_select.selected != idx:
		trigger_select.select(idx)

func _setup_trigger_options() -> void:
	if trigger_select != null:
		trigger_select.clear()
		for i in TRIGGER_OPTIONS.size():
			trigger_select.add_item(TRIGGER_LABELS[i])
		if not trigger_select.is_connected("item_selected", Callable(self, "_on_trigger_selected")):
			trigger_select.item_selected.connect(_on_trigger_selected)
	if title_edit != null and not title_edit.is_connected("text_changed", Callable(self, "_on_name_changed")):
		title_edit.text_changed.connect(_on_name_changed)
	if properties_button != null and not properties_button.is_connected("pressed", Callable(self, "_on_properties_pressed")):
		properties_button.pressed.connect(_on_properties_pressed)

func _on_name_changed(text: String) -> void:
	set_display_name(text)

func _on_trigger_selected(index: int) -> void:
	set_trigger_mode(_index_to_trigger(index))

func _on_properties_pressed() -> void:
	if _properties_popup == null:
		_properties_popup = STATE_PROPERTIES_POPUP_SCENE.instantiate()
		add_child(_properties_popup)
	_properties_popup.open_for(self)

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────
func _trigger_to_index(trigger: String) -> int:
	match trigger:
		"action": return 0
		"auto": return 1
		"touch", "player_touch", "touch_overlap": return 2
		"touch_bump": return 3
		"parallel": return 4
		_: return -1

func _index_to_trigger(index: int) -> String:
	match index:
		0: return "action"
		1: return "auto"
		2: return "touch_overlap"
		3: return "touch_bump"
		4: return "parallel"
		_: return "action"

func _get_drag_offset() -> float:
	var offset := 0.0
	for c in titlebar.get_children():
		if c != title_edit and c is Control:
			offset += c.size.x
	return offset

#region User Intention

func load_from_data(data: NodeData) -> void:
	pass

# ─────────────────────────────────────────────
# Import / Export
# ─────────────────────────────────────────────
func import_params(params: Dictionary) -> void:
	var sid := str(params.get("state_id", ""))
	if sid == "" and _data != null:
		sid = str(_data.id)
	state_id = sid

	var name := str(params.get("name", ""))
	if name == "":
		if state_id == "default":
			name = "Default"
		elif state_id != "":
			name = state_id
	display_name = name
	trigger_mode = _normalize_trigger_mode(str(params.get("trigger_mode", "action")))

	properties = params.get("properties", {}).duplicate(true)
	conditions = params.get("conditions", {}).duplicate(true)

	emit_changed()

func export_params() -> Dictionary:
	return {
		"state_id": state_id,
		"name": display_name,
		"trigger_mode": trigger_mode,
		"properties": properties.duplicate(true),
		"conditions": conditions.duplicate(true),
	}

# ─────────────────────────────────────────────
# Mutators UI
# ─────────────────────────────────────────────
func set_display_name(value: String) -> void:
	if display_name == value:
		return
	display_name = value
	emit_changed()
	request_apply_changes()

func set_trigger_mode(mode: String) -> void:
	mode = _normalize_trigger_mode(mode)
	if trigger_mode == mode:
		return
	trigger_mode = mode
	emit_signal("trigger_mode_changed", trigger_mode)
	emit_changed()
	request_apply_changes()

func _normalize_trigger_mode(mode: String) -> String:
	var m := mode.to_lower()
	match m:
		"touch", "player_touch", "touch_overlap":
			return "touch_overlap"
		"touch_bump":
			return "touch_bump"
		"action", "auto", "parallel":
			return m
		_:
			return "action"

# ─────────────────────────────────────────────
# Advanced properties API
# ─────────────────────────────────────────────
func set_property(key: String, value) -> void:
	properties = properties.duplicate(true)
	properties[key] = value
	emit_changed()
	request_apply_changes()

func remove_property(key: String) -> void:
	if not properties.has(key):
		return
	properties = properties.duplicate(true)
	properties.erase(key)
	emit_changed()
	request_apply_changes()

func set_condition(key: String, value) -> void:
	conditions = conditions.duplicate(true)
	conditions[key] = value
	emit_changed()
	request_apply_changes()

func remove_condition(key: String) -> void:
	if not conditions.has(key):
		return
	conditions = conditions.duplicate(true)
	conditions.erase(key)
	emit_changed()
	request_apply_changes()

func set_conditions(new_conditions: Dictionary) -> void:
	conditions = new_conditions.duplicate(true)
	emit_changed()
	request_apply_changes()

func get_conditions() -> Dictionary:
	return conditions.duplicate(true)

func get_context() -> EventEditorManager:
	if EventEditorManager != null:
		return EventEditorManager
	return null
