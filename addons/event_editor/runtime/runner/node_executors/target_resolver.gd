class_name TargetResolver
extends RefCounted

const TARGET_CURRENT := "__current__"
const TARGET_PLAYER := "__player__"

static func resolve_target(
	ctx: EventRuntimeContext,
	scene_root: Node,
	target_id: String,
	target_name: String = "",
	allow_current: bool = true
) -> Node:
	if ctx == null:
		return null

	var id := target_id.strip_edges()
	var name := target_name.strip_edges()
	var normalized_id := id.to_lower()
	var normalized_name := name.to_lower()

	if id == TARGET_PLAYER or normalized_name == "player" or normalized_name == TARGET_PLAYER:
		return _resolve_player(ctx, scene_root)

	if allow_current and (id == "" or id == TARGET_CURRENT):
		if ctx.current_event_id != "":
			var current_target := ctx.get_event_by_id(ctx.current_event_id)
			if current_target != null:
				return current_target

	if id != "":
		var by_id := ctx.get_event_by_id(id)
		if by_id != null:
			return by_id

	if name != "":
		var by_name := ctx.get_event_by_name(name)
		if by_name != null:
			return by_name

	var player := _resolve_player(ctx, scene_root)
	if player == null:
		return null
	if id != "" and str(player.get("id")) == id:
		return player
	if name != "" and player.name == name:
		return player
	return null

static func _resolve_player(ctx: EventRuntimeContext, scene_root: Node) -> Node:
	var env := ctx.get_scene_event_environment()
	if env != null:
		var env_player := env.get_player("PlayerInstance")
		if env_player != null and is_instance_valid(env_player):
			return env_player
	return _find_player(scene_root)

static func _find_player(root: Node) -> Node:
	if root == null or not is_instance_valid(root):
		return null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n.is_in_group("PlayerInstance") and (n is Node2D or n is Node3D):
			return n
		for c in n.get_children():
			if c is Node:
				stack.push_back(c)
	return null
