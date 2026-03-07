class_name MovePictureExecutor
extends RefCounted

const LAYER_NAME := "RuntimePicturesLayer"
const CONTAINER_NAME := "PicturesRoot"

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, _ctx: EventRuntimeContext, scene_root: Node) -> String:
	if scene_root == null:
		return graph.get_next(node_id, 0)

	var params: Dictionary = node.get("params", {})
	var picture_id := maxi(1, int(params.get("picture_id", 1)))
	var target_position := _parse_position(params.get("target_position", {"x": 0, "y": 0}))
	var duration_frames := maxi(0, int(params.get("duration_frames", params.get("duration", 0))))
	var wait_for_completion := bool(params.get("wait_for_completion", true))

	var sprite := _find_picture_sprite(scene_root, picture_id)
	if sprite == null:
		return graph.get_next(node_id, 0)

	if duration_frames <= 0:
		sprite.position = target_position
		return graph.get_next(node_id, 0)

	var tween := sprite.create_tween()
	tween.tween_property(sprite, "position", target_position, float(duration_frames) / 60.0)
	if wait_for_completion:
		await tween.finished
	return graph.get_next(node_id, 0)

func _find_picture_sprite(scene_root: Node, picture_id: int) -> Sprite2D:
	var layer := scene_root.get_node_or_null(LAYER_NAME) as CanvasLayer
	if layer == null:
		return null
	var root := layer.get_node_or_null(CONTAINER_NAME) as Node2D
	if root == null:
		return null
	return root.get_node_or_null("Picture_%d" % picture_id) as Sprite2D

func _parse_position(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
