@tool
extends EventCommandNode
class_name SetVisibilityNode

@export var event_selector: OptionButton
@export var visible_check_box: CheckBox
@export var disable_collision_check_box: CheckBox

var _event_manager: EventEditorManager = EventEditorManager
var event_instances: Array = []
var target_id: String = ""
var target_name: String = ""
var visibility: bool = true
var disable_collision: bool = false

func _ready() -> void:
	super._ready()
	if event_selector != null and not event_selector.item_selected.is_connected(_on_event_selected):
		event_selector.item_selected.connect(_on_event_selected)
	if visible_check_box != null and not visible_check_box.toggled.is_connected(_on_visible_toggled):
		visible_check_box.toggled.connect(_on_visible_toggled)
	if disable_collision_check_box != null and not disable_collision_check_box.toggled.is_connected(_on_disable_collision_toggled):
		disable_collision_check_box.toggled.connect(_on_disable_collision_toggled)

func _on_changed() -> void:
	if event_selector != null:
		event_selector.clear()
		var items := get_event_options()
		for ev in items:
			if typeof(ev) != TYPE_DICTIONARY:
				continue
			var id := str(ev.get("id", ""))
			if id == "":
				continue
			var name := str(ev.get("name", id))
			var idx := event_selector.item_count
			event_selector.add_item(name)
			event_selector.set_item_metadata(idx, id)
		var idx_sel := get_selected_index()
		if idx_sel >= 0 and idx_sel < event_selector.item_count:
			event_selector.select(idx_sel)
		elif event_selector.item_count > 0:
			event_selector.select(0)
			set_selected_by_index(0)
	if visible_check_box != null:
		visible_check_box.button_pressed = visibility
	if disable_collision_check_box != null:
		disable_collision_check_box.button_pressed = disable_collision

func _on_event_selected(index: int) -> void:
	set_selected_by_index(index)

func _on_visible_toggled(value: bool) -> void:
	set_visibility(value)

func _on_disable_collision_toggled(value: bool) -> void:
	set_disable_collision(value)

#region User Intention 

func import_params(params: Dictionary) -> void:
	target_id = str(params.get("target_id", ""))
	target_name = str(params.get("target_name", ""))
	if target_id == "":
		var legacy := str(params.get("target", ""))
		if legacy != "":
			target_id = legacy
	visibility = bool(params.get("visible", true))
	disable_collision = bool(params.get("disable_collision", false))
	_ensure_valid_target(false)
	emit_changed()

func export_params() -> Dictionary:
	return {
		"target_id": target_id,
		"target_name": target_name,
		"visible": visibility,
		"disable_collision": disable_collision
	}

func load_from_data(data: NodeData) -> void:
	_data = data
	if EventEditorManager != null:
		if not EventEditorManager.available_events_changed.is_connected(_on_available_events_changed):
			EventEditorManager.available_events_changed.connect(_on_available_events_changed)
		event_instances = EventEditorManager.get_event_refs_for_active_map()
	else:
		event_instances = []
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

func get_event_options() -> Array:
	return event_instances.duplicate(true)

func get_selected_index() -> int:
	if event_instances.is_empty():
		return -1
	for i in event_instances.size():
		var ev = event_instances[i]
		if typeof(ev) == TYPE_DICTIONARY and str(ev.get("id", "")) == target_id:
			return i
	return -1

func set_selected_by_index(index: int) -> void:
	if index < 0 or index >= event_instances.size():
		return
	var ev = event_instances[index]
	if typeof(ev) != TYPE_DICTIONARY:
		return
	target_id = str(ev.get("id", ""))
	target_name = str(ev.get("name", ""))
	emit_changed()
	request_apply_changes()

func set_visibility(value: bool) -> void:
	visibility = value
	emit_changed()
	request_apply_changes()

func set_disable_collision(value: bool) -> void:
	disable_collision = value
	emit_changed()
	request_apply_changes()

func _on_available_events_changed(events: Array) -> void:
	event_instances = events.duplicate(true)
	if _ensure_valid_target(true):
		request_apply_changes()
	emit_changed()

func _on_event_refs_changed(refs: Array) -> void:
	event_instances = refs.duplicate(true)
	if _ensure_valid_target(true):
		request_apply_changes()
	emit_changed()

func _reload_events() -> void:
	if _event_manager == null:
		return
	event_instances = _event_manager.get_event_refs_for_active_map()
	if _ensure_valid_target(true):
		request_apply_changes()
	emit_changed()

func _on_active_map_changed(_map_id: String) -> void:
	_reload_events()

func _ensure_valid_target(allow_fallback: bool) -> bool:
	var before_id := target_id
	var before_name := target_name
	_resolve_target_name()
	if target_id != "" and _event_name_from_id(target_id) != "":
		return target_id != before_id or target_name != before_name
	if not allow_fallback:
		return target_id != before_id or target_name != before_name
	target_id = ""
	target_name = ""
	for ev in event_instances:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var id := str(ev.get("id", ""))
		if id == "":
			continue
		target_id = id
		target_name = str(ev.get("name", ""))
		break
	return target_id != before_id or target_name != before_name

func _resolve_target_name() -> void:
	if target_id == "":
		return
	var resolved := _event_name_from_id(target_id)
	if resolved != "" and target_name != resolved:
		target_name = resolved

func _event_name_from_id(event_id: String) -> String:
	if _event_manager != null:
		var resolved := _event_manager.resolve_event_name(event_id)
		if resolved != "":
			return resolved
	for ev in event_instances:
		if typeof(ev) == TYPE_DICTIONARY and str(ev.get("id", "")) == event_id:
			return str(ev.get("name", ""))
	return ""
