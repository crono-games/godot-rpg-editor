class_name MapBoundsService
extends RefCounted


static func compute_world_bounds_from_tilemaps(root: Node) -> Rect2:
	var has_any := false
	var out := Rect2()

	for layer in root.find_children("*", "TileMapLayer", true, false):
		var rect := _compute_layer_world_bounds(layer)

		if rect.size == Vector2.ZERO:
			continue

		if not has_any:
			out = rect
			has_any = true
		else:
			out = out.merge(rect)

	return out if has_any else Rect2()


static func _compute_layer_world_bounds(layer: TileMapLayer) -> Rect2:

	if layer == null or layer.tile_set == null:
		return Rect2()

	var used := layer.get_used_cells()
	if used.is_empty():
		return Rect2()

	var tile_size := Vector2(layer.tile_set.tile_size)

	if tile_size == Vector2.ZERO:
		tile_size = Vector2(16,16)

	var has_any := false
	var out := Rect2()

	for c in used:

		var cell := c as Vector2i

		var local_pos := Vector2(cell) * tile_size
		var world_pos := layer.to_global(local_pos)

		var r := Rect2(world_pos, tile_size)

		if not has_any:
			out = r
			has_any = true
		else:
			out = out.merge(r)

	return out if has_any else Rect2()


static func resolve_bounds(
	auto_bounds: Rect2,
	manual_bounds: Rect2,
	manual_enabled: bool
) -> Rect2:

	if auto_bounds.size != Vector2.ZERO:
		return auto_bounds

	if manual_enabled and manual_bounds.size != Vector2.ZERO:
		return manual_bounds

	return Rect2()


static func clamp_position(pos: Vector2, bounds: Rect2) -> Vector2:
	if bounds.size == Vector2.ZERO:
		return pos

	return Vector2(
		clamp(pos.x, bounds.position.x, bounds.end.x),
		clamp(pos.y, bounds.position.y, bounds.end.y)
	)


static func contains_point(bounds: Rect2, pos: Vector2) -> bool:
	if bounds.size == Vector2.ZERO:
		return true

	return bounds.has_point(pos)
