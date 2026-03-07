class_name ShowPictureExecutor
extends RefCounted

const LAYER_NAME := "RuntimePicturesLayer"
const CONTAINER_NAME := "PicturesRoot"

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, _ctx: EventRuntimeContext, scene_root: Node) -> String:
	if scene_root == null:
		return graph.get_next(node_id, 0)

	var params: Dictionary = node.get("params", {})
	var picture_id := maxi(1, int(params.get("picture_id", 1)))
	var texture_path := str(params.get("texture_path", params.get("texture", ""))).strip_edges()
	if texture_path == "":
		return graph.get_next(node_id, 0)

	var texture: Texture2D = load(texture_path)
	if texture == null:
		return graph.get_next(node_id, 0)

	var pos := _parse_position(params.get("screen_position", {"x": 0, "y": 0}))
	var centered := bool(params.get("centered", false))
	var z_index := int(params.get("z_index", picture_id))

	var sprite := _find_or_create_picture_sprite(scene_root, picture_id)
	if sprite == null:
		return graph.get_next(node_id, 0)

	sprite.texture = texture
	sprite.position = pos
	sprite.centered = centered
	sprite.z_index = z_index
	sprite.visible = true

	return graph.get_next(node_id, 0)

func _find_or_create_picture_sprite(scene_root: Node, picture_id: int) -> Sprite2D:
	var layer := scene_root.get_node_or_null(LAYER_NAME) as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = LAYER_NAME
		layer.layer = 90
		scene_root.add_child(layer)

	var root := layer.get_node_or_null(CONTAINER_NAME) as Node2D
	if root == null:
		root = Node2D.new()
		root.name = CONTAINER_NAME
		layer.add_child(root)

	var node_name := "Picture_%d" % picture_id
	var sprite := root.get_node_or_null(node_name) as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = node_name
		root.add_child(sprite)
	return sprite

func _parse_position(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
