@tool
extends EditorPlugin

var grid_size := 16
var _dragging := false
var _nodes := []
var _offsets := {}

func _handles(object) -> bool:
	return object is EventInstance2D

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event)
		else:
			_end_drag()
		return false

	if event is InputEventMouseMotion and _dragging:
		_drag(event)
		return true

	return false

func _begin_drag(event):
	_nodes.clear()
	_offsets.clear()
	var selection = get_editor_interface().get_selection().get_selected_nodes()
	for n in selection:
		if n is EventInstance2D:
			_nodes.append(n)
			var cursor_local = n.get_parent().to_local(_screen_to_canvas(event.position))
			_offsets[n] = cursor_local - n.position
	_dragging = true

func _end_drag():
	_dragging = false
	_nodes.clear()
	_offsets.clear()

func _drag(event):
	for n in _nodes:
		if not is_instance_valid(n):
			continue
		var cursor_local = n.get_parent().to_local(_screen_to_canvas(event.position))
		var new_pos = cursor_local - _offsets[n]
		new_pos = (new_pos / grid_size).floor() * grid_size + Vector2(grid_size/2, grid_size/2)
		n.position = new_pos

func _screen_to_canvas(screen_pos):
	var vp = get_editor_interface().get_editor_viewport_2d()
	return vp.get_canvas_transform().affine_inverse() * screen_pos
