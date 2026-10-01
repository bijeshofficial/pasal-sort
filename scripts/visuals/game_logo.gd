class_name GameLogo
extends RefCounted
## The PASAL SORT logo: chunky extruded letters with a thick outline and a
## drop shadow, flanked by two candies. Drawn in code.

const OUTLINE := Color("26165e")


## Draws the logo centred horizontally at `c` (top of "PASAL" cap height).
static func draw(ci: CanvasItem, c: Vector2, k: float = 1.0) -> void:
	var f := UIKit.font(true)
	var s1 := int(168 * k)
	var s2 := int(100 * k)
	var w1 := f.get_string_size("PASAL", HORIZONTAL_ALIGNMENT_LEFT, -1, s1).x
	var w2 := f.get_string_size("SORT", HORIZONTAL_ALIGNMENT_LEFT, -1, s2).x
	var p1 := Vector2(c.x - w1 * 0.5, c.y + s1 * 0.78)
	var p2 := Vector2(c.x - w2 * 0.5, p1.y + s2 * 0.92)
	_word(ci, f, "PASAL", p1, s1, Color("ffd93b"), Color("ff8a1f"), k)
	_word(ci, f, "SORT", p2, s2, Color.WHITE, Color("ff4fa3"), k)
	CandyArt.draw_candy(ci, Vector2(c.x - w1 * 0.5 - 92 * k, c.y + s1 * 0.4), 150 * k, 2)
	CandyArt.draw_candy(ci, Vector2(c.x + w1 * 0.5 + 92 * k, c.y + s1 * 0.4), 150 * k, 7)


static func _word(ci: CanvasItem, f: Font, text: String, pos: Vector2, size: int, face: Color, side: Color, k: float) -> void:
	var depth := 9.0 * k
	var ol := int(30 * k)
	# Shadow, then outline around the extrusion, then the extrusion, then the face.
	ci.draw_string_outline(f, pos + Vector2(0, depth + 10 * k), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ol, Color(OUTLINE, 0.5))
	ci.draw_string_outline(f, pos + Vector2(0, depth), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ol, OUTLINE)
	ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ol, OUTLINE)
	for d in range(int(depth), 0, -2):
		ci.draw_string(f, pos + Vector2(0, d), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, side.darkened(0.15))
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, face)
	# Gloss: a lighter copy nudged up and faded.
	ci.draw_string(f, pos + Vector2(0, -2 * k), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.25))
