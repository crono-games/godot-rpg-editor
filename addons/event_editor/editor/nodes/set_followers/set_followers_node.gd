@tool
extends EventCommandNode
class_name SetFollowersNode

@export var action_selector: OptionButton
@export var actor_selector: OptionButton
@export var spin_box: SpinBox
@export var check_box: CheckBox

const ACTION_ADD := "add"
const ACTION_REMOVE := "remove"
const ACTION_CLEAR := "clear"

var _event_manager: EventEditorManager = EventEditorManager
var event_instances: Array = []

var action: String = ACTION_ADD
var actor_id: String = ""
var actor_name: String = ""
var slot_index: int = -1
var make_persistent: bool = false

func _ready() -> void:
	super._ready()
	if action_selector != null and not action_selector.item_selected.is_connected(_on_action_selected):
		action_selector.item_selected.connect(_on_action_selected)
	if actor_selector != null and not actor_selector.item_selected.is_connected(_on_actor_selected):
		actor_selector.item_selected.connect(_on_actor_selected)
	if spin_box != null:
		spin_box.visible = false
		spin_box.editable = false
		spin_box.value = -1
	if check_box != null and not check_box.toggled.is_connected(_on_persistent_toggled):
		check_box.toggled.connect(_on_persistent_toggled)

func _on_changed() -> void:
	_rebuild_action_selector()
	_rebuild_actor_selector()
	if spin_box != null:
		spin_box.value = -1
	if check_box != null:
		check_box.button_pressed = make_persistent
	_apply_mode_enabled()
	_refresh_node_size()

func _rebuild_action_selector() -> void:
	if action_selector == null:
		return
	action_selector.clear()
	var options := get_action_options()
	for option in options:
		action_selector.add_item(str(option.get("label", "")))
	var selected := get_selected_action_index()
	if selected >= 0 and selected < action_selector.item_count:
		action_selector.select(selected)

func _rebuild_actor_selector() -> void:
	if actor_selector == null:
		return
	var previous_selected_id := ""
	var previous_index := actor_selector.selected
	if previous_index >= 0 and previous_index < actor_selector.item_count:
		previous_selected_id = str(actor_selector.get_item_metadata(previous_index))

	actor_selector.clear()
	var options := get_actor_options()
	var index_by_id: Dictionary = {}
	for ev in options:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var id := str(ev.get("id", ""))
		if id == "":
			continue
		var label := str(ev.get("name", id))
		var idx := actor_selector.item_count
		actor_selector.add_item(label)
		actor_selector.set_item_metadata(idx, id)
		index_by_id[id] = idx

	# Prefer model selection, then previous UI selection, then fallback.
	var selected := get_selected_actor_index()
	if selected >= 0 and selected < actor_selector.item_count:
		actor_selector.select(selected)
	elif previous_selected_id != "" and index_by_id.has(previous_selected_id):
		var restore_idx := int(index_by_id[previous_selected_id])
		actor_selector.select(restore_idx)
		set_actor_by_index(restore_idx)
	elif actor_selector.item_count > 0 and uses_actor_selection() and actor_id == "":
		actor_selector.select(0)
		set_actor_by_index(0)

func _apply_mode_enabled() -> void:
	var needs_actor := uses_actor_selection()
	if actor_selector != null:
		actor_selector.disabled = not needs_actor
	if spin_box != null:
		spin_box.editable = false
	if check_box != null:
		check_box.disabled = action != ACTION_ADD

func _on_action_selected(index: int) -> void:
	set_action_by_index(index)

func _on_actor_selected(index: int) -> void:
	set_actor_by_index(index)

func _on_slot_changed(value: float) -> void:
	set_slot_index(int(round(value)))

func _on_persistent_toggled(value: bool) -> void:
	set_make_persistent(value)

func _refresh_node_size() -> void:
	size = Vector2.ZERO
	call_deferred("_refresh_node_size_deferred")

func _refresh_node_size_deferred() -> void:
	size = Vector2.ZERO
	if has_method("reset_size"):
		reset_size()

#region User Intention


func import_params(params: Dictionary) -> void:
	action = str(params.get("action", ACTION_ADD)).to_lower()
	if action != ACTION_ADD and action != ACTION_REMOVE and action != ACTION_CLEAR:
		action = ACTION_ADD
	actor_id = str(params.get("actor_id", ""))
	actor_name = str(params.get("actor_name", ""))
	if actor_id == "":
		var legacy_target := str(params.get("target_id", params.get("target", "")))
		if legacy_target != "":
			actor_id = legacy_target
	slot_index = -1
	make_persistent = bool(params.get("make_persistent", false))
	_ensure_valid_actor(false)
	emit_changed()

func export_params() -> Dictionary:
	return {
		"action": action,
		"actor_id": actor_id,
		"actor_name": actor_name,
		"slot_index": -1,
		"make_persistent": make_persistent
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

func get_action_options() -> Array:
	return [
		{"id": ACTION_ADD, "label": "Add"},
		{"id": ACTION_REMOVE, "label": "Remove"},
		{"id": ACTION_CLEAR, "label": "Clear"}
	]

func get_selected_action_index() -> int:
	var options := get_action_options()
	for i in options.size():
		if str(options[i].get("id", "")) == action:
			return i
	return 0

func set_action_by_index(index: int) -> void:
	var options := get_action_options()
	if index < 0 or index >= options.size():
		return
	action = str(options[index].get("id", ACTION_ADD))
	if action == ACTION_CLEAR:
		actor_id = ""
		actor_name = ""
	emit_changed()
	request_apply_changes()

func get_actor_options() -> Array:
	var out: Array = []
	for ev in event_instances:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var id := str(ev.get("id", ""))
		if id == "":
			continue
		if not _is_follower_candidate(id):
			continue
		out.append(ev)
	return out

func get_selected_actor_index() -> int:
	var options := get_actor_options()
	if options.is_empty():
		return -1
	for i in options.size():
		var ev = options[i]
		if typeof(ev) == TYPE_DICTIONARY and str(ev.get("id", "")) == actor_id:
			return i
	return -1

func set_actor_by_index(index: int) -> void:
	var options := get_actor_options()
	if index < 0 or index >= options.size():
		return
	var ev = options[index]
	if typeof(ev) != TYPE_DICTIONARY:
		return
	actor_id = str(ev.get("id", ""))
	actor_name = str(ev.get("name", ""))
	emit_changed()
	request_apply_changes()

func set_slot_index(_value: int) -> void:
	slot_index = -1
	emit_changed()
	request_apply_changes()

func set_make_persistent(value: bool) -> void:
	make_persistent = value
	emit_changed()
	request_apply_changes()

func uses_actor_selection() -> bool:
	return action != ACTION_CLEAR

func _on_available_events_changed(events: Array) -> void:
	event_instances = events.duplicate(true)
	if _ensure_valid_actor(true):
		request_apply_changes()
	emit_changed()

func _on_event_refs_changed(refs: Array) -> void:
	event_instances = refs.duplicate(true)
	if _ensure_valid_actor(true):
		request_apply_changes()
	emit_changed()

func _reload_events() -> void:
	if _event_manager == null:
		return
	event_instances = _event_manager.get_event_refs_for_active_map()
	if _ensure_valid_actor(true):
		request_apply_changes()
	emit_changed()

func _on_active_map_changed(_map_id: String) -> void:
	_reload_events()

func _ensure_valid_actor(allow_fallback: bool) -> bool:
	if not uses_actor_selection():
		return false
	var before_id := actor_id
	var before_name := actor_name
	_resolve_actor_name()
	if actor_id != "" and _event_name_from_id(actor_id) != "" and _is_follower_candidate(actor_id):
		return actor_id != before_id or actor_name != before_name
	if not allow_fallback:
		return actor_id != before_id or actor_name != before_name
	actor_id = ""
	actor_name = ""
	for ev in get_actor_options():
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var id := str(ev.get("id", ""))
		if id == "":
			continue
		actor_id = id
		actor_name = str(ev.get("name", ""))
		break
	return actor_id != before_id or actor_name != before_name

func _resolve_actor_name() -> void:
	if actor_id == "":
		return
	var resolved := _event_name_from_id(actor_id)
	if resolved != "" and actor_name != resolved:
		actor_name = resolved

func _event_name_from_id(event_id: String) -> String:
	if _event_manager != null:
		var resolved := _event_manager.resolve_event_name(event_id)
		if resolved != "":
			return resolved
	for ev in event_instances:
		if typeof(ev) == TYPE_DICTIONARY and str(ev.get("id", "")) == event_id:
			return str(ev.get("name", ""))
	return ""

func _is_follower_candidate(event_id: String) -> bool:
	if event_id == "":
		return false
	if not Engine.is_editor_hint():
		return true
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node.is_in_group("event_instance") and str(node.get("id")) == event_id:
			return node.has_method("follow_to_world")
		for child in node.get_children():
			if child is Node:
				stack.push_back(child)
	return false
