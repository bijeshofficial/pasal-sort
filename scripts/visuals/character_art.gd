class_name CharacterArt
extends RefCounted
## The story cast, drawn in code: friendly rounded cartoon busts with big
## eyes and six moods (neutral, happy, laugh, surprised, worried, grumpy).
## draw() puts the bottom-centre of the bust at `origin`; one `unit` is about
## 1 px at a 440 px tall bust. Biralo the cat is drawn sitting.

const MOODS := ["neutral", "happy", "laugh", "surprised", "worried", "grumpy"]

const CAST := {
	"maya": {"name": "Maya", "skin": "c98b5e", "hair": "231710", "top": "0f5e63", "accent": "ff9f1c", "hair_style": "ponytail"},
	"hajurama": {"name": "Hajurama", "skin": "b5774f", "hair": "e3ded6", "top": "a8302b", "accent": "f2b632", "hair_style": "bun", "glasses": true, "old": true},
	"bhai": {"name": "Bhai", "skin": "c98b5e", "hair": "231710", "top": "2f9bff", "accent": "fff3dc", "hair_style": "spiky", "kid": true},
	"kanchha": {"name": "Kanchha Dai", "skin": "a86e45", "hair": "231710", "top": "3d5a80", "accent": "f2b632", "hair_style": "cap", "moustache": true},
	"sunita": {"name": "Sunita Didi", "skin": "b97c55", "hair": "231710", "top": "d94a7a", "accent": "fff3dc", "hair_style": "bun_flower", "apron": true},
	"biralo": {"name": "Biralo", "cat": true},
}


static func display_name(id: String) -> String:
	return String(CAST.get(id, {}).get("name", id.capitalize()))


static func is_cat(id: String) -> bool:
	return bool(CAST.get(id, {}).get("cat", false))


## pose: "idle" | "cheer" | "wave"; arm 0..1 eases arms up; blink 0..1.
static func draw(ci: CanvasItem, id: String, origin: Vector2, unit: float, mood: String = "neutral", t: float = 0.0, pose: String = "idle", arm: float = 0.0, blink: float = 0.0) -> void:
	if is_cat(id):
		draw_cat(ci, origin, unit, mood, t, blink)
		return
	var c: Dictionary = CAST.get(id, CAST["maya"])
	var u := unit
	var kid := bool(c.get("kid", false))
	var body_scale := 0.78 if kid else 1.0
	var skin := Color.html(c["skin"])
	var hair := Color.html(c["hair"])
	var top := Color.html(c["top"])
	var accent := Color.html(c["accent"])
	var breathe := sin(t * 2.0) * 3.0 * u
	var hop := absf(sin(t * 9.0)) * 14.0 * u if pose == "cheer" else 0.0
	var o := origin + Vector2(0, -hop)
	var bw := 92.0 * body_scale
	var bh := 214.0 * body_scale
	# Arms behind the torso.
	var sh_l := o + Vector2(-bw * 0.86, -bh) * u
	var sh_r := o + Vector2(bw * 0.86, -bh) * u
	for side in [-1.0, 1.0]:
		var sh: Vector2 = sh_l if side < 0 else sh_r
		var hand := _hand(sh, side, u * body_scale, pose, arm, t)
		DrawKit.capsule(ci, sh, hand, 24 * u * body_scale, top.darkened(0.1))
		ci.draw_circle(hand, 21 * u * body_scale, skin, true, -1.0, true)
	# Torso.
	var torso := PackedVector2Array([o + Vector2(-bw, 0) * u, o + Vector2(-bw * 0.92, -bh) * u + Vector2(0, breathe), o + Vector2(bw * 0.92, -bh) * u + Vector2(0, breathe), o + Vector2(bw, 0) * u])
	ci.draw_colored_polygon(torso, top)
	DrawKit.aa_rim(ci, torso, top.darkened(0.3), 2.0)
	if id == "bhai":
		for k in 3:
			var y := -bh * (0.25 + k * 0.25)
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-bw, y + 12) * u, o + Vector2(-bw, y - 10) * u, o + Vector2(bw, y - 10) * u, o + Vector2(bw, y + 12) * u]), accent)
	if c.get("apron", false):
		var ap := PackedVector2Array([o + Vector2(-bw * 0.6, 0) * u, o + Vector2(-bw * 0.5, -bh * 0.7) * u, o + Vector2(bw * 0.5, -bh * 0.7) * u, o + Vector2(bw * 0.6, 0) * u])
		ci.draw_colored_polygon(ap, accent)
		ci.draw_line(o + Vector2(-bw * 0.5, -bh * 0.7) * u, o + Vector2(-bw * 0.2, -bh) * u, accent, 6 * u)
		ci.draw_line(o + Vector2(bw * 0.5, -bh * 0.7) * u, o + Vector2(bw * 0.2, -bh) * u, accent, 6 * u)
		for k in 3:
			ci.draw_circle(o + Vector2(-bw * 0.3 + k * bw * 0.3, -bh * 0.35) * u, 7 * u, top, true, -1.0, true)
	if id == "kanchha":
		# Overalls bib, a pocket and a pencil.
		ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-bw * 0.55, 0) * u, o + Vector2(-bw * 0.5, -bh * 0.62) * u, o + Vector2(bw * 0.5, -bh * 0.62) * u, o + Vector2(bw * 0.55, 0) * u]), top.lightened(0.18))
		RenoArt.box(ci, Rect2(o + Vector2(-bw * 0.25, -bh * 0.5) * u, Vector2(bw * 0.5, bh * 0.2) * u), top.darkened(0.05), 6 * u, 3 * u)
		ci.draw_line(o + Vector2(bw * 0.1, -bh * 0.55) * u, o + Vector2(bw * 0.18, -bh * 0.38) * u, Color("f2b632"), 7 * u, true)
		for x in [-0.5, 0.5]:
			ci.draw_circle(o + Vector2(bw * x, -bh * 0.58) * u, 8 * u, Color("f2b632"), true, -1.0, true)
	if id == "maya":
		# Marigold dupatta over one shoulder.
		var sc := PackedVector2Array([o + Vector2(-bw * 0.95, -bh * 0.98) * u + Vector2(0, breathe), o + Vector2(-bw * 0.55, -bh * 1.02) * u + Vector2(0, breathe), o + Vector2(bw * 0.5, 0) * u, o + Vector2(bw * 0.05, 0) * u])
		ci.draw_colored_polygon(sc, accent)
		for k in 4:
			var p := o + Vector2(-bw * 0.6 + k * bw * 0.28, -bh * 0.8 + k * bh * 0.24) * u
			ci.draw_circle(p, 6 * u, accent.darkened(0.25), true, -1.0, true)
	if c.get("old", false):
		# Hajurama's shawl.
		var sh := PackedVector2Array([o + Vector2(-bw * 1.02, -bh * 0.55) * u, o + Vector2(-bw * 0.9, -bh * 1.02) * u + Vector2(0, breathe), o + Vector2(bw * 0.9, -bh * 1.02) * u + Vector2(0, breathe), o + Vector2(bw * 1.02, -bh * 0.55) * u, o + Vector2(0, -bh * 0.3) * u])
		ci.draw_colored_polygon(sh, Color("7b2d4f"))
		for k in 5:
			ci.draw_circle(o + Vector2(-bw * 0.8 + k * bw * 0.4, -bh * 0.62) * u, 7 * u, accent, true, -1.0, true)
		# Green bead necklace.
		for k in 9:
			var a := PI * 0.15 + PI * 0.7 * k / 8.0
			ci.draw_circle(o + Vector2(0, -bh * 0.98) * u + Vector2(cos(a) * 46, sin(a) * 40) * u + Vector2(0, breathe), 6 * u, Color("2e9e5b"), true, -1.0, true)
	# Neck and head.
	var head_r := 70.0 if not kid else 64.0
	var head := o + Vector2(0, -bh - 76 * (1.0 if not kid else 0.92)) * u + Vector2(0, breathe)
	ci.draw_rect(Rect2(head + Vector2(-20, 40) * u, Vector2(40, 42) * u), skin.darkened(0.15))
	_hair_back(ci, c, head, head_r, u, hair, t)
	for sx in [-1.0, 1.0]:
		ci.draw_circle(head + Vector2(sx * head_r * 0.95, 8) * u, 15 * u, skin.darkened(0.12), true, -1.0, true)
	var face := DrawKit.ellipse(head, head_r * u, (head_r + 6) * u, 40)
	ci.draw_colored_polygon(face, skin)
	DrawKit.aa_rim(ci, face, skin.darkened(0.3), 2.0)
	_face(ci, c, head, head_r, u, mood, blink)
	_hair_front(ci, c, head, head_r, u, hair, accent)


static func _hand(sh: Vector2, side: float, u: float, pose: String, arm: float, t: float) -> Vector2:
	var down := sh + Vector2(side * 30, 150) * u
	var up := sh + Vector2(side * 70, -130) * u
	var a := arm
	if pose == "wave":
		if side > 0:
			a = 1.0
			up += Vector2(sin(t * 12.0) * 26, 0) * u
		else:
			a = 0.0
	return down.lerp(up, a)


static func _face(ci: CanvasItem, c: Dictionary, head: Vector2, r: float, u: float, mood: String, blink: float) -> void:
	var ink := Color("2b1d16")
	var eye_y := -6.0
	var spread := 26.0
	var shut := blink > 0.5
	for sx in [-1.0, 1.0]:
		var e := head + Vector2(sx * spread, eye_y) * u
		match mood:
			"laugh":
				ci.draw_arc(e + Vector2(0, 6) * u, 11 * u, PI * 1.1, PI * 1.9, 10, ink, 5 * u, true)
			"surprised":
				ci.draw_circle(e, 13 * u, Color.WHITE, true, -1.0, true)
				ci.draw_circle(e, 13 * u, ink, false, 2.5 * u, true)
				ci.draw_circle(e + Vector2(0, 1) * u, 6.5 * u, ink, true, -1.0, true)
			"grumpy":
				ci.draw_circle(e + Vector2(0, 3) * u, 8 * u, ink, true, -1.0, true)
				ci.draw_rect(Rect2(e + Vector2(-11, -10) * u, Vector2(22, 9) * u), Color.html(c["skin"]))
			_:
				if shut:
					ci.draw_line(e + Vector2(-9, 1) * u, e + Vector2(9, 1) * u, ink, 4 * u, true)
				else:
					ci.draw_circle(e, 9 * u, ink, true, -1.0, true)
					ci.draw_circle(e + Vector2(-3, -3.5) * u, 3 * u, Color.WHITE, true, -1.0, true)
		# Brows.
		var brow := head + Vector2(sx * spread, eye_y - 22) * u
		var tilt := 0.0
		match mood:
			"worried":
				tilt = -0.35
			"grumpy":
				tilt = 0.4
			"surprised":
				brow += Vector2(0, -8) * u
		var dir := Vector2(cos(tilt * sx), sin(tilt * sx)) * 12 * u
		ci.draw_line(brow - dir, brow + dir, Color.html(c["hair"]).darkened(0.2) if c.has("old") else ink, 5 * u, true)
		if c.get("old", false):
			ci.draw_arc(head + Vector2(sx * (spread + 14), eye_y + 4) * u, 8 * u, -0.6, 0.6, 6, Color(0, 0, 0, 0.25), 2 * u, true)
		if mood in ["happy", "laugh"]:
			ci.draw_circle(head + Vector2(sx * 42, 22) * u, 12 * u, Color(0.95, 0.42, 0.4, 0.35), true, -1.0, true)
	if c.get("glasses", false):
		for sx in [-1.0, 1.0]:
			ci.draw_circle(head + Vector2(sx * spread, eye_y) * u, 19 * u, Color("8a6a3a"), false, 4 * u, true)
		ci.draw_line(head + Vector2(-8, eye_y) * u, head + Vector2(8, eye_y) * u, Color("8a6a3a"), 3 * u, true)
	# Nose.
	ci.draw_arc(head + Vector2(0, 14) * u, 6 * u, 0.3, PI - 0.3, 8, Color(0, 0, 0, 0.2), 3 * u, true)
	var m := head + Vector2(0, 34) * u
	if c.get("moustache", false):
		ci.draw_colored_polygon(PackedVector2Array([m + Vector2(-4, -8) * u, m + Vector2(-34, -2) * u, m + Vector2(-38, -10) * u, m + Vector2(-18, -16) * u, m + Vector2(0, -12) * u, m + Vector2(18, -16) * u, m + Vector2(38, -10) * u, m + Vector2(34, -2) * u, m + Vector2(4, -8) * u]), Color.html(c["hair"]))
	var lip := Color("7a2b22")
	match mood:
		"happy":
			ci.draw_arc(m + Vector2(0, -6) * u, 18 * u, 0.25, PI - 0.25, 14, lip, 5 * u, true)
		"laugh":
			var mouth := PackedVector2Array()
			for k in 13:
				var a := PI * k / 12.0
				mouth.append(m + Vector2(cos(a) * 20, sin(a) * 18 - 6) * u)
			ci.draw_colored_polygon(mouth, lip)
			ci.draw_colored_polygon(DrawKit.ellipse(m + Vector2(0, 6) * u, 9 * u, 4 * u, 10), Color("e86a6a"))
		"surprised":
			ci.draw_colored_polygon(DrawKit.ellipse(m + Vector2(0, 2) * u, 9 * u, 12 * u, 16), lip)
		"worried":
			var pts := PackedVector2Array()
			for k in 9:
				pts.append(m + Vector2(-16 + k * 4, sin(k * 1.4) * 3) * u)
			ci.draw_polyline(pts, lip, 4 * u, true)
		"grumpy":
			ci.draw_arc(m + Vector2(0, 12) * u, 15 * u, PI + 0.4, TAU - 0.4, 12, lip, 5 * u, true)
		_:
			ci.draw_arc(m + Vector2(0, -4) * u, 13 * u, 0.4, PI - 0.4, 10, lip, 4 * u, true)


static func _hair_back(ci: CanvasItem, c: Dictionary, head: Vector2, r: float, u: float, hair: Color, t: float) -> void:
	match String(c.get("hair_style", "")):
		"ponytail":
			var sway := sin(t * 1.8) * 6.0
			var tail := PackedVector2Array([head + Vector2(30, -40) * u, head + Vector2(70, -30) * u, head + Vector2(92 + sway, 60) * u, head + Vector2(70 + sway, 130) * u, head + Vector2(50, 40) * u])
			ci.draw_colored_polygon(tail, hair)
			ci.draw_colored_polygon(DrawKit.ellipse(head + Vector2(0, -8) * u, (r + 8) * u, (r + 10) * u, 36), hair)
		"bun", "bun_flower":
			ci.draw_circle(head + Vector2(0, -r - 6) * u, 34 * u, hair, true, -1.0, true)
			ci.draw_colored_polygon(DrawKit.ellipse(head + Vector2(0, -10) * u, (r + 6) * u, (r + 6) * u, 36), hair)
		"spiky", "cap":
			ci.draw_colored_polygon(DrawKit.ellipse(head + Vector2(0, -10) * u, (r + 4) * u, (r + 2) * u, 36), hair)


static func _hair_front(ci: CanvasItem, c: Dictionary, head: Vector2, r: float, u: float, hair: Color, accent: Color) -> void:
	match String(c.get("hair_style", "")):
		"ponytail":
			# Side-swept fringe.
			ci.draw_colored_polygon(PackedVector2Array([head + Vector2(-r - 4, -6) * u, head + Vector2(-r + 6, -54) * u, head + Vector2(-10, -r - 10) * u, head + Vector2(r - 4, -50) * u, head + Vector2(r + 4, -8) * u, head + Vector2(r - 12, -34) * u, head + Vector2(10, -40) * u, head + Vector2(-30, -26) * u, head + Vector2(-r + 12, -24) * u]), hair)
			ci.draw_circle(head + Vector2(-r + 2, 26) * u, 6 * u, accent, true, -1.0, true)
			ci.draw_circle(head + Vector2(r - 2, 26) * u, 6 * u, accent, true, -1.0, true)
		"bun", "bun_flower":
			ci.draw_colored_polygon(PackedVector2Array([head + Vector2(-r - 2, 0) * u, head + Vector2(-r + 10, -50) * u, head + Vector2(0, -r - 6) * u, head + Vector2(r - 10, -50) * u, head + Vector2(r + 2, 0) * u, head + Vector2(r - 14, -36) * u, head + Vector2(0, -50) * u, head + Vector2(-r + 14, -36) * u]), hair)
			ci.draw_line(head + Vector2(0, -r - 4) * u, head + Vector2(0, -44) * u, hair.darkened(0.25), 3 * u, true)
			if String(c.get("hair_style")) == "bun_flower":
				RenoArt._flower_static(ci, head + Vector2(30, -r - 14) * u, 22 * u, Color("ff9f1c"))
				ci.draw_circle(head + Vector2(-r + 2, 28) * u, 7 * u, Color("f2b632"), true, -1.0, true)
				ci.draw_circle(head + Vector2(r - 2, 28) * u, 7 * u, Color("f2b632"), true, -1.0, true)
		"spiky":
			var pts := PackedVector2Array([head + Vector2(-r - 2, -8) * u])
			for k in 7:
				var x := -r + k * r * 2.0 / 6.0
				pts.append(head + Vector2(x, -r - (18 if k % 2 == 0 else 2)) * u)
			pts.append(head + Vector2(r + 2, -8) * u)
			pts.append(head + Vector2(r - 10, -30) * u)
			pts.append(head + Vector2(-r + 10, -30) * u)
			ci.draw_colored_polygon(pts, hair)
		"cap":
			var cap_c := Color("e0533d")
			var dome := PackedVector2Array()
			for k in 21:
				var a := PI + PI * k / 20.0
				dome.append(head + Vector2(cos(a) * (r + 6), sin(a) * (r * 0.72) - 36) * u)
			ci.draw_colored_polygon(dome, cap_c)
			ci.draw_colored_polygon(PackedVector2Array([head + Vector2(-r - 6, -38) * u, head + Vector2(r + 60, -38) * u, head + Vector2(r + 50, -26) * u, head + Vector2(-r - 6, -26) * u]), cap_c.darkened(0.2))
			ci.draw_circle(head + Vector2(0, -r * 0.72 - 36) * u, 8 * u, cap_c.lightened(0.3), true, -1.0, true)


## Biralo, an orange tabby, sitting. Origin = bottom centre.
static func draw_cat(ci: CanvasItem, origin: Vector2, unit: float, mood: String = "neutral", t: float = 0.0, blink: float = 0.0) -> void:
	var u := unit
	var fur := Color("f0a04b")
	var dark := Color("c46f26")
	var light := Color("ffe1b8")
	var o := origin
	# Tail with a flick.
	var flick := sin(t * 2.2) * 0.4 + (sin(t * 7.0) * 0.3 if fmod(t, 5.0) < 0.6 else 0.0)
	var tail := PackedVector2Array()
	for k in 14:
		var s := k / 13.0
		tail.append(o + Vector2(90 + s * 60 * cos(flick * s * 3), -20 - s * 150 + sin(flick * s * 4) * 30) * u)
	ci.draw_polyline(tail, dark, 26 * u, true)
	ci.draw_polyline(tail, fur, 18 * u, true)
	# Body.
	var body := DrawKit.ellipse(o + Vector2(0, -95) * u, 100 * u, 100 * u, 36)
	ci.draw_colored_polygon(body, fur)
	ci.draw_colored_polygon(DrawKit.ellipse(o + Vector2(0, -70) * u, 56 * u, 66 * u, 24), light)
	for k in 3:
		ci.draw_arc(o + Vector2(0, -95) * u, (80 - k * 4) * u, PI * (1.15 + k * 0.08), PI * (1.3 + k * 0.08), 6, dark, 8 * u, true)
	# Paws.
	for sx in [-1.0, 1.0]:
		ci.draw_colored_polygon(DrawKit.ellipse(o + Vector2(sx * 40, -10) * u, 28 * u, 16 * u, 16), light)
	# Head.
	var h := o + Vector2(0, -230) * u
	for sx in [-1.0, 1.0]:
		var ear := PackedVector2Array([h + Vector2(sx * 30, -50) * u, h + Vector2(sx * 78, -96) * u, h + Vector2(sx * 74, -24) * u])
		ci.draw_colored_polygon(ear, fur)
		ci.draw_colored_polygon(PackedVector2Array([h + Vector2(sx * 42, -50) * u, h + Vector2(sx * 72, -82) * u, h + Vector2(sx * 68, -38) * u]), Color("ffb3a7"))
	ci.draw_colored_polygon(DrawKit.ellipse(h, 84 * u, 72 * u, 36), fur)
	for k in 3:
		ci.draw_line(h + Vector2(-14 + k * 14, -70) * u, h + Vector2(-10 + k * 10, -44) * u, dark, 7 * u, true)
	ci.draw_colored_polygon(DrawKit.ellipse(h + Vector2(0, 24) * u, 40 * u, 28 * u, 20), light)
	var ink := Color("2b1d16")
	for sx in [-1.0, 1.0]:
		var e := h + Vector2(sx * 32, -6) * u
		match mood:
			"laugh", "happy":
				ci.draw_arc(e + Vector2(0, 6) * u, 12 * u, PI * 1.1, PI * 1.9, 10, ink, 5 * u, true)
			"grumpy":
				ci.draw_colored_polygon(DrawKit.ellipse(e + Vector2(0, 4) * u, 14 * u, 6 * u, 12), Color("8fd14f"))
				ci.draw_line(e + Vector2(-14, -4) * u, e + Vector2(14, -4) * u, ink, 4 * u, true)
			_:
				if blink > 0.5:
					ci.draw_line(e + Vector2(-12, 0) * u, e + Vector2(12, 0) * u, ink, 4 * u, true)
				else:
					var big := 1.3 if mood == "surprised" else 1.0
					ci.draw_colored_polygon(DrawKit.ellipse(e, 15 * u * big, 18 * u * big, 16), Color("8fd14f"))
					ci.draw_colored_polygon(DrawKit.ellipse(e, 5 * u * big, 14 * u * big, 12), ink)
					ci.draw_circle(e + Vector2(-5, -6) * u, 4 * u, Color.WHITE, true, -1.0, true)
		for k in 3:
			ci.draw_line(h + Vector2(sx * 30, 26 + k * 8) * u, h + Vector2(sx * 96, 14 + k * 14) * u, Color(1, 1, 1, 0.8), 2.5 * u, true)
	ci.draw_colored_polygon(PackedVector2Array([h + Vector2(-9, 14) * u, h + Vector2(9, 14) * u, h + Vector2(0, 24) * u]), Color("e46a7a"))
	if mood in ["surprised", "worried"]:
		ci.draw_colored_polygon(DrawKit.ellipse(h + Vector2(0, 40) * u, 8 * u, 10 * u, 12), Color("7a2b22"))
	else:
		ci.draw_arc(h + Vector2(-8, 28) * u, 8 * u, 0.2, PI - 0.4, 8, ink, 3 * u, true)
		ci.draw_arc(h + Vector2(8, 28) * u, 8 * u, 0.4, PI - 0.2, 8, ink, 3 * u, true)
