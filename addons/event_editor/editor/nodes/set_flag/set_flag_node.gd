@tool
extends EventCommandNode
class_name SetFlagNode

@export var flag_selector: OptionButton
@export var state_check_box: CheckBox

var available_flags: Array = []
var selected_flag: String = ""
var state: bool = false
var _context: EventEditorManager
var _global_state: GlobalState

#region Interface

func _ready() -> void:
	super._ready()
	flag_selector.connect("item_selected", Callable(self, "_on_flag_selected"))
	state_check_box.connect("toggled", Callable(self, "_on_state_toggled"))

func _on_changed() -> void:
	flag_selector.clear()
	var items := get_flag_options()
	for i in items.size():
		flag_selector.add_item(items[i])

	var idx := get_selected_index()
	if idx >= 0 and idx < flag_selector.get_item_count():
		flag_selector.select(idx)

	state_check_box.button_pressed = state

func _on_flag_selected(id: int) -> void:
	set_selected_by_index(id)

func _on_state_toggled(toggled: bool) -> void:
	set_state(toggled)

#region User Intention

func import_params(params: Dictionary) -> void:
	selected_flag = params.get("flag_name", "")
	state = params.get("state", false)
	emit_changed()

func export_params() -> Dictionary:
	return {
		"flag_name": selected_flag,
		"state": state,
		"scope": "global"
	}

func load_from_data(data: NodeData) -> void:
	_data = data
	var ctx := EventEditorManager
	if ctx != null:
		_context = ctx
		if not _context.flags_changed.is_connected(_on_flags_changed):
			_context.flags_changed.connect(_on_flags_changed)
		_global_state = _context.get_global_state()
		if _global_state != null and not _global_state.flags_changed.is_connected(_on_global_state_flags_changed):
			_global_state.flags_changed.connect(_on_global_state_flags_changed)
		_on_flags_changed(_context.get_flags())
	else:
		available_flags = []
	emit_changed()

func _on_flags_changed(flags: Array) -> void:
	available_flags = flags.duplicate(true)
	if available_flags.size() == 0:
		selected_flag = ""
		emit_changed()
		return
	if available_flags.find(selected_flag) == -1:
		selected_flag = available_flags[0]
		emit_changed()
		request_apply_changes()
	else:
		emit_changed()

func _on_global_state_flags_changed() -> void:
	if _context == null:
		return
	_on_flags_changed(_context.get_flags())


func get_flag_options() -> Array:
	return available_flags.duplicate(true)

func get_selected_index() -> int:
	var idx = available_flags.find(selected_flag)
	if idx == -1 and available_flags.size() > 0:
		return 0
	return idx

func set_selected_by_index(index: int) -> void:
	if index < 0 or index >= available_flags.size():
		return
	selected_flag = available_flags[index]
	emit_changed()
	request_apply_changes()

func set_state(s: bool) -> void:
	state = s
	emit_changed()
	request_apply_changes()
