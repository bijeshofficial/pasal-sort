class_name PageTurnView
extends Control
## A captured frame that turns away like a storybook page (right edge first).
## progress 0 = flat page covering the screen, 1 = page gone.

var texture: Texture2D
var progress := 0.0:
	set(v):
		progress = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	if texture == null:
		return
	var w := size.x
	var h := size.y
	var tex_size := texture.get_size()
	# The fold moves from the right edge to past the left edge.
	var fold := lerpf(w, -w * 0.25, progress)
	var flap := minf(w - fold, maxf(0.0, fold + w * 0.25)) * 0.5
	var visible_w := clampf(fold, 0.0, w)
	if visible_w > 1.0:
		var src := Rect2(Vector2.ZERO, Vector2(tex_size.x * visible_w / w, tex_size.y))
		draw_texture_rect_region(texture, Rect2(0, 0, visible_w, h), src)
		# Shade near the fold.
		var shade := minf(120.0, visible_w)
		var pts := PackedVector2Array([Vector2(visible_w - shade, 0), Vector2(visible_w, 0), Vector2(visible_w, h), Vector2(visible_w - shade, h)])
		draw_polygon(pts, PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0)]))
	# The back of the page, curling over.
	if flap > 1.0 and fold < w:
		var back := PackedVector2Array([Vector2(fold, 0), Vector2(fold + flap, -h * 0.02), Vector2(fold + flap * 0.9, h * 1.02), Vector2(fold, h)])
		draw_colored_polygon(back, Color("fff4dc"))
		draw_polygon(back, PackedColorArray([Color(1, 1, 1, 0.0), Color(0.6, 0.45, 0.3, 0.35), Color(0.6, 0.45, 0.3, 0.35), Color(1, 1, 1, 0.0)]))
		draw_line(Vector2(fold, 0), Vector2(fold, h), Color(0.55, 0.4, 0.25, 0.6), 3.0)
		# Shadow cast on the new scene.
		var sh := PackedVector2Array([Vector2(fold + flap, 0), Vector2(fold + flap + 60, 0), Vector2(fold + flap * 0.9 + 60, h), Vector2(fold + flap * 0.9, h)])
		draw_polygon(sh, PackedColorArray([Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.25)]))
