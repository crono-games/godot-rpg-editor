class_name PickerPreviewSync
extends RefCounted

static func sync_grid_to_viewport(
	grid_selector: GridSelector,
	sub_viewport: SubViewport,
	map_size: Vector2,
	pixels_per_cell: float,
	selected_cell: Vector2i = Vector2i(-1, -1)
) -> void:
	if grid_selector == null:
		return
	var cell := int(maxf(1.0, pixels_per_cell))
	grid_selector.cell_size = cell
	grid_selector.setup(map_size)
	if sub_viewport != null:
		var preview_size := Vector2(sub_viewport.size)
		grid_selector.custom_minimum_size = preview_size
		grid_selector.size = preview_size
		grid_selector.position = Vector2.ZERO
	if selected_cell.x >= 0 and selected_cell.y >= 0:
		grid_selector.set_selected_cell(selected_cell)
