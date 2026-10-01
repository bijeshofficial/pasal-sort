class_name PasalVisual
extends Control
## "Your pasal": the little corner shop behind the Play button. Every 10
## levels it gains a decoration (see data/meta.json). reveal(id) pops the
## newest one in with a bounce and sparkles. Drawn in code; final art can
## replace this scene without touching the Home screen logic.

const Shopkeeper := preload("res://scenes/components/shopkeeper_visual.tscn")

var owned: Array = []
var theme_id := "theme_asan"
var shopkeeper: ShopkeeperVisual

var _counter: Node2D
var _reveal := {}   # id -> scale 0..1 while animating
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	shopkeeper = Shopkeeper.instantiate()
	add_child(shopkeeper)
	# The counter draws above the shopkeeper.
	_counter = Node2D.new()
	add_child(_counter)
	_counter.draw.connect(func() -> void: draw_counter(_counter))
	resized.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	_counter.queue_redraw()


func set_decorations(ids: Array) -> void:
	owned = ids.duplicate()
	queue_redraw()


func has_deco(id: String) -> bool:
	return owned.has(id)


func _layout() -> void:
	if shopkeeper == null:
		return
	var u := size.x / 1080.0
	shopkeeper.unit = 0.82 * u
	shopkeeper.position = Vector2(size.x * 0.5, _counter_top())
	queue_redraw()


func _counter_top() -> float:
	return size.y - 300.0 * (size.x / 1080.0)


## On tall screens the shop front slides down to meet the counter; the
## extra height becomes street and sky above it.
func _oy() -> float:
	return maxf(0.0, _counter_top() - 660.0 * (size.x / 1080.0))


## Pops decoration `id` in (scale 0 -> 1) with sparkles at its anchor.
func reveal(id: String) -> void:
	if not owned.has(id):
		owned.append(id)
	_reveal[id] = 0.0
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_reveal[id] = v
		queue_redraw(), 0.0, 1.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _reveal.erase(id))
	AudioManager.play("reward")
	VFXManager.sparkle(self, global_position + anchor(id), UIKit.GOLD, 1.6)


func anchor(id: String) -> Vector2:
	var u := size.x / 1080.0
	var ct := _counter_top()
	var up := Vector2(0, _oy())
	match id:
		"fairy_lights": return Vector2(540, 250) * u + up
		"marigold": return Vector2(95 * u, size.y - 20 * u)
		"radio": return Vector2(415 * u, ct)
		"cat": return Vector2(680 * u, ct)
		"shelf": return Vector2(540 * u, 520 * u) + up
		"sign": return Vector2(540, 95) * u + up
		"bunting": return Vector2(540, 200) * u + up
		"kettle": return Vector2(185 * u, ct)
		"scale": return Vector2(895 * u, ct)
		"lantern": return Vector2(230, 280) * u + up
		"awning": return Vector2(540, 170) * u + up
		"bicycle": return Vector2(990 * u, size.y - 10 * u)
	return size * 0.5


func _draw() -> void:
	var w := size.x
	var h := size.y
	var u := w / 1080.0
	var ct := _counter_top()
	var oy := _oy()
	# The screen's backdrop shows through; a soft glow sits behind the shop.
	for k in 6:
		var rr := (620.0 - k * 70.0) * u
		draw_colored_polygon(DrawKit.ellipse(Vector2(w * 0.5, ct - 160 * u), rr, rr * 0.75, 40), Color(1, 1, 1, 0.035))
	# Himalayan skyline and a few clouds (seen on taller screens).
	var base_y := 200.0 * u + oy
	for k in 3:
		var cx := w * (0.2 + 0.32 * k)
		var cy := base_y - (300.0 + 90.0 * (k % 2)) * u
		if cy - 50.0 * u > 0:
			for b in 3:
				draw_circle(Vector2(cx + (b - 1) * 46 * u, cy + (8 if b != 1 else -12) * u), (34 if b != 1 else 48) * u, Color(1, 1, 1, 0.85), true, -1.0, true)
	var peaks := [[0.05, 170.0], [0.24, 250.0], [0.42, 200.0], [0.62, 280.0], [0.83, 210.0], [1.02, 240.0]]
	# Keep every peak whole: shrink the range to fit the space above the shop.
	var fit := minf(1.0, (base_y - 18.0 * u) / (280.0 * u))
	for pk in peaks:
		var px: float = w * float(pk[0])
		var ph: float = float(pk[1]) * u * fit
		draw_colored_polygon(PackedVector2Array([Vector2(px - ph * 1.1, base_y), Vector2(px, base_y - ph), Vector2(px + ph * 1.1, base_y)]), Color(1, 1, 1, 0.16))
		draw_colored_polygon(PackedVector2Array([Vector2(px - ph * 0.3, base_y - ph * 0.72), Vector2(px, base_y - ph), Vector2(px + ph * 0.3, base_y - ph * 0.72), Vector2(px + ph * 0.1, base_y - ph * 0.64), Vector2(px - ph * 0.08, base_y - ph * 0.7)]), Color(1, 1, 1, 0.35))
	# Ground shadow under the shop.
	draw_colored_polygon(DrawKit.ellipse(Vector2(w * 0.5, h - 6 * u), 520 * u, 34 * u, 40), Color(0.05, 0.02, 0.2, 0.35))
	draw_set_transform(Vector2(0, oy))
	# Interior.
	var inner := Rect2(170 * u, 250 * u, 740 * u, ct - oy - 250 * u + 10 * u)
	draw_rect(inner, Color("ffd9a8"))
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 18 * u)), Color(0, 0, 0, 0.12))
	var shelves := [360.0, 470.0]
	if has_deco("shelf"):
		shelves.append(580.0)
	for i in shelves.size():
		_draw_shelf_row(float(shelves[i]) * u, u, i, _deco_scale("shelf") if i == 2 else 1.0)
	# Brick pillars and carved beam.
	for x in [90.0, 910.0]:
		var pr := Rect2(x * u, 150 * u, 80 * u, h - 150 * u)
		draw_rect(pr, Color("e8604a"))
		var y := pr.position.y + 10 * u
		var row := 0
		while y < h:
			draw_line(Vector2(pr.position.x, y), Vector2(pr.end.x, y), Color("c2412f"), 3 * u)
			var off := 0.0 if row % 2 == 0 else 20.0 * u
			draw_line(Vector2(pr.position.x + 40 * u - off, y), Vector2(pr.position.x + 40 * u - off, y + 26 * u), Color("c2412f"), 3 * u)
			y += 26 * u
			row += 1
	var beam := Rect2(70 * u, 150 * u, 940 * u, 80 * u)
	draw_rect(beam, Color("b52f45"))
	for i in 30:
		var bx := beam.position.x + 14 * u + i * 31 * u
		draw_rect(Rect2(bx, beam.position.y + 16 * u, 18 * u, 18 * u), Color("ffc94a"))
		draw_rect(Rect2(bx + 4 * u, beam.position.y + 44 * u, 10 * u, 22 * u), Color("ffc94a"))
	# Rolled-up shutter under the beam.
	draw_rect(Rect2(170 * u, 230 * u, 740 * u, 28 * u), Color("c9d2f0"))
	draw_rect(Rect2(170 * u, 252 * u, 740 * u, 6 * u), Color("9aa5d4"))
	draw_set_transform(Vector2.ZERO)
	# Decorations behind the counter.
	if has_deco("awning"):
		_with(("awning"), func() -> void: _awning(u))
	if has_deco("sign"):
		_with("sign", func() -> void: _sign(u))
	if has_deco("bunting"):
		_with("bunting", func() -> void: _bunting(u))
	if has_deco("fairy_lights"):
		_with("fairy_lights", func() -> void: _fairy_lights(u))
	if has_deco("lantern"):
		_with("lantern", func() -> void: _lantern(u))


## Drawn by the child `_counter` node so the shopkeeper stands behind it.
func draw_counter(ci: CanvasItem) -> void:
	var w := size.x
	var h := size.y
	var u := w / 1080.0
	var ct := _counter_top()
	ci.draw_rect(Rect2(130 * u, ct, 820 * u, 34 * u), Color("ffd27e"))
	ci.draw_rect(Rect2(130 * u, ct + 30 * u, 820 * u, 6 * u), Color("d98a2b"))
	var front := Rect2(150 * u, ct + 36 * u, 780 * u, h - ct - 36 * u)
	ci.draw_rect(front, Color("ff6b5a"))
	for i in 3:
		var r := Rect2(front.position.x + 30 * u + i * 250 * u, front.position.y + 30 * u, 220 * u, front.size.y - 60 * u)
		if r.size.y > 10:
			ci.draw_rect(r, Color("e8473c"))
			ci.draw_rect(r, Color("ffc94a"), false, 4 * u)
	# Candy jars on the counter, clear of the shopkeeper and decorations.
	var jars := [[265.0, [0, 0, 0]], [330.0, [2, 2, 2, 2]], [790.0, [3, 3, 3]], [855.0, [10, 10, 10, 10]]]
	for jr in jars:
		if float(jr[0]) == 855.0 and has_deco("scale"):
			continue
		var types: Array = jr[1]
		CandyArt.draw_mini_jar(ci, Vector2(float(jr[0]) * u, ct + 4 * u), 60 * u, types, int(types[0]) if types.size() == 4 else -1)
	# Decorations on or in front of the counter.
	if has_deco("kettle"):
		_with("kettle", func() -> void: _kettle(ci, u), ci)
	if has_deco("radio"):
		_with("radio", func() -> void: _radio(ci, u), ci)
	if has_deco("cat"):
		_with("cat", func() -> void: _cat(ci, u), ci)
	if has_deco("scale"):
		_with("scale", func() -> void: _scale(ci, u), ci)
	if has_deco("marigold"):
		_with("marigold", func() -> void: _marigold(ci, u), ci)
	if has_deco("bicycle"):
		_with("bicycle", func() -> void: _bicycle(ci, u), ci)


func _deco_scale(id: String) -> float:
	return float(_reveal.get(id, 1.0))


## Draws `fn` scaled about the decoration's anchor while it is revealing.
func _with(id: String, fn: Callable, ci: CanvasItem = null) -> void:
	var target: CanvasItem = ci if ci != null else self
	var s := _deco_scale(id)
	if s <= 0.001:
		return
	var a := anchor(id)
	# Upper decorations are drawn in shop-front coordinates (before the shift).
	var shift := Vector2.ZERO if ci != null else Vector2(0, _oy())
	var base := a - shift
	target.draw_set_transform(base - base * s + shift, 0.0, Vector2(s, s))
	fn.call()
	target.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_shelf_row(y: float, u: float, row: int, s: float) -> void:
	if s <= 0.001:
		return
	var a := Vector2(540 * u, y)
	draw_set_transform(a - a * s + Vector2(0, _oy()), 0.0, Vector2(s, s))
	draw_rect(Rect2(180 * u, y, 720 * u, 14 * u), Color("c9773a"))
	var cols := [Color("ee8a1f"), Color("1d6b74"), Color("f2769f"), Color("f7c52e"), Color("44a5ec"), Color("b23a33"), Color("fff8ec")]
	var x := 200.0 * u
	var k := row * 3
	while x < 880 * u:
		var c: Color = cols[k % cols.size()]
		var bh := (52.0 + 18.0 * (k % 3)) * u
		if k % 4 == 1:
			CandyArt.draw_mini_jar(self, Vector2(x + 24 * u, y), 44 * u, [k % 12, (k + 3) % 12, k % 12], -1)
			x += 60 * u
		else:
			draw_rect(Rect2(x, y - bh, 46 * u, bh), c)
			draw_rect(Rect2(x + 6 * u, y - bh + 12 * u, 34 * u, 14 * u), Color(1, 1, 1, 0.55))
			x += 58 * u
		k += 1
	draw_set_transform(Vector2(0, _oy()), 0.0, Vector2.ONE)


func _fairy_lights(u: float) -> void:
	var cols := [Color("f2b632"), Color("e2493f"), Color("44a5ec"), Color("f2769f"), Color("fff8ec")]
	var prev := Vector2.ZERO
	for i in 25:
		var t := i / 24.0
		var p := Vector2((110 + 860 * t) * u, (238 + absf(sin(t * PI * 6.0)) * 26) * u)
		if i > 0:
			draw_line(prev, p, Color("3a2a20"), 2 * u, true)
		prev = p
		var on := int(_t * 3.0 + i) % 5 != 0
		var c: Color = cols[i % cols.size()]
		draw_circle(p + Vector2(0, 9 * u), 8 * u, c if on else c.darkened(0.35), true, -1.0, true)


func _sign(u: float) -> void:
	var r := Rect2(300 * u, 40 * u, 480 * u, 104 * u)
	draw_rect(r.grow(8 * u), Color("b52f45"))
	draw_rect(r, Color("fff3dc"))
	var f := UIKit.font(true)
	var fs := int(70 * u)
	var text := "PASAL"
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(r.get_center().x - tw * 0.5, r.position.y + 78 * u), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("b23a33"))
	for x in [r.position.x + 36 * u, r.end.x - 36 * u]:
		draw_circle(Vector2(x, r.get_center().y), 18 * u, Color("f39a1e"), true, -1.0, true)
		draw_circle(Vector2(x, r.get_center().y), 8 * u, Color("f7c52e"), true, -1.0, true)


func _bunting(u: float) -> void:
	var cols := [Color("e2493f"), Color("f2b632"), Color("1d6b74"), Color("f2769f"), Color("44a5ec")]
	for i in 16:
		var x0 := (80 + i * 58) * u
		var sag := sin(float(i) / 15.0 * PI) * 12 * u
		var tri := PackedVector2Array([Vector2(x0, 150 * u + sag), Vector2(x0 + 50 * u, 150 * u + sag), Vector2(x0 + 25 * u, 200 * u + sag)])
		draw_colored_polygon(tri, cols[i % cols.size()])
	draw_line(Vector2(80 * u, 150 * u), Vector2(1010 * u, 150 * u), Color("3a2a20"), 3 * u)


func _awning(u: float) -> void:
	var top := 120.0 * u
	var bottom := 214.0 * u
	var n := 12
	var sw := 940.0 * u / n
	for i in n:
		var x := 70 * u + i * sw
		draw_colored_polygon(PackedVector2Array([Vector2(x + 10 * u, top), Vector2(x + sw + 10 * u, top), Vector2(x + sw, bottom), Vector2(x, bottom)]), UIKit.PRIMARY if i % 2 == 0 else Color("fff3dc"))
		draw_circle(Vector2(x + sw * 0.5, bottom), sw * 0.5, UIKit.PRIMARY if i % 2 == 0 else Color("fff3dc"), true, -1.0, true)


func _lantern(u: float) -> void:
	var swing := sin(_t * 1.6) * 0.06
	var top := Vector2(230, 232) * u + Vector2(0, _oy())
	draw_set_transform(top, swing, Vector2.ONE)
	draw_line(Vector2.ZERO, Vector2(0, 30 * u), Color("3a2a20"), 3 * u)
	draw_colored_polygon(DrawKit.ellipse(Vector2(0, 80 * u), 42 * u, 52 * u, 28), Color("d8483a"))
	for k in 3:
		draw_arc(Vector2(0, 80 * u), 42 * u * (0.35 + 0.3 * k), PI * 0.5 - 1.2, PI * 0.5 + 1.2, 12, Color("a2322a"), 3 * u, true)
	draw_rect(Rect2(-20 * u, 26 * u, 40 * u, 10 * u), Color("f2b632"))
	draw_rect(Rect2(-20 * u, 126 * u, 40 * u, 10 * u), Color("f2b632"))
	draw_line(Vector2(0, 136 * u), Vector2(0, 166 * u), Color("f2b632"), 4 * u)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _kettle(ci: CanvasItem, u: float) -> void:
	var b := anchor("kettle")
	ci.draw_colored_polygon(DrawKit.ellipse(b + Vector2(0, -36 * u), 44 * u, 36 * u, 24), Color("9aa3a8"))
	ci.draw_rect(Rect2(b + Vector2(-30, -8) * u, Vector2(60, 8) * u), Color("7f898f"))
	ci.draw_colored_polygon(PackedVector2Array([b + Vector2(36, -40) * u, b + Vector2(76, -70) * u, b + Vector2(80, -62) * u, b + Vector2(40, -26) * u]), Color("9aa3a8"))
	ci.draw_arc(b + Vector2(0, -70 * u), 28 * u, PI, TAU, 14, Color("3a2a20"), 6 * u, true)
	ci.draw_circle(b + Vector2(0, -74 * u), 7 * u, Color("3a2a20"), true, -1.0, true)


func _radio(ci: CanvasItem, u: float) -> void:
	var b := anchor("radio")
	var r := Rect2(b + Vector2(-60, -76) * u, Vector2(120, 76) * u)
	DrawKit.rrect(ci, r, 12 * u, Color("1d6b74"))
	ci.draw_circle(r.position + Vector2(38, 40) * u, 24 * u, Color("fff3dc"), true, -1.0, true)
	for k in 4:
		ci.draw_line(r.position + Vector2(20, 30 + k * 7) * u, r.position + Vector2(56, 30 + k * 7) * u, Color("7a6656"), 2 * u)
	ci.draw_rect(Rect2(r.position + Vector2(74, 20) * u, Vector2(34, 12) * u), Color("f2b632"))
	ci.draw_circle(r.position + Vector2(90, 54) * u, 9 * u, Color("f2b632"), true, -1.0, true)
	ci.draw_line(r.position + Vector2(100, 0) * u, r.position + Vector2(140, -60) * u, Color("3a2a20"), 3 * u, true)


func _cat(ci: CanvasItem, u: float) -> void:
	var b := anchor("cat")
	var breathe := 1.0 + sin(_t * 2.2) * 0.03
	ci.draw_colored_polygon(DrawKit.ellipse(b + Vector2(0, -30 * u), 70 * u, 32 * u * breathe, 28), Color("e8a15c"))
	ci.draw_colored_polygon(DrawKit.ellipse(b + Vector2(-54, -36) * u, 30 * u, 26 * u, 20), Color("e8a15c"))
	for sx in [-1.0, 1.0]:
		var ear := b + Vector2(-54 + sx * 16, -58) * u
		ci.draw_colored_polygon(PackedVector2Array([ear + Vector2(-10, 8) * u, ear + Vector2(0, -14) * u, ear + Vector2(10, 8) * u]), Color("d88a45"))
	ci.draw_arc(b + Vector2(-62, -36) * u, 7 * u, 0.2, PI - 0.2, 8, Color("5a3421"), 3 * u, true)
	ci.draw_arc(b + Vector2(-44, -36) * u, 7 * u, 0.2, PI - 0.2, 8, Color("5a3421"), 3 * u, true)
	for k in 3:
		ci.draw_line(b + Vector2(-10 + k * 22, -58) * u, b + Vector2(-4 + k * 22, -34) * u, Color("c9783a"), 5 * u, true)
	ci.draw_arc(b + Vector2(60, -18) * u, 26 * u, -PI * 0.5, PI * 0.6, 14, Color("e8a15c"), 14 * u, true)
	# Floating "z".
	var z := fmod(_t * 0.5, 1.0)
	var f := UIKit.font(true)
	ci.draw_string(f, b + Vector2(-80, -80 - z * 50) * u, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(34 * u), Color(0.2, 0.15, 0.1, 1.0 - z))


func _scale(ci: CanvasItem, u: float) -> void:
	var b := anchor("scale")
	var brass := Color("d6a53a")
	ci.draw_rect(Rect2(b + Vector2(-40, -12) * u, Vector2(80, 12) * u), brass.darkened(0.2))
	ci.draw_line(b + Vector2(0, -12 * u), b + Vector2(0, -110 * u), brass.darkened(0.2), 7 * u)
	ci.draw_line(b + Vector2(-60, -104) * u, b + Vector2(60, -104) * u, brass, 6 * u)
	for sx in [-1.0, 1.0]:
		var p := b + Vector2(sx * 60, -104) * u
		ci.draw_line(p, p + Vector2(-16, 40) * u, brass.darkened(0.3), 2 * u)
		ci.draw_line(p, p + Vector2(16, 40) * u, brass.darkened(0.3), 2 * u)
		ci.draw_colored_polygon(DrawKit.ellipse(p + Vector2(0, 44) * u, 30 * u, 8 * u, 16), brass)


func _marigold(ci: CanvasItem, u: float) -> void:
	var b := anchor("marigold")
	var pot := PackedVector2Array([b + Vector2(-44, -80) * u, b + Vector2(44, -80) * u, b + Vector2(32, 0), b + Vector2(-32, 0)])
	pot[2] = b + Vector2(32, 0) * u
	pot[3] = b + Vector2(-32, 0) * u
	ci.draw_colored_polygon(pot, Color("b5533c"))
	ci.draw_rect(Rect2(b + Vector2(-50, -92) * u, Vector2(100, 16) * u), Color("8e3f2d"))
	for k in 5:
		ci.draw_line(b + Vector2(-20 + k * 10, -92) * u, b + Vector2(-40 + k * 20, -150) * u, Color("4f8a3a"), 5 * u, true)
	for k in 5:
		var p := b + Vector2(-40 + k * 20, -150 - (k % 2) * 18) * u
		ci.draw_circle(p, 20 * u, Color("f39a1e"), true, -1.0, true)
		ci.draw_circle(p, 10 * u, Color("f7c52e"), true, -1.0, true)


func _bicycle(ci: CanvasItem, u: float) -> void:
	var b := anchor("bicycle") + Vector2(-80, -60) * u
	var dark := Color("2f3a40")
	for sx in [-1.0, 1.0]:
		ci.draw_arc(b + Vector2(sx * 60, 0) * u, 46 * u, 0, TAU, 28, dark, 7 * u, true)
	ci.draw_polyline(PackedVector2Array([b + Vector2(-60, 0) * u, b + Vector2(-10, -60) * u, b + Vector2(40, -60) * u, b + Vector2(60, 0) * u]), UIKit.SECONDARY, 8 * u, true)
	ci.draw_line(b + Vector2(-10, -60) * u, b + Vector2(0, 0) * u, UIKit.SECONDARY, 8 * u, true)
	ci.draw_line(b + Vector2(40, -60) * u, b + Vector2(50, -86) * u, dark, 6 * u)
	ci.draw_rect(Rect2(b + Vector2(-30, -74) * u, Vector2(40, 10) * u), dark)
	ci.draw_rect(Rect2(b + Vector2(56, -100) * u, Vector2(50, 36) * u), Color("c98c58"))
