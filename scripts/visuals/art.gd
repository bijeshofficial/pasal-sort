class_name Art
extends RefCounted
## The painted art (res://assets/art/, from tools/art_brief/import_art.py).
## Paths are stems relative to assets/art without the extension, e.g.
## "ui/btn_green" or "areas/old_counter/counter_broken"; PNG and WebP both
## resolve. Everything that draws looks here first and falls back to its
## code-drawn version when a file is missing, so the game never breaks on a
## missing image.

const ROOT := "res://assets/art/"

## Turn the painted art off (debug / A-B comparisons).
static var enabled := true
static var _cache: Dictionary = {}
static var _boxes: Dictionary = {}


static func tex(stem: String) -> Texture2D:
	if not enabled:
		return null
	if _cache.has(stem):
		return _cache[stem]
	var t: Texture2D = null
	for ext in [".png", ".webp"]:
		var p: String = ROOT + stem + ext
		if ResourceLoader.exists(p):
			t = load(p)
			break
	_cache[stem] = t
	return t


static func has(stem: String) -> bool:
	return tex(stem) != null


## A 9-slice StyleBox from a texture. `margins` = [left, top, right, bottom]
## in source pixels; `scale` shrinks the drawn border (e.g. 0.5 draws a
## 512 px source's 64 px corners at 32 px). Content margins pad children.
static func box(stem: String, margins: Array, scale: float = 1.0, content: Array = []) -> StyleBoxTexture:
	var key := "%s|%s|%s|%s" % [stem, str(margins), scale, str(content)]
	if _boxes.has(key):
		return _boxes[key]
	var t := tex(stem)
	if t == null:
		return null
	# StyleBoxTexture draws its borders at source size, so a smaller border
	# uses a pre-scaled copy of the texture.
	var sb := StyleBoxTexture.new()
	sb.texture = t if is_equal_approx(scale, 1.0) else scaled(stem, scale)
	sb.texture_margin_left = margins[0] * scale
	sb.texture_margin_top = margins[1] * scale
	sb.texture_margin_right = margins[2] * scale
	sb.texture_margin_bottom = margins[3] * scale
	if content.size() == 4:
		sb.content_margin_left = content[0]
		sb.content_margin_top = content[1]
		sb.content_margin_right = content[2]
		sb.content_margin_bottom = content[3]
	_boxes[key] = sb
	return sb


## A resized copy of a texture (cached), for 9-slices drawn at a smaller
## scale than the source.
static func scaled(stem: String, scale: float) -> Texture2D:
	var key := "%s@%s" % [stem, scale]
	if _cache.has(key):
		return _cache[key]
	var t := tex(stem)
	if t == null:
		return null
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	img.resize(maxi(1, int(round(img.get_width() * scale))), maxi(1, int(round(img.get_height() * scale))), Image.INTERPOLATE_LANCZOS)
	var out := ImageTexture.create_from_image(img)
	_cache[key] = out
	return out


## Draws `stem` fitted inside `rect` (keeping its aspect), centred.
## Returns false when the texture is missing (caller draws its fallback).
static func draw_fit(ci: CanvasItem, stem: String, rect: Rect2, modulate: Color = Color.WHITE) -> bool:
	var t := tex(stem)
	if t == null:
		return false
	var ts := t.get_size()
	var k := minf(rect.size.x / ts.x, rect.size.y / ts.y)
	var s := ts * k
	ci.draw_texture_rect(t, Rect2(rect.position + (rect.size - s) * 0.5, s), false, modulate)
	return true


## Draws `stem` covering `rect` (keeping aspect, cropping the overflow).
static func draw_cover(ci: CanvasItem, stem: String, rect: Rect2, modulate: Color = Color.WHITE) -> bool:
	var t := tex(stem)
	if t == null:
		return false
	var ts := t.get_size()
	var k := maxf(rect.size.x / ts.x, rect.size.y / ts.y)
	var src_size := rect.size / k
	var src := Rect2((ts - src_size) * 0.5, src_size)
	ci.draw_texture_rect_region(t, rect, src, modulate)
	return true


## A TextureRect for `stem` (keep-aspect centred), or null.
static func image(stem: String, min_size: Vector2 = Vector2.ZERO) -> TextureRect:
	var t := tex(stem)
	if t == null:
		return null
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = min_size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
