class_name SparkleBurst
extends CPUParticles2D
## Pooled one-shot sparkle burst (lid pops, reveals, unlocks).

var _release_tween: Tween


func _init() -> void:
	one_shot = true
	emitting = false
	amount = 14
	lifetime = 0.55
	explosiveness = 0.95
	local_coords = false
	texture = DrawKit.sparkle_texture()
	direction = Vector2(0, -1)
	spread = 180.0
	gravity = Vector2(0, 260)
	initial_velocity_min = 220.0
	initial_velocity_max = 480.0
	damping_min = 200.0
	damping_max = 320.0
	scale_amount_min = 0.8
	scale_amount_max = 1.8
	angular_velocity_min = -180.0
	angular_velocity_max = 180.0
	z_index = 40
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	color_ramp = fade


func burst(pos: Vector2, col: Color, amount_scale: float = 1.0) -> void:
	global_position = pos
	color = col
	var a := maxi(4, int(14 * amount_scale))
	if amount != a:
		amount = a
	restart()
	emitting = true
	if _release_tween:
		_release_tween.kill()
	_release_tween = create_tween()
	_release_tween.tween_interval(lifetime + 0.15)
	_release_tween.tween_callback(func() -> void: PoolManager.release(self))
