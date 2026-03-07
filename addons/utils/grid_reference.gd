@tool
extends Control
class_name GridOverlay2D

@export var cell_size: int = 16:
	set(value):
		cell_size = max(1, value)
		queue_redraw()

@export var grid_color: Color = Color(1, 1, 1, 0.15):
	set(value):
		grid_color = value
		queue_redraw()

func _ready():
	if not Engine.is_editor_hint():
		visible = false
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw():
	var rect := get_rect()
	var w := rect.size.x
	var h := rect.size.y
	for x in range(0, int(w), cell_size):
		draw_line(
			Vector2(x, 0),
			Vector2(x, h),
			grid_color,
			0.5
		)
	for y in range(0, int(h), cell_size):
		draw_line(
			Vector2(0, y),
			Vector2(w, y),
			grid_color,
			0.5
		)
