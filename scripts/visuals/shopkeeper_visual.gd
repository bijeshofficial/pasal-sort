class_name ShopkeeperVisual
extends Node2D
## The friendly shopkeeper (dhaka topi, waistcoat, big moustache), drawn in
## code. Origin = bottom of the torso (the counter top hides the rest).
## Poses: "idle" (gentle breathing), "wave", "cheer" (both arms up).

const SKIN := Color("c98b5e")
const SKIN_DARK := Color("a86e45")
const KURTA := Color("f4ecd8")
const VEST := Color("1d6b74")
const HAIR := Color("2b1d16")
const TOPI := Color("b23a33")

var pose := "idle"
var unit := 1.0
var _t := 0.0
var _arm := 0.0   # 0 = down, 1 = up (eased)


func _process(delta: float) -> void:
	_t += delta
	var target := 1.0 if pose == "cheer" else (0.5 if pose == "wave" else 0.0)
	_arm = move_toward(_arm, target, delta * 5.0)
	queue_redraw()


func cheer(duration: float = 1.6) -> void:
	pose = "cheer"
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(func() -> void: pose = "idle")


func wave(duration: float = 1.4) -> void:
	pose = "wave"
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(func() -> void: pose = "idle")


func _draw() -> void:
	var u := unit
	var breathe := sin(_t * 2.0) * 3.0 * u
	var hop := absf(sin(_t * 9.0)) * 14.0 * u if pose == "cheer" else 0.0
	var o := Vector2(0, -hop)
	# Arms behind the torso when raised.
	var sh_l := o + Vector2(-78, -210) * u
	var sh_r := o + Vector2(78, -210) * u
	var hand_l := _hand(sh_l, -1.0, u)
	var hand_r := _hand(sh_r, 1.0, u)
	_arm_draw(sh_l, hand_l, u)
	_arm_draw(sh_r, hand_r, u)
	# Torso: kurta with a waistcoat.
	var torso := PackedVector2Array([o + Vector2(-92, 0) * u, o + Vector2(-84, -214) * u + Vector2(0, breathe), o + Vector2(84, -214) * u + Vector2(0, breathe), o + Vector2(92, 0) * u])
	draw_colored_polygon(torso, KURTA)
	var vest_l := PackedVector2Array([o + Vector2(-90, 0) * u, o + Vector2(-82, -206) * u + Vector2(0, breathe), o + Vector2(-26, -206) * u + Vector2(0, breathe), o + Vector2(-8, -40) * u, o + Vector2(-10, 0) * u])
	var vest_r := PackedVector2Array()
	for p in vest_l:
		vest_r.append(Vector2(-p.x, p.y))
	vest_r.reverse()
	draw_colored_polygon(vest_l, VEST)
	draw_colored_polygon(vest_r, VEST)
	for k in 3:
		draw_circle(o + Vector2(-18, -150 + k * 42) * u, 6 * u, Color("f2b632"), true, -1.0, true)
	# Neck and head.
	var head := o + Vector2(0, -290) * u + Vector2(0, breathe)
	draw_rect(Rect2(head + Vector2(-20, 40) * u, Vector2(40, 40) * u), SKIN_DARK)
	draw_circle(head + Vector2(-66, 8) * u, 16 * u, SKIN_DARK, true, -1.0, true)
	draw_circle(head + Vector2(66, 8) * u, 16 * u, SKIN_DARK, true, -1.0, true)
	draw_colored_polygon(DrawKit.ellipse(head, 66 * u, 74 * u, 36), SKIN)
	# Hair at the sides.
	draw_colored_polygon(DrawKit.ellipse(head + Vector2(-58, -18) * u, 14 * u, 26 * u, 16), HAIR)
	draw_colored_polygon(DrawKit.ellipse(head + Vector2(58, -18) * u, 14 * u, 26 * u, 16), HAIR)
	# Eyes, happy when cheering.
	for sx in [-1.0, 1.0]:
		var e := head + Vector2(sx * 24, -6) * u
		if pose == "cheer":
			draw_arc(e + Vector2(0, 6) * u, 10 * u, PI * 1.1, PI * 1.9, 10, HAIR, 5 * u, true)
		else:
			draw_circle(e, 8 * u, HAIR, true, -1.0, true)
			draw_circle(e + Vector2(-2.5, -3) * u, 2.6 * u, Color.WHITE, true, -1.0, true)
		draw_circle(head + Vector2(sx * 40, 22) * u, 11 * u, Color(0.93, 0.45, 0.4, 0.35), true, -1.0, true)
	# Moustache and smile.
	var m := head + Vector2(0, 28) * u
	draw_colored_polygon(PackedVector2Array([m + Vector2(-4, -6) * u, m + Vector2(-40, 2) * u, m + Vector2(-46, -8) * u, m + Vector2(-20, -14) * u, m + Vector2(0, -10) * u, m + Vector2(20, -14) * u, m + Vector2(46, -8) * u, m + Vector2(40, 2) * u, m + Vector2(4, -6) * u]), HAIR)
	if pose == "cheer":
		draw_colored_polygon(DrawKit.ellipse(m + Vector2(0, 16) * u, 16 * u, 12 * u, 16), Color("7a2b22"))
	else:
		draw_arc(m + Vector2(0, 2) * u, 16 * u, 0.3, PI - 0.3, 12, Color("7a2b22"), 5 * u, true)
	# Dhaka topi: taller at the back, woven pattern.
	var t0 := head + Vector2(0, -56) * u
	var cap := PackedVector2Array([t0 + Vector2(-60, 12) * u, t0 + Vector2(-48, -50) * u, t0 + Vector2(50, -30) * u, t0 + Vector2(60, 14) * u])
	draw_colored_polygon(cap, TOPI)
	var cols := [Color("f2b632"), Color("1f2a36"), Color("fff3e0"), Color("ee8a1f")]
	for row in 3:
		for k in 6:
			var c := t0 + Vector2(-42 + k * 17 + row * 3, -30 + row * 14 + k * 1.5) * u
			var s := 5.0 * u
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), cols[(row + k) % 4])
	draw_line(t0 + Vector2(-60, 12) * u, t0 + Vector2(60, 14) * u, Color("1f2a36"), 6 * u, true)


func _hand(shoulder: Vector2, side: float, u: float) -> Vector2:
	var down := shoulder + Vector2(side * 30, 150) * u
	var up := shoulder + Vector2(side * 70, -130) * u
	var a := _arm
	if pose == "wave" and side > 0:
		a = 1.0
		up += Vector2(sin(_t * 12.0) * 26, 0) * u
	elif pose == "wave":
		a = 0.0
	return down.lerp(up, a)


func _arm_draw(shoulder: Vector2, hand: Vector2, u: float) -> void:
	DrawKit.capsule(self, shoulder, hand, 24 * u, KURTA.darkened(0.06))
	draw_circle(hand, 22 * u, SKIN, true, -1.0, true)
