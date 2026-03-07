class_name EventEnvironment
extends RefCounted

func set_root(_scene_root: Node) -> void:
	push_error("EventEnvironment.set_root not implemented")

func get_root() -> Node:
	push_error("EventEnvironment.get_root not implemented")
	return null

func mark_dirty() -> void:
	push_error("EventEnvironment.mark_dirty not implemented")

func reindex() -> void:
	push_error("EventEnvironment.reindex not implemented")

func get_event_by_id(_event_id: String) -> Node:
	push_error("EventEnvironment.get_event_by_id not implemented")
	return null

func get_event_by_name(_name: String) -> Node:
	push_error("EventEnvironment.get_event_by_name not implemented")
	return null

func get_player(_player_group: String = "player") -> Node:
	push_error("EventEnvironment.get_player not implemented")
	return null

func set_event_texture(_event_id: String, _texture_path: String) -> void:
	push_error("EventEnvironment.set_event_texture not implemented")

func set_event_graphics(_event_id: String, _graphics: Dictionary) -> void:
	push_error("EventEnvironment.set_event_graphics not implemented")

func set_event_position(_event_id: String, _position) -> bool:
	push_error("EventEnvironment.set_event_position not implemented")
	return false

func set_event_passability(_event_id: String, _passability: String) -> void:
	push_error("EventEnvironment.set_event_passability not implemented")

func set_event_animation_timing(_event_id: String, _anim_step_time: float, _max_cycles_per_step: float) -> void:
	push_error("EventEnvironment.set_event_animation_timing not implemented")

func set_event_behavior(_event_id: String, _template_id: String, _params: Dictionary = {}) -> void:
	push_error("EventEnvironment.set_event_behavior not implemented")

func set_event_actor_definition(_event_id: String, _actor_props: Dictionary) -> void:
	push_error("EventEnvironment.set_event_actor_definition not implemented")
