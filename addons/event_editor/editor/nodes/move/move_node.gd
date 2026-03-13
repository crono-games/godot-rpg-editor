@tool
extends EventCommandNode
class_name MoveNode

@export var event_selector: OptionButton
@export var action_type: OptionButton
@export var list_container: VBoxContainer
@export var spin_box: SpinBox
@export var button_container: GridContainer
@export var wait_completion_check: CheckBox
@export var wait_container: VBoxContainer

var event_manager: EventEditorManager = EventEditorManager
var available_events: Array = []
var route: Array = []
var wait_for_completion := true

#region Interface

func _ready() -> void:
	super._ready()
	_connect_move_buttons()

func _connect_move_buttons() -> void:
	for btn in button_container.get_children():
		if btn is Button:
			var dir: Vector3 = btn.get_meta("move_vec")
			btn.pressed.connect(
				_on_button_pressed.bind(dir)
			)

func _on_changed() -> void:
	_rebuild_event_selector()
	_rebuild_route_list()
	_refresh_node_size()

	if wait_completion_check != null:
		wait_completion_check.button_pressed = wait_for_completion
	_sync_action_ui()

func _rebuild_event_selector() -> void:
	var prev_id = get_selected_event()
	event_selector.clear()
	var selected_idx := -1
	for ev in available_events:
		var name := str(ev.get("name", ""))
		var id := str(ev.get("id", ""))
		var idx := event_selector.item_count
		event_selector.add_item(name)
		event_selector.set_item_metadata(idx, id)
		if id == prev_id:
			selected_idx = idx
	if selected_idx >= 0:
		event_selector.select(selected_idx)
	elif event_selector.item_count > 0:
		event_selector.select(0)

func _rebuild_route_list() -> void:
	for c in list_container.get_children():
		c.queue_free()

	var items = get_route_items()
	for i in items.size():
		_add_route_item(items[i], i)

func _add_route_item(step: Dictionary, index: int) -> void:
	var hbox := HBoxContainer.new()
	var line := LineEdit.new()
	line.text = _format_step(step)
	line.placeholder_text = _format_step(step)
	line.flat = true
	line.editable = false
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	var del := Button.new()
	del.icon = load("res://addons/event_editor/icons/Remove.svg")
	del.pressed.connect(func(): remove_step(index))
	hbox.add_child(line)
	hbox.add_child(del)
	list_container.add_child(hbox)

func _on_button_pressed(direction: Vector3) -> void:
	add_move_step(
		get_selected_event(),
		direction,
		get_selected_action_type(),
	)

func _on_wait_button_pressed() -> void:
	add_wait_step(int(spin_box.value))

func _on_wait_completion_toggled(value: bool) -> void:
	set_wait_for_completion(value)

func _on_event_selector_item_selected(_index: int) -> void:
	_refresh_node_size()

func _on_action_type_item_selected(_index: int) -> void:
	_sync_action_ui()
	_refresh_node_size()

func get_selected_event() -> String:
	var idx := event_selector.selected
	if idx < 0:
		return ""
	var meta = event_selector.get_item_metadata(idx)
	if typeof(meta) == TYPE_STRING and meta != "":
		return meta
	return event_selector.get_item_text(idx)

func get_selected_action_type() -> String:
	if action_type == null or action_type.selected < 0:
		return "Move"
	return action_type.get_item_text(action_type.selected)

func _format_step(step: Dictionary) -> String: 
	var action := str(step.get("action_type", "")).to_lower()
	if action == "wait":
		return "Wait %d frames" % step.duration 
	
	var d = step.direction 
	var v := Vector3(d.x, d.y, d.z) 

	var target_id := str(step.get("target_id", ""))
	var label := str(step.get("target_name", ""))
	if label == "":
		var name := get_event_name_by_id(target_id)
		if name != "":
			label = name
	if label == "":
		label = target_id
	var verb := "Move"
	if action == "turn":
		verb = "Turn"
	return "[%s] %s %s" % [label, verb, _vec_to_str(v)] 
	
func _vec_to_str(v: Vector3) -> String: 
	if v == Vector3.LEFT: return "Left" 
	if v == Vector3.RIGHT: return "Right" 
	if v == Vector3.FORWARD: return "Up" 
	if v == Vector3.BACK: return "Down" 
	if v == Vector3.ZERO: return "Keep" 
	return "Custom"

func _refresh_node_size() -> void:
	size = Vector2.ZERO

#endregion

#region User Intention

func _sync_action_ui() -> void:
	var selected := get_selected_action_type().to_lower()
	var is_wait := selected == "wait"
	if wait_container != null:
		wait_container.visible = is_wait
	if button_container != null:
		button_container.visible = not is_wait
		for btn in button_container.get_children():
			if btn is Button and btn.has_meta("move_vec"):
				var vec = btn.get_meta("move_vec")

func import_params(params: Dictionary) -> void:
	route = params.get("route", []).duplicate(true)
	wait_for_completion = bool(params.get("wait_for_completion", true))
	_upgrade_route_targets()
	emit_changed()

func export_params() -> Dictionary:
	return {
		"route": route.duplicate(true),
		"wait_for_completion": wait_for_completion
	}

func add_move_step(target: String, direction: Vector3, action_type: String) -> void:
	route = route.duplicate(true)
	var target_name := ""
	if target != "":
		target_name = get_event_name_by_id(target)
	var step := {
		"action_type": action_type,
		"target_id": target,
		"target_name": target_name,
		"direction": {
			"x": direction.x,
			"y": direction.y,
			"z": direction.z
		}
	}
	route.append(step)
	emit_changed()
	request_apply_changes()

func set_wait_for_completion(value: bool) -> void:
	wait_for_completion = value
	emit_changed()
	request_apply_changes()

func add_wait_step(duration: int) -> void:
	route = route.duplicate(true)
	route.append({
		"action_type": "wait",
		"duration": duration
	})
	emit_changed()
	request_apply_changes()

func remove_step(index : int) -> void:
	route = route.duplicate(true)
	if index < 0 or index >= route.size():
		return
	route.remove_at(index)
	emit_changed()
	request_apply_changes()

func get_route_items() -> Array:
	return route.duplicate(true)

func load_from_data(data: NodeData) -> void:
	_data = data
	if EventEditorManager != null:
		available_events = EventEditorManager.get_event_refs_for_active_map()
	else:
		available_events = []
	_upgrade_route_targets()
	_rebuild_event_selector()

	emit_changed()

func _on_available_events_changed(events: Array) -> void:
	available_events = events
	_upgrade_route_targets()
	emit_changed()

func _reload_events() -> void:
	if event_manager == null:
		available_events = []
		emit_changed()
		return
	available_events = event_manager.get_event_refs_for_active_map()
	_upgrade_route_targets()
	emit_changed()

func _on_active_map_changed(_map_id: String) -> void:
	_reload_events()

func _on_event_refs_changed(refs: Array) -> void:
	available_events = refs.duplicate(true)
	_upgrade_route_targets()
	emit_changed()

func get_event_name_by_id(event_id: String) -> String:
	if event_manager != null:
		var resolved = event_manager.resolve_event_name(event_id)
		if resolved != "":
			return resolved
	for ev in available_events:
		if ev.get("id", "") == event_id:
			return str(ev.get("name", ""))
	return ""

func _event_id_from_name(name: String) -> String:
	if event_manager != null:
		var resolved = event_manager.resolve_event_id(name)
		if resolved != "":
			return resolved
	for ev in available_events:
		if ev.get("name", "") == name:
			return str(ev.get("id", ""))
	return ""

func _upgrade_route_targets() -> void:
	if route.is_empty():
		return
	var changed := false
	var new_route := route.duplicate(true)
	for i in new_route.size():
		var step = new_route[i]
		if typeof(step) != TYPE_DICTIONARY:
			continue
		if step.get("action_type", "") != "move":
			continue
		if step.has("target_id"):
			if not step.has("target_name"):
				var name := get_event_name_by_id(str(step.get("target_id", "")))
				if name != "":
					step["target_name"] = name
					new_route[i] = step
					changed = true
			continue
	if changed:
		route = new_route

func emit_changed():
	emit_signal("changed")

func request_apply_changes():
	emit_signal("request_apply", self)
#endregion
