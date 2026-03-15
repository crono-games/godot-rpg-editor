class_name MapEventPersistenceService
extends RefCounted

## Responsibility: Persist event graphs to/from JSON files.
## Handles:
## - load_map / save_map: Full map data I/O
## - load_event / save_event: Individual event graph serialization
## - _prune_missing_events: Cleanup of orphaned events

var serializer := EventGraphSerializer.new()
const BASE_PATH := "res://addons/event_editor/data/runtime/maps/"

func load_map(map_id: String) -> Dictionary:
	var path := _map_path(map_id)
	if not FileAccess.file_exists(path):
		return {
			"version": 1,
			"events": {}
		}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"version": 1,
			"events": {}
		}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("error"):
		if parsed.error != OK:
			return {"version": 1, "events": {}}
		return parsed.result
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {"version": 1, "events": {}}

func save_map(map_id: String, data: Dictionary) -> void:
	var path := _map_path(map_id)
	var dir := DirAccess.open(BASE_PATH)
	if not dir:
		DirAccess.make_dir_recursive_absolute(BASE_PATH)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func has_map(map_id: String) -> bool:
	return FileAccess.file_exists(_map_path(map_id))

func load_event(map_id: String, event_id: String, model: EventGraphModel) -> bool:
	var map_data = load_map(map_id)
	if typeof(map_data) != TYPE_DICTIONARY:
		return false
	serializer.load_event(model, map_data, event_id)
	return true

func save_event(map_id: String, event_id: String, model: EventGraphModel) -> void:
	var map_data = load_map(map_id)
	serializer.save_event(model, map_data, event_id)
	_prune_missing_events(map_id, map_data)
	save_map(map_id, map_data)

func _prune_missing_events(map_id: String, map_data: Dictionary) -> void:
	var repo := MapRepository.new()
	var scene_events := repo.get_events_for_map(map_id)
	var keep := {}
	for ev in scene_events:
		keep[str(ev.get("id", ""))] = true
	var events = map_data.get("events", {})
	for key in events.keys():
		if not keep.has(str(key)):
			events.erase(key)
	map_data["events"] = events

func _map_path(map_id: String) -> String:
	return BASE_PATH + map_id + ".json"
