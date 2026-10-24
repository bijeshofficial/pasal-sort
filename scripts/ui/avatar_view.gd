class_name AvatarView
extends Control
## Draws one of the eight avatars.

var index := 0:
	set(v):
		index = v
		queue_redraw()
## Avatar frame cosmetic id ("" = the selected one).
var frame := ""
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if Engine.get_process_frames() % 3 == 0:
		queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	draw_circle(size * 0.5, r, Color.WHITE, true, -1.0, true)
	if not AvatarArt.draw_painted(self, size * 0.5, r - 6, index):
		AvatarArt.draw_avatar(self, size * 0.5, r - 6, index)
	var fid := frame if frame != "" else ProgressionManager.selected_cosmetic("frame")
	var item := GameData.cosmetic(fid)
	# Painted frame ring (assets/art/avatars/frames/<id>), its opening fits
	# the avatar circle.
	var ft := Art.tex("avatars/frames/" + fid)
	if ft:
		var fs := r * 2.0 * 1.22
		draw_texture_rect(ft, Rect2(size * 0.5 - Vector2(fs, fs) * 0.5, Vector2(fs, fs)), false)
	elif not item.is_empty():
		AvatarArt.draw_frame(self, size * 0.5, r, item, _t)
