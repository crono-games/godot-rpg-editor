class_name ChangeScreenToneExecutor
extends RefCounted

const LAYER_NAME := "ScreenToneLayer"
const RECT_NAME := "ScreenToneRect"

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, _ctx: EventRuntimeContext, scene_root: Node) -> String:
	var params = node.get("params", {})
	var color_dict = params.get("color", {})
	var r := float(color_dict.get("r", 255.0)) / 255.0
	var g := float(color_dict.get("g", 255.0)) / 255.0
	var b := float(color_dict.get("b", 255.0)) / 255.0
	var a := float(color_dict.get("a", 0.0)) / 255.0
	var duration_frames := int(params.get("duration_frames", params.get("duration", 0)))
	var duration := float(duration_frames) / 60.0
	var target := Color(r, g, b, a)

	var rect := _get_or_create_rect(scene_root)
	if rect == null:
		return graph.get_next(node_id, 0)

	if duration <= 0.0:
		rect.color = target
		return graph.get_next(node_id, 0)
	
	var tween := rect.create_tween()
	tween.tween_property(rect, "color", target, duration)
	await tween.finished
	return graph.get_next(node_id, 0)

func _get_or_create_rect(scene_root: Node) -> ColorRect:
	if scene_root == null:
		return null
	var target_viewport := scene_root.get_viewport()
	if target_viewport == null:
		return null
	var layer := target_viewport.get_node_or_null(LAYER_NAME)
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = LAYER_NAME
		layer.layer = 100
		target_viewport.add_child(layer)
	var rect := layer.get_node_or_null(RECT_NAME)
	if rect == null:
		rect = ColorRect.new()
		rect.name = RECT_NAME
		rect.anchor_left = 0.0
		rect.anchor_top = 0.0
		rect.anchor_right = 1.0
		rect.anchor_bottom = 1.0
		rect.offset_left = 0.0
		rect.offset_top = 0.0
		rect.offset_right = 0.0
		rect.offset_bottom = 0.0
		rect.color = Color(0, 0, 0, 0)
		rect.size = target_viewport.size
		layer.add_child(rect)
	return rect
