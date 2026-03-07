class_name PlaySEExecutor
extends RefCounted

const CONTAINER_NAME := "EventSEPlayers"

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, _ctx: EventRuntimeContext, scene_root: Node) -> String:
	var params = node.get("params", {})
	var stream_path := str(params.get("stream_path", ""))
	if stream_path == "":
		return graph.get_next(node_id, 0)

	var stream := load(stream_path)
	if not (stream is AudioStream):
		return graph.get_next(node_id, 0)

	var root := _resolve_root(scene_root)
	if root == null:
		return graph.get_next(node_id, 0)

	var container := _get_or_create_container(root)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = float(params.get("volume_db", 0.0))
	player.pitch_scale = maxf(0.01, float(params.get("pitch_scale", 1.0)))
	player.bus = "Master"
	container.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return graph.get_next(node_id, 0)

func _resolve_root(scene_root: Node) -> Node:
	if scene_root != null and is_instance_valid(scene_root):
		return scene_root
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.current_scene

func _get_or_create_container(root: Node) -> Node:
	var existing := root.get_node_or_null(CONTAINER_NAME)
	if existing != null:
		return existing
	var container := Node.new()
	container.name = CONTAINER_NAME
	root.add_child(container)
	return container
