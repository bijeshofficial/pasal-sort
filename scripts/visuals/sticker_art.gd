class_name StickerArt
extends RefCounted
## Placeholder sticker illustrations, drawn from a short "glyph" code in
## data/album.json: food shapes, festival things, animals (a round face in
## the given colour), mountain peaks, vehicles, crafts, shop items and the
## cast (char:<id>). Every sticker sits on a die-cut card with its name.


static func draw_card(ci: CanvasItem, r: Rect2, st: Dictionary, owned: bool, t: float = 0.0) -> void:
	var base := Color.html(String(st.get("color", "ff9f1c")))
	var rarity := int(st.get("rarity", 1))
	# Die-cut white border, then the coloured card.
	ci.draw_colored_polygon(DrawKit.rounded_rect(Rect2(r.position + Vector2(0, 8), r.size), 26, 6), Color(0, 0, 0, 0.18))
	ci.draw_colored_polygon(DrawKit.rounded_rect(r, 26, 6), Color.WHITE)
	var inner := r.grow(-10)
	if owned:
		DrawKit.gradient_fill(ci, DrawKit.rounded_rect(inner, 20, 6), base.lightened(0.35), base)
	else:
		ci.draw_colored_polygon(DrawKit.rounded_rect(inner, 20, 6), Color("d9d4ea"))
	var art := Rect2(inner.position + Vector2(10, 10), Vector2(inner.size.x - 20, inner.size.y * 0.66))
	if owned:
		draw_glyph(ci, art, String(st.get("glyph", "candy:0")), t)
	else:
		var f := UIKit.font(true)
		var q := "?"
		var fs := int(art.size.y * 0.6)
		var w := f.get_string_size(q, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(f, art.get_center() + Vector2(-w * 0.5, fs * 0.35), q, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("a59fc0"))
	# Rarity stars.
	for k in rarity:
		var c := Vector2(inner.position.x + 24 + k * 30, inner.position.y + 22)
		ci.draw_colored_polygon(DrawKit.star(c, 14, 6), Color("ffd23f") if owned else Color("b9b3d0"))
		DrawKit.outline(ci, DrawKit.star(c, 14, 6), Color("9c4a00") if owned else Color("8f89a8"), 2.0)
	# Name.
	var f := UIKit.font(true)
	var name := String(st.get("name", ""))
	var fs := 26
	while fs > 14 and f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > inner.size.x - 16:
		fs -= 2
	var tw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(inner.get_center().x - tw * 0.5, inner.end.y - 14)
	if owned:
		ci.draw_string_outline(f, p, name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, base.darkened(0.5))
	ci.draw_string(f, p, name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if owned else Color("8f89a8"))


static func draw_glyph(ci: CanvasItem, r: Rect2, glyph: String, t: float = 0.0) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y)
	var kind := glyph.get_slice(":", 0)
	var arg := glyph.get_slice(":", 1) if glyph.contains(":") else ""
	var ink := Color("3a2416")
	match kind:
		"char":
			var unit := s / (380.0 if arg == "biralo" else 470.0)
			CharacterArt.draw(ci, arg, Vector2(c.x, r.end.y + s * 0.05), unit, "happy", t)
		"candy":
			CandyArt.draw_candy(ci, c, s * 0.8, int(arg))
		"momo":
			for k in 3:
				var p := c + Vector2((k - 1) * s * 0.26, (k % 2) * s * 0.08)
				var m := PackedVector2Array()
				for i in 17:
					var a := PI + PI * i / 16.0
					m.append(p + Vector2(cos(a) * s * 0.16, sin(a) * s * 0.18 + s * 0.08))
				RenoArt.shape(ci, m, Color("fff3dc"), 3.0)
				for i in 3:
					ci.draw_line(p + Vector2(0, -s * 0.08), p + Vector2((i - 1) * s * 0.07, s * 0.02), Color("d9c6a5"), 2.0, true)
		"ring":
			ci.draw_arc(c, s * 0.28, 0, TAU, 32, Color("b5652b"), s * 0.14, true)
			ci.draw_arc(c, s * 0.28, -0.6, 0.4, 8, Color("e0a458"), s * 0.05, true)
		"bowl":
			var bowl := PackedVector2Array()
			for i in 17:
				var a := PI * i / 16.0
				bowl.append(c + Vector2(cos(a) * s * 0.36, sin(a) * s * 0.26))
			for k in 6:
				ci.draw_circle(c + Vector2(-s * 0.2 + k * s * 0.08, -s * 0.02 - (k % 2) * s * 0.05), s * 0.06, [Color("ff6b3b"), Color("ffd166"), Color("5fd02c")][k % 3], true, -1.0, true)
			RenoArt.shape(ci, bowl, Color("f4efe6"), 3.0)
		"ball":
			for k in 4:
				var p := c + Vector2(((k % 2) - 0.5) * s * 0.34, (k / 2 - 0.5) * s * 0.3)
				ci.draw_circle(p, s * 0.14, Color("e0a458"), true, -1.0, true)
				ci.draw_arc(p, s * 0.14, 0, TAU, 20, Color("8a5a2b"), 3.0, true)
		"triangle":
			RenoArt.shape(ci, PackedVector2Array([c + Vector2(0, -s * 0.34), c + Vector2(s * 0.36, s * 0.28), c + Vector2(-s * 0.36, s * 0.28)]), Color("e0a458"), 4.0)
		"pot":
			var body := DrawKit.ellipse(c + Vector2(0, s * 0.08), s * 0.32, s * 0.28, 24)
			RenoArt.shape(ci, body, Color("b5623b"), 4.0)
			RenoArt.box(ci, Rect2(c.x - s * 0.18, c.y - s * 0.3, s * 0.36, s * 0.12), Color("8a4b28"), 6, 3.0)
			ci.draw_arc(c + Vector2(0, s * 0.08), s * 0.2, 0.3, PI - 0.3, 12, Color("fff3dc"), 4.0, true)
		"drop":
			var d := PackedVector2Array()
			for i in 24:
				var a := TAU * i / 24.0
				var rr := s * 0.3 * (1.0 + 0.5 * maxf(0.0, -sin(a)))
				d.append(c + Vector2(cos(a) * s * 0.26, sin(a) * rr))
			RenoArt.shape(ci, d, Color("fff1d6"), 3.0)
		"cup":
			RenoArt.box(ci, Rect2(c.x - s * 0.22, c.y - s * 0.2, s * 0.44, s * 0.42), Color("f4efe6"), 10, 3.0)
			ci.draw_arc(c + Vector2(s * 0.24, 0), s * 0.1, -PI * 0.5, PI * 0.5, 10, Color("d9d4cc"), 6.0, true)
			ci.draw_rect(Rect2(c.x - s * 0.18, c.y - s * 0.16, s * 0.36, s * 0.08), Color("b5652b"))
			for k in 2:
				ci.draw_arc(c + Vector2(-s * 0.06 + k * s * 0.12, -s * 0.32), s * 0.06, PI * 0.5, PI * 1.5, 8, Color(1, 1, 1, 0.8), 3.0, true)
		"kite", "lantern", "diyo", "gift", "chest", "basket", "coin", "flag", "star":
			var iv: Array = {"kite": [Color("e8457a"), "kite"], "lantern": [Color("ff6b5b"), "flag"], "diyo": [Color("b5623b"), "diyo"], "gift": [Color("e8457a"), "gift"], "chest": [Color("a8672f"), "chest"], "basket": [Color("c99a5b"), "basket"], "coin": [Color.WHITE, "coin"], "flag": [Color("2f9bff"), "flag"], "star": [Color("ffd23f"), "star"]}[kind]
			if kind == "lantern":
				RenoArt.shape(ci, DrawKit.ellipse(c, s * 0.26, s * 0.32, 24), Color("ff6b5b"), 3.0)
				for k in 3:
					ci.draw_line(c + Vector2(-s * 0.24, -s * 0.12 + k * s * 0.12), c + Vector2(s * 0.24, -s * 0.12 + k * s * 0.12), Color(0, 0, 0, 0.2), 3.0)
				ci.draw_rect(Rect2(c.x - s * 0.1, c.y - s * 0.38, s * 0.2, s * 0.08), Color("f2b632"))
			else:
				_icon(ci, String(iv[1]), Rect2(c - Vector2(s, s) * 0.36, Vector2(s, s) * 0.72), iv[0])
		"swing":
			ci.draw_line(c + Vector2(-s * 0.34, -s * 0.36), c + Vector2(s * 0.34, -s * 0.36), Color("8b5a2b"), 8.0)
			for x in [-0.16, 0.16]:
				ci.draw_line(c + Vector2(x * s, -s * 0.36), c + Vector2(x * s + sin(t) * 6, s * 0.18), Color("c99a5b"), 3.0)
			RenoArt.box(ci, Rect2(c.x - s * 0.22 + sin(t) * 6, c.y + s * 0.16, s * 0.44, s * 0.08), Color("e0a458"), 4, 3.0)
		"garland":
			for k in 9:
				var u := k / 8.0
				ci.draw_circle(c + Vector2((u - 0.5) * s * 0.8, sin(u * PI) * s * 0.3 - s * 0.1), s * 0.07, Color("ff9f1c") if k % 2 == 0 else Color("ffd23f"), true, -1.0, true)
		"sparkle":
			for k in 5:
				var p := c + Vector2(cos(k * 1.3) * s * 0.22, sin(k * 1.9) * s * 0.22)
				ci.draw_colored_polygon(DrawKit.star(p, s * 0.12, s * 0.03, 4), Color("fff2a8"))
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.3), c, Color("8a8f99"), 4.0)
		"drum":
			RenoArt.shape(ci, PackedVector2Array([c + Vector2(-s * 0.36, -s * 0.16), c + Vector2(s * 0.36, -s * 0.16), c + Vector2(s * 0.3, s * 0.16), c + Vector2(-s * 0.3, s * 0.16)]), Color("8b5a2b"), 3.0)
			for x in [-0.36, 0.36]:
				RenoArt.shape(ci, DrawKit.ellipse(c + Vector2(x * s, 0), s * 0.07, s * 0.18, 16), Color("f4e3c3"), 3.0)
			for k in 4:
				ci.draw_line(c + Vector2(-s * 0.3 + k * s * 0.2, -s * 0.16), c + Vector2(-s * 0.2 + k * s * 0.2, s * 0.16), Color("e0a458"), 2.0)
		"bunting":
			ci.draw_line(c + Vector2(-s * 0.4, -s * 0.2), c + Vector2(s * 0.4, -s * 0.2), ink, 2.0)
			for k in 5:
				var x := -s * 0.32 + k * s * 0.16
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(x - s * 0.07, -s * 0.2), c + Vector2(x + s * 0.07, -s * 0.2), c + Vector2(x, s * 0.05)]), [Color("ff6b5b"), Color("ffd23f"), Color("2f9bff"), Color("5fd02c"), Color("a35cff")][k])
		"animal":
			var col := Color.html(arg)
			for sx in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(sx * s * 0.24, -s * 0.22), s * 0.1, col.darkened(0.2), true, -1.0, true)
			RenoArt.shape(ci, DrawKit.ellipse(c, s * 0.32, s * 0.28, 28), col, 3.0)
			ci.draw_colored_polygon(DrawKit.ellipse(c + Vector2(0, s * 0.1), s * 0.16, s * 0.1, 16), col.lightened(0.4))
			for sx in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(sx * s * 0.12, -s * 0.04), s * 0.04, ink, true, -1.0, true)
			ci.draw_circle(c + Vector2(0, s * 0.06), s * 0.035, ink, true, -1.0, true)
		"bird":
			var col := Color.html(arg)
			RenoArt.shape(ci, DrawKit.ellipse(c + Vector2(0, s * 0.08), s * 0.24, s * 0.18, 24), col, 3.0)
			ci.draw_circle(c + Vector2(s * 0.18, -s * 0.12), s * 0.12, col.lightened(0.15), true, -1.0, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.28, -s * 0.12), c + Vector2(s * 0.4, -s * 0.08), c + Vector2(s * 0.28, -s * 0.06)]), Color("f2b632"))
			ci.draw_line(c + Vector2(s * 0.16, -s * 0.24), c + Vector2(s * 0.2, -s * 0.38), Color("c0392b"), 4.0)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.2, s * 0.04), c + Vector2(-s * 0.42, -s * 0.06), c + Vector2(-s * 0.36, s * 0.16)]), Color("c0392b"))
		"peak":
			var n := maxi(1, int(arg))
			ci.draw_colored_polygon(DrawKit.rounded_rect(Rect2(r.position, r.size), 12, 4), Color("bfe3ff"))
			var base_y := r.end.y - 4
			var pts := PackedVector2Array([Vector2(r.position.x, base_y)])
			for k in n + 1:
				var x := r.position.x + r.size.x * (k + 0.5) / (n + 1)
				pts.append(Vector2(x, r.position.y + r.size.y * (0.18 + 0.12 * ((k * 3) % 4) / 3.0)))
			pts.append(Vector2(r.end.x, base_y))
			ci.draw_colored_polygon(pts, Color("7d95c0"))
			for k in range(1, pts.size() - 1):
				var top: Vector2 = pts[k]
				ci.draw_colored_polygon(PackedVector2Array([top, top + Vector2(s * 0.1, s * 0.12), top + Vector2(-s * 0.1, s * 0.12)]), Color.WHITE)
		"vehicle", "cable":
			var col := Color.html(arg)
			if kind == "cable":
				ci.draw_line(r.position + Vector2(0, s * 0.1), Vector2(r.end.x, r.position.y + s * 0.3), ink, 3.0)
				RenoArt.box(ci, Rect2(c.x - s * 0.2, c.y - s * 0.1, s * 0.4, s * 0.34), col, 10, 3.0)
				ci.draw_line(c + Vector2(0, -s * 0.1), c + Vector2(0, -s * 0.24), ink, 3.0)
				ci.draw_rect(Rect2(c.x - s * 0.14, c.y - s * 0.04, s * 0.28, s * 0.12), Color("bfe3ff"))
			else:
				RenoArt.box(ci, Rect2(c.x - s * 0.38, c.y - s * 0.2, s * 0.76, s * 0.34), col, 12, 3.0)
				ci.draw_rect(Rect2(c.x - s * 0.3, c.y - s * 0.14, s * 0.24, s * 0.12), Color("bfe3ff"))
				ci.draw_rect(Rect2(c.x + s * 0.02, c.y - s * 0.14, s * 0.24, s * 0.12), Color("bfe3ff"))
				for x in [-0.22, 0.22]:
					ci.draw_circle(c + Vector2(x * s, s * 0.16), s * 0.09, ink, true, -1.0, true)
					ci.draw_circle(c + Vector2(x * s, s * 0.16), s * 0.04, Color("b9b9b9"), true, -1.0, true)
		"bike":
			var col := Color.html(arg)
			for x in [-0.22, 0.22]:
				ci.draw_arc(c + Vector2(x * s, s * 0.12), s * 0.13, 0, TAU, 24, ink, 5.0, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.22, s * 0.12), c + Vector2(-s * 0.02, -s * 0.06), c + Vector2(s * 0.22, s * 0.12)]), col, 6.0, true)
			ci.draw_line(c + Vector2(-s * 0.02, -s * 0.06), c + Vector2(s * 0.14, -s * 0.14), col, 6.0)
		"cloth", "shawl", "paper", "loom":
			var col: Color = {"cloth": Color("c0392b"), "shawl": Color("a35cff"), "paper": Color("f4e3c3"), "loom": Color("8b5a2b")}[kind]
			var rr := Rect2(c - Vector2(s * 0.32, s * 0.3), Vector2(s * 0.64, s * 0.6))
			RenoArt.pattern_rect(ci, rr, "dhaka" if kind != "paper" else "plaster", col, Color("1f2a36") if kind != "paper" else Color("c9a86f"), 8)
			DrawKit.outline(ci, RenoArt.rect_pts(rr, 8), col.darkened(0.4), 3.0)
		"window":
			RenoArt.draw_object(ci, "window", Vector2(s * 0.7, s * 0.7), {"base": "7a4a22", "accent": "e0a458", "pattern": "carved"}, false, t, false, Transform2D(0.0, c - Vector2(s * 0.35, s * 0.35)))
		"jar":
			CandyArt.draw_mini_jar(ci, c + Vector2(0, s * 0.38), s * 0.34, [2, 2, 2])
		"scale", "kettle", "tin", "bag", "abacus", "book", "jug", "balls":
			_item(ci, kind, c, s)
		_:
			CandyArt.draw_candy(ci, c, s * 0.7, 2)


static func _icon(ci: CanvasItem, icon: String, r: Rect2, col: Color) -> void:
	# A throwaway IconView can't draw on another canvas item, so the few
	# icons used here are drawn directly with the same shapes.
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y)
	match icon:
		"kite":
			RenoArt.shape(ci, PackedVector2Array([c + Vector2(0, -s * 0.45), c + Vector2(s * 0.35, 0), c + Vector2(0, s * 0.4), c + Vector2(-s * 0.35, 0)]), col, 3.0)
			ci.draw_line(c + Vector2(0, -s * 0.45), c + Vector2(0, s * 0.4), Color(1, 1, 1, 0.7), 2.0)
			ci.draw_line(c + Vector2(-s * 0.35, 0), c + Vector2(s * 0.35, 0), Color(1, 1, 1, 0.7), 2.0)
		"diyo":
			RenoArt.shape(ci, PackedVector2Array([c + Vector2(-s * 0.4, s * 0.1), c + Vector2(s * 0.4, s * 0.1), c + Vector2(s * 0.24, s * 0.36), c + Vector2(-s * 0.24, s * 0.36)]), col, 3.0)
			ci.draw_colored_polygon(DrawKit.ellipse(c + Vector2(0, -s * 0.12), s * 0.1, s * 0.2, 14), Color("ffb020"))
			ci.draw_colored_polygon(DrawKit.ellipse(c + Vector2(0, -s * 0.06), s * 0.05, s * 0.1, 10), Color("fff2a8"))
		"gift":
			RenoArt.box(ci, Rect2(c.x - s * 0.34, c.y - s * 0.1, s * 0.68, s * 0.46), col, 8, 3.0)
			RenoArt.box(ci, Rect2(c.x - s * 0.4, c.y - s * 0.24, s * 0.8, s * 0.16), col.lightened(0.2), 6, 3.0)
			ci.draw_rect(Rect2(c.x - s * 0.06, c.y - s * 0.24, s * 0.12, s * 0.6), Color("ffd23f"))
		"chest":
			RenoArt.box(ci, Rect2(c.x - s * 0.4, c.y - s * 0.06, s * 0.8, s * 0.42), col, 8, 3.0)
			RenoArt.box(ci, Rect2(c.x - s * 0.42, c.y - s * 0.3, s * 0.84, s * 0.26), col.lightened(0.15), 14, 3.0)
			ci.draw_rect(Rect2(c.x - s * 0.08, c.y - s * 0.12, s * 0.16, s * 0.2), Color("f2b632"))
		"basket":
			RenoArt.shape(ci, PackedVector2Array([c + Vector2(-s * 0.4, -s * 0.05), c + Vector2(s * 0.4, -s * 0.05), c + Vector2(s * 0.3, s * 0.38), c + Vector2(-s * 0.3, s * 0.38)]), col, 3.0)
			ci.draw_arc(c + Vector2(0, -s * 0.05), s * 0.3, PI, TAU, 16, col.darkened(0.3), 6.0, true)
		"coin":
			ci.draw_circle(c, s * 0.4, Color("b07c14"), true, -1.0, true)
			ci.draw_circle(c + Vector2(0, -3), s * 0.36, Color("f2b632"), true, -1.0, true)
			ci.draw_arc(c + Vector2(0, -3), s * 0.25, 0, TAU, 32, Color("d69a1c"), 5.0, true)
		"flag":
			ci.draw_line(c + Vector2(-s * 0.3, -s * 0.42), c + Vector2(-s * 0.3, s * 0.42), Color("5a3a20"), 6.0)
			RenoArt.shape(ci, PackedVector2Array([c + Vector2(-s * 0.28, -s * 0.4), c + Vector2(s * 0.36, -s * 0.28), c + Vector2(-s * 0.28, -s * 0.04)]), col, 3.0)
		"star":
			RenoArt.shape(ci, DrawKit.star(c, s * 0.42, s * 0.18), col, 3.0)


static func _item(ci: CanvasItem, kind: String, c: Vector2, s: float) -> void:
	match kind:
		"scale":
			RenoArt.draw_object(ci, "scale", Vector2(s * 0.8, s * 0.6), {"base": "d6a53a", "accent": "ff9f1c"}, false, 0.0, false, Transform2D(0.0, c - Vector2(s * 0.4, s * 0.3)))
		"kettle":
			RenoArt.shape(ci, DrawKit.ellipse(c + Vector2(0, s * 0.08), s * 0.3, s * 0.24, 24), Color("b8b8c0"), 3.0)
			ci.draw_arc(c + Vector2(0, -s * 0.1), s * 0.2, PI * 1.1, PI * 1.9, 12, Color("5a5a66"), 6.0, true)
			ci.draw_line(c + Vector2(s * 0.28, 0), c + Vector2(s * 0.44, -s * 0.14), Color("b8b8c0"), 8.0)
		"tin":
			RenoArt.box(ci, Rect2(c.x - s * 0.28, c.y - s * 0.26, s * 0.56, s * 0.56), Color("c0392b"), 10, 3.0)
			RenoArt.pattern_rect(ci, Rect2(c.x - s * 0.22, c.y - s * 0.1, s * 0.44, s * 0.24), "floral", Color("c0392b"), Color("f2b632"), 6)
		"bag":
			RenoArt.shape(ci, PackedVector2Array([c + Vector2(-s * 0.26, -s * 0.24), c + Vector2(s * 0.26, -s * 0.24), c + Vector2(s * 0.3, s * 0.34), c + Vector2(-s * 0.3, s * 0.34)]), Color("d9b98a"), 3.0)
			ci.draw_line(c + Vector2(-s * 0.26, -s * 0.18), c + Vector2(s * 0.26, -s * 0.18), Color("a8875a"), 3.0)
		"abacus":
			RenoArt.box(ci, Rect2(c.x - s * 0.36, c.y - s * 0.3, s * 0.72, s * 0.6), Color("8b5a2b"), 6, 3.0)
			for row in 3:
				var y := c.y - s * 0.15 + row * s * 0.15
				ci.draw_line(Vector2(c.x - s * 0.3, y), Vector2(c.x + s * 0.3, y), Color("3a2416"), 2.0)
				for k in 4:
					ci.draw_circle(Vector2(c.x - s * 0.22 + k * s * 0.08 + (row % 2) * s * 0.12, y), s * 0.04, [Color("ff6b5b"), Color("2f9bff"), Color("ffd23f")][row], true, -1.0, true)
		"book":
			RenoArt.box(ci, Rect2(c.x - s * 0.3, c.y - s * 0.34, s * 0.6, s * 0.68), Color("0f5e63"), 6, 3.0)
			ci.draw_rect(Rect2(c.x - s * 0.3, c.y - s * 0.34, s * 0.08, s * 0.68), Color("0a4447"))
			ci.draw_rect(Rect2(c.x - s * 0.12, c.y - s * 0.18, s * 0.3, s * 0.06), Color("f2b632"))
		"jug":
			RenoArt.shape(ci, DrawKit.ellipse(c + Vector2(0, s * 0.1), s * 0.3, s * 0.26, 24), Color("c77b4a"), 3.0)
			RenoArt.box(ci, Rect2(c.x - s * 0.12, c.y - s * 0.32, s * 0.24, s * 0.2), Color("c77b4a"), 4, 3.0)
			ci.draw_arc(c + Vector2(0, s * 0.1), s * 0.22, -0.8, -0.2, 8, Color(1, 1, 1, 0.5), 4.0, true)
		"balls":
			for k in 5:
				ci.draw_circle(c + Vector2(cos(k * 1.26) * s * 0.2, sin(k * 1.26) * s * 0.2), s * 0.12, [Color("ff6b5b"), Color("ffd23f"), Color("2f9bff"), Color("5fd02c"), Color("a35cff")][k], true, -1.0, true)
