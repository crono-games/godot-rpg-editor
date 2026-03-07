@tool
extends Control
class_name PathOverlay2D

signal point_added(world_pos: Vector2)
signal point_selected(index: int)
signal points_changed(points: Array)
signal pan_requested(delta: Vector2)

var map_origin: Vector2 = Vector2.ZERO
var map_size: Vector2 = Vector2(20, 20)
var pixels_per_cell: float = 32.0
var points: Array[Vector2] = []
var curve_preview_points: Array[Vector2] = []
var selected_index: int = -1
var show_grid: bool = true
var interaction_mode: String = "add"
var _dragging := false

func set_selected_index(index: int) -> void:
	selected_index = index
	queue_redraw()

func set_interaction_mode(mode: String) -> void:
	var normalized := str(mode).to_lower()
	if normalized != "add" and normalized != "move" and normalized != "delete":
		normalized = "add"
	interaction_mode = normalized

func set_data(new_points: Array, origin: Vector2, size_cells: Vector2, ppc: float) -> void:
	points = []
	for p in new_points:
		if p is Vector2:
			points.append(p)
	map_origin = origin
	map_size = size_cells
	pixels_per_cell = maxf(1.0, ppc)
	custom_minimum_size = map_size * pixels_per_cell
	size = custom_minimum_size
	queue_redraw()

func set_curve_preview(new_points: Array) -> void:
	curve_preview_points = []
	for p in new_points:
		if p is Vector2:
			curve_preview_points.append(p)
	queue_redraw()

func set_show_grid(value: bool) -> void:
	show_grid = value
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(get_local_mouse_position())
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			selected_index = _find_nearest_point_index(get_local_mouse_position(), 8.0)
			point_selected.emit(selected_index)
			queue_redraw()
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			pan_requested.emit(mm.relative)
			return
		var force_move := Input.is_key_pressed(KEY_CTRL)
		if (interaction_mode == "move" or force_move) and _dragging and selected_index >= 0 and selected_index < points.size():
			points[selected_index] = _local_to_world(get_local_mouse_position())
			points_changed.emit(points.duplicate(true))
			queue_redraw()
	if event is InputEventMouseButton and not event.pressed:
		var mbu := event as InputEventMouseButton
		if mbu.button_index == MOUSE_BUTTON_LEFT:
			_dragging = false

func _draw() -> void:
	if show_grid:
		_draw_grid()
	var local_points: PackedVector2Array = []
	for p in points:
		local_points.append(_world_to_local(p))
	#if local_points.size() >= 2:
		#draw_polyline(local_points, Color(0.75, 0.75, 0.75, 0.75), 1.0, true)
	var curve_local: PackedVector2Array = []
	for p in curve_preview_points:
		curve_local.append(_world_to_local(p))
	if curve_local.size() >= 2:
		draw_polyline(curve_local, Color(1.0, 0.255, 0.0, 1.0), 1.0, true)
	elif local_points.size() >= 2:
		draw_polyline(local_points, Color(1.0, 0.255, 0.0, 1.0), 1.0, true)
	for i in local_points.size():
		var col := Color(0.92, 0.92, 0.92, 1.0)
		var outline_col := Color(0.92, 0.92, 0.92, 1.0)

		if i == 0:
			col = Color(1.0, 1.0, 1.0, 1.0)
			outline_col = Color(0.0, 0.0, 0.0, 1.0)

		if i == selected_index:
			col = Color(0.123, 0.916, 1.0, 1.0)
			outline_col = Color(0.0, 0.0, 0.0, 1.0)
		draw_circle(local_points[i], 4.0, outline_col)
		draw_circle(local_points[i], 3.0, col)

func _draw_grid() -> void:
	var w := int(round(map_size.x))
	var h := int(round(map_size.y))
	var cw := pixels_per_cell
	var total_w := float(w) * cw
	var total_h := float(h) * cw
	for x in range(w + 1):
		var lx := float(x) * cw
		draw_line(Vector2(lx, 0.0), Vector2(lx, total_h), Color(0.45, 0.45, 0.45, 0.45))
	for y in range(h + 1):
		var ly := float(y) * cw
		draw_line(Vector2(0.0, ly), Vector2(total_w, ly), Color(0.45, 0.45, 0.45, 0.45))

func _local_to_world(local_pos: Vector2) -> Vector2:
	return map_origin + local_pos

func _world_to_local(world_pos: Vector2) -> Vector2:
	return world_pos - map_origin

func _find_nearest_point_index(local_pos: Vector2, radius: float) -> int:
	if points.is_empty():
		return -1
	var radius_sq := radius * radius
	var best_idx := -1
	var best_dist := INF
	for i in points.size():
		var d := _world_to_local(points[i]).distance_squared_to(local_pos)
		if d <= radius_sq and d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx

func _handle_left_click(local_pos: Vector2) -> void:
	var near_idx := _find_nearest_point_index(local_pos, 10.0)
	var force_move := Input.is_key_pressed(KEY_CTRL)
	if near_idx >= 0:
		selected_index = near_idx
		point_selected.emit(selected_index)
		_dragging = interaction_mode == "move" or force_move
		if interaction_mode == "delete":
			points.remove_at(near_idx)
			selected_index = clampi(near_idx - 1, -1, points.size() - 1)
			points_changed.emit(points.duplicate(true))
			point_selected.emit(selected_index)
		queue_redraw()
		return
	match interaction_mode:
		"move":
			_dragging = false
			queue_redraw()
		"delete":
			queue_redraw()
		_:
			var world := _local_to_world(local_pos)
			points.append(world)
			selected_index = points.size() - 1
			point_added.emit(world)
			points_changed.emit(points.duplicate(true))
			point_selected.emit(selected_index)
			queue_redraw()
