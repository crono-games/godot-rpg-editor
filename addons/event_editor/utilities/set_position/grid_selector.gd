@tool
extends Control
class_name GridSelector

signal position_chosen(coords: Vector2i)
signal view_changed(zoom: float, offset: Vector2)

@export var cell_size: int = 8

var selected_cell: Vector2i = Vector2i(-1, -1)

var map_size = Vector2(20, 20)

func setup(_map_size):
	mouse_filter = MOUSE_FILTER_STOP
	map_size = _map_size
	custom_minimum_size = map_size * cell_size
	size = custom_minimum_size
	position = Vector2.ZERO
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
			var local_pos = get_local_mouse_position()
			var cell_pos = _screen_to_grid(local_pos)
			var cell_x = int(cell_pos.x)
			var cell_y = int(cell_pos.y)
			if cell_x < 0 or cell_x >= map_size.x:
				return
			if cell_y < 0 or cell_y >= map_size.y:
				return
			selected_cell = Vector2i(cell_x, cell_y)
			queue_redraw()
			position_chosen.emit(Vector2i(cell_x, cell_y))
			return

		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var local_pos = get_local_mouse_position()
			var cell_pos = _screen_to_grid(local_pos)
			var cell_x = int(cell_pos.x)
			var cell_y = int(cell_pos.y)
			if cell_x < 0 or cell_x >= map_size.x:
				return
			if cell_y < 0 or cell_y >= map_size.y:
				return
			selected_cell = Vector2i(cell_x, cell_y)
			queue_redraw()
			return

func _draw():
	var width = map_size.x * cell_size
	var height = map_size.y * cell_size

	for i in range(map_size.x + 1):
		draw_line(Vector2(i * cell_size, 0), Vector2(i * cell_size, height), Color.GRAY)
	for j in range(map_size.y + 1):
		draw_line(Vector2(0, j * cell_size), Vector2(width, j * cell_size), Color.GRAY)
	
	if selected_cell.x >= 0 and selected_cell.y >= 0:
		var selected_pos := Vector2(selected_cell.x * cell_size, selected_cell.y * cell_size)
		draw_rect(Rect2(selected_pos, Vector2(cell_size, cell_size)), Color(0, 1, 0, 0.3), true)
		draw_rect(Rect2(selected_pos, Vector2(cell_size, cell_size)), Color(0, 1, 0, 1), false, 2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func get_selected_position() -> Vector3:
	return Vector3(selected_cell.x, 0, selected_cell.y)

func set_selected_position(pos: Vector3) -> void:
	selected_cell = Vector2i(int(round(pos.x)), int(round(pos.z)))
	queue_redraw()

func get_selected_cell() -> Vector2i:
	return selected_cell

func set_selected_cell(cell: Vector2i) -> void:
	selected_cell = cell
	queue_redraw()

func set_view(new_zoom: float, new_offset: Vector2) -> void:
	queue_redraw()

func _screen_to_world(local_pos: Vector2) -> Vector2:
	return local_pos / cell_size

func _screen_to_grid(local_pos: Vector2) -> Vector2:
	return _screen_to_world(local_pos)
