class_name DrawKit
extends RefCounted
## Small shape helpers shared by the code-drawn placeholder art.

static var _textures: Dictionary = {}


static func ellipse(center: Vector2, rx: float, ry: float, segments: int = 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## An ellipse with scalloped "fur tuft" edges.
static func blob(center: Vector2, rx: float, ry: float, bumps: int, amp: float, segments: int = 96) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		var k := 1.0 + amp * absf(sin(a * bumps * 0.5))
		pts.append(center + Vector2(cos(a) * rx * k, sin(a) * ry * k))
	return pts


static func rounded_rect(rect: Rect2, radius: float, corner_segments: int = 6) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		[rect.position + Vector2(rect.size.x - r, r), -PI * 0.5],
		[rect.position + Vector2(rect.size.x - r, rect.size.y - r), 0.0],
		[rect.position + Vector2(r, rect.size.y - r), PI * 0.5],
		[rect.position + Vector2(r, r), PI],
	]
	for c in corners:
		var center: Vector2 = c[0]
		var start: float = c[1]
		for i in corner_segments + 1:
			var a := start + (PI * 0.5) * float(i) / float(corner_segments)
			pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


static func mirror(pts: PackedVector2Array, flip: bool) -> PackedVector2Array:
	if not flip:
		return pts
	var out := PackedVector2Array()
	for i in range(pts.size() - 1, -1, -1):
		out.append(Vector2(-pts[i].x, pts[i].y))
	return out


static func outline(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	if pts.size() < 2:
		return
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, color, width, true)


static func fill_outlined(ci: CanvasItem, pts: PackedVector2Array, fill: Color, line: Color, width: float) -> void:
	ci.draw_colored_polygon(pts, fill)
	outline(ci, pts, line, width)


static func capsule(ci: CanvasItem, a: Vector2, b: Vector2, r: float, color: Color) -> void:
	ci.draw_line(a, b, color, r * 2.0, true)
	ci.draw_circle(a, r, color, true, -1.0, true)
	ci.draw_circle(b, r, color, true, -1.0, true)


static func capsule_outlined(ci: CanvasItem, a: Vector2, b: Vector2, r: float, fill: Color, line: Color, width: float) -> void:
	capsule(ci, a, b, r + width * 0.5, line)
	capsule(ci, a, b, r - width * 0.5, fill)


static func rrect(ci: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	ci.draw_colored_polygon(rounded_rect(rect, radius), color)


## Hard-edged (1 px anti-aliased) circle texture for particles.
static func circle_texture(radius: int = 16) -> Texture2D:
	var key := "circle_%d" % radius
	if _textures.has(key):
		return _textures[key]
	var d := radius * 2
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - radius, y + 0.5 - radius).length()
			var a := clampf(float(radius) - dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex


## Four-point sparkle (a thin plus with tapered arms) for lid pops.
static func sparkle_texture() -> Texture2D:
	if _textures.has("sparkle"):
		return _textures["sparkle"]
	var d := 32
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	for y in d:
		for x in d:
			var nx := absf(x + 0.5 - d * 0.5) / (d * 0.5)
			var ny := absf(y + 0.5 - d * 0.5) / (d * 0.5)
			# Astroid-like star: |x|^0.5 + |y|^0.5 <= 1
			var v := sqrt(nx) + sqrt(ny)
			var a := clampf((1.0 - v) * 5.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	_textures["sparkle"] = tex
	return tex


## Small paper rectangle for confetti.
static func paper_texture() -> Texture2D:
	if _textures.has("paper"):
		return _textures["paper"]
	var img := Image.create(22, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_textures["paper"] = tex
	return tex


## Regular polygon points (hexagons, stars use their own helper).
static func regular(center: Vector2, r: float, sides: int, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var a := rot + TAU * float(i) / float(sides)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


static func star(center: Vector2, r_out: float, r_in: float, points: int = 5, rot: float = -PI * 0.5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := rot + PI * float(i) / float(points)
		var r := r_out if i % 2 == 0 else r_in
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


static func petal_texture() -> Texture2D:
	if _textures.has("petal"):
		return _textures["petal"]
	var w := 28
	var h := 16
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var nx := (x + 0.5 - w * 0.5) / (w * 0.5)
			var ny := (y + 0.5 - h * 0.5) / (h * 0.5)
			var v := nx * nx + ny * ny
			var a := clampf((1.0 - v) * 6.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	_textures["petal"] = tex
	return tex


static func streak_texture() -> Texture2D:
	if _textures.has("streak"):
		return _textures["streak"]
	var img := Image.create(64, 4, false, Image.FORMAT_RGBA8)
	for y in 4:
		for x in 64:
			var edge := minf(float(x), float(63 - x)) / 16.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(edge, 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	_textures["streak"] = tex
	return tex


# --- Glossy game-UI shapes ---------------------------------------------------

## Fills a polygon with a vertical gradient (top colour -> bottom colour).
static func gradient_fill(ci: CanvasItem, pts: PackedVector2Array, top: Color, bottom: Color) -> void:
	if pts.size() < 3:
		return
	var y0 := INF
	var y1 := -INF
	for p in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var span := maxf(1.0, y1 - y0)
	var cols := PackedColorArray()
	cols.resize(pts.size())
	for i in pts.size():
		cols[i] = top.lerp(bottom, (pts[i].y - y0) / span)
	ci.draw_polygon(pts, cols)


## Thin antialiased rim so code-drawn fills look smooth (no MSAA on GLES3).
static func aa_rim(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float = 1.6) -> void:
	outline(ci, pts, color, width)


## A chunky glossy game button/tile: drop shadow, dark outline, a darker 3D
## lip at the bottom, a gradient body and a gloss highlight on top.
## `press` 0..1 pushes the body down onto the lip.
static func glossy_rrect(ci: CanvasItem, rect: Rect2, radius: float, base: Color, edge: Color, press: float = 0.0, outline_w: float = 5.0, lip: float = 12.0, shadow: bool = true) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	if shadow:
		ci.draw_colored_polygon(rounded_rect(Rect2(rect.position + Vector2(0, lip * 0.6 + 6), rect.size), r, 8), Color(0.05, 0.02, 0.15, 0.28))
	var outer := rounded_rect(rect, r, 8)
	var dark := edge.darkened(0.45)
	ci.draw_colored_polygon(outer, dark)
	aa_rim(ci, outer, dark)
	var inner := rect.grow(-outline_w)
	var ri := maxf(2.0, r - outline_w)
	ci.draw_colored_polygon(rounded_rect(inner, ri, 8), edge)
	var l := lip * (1.0 - press)
	var body := Rect2(inner.position + Vector2(0, lip - l), Vector2(inner.size.x, inner.size.y - lip))
	var body_pts := rounded_rect(body, ri, 8)
	gradient_fill(ci, body_pts, base.lightened(0.32), base)
	# Gloss on the upper half.
	var inset := minf(body.size.x, body.size.y) * 0.08 + 2.0
	var g := Rect2(body.position + Vector2(inset, inset * 0.7), Vector2(body.size.x - inset * 2.0, body.size.y * 0.42))
	if g.size.x > 4 and g.size.y > 4:
		gradient_fill(ci, rounded_rect(g, minf(ri, g.size.y * 0.5), 6), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.06))
	# A small sparkle of shine at the top left.
	var d := clampf(body.size.y * 0.09, 3.0, 12.0)
	ci.draw_circle(body.position + Vector2(ri * 0.75 + d, inset * 0.7 + d * 1.2), d, Color(1, 1, 1, 0.75), true, -1.0, true)


## A glossy round badge/button (same layers as glossy_rrect).
static func glossy_circle(ci: CanvasItem, c: Vector2, rad: float, base: Color, edge: Color, outline_w: float = 5.0, lip: float = 8.0) -> void:
	ci.draw_circle(c + Vector2(0, lip * 0.6 + 4), rad, Color(0.05, 0.02, 0.15, 0.28), true, -1.0, true)
	ci.draw_circle(c, rad, edge.darkened(0.45), true, -1.0, true)
	ci.draw_circle(c, rad - outline_w, edge, true, -1.0, true)
	var body := ellipse(c - Vector2(0, lip * 0.5), rad - outline_w, rad - outline_w - lip * 0.5, 40)
	gradient_fill(ci, body, base.lightened(0.32), base)
	var g := ellipse(c - Vector2(0, rad * 0.42), (rad - outline_w) * 0.62, (rad - outline_w) * 0.3, 28)
	gradient_fill(ci, g, Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.08))
