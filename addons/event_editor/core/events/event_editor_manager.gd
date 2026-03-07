@tool
extends Node
# Editor-only context singleton.
# Responsibilities:
# - active editor selection (map/event/state)
# - editor-facing map event refs and signals for node UIs
# - global state lists (flags/variables) for editor widgets
# Not used by runtime gameplay execution.

signal maps_changed
signal active_map_changed(map_id)
signal active_event_changed(event_id)
signal events_changed(events)

signal states_changed(states: Array)
signal flags_changed(flags: Array)
signal variables_changed(variables: Array)

var _global_state: GlobalState

var _states: Array = []

var _map_repo : MapRepository
var _maps: Array[String] = []

var _events: Array = []

var active_map_id := ""
var active_event_id := ""

func initialize() -> void:
	_map_repo = MapRepository.new()
	refresh_maps()

func get_map_repository() -> MapRepository:
	return _map_repo

func get_maps() -> Array[String]:
	return _maps

func refresh_maps() -> void:
	if _map_repo == null:
		return

	_maps = _map_repo.get_maps()
	emit_signal("maps_changed")

func set_active_map(map_id: String) -> void:
	if active_map_id == map_id:
		return

	active_map_id = map_id
	active_event_id = ""

	_load_events(map_id)

	emit_signal("active_map_changed", map_id)
	emit_signal("events_changed", _events)


func _load_events(map_id: String) -> void:
	if map_id == "" or _map_repo == null:
		_events.clear()
		return
	_events = _map_repo.get_events_for_map(map_id)

func refresh_events_for_active_map(scene_root: Node = null) -> void:
	var events: Array = []
	if scene_root != null:
		var scene_path := ""
		if scene_root.scene_file_path != "":
			scene_path = scene_root.scene_file_path
			events = _map_repo.get_events_from_root(scene_root)

## Used to get EventInstances


func get_events_for_active_map() -> Array:
	return _events

## Used for Map Selector (not includes Player)

func get_events_for_map_selector() -> Array:
	var out: Array = []
	for ev in _events:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		if bool(ev.get("is_player", false)):
			continue
		out.append(ev)
	return out

## Used for Graph Nodes to populate OptionButton

func get_event_refs_for_active_map() -> Array:
	var refs: Array = []
	for ev in _events:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var id := str(ev.get("id", "")).strip_edges()
		if id == "":
			continue
		refs.append({
			"id": id,
			"name": str(ev.get("name", id))
		})
	return refs


func resolve_event_name(event_id: String) -> String:
	var id := event_id.strip_edges()
	for ev in _events:
		if str(ev.get("id", "")) == id:
			return str(ev.get("name", id))
	return ""

func resolve_event_id(event_name: String) -> String:
	var name := event_name.strip_edges()
	for ev in _events:
		if str(ev.get("name", "")) == name:
			return str(ev.get("id", ""))
	return ""

func set_active_event(event_id: String) -> void:
	if active_event_id == event_id:
		return
	active_event_id = event_id
	emit_signal("active_event_changed", event_id)

func set_states(states: Array) -> void:
	_states = states.duplicate(true)
	emit_signal("states_changed", _states)

func get_states() -> Array:
	return _states.duplicate(true)

func get_global_state() -> GlobalState:
	return _global_state

func _set_global_state(state: GlobalState) -> void:
	if _global_state != null and _global_state.flags_changed.is_connected(_on_global_flags_changed):
		_global_state.flags_changed.disconnect(_on_global_flags_changed)
	if _global_state != null and _global_state.variables_changed.is_connected(_on_global_variables_changed):
		_global_state.variables_changed.disconnect(_on_global_variables_changed)

	_global_state = state
	if _global_state != null and not _global_state.flags_changed.is_connected(_on_global_flags_changed):
		_global_state.flags_changed.connect(_on_global_flags_changed)
	if _global_state != null and not _global_state.variables_changed.is_connected(_on_global_variables_changed):
		_global_state.variables_changed.connect(_on_global_variables_changed)

	emit_signal("flags_changed", get_flags())
	emit_signal("variables_changed", get_variables())

func get_flags() -> Array:
	if _global_state == null:
		return []
	var names := []
	for entry in _global_state.get_flags().values():
		if entry == null:
			continue
		var label := str(entry.name)
		if label == "":
			label = str(entry.id)
		names.append(label)
	names.sort()
	return names

func get_variables() -> Array:
	if _global_state == null:
		return []
	var names := []
	for entry in _global_state.get_variables().values():
		if entry == null:
			continue
		var label := str(entry.name)
		if label == "":
			label = str(entry.id)
		names.append(label)
	names.sort()
	return names

func get_all_variables() -> Array:
	return get_variables()

func _on_global_flags_changed() -> void:
	emit_signal("flags_changed", get_flags())

func _on_global_variables_changed() -> void:
	emit_signal("variables_changed", get_variables())
