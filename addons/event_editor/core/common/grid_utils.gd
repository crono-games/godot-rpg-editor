class_name GridUtils
extends RefCounted

static func world_to_cell(pos: Vector3, cell_size: float = 1.0, centered: bool = true) -> Vector2i:
	var s := maxf(0.001, cell_size)
	if centered:
		return Vector2i(
			int(floor(pos.x / s)),
			int(floor(pos.z / s))
		)
	return Vector2i(
		int(round(pos.x / s)),
		int(round(pos.z / s))
	)

static func cell_to_world(cell: Vector2i, y: float = 0.0, cell_size: float = 1.0, centered: bool = true) -> Vector3:
	var s := maxf(0.001, cell_size)
	if centered:
		return Vector3(
			(float(cell.x) + 0.5) * s,
			y,
			(float(cell.y) + 0.5) * s
		)
	return Vector3(
		float(cell.x) * s,
		y,
		float(cell.y) * s
	)

static func snap_world_to_grid(pos: Vector3, cell_size: float = 1.0, centered: bool = true) -> Vector3:
	var cell := world_to_cell(pos, cell_size, centered)
	return cell_to_world(cell, pos.y, cell_size, centered)

static func is_same_cell(a: Vector3, b: Vector3, cell_size: float = 1.0, centered: bool = true) -> bool:
	return world_to_cell(a, cell_size, centered) == world_to_cell(b, cell_size, centered)
