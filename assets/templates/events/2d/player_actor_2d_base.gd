@tool
extends Node2D
class_name PlayerActor2DBase

signal player_ready(player: Node)
signal move_finished(player: Node)
signal event_bumped(event_id: String, event_node: Node)

@export_storage var id: String = ""


@export var movement_mode: String = "Grid"
@export var trigger_resolution_mode: String = "Grid"

@export var move_speed: float = 96.0
@export var collide_with_events := true

@export var editor_preview_enabled := false

@export var camera: Camera2D
@export var animation_player: AnimationPlayer
@export var sprite: Sprite2D
@export var area: Area2D

const BUMP_EMIT_COOLDOWN_MS := 150

var _anim_step_time := 0.11
var _max_anim_cycles_per_step := 1.0

var _last_bump_event_id := ""
var _last_bump_ms := 0
var _moving := false
var _last_dir := Vector2.DOWN
var _sprite_base_local := Vector2.ZERO

var debug_noclip_action := "debug_noclip_toggle"
var debug_noclip := false

var state := 0

func _common_ready(mode: String, snap_grid_on_ready: bool) -> void:
	_resolve_runtime_actor_links()
	add_to_group("player")
	movement_mode = mode
	trigger_resolution_mode = mode
	if camera != null:
		camera.enabled = true
		_fit_camera_limits()
	if sprite != null and is_instance_valid(sprite):
		_sprite_base_local = sprite.position
	if id == "":
		push_warning("%s without id (editor/repository should assign one)" % [name])
	if snap_grid_on_ready:
		snap_to_grid()
	player_ready.emit(self)

func _resolve_runtime_actor_links() -> void:
	if animation_player == null or not is_instance_valid(animation_player):
		var ap := get_node_or_null("AnimationPlayer")
		if ap is AnimationPlayer:
			animation_player = ap as AnimationPlayer
	if sprite == null or not is_instance_valid(sprite):
		var sp := get_node_or_null("Sprite2D")
		if sp is Sprite2D:
			sprite = sp as Sprite2D
	if camera == null or not is_instance_valid(camera):
		var cam := get_node_or_null("Camera2D")
		if cam is Camera2D:
			camera = cam as Camera2D
	if area == null or not is_instance_valid(area):
		var ta := get_node_or_null("TriggerArea")
		if ta is Area2D:
			area = ta as Area2D

func _unhandled_input(event: InputEvent) -> void:
	if debug_noclip_action == "":
		return
	if event.is_action_pressed(debug_noclip_action):
		debug_noclip = not debug_noclip

func is_moving() -> bool:
	return _moving

func get_trigger_resolution_mode() -> String:
	return trigger_resolution_mode

func get_facing_direction() -> Vector2:
	return Vector2(_last_dir.x, _last_dir.y)

func get_trigger_area() -> Variant:
	if area != null and is_instance_valid(area):
		return area
	return null

func snap_to_grid() -> void:
	pass

func blocks_player_movement() -> bool:
	return false

func _get_input_direction() -> Vector2:
	var x := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var y := Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	return Vector2(x, y)

func _get_blocking_event(next_global_pos: Vector2, radius: float) -> Node:
	if not collide_with_events:
		return null
	for node in get_tree().get_nodes_in_group("EventInstance"):
		if node == self:
			continue
		if not (node is Node2D):
			continue
		if node.has_method("blocks_player_movement") and not bool(node.call("blocks_player_movement")):
			continue
		var node_pos := (node as Node2D).global_position
		if node_pos.distance_to(next_global_pos) <= radius:
			return node
	return null

func _emit_bump_event(blocked_event: Node) -> void:
	if blocked_event == null or blocked_event == area:
		return
	var event_id := str(blocked_event.get("id"))
	if event_id == "":
		return
	var now := Time.get_ticks_msec()
	if event_id == _last_bump_event_id and (now - _last_bump_ms) < BUMP_EMIT_COOLDOWN_MS:
		return
	_last_bump_event_id = event_id
	_last_bump_ms = now
	event_bumped.emit(event_id, blocked_event)

func _is_dialog_input_locked() -> bool:
	if get_tree() == null:
		return false
	for node in get_tree().get_nodes_in_group("dialogue_runner"):
		if node == null or not is_instance_valid(node):
			continue
		var state = int(node.get("state"))
		if state != int(DialogueRunner.State.IDLE):
			return true
	return false

func _fit_camera_limits() -> void:
	if camera == null:
		return
	var map_root := _resolve_map_root()
	if map_root != null and map_root.has_method("apply_camera_limits_to"):
		if bool(map_root.call("apply_camera_limits_to", camera)):
			return

func _resolve_map_root() -> Node:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null
	for node in get_tree().get_nodes_in_group("Map2D"):
		if not (node is Node):
			continue
		if (node as Node).get_tree() != get_tree():
			continue
		return node as Node
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n.has_method("get"):
			var map_id := str(n.get("map_id")).strip_edges()
			if map_id != "" and map_id != "Null":
				return n
		for c in n.get_children():
			if c is Node:
				stack.push_back(c)
	return null

func update_animation(direction) -> void:
	if not _can_play_animation():
		return
	var dir = direction if direction is Vector2 else Vector2.ZERO
	if dir != Vector2.ZERO:
		play_animation("move", dir)
	else:
		play_animation("idle", dir)


func play_animation(base: String, vec: Vector2) -> void:
	if not _can_play_animation():
		return
	var dir := _main_dir(vec)
	if dir == Vector2.ZERO:
		dir = _last_dir
	else:
		_last_dir = dir
	var anim_name := base + "_" + _dir_to_string(dir)
	if str(animation_player.current_animation) != anim_name:
		animation_player.play(anim_name)

func _main_dir(vec: Vector2) -> Vector2:
	if vec.length_squared() <= 0.000001:
		return Vector2.ZERO
	var ax := absf(vec.x)
	var ay := absf(vec.y)
	var diff := absf(ax - ay)
	if diff <= 0.05:
		if _last_dir == Vector2.LEFT or _last_dir == Vector2.RIGHT:
			return Vector2.RIGHT if vec.x > 0 else Vector2.LEFT
		if _last_dir == Vector2.UP or _last_dir == Vector2.DOWN:
			return Vector2.DOWN if vec.y > 0 else Vector2.UP
	if ax > ay:
		return Vector2.RIGHT if vec.x > 0 else Vector2.LEFT
	return Vector2.DOWN if vec.y > 0 else Vector2.UP

func _dir_to_string(dir: Vector2) -> String:
	match dir:
		Vector2.DOWN: return "down"
		Vector2.UP: return "up"
		Vector2.LEFT: return "left"
		Vector2.RIGHT: return "right"
		_: return "down"

func _can_play_animation() -> bool:
	if animation_player == null:
		return false
	if Engine.is_editor_hint() and not editor_preview_enabled:
		return false
	return true
