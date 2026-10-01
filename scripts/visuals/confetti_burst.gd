class_name ConfettiBurst
extends CPUParticles2D
## Pooled paper confetti in the shop palette (level complete).

const COLORS := ["ee8a1f", "1d6b74", "f2b632", "f2769f", "44a5ec", "fff8ec"]

var _release_tween: Tween


func _init() -> void:
	one_shot = true
	emitting = false
	amount = 36
	lifetime = 2.6
	explosiveness = 0.85
	local_coords = false
	texture = DrawKit.paper_texture()
	direction = Vector2(0, 1)
	spread = 50.0
	gravity = Vector2(0, 520)
	initial_velocity_min = 120.0
	initial_velocity_max = 420.0
	damping_min = 60.0
	damping_max = 120.0
	angular_velocity_min = -420.0
	angular_velocity_max = 420.0
	scale_amount_min = 0.8
	scale_amount_max = 1.5
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	z_index = 45
	var g := Gradient.new()
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for i in COLORS.size():
		g.add_point(float(i) / float(COLORS.size() - 1), Color(COLORS[i]))
	color_initial_ramp = g


func burst(pos: Vector2, width: float) -> void:
	global_position = pos
	emission_rect_extents = Vector2(width * 0.16, 10)
	restart()
	emitting = true
	if _release_tween:
		_release_tween.kill()
	_release_tween = create_tween()
	_release_tween.tween_interval(lifetime + 0.2)
	_release_tween.tween_callback(func() -> void: PoolManager.release(self))
