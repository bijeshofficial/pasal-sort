class_name AreaBackdrop
extends Node2D
## What sits behind an area's objects: the sky, mountains, neighbouring
## houses or a plain interior. `saturation` (0..1) washes the whole backdrop
## out while the area is still shabby; it fills with colour as tasks are done.
## Types: interior, exterior, rooftop, courtyard, night, lakeside, mountain.

const SAT_SHADER := """
shader_type canvas_item;
uniform float saturation = 1.0;
void fragment() {
	vec4 c = COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(vec3(g), c.rgb, saturation), c.a);
}
"""

var kind := "interior"
var world := Vector2(1800, 1500)
var night := false
var saturation := 1.0:
	set(v):
		saturation = v
		if material:
			(material as ShaderMaterial).set_shader_parameter("saturation", v)

static var _shader: Shader


func _init() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SAT_SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	material = m


func setup(type_name: String, size: Vector2, is_night: bool) -> void:
	kind = type_name
	world = size
	night = is_night
	queue_redraw()


## Colours that continue past the world's top and bottom edges (seen behind
## the top bar and the bottom buttons).
func edge_colors() -> Array:
	match kind:
		"interior":
			return [Color("3b2716"), Color("2e2018")]
		"night":
			return [Color("101a3a"), Color("2a2340")]
		"lakeside":
			return [Color("7fd0ff") if not night else Color("1a2550"), Color("c9b48a")]
		"mountain":
			return [Color("4aa8ff") if not night else Color("101a3a"), Color("9bb07a")]
	return [Color("6fc3ff") if not night else Color("1a2550"), Color("8d7f6c")]


func _draw() -> void:
	var w := world.x
	var h := world.y
	var edges := edge_colors()
	draw_rect(Rect2(-3000, -3000, w + 6000, 3000), edges[0])
	draw_rect(Rect2(-3000, h, w + 6000, 3000), edges[1])
	draw_rect(Rect2(-3000, 0, 3000, h), edges[0])
	draw_rect(Rect2(w, 0, 3000, h), edges[0])
	match kind:
		"interior":
			draw_rect(Rect2(Vector2.ZERO, world), Color("3b2a20"))
		"night":
			_sky(Color("101a3a"), Color("3b2f6b"), h * 0.75)
			_stars(w, h * 0.6)
			draw_circle(Vector2(w * 0.8, h * 0.14), 70, Color("fff3c4"), true, -1.0, true)
			draw_circle(Vector2(w * 0.8 + 26, h * 0.14 - 16), 62, Color("3b2f6b").lerp(Color("101a3a"), 0.5), true, -1.0, true)
			_mountains(h * 0.62, Color("2d2f5c"), Color("b9bfe0"), 0.6)
			_houses(h * 0.78, Color("232448"), true)
			draw_rect(Rect2(0, h * 0.78, w, h * 0.22), Color("2a2340"))
		"exterior", "courtyard":
			_sky(Color("6fc3ff") if not night else Color("1a2550"), Color("dff3ff") if not night else Color("4b3f7a"), h * 0.75)
			_mountains(h * 0.48, Color("8aa0c8") if not night else Color("3a4170"), Color.WHITE, 1.0)
			_houses(h * 0.8, Color("c98b6b") if not night else Color("4a3a5a"), night)
			draw_rect(Rect2(0, h * 0.74, w, h * 0.26), Color("b8a68c") if not night else Color("4a4250"))
		"rooftop":
			_sky(Color("5ab8ff") if not night else Color("1a2550"), Color("ffe9c7") if not night else Color("4b3f7a"), h * 0.8)
			_mountains(h * 0.5, Color("7d95c0") if not night else Color("3a4170"), Color.WHITE, 1.2)
			_houses(h * 0.72, Color("b5806a") if not night else Color("4a3a5a"), night)
			draw_rect(Rect2(0, h * 0.7, w, h * 0.3), Color("a89a88"))
		"lakeside":
			_sky(Color("7fd0ff") if not night else Color("1a2550"), Color("fff0d6") if not night else Color("4b3f7a"), h * 0.6)
			_mountains(h * 0.42, Color("7d95c0"), Color.WHITE, 1.4)
			_hills(h * 0.5, Color("5f9e5a"))
			var lake := PackedVector2Array([Vector2(0, h * 0.5), Vector2(w, h * 0.5), Vector2(w, h * 0.78), Vector2(0, h * 0.78)])
			DrawKit.gradient_fill(self, lake, Color("4aa3c8"), Color("2d7fa6"))
			for k in 8:
				var y := h * (0.53 + k * 0.03)
				draw_line(Vector2(w * (0.1 + 0.07 * k), y), Vector2(w * (0.25 + 0.07 * k), y), Color(1, 1, 1, 0.3), 3.0)
			draw_rect(Rect2(0, h * 0.76, w, h * 0.24), Color("c9b48a"))
		"mountain":
			_sky(Color("4aa8ff") if not night else Color("101a3a"), Color("e6f4ff") if not night else Color("3b2f6b"), h * 0.7)
			_mountains(h * 0.62, Color("8aa0c8"), Color.WHITE, 2.2)
			_pines(h * 0.7)
			draw_rect(Rect2(0, h * 0.7, w, h * 0.3), Color("9bb07a"))
		_:
			draw_rect(Rect2(Vector2.ZERO, world), Color("6fc3ff"))


func _sky(top: Color, bottom: Color, horizon: float) -> void:
	DrawKit.gradient_fill(self, PackedVector2Array([Vector2.ZERO, Vector2(world.x, 0), Vector2(world.x, horizon), Vector2(0, horizon)]), top, bottom)
	draw_rect(Rect2(0, horizon, world.x, world.y - horizon), bottom)


func _mountains(base_y: float, color: Color, snow: Color, height: float) -> void:
	var w := world.x
	var peaks := [[0.0, 0.0], [0.12, 0.35], [0.24, 0.18], [0.4, 0.55], [0.52, 0.3], [0.66, 0.62], [0.8, 0.28], [0.92, 0.45], [1.0, 0.2]]
	var amp := 360.0 * height
	var pts := PackedVector2Array([Vector2(0, base_y)])
	for p in peaks:
		pts.append(Vector2(float(p[0]) * w, base_y - float(p[1]) * amp))
	pts.append(Vector2(w, base_y))
	draw_colored_polygon(pts, color)
	for i in range(1, peaks.size() - 1):
		var top := Vector2(float(peaks[i][0]) * w, base_y - float(peaks[i][1]) * amp)
		if float(peaks[i][1]) > 0.3:
			var cap := 60.0 * height
			draw_colored_polygon(PackedVector2Array([top, top + Vector2(cap * 0.9, cap * 0.8), top + Vector2(cap * 0.3, cap * 0.6), top + Vector2(-cap * 0.2, cap * 0.85), top + Vector2(-cap * 0.9, cap * 0.8)]), snow)


func _hills(base_y: float, color: Color) -> void:
	var pts := PackedVector2Array([Vector2(0, base_y)])
	for k in 13:
		pts.append(Vector2(world.x * k / 12.0, base_y - 80 - sin(k * 1.3) * 60))
	pts.append(Vector2(world.x, base_y))
	draw_colored_polygon(pts, color)


func _houses(base_y: float, color: Color, lit: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var x := -40.0
	while x < world.x:
		var bw := rng.randf_range(160, 280)
		var bh := rng.randf_range(260, 480)
		var c := color.darkened(rng.randf_range(0.0, 0.2))
		draw_rect(Rect2(x, base_y - bh, bw, bh), c)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 16, base_y - bh), Vector2(x + bw + 16, base_y - bh), Vector2(x + bw * 0.5, base_y - bh - 70)]), c.darkened(0.25))
		for j in int(bh / 120.0):
			for i in int(bw / 90.0):
				var wr := Rect2(x + 26 + i * 90, base_y - bh + 40 + j * 120, 44, 60)
				draw_rect(wr, Color("ffd88a") if lit and (i + j) % 2 == 0 else c.darkened(0.35))
		x += bw + rng.randf_range(10, 40)


func _stars(w: float, h: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 60:
		draw_circle(Vector2(rng.randf() * w, rng.randf() * h), rng.randf_range(1.5, 3.5), Color(1, 1, 1, rng.randf_range(0.4, 0.9)), true, -1.0, true)


func _pines(base_y: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var x := 0.0
	while x < world.x:
		var ph := rng.randf_range(160, 260)
		var c := Color("2f6b4a").darkened(rng.randf_range(0, 0.2))
		for k in 3:
			var y := base_y - k * ph * 0.28
			var half := ph * (0.32 - k * 0.07)
			draw_colored_polygon(PackedVector2Array([Vector2(x - half, y), Vector2(x + half, y), Vector2(x, y - ph * 0.45)]), c)
		x += rng.randf_range(70, 140)
