@tool
extends Node
# Editor-only context singleton.
# Responsibilities:
# - active editor selection (map/event/state)
# - editor-facing map event refs and signals for node UIs
# Not used by runtime gameplay execution.

signal active_map_changed(map_id)
signal active_event_changed(event_id)
signal events_changed(events)


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
	emit_signal("events_changed", _events)

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
	if _map_repo == null:
		return
	if scene_root != null and is_instance_valid(scene_root):
		_events = _map_repo.get_events_from_root(scene_root)
	else:
		# If no scene root, avoid overwriting in-editor list (prevents flicker).
		return
	emit_signal("events_changed", _events)

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
