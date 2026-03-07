@tool
extends EventCommandNode
class_name SetPositionCommandNode

@export var option_button: OptionButton
@export var position_picker: PositionPickerBase
@export var facing_dir_selector: OptionButton

var _event_manager: EventEditorManager = EventEditorManager
var event_instances: Array = []
var selected_target_id: String = ""
var selected_target_name: String = ""
var target_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	super._ready()
	set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)
	if option_button != null and not option_button.item_selected.is_connected(_on_option_selected):
		option_button.item_selected.connect(_on_option_selected)
	if position_picker != null:
		if not position_picker.position_confirmed.is_connected(_on_position_confirmed):
			position_picker.position_confirmed.connect(_on_position_confirmed)
	_reload_events()

func _on_changed() -> void:
	selected_target_id = rebuild_option_button(option_button, get_event_options(), selected_target_id)
	_resolve_selected_name()

	if position_picker != null:
		position_picker.set_selected_position_world(target_position)

func _on_option_selected(id: int) -> void:
	set_selected_by_index(id)

func _on_button_pressed() -> void:
	if position_picker == null:
		return
	position_picker.update_preview()
	position_picker.popup()

func _on_position_confirmed(pos) -> void:
	set_target_position(_to_vec3(pos))

func set_scene_root_provider(provider: Callable) -> void:
	if position_picker != null:
		position_picker.set_scene_root_provider(provider)

func _to_vec3(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Vector2:
		return Vector3(value.x, value.y, 0.0)
	return Vector3.ZERO

#region User Intention


func import_params(params: Dictionary) -> void:
	selected_target_id = str(params.get("target_id", ""))
	selected_target_name = str(params.get("target_name", ""))
	if selected_target_id == "":
		var legacy_name := str(params.get("target", ""))
		if legacy_name != "":
			selected_target_id = _event_id_from_name(legacy_name)
			selected_target_name = legacy_name
	target_position = _parse_target_position(params.get("target_position", Vector3.ZERO))
	_ensure_valid_selection(false)
	emit_changed()

func export_params() -> Dictionary:
	return {
		"target_id": selected_target_id,
		"target_name": selected_target_name,
		"target_position": _to_int_position_dict(target_position)
	}

func load_from_data(data: NodeData) -> void:
	_data = data
	if EventEditorManager != null:
		if not EventEditorManager.available_events_changed.is_connected(_on_available_events_changed):
			EventEditorManager.available_events_changed.connect(_on_available_events_changed)
		event_instances = get_event_items_for_active_map()
	else:
		event_instances = []
	import_params(data.params)

func bind_event_manager(_manager: EventEditorManager) -> void:
	_event_manager = EventEditorManager
	if _event_manager == null:
		return
	if not _event_manager.events_changed.is_connected(_on_event_refs_changed):
		_event_manager.events_changed.connect(_on_event_refs_changed)
	if not _event_manager.events_changed.is_connected(_on_available_events_changed):
		_event_manager.events_changed.connect(_on_available_events_changed)
	if not _event_manager.active_map_changed.is_connected(_on_active_map_changed):
		_event_manager.active_map_changed.connect(_on_active_map_changed)
	_reload_events()

func get_event_options() -> Array:
	return event_instances.duplicate(true)

func set_selected_by_index(index: int) -> void:
	if option_button == null:
		return
	if index < 0 or index >= option_button.item_count:
		return
	selected_target_id = str(option_button.get_item_metadata(index))
	selected_target_name = str(option_button.get_item_text(index))
	emit_changed()
	emit_apply()

func set_target_position(pos: Vector3) -> void:
	target_position = _quantize_position(pos)
	emit_changed()
	emit_apply()

func _on_available_events_changed(events: Array) -> void:
	event_instances = _normalize_event_items(events)
	if _ensure_valid_selection(true):
		emit_apply()
	emit_changed()

func _on_event_refs_changed(refs: Array) -> void:
	event_instances = _normalize_event_items(refs)
	if _ensure_valid_selection(true):
		emit_apply()
	emit_changed()

func _reload_events() -> void:
	if _event_manager == null:
		return
	event_instances = get_event_items_for_active_map()
	if _ensure_valid_selection(true):
		emit_apply()
	emit_changed()

func _on_active_map_changed(_map_id: String) -> void:
	_reload_events()

func _event_id_from_name(name: String) -> String:
	if _event_manager != null:
		var resolved := _event_manager.resolve_event_id(name)
		if resolved != "":
			return resolved
	for ev in event_instances:
		if typeof(ev) == TYPE_DICTIONARY and ev.get("name", "") == name:
			return str(ev.get("id", ""))
	return ""

func _event_name_from_id(event_id: String) -> String:
	if _event_manager != null:
		var resolved := _event_manager.resolve_event_name(event_id)
		if resolved != "":
			return resolved
	for ev in event_instances:
		if typeof(ev) == TYPE_DICTIONARY and ev.get("id", "") == event_id:
			return str(ev.get("name", ""))
	return ""

func _ensure_valid_selection(allow_fallback: bool) -> bool:
	var before_id := selected_target_id
	var before_name := selected_target_name
	_resolve_selected_name()
	if selected_target_id != "" and _event_name_from_id(selected_target_id) != "":
		return selected_target_id != before_id or selected_target_name != before_name
	if not allow_fallback:
		return selected_target_id != before_id or selected_target_name != before_name
	selected_target_id = ""
	selected_target_name = ""
	for ev in event_instances:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var id := str(ev.get("id", ""))
		if id == "":
			continue
		selected_target_id = id
		selected_target_name = str(ev.get("name", ""))
		break
	return selected_target_id != before_id or selected_target_name != before_name

func _resolve_selected_name() -> void:
	if selected_target_id == "":
		return
	var name := _event_name_from_id(selected_target_id)
	if name != "" and selected_target_name != name:
		selected_target_name = name

func _normalize_event_items(items: Array) -> Array:
	var out: Array = []
	for row in items:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var it := row as Dictionary
		out.append({
			"id": str(it.get("id", "")),
			"name": str(it.get("name", ""))
		})
	return out

func _parse_target_position(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Vector2:
		return Vector3(value.x, value.y, 0)
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		var x := float(value.get("x", 0))
		var y := float(value.get("y", value.get("z", 0)))
		return Vector3(x, y, 0)
	if value is String:
		var parts = value.split(",")
		if parts.size() >= 3:
			return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	return Vector3.ZERO

func _quantize_position(pos: Vector3) -> Vector3:
	return Vector3(round(pos.x), round(pos.y), round(pos.z))

func _to_int_position_dict(pos: Vector3) -> Dictionary:
	var p := _quantize_position(pos)
	return {
		"x": int(p.x),
		"y": int(p.y),
		"z": int(p.y) # legacy mirror for older 3D-oriented payload readers
	}
