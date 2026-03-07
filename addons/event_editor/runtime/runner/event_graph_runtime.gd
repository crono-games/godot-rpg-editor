class_name EventGraphRuntime
extends RefCounted

var nodes := {}
var edges := []
var state_index := {}
var label_index := {}

func _init(map_data: Dictionary, event_id: String) -> void:
	var events = map_data.get("events", {})
	if not events.has(event_id):
		return
	var flow = events[event_id].get("flow", {})
	nodes = flow.get("nodes", {})
	edges = flow.get("edges", [])
	_build_state_index()
	_build_label_index()

func get_node(node_id: String) -> Dictionary:
	var node = nodes.get(node_id, null)
	if node == null:
		return {}
	return node

func get_start_node_id() -> String:
	if nodes.is_empty():
		return ""
	# Prefer explicit default state when present.
	for id in nodes.keys():
		var node = nodes[id]
		if node.get("type", "") != "state":
			continue
		var params = node.get("params", {})
		if bool(params.get("is_default", false)) or str(params.get("state_id", "")) == "default":
			return str(id)
	# Fallback: first state node.
	for id in nodes.keys():
		if nodes[id].get("type", "") == "state":
			return id
	return str(nodes.keys()[0])

func get_next(node_id: String, from_port: int = 0) -> String:
	for e in edges:
		if str(e.get("from", "")) == node_id and int(e.get("from_port", 0)) == from_port:
			return str(e.get("to", ""))
	return ""

func get_state_node_id(key: String) -> String:
	return str(state_index.get(key, ""))

func get_state_nodes() -> Array:
	var result: Array = []
	for id in nodes.keys():
		var node = nodes[id]
		if node.get("type", "") == "state":
			result.append({"id": str(id), "node": node})
	return result

func get_label_node_id(label_id: String) -> String:
	return str(label_index.get(label_id, ""))

func _build_state_index() -> void:
	state_index.clear()
	for id in nodes.keys():
		var node = nodes[id]
		if node.get("type", "") != "state":
			continue
		var params = node.get("params", {})
		var name := str(params.get("name", ""))
		var state_id := str(params.get("state_id", ""))
		if state_id == "":
			state_id = str(id)
		if name != "":
			state_index[name] = id
		state_index[state_id] = id

func _build_label_index() -> void:
	label_index.clear()
	for id in nodes.keys():
		var node = nodes[id]
		if node.get("type", "") != "label":
			continue
		var params = node.get("params", {})
		var label_id := str(params.get("label_id", "")).strip_edges()
		if label_id == "":
			continue
		label_index[label_id] = id
