class_name GraphRepository
extends RefCounted

var graphs_path := "res://events/"
var serializer := EventGraphSerializer.new()

func load_event(event_id: String, model: EventGraphModel) -> bool:
	var path := graphs_path + event_id + ".json"

	if not FileAccess.file_exists(path):
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return false

	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false

	serializer.load_into(model, data)
	return true

func save_event(event_id: String, model: EventGraphModel) -> void:
	var path := graphs_path + event_id + ".json"

	var data := serializer.save(model)
	var json := JSON.stringify(data, "\t")

	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(json)
