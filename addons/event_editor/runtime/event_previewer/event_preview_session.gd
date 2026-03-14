class_name EventPreviewSession
extends RefCounted

signal selection_changed(event_id: String)
signal preview_ready(scene_root: Node)

const DEBUG_PREVIEW := false

var preview_scene: Node
var event_instances: Array = []
var selected_event_id: String = ""
var selected_event_node: Node = null
var original_event_states: Array[Dictionary] = []
var _original_states_by_id: Dictionary = {}

func clear() -> void:
	if not Engine.is_editor_hint():
		return
	_set_preview_mode_for_events(false)
	if preview_scene and is_instance_valid(preview_scene):
		if preview_scene.get_parent() != null:
			preview_scene.get_parent().remove_child(preview_scene)
		if preview_scene.is_inside_tree():
			preview_scene.queue_free()
	preview_scene = null
	event_instances.clear()
	original_event_states.clear()
	_original_states_by_id.clear()
	selected_event_id = ""
	selected_event_node = null

func build_from_scene_root(scene_root: Node, preferred_event_id: String = "") -> void:
	preview_scene = scene_root
	_collect_event_instances(preview_scene)
	var ids := []
	for ev in event_instances:
		ids.append(_get_node_id(ev))

	if preferred_event_id != "":
		selected_event_id = preferred_event_id

	_select_best_event()
	_set_preview_mode_for_events(true)
	_save_original_states()
	_ensure_active_camera()

	emit_signal("preview_ready", preview_scene)

func add_to_viewport(viewport: SubViewport) -> void:
	if preview_scene != null and viewport != null:
		viewport.add_child(preview_scene)

func get_event_list() -> Array:
	return event_instances

func get_event_by_id(event_id: String) -> Node:
	return _get_event_instance_by_id(event_id)

func select_event_by_id(event_id: String) -> void:
	if event_id == "":
		return
	var target := _get_event_instance_by_id(event_id)
	if target == null:
		return
	selected_event_id = _get_node_id(target)
	selected_event_node = target
	emit_signal("selection_changed", selected_event_id)

func set_event_camera(event_id: String) -> void:
	if preview_scene == null or not preview_scene.is_inside_tree():
		return
	var target_camera: Node = null
	for event in event_instances:
		var camera := _resolve_event_camera(event)
		if camera != null:
			_set_camera_active(camera, false)
			if _get_node_id(event) == event_id:
				target_camera = camera
	if target_camera != null:
		_set_camera_active(target_camera, true)
	else:
		_ensure_active_camera()

func restore_original_states() -> void:
	if preview_scene == null:
		return
	for ev in event_instances:
		var state = _original_states_by_id.get(_get_node_id(ev), null)
		if state == null:
			continue
		if ev is Node3D:
			(ev as Node3D).position = state.position
			(ev as Node3D).rotation = state.rotation
		elif ev is Node2D:
			(ev as Node2D).position = state.position_2d
			(ev as Node2D).rotation = state.rotation_2d
		var sprite = _get_sprite_node(ev)
		if sprite != null and sprite.has_method("set_frame"):
			sprite.set("frame", state.sprite_frame)
	_reset_runtime_effects()

# ==================================================
# Internals
# ==================================================

func _collect_event_instances(node: Node) -> void:
	if _is_event_node(node):
		event_instances.append(node)
	for child in node.get_children():
		_collect_event_instances(child)

func _select_best_event() -> void:
	var target := _get_event_instance_by_id(selected_event_id)
	if target == null and event_instances.size() > 0:
		target = event_instances[0]
	if target != null:
		selected_event_node = target
		selected_event_id = _get_node_id(target)

func _get_event_instance_by_id(event_id: String) -> Node:
	if event_id == "":
		return null
	for ev in event_instances:
		if _get_node_id(ev) == event_id:
			return ev
	return null

func _save_original_states() -> void:
	original_event_states.clear()
	_original_states_by_id.clear()
	for event in event_instances:
		var state: Dictionary = {
			"position": (event as Node3D).position if event is Node3D else Vector3.ZERO,
			"rotation": (event as Node3D).rotation if event is Node3D else Vector3.ZERO,
			"position_2d": (event as Node2D).position if event is Node2D else Vector2.ZERO,
			"rotation_2d": (event as Node2D).rotation if event is Node2D else 0.0,
			"sprite_frame": _get_sprite_frame(event)
		}
		original_event_states.append(state)
		_original_states_by_id[_get_node_id(event)] = state

func _set_preview_mode_for_events(enabled: bool) -> void:
	for event in event_instances:
		if event != null and event.has_method("set_preview_mode"):
			event.call("set_preview_mode", enabled)

func _ensure_active_camera() -> void:
	if preview_scene == null or not preview_scene.is_inside_tree():
		return
	var cameras: Array[Node] = []
	_collect_cameras(preview_scene, cameras)
	# Always normalize camera state so duplicated event cameras do not steal preview focus.
	for cam in cameras:
		_set_camera_active(cam, false)

	# Prefer selected event camera when available.
	if selected_event_node != null:
		var selected_cam := _resolve_event_camera(selected_event_node)
		if selected_cam != null:
			_set_camera_active(selected_cam, true)
			return

	# If selected event has no camera, force a fallback camera focused on it.
	if selected_event_node != null:
		#_create_fallback_camera()
		return

	if cameras.size() > 0:
		_set_camera_active(cameras[0], true)
		return

	#_create_fallback_camera()

func _collect_cameras(node: Node, out: Array) -> void:
	if node is Camera2D or node is Camera3D:
		out.append(node)
	for child in node.get_children():
		_collect_cameras(child, out)

func _resolve_event_camera(event: Node) -> Node:
	if event == null:
		return null
	var event_camera = event.get("camera")
	if event_camera is Camera2D or event_camera is Camera3D:
		var cam := event_camera as Node
		if is_instance_valid(cam):
			return cam
	for child in event.get_children():
		var cam := _find_camera_in_branch(child)
		if cam != null:
			return cam
	return null

func _find_camera_in_branch(node: Node) -> Node:
	if node is Camera2D or node is Camera3D:
		return node
	for child in node.get_children():
		var cam := _find_camera_in_branch(child)
		if cam != null:
			return cam
	return null

func _set_camera_active(camera: Node, active: bool) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	# Godot 4 Camera2D/3D use `enabled`; keep `current` fallback for compatibility.
	if camera.has_method("set_enabled"):
		camera.call("set_enabled", active)
	elif camera.has_method("set_current"):
		camera.call("set_current", active)
	else:
		for prop in camera.get_property_list():
			var prop_name := str(prop.get("name", ""))
			if prop_name == "enabled":
				camera.set("enabled", active)
				return
			if prop_name == "current":
				camera.set("current", active)
				return

func _reset_runtime_effects() -> void:
	if preview_scene == null or not preview_scene.is_inside_tree():
		return
	_stop_event_motion_loops()
	# Screen tone overlay (created by ChangeScreenToneExecutor in the target viewport)
	var viewport := preview_scene.get_viewport()
	if viewport != null:
		var tone_layer := viewport.get_node_or_null("ScreenToneLayer")
		if tone_layer != null:
			tone_layer.queue_free()

	# BGM player (created by PlayBGMExecutor under scene root)
	var bgm := preview_scene.get_node_or_null("EventBGMPlayer")
	if bgm != null:
		if bgm.has_method("stop"):
			bgm.stop()
		bgm.queue_free()

	# SE container + transient players (created by PlaySEExecutor under scene root)
	var se_container := preview_scene.get_node_or_null("EventSEPlayers")
	if se_container != null:
		for child in se_container.get_children():
			if child != null and child.has_method("stop"):
				child.stop()
		se_container.queue_free()

	# Camera shake reset (used by ScreenShakeExecutor metadata)
	if preview_scene is Node2D:
		var cameras: Array[Node] = []
		_collect_cameras(preview_scene, cameras)
		for cam in cameras:
			if not (cam is Camera2D):
				continue
			var cam2d := cam as Camera2D
			if cam.has_meta("_screen_shake_tween"):
				var tw = cam.get_meta("_screen_shake_tween")
				if tw is Tween and is_instance_valid(tw):
					(tw as Tween).kill()
				cam.remove_meta("_screen_shake_tween")
			if cam.has_meta("_screen_shake_origin"):
				cam2d.position = cam.get_meta("_screen_shake_origin")
				cam.remove_meta("_screen_shake_origin")

func _stop_event_motion_loops() -> void:
	for ev in event_instances:
		if ev == null or not is_instance_valid(ev):
			continue
		if ev.has_meta("_move_along_path_tween"):
			var tw = ev.get_meta("_move_along_path_tween")
			if tw is Tween and is_instance_valid(tw):
				(tw as Tween).kill()
			ev.remove_meta("_move_along_path_tween")
		if ev.has_method("update_animation"):
			if ev is Node3D:
				ev.call("update_animation", Vector3.ZERO)
			else:
				ev.call("update_animation", Vector2.ZERO)

func _is_event_node(node: Node) -> bool:
	if node.is_in_group("event_instance"):
		return true
	if node is EventInstance2D:
		return true
	for prop in node.get_property_list():
		if str(prop.get("name", "")) == "id":
			return true
	return false

func _get_node_id(node: Node) -> String:
	if node == null:
		return ""
	var id_value = node.get("id")
	return str(id_value).strip_edges()

func _get_sprite_node(node: Node) -> Node:
	if node == null:
		return null
	var sprite = node.get("sprite")
	if sprite is Node and is_instance_valid(sprite):
		return sprite
	return null

func _get_sprite_frame(node: Node) -> int:
	var sprite := _get_sprite_node(node)
	if sprite == null:
		return 0
	if sprite.has_method("get_frame"):
		return int(sprite.call("get_frame"))
	var value = sprite.get("frame")
	if value is int:
		return value
	return 0
