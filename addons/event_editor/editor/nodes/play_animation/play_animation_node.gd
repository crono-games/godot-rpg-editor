@tool
extends EventCommandNode
class_name PlayAnimationNode

@export var animation_selector: OptionButton
@export var target_selector: OptionButton
@export var wait_completion_check: CheckBox

const TARGET_CURRENT := "__current__"
const TARGET_PLAYER := "__player__"

var animation_id := ""
var target_id := TARGET_CURRENT
var wait_for_completion := false
var available_events: Array = []
var available_animations: Array = []
var _animation_display_to_runtime: Dictionary = {}
var _animation_runtime_to_display: Dictionary = {}

func _ready() -> void:
	super._ready()
	if target_selector != null and not target_selector.item_selected.is_connected(_on_target_selected):
		target_selector.item_selected.connect(_on_target_selected)
	if animation_selector != null and not animation_selector.item_selected.is_connected(_on_animation_selected):
		animation_selector.item_selected.connect(_on_animation_selected)
	if wait_completion_check != null and not wait_completion_check.toggled.is_connected(_on_wait_toggled):
		wait_completion_check.toggled.connect(_on_wait_toggled)

func _on_changed() -> void:
	_rebuild_target_selector()
	_rebuild_animation_selector()
	if wait_completion_check != null:
		wait_completion_check.button_pressed = wait_for_completion
	_refresh_node_size()

func _rebuild_target_selector() -> void:
	if target_selector == null:
		return
	target_selector.clear()
	var options := get_target_options()
	for option in options:
		var idx := target_selector.item_count
		target_selector.add_item(str(option.get("label", "")))
		target_selector.set_item_metadata(idx, str(option.get("id", "")))
	var selected := get_selected_target_index()
	if selected >= 0 and selected < target_selector.item_count:
		target_selector.select(selected)

func _rebuild_animation_selector() -> void:
	if animation_selector == null:
		return
	animation_selector.clear()
	var options := get_animation_options()
	for anim_name in options:
		animation_selector.add_item(str(anim_name))
	var selected := get_selected_animation_index()
	if selected >= 0 and selected < animation_selector.item_count:
		animation_selector.select(selected)

func _on_target_selected(index: int) -> void:
	set_target_by_index(index)

func _on_animation_selected(index: int) -> void:
	set_animation_by_index(index)

func _on_wait_toggled(value: bool) -> void:
	set_wait_for_completion(value)

func _refresh_node_size() -> void:
	size = Vector2.ZERO
	call_deferred("_refresh_node_size_deferred")

func _refresh_node_size_deferred() -> void:
	size = Vector2.ZERO
	if has_method("reset_size"):
		reset_size()

#region User Intention


func import_params(params: Dictionary) -> void:
	animation_id = str(params.get("animation_id", ""))
	target_id = str(params.get("target_id", ""))
	# Legacy values are no longer exposed in UI; fallback to first event.
	if target_id == TARGET_CURRENT or target_id == TARGET_PLAYER:
		target_id = ""
	wait_for_completion = bool(params.get("wait_for_completion", false))
	emit_changed()

func export_params() -> Dictionary:
	return {
		"animation_id": animation_id,
		"target_id": target_id,
		"wait_for_completion": wait_for_completion
	}

func load_from_data(data: NodeData) -> void:
	_data = data
	import_params(data.params)
	if EventEditorManager != null:
		_on_available_events_changed(EventEditorManager.get_event_refs_for_active_map())
	else:
		available_events = []
	refresh_animation_options()
	emit_changed()

func get_target_options() -> Array:
	var items: Array = []
	for ev in available_events:
		var id := str(ev.get("id", ""))
		var name := str(ev.get("name", id))
		if id == "":
			continue
		items.append({"id": id, "label": name})
	return items

func get_selected_target_index() -> int:
	var options := get_target_options()
	for i in options.size():
		if str(options[i].get("id", "")) == target_id:
			return i
	return -1

func set_target_by_index(index: int) -> void:
	var options := get_target_options()
	if index < 0 or index >= options.size():
		return
	target_id = str(options[index].get("id", ""))
	refresh_animation_options()
	if available_animations.find(animation_id) == -1 and available_animations.size() > 0:
		animation_id = str(available_animations[0])
	emit_changed()
	request_apply_changes()

func get_animation_options() -> Array:
	return available_animations.duplicate(true)

func get_selected_animation_index() -> int:
	var display = _animation_runtime_to_display.get(animation_id, animation_id)
	var idx := available_animations.find(display)
	if idx == -1 and available_animations.size() > 0:
		return 0
	return idx

func set_animation_by_index(index: int) -> void:
	if index < 0 or index >= available_animations.size():
		return
	var display_name := str(available_animations[index])
	animation_id = str(_animation_display_to_runtime.get(display_name, display_name))
	emit_changed()
	request_apply_changes()

func set_wait_for_completion(value: bool) -> void:
	wait_for_completion = value
	emit_changed()
	request_apply_changes()

func _on_available_events_changed(events: Array) -> void:
	available_events = events.duplicate(true)
	_ensure_valid_target()
	refresh_animation_options()
	emit_changed()

func _on_event_refs_changed(refs: Array) -> void:
	available_events = refs.duplicate(true)
	_ensure_valid_target()
	refresh_animation_options()
	emit_changed()

func _reload_events() -> void:
	if _event_manager == null:
		return
	available_events = _event_manager.get_event_refs_for_active_map()
	_ensure_valid_target()
	refresh_animation_options()
	emit_changed()

func _on_active_map_changed(_map_id: String) -> void:
	if _event_manager != null:
		available_events = _event_manager.get_event_refs_for_active_map().duplicate(true)
	_ensure_valid_target()
	refresh_animation_options()
	emit_changed()

func _on_active_event_changed(_event_id: String) -> void:
	# Keep stable: this node now targets explicit events only.
	pass

func refresh_animation_options() -> void:
	available_animations.clear()
	_animation_display_to_runtime.clear()
	_animation_runtime_to_display.clear()

	var target := _resolve_target_node_for_editor()
	var player := _resolve_animation_player(target)
	var runtime_names: Array = []
	if player != null:
		runtime_names = _collect_animation_names(player)
	_build_animation_display_map(runtime_names)

	if available_animations.is_empty():
		var defaults := [
			"idle_down", "idle_up", "idle_left", "idle_right",
			"move_down", "move_up", "move_left", "move_right"
		]
		for anim_name in defaults:
			var key := str(anim_name)
			available_animations.append(key)
			_animation_display_to_runtime[key] = key
			_animation_runtime_to_display[key] = key

	if animation_id == "" and available_animations.size() > 0:
		var first_display := str(available_animations[0])
		animation_id = str(_animation_display_to_runtime.get(first_display, first_display))
	elif not _animation_runtime_to_display.has(animation_id):
		var custom_display := _display_name_for_runtime(animation_id)
		available_animations.append(custom_display)
		_animation_display_to_runtime[custom_display] = animation_id
		_animation_runtime_to_display[animation_id] = custom_display

func _resolve_target_node_for_editor() -> Node:
	var scene_root: Node = null
	if Engine.is_editor_hint():
		scene_root = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return null
	var event_id := target_id
	if event_id == "":
		return null
	for node in scene_root.get_tree().get_nodes_in_group("EventInstance"):
		if str(node.get("id")) == event_id:
			return node
	return null

func _ensure_valid_target() -> void:
	if available_events.is_empty():
		target_id = ""
		return
	for ev in available_events:
		if str(ev.get("id", "")) == target_id:
			return
	target_id = str(available_events[0].get("id", ""))

func _resolve_animation_player(target: Node) -> AnimationPlayer:
	if target == null:
		return null
	if target.has_method("get"):
		var direct = target.get("animation_player")
		if direct is AnimationPlayer:
			return direct as AnimationPlayer
	if target.has_node("AnimationPlayer"):
		var from_node := target.get_node("AnimationPlayer")
		if from_node is AnimationPlayer:
			return from_node as AnimationPlayer
	return null

func _collect_animation_names(player: AnimationPlayer) -> Array:
	var out: Array = []
	if player == null:
		return out
	# Keep existing behavior.
	for anim_name in player.get_animation_list():
		var key := str(anim_name)
		if not out.has(key):
			out.append(key)
	# Also enumerate named animation libraries explicitly (custom/boss/etc).
	for lib_name in player.get_animation_library_list():
		var lib_key := str(lib_name)
		var lib := player.get_animation_library(lib_name)
		if lib == null:
			continue
		for anim_name in lib.get_animation_list():
			var raw := str(anim_name)
			var runtime_name := raw if lib_key == "" else "%s/%s" % [lib_key, raw]
			if not out.has(runtime_name):
				out.append(runtime_name)
	return out

func _build_animation_display_map(runtime_names: Array) -> void:
	var suffix_count: Dictionary = {}
	for runtime_name in runtime_names:
		var suffix := _display_name_for_runtime(str(runtime_name))
		suffix_count[suffix] = int(suffix_count.get(suffix, 0)) + 1

	for runtime_name in runtime_names:
		var runtime_key := str(runtime_name)
		var suffix := _display_name_for_runtime(runtime_key)
		var display := suffix if int(suffix_count.get(suffix, 0)) <= 1 else runtime_key
		if not available_animations.has(display):
			available_animations.append(display)
		_animation_display_to_runtime[display] = runtime_key
		_animation_runtime_to_display[runtime_key] = display

func _display_name_for_runtime(runtime_name: String) -> String:
	var slash := runtime_name.rfind("/")
	if slash == -1:
		return runtime_name
	return runtime_name.substr(slash + 1)
