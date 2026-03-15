@tool
extends Node2D
class_name PlayerActor2DBase

signal move_finished(player: Node)
signal event_bumped(event_id: String, event_node: Node)

@export_storage var id: String = ""

@export var move_speed: float = 64.0
@export var collide_with_events := true
@export var anim_cycles_per_tile := 0.5

@export var editor_preview_enabled := false

@export var camera: Camera2D
@export var animation_player: AnimationPlayer
@export var sprite: Sprite2D
@export var area: Area2D

const BUMP_EMIT_COOLDOWN_MS := 150

var _moving := false
var _last_dir := Vector2.DOWN
var _sprite_base_local := Vector2.ZERO

var _last_bump_event_id := ""
var _last_bump_ms := 0

var debug_noclip_action := "debug_noclip_toggle"
var debug_noclip := false

var state := 0
var current_map : Node2D

func _common_ready(mode: String, snap_grid_on_ready: bool) -> void:
	_resolve_runtime_actor_links()
	if not Engine.is_editor_hint():
		if camera:
			camera.enabled = true
			_fit_camera_limits()
	if sprite:
		_sprite_base_local = sprite.position
	if id == "":
		push_warning("%s without id (editor/repository should assign one)" % [name])
	if snap_grid_on_ready:
		snap_to_grid()

func _resolve_runtime_actor_links() -> void:
	if animation_player == null:
		var ap := get_node_or_null("AnimationPlayer")
		if ap is AnimationPlayer:
			animation_player = ap

	if sprite == null:
		var sp := get_node_or_null("Sprite2D")
		if sp is Sprite2D:
			sprite = sp

	if camera == null:
		var cam := get_node_or_null("Camera2D")
		if cam is Camera2D:
			camera = cam

	if area == null:
		var ta := get_node_or_null("TriggerArea")
		if ta is Area2D:
			area = ta


func _unhandled_input(event: InputEvent) -> void:
	if debug_noclip_action == "":
		return

	if event.is_action_pressed(debug_noclip_action):
		debug_noclip = not debug_noclip


func _get_input_direction() -> Vector2:

	var x := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var y := Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

	var v := Vector2(x, y)

	if v == Vector2.ZERO:
		return v

	if absf(v.x) > absf(v.y):
		return Vector2.RIGHT if v.x > 0 else Vector2.LEFT

	return Vector2.DOWN if v.y > 0 else Vector2.UP

func is_moving() -> bool:
	return _moving

func snap_to_grid() -> void:
	pass

func blocks_player_movement() -> bool:
	return false

func update_animation(direction: Vector2) -> void:

	if direction != Vector2.ZERO:
		play_animation("move", direction)
	else:
		play_animation("idle", _last_dir)


func play_animation(base: String, vec: Vector2) -> void:
	if not _can_play_animation():
		return
	if sprite == null or not is_instance_valid(sprite) or sprite.texture == null:
		return

	var dir := _main_dir(vec)
	if dir == Vector2.ZERO:
		dir = _last_dir
	else:
		_last_dir = dir

	var anim_name := base + "_" + _dir_to_string(dir)

	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)

func _can_play_animation() -> bool:

	if animation_player == null:
		return false

	if Engine.is_editor_hint() and not editor_preview_enabled:
		return false

	return true

func sync_animation_to_move(progress: float) -> void:

	if animation_player == null:
		return

	var anim_name := animation_player.current_animation
	if anim_name == "":
		return

	var anim := animation_player.get_animation(anim_name)
	if anim == null:
		return

	var anim_len := anim.length

	var t = progress * anim_cycles_per_tile
	t = fmod(t, 1.0)

	animation_player.seek(t * anim_len, true)


func _reset_anim_speed() -> void:

	if animation_player:
		animation_player.speed_scale = 1.0


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

		if not is_instance_valid(node):
			continue
		var state = int(node.get("state"))

		if state != int(DialogueRunner.State.IDLE):
			return true

	return false

## MapRoot applies camera limits from Tilemaps Bounding Boxes.

func _fit_camera_limits() -> void:
	if camera == null:
		return

	current_map = _resolve_map_root()
	current_map.apply_camera_limits(camera)

func _resolve_map_root() -> Node:
	var scene_root := get_tree().current_scene

	if scene_root == null:
		return null

	for node in get_tree().get_nodes_in_group("Map2D"):
		if node.get_tree() == get_tree():
			return node

	return null


## Helpers used by EventTriggerService probably i'll move them in the future.

func get_facing_direction() -> Vector2:
	return _last_dir

func get_trigger_area() -> Variant:
	if area and is_instance_valid(area):
		return area
	return null

## Helpers for Animation resolve.

func _main_dir(vec: Vector2) -> Vector2:
	if vec.length_squared() < 0.01:
		return Vector2.ZERO
	if absf(vec.x) > absf(vec.y):
		return Vector2.RIGHT if vec.x > 0 else Vector2.LEFT
	return Vector2.DOWN if vec.y > 0 else Vector2.UP


func _dir_to_string(dir: Vector2) -> String:
	match dir:
		Vector2.DOWN: return "down"
		Vector2.UP: return "up"
		Vector2.LEFT: return "left"
		Vector2.RIGHT: return "right"
	return "down"
