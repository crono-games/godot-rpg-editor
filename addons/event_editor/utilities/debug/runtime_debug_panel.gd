extends CanvasLayer
class_name RuntimeDebugPanel

@export var map_label: Label
@export var run_event_id_edit: LineEdit
@export var run_event_button: Button
@export var refresh_states_button: Button
@export var flags_list: ItemList
@export var variables_list: ItemList
@export var event_select: OptionButton
@export var local_flags_list: ItemList
@export var toggle_action := "debug_runtime_panel"
@export var fallback_toggle_key: Key = KEY_F3

var _map_manager: Node = null
var _ctx: EventRuntimeContext = null
var _refresh_accum := 0.0

func _ready() -> void:
	visible = false
	_resolve_runtime_refs()
	if _ctx == null:
		push_warning("RuntimeDebugPanel: runtime context not found")
		return
	_bind_ui()
	_bind_context_signals()
	set_process(true)
	set_process_input(true)
	_refresh_all()

func _input(event: InputEvent) -> void:
	if event == null:
		return

	if _is_toggle_event(event):
		visible = not visible
		if visible:
			_refresh_all()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_accum += delta
	if _refresh_accum < 0.25:
		return
	_refresh_accum = 0.0
	_refresh_all()

func _bind_ui() -> void:
	run_event_button.pressed.connect(_on_run_event_pressed)
	refresh_states_button.pressed.connect(_on_refresh_pressed)
	event_select.item_selected.connect(_on_event_selected)

func _refresh_all() -> void:
	if _ctx == null:
		_resolve_runtime_refs()
		if _ctx == null:
			return
	_refresh_map()
	_refresh_flags()
	_refresh_variables()
	_refresh_event_select()
	_refresh_local_flags()

func _refresh_map() -> void:
	if _map_manager != null and _map_manager.has_method("get_current_map_id"):
		map_label.text = "Map: %s" % _map_manager.get_current_map_id()

func _refresh_flags() -> void:
	flags_list.clear()
	if _ctx == null:
		return
	for k in _ctx.flags.keys():
		flags_list.add_item("%s = %s" % [k, str(_ctx.flags[k])])

func _refresh_variables() -> void:
	variables_list.clear()
	if _ctx == null:
		return
	for k in _ctx.variables.keys():
		variables_list.add_item("%s = %s" % [k, str(_ctx.variables[k])])

func _refresh_event_select() -> void:
	var previous_id := ""
	if event_select.selected >= 0:
		previous_id = str(event_select.get_item_metadata(event_select.selected))
	event_select.clear()
	if _ctx == null:
		return
	var ids: Dictionary = {}
	for event_id in _ctx.current_state_by_event.keys():
		ids[str(event_id)] = true
	for event_id in _ctx.local_flags_by_event.keys():
		ids[str(event_id)] = true
	for event_id in ids.keys():
		var idx := event_select.item_count
		event_select.add_item(_event_label(event_id))
		event_select.set_item_metadata(idx, event_id)
	# Preserve current selection when possible.
	if previous_id != "":
		for i in range(event_select.item_count):
			if str(event_select.get_item_metadata(i)) == previous_id:
				event_select.select(i)
				return
	if event_select.item_count > 0:
		event_select.select(0)

func _refresh_local_flags() -> void:
	local_flags_list.clear()
	if _ctx == null:
		return
	if event_select.selected < 0:
		return
	var event_id := str(event_select.get_item_metadata(event_select.selected))
	var data: Dictionary = _ctx.local_flags_by_event.get(event_id, {})
	for k in data.keys():
		local_flags_list.add_item("%s = %s" % [k, str(data[k])])

func _on_run_event_pressed() -> void:
	if _map_manager == null:
		return
	var event_id := run_event_id_edit.text.strip_edges()
	if event_id == "":
		return
	if _map_manager.has_method("run_event"):
		_map_manager.run_event(event_id)

func _on_refresh_pressed() -> void:
	if _map_manager == null:
		return
	if _map_manager.has_method("_deferred_refresh"):
		_map_manager._deferred_refresh()
	_refresh_all()

func _on_event_selected(_idx: int) -> void:
	_refresh_local_flags()

func _bind_context_signals() -> void:
	if _ctx == null:
		return
	if not _ctx.flags_changed.is_connected(_on_flags_changed):
		_ctx.flags_changed.connect(_on_flags_changed)
	if not _ctx.variables_changed.is_connected(_on_variables_changed):
		_ctx.variables_changed.connect(_on_variables_changed)
	if not _ctx.local_flags_changed.is_connected(_on_local_flags_changed):
		_ctx.local_flags_changed.connect(_on_local_flags_changed)
	if not _ctx.changed.is_connected(_on_runtime_changed):
		_ctx.changed.connect(_on_runtime_changed)

func _on_flags_changed() -> void:
	_refresh_flags()

func _on_variables_changed() -> void:
	_refresh_variables()

func _on_local_flags_changed(_event_id: String) -> void:
	_refresh_event_select()
	_refresh_local_flags()

func _on_runtime_changed() -> void:
	_refresh_map()

func _is_toggle_event(event: InputEvent) -> bool:
	if toggle_action != "" and event.is_action_pressed(toggle_action):
		return true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == fallback_toggle_key:
			return true
	return false

func _resolve_runtime_refs() -> void:
	# Prefer autoload singleton.
	_map_manager = MapEventManager
	if _map_manager == null:
		for node in get_tree().get_nodes_in_group("map_manager"):
			_map_manager = node
			break
	if _map_manager == null:
		_ctx = null
		return
	if _map_manager.has_method("get_runtime_context"):
		_ctx = _map_manager.get_runtime_context()
	elif _map_manager.get("_runtime_context") != null:
		_ctx = _map_manager._runtime_context
	else:
		_ctx = null

func _event_label(event_id: String) -> String:
	if _ctx == null:
		return event_id
	var event_node := _ctx.get_event_by_id(event_id)
	if event_node == null:
		return event_id
	var n := str(event_node.name)
	if n == "":
		return event_id
	return "%s (%s)" % [n, event_id]
