class_name SetFollowersExecutor
extends RefCounted

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, ctx: EventRuntimeContext, scene_root: Node) -> String:
	if scene_root == null:
		return graph.get_next(node_id, 0)

	var params: Dictionary = node.get("params", {})
	var action := str(params.get("action", "add")).to_lower()
	var actor_id := str(params.get("actor_id", params.get("target_id", ""))).strip_edges()
	var actor_name := str(params.get("actor_name", params.get("target_name", params.get("target", "")))).strip_edges()
	var make_persistent := bool(params.get("make_persistent", false))

	var controller := _resolve_controller(scene_root)
	if controller == null:
		return graph.get_next(node_id, 0)

	match action:
		"add":
			var actor := _resolve_actor(ctx, scene_root, actor_id, actor_name)
			if actor == null:
				return graph.get_next(node_id, 0)
			if not actor.has_method("follow_to_world"):
				return graph.get_next(node_id, 0)
			if controller.has_method("add_follower_actor"):
				# Slot assignment is always dynamic (append).
				controller.call("add_follower_actor", actor, -1)
			if make_persistent:
				controller.set_meta("followers_persistent", true)
		"remove":
			if actor_id != "" and controller.has_method("remove_follower_actor_by_event_id"):
				controller.call("remove_follower_actor_by_event_id", actor_id)
			else:
				var actor := _resolve_actor(ctx, scene_root, actor_id, actor_name)
				if actor != null and controller.has_method("remove_follower_actor"):
					controller.call("remove_follower_actor", actor)
		"clear":
			if controller.has_method("clear_followers"):
				controller.call("clear_followers")
		_:
			printerr("SetFollowersExecutor: unsupported action -> ", action)

	return graph.get_next(node_id, 0)

func _resolve_controller(scene_root: Node) -> Node:
	if scene_root == null:
		return null
	var tree := scene_root.get_tree()
	if tree == null:
		return null
	var controllers := tree.get_nodes_in_group("follower_controller")
	for c in controllers:
		if c != null and is_instance_valid(c):
			return c
	return null

func _resolve_actor(ctx: EventRuntimeContext, scene_root: Node, actor_id: String, actor_name: String) -> Node:
	var actor := TargetResolver.resolve_target(ctx, scene_root, actor_id, actor_name, false)
	if actor != null:
		return actor
	return _scan_actor(scene_root, actor_id, actor_name)

func _scan_actor(scene_root: Node, actor_id: String, actor_name: String) -> Node:
	if scene_root == null or not is_instance_valid(scene_root):
		return null
	var id := actor_id.strip_edges()
	var name := actor_name.strip_edges()
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node.is_in_group("event_instance"):
			var node_id := ""
			if node.has_method("get"):
				node_id = str(node.get("id"))
			if id != "" and (node_id == id or node.name == id):
				return node
			if name != "" and (node.name == name or node_id == name):
				return node
		for child in node.get_children():
			if child is Node:
				stack.push_back(child)
	return null
