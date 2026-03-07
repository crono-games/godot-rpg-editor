@tool
extends EditorScript

var src_path := "res://graphics/system/font.png"
var dst_path := "res://graphics/system/baseline_atlas.png"

var cell_size := Vector2i(16,16)

# <<< AJUSTA ESTO >>>
var baseline := 12


func _run():

	var tex: Texture2D = load(src_path)
	var src := tex.get_image()
	src.convert(Image.FORMAT_RGBA8)

	var size := src.get_size()
	var cols := size.x / cell_size.x
	var rows := size.y / cell_size.y

	var dst := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	dst.fill(Color(0,0,0,0))
	

	for y in rows:
		for x in cols:

			var region := Rect2i(
				x*cell_size.x,
				y*cell_size.y,
				cell_size.x,
				cell_size.y
			)
			for i in cell_size.x:
				dst.set_pixel(region.position.x+i, region.position.y, Color.RED)
				
			var bounds := _get_bounds(src, region)
			if bounds.size.x == 0:
				continue

			# ---- offsets ----
			var offset_x := int((cell_size.x - bounds.size.x) / 2)

			var offset_y := baseline - bounds.size.y

			offset_y = clamp(offset_y, 0, cell_size.y - bounds.size.y)


			var glyph_bottom = bounds.size.y

			for py in bounds.size.y:
				for px in bounds.size.x:
					var col := src.get_pixel(
						bounds.position.x + px,
						bounds.position.y + py
					)

					dst.set_pixel(
						region.position.x + offset_x + px,
						region.position.y + offset_y + py,
						col
					)

	dst.save_png(dst_path)

func _get_bounds(img: Image, region: Rect2i) -> Rect2i:

	var minx := region.end.x
	var miny := region.end.y
	var maxx := region.position.x
	var maxy := region.position.y

	var found := false

	for y in region.size.y:
		for x in region.size.x:
			var px := img.get_pixel(region.position.x+x,
									region.position.y+y)

			if px.a > 0.1:
				found = true
				minx = min(minx, region.position.x+x)
				miny = min(miny, region.position.y+y)
				maxx = max(maxx, region.position.x+x)
				maxy = max(maxy, region.position.y+y)

	if not found:
		return Rect2i(region.position, Vector2i.ZERO)

	return Rect2i(
		Vector2i(minx, miny),
		Vector2i(maxx-minx+1, maxy-miny+1)
	)
