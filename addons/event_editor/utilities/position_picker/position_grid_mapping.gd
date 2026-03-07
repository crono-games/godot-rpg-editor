class_name PositionGridMapping
extends RefCounted

static func cell_to_world_2d(cell: Vector2i, origin: Vector2, pixels_per_cell: float) -> Vector2:
	var ppc := maxf(1.0, pixels_per_cell)
	return Vector2(
		origin.x + (float(cell.x) + 0.5) * ppc,
		origin.y + (float(cell.y) + 0.5) * ppc
	)

static func world_to_cell_2d(world_pos: Vector2, origin: Vector2, pixels_per_cell: float) -> Vector2i:
	var ppc := maxf(1.0, pixels_per_cell)
	var cell_x := int(floor((world_pos.x - origin.x) / ppc))
	var cell_y := int(floor((world_pos.y - origin.y) / ppc))
	return Vector2i(cell_x, cell_y)
