class_name PlayBGMExecutor
extends RefCounted

const PLAYER_NAME := "EventBGMPlayer"

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

	var player := _get_or_create_audio_player(root)
	if player == null:
		return graph.get_next(node_id, 0)

	player.bus = "Master"
	player.volume_db = float(params.get("volume_db", 0.0))
	player.pitch_scale = maxf(0.01, float(params.get("pitch_scale", 1.0)))

	var stream_typed := stream as AudioStream
	_apply_loop(stream_typed, bool(params.get("loop", true)))
	player.stream = stream_typed
	player.play()
	return graph.get_next(node_id, 0)

func _resolve_root(scene_root: Node) -> Node:
	if scene_root != null and is_instance_valid(scene_root):
		return scene_root
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.current_scene

func _get_or_create_audio_player(root: Node) -> AudioStreamPlayer:
	var existing := root.get_node_or_null(PLAYER_NAME)
	if existing is AudioStreamPlayer:
		return existing as AudioStreamPlayer
	var player := AudioStreamPlayer.new()
	player.name = PLAYER_NAME
	root.add_child(player)
	return player

func _apply_loop(stream: AudioStream, enabled: bool) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if enabled else AudioStreamWAV.LOOP_DISABLED
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = enabled
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = enabled
