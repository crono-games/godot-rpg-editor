class_name StatePropertyApplier
extends RefCounted

func apply_state_node(node: Dictionary, event_id: String, ctx: EventRuntimeContext) -> void:
	if event_id == "" or node == null:
		return
	var env := ctx.get_scene_event_environment()
	if env == null:
		return
	var params = node.get("params", {})
	var props = params.get("properties", {})
	var graphics = props.get("graphics", {})
	if typeof(graphics) != TYPE_DICTIONARY:
		graphics = {}
	var texture_path := str(graphics.get("texture", ""))
	var actor_props: Dictionary = props.get("actor", {})
	if actor_props != null and not actor_props.is_empty():
		env.set_event_actor_definition(event_id, actor_props)
	env.set_event_graphics(event_id, graphics)
	env.set_event_passability(event_id, _resolve_passability(props, texture_path, actor_props))
	# Only override animation timing when explicitly configured in state properties.
	if props.has("anim_step_time") or props.has("max_anim_cycles_per_step"):
		var anim_step_time := float(props.get("anim_step_time", 0.11))
		var max_cycles := float(props.get("max_anim_cycles_per_step", 1.0))
		env.set_event_animation_timing(event_id, anim_step_time, max_cycles)
	var behavior: Dictionary = props.get("behavior", {})
	var template_id := str(behavior.get("template_id", ""))
	var behavior_params: Dictionary = behavior.get("params", {})
	env.set_event_behavior(event_id, template_id, behavior_params)

func _resolve_passability(props: Dictionary, texture_path: String, actor_props: Dictionary = {}) -> String:
	var passability := str(props.get("passability", "auto")).to_lower()
	if passability == "passable":
		return "Passable"
	if passability == "block":
		return "Block"
	# Auto rule:
	# If the state has a graphic, block by default.
	# If the state has no graphic, passable by default.
	return "Block" if _state_has_visual(texture_path, actor_props) else "Passable"

func _state_has_visual(texture_path: String, actor_props: Dictionary) -> bool:
	if texture_path != "":
		return true
	if actor_props == null or actor_props.is_empty():
		return false
	if str(actor_props.get("texture_path", "")).strip_edges() != "":
		return true
	if str(actor_props.get("actor_id", "")).strip_edges() != "":
		return true
	if str(actor_props.get("definition_path", "")).strip_edges() != "":
		return true
	return false
