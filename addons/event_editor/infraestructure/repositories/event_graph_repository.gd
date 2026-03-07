class_name EventGraphRepository
extends RefCounted

func load_map(map_id: String) -> Dictionary:
	# devuelve el JSON completo del mapa
	return {}

func save_map(map_id: String, data: Dictionary) -> void:
	pass

func has_map(map_id: String) -> bool:
	return false
