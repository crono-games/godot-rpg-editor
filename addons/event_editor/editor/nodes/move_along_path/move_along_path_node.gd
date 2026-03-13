@tool
extends EventCommandNode
class_name MoveAlongPathNode

@export var target_selector: OptionButton
@export var points_count_label: Label
@export var speed_spin: SpinBox
@export var loop_check: CheckBox
@export var wait_check: CheckBox
@export var return_back_check: CheckBox
@export var snap_to_first_check: CheckBox
@export var path_picker_popup: PathPickerPopup
@export var path_preview: PathPreviewControl

var event_instances: Array = []
var selected_target_id: String = ""
var selected_target_name: String = ""
var points: Array = []
var speed_px_per_sec: float = 64.0
var loop: bool = false
var wait_for_completion: bool = true
var return_back_on_finish: bool = false
var snap_to_first_point: bool = false
var curve_enabled: bool = false
var curve_subdivisions: int = 6

func _ready() -> void:
	super._ready()
	if target_selector != null and not target_selector.item_selected.is_connected(_on_target_selected):
		target_selector.item_selected.connect(_on_target_selected)
	if speed_spin != null and not speed_spin.value_changed.is_connected(_on_speed_changed):
		speed_spin.value_changed.connect(_on_speed_changed)
	if loop_check != null and not loop_check.toggled.is_connected(_on_loop_toggled):
		loop_check.toggled.connect(_on_loop_toggled)
	if wait_check != null and not wait_check.toggled.is_connected(_on_wait_toggled):
		wait_check.toggled.connect(_on_wait_toggled)
	if return_back_check != null and not return_back_check.toggled.is_connected(_on_return_back_toggled):
		return_back_check.toggled.connect(_on_return_back_toggled)
	if snap_to_first_check != null and not snap_to_first_check.toggled.is_connected(_on_snap_to_first_toggled):
		snap_to_first_check.toggled.connect(_on_snap_to_first_toggled)
	if path_picker_popup != null and not path_picker_popup.points_confirmed.is_connected(_on_points_confirmed):
		path_picker_popup.points_confirmed.connect(_on_points_confirmed)

func _on_changed() -> void:
	_rebuild_target_selector()
	_refresh_points_summary()
	if speed_spin != null:
		speed_spin.value = speed_px_per_sec
	if loop_check != null:
		loop_check.button_pressed = loop
	if wait_check != null:
		wait_check.button_pressed = wait_for_completion
	if return_back_check != null:
		return_back_check.button_pressed = return_back_on_finish
	if snap_to_first_check != null:
		snap_to_first_check.button_pressed = snap_to_first_point
	if path_preview != null:
		path_preview.set_points(get_points())
	if path_picker_popup != null:
		path_picker_popup.set_curve_enabled(curve_enabled)
		path_picker_popup.set_curve_subdivisions(curve_subdivisions)

func _rebuild_target_selector() -> void:
	if target_selector == null:
		return
	target_selector.clear()
	var items := get_event_options()
	for i in items.size():
		var ev = items[i]
		var name := str(ev.get("name", ""))
		var id := str(ev.get("id", ""))
		var idx := target_selector.item_count
		target_selector.add_item(name)
		target_selector.set_item_metadata(idx, id)

	var idx := get_selected_index()
	if idx >= 0 and idx < target_selector.item_count:
		target_selector.select(idx)
	elif target_selector.item_count > 0:
		target_selector.select(0)

func _refresh_points_summary() -> void:
	if points_count_label == null:
		return
	points_count_label.text = "%d points" % get_points().size()

func _on_target_selected(index: int) -> void:
	set_selected_by_index(index)

func _on_pick_pressed() -> void:
	path_picker_popup.open_with_points(get_points())

func _on_clear_points_pressed() -> void:
	clear_points()

func _on_speed_changed(value: float) -> void:
	set_speed(value)

func _on_loop_toggled(value: bool) -> void:
	set_loop(value)

func _on_wait_toggled(value: bool) -> void:
	set_wait_for_completion(value)

func _on_return_back_toggled(value: bool) -> void:
	set_return_back_on_finish(value)

func _on_snap_to_first_toggled(value: bool) -> void:
	set_snap_to_first_point(value)

func _on_points_confirmed(points: Array) -> void:
	set_points_world(points)
	if path_picker_popup != null:
		set_curve_enabled(path_picker_popup.get_curve_enabled())
		set_curve_subdivisions(path_picker_popup.get_curve_subdivisions())

func set_scene_root_provider(provider: Callable) -> void:
	if path_picker_popup != null:
		path_picker_popup.set_scene_root_provider(provider)
		path_picker_popup.set_pixels_per_cell(32.0)

#region User Intention


func import_params(params: Dictionary) -> void:
	selected_target_id = str(params.get("target_id", ""))
	selected_target_name = str(params.get("target_name", ""))
	points = _parse_points(params.get("points", []))
	speed_px_per_sec = maxf(1.0, float(params.get("speed_px_per_sec", params.get("speed", 64.0))))
	loop = bool(params.get("loop", false))
	wait_for_completion = bool(params.get("wait_for_completion", true))
	return_back_on_finish = bool(params.get("return_back_on_finish", false))
	snap_to_first_point = bool(params.get("snap_to_first_point", false))
	curve_enabled = bool(params.get("curve_enabled", false))
	curve_subdivisions = maxi(1, int(params.get("curve_subdivisions", 6)))
	_ensure_valid_selection(false)
	emit_changed()

func export_params() -> Dictionary:
	return {
		"target_id": selected_target_id,
		"target_name": selected_target_name,
		"points": _export_points(),
		"speed_px_per_sec": speed_px_per_sec,
		"loop": loop,
		"wait_for_completion": wait_for_completion,
		"return_back_on_finish": return_back_on_finish,
		"snap_to_first_point": snap_to_first_point,
		"curve_enabled": curve_enabled,
		"curve_subdivisions": curve_subdivisions
	}

func load_from_data(data: NodeData) -> void:
	_data = data
	if EventEditorManager != null:
		event_instances = EventEditorManager.get_event_refs_for_active_map()
	else:
		event_instances = []
	import_params(data.params)

func get_event_options() -> Array:
	return event_instances.duplicate(true)

func get_selected_index() -> int:
	if event_instances.is_empty():
		return -1
	for i in event_instances.size():
		var ev = event_instances[i]
		if typeof(ev) == TYPE_DICTIONARY and str(ev.get("id", "")) == selected_target_id:
			return i
	return -1

func set_selected_by_index(index: int) -> void:
	if index < 0 or index >= event_instances.size():
		return
	var ev = event_instances[index]
	if typeof(ev) != TYPE_DICTIONARY:
		return
	selected_target_id = str(ev.get("id", ""))
	selected_target_name = str(ev.get("name", ""))
	emit_changed()
	request_apply_changes()

func add_point_world(pos: Vector3) -> void:
	points.append(_to_vec2(pos))
	emit_changed()
	request_apply_changes()

func set_points_world(new_points: Array) -> void:
	points = []
	for p in new_points:
		if p is Vector2:
			points.append(p)
		elif p is Vector3:
			points.append(_to_vec2(p))
		elif p is Dictionary:
			points.append(Vector2(float(p.get("x", 0.0)), float(p.get("y", p.get("z", 0.0)))))
	emit_changed()
	request_apply_changes()

func remove_point(index: int) -> void:
	if index < 0 or index >= points.size():
		return
	points.remove_at(index)
	emit_changed()
	request_apply_changes()

func clear_points() -> void:
	if points.is_empty():
		return
	points.clear()
	emit_changed()
	request_apply_changes()

func set_speed(value: float) -> void:
	speed_px_per_sec = maxf(1.0, value)
	emit_changed()
	request_apply_changes()

func set_loop(value: bool) -> void:
	loop = value
	emit_changed()
	request_apply_changes()

func set_wait_for_completion(value: bool) -> void:
	wait_for_completion = value
	emit_changed()
	request_apply_changes()

func set_return_back_on_finish(value: bool) -> void:
	return_back_on_finish = value
	emit_changed()
	request_apply_changes()

func set_snap_to_first_point(value: bool) -> void:
	snap_to_first_point = value
	emit_changed()
	request_apply_changes()

func set_curve_enabled(value: bool) -> void:
	curve_enabled = value
	emit_changed()
	request_apply_changes()

func set_curve_subdivisions(value: int) -> void:
	curve_subdivisions = maxi(1, value)
	emit_changed()
	request_apply_changes()

func get_points() -> Array:
	return points.duplicate(true)

func _on_available_events_changed(events: Array) -> void:
	event_instances = events
	if _ensure_valid_selection(true):
		request_apply_changes()
	emit_changed()

func _on_event_refs_changed(refs: Array) -> void:
	event_instances = refs.duplicate(true)
	if _ensure_valid_selection(true):
		request_apply_changes()
	emit_changed()

func _reload_events() -> void:
	if _event_manager == null:
		return
	event_instances = _event_manager.get_event_refs_for_active_map()
	if _ensure_valid_selection(true):
		request_apply_changes()
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

func _parse_points(value) -> Array:
	var out: Array = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				out.append(Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0))))
			elif item is Vector2:
				out.append(item)
			elif item is Vector3:
				out.append(Vector2(item.x, item.z if absf(item.z) > 0.0001 else item.y))
	return out

func _export_points() -> Array:
	var out: Array = []
	for p in points:
		if p is Vector2:
			out.append({
				"x": int(round((p as Vector2).x)),
				"y": int(round((p as Vector2).y))
			})
	return out

func _to_vec2(pos: Vector3) -> Vector2:
	return Vector2(pos.x, pos.y)
