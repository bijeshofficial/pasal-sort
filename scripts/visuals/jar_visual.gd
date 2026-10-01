class_name JarVisual
extends Node2D
## A clear Nepali candy jar, drawn in code. Origin = bottom centre.
## Layers: this node draws the back glass, `candies` holds CandyVisuals,
## `front` draws the glass tint, highlights, label, lid, cloth and padlock.
## Gameplay only uses the public API below, so final art can replace it.

signal lid_closed

var jar_width := 180.0
var slots := 4
var skin: Dictionary = {}
var home_position := Vector2.ZERO

var done := false
var lid_color := Color.WHITE
var lid_drop := 0.0       # 0 = seated, 1 = high above
var lid_squash := 1.0
var cloth_on := false
var cloth_slide := 0.0    # 0 = covering, 1 = gone
var lock_type := -1
var lock_open := 0.0      # 0 = locked, 1 = open & gone
var shine := -1.0         # sweep position; <0 = off
var shine_color := Color(1.0, 0.86, 0.45, 0.55)
var selected := false
var dimmed := false

var candies: Node2D
var front: Node2D

var _tween: Tween
var _bump: Tween

const POUR_TRAVEL := 0.18
const POUR_TILT := 0.1
var _body: PackedVector2Array = PackedVector2Array()


func _init() -> void:
	candies = Node2D.new()
	candies.name = "Candies"
	add_child(candies)
	front = Node2D.new()
	front.name = "Front"
	add_child(front)
	front.draw.connect(_draw_front)


func setup(width: float, slot_count: int, skin_data: Dictionary) -> void:
	jar_width = width
	slots = slot_count
	skin = skin_data
	_body = _body_polygon()
	queue_redraw()
	front.queue_redraw()


# --- Geometry ----------------------------------------------------------------

func candy_diameter() -> float:
	return jar_width * 0.8


func slot_step() -> float:
	return candy_diameter() * 0.8


func base_height() -> float:
	return jar_width * 0.13


func body_height() -> float:
	return base_height() + slots * slot_step() + jar_width * 0.12


func neck_height() -> float:
	return jar_width * 0.1


func total_height() -> float:
	return body_height() + neck_height() + jar_width * 0.07


## Local position of the centre of candy slot i (0 = bottom).
func slot_position(i: int) -> Vector2:
	return Vector2(0, -base_height() - slot_step() * (i + 0.5) - candy_diameter() * 0.04)


## Area that accepts taps (generous, includes the space above the jar).
func hit_rect() -> Rect2:
	var h := total_height() + jar_width * 0.5
	return Rect2(-jar_width * 0.62, -h, jar_width * 1.24, h + jar_width * 0.2)


func _body_polygon() -> PackedVector2Array:
	var w := jar_width
	var bh := body_height()
	var body := DrawKit.rounded_rect(Rect2(-w * 0.5, -bh, w, bh), w * 0.2, 8)
	var nw := w * 0.8
	var neck := DrawKit.rounded_rect(Rect2(-nw * 0.5, -bh - neck_height() - w * 0.06, nw, neck_height() + w * 0.2), w * 0.04, 3)
	var merged := Geometry2D.merge_polygons(body, neck)
	return merged[0] if not merged.is_empty() else body


# --- Drawing -----------------------------------------------------------------

func _skin_color(key: String, fallback: String) -> Color:
	return Color.html(String(skin.get(key, fallback)))


func _draw() -> void:
	var w := jar_width
	var glass := _skin_color("glass", "dcefee")
	var base := _skin_color("base", "b8d6d6")
	# Shadow on the shelf.
	draw_colored_polygon(DrawKit.ellipse(Vector2(0, 2), w * 0.56, w * 0.07, 28), Color(0.2, 0.12, 0.06, 0.22))
	# Back glass.
	draw_colored_polygon(_body, Color(glass, 0.2))
	# Inside back wall of the neck (the opening).
	var top := -body_height() - neck_height() - w * 0.06
	draw_colored_polygon(DrawKit.ellipse(Vector2(0, top + w * 0.03), w * 0.38, w * 0.05, 24), Color(glass.darkened(0.25), 0.55))
	# Thick glass base.
	var bh := base_height()
	draw_colored_polygon(DrawKit.rounded_rect(Rect2(-w * 0.46, -bh, w * 0.92, bh - 3), w * 0.12, 5), Color(base, 0.75))


func _draw_front() -> void:
	var f := front
	var w := jar_width
	var glass := _skin_color("glass", "dcefee")
	var rim := _skin_color("rim", "8fb9bd")
	var rim_w := float(skin.get("rim_width", 1.0))
	var bh := body_height()
	# Glass tint over the candies.
	f.draw_colored_polygon(_body, Color(glass, 0.08))
	# Skin effects.
	match String(skin.get("fx", "")):
		"diyo":
			for i in 5:
				var p := Vector2(w * (-0.3 + 0.15 * i), -bh * (0.25 + 0.13 * float(i % 3)))
				f.draw_circle(p, w * 0.035, Color(1.0, 0.72, 0.25, 0.55), true, -1.0, true)
				f.draw_circle(p, w * 0.016, Color(1.0, 0.95, 0.75, 0.9), true, -1.0, true)
		"frost":
			for i in 14:
				var ang := float(i) * 1.7
				var p := Vector2(-w * 0.42 + fmod(i * 37.0, w * 0.2), -w * 0.08 - fmod(i * 23.0, w * 0.5))
				if i % 2 == 1:
					p.x = -p.x
				f.draw_line(p - Vector2(cos(ang), sin(ang)) * w * 0.03, p + Vector2(cos(ang), sin(ang)) * w * 0.03, Color(1, 1, 1, 0.8), 2.0, true)
	# Highlight streaks.
	f.draw_colored_polygon(DrawKit.rounded_rect(Rect2(-w * 0.4, -bh + w * 0.2, w * 0.09, bh - w * 0.42), w * 0.045, 4), Color(1, 1, 1, 0.5))
	f.draw_colored_polygon(DrawKit.rounded_rect(Rect2(-w * 0.26, -bh + w * 0.24, w * 0.035, bh * 0.32), w * 0.02, 3), Color(1, 1, 1, 0.35))
	f.draw_colored_polygon(DrawKit.rounded_rect(Rect2(w * 0.33, -bh + w * 0.3, w * 0.04, bh * 0.45), w * 0.02, 3), Color(1, 1, 1, 0.22))
	# Shine sweep after a lid closes (coin-coloured band clipped to the glass).
	if shine >= 0.0:
		var x := lerpf(-w * 1.1, w * 1.1, shine)
		var band := PackedVector2Array([Vector2(x - w * 0.12, 0), Vector2(x + w * 0.12, 0), Vector2(x + w * 0.52, -bh - w), Vector2(x + w * 0.28, -bh - w)])
		for part in Geometry2D.intersect_polygons(_body, band):
			f.draw_colored_polygon(part, shine_color)
	# Glass outline and rim lip.
	DrawKit.outline(f, _body, Color(rim.lerp(Color.WHITE, 0.55), 0.95), maxf(3.5, w * 0.024) * rim_w)
	var top := -bh - neck_height() - w * 0.06
	var lip := DrawKit.rounded_rect(Rect2(-w * 0.45, top - w * 0.02, w * 0.9, w * 0.07), w * 0.035, 4)
	f.draw_colored_polygon(lip, Color(rim.lightened(0.25), 0.9))
	DrawKit.outline(f, lip, rim, maxf(2.0, w * 0.015) * rim_w)
	# Label strip with a little hand-drawn doodle (decorative only).
	var lh := w * 0.12
	var label := DrawKit.rounded_rect(Rect2(-w * 0.3, -base_height() * 0.5 - lh * 0.5 - w * 0.02, w * 0.6, lh), w * 0.03, 3)
	f.draw_colored_polygon(label, Color("fbf1dc"))
	DrawKit.outline(f, label, Color("c9a86f"), 2.0)
	var ly := -base_height() * 0.5 - w * 0.045
	var ink := Color("b4472f")
	f.draw_line(Vector2(-w * 0.22, ly), Vector2(w * 0.22, ly), ink, maxf(2.0, w * 0.014))
	for k in 4:
		var x0 := -w * 0.18 + k * w * 0.11
		f.draw_arc(Vector2(x0, ly + w * 0.035), w * 0.025, -PI * 0.5, PI * 0.9, 8, ink, maxf(1.5, w * 0.011), true)
		f.draw_line(Vector2(x0 + w * 0.03, ly), Vector2(x0 + w * 0.03, ly + w * 0.055), ink, maxf(1.5, w * 0.011))
	# Cloth, padlock, lid.
	if cloth_on or (cloth_slide > 0.0 and cloth_slide < 1.0):
		_draw_cloth(f)
	if lock_type >= 0 and lock_open < 1.0:
		_draw_lock(f)
	if done:
		_draw_lid(f, top)
	if dimmed:
		f.draw_colored_polygon(_body, Color(0.2, 0.14, 0.1, 0.18))


func _draw_lid(f: Node2D, top: float) -> void:
	var w := jar_width
	var style := String(skin.get("lid", "candy"))
	var col := lid_color
	if style == "steel":
		col = Color("a9b3b9")
	elif style == "gold":
		col = Color("d9a72b")
	var lw := w * 0.98 * (2.0 - lid_squash)
	var lh := w * 0.2 * lid_squash
	var y := top - lh + w * 0.03 - lid_drop * w * 2.2
	var r := Rect2(-lw * 0.5, y, lw, lh)
	f.draw_colored_polygon(DrawKit.rounded_rect(r.grow(3), w * 0.07, 5), col.darkened(0.4))
	f.draw_colored_polygon(DrawKit.rounded_rect(r, w * 0.065, 5), col)
	# Screw ridges and a top highlight.
	for k in 9:
		var x := r.position.x + lw * (0.1 + 0.1 * k)
		f.draw_line(Vector2(x, y + lh * 0.35), Vector2(x, y + lh * 0.85), col.darkened(0.22), maxf(2.0, w * 0.012))
	f.draw_colored_polygon(DrawKit.rounded_rect(Rect2(r.position.x + lw * 0.08, y + lh * 0.1, lw * 0.84, lh * 0.18), lh * 0.09, 3), Color(1, 1, 1, 0.45))
	if style != "candy":
		f.draw_rect(Rect2(r.position.x + 4, y + lh * 0.62, lw - 8, lh * 0.2), lid_color)


func _draw_cloth(f: Node2D) -> void:
	var w := jar_width
	var t := cloth_slide
	var off := Vector2(w * 1.2 * t, -w * 0.5 * t)
	var a := 1.0 - t
	var top := -body_height() - neck_height() - w * 0.16
	var r := Rect2(-w * 0.56, top, w * 1.12, -top + w * 0.02)
	var drape := DrawKit.rounded_rect(r, w * 0.34, 8)
	var shifted := PackedVector2Array()
	for p in drape:
		shifted.append(p + off)
	var base := Color("a8302b")
	f.draw_colored_polygon(shifted, Color(base, a))
	# Dhaka weave: horizontal bands of little triangles in bright threads.
	var band_cols := [Color("f2b632"), Color("1f2a36"), Color("fff3e0"), Color("ee8a1f")]
	var tri := w * 0.14
	var y := top + w * 0.3
	var band := 0
	while y < -w * 0.12:
		var col: Color = band_cols[band % band_cols.size()]
		var x := r.position.x + w * 0.06
		while x + tri <= r.end.x - w * 0.05:
			var up := band % 2 == 0
			var pts := PackedVector2Array([
				Vector2(x, y + (tri * 0.5 if up else 0.0)) + off,
				Vector2(x + tri * 0.5, y + (0.0 if up else tri * 0.5)) + off,
				Vector2(x + tri, y + (tri * 0.5 if up else 0.0)) + off])
			f.draw_colored_polygon(pts, Color(col, a))
			x += tri
		f.draw_line(Vector2(r.position.x + w * 0.04, y + tri * 0.62) + off, Vector2(r.end.x - w * 0.04, y + tri * 0.62) + off, Color(Color("1f2a36"), a * 0.8), maxf(2.0, w * 0.015))
		y += w * 0.34
		band += 1
	DrawKit.outline(f, shifted, Color(base.darkened(0.35), a), maxf(2.0, w * 0.02))
	# Fringe along the hem and a tassel on top.
	var k := 0
	var fx := r.position.x + w * 0.08
	while fx < r.end.x - w * 0.06:
		f.draw_line(Vector2(fx, r.end.y - w * 0.02) + off, Vector2(fx, r.end.y + w * 0.06) + off, Color(Color("f2b632") if k % 2 == 0 else Color("fff3e0"), a), maxf(2.0, w * 0.02))
		fx += w * 0.09
		k += 1
	f.draw_circle(Vector2(0, top + w * 0.02) + off, w * 0.07, Color(Color("f2b632"), a), true, -1.0, true)
	f.draw_line(Vector2(0, top + w * 0.02) + off, Vector2(0, top - w * 0.12) + off, Color(Color("f2b632"), a), maxf(2.0, w * 0.025))


func _draw_lock(f: Node2D) -> void:
	var w := jar_width
	var t := lock_open
	var a := 1.0 - clampf((t - 0.5) * 2.0, 0.0, 1.0)
	var c := Vector2(0, -body_height() * 0.45 + t * w * 0.4)
	var brass := Color(Color("d6a53a"), a)
	var brass_dark := Color(Color("8e6a1c"), a)
	# Shackle (lifts open).
	var lift := minf(t * 2.0, 1.0) * w * 0.16
	f.draw_arc(c + Vector2(0, -w * 0.14 - lift), w * 0.19, PI, TAU, 20, brass_dark, w * 0.09, true)
	f.draw_arc(c + Vector2(0, -w * 0.14 - lift), w * 0.19, PI, TAU, 20, brass, w * 0.05, true)
	var body := DrawKit.rounded_rect(Rect2(c.x - w * 0.34, c.y - w * 0.15, w * 0.68, w * 0.5), w * 0.1, 6)
	f.draw_colored_polygon(body, brass)
	DrawKit.outline(f, body, brass_dark, maxf(2.5, w * 0.025))
	f.draw_rect(Rect2(c.x - w * 0.3, c.y - w * 0.11, w * 0.6, w * 0.05), Color(1, 1, 1, 0.3 * a))
	# Badge: which candy opens it.
	var bc := c + Vector2(0, w * 0.1)
	f.draw_circle(bc, w * 0.2, Color(brass_dark, a), true, -1.0, true)
	f.draw_circle(bc, w * 0.17, Color(Color("5a4630") if lock_type == 5 else Color("fff8ec"), a), true, -1.0, true)
	if a > 0.99:
		CandyArt.draw_candy(f, bc, w * 0.5, lock_type, "classic", false, false)


# --- Public API --------------------------------------------------------------

func place(pos: Vector2) -> void:
	home_position = pos
	position = pos + (Vector2(0, -30) if selected else Vector2.ZERO)


func move_home(pos: Vector2, duration: float = 0.3) -> void:
	home_position = pos
	var tw := create_tween()
	tw.tween_property(self, "position", pos + (Vector2(0, -30) if selected else Vector2.ZERO), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Selected jar lifts 30 px and tilts 5 degrees.
func set_selected(on: bool) -> void:
	selected = on
	z_index = 0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	var target := home_position + (Vector2(0, -30) if on else Vector2.ZERO)
	_tween.tween_property(self, "position", target, 0.16 if on else 0.2).set_trans(Tween.TRANS_BACK if on else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation", deg_to_rad(5.0) if on else 0.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Local position of the jar's mouth (where candies pour out).
func mouth_local() -> Vector2:
	return Vector2(0, -total_height() + jar_width * 0.05)


## Pour: fly to `pos`, tilt to `angle`, hold while candies leave, swing home.
func pour(pos: Vector2, angle: float, hold: float) -> void:
	selected = false
	if _tween:
		_tween.kill()
	z_index = 10
	_tween = create_tween()
	_tween.tween_property(self, "position", pos, POUR_TRAVEL).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "rotation", angle * 0.55, POUR_TRAVEL).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "rotation", angle, POUR_TILT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold)
	_tween.tween_property(self, "rotation", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "position", home_position, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func() -> void: z_index = 0)


## Idle life: a soft white glint sweeps across the glass.
func glint() -> void:
	if shine >= 0.0:
		return
	shine_color = Color(1, 1, 1, 0.3)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		shine = v
		front.queue_redraw(), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		shine = -1.0
		front.queue_redraw())


## A candy landed: a quick jelly squash.
func land_bump() -> void:
	if _bump:
		_bump.kill()
	_bump = create_tween()
	_bump.tween_property(self, "scale", Vector2(1.035, 0.965), 0.05)
	_bump.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Illegal move: the target wobbles.
func wobble() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	for k in [7.0, -6.0, 4.0, -2.0, 0.0]:
		_tween.tween_property(self, "rotation", deg_to_rad(k), 0.05)
	_tween.parallel().tween_property(self, "position", home_position, 0.1)


func bounce(amount: float = 1.08) -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.0 / amount, amount), 0.08)
	tw.tween_property(self, "scale", Vector2(amount, 1.0 / amount), 0.08)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Lid drops on with squash-and-stretch, then a coin-coloured shine sweeps.
func close_lid(color: Color, animate: bool = true) -> void:
	done = true
	lid_color = color
	if not animate:
		lid_drop = 0.0
		lid_squash = 1.0
		front.queue_redraw()
		return
	lid_drop = 1.0
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		lid_drop = v
		front.queue_redraw(), 1.0, 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		lid_closed.emit()
		bounce(1.1))
	tw.tween_method(func(v: float) -> void:
		lid_squash = v
		front.queue_redraw(), 0.62, 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: shine_color = Color(1.0, 0.86, 0.45, 0.55))
	tw.tween_method(func(v: float) -> void:
		shine = v
		front.queue_redraw(), 0.0, 1.0, 0.45)
	tw.tween_callback(func() -> void:
		shine = -1.0
		front.queue_redraw())


func open_lid() -> void:
	done = false
	front.queue_redraw()


func set_cloth(on: bool, animate: bool = false) -> void:
	if on == cloth_on and (on or cloth_slide >= 1.0):
		return
	cloth_on = on
	if on or not animate:
		cloth_slide = 0.0 if on else 1.0
		front.queue_redraw()
		return
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		cloth_slide = v
		front.queue_redraw(), 0.0, 1.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func set_lock(type: int, locked: bool, animate: bool = false) -> void:
	lock_type = type
	if locked or not animate:
		lock_open = 0.0 if locked else 1.0
		front.queue_redraw()
		return
	if lock_open >= 1.0:
		return
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		lock_open = v
		front.queue_redraw(), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## Shuffle: the jar shakes.
func shake(duration: float = 0.5) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var n := int(duration / 0.05)
	for k in n:
		var amp := 10.0 * (1.0 - float(k) / n)
		_tween.tween_property(self, "position", home_position + Vector2(amp if k % 2 == 0 else -amp, 0), 0.05)
	_tween.tween_property(self, "position", home_position, 0.05)


## Hint: a gentle pulse until stopped.
func start_pulse() -> Tween:
	var tw := create_tween().set_loops(3)
	tw.tween_property(self, "scale", Vector2(1.06, 1.06), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)
	return tw


func set_dimmed(on: bool) -> void:
	if dimmed != on:
		dimmed = on
		front.queue_redraw()
