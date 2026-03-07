class_name PositionModeResolver
extends RefCounted

static func resolve_runtime_position(_target: Node, pos: Vector3, _position_mode: String = "tile") -> Vector3:
	# World-space only policy:
	# runtime uses the stored position as-is and never converts tile->world.
	return pos
