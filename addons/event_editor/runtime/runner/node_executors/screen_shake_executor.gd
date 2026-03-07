class_name ScreenShakeExecutor
extends RefCounted

const META_TWEEN := "_screen_shake_tween"
const META_ORIGIN := "_screen_shake_origin"

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, _ctx: EventRuntimeContext, scene_root: Node) -> String:
	var params = node.get("params", {})
	var frames := int(params.get("duration_frames", 0))
	var strength_x := float(params.get("strength_x", 0.0))
	var strength_y := float(params.get("strength_y", 0.0))
	var wait_for_completion := bool(params.get("wait_for_completion", false))
	if frames <= 0 or (strength_x <= 0.0 and strength_y <= 0.0):
		return graph.get_next(node_id, 0)

	var cam := _find_active_camera(scene_root)
	if cam == null:
		return graph.get_next(node_id, 0)

	_stop_shake_if_running(cam)
	cam.set_meta(META_ORIGIN, cam.position)
	var original_pos: Vector3 = cam.position
	var frame_time := 1.0 / 60.0
	var tween := cam.create_tween()
	for _i in range(frames):
		var offset_x := randf_range(-strength_x, strength_x)
		var offset_y := randf_range(-strength_y, strength_y)
		tween.tween_property(cam, "position", original_pos + Vector3(offset_x, offset_y, 0.0), frame_time)
	tween.tween_property(cam, "position", original_pos, frame_time)
	tween.finished.connect(func():
		if is_instance_valid(cam):
			if cam.has_meta(META_ORIGIN):
				cam.position = cam.get_meta(META_ORIGIN)
				cam.remove_meta(META_ORIGIN)
			if cam.has_meta(META_TWEEN):
				cam.remove_meta(META_TWEEN)
	)
	cam.set_meta(META_TWEEN, tween)
	if wait_for_completion:
		await tween.finished
	return graph.get_next(node_id, 0)

func _find_active_camera(scene_root: Node) -> Camera3D:
	if scene_root == null:
		return null
	var viewport := scene_root.get_viewport()
	if viewport == null:
		return null
	var active := viewport.get_camera_3d()
	if active != null:
		return active
	return _find_any_camera(scene_root)

func _find_any_camera(node: Node) -> Camera3D:
	if node is Camera3D:
		return node as Camera3D
	for child in node.get_children():
		var found := _find_any_camera(child)
		if found != null:
			return found
	return null

func _stop_shake_if_running(cam: Camera3D) -> void:
	if cam == null:
		return
	if cam.has_meta(META_TWEEN):
		var tween = cam.get_meta(META_TWEEN)
		if tween is Tween and is_instance_valid(tween):
			(tween as Tween).kill()
		cam.remove_meta(META_TWEEN)
	if cam.has_meta(META_ORIGIN):
		cam.position = cam.get_meta(META_ORIGIN)
		cam.remove_meta(META_ORIGIN)
