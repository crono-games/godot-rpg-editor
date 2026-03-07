class_name GraphIdGenerator
extends RefCounted

var counters := {}

func next_node_id(type: String) -> String:
	if not counters.has(type):
		counters[type] = 0

	counters[type] += 1
	return "%s_%d" % [type, counters[type]]

func next_unique_node_id(type: String, model: EventGraphModel) -> String:
	var candidate := next_node_id(type)
	if model == null:
		return candidate
	while model.has_node(candidate):
		candidate = next_node_id(type)
	return candidate

func reset_from_model(model: EventGraphModel) -> void:
	counters.clear()

	for id in model.get_node_ids():
		var id_str := str(id)
		var sep := id_str.rfind("_")
		if sep <= 0 or sep >= id_str.length() - 1:
			continue
		var type := id_str.substr(0, sep)
		var suffix := id_str.substr(sep + 1)
		if not suffix.is_valid_int():
			continue
		var index := int(suffix)

		counters[type] = max(counters.get(type, 0), index)
