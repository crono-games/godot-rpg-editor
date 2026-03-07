class_name EventGraphSerializer
extends RefCounted

# ================================
# Public API
# ================================

func save(model: EventGraphModel) -> Dictionary:
	return {
		"nodes": _save_nodes(model),
		"edges": _save_edges(model)
	}

func load_into(model: EventGraphModel, data: Dictionary) -> void:
	model.clear()
	_load_nodes(model, data)
	_load_edges(model, data)


# ================================
# Load helpers
# ================================

func load_event(
	model: EventGraphModel,
	map_data: Dictionary,
	event_id: String
) -> void:
	model.clear()

	var events = map_data.get("events", {})
	if not events.has(event_id):
		return

	var event_data = events[event_id]
	var flow = event_data.get("flow", {})

	_load_nodes(model, flow)
	_load_edges(model, flow)

func save_event(
	model: EventGraphModel,
	map_data: Dictionary,
	event_id: String
) -> Dictionary:
	if not map_data.has("events"):
		map_data["events"] = {}

	map_data["events"][event_id] = {
		"flow": {
			"nodes": _save_nodes(model),
			"edges": _save_edges(model)
		}
	}

	return map_data



func _load_nodes(model: EventGraphModel, flow: Dictionary) -> void:
	var nodes = flow.get("nodes", {})

	for node_id in nodes:
		var n = nodes[node_id]
		var pos = n.get("position", [0, 0])

		model.add_node(
			NodeData.new(
				node_id,
				n.get("type", ""),
				Vector2(pos[0], pos[1])
			)
		)
		model.get_node(node_id).params = n.get("params", {}).duplicate(true)



func _load_edges(model: EventGraphModel, flow: Dictionary) -> void:
	var edges = flow.get("edges", [])

	for e in edges:
		model.add_edge(
			e.get("from"),
			e.get("from_port", 0),
			e.get("to"),
			e.get("to_port", 0)
		)


# ================================
# Save helpers
# ================================

func _save_nodes(model: EventGraphModel) -> Dictionary:
	var result := {}

	for node_id in model.get_node_ids():
		var node = model.get_node(node_id)

		result[node_id] = {
			"type": node.type,
			"position": [node.position.x, node.position.y],
			"params": node.params.duplicate(true)
		}

	return result


func _save_edges(model: EventGraphModel) -> Array:
	var result := []

	for e in model.get_edges():
		result.append({
			"from": e.from_node,
			"from_port": e.from_port,
			"to": e.to_node,
			"to_port": e.to_port
		})

	return result
