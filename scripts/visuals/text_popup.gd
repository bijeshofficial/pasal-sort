class_name TextPopup
extends Node2D
## Pooled floating text ("PERFECT", "+120", "MISS"): pops in, rises, fades.

var text := ""
var color := Color.WHITE
var font_size := 72
var _tween: Tween


func show_text(value: String, pos: Vector2, col: Color, size: int, rise: float, duration: float) -> void:
	text = value
	color = col
	font_size = size
	position = pos
	modulate.a = 1.0
	scale = Vector2(0.4, 0.4)
	z_index = 50
	queue_redraw()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.08)
	_tween.parallel().tween_property(self, "position:y", pos.y - rise, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, 0.22)
	_tween.tween_callback(func() -> void: PoolManager.release(self))


func _draw() -> void:
	var f := UIKit.font(true)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2(-w * 0.5, font_size * 0.35)
	draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(8, font_size / 6), Color("2b2622"))
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
