@tool
extends Window
class_name StatePropertiesPopup

const TRIGGER_OPTIONS := ["action", "auto", "touch_overlap", "touch_bump", "parallel"]
const TRIGGER_LABELS := ["Action", "Auto", "Touch", "Bump", "Parallel"]
const MOVEMENT_OPTIONS := ["fixed", "random", "approach"]
const MOVEMENT_LABELS := ["Fixed", "Random", "Approach"]
const MOVEMENT_PRESET_OPTIONS := ["custom", "slow", "normal", "fast"]
const MOVEMENT_PRESET_LABELS := ["Custom", "Slow", "Normal", "Fast"]
const PRESET_TO_VALUES := {
	"slow": {"frequency": 2, "speed": 2},
	"normal": {"frequency": 3, "speed": 4},
	"fast": {"frequency": 5, "speed": 6}
}

@export var conditions_editor: StateConditionsEditor
@export var trigger_select: OptionButton
@export var passability_check: CheckBox
@export var movement_type_select: OptionButton
@export var movement_preset_select: OptionButton
@export var movement_frequency_spin: SpinBox
@export var movement_speed_spin: SpinBox
@export var movement_anim_step_spin: SpinBox
@export var movement_max_cycles_spin: SpinBox
@export var graphics_editor: StateGraphicsEditor

var _ev_command_node: StateNode
var _context: EventEditorManager
var _loading := false

func _ready() -> void:
	size = Vector2.ZERO
	if trigger_select != null:
		trigger_select.clear()
		for i in TRIGGER_OPTIONS.size():
			trigger_select.add_item(TRIGGER_LABELS[i])
	if trigger_select != null and not trigger_select.item_selected.is_connected(_on_trigger_selected):
		trigger_select.item_selected.connect(_on_trigger_selected)
	if passability_check != null and not passability_check.toggled.is_connected(_on_passability_toggled):
		passability_check.toggled.connect(_on_passability_toggled)
	if movement_type_select != null:
		movement_type_select.clear()
		for i in MOVEMENT_OPTIONS.size():
			movement_type_select.add_item(MOVEMENT_LABELS[i])
	if movement_type_select != null and not movement_type_select.item_selected.is_connected(_on_movement_type_selected):
		movement_type_select.item_selected.connect(_on_movement_type_selected)
	if movement_preset_select != null:
		movement_preset_select.clear()
		for i in MOVEMENT_PRESET_OPTIONS.size():
			movement_preset_select.add_item(MOVEMENT_PRESET_LABELS[i])
	if movement_preset_select != null and not movement_preset_select.item_selected.is_connected(_on_movement_preset_selected):
		movement_preset_select.item_selected.connect(_on_movement_preset_selected)
	if movement_frequency_spin != null and not movement_frequency_spin.value_changed.is_connected(_on_movement_frequency_changed):
		movement_frequency_spin.value_changed.connect(_on_movement_frequency_changed)
	if movement_speed_spin != null and not movement_speed_spin.value_changed.is_connected(_on_movement_speed_changed):
		movement_speed_spin.value_changed.connect(_on_movement_speed_changed)
	if movement_anim_step_spin != null and not movement_anim_step_spin.value_changed.is_connected(_on_movement_anim_step_changed):
		movement_anim_step_spin.value_changed.connect(_on_movement_anim_step_changed)
	if movement_max_cycles_spin != null and not movement_max_cycles_spin.value_changed.is_connected(_on_movement_max_cycles_changed):
		movement_max_cycles_spin.value_changed.connect(_on_movement_max_cycles_changed)

func open_for(ev_command_node: StateNode) -> void:
	_ev_command_node = ev_command_node
	_context = _ev_command_node.get_context()
	if _ev_command_node != null and not _ev_command_node.trigger_mode_changed.is_connected(_on_node_trigger_changed):
		_ev_command_node.trigger_mode_changed.connect(_on_node_trigger_changed)
	_load_from_ev_command_node()
	popup_centered(Vector2(520, 560))

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if conditions_editor != null:
			conditions_editor.apply_conditions()

func _load_from_ev_command_node() -> void:
	if _ev_command_node == null:
		return
	_loading = true

	var trigger_mode := str(_ev_command_node.trigger_mode).to_lower()
	if trigger_mode == "touch" or trigger_mode == "player_touch":
		trigger_mode = "touch_overlap"
	var idx := TRIGGER_OPTIONS.find(trigger_mode)
	if idx >= 0 and trigger_select != null:
		trigger_select.select(idx)
	var passability := str(_ev_command_node.properties.get("passability", "auto")).to_lower()
	if passability_check != null:
		passability_check.button_pressed = passability == "passable"
	var movement_type := str(_ev_command_node.properties.get("movement_type", "fixed")).to_lower()
	var movement_idx := MOVEMENT_OPTIONS.find(movement_type)
	if movement_idx < 0:
		movement_idx = 0
	if movement_type_select != null:
		movement_type_select.select(movement_idx)
	if movement_preset_select != null:
		movement_preset_select.select(_preset_index_for_values(
			int(_ev_command_node.properties.get("movement_frequency", 3)),
			int(_ev_command_node.properties.get("movement_speed", 4))
		))
	if movement_frequency_spin != null:
		movement_frequency_spin.value = float(_ev_command_node.properties.get("movement_frequency", 3))
	if movement_speed_spin != null:
		movement_speed_spin.value = float(_ev_command_node.properties.get("movement_speed", 4))
	if movement_anim_step_spin != null:
		movement_anim_step_spin.value = float(_ev_command_node.properties.get("anim_step_time", 0.11))
	if movement_max_cycles_spin != null:
		movement_max_cycles_spin.value = float(_ev_command_node.properties.get("max_anim_cycles_per_step", 1.0))

	if conditions_editor != null:
		conditions_editor.setup(_ev_command_node, _context)
	if graphics_editor != null:
		graphics_editor.setup(_ev_command_node)
	_loading = false
	_sync_movement_ui()

func _on_trigger_selected(index: int) -> void:
	if _ev_command_node == null or index < 0 or index >= TRIGGER_OPTIONS.size():
		return
	_loading = true
	_ev_command_node.set_trigger_mode(TRIGGER_OPTIONS[index])
	_loading = false

func _on_node_trigger_changed(mode: String) -> void:
	if _loading or trigger_select == null:
		return
	var trigger_mode := str(mode).to_lower()
	if trigger_mode == "touch" or trigger_mode == "player_touch":
		trigger_mode = "touch_overlap"
	var idx := TRIGGER_OPTIONS.find(trigger_mode)
	if idx >= 0 and trigger_select.selected != idx:
		trigger_select.select(idx)

func _on_passability_toggled(value: bool) -> void:
	if _loading:
		return
	if _ev_command_node == null:
		return
	_ev_command_node.set_property("passability", "passable" if value else "block")

func _on_movement_type_selected(index: int) -> void:
	if _loading:
		return
	if _ev_command_node == null or index < 0 or index >= MOVEMENT_OPTIONS.size():
		return
	var mode = MOVEMENT_OPTIONS[index]
	_ev_command_node.set_property("movement_type", mode)
	_sync_movement_ui()

func _on_movement_frequency_changed(value: float) -> void:
	if _loading:
		return
	if _ev_command_node == null:
		return
	_ev_command_node.set_property("movement_frequency", int(value))
	_update_preset_from_current_values()

func _on_movement_speed_changed(value: float) -> void:
	if _loading:
		return
	if _ev_command_node == null:
		return
	_ev_command_node.set_property("movement_speed", int(value))
	_update_preset_from_current_values()

func _on_movement_anim_step_changed(value: float) -> void:
	if _loading:
		return
	if _ev_command_node == null:
		return
	_ev_command_node.set_property("anim_step_time", maxf(0.01, value))

func _on_movement_max_cycles_changed(value: float) -> void:
	if _loading:
		return
	if _ev_command_node == null:
		return
	_ev_command_node.set_property("max_anim_cycles_per_step", maxf(0.0, value))

func _on_movement_preset_selected(index: int) -> void:
	if _loading:
		return
	if _ev_command_node == null or index < 0 or index >= MOVEMENT_PRESET_OPTIONS.size():
		return
	var preset = MOVEMENT_PRESET_OPTIONS[index]
	if preset == "custom":
		return
	var values: Dictionary = PRESET_TO_VALUES.get(preset, {})
	var freq := int(values.get("frequency", 3))
	var speed := int(values.get("speed", 4))
	if movement_frequency_spin != null:
		movement_frequency_spin.value = freq
	if movement_speed_spin != null:
		movement_speed_spin.value = speed
	_ev_command_node.set_property("movement_frequency", freq)
	_ev_command_node.set_property("movement_speed", speed)

func _sync_movement_ui() -> void:
	if movement_type_select == null:
		return
	var idx := movement_type_select.selected
	var mode := "fixed"
	if idx >= 0 and idx < MOVEMENT_OPTIONS.size():
		mode = MOVEMENT_OPTIONS[idx]
	var editable := mode != "fixed"
	if movement_preset_select != null:
		movement_preset_select.disabled = not editable
	if movement_frequency_spin != null:
		movement_frequency_spin.editable = editable
	if movement_speed_spin != null:
		movement_speed_spin.editable = editable
	if movement_anim_step_spin != null:
		movement_anim_step_spin.editable = editable
	if movement_max_cycles_spin != null:
		movement_max_cycles_spin.editable = editable

func _update_preset_from_current_values() -> void:
	if movement_preset_select == null or movement_frequency_spin == null or movement_speed_spin == null:
		return
	movement_preset_select.select(_preset_index_for_values(
		int(movement_frequency_spin.value),
		int(movement_speed_spin.value)
	))

func _preset_index_for_values(freq: int, speed: int) -> int:
	for i in MOVEMENT_PRESET_OPTIONS.size():
		var key = MOVEMENT_PRESET_OPTIONS[i]
		if key == "custom":
			continue
		var values: Dictionary = PRESET_TO_VALUES.get(key, {})
		if int(values.get("frequency", -1)) == freq and int(values.get("speed", -1)) == speed:
			return i
	return 0
