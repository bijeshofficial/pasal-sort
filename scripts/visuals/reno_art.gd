class_name RenoArt
extends RefCounted
## Code-drawn placeholder art for renovatable objects.
##
## draw_object(ci, kind, size, style, broken, t) draws one object inside
## Rect2(Vector2.ZERO, size). `style` is a dictionary from the area JSON:
##   {base: "hex", accent: "hex", trim: "hex" (optional), pattern: "carved" |
##    "painted" | "steel" | "stripes" | "dhaka" | "tiles" | "planks" |
##    "checks" | "brick" | "plaster" | "floral" | "bamboo" | "gold" | "plain"}
## broken = the dusty "before" state: desaturated, cracked, cobwebs.
## Every kind uses the same pattern vocabulary, so three styles of one
## object differ clearly in colour and pattern.

const GRIME := Color(0.47, 0.43, 0.38)
const INK := Color("3a2416")
const BROKEN_STYLE := {"base": "8f8274", "accent": "6f655a", "pattern": "plain"}

## One shared instance hosts the per-kind drawers (looked up by name).
static var _drawer: RenoArt
## The caller's placement; drawers that rotate compose with it.
static var _base := Transform2D.IDENTITY


## Kinds this class can draw (used by the area data validator).
static func has_kind(kind: String) -> bool:
	if _drawer == null:
		_drawer = RenoArt.new()
	return _drawer.has_method("_" + kind)


static func col(style: Dictionary, key: String, fallback: String) -> Color:
	return Color.html(String(style.get(key, fallback)))


## Dusty, washed-out version of a colour (broken objects).
static func grime(c: Color) -> Color:
	return c.lerp(GRIME, 0.6).darkened(0.08)


static func ol(c: Color) -> Color:
	return c.darkened(0.5)


static func rect_pts(r: Rect2, radius: float = 0.0) -> PackedVector2Array:
	if radius <= 0.5:
		return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	return DrawKit.rounded_rect(r, radius, 5)


## Filled shape with a dark outline.
static func shape(ci: CanvasItem, pts: PackedVector2Array, fill: Color, line_w: float = 5.0) -> void:
	ci.draw_colored_polygon(pts, fill)
	DrawKit.outline(ci, pts, ol(fill), line_w)


static func box(ci: CanvasItem, r: Rect2, fill: Color, radius: float = 6.0, line_w: float = 5.0) -> void:
	shape(ci, rect_pts(r, radius), fill, line_w)


static func soft_shadow(ci: CanvasItem, center: Vector2, rx: float, ry: float, alpha: float = 0.22) -> void:
	ci.draw_colored_polygon(DrawKit.ellipse(center, rx, ry, 28), Color(0.1, 0.05, 0.02, alpha))


## Fills `r` with a surface pattern. The outline is drawn by the caller.
static func pattern_rect(ci: CanvasItem, r: Rect2, pattern: String, base: Color, accent: Color, radius: float = 0.0) -> void:
	var pts := rect_pts(r, radius)
	DrawKit.gradient_fill(ci, pts, base.lightened(0.1), base.darkened(0.06))
	var x0 := r.position.x
	var y0 := r.position.y
	var w := r.size.x
	var h := r.size.y
	match pattern:
		"carved":
			# Recessed panels with a diamond lattice (Newari carved wood).
			var cols := maxi(1, int(round(w / 150.0)))
			var rows := maxi(1, int(round(h / 160.0)))
			var pw := w / cols
			var ph := h / rows
			for i in cols:
				for j in rows:
					var pr := Rect2(x0 + i * pw + pw * 0.12, y0 + j * ph + ph * 0.14, pw * 0.76, ph * 0.72)
					ci.draw_colored_polygon(rect_pts(pr, 6), base.darkened(0.22))
					DrawKit.outline(ci, rect_pts(pr, 6), accent, 3.0)
					var c := pr.get_center()
					var dx := pr.size.x * 0.32
					var dy := pr.size.y * 0.32
					ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -dy), c + Vector2(dx, 0), c + Vector2(0, dy), c + Vector2(-dx, 0)]), accent.darkened(0.1))
					ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -dy * 0.5), c + Vector2(dx * 0.5, 0), c + Vector2(0, dy * 0.5), c + Vector2(-dx * 0.5, 0)]), base.darkened(0.3))
		"painted":
			var band := clampf(h * 0.12, 8.0, 40.0)
			ci.draw_rect(Rect2(x0, y0 + band * 0.6, w, band * 0.5), accent)
			ci.draw_rect(Rect2(x0, y0 + h - band * 1.1, w, band * 0.5), accent)
			var n := maxi(2, int(w / 120.0))
			for i in n:
				var c := Vector2(x0 + (i + 0.5) * w / n, y0 + h * 0.5)
				_flower(ci, c, clampf(h * 0.12, 8.0, 34.0), accent, base.lightened(0.5))
		"steel":
			DrawKit.gradient_fill(ci, pts, base.lightened(0.35), base.darkened(0.15))
			ci.draw_colored_polygon(rect_pts(Rect2(x0 + w * 0.08, y0, w * 0.1, h), 0), Color(1, 1, 1, 0.22))
			ci.draw_colored_polygon(rect_pts(Rect2(x0 + w * 0.22, y0, w * 0.035, h), 0), Color(1, 1, 1, 0.15))
			var step := maxf(60.0, w / 8.0)
			var x := x0 + step * 0.5
			while x < x0 + w:
				ci.draw_circle(Vector2(x, y0 + 12), 4.5, accent, true, -1.0, true)
				ci.draw_circle(Vector2(x, y0 + h - 12), 4.5, accent, true, -1.0, true)
				x += step
		"stripes":
			var sw := clampf(w / 10.0, 18.0, 60.0)
			var i := 0
			var x := x0
			while x < x0 + w:
				if i % 2 == 1:
					ci.draw_rect(Rect2(x, y0, minf(sw, x0 + w - x), h), accent)
				x += sw
				i += 1
		"dhaka":
			# Woven dhaka cloth: rows of little diamonds and triangles.
			var cell := clampf(minf(w, h) / 6.0, 16.0, 46.0)
			var palette := [accent, Color("1f2a36"), Color("f2b632"), Color("fff3e0")]
			var row := 0
			var y := y0 + cell * 0.5
			while y < y0 + h:
				var x := x0 + cell * (0.5 if row % 2 == 0 else 1.0)
				var k := row
				while x < x0 + w:
					var s := cell * 0.34
					var c := Vector2(x, y)
					ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), palette[k % palette.size()])
					x += cell
					k += 1
				y += cell * 0.8
				row += 1
		"tiles":
			var tile := clampf(minf(w, h) / 4.0, 40.0, 110.0)
			var y := y0
			var j := 0
			while y < y0 + h:
				var x := x0
				var i := 0
				while x < x0 + w:
					var tr := Rect2(x + 3, y + 3, minf(tile, x0 + w - x) - 6, minf(tile, y0 + h - y) - 6)
					if tr.size.x > 4 and tr.size.y > 4:
						ci.draw_colored_polygon(rect_pts(tr, 4), base if (i + j) % 2 == 0 else base.lerp(accent, 0.35))
						ci.draw_rect(Rect2(tr.position + Vector2(4, 4), Vector2(tr.size.x - 8, 4)), Color(1, 1, 1, 0.18))
					x += tile
					i += 1
				y += tile
				j += 1
		"planks":
			var ph := clampf(h / 6.0, 22.0, 60.0)
			var y := y0
			var j := 0
			while y < y0 + h:
				var hh := minf(ph, y0 + h - y)
				ci.draw_rect(Rect2(x0, y, w, hh), base.darkened(0.05 * (j % 3)))
				ci.draw_line(Vector2(x0, y), Vector2(x0 + w, y), base.darkened(0.35), 3.0)
				var seam := x0 + fmod(j * 173.0, maxf(1.0, w - 40.0)) + 20.0
				ci.draw_line(Vector2(seam, y), Vector2(seam, y + hh), base.darkened(0.3), 3.0)
				ci.draw_line(Vector2(x0 + 10, y + hh * 0.55), Vector2(x0 + w * 0.4, y + hh * 0.5), Color(accent, 0.35), 2.0)
				y += ph
				j += 1
		"checks":
			var c2 := clampf(minf(w, h) / 5.0, 30.0, 90.0)
			var j := 0
			var y := y0
			while y < y0 + h:
				var i := 0
				var x := x0
				while x < x0 + w:
					if (i + j) % 2 == 1:
						ci.draw_rect(Rect2(x, y, minf(c2, x0 + w - x), minf(c2, y0 + h - y)), accent)
					x += c2
					i += 1
				y += c2
				j += 1
		"brick":
			var bh := clampf(h / 10.0, 26.0, 46.0)
			var bw := bh * 2.3
			var j := 0
			var y := y0
			while y < y0 + h:
				var off := bw * 0.5 if j % 2 == 1 else 0.0
				var x := x0 - off
				var i := 0
				while x < x0 + w:
					var br := Rect2(maxf(x0, x) + 3, y + 3, minf(x + bw, x0 + w) - maxf(x0, x) - 6, minf(bh, y0 + h - y) - 6)
					if br.size.x > 4 and br.size.y > 4:
						ci.draw_colored_polygon(rect_pts(br, 3), base.darkened(0.04 * ((i + j) % 3)))
					x += bw
					i += 1
				y += bh
				j += 1
			# Mortar shows through the gaps (the base fill is drawn first).
		"plaster":
			var rng := RandomNumberGenerator.new()
			rng.seed = int(w * 13 + h * 7)
			for k in int(w * h / 9000.0):
				var p := Vector2(x0 + rng.randf() * w, y0 + rng.randf() * h)
				ci.draw_circle(p, rng.randf_range(2.0, 5.0), Color(accent, 0.18), true, -1.0, true)
		"floral":
			var n := maxi(3, int(w * h / 26000.0))
			var rng := RandomNumberGenerator.new()
			rng.seed = int(w * 3 + h)
			for k in n:
				var p := Vector2(x0 + rng.randf_range(0.08, 0.92) * w, y0 + rng.randf_range(0.12, 0.88) * h)
				_flower(ci, p, clampf(minf(w, h) * 0.07, 7.0, 26.0), accent, Color("fff3c4"))
		"bamboo":
			var bwid := clampf(w / 9.0, 18.0, 44.0)
			var x := x0
			var i := 0
			while x < x0 + w:
				var cw := minf(bwid, x0 + w - x)
				ci.draw_rect(Rect2(x + 1, y0, cw - 2, h), base.darkened(0.06 * (i % 2)))
				ci.draw_rect(Rect2(x + cw * 0.2, y0, cw * 0.15, h), Color(1, 1, 1, 0.16))
				var y := y0 + 50.0 + (i % 3) * 20.0
				while y < y0 + h:
					ci.draw_line(Vector2(x + 2, y), Vector2(x + cw - 2, y), accent, 4.0)
					y += 90.0
				x += bwid
				i += 1
		"gold":
			var band := clampf(minf(w, h) * 0.08, 6.0, 22.0)
			DrawKit.outline(ci, rect_pts(r.grow(-band), maxf(0.0, radius - band)), accent, band * 0.6)
			ci.draw_rect(Rect2(x0 + band * 2, y0 + band * 2, w - band * 4, band * 0.6), Color(1, 1, 1, 0.3))
		_:
			pass


static func _flower(ci: CanvasItem, c: Vector2, r: float, petal: Color, center: Color) -> void:
	for k in 5:
		var a := TAU * k / 5.0 - PI * 0.5
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.6, r * 0.45, petal, true, -1.0, true)
	ci.draw_circle(c, r * 0.32, center, true, -1.0, true)


## Dust specks, cracks and a cobweb on a broken object.
static func wear(ci: CanvasItem, r: Rect2, seed_value: int, web: bool = true) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := clampi(int(r.size.x * r.size.y / 7000.0), 6, 60)
	for k in n:
		var p := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		ci.draw_circle(p, rng.randf_range(2.0, 6.0), Color(0.86, 0.82, 0.74, rng.randf_range(0.18, 0.4)), true, -1.0, true)
	for k in clampi(int(r.size.x / 260.0), 1, 4):
		var p := r.position + Vector2(rng.randf_range(0.15, 0.85) * r.size.x, rng.randf_range(0.1, 0.5) * r.size.y)
		var pts := PackedVector2Array([p])
		for s in 4:
			p += Vector2(rng.randf_range(-22, 22), rng.randf_range(14, 34))
			pts.append(p)
		ci.draw_polyline(pts, Color(0.18, 0.12, 0.08, 0.55), 3.0, true)
	if web and r.size.x > 120 and r.size.y > 80:
		cobweb(ci, r.position + Vector2(4, 4), minf(90.0, minf(r.size.x, r.size.y) * 0.35))


static func cobweb(ci: CanvasItem, corner: Vector2, size: float, flip: bool = false) -> void:
	var sx := -1.0 if flip else 1.0
	var col := Color(1, 1, 1, 0.55)
	for k in 5:
		var a := (PI * 0.5) * k / 4.0
		ci.draw_line(corner, corner + Vector2(cos(a) * sx, sin(a)) * size, col, 2.0, true)
	for ring in 3:
		var rr := size * (0.35 + ring * 0.3)
		var pts := PackedVector2Array()
		for k in 5:
			var a := (PI * 0.5) * k / 4.0
			pts.append(corner + Vector2(cos(a) * sx, sin(a)) * rr * (0.92 if k % 2 == 1 else 1.0))
		ci.draw_polyline(pts, col, 2.0, true)


# --- Objects -----------------------------------------------------------------

## Draws `kind` in Rect2(0, 0, size), placed by `base` (offset/scale on the
## canvas item). `t` is time for small animations.
static func draw_object(ci: CanvasItem, kind: String, size: Vector2, style: Dictionary, broken: bool, t: float = 0.0, night: bool = false, base_xform: Transform2D = Transform2D.IDENTITY) -> void:
	_base = base_xform
	ci.draw_set_transform_matrix(_base)
	var st: Dictionary = BROKEN_STYLE if broken and style.is_empty() else style
	var base := col(st, "base", "b07a4a")
	var accent := col(st, "accent", "f2b632")
	var trim := col(st, "trim", base.darkened(0.3).to_html(false))
	var pattern := String(st.get("pattern", "plain"))
	if broken:
		base = grime(base)
		accent = grime(accent)
		trim = grime(trim)
		pattern = "plain"
	var w := size.x
	var h := size.y
	var fn: String = "_" + kind
	var args := [ci, size, base, accent, trim, pattern, broken, t, night]
	if _drawer == null:
		_drawer = RenoArt.new()
	if _drawer.has_method(fn):
		_drawer.callv(fn, args)
	else:
		box(ci, Rect2(Vector2.ZERO, size), base, 12)
		pattern_rect(ci, Rect2(Vector2(6, 6), size - Vector2(12, 12)), pattern, base, accent, 8)
	if broken:
		wear(ci, Rect2(Vector2.ZERO, Vector2(w, h)), hash(kind) + int(w), kind in ["wall", "facade", "shelf", "rack", "window", "counter", "cabinet"])
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# Each drawer: (ci, size, base, accent, trim, pattern, broken, t, night)

func _wall(ci: CanvasItem, s: Vector2, base: Color, accent: Color, trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	var r := Rect2(Vector2.ZERO, s)
	RenoArt.pattern_rect(ci, r, pattern if not broken else "plaster", base, accent)
	# Wainscot band near the floor and a picture rail.
	ci.draw_rect(Rect2(0, s.y * 0.72, s.x, s.y * 0.28), Color(trim, 0.85))
	ci.draw_rect(Rect2(0, s.y * 0.72, s.x, 10), trim.darkened(0.3))
	ci.draw_rect(Rect2(0, s.y * 0.1, s.x, 8), trim.darkened(0.15))
	if broken:
		# Peeling plaster shows the bricks underneath.
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for k in 6:
			var c := Vector2(rng.randf_range(0.05, 0.95) * s.x, rng.randf_range(0.18, 0.65) * s.y)
			var patch := DrawKit.blob(c, rng.randf_range(50, 110), rng.randf_range(34, 70), 5, 0.25, 30)
			ci.draw_colored_polygon(patch, Color("8e5a45").lerp(RenoArt.GRIME, 0.5))
			for b in 3:
				ci.draw_line(c + Vector2(-40, -16 + b * 16), c + Vector2(40, -16 + b * 16), Color(0.3, 0.2, 0.15, 0.4), 2.0)
			DrawKit.outline(ci, patch, Color(0.95, 0.9, 0.8, 0.5), 3.0)
		for k in 4:
			var x := rng.randf_range(0.1, 0.9) * s.x
			ci.draw_rect(Rect2(x, s.y * 0.1, rng.randf_range(16, 30), s.y * rng.randf_range(0.2, 0.5)), Color(0.35, 0.28, 0.2, 0.18))


func _facade(ci: CanvasItem, s: Vector2, base: Color, accent: Color, trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	var r := Rect2(0, 0, s.x, s.y)
	RenoArt.pattern_rect(ci, r, pattern if not broken else "brick", base, accent)
	DrawKit.outline(ci, RenoArt.rect_pts(r), RenoArt.ol(base), 6.0)
	# Carved cornice along the top and a floor band between the storeys.
	RenoArt.box(ci, Rect2(-20, -10, s.x + 40, 46), trim, 6)
	for k in int(s.x / 60.0):
		ci.draw_rect(Rect2(10 + k * 60, 36, 26, 18), trim.darkened(0.2))
	RenoArt.box(ci, Rect2(-10, s.y * 0.34, s.x + 20, 30), trim, 4)


func _floor(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	var r := Rect2(Vector2.ZERO, s)
	RenoArt.pattern_rect(ci, r, pattern, base, accent)
	ci.draw_rect(Rect2(0, 0, s.x, 14), Color(0, 0, 0, 0.22))
	if broken:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for k in 7:
			var p := Vector2(rng.randf() * s.x, rng.randf_range(0.2, 0.9) * s.y)
			var pts := PackedVector2Array([p])
			for i in 5:
				p += Vector2(rng.randf_range(20, 60), rng.randf_range(-16, 16))
				pts.append(p)
			ci.draw_polyline(pts, Color(0.15, 0.1, 0.06, 0.5), 3.0, true)
		for k in 5:
			ci.draw_colored_polygon(DrawKit.ellipse(Vector2(rng.randf() * s.x, rng.randf_range(0.3, 0.9) * s.y), rng.randf_range(40, 90), rng.randf_range(10, 22), 16), Color(0.25, 0.2, 0.15, 0.18))


func _street(ci: CanvasItem, s: Vector2, base: Color, accent: Color, trim: Color, pattern: String, broken: bool, t: float, n: bool) -> void:
	_floor(ci, s, base, accent, trim, pattern if pattern != "plain" else "tiles", broken, t, n)
	ci.draw_rect(Rect2(0, 0, s.x, 20), trim)
	if broken:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		for k in 8:
			var c := Vector2(rng.randf() * s.x, rng.randf_range(0.3, 0.9) * s.y)
			ci.draw_colored_polygon(DrawKit.blob(c, 26, 12, 4, 0.3, 16), Color("6e6253"))
			ci.draw_line(c + Vector2(-8, -18), c + Vector2(-2, -40), Color("7d8f4a"), 3.0)


func _window(ci: CanvasItem, s: Vector2, base: Color, accent: Color, trim: Color, pattern: String, broken: bool, t: float, night: bool) -> void:
	var frame := Rect2(0, 0, s.x, s.y)
	var glass := Rect2(s.x * 0.12, s.y * 0.12, s.x * 0.76, s.y * 0.72)
	# The view: sky and mountains.
	var sky_top := Color("21305a") if night else Color("8fd0ff")
	var sky_bot := Color("4b3f7a") if night else Color("dff3ff")
	DrawKit.gradient_fill(ci, RenoArt.rect_pts(glass), sky_top, sky_bot)
	var gy := glass.end.y
	var m := PackedVector2Array([Vector2(glass.position.x, gy), Vector2(glass.position.x, gy - glass.size.y * 0.35), Vector2(glass.position.x + glass.size.x * 0.3, gy - glass.size.y * 0.62), Vector2(glass.position.x + glass.size.x * 0.5, gy - glass.size.y * 0.42), Vector2(glass.position.x + glass.size.x * 0.75, gy - glass.size.y * 0.7), Vector2(glass.end.x, gy - glass.size.y * 0.38), Vector2(glass.end.x, gy)])
	ci.draw_colored_polygon(m, Color("8aa0c8") if not night else Color("39406a"))
	ci.draw_colored_polygon(PackedVector2Array([m[2] + Vector2(-26, 22), m[2], m[2] + Vector2(26, 22)]), Color.WHITE if not night else Color("b7bedc"))
	ci.draw_colored_polygon(PackedVector2Array([m[4] + Vector2(-30, 26), m[4], m[4] + Vector2(30, 26)]), Color.WHITE if not night else Color("b7bedc"))
	# Frame.
	var fw := s.x * 0.12
	for r in [Rect2(0, 0, s.x, s.y * 0.12), Rect2(0, s.y * 0.84, s.x, s.y * 0.16), Rect2(0, 0, fw, s.y), Rect2(s.x - fw, 0, fw, s.y)]:
		RenoArt.pattern_rect(ci, r, pattern if pattern in ["carved", "steel", "gold", "painted"] else "plain", base, accent)
	DrawKit.outline(ci, RenoArt.rect_pts(frame), RenoArt.ol(base), 6.0)
	DrawKit.outline(ci, RenoArt.rect_pts(glass), RenoArt.ol(base), 4.0)
	# Mullions.
	ci.draw_line(Vector2(s.x * 0.5, glass.position.y), Vector2(s.x * 0.5, glass.end.y), base.darkened(0.1), maxf(6.0, s.x * 0.035))
	ci.draw_line(Vector2(glass.position.x, s.y * 0.45), Vector2(glass.end.x, s.y * 0.45), base.darkened(0.1), maxf(6.0, s.x * 0.03))
	if pattern == "carved" and not broken:
		# A carved Newari lintel with little teeth.
		RenoArt.box(ci, Rect2(-s.x * 0.08, -s.y * 0.1, s.x * 1.16, s.y * 0.12), base.darkened(0.1), 4)
		for k in 9:
			ci.draw_rect(Rect2(-s.x * 0.04 + k * s.x * 0.125, s.y * 0.0, s.x * 0.05, s.y * 0.04), accent.darkened(0.1))
	# Glass shine.
	ci.draw_colored_polygon(PackedVector2Array([glass.position + Vector2(glass.size.x * 0.1, 0), glass.position + Vector2(glass.size.x * 0.24, 0), glass.position + Vector2(glass.size.x * 0.08, glass.size.y), glass.position + Vector2(-glass.size.x * 0.04 + 6, glass.size.y)]), Color(1, 1, 1, 0.2))
	# Window sill.
	RenoArt.box(ci, Rect2(-s.x * 0.06, s.y * 0.88, s.x * 1.12, s.y * 0.1), base.darkened(0.12), 4)
	if broken:
		# Boarded up, one pane cracked.
		for k in 2:
			var y := glass.position.y + glass.size.y * (0.3 + k * 0.35)
			var plank := PackedVector2Array([Vector2(-10, y - 18 + k * 20), Vector2(s.x + 10, y - 30 + k * 30), Vector2(s.x + 10, y + 8 + k * 30), Vector2(-10, y + 20 + k * 20)])
			RenoArt.shape(ci, plank, Color("8d7a62"), 4.0)
			ci.draw_circle(plank[0] + Vector2(24, 18), 4, Color("3c3026"), true, -1.0, true)
			ci.draw_circle(plank[1] + Vector2(-24, 18), 4, Color("3c3026"), true, -1.0, true)
		var c := glass.position + glass.size * Vector2(0.72, 0.2)
		for k in 6:
			var a := TAU * k / 6.0 + 0.4
			ci.draw_line(c, c + Vector2(cos(a), sin(a)) * 50, Color(1, 1, 1, 0.7), 2.0, true)


func _shelf(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	# Back panel, sides and three shelves full of candy jars.
	RenoArt.pattern_rect(ci, Rect2(0, 0, s.x, s.y), pattern, base.darkened(0.25), accent)
	DrawKit.outline(ci, RenoArt.rect_pts(Rect2(0, 0, s.x, s.y)), RenoArt.ol(base), 6.0)
	var rows := 3
	for k in rows:
		var y := s.y * (0.33 + k * 0.32)
		var tilt := 24.0 if broken and k == 1 else 0.0
		var plank := PackedVector2Array([Vector2(-14, y - 12), Vector2(s.x + 14, y - 12 + tilt), Vector2(s.x + 14, y + 12 + tilt), Vector2(-14, y + 12)])
		RenoArt.shape(ci, plank, base, 4.0)
		var n := int(s.x / 95.0)
		for i in n:
			var x := 40.0 + i * (s.x - 80.0) / maxf(1.0, n - 1)
			var fall := broken and (i + k) % 3 == 0
			var jy := y - 12 + tilt * (x / s.x)
			_mini_jar(ci, Vector2(x, jy), 58.0, (i * 3 + k * 5) % 12, broken, fall)
	RenoArt.box(ci, Rect2(-22, -16, s.x + 44, 30), base.lightened(0.05), 6)


func _rack(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	# Tall storage shelves with boxes and tins.
	for x in [0.0, s.x - 30.0]:
		RenoArt.box(ci, Rect2(x, 0, 30, s.y), base, 4)
	for k in 4:
		var y := s.y * (0.22 + k * 0.25)
		var tilt := 30.0 if broken and k == 2 else 0.0
		RenoArt.shape(ci, PackedVector2Array([Vector2(0, y), Vector2(s.x, y + tilt), Vector2(s.x, y + 22 + tilt), Vector2(0, y + 22)]), base.lightened(0.05), 4.0)
		var x := 50.0
		var i := 0
		while x < s.x - 90:
			var bw := 70.0 + (i * 37 % 40)
			var bh := 80.0 + (i * 23 % 50)
			var c: Color = [Color("e0a458"), Color("c8553d"), Color("588b8b"), Color("f2d0a4")][(i + k) % 4]
			if broken:
				c = RenoArt.grime(c)
			var by := y - bh + tilt * (x / s.x)
			RenoArt.box(ci, Rect2(x, by, bw, bh), c, 6, 4.0)
			if not broken:
				RenoArt.pattern_rect(ci, Rect2(x + 10, by + bh * 0.35, bw - 20, bh * 0.3), pattern, c.lightened(0.2), accent, 3)
			x += bw + 18
			i += 1


func _counter(ci: CanvasItem, s: Vector2, base: Color, accent: Color, trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	var top := Rect2(-24, 0, s.x + 48, 54)
	var front := Rect2(0, 44, s.x, s.y - 44)
	RenoArt.soft_shadow(ci, Vector2(s.x * 0.5, s.y), s.x * 0.55, 36)
	RenoArt.pattern_rect(ci, front, pattern, base, accent)
	DrawKit.outline(ci, RenoArt.rect_pts(front), RenoArt.ol(base), 6.0)
	# Glass display window in the counter front.
	if true:
		var gl := Rect2(s.x * 0.06, s.y * 0.26, s.x * 0.36, s.y * 0.42)
		ci.draw_colored_polygon(RenoArt.rect_pts(gl, 8), Color(0.85, 0.95, 1.0, 0.55) if not broken else Color(0.5, 0.5, 0.45, 0.6))
		DrawKit.outline(ci, RenoArt.rect_pts(gl, 8), trim, 5.0)
		for i in 5:
			CandyArt.draw_candy(ci, gl.position + Vector2(40 + i * (gl.size.x - 80) / 4.0, gl.size.y * 0.66), 54, (i * 2 + 1) % 12)
		ci.draw_colored_polygon(PackedVector2Array([gl.position + Vector2(20, 6), gl.position + Vector2(60, 6), gl.position + Vector2(20, gl.size.y - 6)]), Color(1, 1, 1, 0.3))
	RenoArt.box(ci, top, trim if not broken else base.darkened(0.1), 10)
	ci.draw_rect(Rect2(-14, 8, s.x + 28, 10), Color(1, 1, 1, 0.22))
	if broken:
		# A missing plank and a chipped corner.
		ci.draw_colored_polygon(PackedVector2Array([Vector2(s.x * 0.62, 60), Vector2(s.x * 0.74, 60), Vector2(s.x * 0.72, s.y - 20), Vector2(s.x * 0.6, s.y - 20)]), Color(0.18, 0.12, 0.08, 0.85))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(s.x + 24, 0), Vector2(s.x - 40, 0), Vector2(s.x + 24, 40)]), Color(0.25, 0.2, 0.18))


func _counter_jars(ci: CanvasItem, s: Vector2, _b: Color, _a: Color, _tr: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	var n := 5
	for i in n:
		var x := s.x * (0.1 + 0.8 * i / float(n - 1))
		_mini_jar(ci, Vector2(x, s.y), s.y * 0.48, (i * 5 + 2) % 12, broken, broken and i % 2 == 0, pattern)


func _mini_jar(ci: CanvasItem, bottom: Vector2, w: float, candy: int, broken: bool, fallen: bool, pattern: String = "") -> void:
	var h := w * 1.35
	if fallen:
		# Knocked over on its side, candies spilled.
		var r := Rect2(bottom.x - h * 0.5, bottom.y - w * 0.95, h, w * 0.9)
		ci.draw_colored_polygon(RenoArt.rect_pts(r, w * 0.3), Color(0.8, 0.85, 0.85, 0.45))
		DrawKit.outline(ci, RenoArt.rect_pts(r, w * 0.3), Color(0.4, 0.42, 0.42, 0.8), 3.0)
		for k in 3:
			CandyArt.draw_candy(ci, bottom + Vector2(-h * 0.2 + k * w * 0.4, -w * 0.25), w * 0.42, (candy + k) % 12)
		return
	var r := Rect2(bottom.x - w * 0.5, bottom.y - h, w, h)
	var glass := Color(0.85, 0.95, 0.97, 0.5) if not broken else Color(0.6, 0.6, 0.55, 0.6)
	ci.draw_colored_polygon(RenoArt.rect_pts(r, w * 0.25), glass)
	if not broken:
		for k in 3:
			CandyArt.draw_candy(ci, Vector2(bottom.x, bottom.y - w * 0.32 - k * w * 0.36), w * 0.5, candy)
	DrawKit.outline(ci, RenoArt.rect_pts(r, w * 0.25), Color(0.35, 0.45, 0.47, 0.9), 3.0)
	var lid := GameData.candy_color(candy) if not broken else Color("8a8178")
	RenoArt.box(ci, Rect2(r.position.x - 3, r.position.y - w * 0.16, w + 6, w * 0.22), lid, 5, 3.0)
	ci.draw_rect(Rect2(r.position.x + w * 0.16, r.position.y + w * 0.12, w * 0.1, h * 0.6), Color(1, 1, 1, 0.35))


func _pendant_lamp(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, night: bool) -> void:
	var cx := s.x * 0.5
	var cord_end := s.y * 0.55
	ci.draw_line(Vector2(cx, 0), Vector2(cx + (24 if broken else 0), cord_end), Color("2b2016"), 5.0, true)
	var shade_c := Vector2(cx + (24 if broken else 0), cord_end)
	var shade := PackedVector2Array([shade_c + Vector2(-s.x * 0.18, 0), shade_c + Vector2(s.x * 0.18, 0), shade_c + Vector2(s.x * 0.48, s.y * 0.3), shade_c + Vector2(-s.x * 0.48, s.y * 0.3)])
	if broken:
		# A bare bulb hanging crooked; no shade.
		ci.draw_circle(shade_c + Vector2(0, 30), 26, Color("cfc7b0"), true, -1.0, true)
		DrawKit.outline(ci, DrawKit.ellipse(shade_c + Vector2(0, 30), 26, 26, 20), Color("6c6656"), 3.0)
		return
	if night:
		for k in 4:
			ci.draw_colored_polygon(DrawKit.ellipse(shade_c + Vector2(0, s.y * 0.38), 120.0 - k * 22.0, 80.0 - k * 14.0, 28), Color(1.0, 0.85, 0.4, 0.07))
	ci.draw_colored_polygon(shade, base)
	RenoArt.pattern_rect(ci, Rect2(shade_c.x - s.x * 0.32, shade_c.y + s.y * 0.08, s.x * 0.64, s.y * 0.12), pattern, base, accent)
	DrawKit.outline(ci, shade, RenoArt.ol(base), 4.0)
	ci.draw_circle(shade_c + Vector2(0, s.y * 0.32), s.x * 0.14, Color("fff2b0"), true, -1.0, true)


func _wall_sign(ci: CanvasItem, s: Vector2, base: Color, accent: Color, trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	var tilt := 0.06 if broken else 0.0
	ci.draw_set_transform_matrix(RenoArt._base * Transform2D(tilt, Vector2(s.x * 0.5, s.y * 0.5)))
	var r := Rect2(-s.x * 0.5, -s.y * 0.5, s.x, s.y)
	ci.draw_line(Vector2(-s.x * 0.3, -s.y * 0.5), Vector2(0, -s.y * 0.95), Color("3a2a1c"), 4.0, true)
	ci.draw_line(Vector2(s.x * 0.3, -s.y * 0.5), Vector2(0, -s.y * 0.95), Color("3a2a1c"), 4.0, true)
	RenoArt.pattern_rect(ci, r, pattern, base, accent, 18)
	DrawKit.outline(ci, RenoArt.rect_pts(r, 18), trim, 8.0)
	var text := "HAJURAMA'S PASAL" if not broken else "H J R M   P S L"
	var f := UIKit.font(true)
	var fs := int(s.y * 0.42)
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while tw > s.x * 0.88 and fs > 12:
		fs -= 2
		tw = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tc := accent.lightened(0.6) if not broken else Color(0.85, 0.8, 0.7, 0.6)
	ci.draw_string_outline(f, Vector2(-tw * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, RenoArt.ol(base))
	ci.draw_string(f, Vector2(-tw * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
	ci.draw_set_transform_matrix(RenoArt._base)


func _sign_board(ci: CanvasItem, s: Vector2, base: Color, accent: Color, trim: Color, pattern: String, broken: bool, t: float, n: bool) -> void:
	_wall_sign(ci, s, base, accent, trim, pattern, broken, t, n)


func _cash_box(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	RenoArt.soft_shadow(ci, Vector2(s.x * 0.5, s.y), s.x * 0.5, 12)
	var body := Rect2(0, s.y * 0.3, s.x, s.y * 0.7)
	RenoArt.pattern_rect(ci, body, pattern, base, accent, 10)
	DrawKit.outline(ci, RenoArt.rect_pts(body, 10), RenoArt.ol(base), 5.0)
	var lid := PackedVector2Array([Vector2(-6, s.y * 0.32), Vector2(s.x + 6, s.y * 0.32), Vector2(s.x - 10, 0), Vector2(10, 0)])
	if broken:
		lid = PackedVector2Array([Vector2(-6, s.y * 0.32), Vector2(s.x + 6, s.y * 0.32), Vector2(s.x + 30, -s.y * 0.1), Vector2(30, -s.y * 0.25)])
	RenoArt.shape(ci, lid, base.lightened(0.08), 5.0)
	ci.draw_circle(Vector2(s.x * 0.5, s.y * 0.58), s.y * 0.12, accent, true, -1.0, true)
	ci.draw_rect(Rect2(s.x * 0.5 - 3, s.y * 0.56, 6, s.y * 0.1), RenoArt.ol(accent))


func _scale(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, _pattern: String, broken: bool, _t: float, _n: bool) -> void:
	RenoArt.soft_shadow(ci, Vector2(s.x * 0.5, s.y), s.x * 0.45, 12)
	var metal := base
	RenoArt.box(ci, Rect2(s.x * 0.3, s.y * 0.82, s.x * 0.4, s.y * 0.18), metal.darkened(0.15), 6)
	ci.draw_line(Vector2(s.x * 0.5, s.y * 0.82), Vector2(s.x * 0.5, s.y * 0.15), metal.darkened(0.3), 10.0, true)
	var tilt := 0.18 if broken else 0.0
	var l := Vector2(s.x * 0.1, s.y * 0.2 + tilt * 100)
	var r := Vector2(s.x * 0.9, s.y * 0.2 - tilt * 100)
	ci.draw_line(l, r, metal.darkened(0.2), 9.0, true)
	for p in [l, r]:
		ci.draw_line(p, p + Vector2(-30, 70), metal.darkened(0.3), 3.0, true)
		ci.draw_line(p, p + Vector2(30, 70), metal.darkened(0.3), 3.0, true)
		var pan := DrawKit.ellipse(p + Vector2(0, 74), 46, 14, 20)
		RenoArt.shape(ci, pan, metal, 4.0)
		ci.draw_colored_polygon(DrawKit.ellipse(p + Vector2(-12, 70), 16, 4, 10), Color(1, 1, 1, 0.45))
	ci.draw_circle(Vector2(s.x * 0.5, s.y * 0.15), 14, accent, true, -1.0, true)


func _basket(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	RenoArt.soft_shadow(ci, Vector2(s.x * 0.5, s.y), s.x * 0.52, 18)
	var body := PackedVector2Array([Vector2(0, s.y * 0.3), Vector2(s.x, s.y * 0.3), Vector2(s.x * 0.9, s.y), Vector2(s.x * 0.1, s.y)])
	ci.draw_colored_polygon(body, base)
	if not broken:
		# Woven texture.
		for k in 5:
			var y := s.y * (0.38 + k * 0.13)
			ci.draw_line(Vector2(s.x * 0.05 + k * 4, y), Vector2(s.x * 0.95 - k * 4, y), base.darkened(0.25), 4.0)
		RenoArt.pattern_rect(ci, Rect2(s.x * 0.18, s.y * 0.05, s.x * 0.64, s.y * 0.3), pattern if pattern != "plain" else "dhaka", accent, base.lightened(0.3), 20)
	else:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(s.x * 0.6, s.y * 0.3), Vector2(s.x * 0.8, s.y * 0.3), Vector2(s.x * 0.72, s.y * 0.6)]), Color(0.2, 0.15, 0.1))
	DrawKit.outline(ci, body, RenoArt.ol(base), 5.0)
	RenoArt.box(ci, Rect2(-8, s.y * 0.24, s.x + 16, s.y * 0.14), base.lightened(0.1), 12)


func _garland(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, _pattern: String, broken: bool, t: float, _n: bool) -> void:
	var n := maxi(8, int(s.x / 34.0))
	for k in n:
		var u := k / float(n - 1)
		var sag := sin(u * PI) * s.y * 0.6
		var p := Vector2(u * s.x, s.y * 0.2 + sag + sin(t * 1.5 + k) * 1.5)
		var c := base if k % 3 != 2 else accent
		if broken:
			if k % 2 == 0:
				continue
			p.y += s.y * 0.2
		ci.draw_circle(p, 17, c.darkened(0.25), true, -1.0, true)
		ci.draw_circle(p + Vector2(0, -2), 14, c, true, -1.0, true)
		ci.draw_circle(p + Vector2(-4, -6), 4, Color(1, 1, 1, 0.4), true, -1.0, true)
	if not broken:
		for k in 3:
			var x := s.x * (0.2 + k * 0.3)
			var y := s.y * 0.2 + sin(x / s.x * PI) * s.y * 0.6
			for j in 3:
				ci.draw_circle(Vector2(x, y + 22 + j * 22), 11, accent if j % 2 == 0 else base, true, -1.0, true)


func _stool(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	RenoArt.soft_shadow(ci, Vector2(s.x * 0.5, s.y), s.x * 0.5, 14)
	var leg_w := s.x * 0.12
	for x in [s.x * 0.12, s.x * 0.76]:
		var lean := 0.0
		if broken and x > s.x * 0.5:
			lean = 18.0
		RenoArt.shape(ci, PackedVector2Array([Vector2(x, s.y * 0.3), Vector2(x + leg_w, s.y * 0.3), Vector2(x + leg_w + lean, s.y), Vector2(x + lean, s.y)]), base.darkened(0.12), 4.0)
	RenoArt.box(ci, Rect2(s.x * 0.12, s.y * 0.6, s.x * 0.76, s.y * 0.06), base.darkened(0.2), 3, 3.0)
	var seat := Rect2(0, s.y * 0.2, s.x, s.y * 0.16)
	RenoArt.pattern_rect(ci, seat, pattern, base, accent, 10)
	DrawKit.outline(ci, RenoArt.rect_pts(seat, 10), RenoArt.ol(base), 4.0)
	if not broken and pattern != "steel":
		RenoArt.pattern_rect(ci, Rect2(s.x * 0.08, s.y * 0.08, s.x * 0.84, s.y * 0.14), "dhaka", accent, base, 14)


func _shutter(ci: CanvasItem, s: Vector2, base: Color, accent: Color, trim: Color, pattern: String, broken: bool, _t: float, night: bool) -> void:
	# Open shutter: rolled up at the top, the shop inside visible below.
	var inside := Rect2(0, s.y * 0.18, s.x, s.y * 0.82)
	DrawKit.gradient_fill(ci, RenoArt.rect_pts(inside), Color("ffe3a8") if not broken else Color("4a4038"), Color("d79a5a") if not broken else Color("2f2822"))
	if broken:
		# Rusty half-closed shutter.
		var down := Rect2(0, 0, s.x, s.y * 0.78)
		RenoArt.pattern_rect(ci, down, "plain", base, accent)
		for k in int(down.size.y / 22.0):
			ci.draw_line(Vector2(0, k * 22), Vector2(s.x, k * 22), base.darkened(0.3), 3.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 31
		for k in 14:
			ci.draw_colored_polygon(DrawKit.blob(Vector2(rng.randf() * s.x, rng.randf() * down.size.y), rng.randf_range(16, 40), rng.randf_range(8, 20), 4, 0.3, 14), Color("8a4b2a").lerp(RenoArt.GRIME, 0.3))
		DrawKit.outline(ci, RenoArt.rect_pts(down), RenoArt.ol(base), 5.0)
		return
	# Shelves inside with jars, warm light.
	for k in 2:
		var y := inside.position.y + inside.size.y * (0.35 + k * 0.32)
		ci.draw_rect(Rect2(20, y, s.x - 40, 14), Color("8b5a2b"))
		for i in int((s.x - 80) / 80.0):
			_mini_jar(ci, Vector2(60 + i * 80, y), 46, (i + k * 3) % 12, false, false)
	if night:
		ci.draw_colored_polygon(RenoArt.rect_pts(inside), Color(1.0, 0.8, 0.4, 0.15))
	var roll := Rect2(-10, 0, s.x + 20, s.y * 0.2)
	RenoArt.pattern_rect(ci, roll, pattern, base, accent, 14)
	for k in 4:
		ci.draw_line(Vector2(0, 12 + k * roll.size.y * 0.22), Vector2(s.x, 12 + k * roll.size.y * 0.22), base.darkened(0.25), 3.0)
	DrawKit.outline(ci, RenoArt.rect_pts(roll, 14), RenoArt.ol(base), 5.0)
	for x in [0.0, s.x - 18.0]:
		RenoArt.box(ci, Rect2(x, s.y * 0.15, 18, s.y * 0.85), trim, 3, 3.0)


func _awning(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, t: float, _n: bool) -> void:
	var stripes := 10
	var sw := s.x / stripes
	for k in stripes:
		if broken and k in [3, 4, 8]:
			continue
		var c := base if k % 2 == 0 else accent
		if pattern == "dhaka" and k % 2 == 1:
			c = accent
		var x := k * sw
		var flap := sin(t * 2.0 + k) * 2.0
		var poly := PackedVector2Array([Vector2(x, 0), Vector2(x + sw, 0), Vector2(x + sw, s.y * 0.72), Vector2(x, s.y * 0.72)])
		ci.draw_colored_polygon(poly, c)
		var scallop := DrawKit.ellipse(Vector2(x + sw * 0.5, s.y * 0.72 + flap), sw * 0.5, s.y * 0.22, 14)
		var half := PackedVector2Array()
		for p in scallop:
			if p.y >= s.y * 0.72 + flap - 0.5:
				half.append(p)
		if half.size() >= 3:
			ci.draw_colored_polygon(half, c)
		if pattern == "dhaka" and not broken:
			RenoArt.pattern_rect(ci, Rect2(x + 4, s.y * 0.1, sw - 8, s.y * 0.5), "dhaka", c, base, 4)
	ci.draw_rect(Rect2(0, 0, s.x, 14), Color(0, 0, 0, 0.25))
	DrawKit.outline(ci, RenoArt.rect_pts(Rect2(0, 0, s.x, s.y * 0.72)), RenoArt.ol(base), 4.0)
	if broken:
		ci.draw_line(Vector2(s.x * 0.35, 0), Vector2(s.x * 0.38, s.y * 0.9), Color("5b4a3a"), 5.0)


func _steps(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	var n := 3
	for k in n:
		var inset := k * s.x * 0.06
		var r := Rect2(inset, s.y * (k / float(n)), s.x - inset * 2, s.y / n)
		r = Rect2(inset, s.y - (k + 1) * s.y / n, s.x - inset * 2, s.y / n)
		RenoArt.pattern_rect(ci, r, pattern, base.darkened(0.06 * k), accent)
		DrawKit.outline(ci, RenoArt.rect_pts(r), RenoArt.ol(base), 4.0)
		ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 6), Color(1, 1, 1, 0.25))
	if broken:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(s.x * 0.7, s.y * 0.34), Vector2(s.x * 0.9, s.y * 0.34), Vector2(s.x * 0.84, s.y * 0.6)]), Color(0.2, 0.16, 0.12))


func _plant_pot(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, t: float, _n: bool) -> void:
	RenoArt.soft_shadow(ci, Vector2(s.x * 0.5, s.y), s.x * 0.45, 12)
	var pot := PackedVector2Array([Vector2(s.x * 0.1, s.y * 0.58), Vector2(s.x * 0.9, s.y * 0.58), Vector2(s.x * 0.76, s.y), Vector2(s.x * 0.24, s.y)])
	ci.draw_colored_polygon(pot, base)
	if not broken:
		RenoArt.pattern_rect(ci, Rect2(s.x * 0.22, s.y * 0.66, s.x * 0.56, s.y * 0.14), pattern, base, accent)
	DrawKit.outline(ci, pot, RenoArt.ol(base), 4.0)
	RenoArt.box(ci, Rect2(s.x * 0.04, s.y * 0.54, s.x * 0.92, s.y * 0.08), base.lightened(0.1), 6, 4.0)
	if broken:
		ci.draw_line(Vector2(s.x * 0.5, s.y * 0.55), Vector2(s.x * 0.62, s.y * 0.3), Color("6e5a3c"), 5.0)
		ci.draw_line(Vector2(s.x * 0.62, s.y * 0.3), Vector2(s.x * 0.72, s.y * 0.42), Color("6e5a3c"), 4.0)
		return
	var sway := sin(t * 1.3) * 3.0
	for k in 7:
		var a := -PI * 0.5 + (k - 3) * 0.32
		var tip := Vector2(s.x * 0.5, s.y * 0.55) + Vector2(cos(a), sin(a)) * s.y * 0.45 + Vector2(sway, 0)
		DrawKit.capsule(ci, Vector2(s.x * 0.5, s.y * 0.55), tip, 5, Color("3f8f3a"))
		ci.draw_colored_polygon(DrawKit.ellipse(tip, 16, 9, 12), Color("4fae45"))
	for k in 3:
		var p := Vector2(s.x * (0.32 + k * 0.18), s.y * (0.16 + (k % 2) * 0.1))
		_flower_static(ci, p + Vector2(sway, 0), 16, Color("ff9f1c"))


static func _flower_static(ci: CanvasItem, c: Vector2, r: float, petal: Color) -> void:
	for k in 8:
		var a := TAU * k / 8.0
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.55, r * 0.42, petal, true, -1.0, true)
	ci.draw_circle(c, r * 0.35, petal.darkened(0.25), true, -1.0, true)


func _street_lamp(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, night: bool) -> void:
	var cx := s.x * 0.5
	RenoArt.box(ci, Rect2(cx - 30, s.y - 40, 60, 40), base.darkened(0.15), 6)
	var lean := 30.0 if broken else 0.0
	RenoArt.shape(ci, PackedVector2Array([Vector2(cx - 10, s.y - 40), Vector2(cx + 10, s.y - 40), Vector2(cx + 10 + lean, s.y * 0.22), Vector2(cx - 10 + lean, s.y * 0.22)]), base, 4.0)
	var head := Rect2(cx - 44 + lean, s.y * 0.06, 88, s.y * 0.17)
	if night and not broken:
		for k in 5:
			ci.draw_colored_polygon(DrawKit.ellipse(head.get_center(), 160.0 - k * 28.0, 160.0 - k * 28.0, 30), Color(1.0, 0.86, 0.45, 0.06))
	ci.draw_colored_polygon(RenoArt.rect_pts(head, 10), Color("fff0a8") if not broken else Color("5c574d"))
	if not broken and pattern in ["carved", "gold", "painted"]:
		DrawKit.outline(ci, RenoArt.rect_pts(head.grow(-10), 6), accent, 4.0)
	DrawKit.outline(ci, RenoArt.rect_pts(head, 10), RenoArt.ol(base), 6.0)
	ci.draw_colored_polygon(PackedVector2Array([head.position + Vector2(-16, 0), head.position + Vector2(head.size.x + 16, 0), head.position + Vector2(head.size.x * 0.5, -40)]), base)
	if broken:
		ci.draw_line(head.position + Vector2(20, 20), head.position + Vector2(60, 70), Color(1, 1, 1, 0.5), 3.0)


func _bench(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	RenoArt.soft_shadow(ci, Vector2(s.x * 0.5, s.y), s.x * 0.5, 16)
	for x in [s.x * 0.08, s.x * 0.84]:
		RenoArt.box(ci, Rect2(x, s.y * 0.45, s.x * 0.08, s.y * 0.55), base.darkened(0.2), 4, 4.0)
	var seat := Rect2(0, s.y * 0.42, s.x, s.y * 0.14)
	if broken:
		RenoArt.shape(ci, PackedVector2Array([Vector2(0, s.y * 0.42), Vector2(s.x * 0.55, s.y * 0.42), Vector2(s.x * 0.5, s.y * 0.56), Vector2(0, s.y * 0.56)]), base, 4.0)
		RenoArt.shape(ci, PackedVector2Array([Vector2(s.x * 0.62, s.y * 0.5), Vector2(s.x, s.y * 0.44), Vector2(s.x, s.y * 0.58), Vector2(s.x * 0.6, s.y * 0.64)]), base, 4.0)
		return
	RenoArt.pattern_rect(ci, seat, pattern, base, accent, 8)
	DrawKit.outline(ci, RenoArt.rect_pts(seat, 8), RenoArt.ol(base), 4.0)
	var back := Rect2(s.x * 0.02, 0, s.x * 0.96, s.y * 0.3)
	RenoArt.pattern_rect(ci, back, pattern, base.lightened(0.05), accent, 10)
	DrawKit.outline(ci, RenoArt.rect_pts(back, 10), RenoArt.ol(base), 4.0)
	for x in [s.x * 0.1, s.x * 0.86]:
		ci.draw_rect(Rect2(x, s.y * 0.28, 16, s.y * 0.16), base.darkened(0.2))


func _string_lights(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, _pattern: String, broken: bool, t: float, night: bool) -> void:
	var pts := PackedVector2Array()
	var n := 32
	for k in n + 1:
		var u := k / float(n)
		pts.append(Vector2(u * s.x, s.y * 0.15 + sin(u * PI * 3.0) * s.y * 0.35 + s.y * 0.35))
	ci.draw_polyline(pts, Color("2b2016"), 3.0, true)
	var bulbs := maxi(6, int(s.x / 70.0))
	for k in bulbs:
		var u := (k + 0.5) / bulbs
		var p := Vector2(u * s.x, s.y * 0.15 + sin(u * PI * 3.0) * s.y * 0.35 + s.y * 0.35 + 12)
		var on := not broken or k % 4 == 0
		var c: Color = [base, accent, Color("ff6b8b"), Color("8fd3ff")][k % 4]
		if broken:
			c = RenoArt.grime(c)
		var tw := 0.75 + 0.25 * sin(t * 3.0 + k * 1.7)
		if on and night:
			ci.draw_circle(p, 26, Color(c, 0.18 * tw), true, -1.0, true)
		ci.draw_circle(p, 10, c if on else Color("6b6358"), true, -1.0, true)
		ci.draw_circle(p + Vector2(-3, -3), 3, Color(1, 1, 1, 0.6), true, -1.0, true)


func _bicycle(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, _pattern: String, broken: bool, _t: float, _n: bool) -> void:
	RenoArt.soft_shadow(ci, Vector2(s.x * 0.5, s.y), s.x * 0.5, 14)
	var r := s.y * 0.3
	var w1 := Vector2(s.x * 0.22, s.y - r)
	var w2 := Vector2(s.x * 0.78, s.y - r)
	for w in [w1, w2]:
		ci.draw_arc(w, r, 0, TAU, 32, Color("2b2b2b"), 9.0, true)
		ci.draw_arc(w, r * 0.85, 0, TAU, 32, Color("8c8c8c"), 2.0, true)
		if broken and w == w2:
			ci.draw_arc(w, r, 0.4, 1.4, 10, Color("8a7a66"), 12.0, true)
	var seat := Vector2(s.x * 0.38, s.y * 0.32)
	var bar := Vector2(s.x * 0.7, s.y * 0.26)
	var crank := Vector2(s.x * 0.46, s.y - r)
	for seg in [[w1, crank], [crank, seat], [seat, w1], [crank, bar], [seat, bar], [bar, w2]]:
		ci.draw_line(seg[0], seg[1], base, 9.0, true)
	RenoArt.box(ci, Rect2(seat + Vector2(-34, -16), Vector2(68, 18)), Color("3a2a1c"), 8, 3.0)
	ci.draw_line(bar, bar + Vector2(30, -40), base.darkened(0.2), 7.0, true)
	ci.draw_line(bar + Vector2(10, -40), bar + Vector2(50, -40), Color("2b2b2b"), 8.0, true)
	if not broken:
		# A basket of goods on the front.
		RenoArt.box(ci, Rect2(bar + Vector2(30, -30), Vector2(90, 60)), accent, 8, 4.0)
		ci.draw_circle(bar + Vector2(60, -34), 14, Color("ff9f1c"), true, -1.0, true)
		ci.draw_circle(bar + Vector2(90, -32), 12, Color("5fd02c"), true, -1.0, true)


func _ceiling_fan(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, _pattern: String, broken: bool, t: float, _n: bool) -> void:
	var c := Vector2(s.x * 0.5, s.y * 0.6)
	ci.draw_line(Vector2(s.x * 0.5, 0), c, Color("3a2a1c"), 8.0)
	var spin := 0.0 if broken else t * 6.0
	for k in 3:
		var a := spin + TAU * k / 3.0
		var droop := 0.25 if broken and k == 1 else 0.0
		var tip := c + Vector2(cos(a), sin(a) * 0.28 + droop) * s.x * 0.48
		var blade := PackedVector2Array([c + Vector2(cos(a + 1.4), sin(a + 1.4) * 0.28) * 14, tip + Vector2(cos(a + 1.57), sin(a + 1.57) * 0.28) * 24, tip, c])
		RenoArt.shape(ci, blade, base, 3.0)
	ci.draw_circle(c, 22, accent, true, -1.0, true)
	ci.draw_circle(c, 22, RenoArt.ol(accent), false, 3.0, true)


func _cabinet(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	RenoArt.soft_shadow(ci, Vector2(s.x * 0.5, s.y), s.x * 0.5, 14)
	var r := Rect2(0, 0, s.x, s.y)
	RenoArt.pattern_rect(ci, r, pattern, base, accent, 8)
	DrawKit.outline(ci, RenoArt.rect_pts(r, 8), RenoArt.ol(base), 6.0)
	var rows := 4
	for k in rows:
		var dr := Rect2(s.x * 0.08, s.y * (0.06 + k * 0.235), s.x * 0.84, s.y * 0.2)
		if broken and k == 2:
			dr.position.x += 30
		ci.draw_colored_polygon(RenoArt.rect_pts(dr, 6), Color(0, 0, 0, 0.12))
		DrawKit.outline(ci, RenoArt.rect_pts(dr, 6), RenoArt.ol(base), 4.0)
		RenoArt.box(ci, Rect2(dr.get_center() - Vector2(26, 7), Vector2(52, 14)), accent, 7, 3.0)


func _sacks(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	RenoArt.soft_shadow(ci, Vector2(s.x * 0.5, s.y), s.x * 0.55, 18)
	var spots := [[0.25, 0.68], [0.6, 0.7], [0.42, 0.3]] if not broken else [[0.2, 0.75], [0.62, 0.78], [0.86, 0.6]]
	for i in spots.size():
		var c := Vector2(s.x * spots[i][0], s.y * spots[i][1])
		var sack := DrawKit.blob(c, s.x * 0.2, s.y * 0.3, 3, 0.08, 30)
		if broken and i == 2:
			sack = DrawKit.blob(c, s.x * 0.18, s.y * 0.18, 3, 0.15, 30)
		RenoArt.shape(ci, sack, base, 4.0)
		if not broken:
			RenoArt.pattern_rect(ci, Rect2(c.x - s.x * 0.1, c.y - s.y * 0.06, s.x * 0.2, s.y * 0.1), pattern, base, accent, 6)
		ci.draw_line(c + Vector2(-20, -s.y * 0.26), c + Vector2(20, -s.y * 0.26), base.darkened(0.4), 5.0)
	if broken:
		for k in 16:
			ci.draw_circle(Vector2(s.x * (0.7 + 0.015 * k), s.y * 0.95 - (k % 4) * 6), 4, Color("e8dcc0"), true, -1.0, true)


func _ladder(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, _pattern: String, broken: bool, _t: float, _n: bool) -> void:
	var lx := s.x * 0.15
	var rx := s.x * 0.85
	RenoArt.box(ci, Rect2(lx - 14, 0, 28, s.y), base, 6, 4.0)
	RenoArt.box(ci, Rect2(rx - 14, 0, 28, s.y), base, 6, 4.0)
	var n := 6
	for k in n:
		if broken and k in [2, 4]:
			ci.draw_line(Vector2(lx, s.y * (0.1 + k * 0.15)), Vector2(lx + 40, s.y * (0.1 + k * 0.15) + 30), base, 12.0)
			continue
		var y := s.y * (0.1 + k * 0.15)
		RenoArt.box(ci, Rect2(lx, y, rx - lx, 18), accent if k % 2 == 0 else base.lightened(0.1), 4, 3.0)


func _crates(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	RenoArt.soft_shadow(ci, Vector2(s.x * 0.5, s.y), s.x * 0.55, 16)
	var cs := s.y * 0.5
	var spots := [Vector2(0, s.y - cs), Vector2(cs * 1.05, s.y - cs), Vector2(cs * 0.5, s.y - cs * 2.0)]
	if broken:
		spots = [Vector2(0, s.y - cs), Vector2(cs * 1.3, s.y - cs * 0.8), Vector2(cs * 0.4, s.y - cs * 1.6)]
	for i in spots.size():
		var r := Rect2(spots[i], Vector2(cs, cs * (0.8 if broken and i == 1 else 1.0)))
		RenoArt.pattern_rect(ci, r, pattern if pattern != "plain" else "planks", base, accent, 4)
		DrawKit.outline(ci, RenoArt.rect_pts(r, 4), RenoArt.ol(base), 5.0)
		ci.draw_line(r.position + Vector2(8, 8), r.end - Vector2(8, 8), base.darkened(0.3), 6.0)
		if not broken:
			RenoArt.box(ci, Rect2(r.get_center() - Vector2(30, 14), Vector2(60, 28)), accent, 6, 3.0)


func _curtain(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, t: float, _n: bool) -> void:
	ci.draw_line(Vector2(-10, 8), Vector2(s.x + 10, 8), Color("5a3a20"), 10.0, true)
	for side in [0, 1]:
		var x0 := 0.0 if side == 0 else s.x * 0.62
		var w := s.x * 0.38
		var sway := sin(t * 0.9 + side) * 4.0
		var pts := PackedVector2Array([Vector2(x0, 10), Vector2(x0 + w, 10), Vector2(x0 + w + (sway if side == 0 else -w * 0.3), s.y), Vector2(x0 + (w * 0.3 if side == 0 else sway), s.y)])
		if broken:
			pts = PackedVector2Array([Vector2(x0, 10), Vector2(x0 + w, 10), Vector2(x0 + w * 0.8, s.y * 0.6), Vector2(x0 + w * 0.2, s.y * 0.7)])
		ci.draw_colored_polygon(pts, base)
		if not broken:
			RenoArt.pattern_rect(ci, Rect2(x0 + 8, s.y * 0.2, w - 16, s.y * 0.5), pattern, base, accent)
		for k in 3:
			ci.draw_line(Vector2(x0 + w * (0.25 + k * 0.25), 12), Vector2(x0 + w * (0.25 + k * 0.25) + sway, s.y * 0.9), base.darkened(0.2), 3.0, true)
		DrawKit.outline(ci, pts, RenoArt.ol(base), 4.0)


func _wall_clock(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, t: float, _n: bool) -> void:
	var c := s * 0.5
	var r := minf(s.x, s.y) * 0.46
	ci.draw_circle(c, r, RenoArt.ol(base), true, -1.0, true)
	ci.draw_circle(c, r - 6, base, true, -1.0, true)
	if pattern in ["carved", "gold", "painted"] and not broken:
		for k in 12:
			var a := TAU * k / 12.0
			ci.draw_circle(c + Vector2(cos(a), sin(a)) * (r - 16), 6, accent, true, -1.0, true)
	ci.draw_circle(c, r * 0.72, Color("fff8e6") if not broken else Color("bdb2a0"), true, -1.0, true)
	var hour := 0.0 if broken else t * 0.02
	var minute := 1.2 if broken else t * 0.25
	ci.draw_line(c, c + Vector2(cos(hour - PI * 0.5), sin(hour - PI * 0.5)) * r * 0.4, Color("2b2016"), 7.0, true)
	ci.draw_line(c, c + Vector2(cos(minute - PI * 0.5), sin(minute - PI * 0.5)) * r * 0.6, Color("2b2016"), 4.0, true)
	ci.draw_circle(c, 7, accent, true, -1.0, true)
	if broken:
		ci.draw_line(c + Vector2(-r * 0.5, -r * 0.3), c + Vector2(r * 0.3, r * 0.5), Color(0.2, 0.2, 0.2, 0.6), 3.0)


func _stove(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, t: float, _n: bool) -> void:
	RenoArt.soft_shadow(ci, Vector2(s.x * 0.5, s.y), s.x * 0.5, 14)
	var body := Rect2(0, s.y * 0.35, s.x, s.y * 0.65)
	RenoArt.pattern_rect(ci, body, pattern, base, accent, 10)
	DrawKit.outline(ci, RenoArt.rect_pts(body, 10), RenoArt.ol(base), 5.0)
	RenoArt.box(ci, Rect2(-10, s.y * 0.3, s.x + 20, s.y * 0.08), base.darkened(0.15), 6)
	# A pot of tea with steam.
	var pot := Rect2(s.x * 0.3, s.y * 0.05, s.x * 0.4, s.y * 0.26)
	RenoArt.box(ci, pot, Color("b8b8c0") if not broken else Color("7a746a"), 12)
	if not broken:
		for k in 3:
			var y := s.y * 0.02 - fmod(t * 30.0 + k * 20.0, 60.0)
			ci.draw_circle(Vector2(s.x * 0.5 + sin(t * 2 + k) * 10, y), 10 + k * 2, Color(1, 1, 1, 0.3), true, -1.0, true)
	for k in 2:
		ci.draw_circle(Vector2(s.x * (0.3 + k * 0.4), s.y * 0.65), s.y * 0.12, Color("2b2b2b"), true, -1.0, true)
		ci.draw_circle(Vector2(s.x * (0.3 + k * 0.4), s.y * 0.65), s.y * 0.07, accent, true, -1.0, true)


func _table(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	RenoArt.soft_shadow(ci, Vector2(s.x * 0.5, s.y), s.x * 0.55, 16)
	for x in [s.x * 0.08, s.x * 0.86]:
		var lean := 20.0 if broken and x > s.x * 0.5 else 0.0
		RenoArt.shape(ci, PackedVector2Array([Vector2(x, s.y * 0.2), Vector2(x + s.x * 0.06, s.y * 0.2), Vector2(x + s.x * 0.06 + lean, s.y), Vector2(x + lean, s.y)]), base.darkened(0.15), 4.0)
	var top := Rect2(0, s.y * 0.12, s.x, s.y * 0.14)
	RenoArt.pattern_rect(ci, top, pattern, base, accent, 8)
	DrawKit.outline(ci, RenoArt.rect_pts(top, 8), RenoArt.ol(base), 4.0)
	if not broken:
		RenoArt.box(ci, Rect2(s.x * 0.2, s.y * 0.02, s.x * 0.14, s.y * 0.1), Color("fff3dc"), 6, 3.0)
		RenoArt.box(ci, Rect2(s.x * 0.6, -s.y * 0.04, s.x * 0.18, s.y * 0.16), accent, 8, 3.0)


func _sofa(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	RenoArt.soft_shadow(ci, Vector2(s.x * 0.5, s.y), s.x * 0.55, 18)
	var back := Rect2(s.x * 0.04, 0, s.x * 0.92, s.y * 0.55)
	RenoArt.pattern_rect(ci, back, pattern, base, accent, 30)
	DrawKit.outline(ci, RenoArt.rect_pts(back, 30), RenoArt.ol(base), 5.0)
	var seat := Rect2(0, s.y * 0.48, s.x, s.y * 0.36)
	RenoArt.box(ci, seat, base.lightened(0.06), 26)
	for x in [0.0, s.x * 0.86]:
		RenoArt.box(ci, Rect2(x, s.y * 0.3, s.x * 0.14, s.y * 0.54), base.darkened(0.08), 24)
	for x in [s.x * 0.1, s.x * 0.86]:
		ci.draw_rect(Rect2(x, s.y * 0.84, 18, s.y * 0.16), Color("3a2a1c"))
	if broken:
		ci.draw_colored_polygon(DrawKit.blob(Vector2(s.x * 0.4, s.y * 0.62), 50, 22, 5, 0.3, 20), Color("d9cdb4"))
	else:
		for k in 2:
			RenoArt.box(ci, Rect2(s.x * (0.2 + k * 0.42), s.y * 0.22, s.x * 0.18, s.y * 0.26), accent, 18, 4.0)


func _rug(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	var pts := PackedVector2Array([Vector2(s.x * 0.1, 0), Vector2(s.x * 0.9, 0), Vector2(s.x, s.y), Vector2(0, s.y)])
	if broken:
		pts = PackedVector2Array([Vector2(s.x * 0.1, 0), Vector2(s.x * 0.7, s.y * 0.1), Vector2(s.x * 0.9, s.y), Vector2(0, s.y * 0.8)])
	ci.draw_colored_polygon(pts, base)
	if not broken:
		RenoArt.pattern_rect(ci, Rect2(s.x * 0.18, s.y * 0.2, s.x * 0.64, s.y * 0.6), pattern if pattern != "plain" else "dhaka", base, accent)
	DrawKit.outline(ci, pts, accent.darkened(0.2), 8.0)


func _frames(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, _pattern: String, broken: bool, _t: float, _n: bool) -> void:
	var specs := [Rect2(0, s.y * 0.1, s.x * 0.3, s.y * 0.6), Rect2(s.x * 0.36, 0, s.x * 0.3, s.y * 0.45), Rect2(s.x * 0.72, s.y * 0.2, s.x * 0.28, s.y * 0.5)]
	for i in specs.size():
		var r: Rect2 = specs[i]
		if broken and i == 1:
			continue
		RenoArt.box(ci, r, base, 4)
		var inner := r.grow(-r.size.x * 0.12)
		var sky: Color = [Color("9fd3ff"), Color("ffd6a5"), Color("cdeac0")][i]
		ci.draw_colored_polygon(RenoArt.rect_pts(inner), sky if not broken else RenoArt.grime(sky))
		if not broken:
			# Simple family snapshots: round heads and shoulders.
			for k in 2:
				var hc := inner.position + Vector2(inner.size.x * (0.32 + k * 0.36), inner.size.y * 0.45)
				ci.draw_circle(hc, inner.size.x * 0.12, Color("c98b5e"), true, -1.0, true)
				ci.draw_colored_polygon(DrawKit.ellipse(hc + Vector2(0, inner.size.y * 0.4), inner.size.x * 0.18, inner.size.y * 0.22, 16), accent)
		DrawKit.outline(ci, RenoArt.rect_pts(inner), RenoArt.ol(base), 3.0)


func _water_tank(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	RenoArt.box(ci, Rect2(s.x * 0.05, s.y * 0.75, s.x * 0.9, s.y * 0.25), Color("8c8577"), 4)
	var body := Rect2(s.x * 0.1, s.y * 0.08, s.x * 0.8, s.y * 0.7)
	RenoArt.pattern_rect(ci, body, pattern, base, accent, 30)
	for k in 3:
		ci.draw_line(Vector2(body.position.x, body.position.y + body.size.y * (0.25 + k * 0.25)), Vector2(body.end.x, body.position.y + body.size.y * (0.25 + k * 0.25)), base.darkened(0.2), 5.0)
	DrawKit.outline(ci, RenoArt.rect_pts(body, 30), RenoArt.ol(base), 5.0)
	RenoArt.box(ci, Rect2(s.x * 0.3, 0, s.x * 0.4, s.y * 0.12), base.darkened(0.1), 10)
	if broken:
		ci.draw_line(Vector2(s.x * 0.6, s.y * 0.5), Vector2(s.x * 0.62, s.y), Color("7aa9c9"), 6.0)


func _kite(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, _pattern: String, broken: bool, t: float, _n: bool) -> void:
	var c := Vector2(s.x * 0.5, s.y * 0.35) + Vector2(sin(t * 1.2) * 10, cos(t * 0.9) * 6)
	var k := s.x * 0.32
	var pts := PackedVector2Array([c + Vector2(0, -k), c + Vector2(k * 0.8, 0), c + Vector2(0, k), c + Vector2(-k * 0.8, 0)])
	if broken:
		pts = PackedVector2Array([c + Vector2(0, -k), c + Vector2(k * 0.6, k * 0.2), c + Vector2(0, k)])
	ci.draw_colored_polygon(pts, base)
	if not broken:
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k), c + Vector2(k * 0.8, 0), c]), accent)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, k), c + Vector2(-k * 0.8, 0), c]), accent)
	DrawKit.outline(ci, pts, RenoArt.ol(base), 4.0)
	var tail := PackedVector2Array()
	for i in 12:
		tail.append(c + Vector2(sin(t * 3.0 + i * 0.6) * 12, k + i * s.y * 0.04))
	ci.draw_polyline(tail, Color("2b2016"), 2.0, true)
	ci.draw_line(c, Vector2(s.x * 0.5, s.y), Color(1, 1, 1, 0.6), 1.5, true)


func _railing(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	RenoArt.box(ci, Rect2(0, 0, s.x, s.y * 0.14), base, 6)
	RenoArt.box(ci, Rect2(0, s.y * 0.86, s.x, s.y * 0.14), base, 6)
	var n := int(s.x / 60.0)
	for k in n:
		if broken and k % 4 == 1:
			continue
		var x := k * s.x / n + 20
		RenoArt.box(ci, Rect2(x, s.y * 0.14, 16, s.y * 0.72), accent if pattern in ["painted", "gold"] else base.darkened(0.1), 4, 3.0)


func _umbrella(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, _pattern: String, broken: bool, _t: float, _n: bool) -> void:
	ci.draw_line(Vector2(s.x * 0.5, s.y * 0.2), Vector2(s.x * 0.5, s.y), Color("5a3a20"), 8.0)
	var c := Vector2(s.x * 0.5, s.y * 0.32)
	var n := 8
	for k in n:
		var a0 := PI + PI * k / n
		var a1 := PI + PI * (k + 1) / n
		if broken and k in [2, 5]:
			continue
		ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0) * 0.5) * s.x * 0.5, c + Vector2(cos(a1), sin(a1) * 0.5) * s.x * 0.5]), base if k % 2 == 0 else accent)
	ci.draw_circle(c + Vector2(0, -s.x * 0.25), 8, accent, true, -1.0, true)


func _clothesline(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, _pattern: String, broken: bool, t: float, _n: bool) -> void:
	ci.draw_line(Vector2(0, s.y * 0.2), Vector2(s.x, s.y * 0.2), Color("4a3a2a"), 3.0)
	if broken:
		return
	var cols := [base, accent, Color("8fd3ff"), Color("ff9f1c"), Color("fff3dc")]
	var n := int(s.x / 110.0)
	for k in n:
		var x := 30 + k * (s.x - 60) / maxf(1.0, n - 1)
		var sway := sin(t * 1.5 + k) * 4
		var r := Rect2(x - 36 + sway, s.y * 0.2, 72, s.y * (0.4 + (k % 2) * 0.2))
		RenoArt.box(ci, r, cols[k % cols.size()], 6, 3.0)


func _tea_stall(ci: CanvasItem, s: Vector2, base: Color, accent: Color, trim: Color, pattern: String, broken: bool, t: float, n: bool) -> void:
	var counter := Rect2(0, s.y * 0.55, s.x, s.y * 0.45)
	RenoArt.pattern_rect(ci, counter, pattern, base, accent, 8)
	DrawKit.outline(ci, RenoArt.rect_pts(counter, 8), RenoArt.ol(base), 5.0)
	for x in [8.0, s.x - 26.0]:
		RenoArt.box(ci, Rect2(x, s.y * 0.12, 18, s.y * 0.45), trim, 3, 3.0)
	_awning(ci, Vector2(s.x, s.y * 0.2), accent, base.lightened(0.4), trim, pattern, broken, t, n)
	if not broken:
		_stove(ci, Vector2(s.x * 0.3, s.y * 0.3), Color("b8b8c0"), Color("ff6b3b"), trim, "plain", false, t, n)
		for k in 4:
			RenoArt.box(ci, Rect2(s.x * (0.45 + k * 0.12), s.y * 0.46, s.x * 0.07, s.y * 0.09), Color("fff3dc"), 4, 3.0)


func _tree(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, _pattern: String, broken: bool, t: float, _n: bool) -> void:
	RenoArt.soft_shadow(ci, Vector2(s.x * 0.5, s.y), s.x * 0.4, 16)
	RenoArt.shape(ci, PackedVector2Array([Vector2(s.x * 0.44, s.y), Vector2(s.x * 0.56, s.y), Vector2(s.x * 0.53, s.y * 0.45), Vector2(s.x * 0.47, s.y * 0.45)]), Color("7a4e2c"), 4.0)
	if broken:
		ci.draw_line(Vector2(s.x * 0.5, s.y * 0.5), Vector2(s.x * 0.3, s.y * 0.3), Color("7a4e2c"), 10.0)
		ci.draw_line(Vector2(s.x * 0.5, s.y * 0.5), Vector2(s.x * 0.68, s.y * 0.28), Color("7a4e2c"), 8.0)
		return
	var sway := sin(t * 0.8) * 4.0
	for k in 5:
		var c := Vector2(s.x * (0.3 + (k % 3) * 0.2) + sway, s.y * (0.28 + (k / 3) * 0.16))
		ci.draw_circle(c, s.x * 0.22, base.darkened(0.15), true, -1.0, true)
		ci.draw_circle(c + Vector2(-6, -8), s.x * 0.18, base, true, -1.0, true)
	for k in 6:
		ci.draw_circle(Vector2(s.x * (0.25 + k * 0.1) + sway, s.y * (0.25 + (k % 3) * 0.1)), 9, accent, true, -1.0, true)


func _lantern(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, t: float, night: bool) -> void:
	var n := maxi(1, int(s.x / 150.0))
	for k in n:
		var cx := (k + 0.5) * s.x / n
		var swing := sin(t * 1.4 + k) * 4.0
		var c := Vector2(cx + swing, s.y * 0.55)
		ci.draw_line(Vector2(cx, 0), c + Vector2(0, -s.y * 0.3), Color("2b2016"), 2.0)
		if night and not broken:
			ci.draw_circle(c, s.y * 0.5, Color(1.0, 0.7, 0.3, 0.1), true, -1.0, true)
		var body := DrawKit.ellipse(c, s.y * 0.26, s.y * 0.3, 24)
		if broken:
			body = DrawKit.ellipse(c + Vector2(0, 10), s.y * 0.2, s.y * 0.16, 14)
		ci.draw_colored_polygon(body, base if k % 2 == 0 else accent)
		for j in 3:
			ci.draw_line(c + Vector2(-s.y * 0.24, -s.y * 0.15 + j * s.y * 0.15), c + Vector2(s.y * 0.24, -s.y * 0.15 + j * s.y * 0.15), Color(0, 0, 0, 0.18), 2.0)
		DrawKit.outline(ci, body, RenoArt.ol(base), 3.0)


func _bunting(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, _pattern: String, broken: bool, t: float, _n: bool) -> void:
	var pts := PackedVector2Array()
	for k in 21:
		var u := k / 20.0
		pts.append(Vector2(u * s.x, s.y * 0.1 + sin(u * PI) * s.y * 0.3))
	ci.draw_polyline(pts, Color("2b2016"), 3.0, true)
	var cols := [base, accent, Color("8fd3ff"), Color("fff3dc"), Color("5fd02c")]
	var n := int(s.x / 60.0)
	for k in n:
		if broken and k % 3 != 0:
			continue
		var u := (k + 0.5) / n
		var p := Vector2(u * s.x, s.y * 0.1 + sin(u * PI) * s.y * 0.3)
		var flap := sin(t * 2.0 + k) * 4.0
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-22, 0), p + Vector2(22, 0), p + Vector2(flap, s.y * 0.5)]), cols[k % cols.size()])


func _boat(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, t: float, _n: bool) -> void:
	var bob := sin(t * 1.2) * 4.0
	var hull := PackedVector2Array([Vector2(0, s.y * 0.4 + bob), Vector2(s.x, s.y * 0.4 + bob), Vector2(s.x * 0.85, s.y * 0.85 + bob), Vector2(s.x * 0.15, s.y * 0.85 + bob)])
	ci.draw_colored_polygon(hull, base)
	if not broken:
		RenoArt.pattern_rect(ci, Rect2(s.x * 0.1, s.y * 0.45 + bob, s.x * 0.8, s.y * 0.14), pattern, base, accent)
	DrawKit.outline(ci, hull, RenoArt.ol(base), 5.0)
	if broken:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(s.x * 0.4, s.y * 0.6 + bob), Vector2(s.x * 0.55, s.y * 0.62 + bob), Vector2(s.x * 0.48, s.y * 0.8 + bob)]), Color(0.15, 0.1, 0.08))
	ci.draw_line(Vector2(s.x * 0.7, s.y * 0.4 + bob), Vector2(s.x * 1.05, s.y * 0.0 + bob), Color("5a3a20"), 6.0)


func _dock(ci: CanvasItem, s: Vector2, base: Color, accent: Color, trim: Color, pattern: String, broken: bool, t: float, n: bool) -> void:
	var top := Rect2(0, 0, s.x, s.y * 0.3)
	_floor(ci, top.size, base, accent, trim, pattern if pattern != "plain" else "planks", broken, t, n)
	for k in 5:
		if broken and k == 3:
			continue
		RenoArt.box(ci, Rect2(k * (s.x - 30) / 4.0, s.y * 0.3, 30, s.y * 0.7), base.darkened(0.25), 4, 3.0)


func _chair(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	RenoArt.soft_shadow(ci, Vector2(s.x * 0.5, s.y), s.x * 0.45, 12)
	RenoArt.box(ci, Rect2(s.x * 0.1, 0, s.x * 0.8, s.y * 0.5), base, 12)
	if not broken:
		RenoArt.pattern_rect(ci, Rect2(s.x * 0.2, s.y * 0.08, s.x * 0.6, s.y * 0.34), pattern, base, accent, 8)
	RenoArt.box(ci, Rect2(0, s.y * 0.48, s.x, s.y * 0.14), base.lightened(0.08), 8)
	for x in [s.x * 0.08, s.x * 0.82]:
		var lean := 16.0 if broken and x > s.x * 0.5 else 0.0
		RenoArt.shape(ci, PackedVector2Array([Vector2(x, s.y * 0.6), Vector2(x + s.x * 0.1, s.y * 0.6), Vector2(x + s.x * 0.1 + lean, s.y), Vector2(x + lean, s.y)]), base.darkened(0.15), 3.0)


func _flower_bed(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, t: float, _n: bool) -> void:
	var bed := Rect2(0, s.y * 0.5, s.x, s.y * 0.5)
	RenoArt.pattern_rect(ci, bed, pattern if pattern != "plain" else "brick", base, accent, 8)
	DrawKit.outline(ci, RenoArt.rect_pts(bed, 8), RenoArt.ol(base), 5.0)
	ci.draw_rect(Rect2(8, s.y * 0.5, s.x - 16, 18), Color("5a3b22"))
	var n := int(s.x / 50.0)
	for k in n:
		var x := 25 + k * (s.x - 50) / maxf(1.0, n - 1)
		var sway := sin(t * 1.4 + k) * 3.0
		if broken:
			if k % 3 == 0:
				ci.draw_line(Vector2(x, s.y * 0.5), Vector2(x + 10, s.y * 0.38), Color("7a6a48"), 3.0)
			continue
		ci.draw_line(Vector2(x, s.y * 0.5), Vector2(x + sway, s.y * 0.2), Color("3f8f3a"), 4.0)
		_flower_static(ci, Vector2(x + sway, s.y * 0.18), 18, [accent, Color("ff9f1c"), Color("ff6b8b")][k % 3])


func _fence(ci: CanvasItem, s: Vector2, base: Color, accent: Color, trim: Color, pattern: String, broken: bool, t: float, n: bool) -> void:
	_railing(ci, s, base, accent, trim, pattern, broken, t, n)


func _hut(ci: CanvasItem, s: Vector2, base: Color, accent: Color, trim: Color, pattern: String, broken: bool, t: float, n: bool) -> void:
	var wall := Rect2(s.x * 0.08, s.y * 0.38, s.x * 0.84, s.y * 0.62)
	RenoArt.pattern_rect(ci, wall, pattern if pattern != "plain" else "brick", base, accent)
	DrawKit.outline(ci, RenoArt.rect_pts(wall), RenoArt.ol(base), 6.0)
	var roof := PackedVector2Array([Vector2(-20, s.y * 0.42), Vector2(s.x * 0.5, 0), Vector2(s.x + 20, s.y * 0.42)])
	RenoArt.shape(ci, roof, trim, 6.0)
	if broken:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(s.x * 0.55, s.y * 0.08), Vector2(s.x * 0.7, s.y * 0.2), Vector2(s.x * 0.6, s.y * 0.28)]), Color(0.15, 0.1, 0.08))
	var door := Rect2(s.x * 0.4, s.y * 0.62, s.x * 0.2, s.y * 0.38)
	RenoArt.box(ci, door, accent.darkened(0.2), 6)
	_window(ci, Vector2(s.x * 0.2, s.y * 0.22), base.darkened(0.2), accent, trim, pattern, broken, t, n)


func _door(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, pattern: String, broken: bool, _t: float, _n: bool) -> void:
	var r := Rect2(0, 0, s.x, s.y)
	RenoArt.pattern_rect(ci, r, pattern, base, accent, 10)
	DrawKit.outline(ci, RenoArt.rect_pts(r, 10), RenoArt.ol(base), 6.0)
	ci.draw_line(Vector2(s.x * 0.5, 10), Vector2(s.x * 0.5, s.y - 10), RenoArt.ol(base), 4.0)
	ci.draw_circle(Vector2(s.x * 0.42, s.y * 0.55), 9, accent, true, -1.0, true)
	ci.draw_circle(Vector2(s.x * 0.58, s.y * 0.55), 9, accent, true, -1.0, true)
	if broken:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(s.x * 0.6, s.y * 0.1), Vector2(s.x * 0.9, s.y * 0.2), Vector2(s.x * 0.7, s.y * 0.35)]), Color(0.15, 0.1, 0.08))


func _beams(ci: CanvasItem, s: Vector2, base: Color, accent: Color, _trim: Color, _pattern: String, _broken: bool, _t: float, _n: bool) -> void:
	ci.draw_rect(Rect2(0, 0, s.x, s.y), base)
	ci.draw_rect(Rect2(0, s.y - 10, s.x, 10), base.darkened(0.35))
	var n := int(s.x / 300.0) + 1
	for k in n:
		var x := k * s.x / maxf(1.0, n - 1)
		var end := PackedVector2Array([Vector2(x - 34, s.y - 4), Vector2(x + 34, s.y - 4), Vector2(x + 24, s.y + 30), Vector2(x - 24, s.y + 30)])
		RenoArt.shape(ci, end, base.darkened(0.12), 4.0)
		ci.draw_rect(Rect2(x - 14, s.y + 6, 28, 8), accent)
