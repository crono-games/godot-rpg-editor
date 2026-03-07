@tool
extends EventCommandNode
class_name ChangeGraphicsNode

@export var event_selector: OptionButton
@export var file_dialog: FileDialog

var _event_manager: EventEditorManager = EventEditorManager
var available_events: Array = []

var selected_event_id : String = ""
var selected_event_name: String = ""
var graphics_path : String = ""

func _ready() -> void:
	super._ready()

func _on_changed():
	event_selector.clear()

	for ev in available_events:
		var name := str(ev.get("name", ""))
		var id := str(ev.get("id", ""))
		var idx := event_selector.item_count
		event_selector.add_item(name)
		event_selector.set_item_metadata(idx, id)

	if selected_event_id != "":
		_select_event_by_id(selected_event_id)
	elif event_selector.item_count > 0:
		event_selector.select(0)
		request_set_target(str(event_selector.get_item_metadata(0)))
		request_apply_changes()
	size = Vector2.ZERO

func _on_event_selector_item_selected(index):
	request_set_target(
		str(event_selector.get_item_metadata(index))
	)
	request_apply_changes()


func _on_file_selected(path):
	request_set_graphics(path)
	request_apply_changes()

func _select_event_by_id(event_id: String):
	for i in event_selector.item_count:
		var meta := str(event_selector.get_item_metadata(i))
		if meta == event_id:
			event_selector.select(i)
			return

func _on_button_pressed() -> void:
	file_dialog.popup()

#region User Intention

func import_params(params: Dictionary) -> void:
	selected_event_id = str(params.get("target_id", ""))
	selected_event_name = str(params.get("target_name", ""))
	if selected_event_id == "":
		var legacy_name := str(params.get("target", ""))
		if legacy_name != "":
			selected_event_id = _event_id_from_name(legacy_name)
			selected_event_name = legacy_name
	graphics_path = str(params.get("graphics", ""))
	emit_changed()

func export_params() -> Dictionary:
	return {
		"target_id": selected_event_id,
		"target_name": selected_event_name,
		"graphics": graphics_path
	}

func load_from_data(data: NodeData) -> void:
	_data = data

	if EventEditorManager != null:
		if not EventEditorManager.available_events_changed.is_connected(_on_available_events_changed):
			EventEditorManager.available_events_changed.connect(_on_available_events_changed)
		available_events = EventEditorManager.get_event_refs_for_active_map()
	else:
		available_events = []

	import_params(data.params)

func bind_event_manager(_manager: EventEditorManager) -> void:
	_event_manager = EventEditorManager
	if _event_manager == null:
		return
	if not _event_manager.event_refs_changed.is_connected(_on_event_refs_changed):
		_event_manager.event_refs_changed.connect(_on_event_refs_changed)
	if not _event_manager.available_events_changed.is_connected(_on_available_events_changed):
		_event_manager.available_events_changed.connect(_on_available_events_changed)
	if not _event_manager.active_map_changed.is_connected(_on_active_map_changed):
		_event_manager.active_map_changed.connect(_on_active_map_changed)
	_reload_events()

func _on_available_events_changed(events: Array) -> void:
	available_events = events
	_resolve_selected_event()
	emit_changed()

func _reload_events() -> void:
	if _event_manager == null:
		return
	available_events = _event_manager.get_event_refs_for_active_map()
	_resolve_selected_event()
	emit_changed()

func _on_active_map_changed(_map_id: String) -> void:
	_reload_events()

func _on_event_refs_changed(refs: Array) -> void:
	available_events = refs.duplicate(true)
	_resolve_selected_event()
	emit_changed()


func request_set_target(value):
	if selected_event_id == value:
		return
	selected_event_id = value
	selected_event_name = _event_name_from_id(value)
	emit_signal("changed")

func request_set_graphics(path):
	if graphics_path == path:
		return
	graphics_path = path
	emit_signal("changed")

func _event_id_from_name(name: String) -> String:
	if _event_manager != null:
		return _event_manager.resolve_event_id(name)
	for ev in available_events:
		if ev.get("name", "") == name:
			return str(ev.get("id", ""))
	return ""

func _event_name_from_id(event_id: String) -> String:
	if _event_manager != null:
		return _event_manager.resolve_event_name(event_id)
	for ev in available_events:
		if ev.get("id", "") == event_id:
			return str(ev.get("name", ""))
	return ""

func _resolve_selected_event() -> void:
	if selected_event_id == "":
		return
	var name := _event_name_from_id(selected_event_id)
	if name == "":
		# allow UI to show id if name not found
		return
	if selected_event_name != name:
		selected_event_name = name
