class_name CoinVisual
extends Node2D
## Pooled flying coin (win screen -> coin counter).

var _tween: Tween


func _draw() -> void:
	draw_circle(Vector2.ZERO, 30, Color("b07c14"), true, -1.0, true)
	draw_circle(Vector2(0, -3), 27, Color("f2b632"), true, -1.0, true)
	draw_arc(Vector2(0, -3), 18, 0, TAU, 28, Color("d69a1c"), 5, true)
	draw_line(Vector2(0, -13), Vector2(0, 7), Color("b07c14"), 6, true)


func fly(from: Vector2, to: Vector2, delay: float, on_arrive: Callable) -> void:
	position = from
	scale = Vector2.ZERO
	z_index = 60
	queue_redraw()
	if _tween:
		_tween.kill()
	var mid := from.lerp(to, 0.5) + Vector2(randf_range(-160, 160), -180)
	_tween = create_tween()
	_tween.tween_interval(delay)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(t: float) -> void:
		position = from.lerp(mid, t).lerp(mid.lerp(to, t), t), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void:
		on_arrive.call()
		PoolManager.release(self))
