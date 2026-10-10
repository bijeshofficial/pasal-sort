class_name CandyArt
extends RefCounted
## Code-drawn candies: a glossy body in the candy's colour AND a unique
## shape (colour-blind friendly), each with its own wrapper ("wrap" in
## data/candies.json): twisted cellophane, crimped ends, a ribbon bow, a
## pleated paper cup, a lollipop stick, or bare and sugar-coated.
## Shapes are built once on a unit grid (1 = slot diameter) and cached.
## Final art can replace CandyVisual without touching gameplay code.

const PAPER := Color("e8d6b3")
const PAPER_EDGE := Color("b89a6c")
const FOIL := Color("d7dde1")
const FOIL_EDGE := Color("9aa5ad")
const GOLD_FOIL := Color("f0cf6a")
const GOLD_FOIL_EDGE := Color("a97d17")

static var _shapes: Dictionary = {}
## Colour-blind mode: an extra inner marking per candy type (1-6 pips, with
## a bar under them for types 7-12), so nothing relies on colour alone.
static var colorblind := false


static func shape(name: String) -> PackedVector2Array:
	if _shapes.has(name):
		return _shapes[name]
	var pts := PackedVector2Array()
	match name:
		"round":
			pts = DrawKit.ellipse(Vector2.ZERO, 0.3, 0.3, 36)
		"oval":
			pts = DrawKit.ellipse(Vector2.ZERO, 0.35, 0.235, 36)
		"leaf":
			var half := PackedVector2Array()
			for i in 17:
				var t := -1.0 + 2.0 * i / 16.0
				half.append(Vector2(0.37 * t, -0.23 * (1.0 - t * t)))
			for i in range(15, 0, -1):
				var t := -1.0 + 2.0 * i / 16.0
				half.append(Vector2(0.37 * t, 0.23 * (1.0 - t * t)))
			pts = _rotate(half, -0.45)
		"heart":
			for i in 40:
				var t := TAU * i / 40.0
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
				pts.append(Vector2(x, y + 2.0) * (0.31 / 16.5))
		"drop":
			for i in 40:
				var t := TAU * i / 40.0
				pts.append(Vector2(sin(t) * sin(t * 0.5) * 0.31, -cos(t) * 0.33 + 0.02))
		"cube":
			pts = DrawKit.regular(Vector2.ZERO, 0.31, 6, -PI * 0.5)
		"flame":
			pts = PackedVector2Array([
				Vector2(0.03, -0.37), Vector2(0.13, -0.2), Vector2(0.12, -0.11), Vector2(0.21, -0.17),
				Vector2(0.27, 0.01), Vector2(0.24, 0.17), Vector2(0.12, 0.28), Vector2(-0.07, 0.29),
				Vector2(-0.22, 0.19), Vector2(-0.27, 0.01), Vector2(-0.19, -0.14), Vector2(-0.11, -0.05),
				Vector2(-0.09, -0.22)])
		"star":
			pts = DrawKit.star(Vector2(0, 0.02), 0.35, 0.16, 5)
		"diamond":
			pts = PackedVector2Array([Vector2(-0.17, -0.22), Vector2(0.17, -0.22), Vector2(0.31, -0.07), Vector2(0, 0.31), Vector2(-0.31, -0.07)])
		"square":
			pts = DrawKit.rounded_rect(Rect2(-0.27, -0.27, 0.54, 0.54), 0.1, 6)
		"crescent":
			var outer := DrawKit.ellipse(Vector2.ZERO, 0.31, 0.31, 40)
			var inner := DrawKit.ellipse(Vector2(0.14, -0.1), 0.25, 0.25, 40)
			var clipped := Geometry2D.clip_polygons(outer, inner)
			pts = _rotate(clipped[0] if not clipped.is_empty() else outer, 0.3)
		"hexagon":
			pts = DrawKit.regular(Vector2.ZERO, 0.32, 6, 0.0)
		_:
			pts = DrawKit.ellipse(Vector2.ZERO, 0.3, 0.3, 36)
	_shapes[name] = pts
	return pts


static func _rotate(pts: PackedVector2Array, a: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p.rotated(a))
	return out


static func _xf(pts: PackedVector2Array, c: Vector2, d: float, k: float = 1.0, off: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = c + (pts[i] * k + off) * d
	return out


## Draws one candy centred at `c` in a slot of diameter `d`.
## style: "classic" | "striped" | "foil". hidden: plain paper wrapper.
## selected: a white halo so the moving group reads clearly.
static func draw_candy(ci: CanvasItem, c: Vector2, d: float, type: int, style: String = "classic", hidden: bool = false, selected: bool = false) -> void:
	var col := GameData.candy_color(type)
	var shape_name := GameData.candy_shape(type)
	var edge := col.darkened(0.42)
	if type == 5:  # the white candy needs a visible edge
		edge = Color("a89f90")
	var line := maxf(1.5, d * 0.03)

	if hidden:
		_draw_twists(ci, c, d, PAPER, PAPER_EDGE, "paper", line, selected)
		var body := DrawKit.rounded_rect(Rect2(c.x - d * 0.3, c.y - d * 0.26, d * 0.6, d * 0.52), d * 0.12, 5)
		if selected:
			DrawKit.outline(ci, body, Color.WHITE, line * 4.0)
		ci.draw_colored_polygon(body, PAPER)
		ci.draw_line(c + Vector2(-d * 0.26, d * 0.1), c + Vector2(d * 0.26, d * 0.1), PAPER.darkened(0.08), line * 2.0)
		DrawKit.outline(ci, body, PAPER_EDGE, line)
		var f := UIKit.font(true)
		var fs := int(d * 0.4)
		var w := f.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(f, c + Vector2(-w * 0.5, d * 0.14), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("8a6d45"))
		return

	var twist := col.lightened(0.38)
	var twist_edge := col.darkened(0.25)
	if style == "foil":
		twist = GOLD_FOIL if type == 11 else FOIL
		twist_edge = GOLD_FOIL_EDGE if type == 11 else FOIL_EDGE
	elif type == 5:
		twist = Color("f4efe6")
		twist_edge = edge
	var wrap := String(GameData.candy(type).get("wrap", "twist"))
	if wrap == "bare":
		d *= 1.12
	var pts := shape(shape_name)
	var body := _xf(pts, c, d)
	var parts := _parts(shape_name)
	# Contact shadow (the candy rests on the one below / the jar floor).
	ci.draw_colored_polygon(DrawKit.ellipse(c + Vector2(0, 0.3) * d, 0.3 * d, 0.055 * d, 20), Color(0.05, 0.02, 0.15, 0.22))
	match wrap:
		"twist":
			_draw_twists(ci, c, d, twist, twist_edge, style, line, selected)
		"crimp":
			_draw_crimp(ci, c, d, twist, twist_edge, style, line, selected)
		"bow":
			# A ribbon in a deeper shade of the candy, so it reads as a bow.
			var ribbon := twist if style == "foil" else Color.from_hsv(col.h, minf(1.0, col.s * 1.15), col.v * 0.82)
			_draw_bow(ci, c, d, ribbon, edge if style != "foil" else twist_edge, style, line, selected)
		"stick":
			_draw_stick(ci, c, d, line, selected)
	if selected:
		ci.draw_colored_polygon(_xf(parts["halo"], c, d), Color.WHITE)
	# Inked outline, then a gradient body.
	ci.draw_colored_polygon(_xf(parts["ink"], c, d), edge)
	DrawKit.gradient_fill(ci, body, _lit(col) if type != 5 else Color.WHITE, _shade(col) if type != 5 else Color("ddd5c7"))
	# Reflected light along the bottom edge.
	for crescent in parts["rim"]:
		ci.draw_colored_polygon(_xf(crescent, c, d), Color(_lit(col).lightened(0.35), 0.55))
	_details(ci, c, d, type, shape_name, col, edge, line, body)
	if wrap == "cup":
		var cup := twist
		var cup_edge := twist_edge
		if style != "foil" and type == 5:  # pink paper so the white coconut stands out
			cup = Color("f4a6c0")
			cup_edge = Color("c0577c")
		elif style != "foil" and type == 11:  # brown paper under the gold chocolate
			cup = Color("8a5636")
			cup_edge = Color("4e2c18")
		_draw_cup(ci, c, d, cup, cup_edge, style, line, selected)
	# Gloss: a big soft highlight and a sharp specular dot.
	DrawKit.gradient_fill(ci, _xf(parts["gloss"], c, d), Color(1, 1, 1, 0.62), Color(1, 1, 1, 0.04))
	ci.draw_circle(c + Vector2(-0.15, -0.02) * d, d * 0.024, Color(1, 1, 1, 0.8), true, -1.0, true)
	ci.draw_circle(c + Vector2(0.12, 0.12) * d, d * 0.014, Color(1, 1, 1, 0.45), true, -1.0, true)
	DrawKit.aa_rim(ci, _xf(parts["ink"], c, d), edge, 1.4)
	if colorblind:
		_draw_marking(ci, c, d, type)


static func _draw_marking(ci: CanvasItem, c: Vector2, d: float, type: int) -> void:
	var pips := type % 6 + 1
	var bar := type >= 6
	var r := d * 0.045
	var w := pips * r * 2.6 + r
	var box := Rect2(c.x - w * 0.5, c.y + d * 0.04, w, r * (4.4 if bar else 3.0))
	ci.draw_colored_polygon(DrawKit.rounded_rect(box, r * 1.4, 4), Color(1, 1, 1, 0.92))
	DrawKit.outline(ci, DrawKit.rounded_rect(box, r * 1.4, 4), Color("2b1d16"), maxf(1.0, d * 0.012))
	for k in pips:
		ci.draw_circle(Vector2(box.position.x + r * 1.8 + k * r * 2.6, box.position.y + r * 1.5), r * 0.8, Color("2b1d16"), true, -1.0, true)
	if bar:
		ci.draw_line(Vector2(box.position.x + r, box.end.y - r * 1.1), Vector2(box.end.x - r, box.end.y - r * 1.1), Color("2b1d16"), r * 0.9)


## Lit (top) and shaded (bottom) tones that keep the candy saturated.
static func _lit(col: Color) -> Color:
	return Color.from_hsv(col.h, col.s * 0.88, minf(1.0, col.v * 1.14))


static func _shade(col: Color) -> Color:
	return Color.from_hsv(col.h, minf(1.0, col.s * 1.1), col.v * 0.8)


## Unit-space helper shapes per candy shape (cached): an inked outline, a
## selection halo, the reflected-light crescent and the gloss blob.
static var _part_cache: Dictionary = {}


static func _parts(shape_name: String) -> Dictionary:
	if _part_cache.has(shape_name):
		return _part_cache[shape_name]
	var pts := shape(shape_name)
	var ink: PackedVector2Array = pts
	var grown := Geometry2D.offset_polygon(pts, 0.032, Geometry2D.JOIN_ROUND)
	if not grown.is_empty():
		ink = grown[0]
	var halo: PackedVector2Array = ink
	var big := Geometry2D.offset_polygon(pts, 0.085, Geometry2D.JOIN_ROUND)
	if not big.is_empty():
		halo = big[0]
	var lower := _scaled(pts, 0.9, Vector2(0, 0.025))
	var upper := _scaled(pts, 0.86, Vector2(0, -0.015))
	var rim: Array = Geometry2D.clip_polygons(lower, upper)
	# Gloss: an ellipse in the upper-left, kept inside the body.
	var blob := DrawKit.ellipse(Vector2(-0.08, -0.13), 0.09, 0.05, 20)
	var rot := PackedVector2Array()
	for p in blob:
		rot.append((p - Vector2(-0.08, -0.13)).rotated(-0.5) + Vector2(-0.08, -0.13))
	var inside := Geometry2D.intersect_polygons(rot, _scaled(pts, 0.86, Vector2.ZERO))
	var gloss: PackedVector2Array = inside[0] if not inside.is_empty() else rot
	var out := {"ink": ink, "halo": halo, "rim": rim, "gloss": gloss}
	_part_cache[shape_name] = out
	return out


static func _scaled(pts: PackedVector2Array, k: float, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * k + off)
	return out


## Little touches that make each candy its own sweet.
static func _details(ci: CanvasItem, c: Vector2, d: float, type: int, shape_name: String, col: Color, edge: Color, line: float, body: PackedVector2Array) -> void:
	var pts := shape(shape_name)
	match shape_name:
		"round":
			# Sugar-coated lapsi: tiny specks.
			var specks := [[-0.12, 0.06], [0.05, 0.12], [0.14, -0.04], [-0.02, -0.1], [0.11, 0.08], [-0.15, -0.08], [0.0, 0.03], [0.17, 0.1], [-0.07, 0.17]]
			for sp in specks:
				ci.draw_circle(c + Vector2(sp[0], sp[1]) * d, d * 0.013, Color(1, 0.97, 0.9, 0.75), true, -1.0, true)
		"leaf":
			ci.draw_line(c + Vector2(-0.3, 0.13) * d, c + Vector2(0.3, -0.13) * d, col.darkened(0.3), line, true)
			for k in 3:
				var t := -0.15 + k * 0.15
				var base := c + Vector2(t, -t * 0.43) * d
				ci.draw_line(base, base + Vector2(0.03, -0.09) * d, col.darkened(0.2), line * 0.7, true)
				ci.draw_line(base, base + Vector2(0.06, 0.06) * d, col.darkened(0.2), line * 0.7, true)
		"oval":
			# A ripe blush on the mango.
			ci.draw_circle(c + Vector2(0.12, 0.06) * d, d * 0.11, Color(1.0, 0.5, 0.2, 0.3), true, -1.0, true)
		"cube":
			var top := PackedVector2Array([body[0], body[1], c, body[5]])
			ci.draw_colored_polygon(top, Color.WHITE)
			var right := PackedVector2Array([body[1], body[2], body[3], c])
			ci.draw_colored_polygon(right, Color(0.8, 0.75, 0.66, 0.5))
			ci.draw_line(c, body[3], edge, line * 0.8, true)
			ci.draw_line(c, body[1], edge, line * 0.8, true)
			ci.draw_line(c, body[5], edge, line * 0.8, true)
			# Coconut flakes.
			for sp in [[-0.14, 0.05], [-0.06, 0.14], [0.08, 0.1], [0.15, 0.02], [-0.18, 0.12]]:
				ci.draw_line(c + Vector2(sp[0], sp[1]) * d, c + Vector2(sp[0] + 0.03, sp[1] - 0.012) * d, Color("c9bba6"), line * 0.8, true)
		"flame":
			DrawKit.gradient_fill(ci, _xf(pts, c, d, 0.55, Vector2(0.0, 0.1)), Color("ffe36a"), Color("ff9a2e"))
		"star":
			DrawKit.gradient_fill(ci, _xf(pts, c, d, 0.48, Vector2(0, 0.01)), col.lightened(0.45), col.lightened(0.15))
		"diamond":
			var a := c + Vector2(-0.31, -0.07) * d
			var b := c + Vector2(0.31, -0.07) * d
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.17, -0.22) * d, c + Vector2(0.17, -0.22) * d, b, a]), Color(col.lightened(0.4), 0.7))
			ci.draw_line(a, b, col.lightened(0.5), line * 0.8, true)
			ci.draw_line(c + Vector2(-0.08, -0.22) * d, c + Vector2(0, 0.31) * d, col.lightened(0.3), line * 0.7, true)
			ci.draw_line(c + Vector2(0.08, -0.22) * d, c + Vector2(0, 0.31) * d, col.lightened(0.3), line * 0.7, true)
		"square":
			# A coffee bean pressed into the kafi toffee.
			var bean := DrawKit.ellipse(c + Vector2(0.02, 0.03) * d, 0.12 * d, 0.16 * d, 20)
			var rb := PackedVector2Array()
			for p in bean:
				rb.append((p - c).rotated(0.5) + c)
			ci.draw_colored_polygon(rb, col.darkened(0.3))
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.04, -0.1) * d, c + Vector2(0.03, -0.01) * d, c + Vector2(0.0, 0.08) * d, c + Vector2(0.08, 0.15) * d]), col.lightened(0.25), line * 0.9, true)
		"hexagon":
			DrawKit.outline(ci, _xf(pts, c, d, 0.62), col.lightened(0.45), line * 0.9)
			# Foil sheen: a bright diagonal band.
			var band := PackedVector2Array([c + Vector2(-0.05, -0.4) * d, c + Vector2(0.08, -0.4) * d, c + Vector2(-0.12, 0.4) * d, c + Vector2(-0.25, 0.4) * d])
			for part in Geometry2D.intersect_polygons(body, band):
				ci.draw_colored_polygon(part, Color(1, 1, 0.85, 0.45))
		"heart":
			ci.draw_circle(c + Vector2(0.12, -0.08) * d, d * 0.035, Color(1, 1, 1, 0.5), true, -1.0, true)
		"drop":
			ci.draw_circle(c + Vector2(0.08, 0.12) * d, d * 0.06, Color(col.lightened(0.4), 0.45), true, -1.0, true)


## Twisted cellophane wrapper ends: a pinched knot and a pleated fan.
static func _draw_twists(ci: CanvasItem, c: Vector2, d: float, fill: Color, edge: Color, style: String, line: float, selected: bool) -> void:
	for side in [-1.0, 1.0]:
		var s: float = side
		var fan := PackedVector2Array([
			c + Vector2(s * 0.25, -0.08) * d,
			c + Vector2(s * 0.5, -0.23) * d,
			c + Vector2(s * 0.46, -0.08) * d,
			c + Vector2(s * 0.51, 0.0) * d,
			c + Vector2(s * 0.46, 0.08) * d,
			c + Vector2(s * 0.5, 0.23) * d,
			c + Vector2(s * 0.25, 0.08) * d,
		])
		if s < 0:
			fan.reverse()
		if selected:
			DrawKit.outline(ci, fan, Color.WHITE, line * 4.0)
		var top := fill.lightened(0.25)
		var bottom := fill.darkened(0.08)
		if style == "foil":
			top = fill.lightened(0.45)
			bottom = fill.darkened(0.2)
		DrawKit.gradient_fill(ci, fan, Color(top, 0.95), Color(bottom, 0.85))
		# Pleats fanning out from the knot.
		for k in 3:
			var ty := -0.15 + k * 0.15
			ci.draw_line(c + Vector2(s * 0.3, ty * 0.25) * d, c + Vector2(s * 0.47, ty) * d, Color(1, 1, 1, 0.55), line * 0.75, true)
		match style:
			"striped":
				ci.draw_line(c + Vector2(s * 0.35, -0.15) * d, c + Vector2(s * 0.35, 0.15) * d, Color(1, 1, 1, 0.95), line * 1.8)
				ci.draw_line(c + Vector2(s * 0.44, -0.2) * d, c + Vector2(s * 0.44, 0.2) * d, Color(1, 1, 1, 0.95), line * 1.8)
			"foil", "paper":
				ci.draw_line(c + Vector2(s * 0.31, -0.04) * d, c + Vector2(s * 0.47, -0.16) * d, edge.lightened(0.2), line * 0.7, true)
				ci.draw_line(c + Vector2(s * 0.31, 0.04) * d, c + Vector2(s * 0.47, 0.16) * d, edge.lightened(0.2), line * 0.7, true)
		DrawKit.outline(ci, fan, edge, line * 0.9)
		# The twist knot.
		var knot := DrawKit.rounded_rect(Rect2(c.x + (s * 0.27 - 0.038) * d, c.y - 0.08 * d, 0.076 * d, 0.16 * d), 0.034 * d, 3)
		DrawKit.gradient_fill(ci, knot, fill.lightened(0.1), fill.darkened(0.2))
		DrawKit.outline(ci, knot, edge, line * 0.8)


## Crimped sachet ends: flat, with a zigzag edge and pressed lines.
static func _draw_crimp(ci: CanvasItem, c: Vector2, d: float, fill: Color, edge: Color, style: String, line: float, selected: bool) -> void:
	for side in [-1.0, 1.0]:
		var s: float = side
		var pts := PackedVector2Array([c + Vector2(s * 0.22, -0.15) * d, c + Vector2(s * 0.42, -0.19) * d])
		var teeth := 6
		for k in teeth + 1:
			var y := -0.19 + 0.38 * k / teeth
			pts.append(c + Vector2(s * (0.49 if k % 2 == 0 else 0.44), y) * d)
		pts.append(c + Vector2(s * 0.42, 0.19) * d)
		pts.append(c + Vector2(s * 0.22, 0.15) * d)
		if s < 0:
			pts.reverse()
		if selected:
			DrawKit.outline(ci, pts, Color.WHITE, line * 4.0)
		DrawKit.gradient_fill(ci, pts, Color(_wrap_top(fill, style), 0.95), Color(_wrap_bottom(fill, style), 0.9))
		for x in [0.34, 0.39]:
			ci.draw_line(c + Vector2(s * x, -0.15) * d, c + Vector2(s * x, 0.15) * d, Color(edge, 0.45), line * 0.7, true)
		if style == "striped":
			ci.draw_line(c + Vector2(s * 0.26, 0) * d, c + Vector2(s * 0.45, 0) * d, Color(1, 1, 1, 0.95), line * 2.2)
		DrawKit.outline(ci, pts, edge, line * 0.9)


## A ribbon bow on each side: two round loops and a knot.
static func _draw_bow(ci: CanvasItem, c: Vector2, d: float, fill: Color, edge: Color, style: String, line: float, selected: bool) -> void:
	for side in [-1.0, 1.0]:
		var s: float = side
		for up in [-1.0, 1.0]:
			var lc := c + Vector2(s * 0.38, up * 0.12) * d
			var loop := PackedVector2Array()
			for p in DrawKit.ellipse(Vector2.ZERO, 0.13 * d, 0.075 * d, 24):
				loop.append(lc + p.rotated(s * up * 0.55))
			if selected:
				DrawKit.outline(ci, loop, Color.WHITE, line * 4.0)
			DrawKit.gradient_fill(ci, loop, _wrap_top(fill, style), _wrap_bottom(fill, style))
			var hole := PackedVector2Array()
			for p in DrawKit.ellipse(Vector2.ZERO, 0.06 * d, 0.025 * d, 16):
				hole.append(lc + Vector2(s * 0.02, 0) * d + p.rotated(s * up * 0.55))
			ci.draw_colored_polygon(hole, Color(edge, 0.55))
			if style == "striped":
				ci.draw_line(lc - Vector2(s * 0.08, 0).rotated(s * up * 0.55) * d, lc + Vector2(s * 0.08, 0).rotated(s * up * 0.55) * d, Color(1, 1, 1, 0.9), line * 1.4)
			DrawKit.outline(ci, loop, edge, line * 0.9)
		var knot := DrawKit.ellipse(c + Vector2(s * 0.28, 0) * d, 0.05 * d, 0.07 * d, 16)
		DrawKit.gradient_fill(ci, knot, fill.lightened(0.15), fill.darkened(0.15))
		DrawKit.outline(ci, knot, edge, line * 0.8)


## A lollipop stick poking out to the lower right.
static func _draw_stick(ci: CanvasItem, c: Vector2, d: float, line: float, selected: bool) -> void:
	var a := c + Vector2(0.1, 0.06) * d
	var b := c + Vector2(0.47, 0.3) * d
	if selected:
		ci.draw_line(a, b, Color.WHITE, d * 0.075 + line * 4.0, true)
	ci.draw_line(a, b, Color("8f8577"), d * 0.075, true)
	ci.draw_line(a, b, Color("fbf6ec"), d * 0.075 - line * 1.6, true)
	ci.draw_circle(b, d * 0.0375, Color("8f8577"), true, -1.0, true)
	ci.draw_circle(b, d * 0.0375 - line * 0.8, Color("fbf6ec"), true, -1.0, true)


## A pleated paper cup holding the lower half of the sweet (drawn in front).
static func _draw_cup(ci: CanvasItem, c: Vector2, d: float, fill: Color, edge: Color, style: String, line: float, selected: bool) -> void:
	var pts := PackedVector2Array()
	var scallops := 7
	for k in scallops * 4 + 1:
		var t := float(k) / (scallops * 4)
		var x := -0.38 + 0.76 * t
		pts.append(c + Vector2(x, 0.03 - absf(sin(t * scallops * PI)) * 0.035) * d)
	pts.append(c + Vector2(0.29, 0.34) * d)
	pts.append(c + Vector2(-0.29, 0.34) * d)
	if selected:
		DrawKit.outline(ci, pts, Color.WHITE, line * 4.0)
	DrawKit.gradient_fill(ci, pts, _wrap_top(fill, style), _wrap_bottom(fill, style).darkened(0.08))
	for k in range(1, 8):
		var t := k / 8.0
		ci.draw_line(c + Vector2(-0.36 + 0.72 * t, 0.06) * d, c + Vector2(-0.27 + 0.54 * t, 0.32) * d, Color(edge, 0.5), line * 0.8, true)
	if style == "striped":
		ci.draw_line(c + Vector2(-0.33, 0.18) * d, c + Vector2(0.33, 0.18) * d, Color(1, 1, 1, 0.9), line * 2.0)
	ci.draw_polyline(PackedVector2Array([c + Vector2(-0.34, 0.07) * d, c + Vector2(0.34, 0.07) * d]), Color(1, 1, 1, 0.35), line, true)
	DrawKit.outline(ci, pts, edge, line * 0.9)


static func _wrap_top(fill: Color, style: String) -> Color:
	return fill.lightened(0.45 if style == "foil" else 0.25)


static func _wrap_bottom(fill: Color, style: String) -> Color:
	return fill.darkened(0.2 if style == "foil" else 0.08)


## A small decorative jar with candies (home counter, icons, cards).
## `bottom` = bottom centre; `types` bottom -> top; lid < 0 = no lid.
static func draw_mini_jar(ci: CanvasItem, bottom: Vector2, w: float, types: Array, lid_type: int = -1, glass: Color = Color("dcefee"), rim: Color = Color("8fb9bd")) -> void:
	var slot := w * 0.78
	var step := slot * 0.78
	var n := maxi(4, types.size())
	var h := w * 0.16 + n * step + w * 0.1
	var body := DrawKit.rounded_rect(Rect2(bottom.x - w * 0.5, bottom.y - h, w, h), w * 0.2, 6)
	ci.draw_colored_polygon(DrawKit.ellipse(bottom + Vector2(0, 2), w * 0.55, w * 0.07, 20), Color(0.2, 0.12, 0.06, 0.2))
	ci.draw_colored_polygon(body, Color(glass, 0.45))
	for i in types.size():
		draw_candy(ci, bottom + Vector2(0, -w * 0.13 - step * (i + 0.5)), slot, int(types[i]))
	ci.draw_colored_polygon(body, Color(glass, 0.16))
	ci.draw_colored_polygon(DrawKit.rounded_rect(Rect2(bottom.x - w * 0.4, bottom.y - h + w * 0.2, w * 0.09, h - w * 0.4), w * 0.04, 3), Color(1, 1, 1, 0.5))
	DrawKit.outline(ci, body, rim, maxf(2.0, w * 0.03))
	var top := bottom.y - h
	if lid_type >= 0:
		var lc := GameData.candy_color(lid_type)
		var lid := DrawKit.rounded_rect(Rect2(bottom.x - w * 0.5, top - w * 0.17, w, w * 0.2), w * 0.06, 4)
		ci.draw_colored_polygon(lid, lc)
		DrawKit.outline(ci, lid, lc.darkened(0.4), maxf(2.0, w * 0.025))
		ci.draw_rect(Rect2(bottom.x - w * 0.4, top - w * 0.14, w * 0.8, w * 0.04), Color(1, 1, 1, 0.4))
	else:
		ci.draw_rect(Rect2(bottom.x - w * 0.42, top - w * 0.02, w * 0.84, w * 0.06), rim.lightened(0.2))
