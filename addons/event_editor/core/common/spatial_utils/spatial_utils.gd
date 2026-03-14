class_name SpatialUtils
extends RefCounted

static func get_position3(node: Node) -> Vector3:

	if node is Node3D:
		return node.position

	if node is Node2D:
		var p = node.position
		return Vector3(p.x, 0.0, p.y)

	return Vector3.ZERO


static func set_position(node: Node, pos3: Vector3):

	if node is Node3D:
		node.position = pos3
		return

	if node is Node2D:
		node.position = Vector2(pos3.x, pos3.z)


static func vector3_to_anim_dir(node: Node, dir3: Vector3):

	if node is Node2D:
		return Vector2(dir3.x, dir3.z)

	return dir3
