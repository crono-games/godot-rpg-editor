@tool
extends Control
class_name PathPreviewControl

var _points: Array = []

func set_points(points: Array) -> void:
	_points = points.duplicate(true)
	queue_redraw()

func _draw() -> void:
	if _points.is_empty():
		return
	var pts := _as_vec2_points(_points)
	if pts.is_empty():
		return
	var rect := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		rect = rect.expand(p)
	var margin := 8.0
	var size_safe := size - Vector2(margin * 2.0, margin * 2.0)
	if size_safe.x <= 1.0 or size_safe.y <= 1.0:
		return
	var span := rect.size
	if span.x < 1.0:
		span.x = 1.0
	if span.y < 1.0:
		span.y = 1.0
	var scale = min(size_safe.x / span.x, size_safe.y / span.y)
	var offset = Vector2(margin, margin) - rect.position * scale
	var draw_pts: PackedVector2Array = []
	for p in pts:
		draw_pts.append(p * scale + offset)
	if draw_pts.size() >= 2:
		draw_polyline(draw_pts, Color(0.29, 0.73, 1.0, 1.0), 2.0, true)
	for i in draw_pts.size():
		var col := Color(0.95, 0.95, 0.95, 1.0)
		if i == 0:
			col = Color(0.37, 0.93, 0.44, 1.0)
		elif i == draw_pts.size() - 1:
			col = Color(1.0, 0.43, 0.43, 1.0)
		draw_circle(draw_pts[i], 3.0, col)

func _as_vec2_points(raw: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for item in raw:
		if item is Vector2:
			out.append(item)
		elif item is Dictionary:
			out.append(Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0))))
	return out
