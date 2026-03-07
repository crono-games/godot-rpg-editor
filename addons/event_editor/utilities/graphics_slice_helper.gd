@tool
extends RefCounted
class_name GraphicsSliceHelper

static func clamp_frame(frame: int, hframes: int, vframes: int) -> int:
	var h := maxi(1, hframes)
	var v := maxi(1, vframes)
	var total := maxi(1, h * v)
	return clampi(frame, 0, total - 1)

static func compute_frame_rect(texture_size: Vector2i, hframes: int, vframes: int, frame: int) -> Rect2i:
	var w := maxi(1, texture_size.x)
	var h := maxi(1, texture_size.y)
	var cols := maxi(1, hframes)
	var rows := maxi(1, vframes)
	var cell_w := maxi(1, w / cols)
	var cell_h := maxi(1, h / rows)
	var idx := clamp_frame(frame, cols, rows)
	var x := idx % cols
	var y := idx / cols
	return Rect2i(x * cell_w, y * cell_h, cell_w, cell_h)

static func build_atlas_preview(texture: Texture2D, hframes: int, vframes: int, frame: int) -> Texture2D:
	if texture == null:
		return null
	var size := texture.get_size()
	if size.x <= 0 or size.y <= 0:
		return texture
	var rect := compute_frame_rect(Vector2i(size.x, size.y), hframes, vframes, frame)
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = rect
	return atlas

static func compute_grid_from_cell_size(texture_size: Vector2i, cell_size: Vector2i) -> Vector2i:
	var w := maxi(1, texture_size.x)
	var h := maxi(1, texture_size.y)
	var cw := maxi(1, cell_size.x)
	var ch := maxi(1, cell_size.y)
	return Vector2i(maxi(1, w / cw), maxi(1, h / ch))

static func suggest_auto_grid(texture_size: Vector2i) -> Vector2i:
	var w := maxi(1, texture_size.x)
	var h := maxi(1, texture_size.y)

	# Common actor sheets first.
	if w % 3 == 0 and h % 4 == 0:
		return Vector2i(3, 4)
	if w % 4 == 0 and h % 4 == 0:
		return Vector2i(4, 4)

	# Square-cell fallback.
	if w >= h and w % h == 0:
		return Vector2i(maxi(1, w / h), 1)
	if h > w and h % w == 0:
		return Vector2i(1, maxi(1, h / w))

	return Vector2i(1, 1)
