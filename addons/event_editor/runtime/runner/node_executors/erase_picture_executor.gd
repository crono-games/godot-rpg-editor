class_name ErasePictureExecutor
extends RefCounted

const LAYER_NAME := "RuntimePicturesLayer"
const CONTAINER_NAME := "PicturesRoot"

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, _ctx: EventRuntimeContext, scene_root: Node) -> String:
	if scene_root == null:
		return graph.get_next(node_id, 0)

	var params: Dictionary = node.get("params", {})
	var picture_id := maxi(1, int(params.get("picture_id", 1)))

	var layer := scene_root.get_node_or_null(LAYER_NAME) as CanvasLayer
	if layer == null:
		return graph.get_next(node_id, 0)
	var root := layer.get_node_or_null(CONTAINER_NAME) as Node2D
	if root == null:
		return graph.get_next(node_id, 0)

	var sprite := root.get_node_or_null("Picture_%d" % picture_id) as Sprite2D
	if sprite != null:
		sprite.queue_free()

	return graph.get_next(node_id, 0)
