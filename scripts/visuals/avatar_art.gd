class_name AvatarArt
extends RefCounted
## Eight friendly illustrated avatars, drawn in code inside a circle.

const BG := ["1d6b74", "ee8a1f", "5f97c2", "b23a33", "8a5a9e", "a4673c", "2f8f83", "d98b6a"]
const SKINS := ["c98b5e", "d9a07a", "b87a50", "e0ae84", "c48a62", "b98060", "d49b73", "c7875b"]
const HAIR := Color("2b1d16")


static func draw_avatar(ci: CanvasItem, c: Vector2, r: float, idx: int) -> void:
	idx = posmod(idx, 8)
	var u := r / 100.0
	var skin := Color(SKINS[idx])
	ci.draw_circle(c, r, Color(BG[idx]), true, -1.0, true)
	# Shoulders / clothes.
	var cloth: Color = [Color("f4ecd8"), Color("e0739a"), Color("f7f7f2"), Color("d8483a"), Color("f2b632"), Color("f4ecd8"), Color("f7f7f2"), Color("fbfbf8")][idx]
	var body := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		body.append(c + Vector2(cos(a) * 70, 100 + sin(a) * 48) * u)
	var disc := DrawKit.ellipse(c, r, r, 48)
	for part in Geometry2D.intersect_polygons(body, disc):
		ci.draw_colored_polygon(part, cloth)
	match idx:
		0:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-60, 70) * u, c + Vector2(-18, 56) * u, c + Vector2(-12, 100) * u, c + Vector2(-60, 100) * u]), Color("1d6b74"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(60, 70) * u, c + Vector2(18, 56) * u, c + Vector2(12, 100) * u, c + Vector2(60, 100) * u]), Color("1d6b74"))
		2:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 58) * u, c + Vector2(8, 58) * u, c + Vector2(12, 96) * u, c + Vector2(0, 100) * u, c + Vector2(-12, 96) * u]), Color("b23a33"))
		3:
			ci.draw_line(c + Vector2(0, 56) * u, c + Vector2(0, 100) * u, Color("7a2b22"), 5 * u)
		7:
			ci.draw_rect(Rect2(c + Vector2(-34, 66) * u, Vector2(68, 40) * u), Color("dfe7ea"))
	ci.draw_rect(Rect2(c + Vector2(-14, 26) * u, Vector2(28, 34) * u), skin.darkened(0.12))
	# Head.
	var head := c + Vector2(0, -6) * u
	if idx == 4:
		ci.draw_colored_polygon(DrawKit.ellipse(head + Vector2(0, 10) * u, 56 * u, 66 * u, 32), Color("8d2622"))
	ci.draw_colored_polygon(DrawKit.ellipse(head, 40 * u, 46 * u, 32), skin)
	# Hair / hats.
	match idx:
		0, 5:
			var topi := Color("b23a33") if idx == 0 else Color("2b2a2e")
			ci.draw_colored_polygon(PackedVector2Array([head + Vector2(-40, -26) * u, head + Vector2(-32, -66) * u, head + Vector2(34, -54) * u, head + Vector2(40, -24) * u]), topi)
			if idx == 0:
				for k in 5:
					ci.draw_circle(head + Vector2(-24 + k * 12, -44 + k * 2) * u, 4 * u, Color("f2b632") if k % 2 == 0 else Color("fff3e0"), true, -1.0, true)
		1:
			ci.draw_colored_polygon(DrawKit.ellipse(head + Vector2(0, -24) * u, 42 * u, 26 * u, 24), HAIR)
			ci.draw_circle(head + Vector2(0, -52) * u, 18 * u, HAIR, true, -1.0, true)
			ci.draw_circle(head + Vector2(-40, 12) * u, 5 * u, Color("f2b632"), true, -1.0, true)
			ci.draw_circle(head + Vector2(40, 12) * u, 5 * u, Color("f2b632"), true, -1.0, true)
		2:
			ci.draw_colored_polygon(DrawKit.ellipse(head + Vector2(0, -26) * u, 42 * u, 24 * u, 24), HAIR)
		3:
			ci.draw_colored_polygon(DrawKit.ellipse(head + Vector2(0, -28) * u, 44 * u, 30 * u, 24), Color("ee8a1f"))
			ci.draw_rect(Rect2(head + Vector2(-44, -24) * u, Vector2(88, 14) * u), Color("c56a12"))
			ci.draw_circle(head + Vector2(0, -60) * u, 10 * u, Color("fff3e0"), true, -1.0, true)
		4:
			pass
		6:
			ci.draw_colored_polygon(DrawKit.ellipse(head + Vector2(0, -28) * u, 42 * u, 26 * u, 24), Color("1d6b74"))
			ci.draw_colored_polygon(PackedVector2Array([head + Vector2(0, -26) * u, head + Vector2(62, -20) * u, head + Vector2(58, -10) * u, head + Vector2(0, -14) * u]), Color("124a51"))
		7:
			ci.draw_rect(Rect2(head + Vector2(-34, -52) * u, Vector2(68, 26) * u), Color("fbfbf8"))
			for k in 3:
				ci.draw_circle(head + Vector2(-22 + k * 22, -60) * u, 20 * u, Color("fbfbf8"), true, -1.0, true)
	# Face.
	for sx in [-1.0, 1.0]:
		ci.draw_circle(head + Vector2(sx * 15, 2) * u, 5 * u, HAIR, true, -1.0, true)
		ci.draw_circle(head + Vector2(sx * 24, 18) * u, 7 * u, Color(0.93, 0.45, 0.4, 0.35), true, -1.0, true)
	if idx == 5:
		for sx in [-1.0, 1.0]:
			ci.draw_arc(head + Vector2(sx * 15, 2) * u, 12 * u, 0, TAU, 16, Color("3a3a3a"), 3 * u, true)
		ci.draw_line(head + Vector2(-3, 2) * u, head + Vector2(3, 2) * u, Color("3a3a3a"), 3 * u)
	if idx == 0 or idx == 5:
		var mc := Color("2b1d16") if idx == 0 else Color("d8d4cc")
		ci.draw_colored_polygon(PackedVector2Array([head + Vector2(-2, 18) * u, head + Vector2(-26, 24) * u, head + Vector2(-24, 16) * u, head + Vector2(0, 14) * u, head + Vector2(24, 16) * u, head + Vector2(26, 24) * u, head + Vector2(2, 18) * u]), mc)
	ci.draw_arc(head + Vector2(0, 22) * u, 12 * u, 0.4, PI - 0.4, 10, Color("7a2b22"), 4 * u, true)
