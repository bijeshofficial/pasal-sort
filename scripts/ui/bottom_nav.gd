class_name BottomNav
extends Control
## Shop | Home | Profile. Full-colour illustrated icons; the selected tab
## sits raised on a glossy gold plate that slides between tabs, the others
## rest smaller and dimmer. Red dots mark free shop gifts and claimable
## achievements.

signal tab_selected(index: int)

const TABS := [["shop", "Shop"], ["home", "Home"], ["profile", "Profile"]]
const BAR_H := 196.0

var current := 1
var _buttons: Array[Button] = []
var _icons: Array[Control] = []
var _labels: Array[Label] = []
var _dots: Array[Control] = []
var _plate: Control
var _plate_x := -1.0
var _lift: Array[float] = [0.0, 0.0, 0.0]
var _bottom_inset := 0.0


func _ready() -> void:
	_bottom_inset = UIKit.safe_bottom()
	custom_minimum_size = Vector2(0, BAR_H + _bottom_inset)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_plate = Control.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.draw.connect(_draw_plate)
	add_child(_plate)
	for i in TABS.size():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		add_child(b)
		var ic := Control.new()
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var id: String = TABS[i][0]
		var idx := i
		ic.draw.connect(func() -> void: _draw_icon(ic, id, idx == current))
		b.add_child(ic)
		var l := UIKit.title(TABS[i][1], 34)
		b.add_child(l)
		var dot := UIKit.red_dot(36)
		dot.visible = false
		b.add_child(dot)
		b.pressed.connect(func() -> void:
			AudioManager.play("button_click")
			HapticsManager.light()
			tab_selected.emit(idx))
		_buttons.append(b)
		_icons.append(ic)
		_labels.append(l)
		_dots.append(dot)
	resized.connect(func() -> void: _layout(false))
	select(current, false)


func set_dot(index: int, on: bool) -> void:
	_dots[index].visible = on


func has_dot(index: int) -> bool:
	return _dots[index].visible


func select(index: int, animate: bool = true) -> void:
	current = index
	_layout(animate)


func _tab_w() -> float:
	return (size.x - 40.0) / TABS.size()


func _layout(animate: bool = false) -> void:
	if size.x <= 0.0:
		return
	var tw := _tab_w()
	for i in _buttons.size():
		var b := _buttons[i]
		b.position = Vector2(20 + i * tw, 0)
		b.size = Vector2(tw, BAR_H)
		var on := i == current
		var s := 128.0 if on else 92.0
		var target_lift := -46.0 if on else 0.0
		var ic := _icons[i]
		var l := _labels[i]
		l.size = Vector2(tw, 44)
		l.modulate.a = 1.0 if on else 0.62
		if animate:
			var t := create_tween().set_parallel(true)
			t.tween_method(_set_lift.bind(i), _lift[i], target_lift, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(ic, "size", Vector2(s, s), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			ic.size = Vector2(s, s)
			_set_lift(target_lift, i)
		ic.queue_redraw()
	var px := 20 + current * tw
	if animate and _plate_x >= 0.0:
		create_tween().tween_method(_set_plate, _plate_x, px, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_set_plate(px)
	queue_redraw()


func _set_lift(v: float, i: int) -> void:
	_lift[i] = v
	var b := _buttons[i]
	var ic := _icons[i]
	ic.position = Vector2((b.size.x - ic.size.x) * 0.5, 30 + v - (ic.size.x - 92.0) * 0.5)
	_labels[i].position = Vector2(0, BAR_H - 62 + (v * 0.25))
	_dots[i].position = Vector2(b.size.x * 0.5 + 30, 14 + v)


func _set_plate(x: float) -> void:
	_plate_x = x
	_plate.position = Vector2(x + 14, -30)
	_plate.size = Vector2(_tab_w() - 28, BAR_H + 6)
	_plate.queue_redraw()


## The bar: a deep gradient with a bright rim and a soft shadow above it.
func _draw() -> void:
	var w := size.x
	var h := size.y
	for k in 4:
		draw_rect(Rect2(0, -6 - k * 5, w, 6), Color(0.04, 0.0, 0.14, 0.06))
	var bar := DrawKit.rounded_rect(Rect2(0, 0, w, h + 60), 56, 10)
	DrawKit.gradient_fill(self, bar, Color("3a2390"), Color("150a3f"))
	DrawKit.outline(self, bar, Color("6c50e0"), 4.0)
	draw_polyline(PackedVector2Array([Vector2(56, 6), Vector2(w - 56, 6)]), Color(1, 1, 1, 0.28), 3.0, true)
	# Soft separators between tabs.
	var tw := _tab_w()
	for i in range(1, TABS.size()):
		var x := 20 + i * tw
		draw_line(Vector2(x, 40), Vector2(x, BAR_H - 34), Color(1, 1, 1, 0.08), 3.0)


func _draw_plate() -> void:
	var r := Rect2(Vector2.ZERO, _plate.size)
	DrawKit.glossy_rrect(_plate, r, 46, Color("ffc23a"), Color("d9761a"), 0.0, 6.0, 14.0, true)
	_plate.draw_colored_polygon(DrawKit.star(Vector2(r.size.x - 34, 34), 12, 4, 4), Color(1, 1, 1, 0.85))


## Full-colour tab icons drawn in a 100x100 box scaled to the control.
## Inactive tabs are a little washed out.
func _draw_icon(ci: Control, id: String, on: bool) -> void:
	var s := minf(ci.size.x, ci.size.y)
	if s <= 0.0:
		return
	var u := s / 100.0
	var o := (ci.size - Vector2(s, s)) * 0.5
	var ink := Color("2b1640")
	var dim := 0.0 if on else 0.22
	var wash := Color("8c86b8")
	var pt := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * u
	ci.draw_colored_polygon(DrawKit.ellipse(pt.call(50, 95), 34 * u, 6 * u, 20), Color(0, 0, 0, 0.25))
	match id:
		"shop":
			# A counter with a candy jar under a striped, scalloped awning.
			var counter := DrawKit.rounded_rect(Rect2(pt.call(14, 52), Vector2(72, 38) * u), 6 * u, 4)
			RenoArt.shape(ci, counter, Color("b9733a").lerp(wash, dim), 3.0 * u)
			ci.draw_rect(Rect2(pt.call(14, 52), Vector2(72, 8) * u), Color("e09a55").lerp(wash, dim))
			ci.draw_line(pt.call(14, 52), pt.call(14, 22), ink, 5 * u)
			ci.draw_line(pt.call(86, 52), pt.call(86, 22), ink, 5 * u)
			for k in 4:
				var x0 := 8.0 + k * 21.0
				var col := (Color("ff4d5e") if k % 2 == 0 else Color("fff4e0")).lerp(wash, dim)
				ci.draw_colored_polygon(PackedVector2Array([pt.call(x0 + 3, 10), pt.call(x0 + 24, 10), pt.call(x0 + 21, 34), pt.call(x0, 34)]), col)
				ci.draw_circle(pt.call(x0 + 10.5, 34), 10.5 * u, col, true, -1.0, true)
			RenoArt.box(ci, Rect2(pt.call(42, 38), Vector2(16, 16) * u), Color(0.85, 0.95, 1.0, 0.9), 4 * u, 2.0 * u)
			ci.draw_circle(pt.call(50, 47), 4.5 * u, Color("ff9f1c").lerp(wash, dim), true, -1.0, true)
			RenoArt.box(ci, Rect2(pt.call(40, 34), Vector2(20, 5) * u), Color("5fd02c").lerp(wash, dim), 2 * u, 1.5 * u)
		"home":
			# A cosy house: terracotta roof, cream walls, lit window, teal door.
			RenoArt.shape(ci, PackedVector2Array([pt.call(18, 46), pt.call(82, 46), pt.call(82, 88), pt.call(18, 88)]), Color("fff1d6").lerp(wash, dim), 3.0 * u)
			ci.draw_rect(Rect2(pt.call(70, 16), Vector2(9, 18) * u), Color("b5523b").lerp(wash, dim))
			RenoArt.shape(ci, PackedVector2Array([pt.call(8, 50), pt.call(50, 12), pt.call(92, 50), pt.call(84, 56), pt.call(50, 24), pt.call(16, 56)]), Color("e2583e").lerp(wash, dim), 3.0 * u)
			RenoArt.box(ci, Rect2(pt.call(26, 58), Vector2(20, 18) * u), Color("ffd23f").lerp(wash, dim), 3 * u, 2.5 * u)
			ci.draw_line(pt.call(36, 58), pt.call(36, 76), Color(ink, 0.5), 2 * u)
			RenoArt.box(ci, Rect2(pt.call(54, 60), Vector2(18, 28) * u), Color("1aa39a").lerp(wash, dim), 4 * u, 2.5 * u)
			ci.draw_circle(pt.call(68, 75), 2 * u, Color("ffd23f"), true, -1.0, true)
		"profile":
			# A round portrait in a blue frame.
			ci.draw_circle(pt.call(50, 52), 42 * u, Color("2f9bff").lerp(wash, dim), true, -1.0, true)
			ci.draw_circle(pt.call(50, 52), 36 * u, Color("bfe6ff").lerp(wash, dim), true, -1.0, true)
			var shoulders := PackedVector2Array()
			for k in 17:
				var a := PI + PI * k / 16.0
				shoulders.append(pt.call(50, 92) + Vector2(cos(a) * 30, sin(a) * 22) * u)
			var disc := DrawKit.ellipse(pt.call(50, 52), 36 * u, 36 * u, 40)
			for part in Geometry2D.intersect_polygons(shoulders, disc):
				ci.draw_colored_polygon(part, Color("0f5e63").lerp(wash, dim))
			ci.draw_circle(pt.call(50, 46), 16 * u, Color("2b1d16"), true, -1.0, true)
			ci.draw_circle(pt.call(50, 50), 14 * u, Color("c98b5e").lerp(wash, dim), true, -1.0, true)
			ci.draw_colored_polygon(PackedVector2Array([pt.call(36, 44), pt.call(42, 34), pt.call(58, 33), pt.call(64, 44), pt.call(56, 40), pt.call(44, 41)]), Color("2b1d16"))
			ci.draw_circle(pt.call(45, 50), 1.8 * u, ink, true, -1.0, true)
			ci.draw_circle(pt.call(55, 50), 1.8 * u, ink, true, -1.0, true)
			ci.draw_arc(pt.call(50, 54), 5 * u, 0.3, PI - 0.3, 8, Color("7a2b22"), 2 * u, true)
			DrawKit.outline(ci, DrawKit.ellipse(pt.call(50, 52), 42 * u, 42 * u, 40), Color(ink, 0.5), 3 * u)
