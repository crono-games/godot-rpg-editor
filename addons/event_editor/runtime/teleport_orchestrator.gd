class_name TeleportOrchestrator
extends RefCounted

var player_group: String = "player"
var player_scene_path: String = "res://events/player_instance.tscn"

var _pending_teleport := false
var _pending_pos := Vector3.ZERO
var _pending_scene_path := ""
var _pending_fade_in := false
var _pending_fade_frames := 0
var _pending_player_scene_path := ""
var _pending_facing_dir := "keep"

func configure(in_player_group: String, in_player_scene_path: String) -> void:
	player_group = in_player_group
	player_scene_path = in_player_scene_path

func begin_pending(scene_path: String, pos: Vector3, fade_in: bool, fade_frames: int, source_player_scene_path: String = "", facing_dir: String = "keep") -> void:
	_pending_teleport = true
	_pending_pos = pos
	_pending_scene_path = scene_path
	_pending_fade_in = fade_in
	_pending_fade_frames = fade_frames
	_pending_player_scene_path = source_player_scene_path.strip_edges()
	_pending_facing_dir = facing_dir.strip_edges().to_lower()

func has_pending() -> bool:
	return _pending_teleport

func should_clear_pending_for_scene(scene_root: Node) -> bool:
	if scene_root == null:
		return false
	if not _pending_teleport:
		return false
	if _pending_scene_path == "":
		return false
	var scene_path := str(scene_root.get("scene_file_path"))
	if scene_path != "":
		return scene_path != _pending_scene_path
	return false

func clear_pending() -> void:
	_pending_teleport = false
	_pending_pos = Vector3.ZERO
	_pending_scene_path = ""
	_pending_fade_in = false
	_pending_fade_frames = 0
	_pending_player_scene_path = ""
	_pending_facing_dir = "keep"

func apply_pending(scene_root: Node) -> void:
	if not _pending_teleport:
		return
	if not move_player_to(scene_root, _pending_pos):
		if ensure_player(scene_root):
			move_player_to(scene_root, _pending_pos)
		else:
			return
	_apply_facing_to_player(find_player_in_scene(scene_root), _pending_facing_dir)
	if _pending_fade_in and _pending_fade_frames > 0:
		await fade_in(scene_root, _pending_fade_frames)
	clear_pending()

func move_player_to(scene_root: Node, pos: Vector3) -> bool:
	var player := find_player_in_scene(scene_root)
	if player == null:
		return false
	if player is Node3D:
		(player as Node3D).position = pos
	elif player is Node2D:
		(player as Node2D).position = Vector2(pos.x, pos.y)
	else:
		return false
	return true

func ensure_player(scene_root: Node) -> bool:
	if scene_root == null:
		return false
	var resolved_scene_path := _resolve_player_scene_path()
	if resolved_scene_path == "":
		return false
	var packed := load(resolved_scene_path)
	if packed == null:
		return false
	var player = packed.instantiate()
	scene_root.add_child(player)
	return true

func get_player(scene_root: Node) -> Node:
	return find_player_in_scene(scene_root)

func find_player_in_scene(scene_root: Node) -> Node:
	if scene_root == null or not is_instance_valid(scene_root):
		return null
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node.is_in_group(player_group) and (node is Node2D or node is Node3D):
			return node
		for child in node.get_children():
			if child is Node:
				stack.push_back(child)
	return null

func is_node_in_scene(node: Node, scene_root: Node) -> bool:
	if node == null or scene_root == null:
		return false
	var cursor: Node = node
	while cursor != null:
		if cursor == scene_root:
			return true
		cursor = cursor.get_parent()
	return false

func fade_in(scene_root: Node, frames: int) -> void:
	var node := {
		"params": {
			"color": {"r": 0, "g": 0, "b": 0, "a": 0},
			"duration": frames
		}
	}
	var executor := ChangeScreenToneExecutor.new()
	await executor.run("", node, EventGraphRuntime.new({}, ""), EventRuntimeContext.new(), scene_root)

func _resolve_player_scene_path() -> String:
	if _pending_player_scene_path != "" and ResourceLoader.exists(_pending_player_scene_path):
		return _pending_player_scene_path
	if player_scene_path != "" and ResourceLoader.exists(player_scene_path):
		return player_scene_path
	var fallbacks := [
		"res://assets/templates/events/2d/player_instance_grid.tscn",
		"res://assets/templates/events/2d/player_instance_pixel.tscn",
		"res://assets/templates/events/3d/player_instance.tscn"
	]
	for p in fallbacks:
		if ResourceLoader.exists(p):
			return p
	return ""

func _apply_facing_to_player(player: Node, facing_dir: String) -> void:
	if player == null:
		return
	var dir := facing_dir.strip_edges().to_lower()
	if dir == "" or dir == "keep":
		return
	var v2 := Vector2.DOWN
	match dir:
		"up":
			v2 = Vector2.UP
		"left":
			v2 = Vector2.LEFT
		"right":
			v2 = Vector2.RIGHT
		_:
			v2 = Vector2.DOWN
	if player.has_method("set"):
		player.set("_last_dir", v2)
		player.set("last_dir", v2)
	if player.has_method("play_animation"):
		player.call("play_animation", "idle", v2)
