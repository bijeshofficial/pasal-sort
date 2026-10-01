class_name AvatarView
extends Control
## Draws one of the eight avatars.

var index := 0:
	set(v):
		index = v
		queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	draw_circle(size * 0.5, r, Color.WHITE, true, -1.0, true)
	AvatarArt.draw_avatar(self, size * 0.5, r - 6, index)
