class_name DustPoof
extends CPUParticles2D
## Pooled dust cloud for renovations: soft puffs that billow out and fade.

var _release_tween: Tween


func _init() -> void:
	one_shot = true
	emitting = false
	amount = 22
	lifetime = 0.9
	explosiveness = 0.9
	local_coords = false
	texture = DrawKit.circle_texture(32)
	direction = Vector2(0, -1)
	spread = 180.0
	gravity = Vector2(0, -40)
	initial_velocity_min = 120.0
	initial_velocity_max = 320.0
	damping_min = 220.0
	damping_max = 360.0
	scale_amount_min = 1.2
	scale_amount_max = 3.4
	z_index = 70
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1, 1.2))
	scale_amount_curve = curve
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 0.97, 0.9, 0.9))
	fade.set_color(1, Color(0.95, 0.9, 0.8, 0))
	color_ramp = fade


func burst(pos: Vector2, size: float) -> void:
	global_position = pos
	emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = clampf(size * 0.3, 30.0, 220.0)
	initial_velocity_max = clampf(size * 0.8, 200.0, 520.0)
	restart()
	emitting = true
	if _release_tween:
		_release_tween.kill()
	_release_tween = create_tween()
	_release_tween.tween_interval(lifetime + 0.2)
	_release_tween.tween_callback(func() -> void: PoolManager.release(self))
