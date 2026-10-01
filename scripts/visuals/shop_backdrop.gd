class_name ShopBackdrop
extends Control
## Vibrant game backdrop behind every screen: a rich three-stop gradient,
## soft bokeh lights, twinkling sparkles and a low silhouette that changes
## with the Shop theme (Kathmandu rooftops, terraced hills, Himalaya).
## `drift` gives a slight parallax to the silhouette and bokeh.

const THEMES := {
	"theme_asan": {"top": "3428c4", "mid": "6c3ae0", "bottom": "c24fd8", "sil": "241785", "glow": "ffd36b", "skyline": "roofs", "lights": ""},
	"theme_thamel": {"top": "16185a", "mid": "47288f", "bottom": "e4578f", "sil": "1a1050", "glow": "ffcf6b", "skyline": "roofs", "lights": "ffcf6b"},
	"theme_hill": {"top": "1b8fe0", "mid": "35bcd6", "bottom": "8fe08a", "sil": "157087", "glow": "ffffff", "skyline": "hills", "lights": ""},
	"theme_tihar": {"top": "110b3a", "mid": "36106c", "bottom": "8c1f7c", "sil": "0d0630", "glow": "ffae3b", "skyline": "roofs", "lights": "ffb13b"},
	"theme_snow": {"top": "2775dc", "mid": "5aaef5", "bottom": "cdeaff", "sil": "ffffff", "glow": "ffffff", "skyline": "peaks", "lights": ""},
}

var theme_id := "theme_asan":
	set(v):
		theme_id = v if THEMES.has(v) else "theme_asan"
		queue_redraw()
var drift := 0.0:
	set(v):
		drift = v
		queue_redraw()
## Where the silhouette sits, as a fraction of the height.
var horizon := 0.8
## Calm mode (behind the puzzle): a deeper, quieter gradient with no bokeh,
## sparkles or light pools, so the glass jars and candies stand out.
var calm := false:
	set(v):
		calm = v
		queue_redraw()
## Unused by the game look; kept so older callers still work.
var wainscot := 0.7
var window_top := 0.05
var window_height := 0.2

var _twinkles: Control
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	_twinkles = Control.new()
	_twinkles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_twinkles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_twinkles.draw.connect(_draw_twinkles)
	add_child(_twinkles)


func _process(delta: float) -> void:
	_t += delta
	if _twinkles and is_visible_in_tree():
		_twinkles.queue_redraw()


func pal(key: String) -> Color:
	return Color.html(String(THEMES[theme_id][key]))


func is_dark() -> bool:
	return theme_id != "theme_snow" and theme_id != "theme_hill"


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return
	var u := w / 1080.0
	var top := pal("top")
	var mid := pal("mid")
	var bottom := pal("bottom")
	if calm:
		top = top.darkened(0.35).lerp(Color("1a1440"), 0.25)
		mid = mid.darkened(0.42).lerp(Color("1a1440"), 0.3)
		bottom = bottom.darkened(0.5).lerp(Color("1a1440"), 0.35)
	# Three-stop vertical gradient.
	var m := h * 0.55
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, m), Vector2(0, m)]), PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, m), Vector2(w, m), Vector2(w, h), Vector2(0, h)]), PackedColorArray([mid, mid, bottom, bottom]))
	if calm:
		_draw_calm(w, h, u)
		return
	# Soft light pooling at the top centre.
	for k in 5:
		var rr := (520.0 - k * 80.0) * u
		draw_colored_polygon(DrawKit.ellipse(Vector2(w * 0.5, h * 0.18), rr * 1.3, rr, 40), Color(1, 1, 1, 0.025))
	# Bokeh: soft out-of-focus lights.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(theme_id)
	var glow := pal("glow")
	for i in 22:
		var p := Vector2(rng.randf() * w, rng.randf() * h * 0.95)
		p.x += drift * 14.0 * u * (0.5 + rng.randf())
		var r := rng.randf_range(24, 90) * u
		var col := glow if rng.randf() < 0.5 else Color.WHITE
		var a := rng.randf_range(0.04, 0.1)
		draw_circle(p, r, Color(col, a), true, -1.0, true)
		draw_circle(p, r * 0.7, Color(col, a * 0.8), true, -1.0, true)
		draw_arc(p, r, 0, TAU, 32, Color(col, a * 1.4), 2.0 * u, true)
	# Silhouette near the bottom.
	var sil := pal("sil")
	var base_y := h * horizon
	var shift := drift * 8.0 * u
	match String(THEMES[theme_id]["skyline"]):
		"roofs":
			_roofs(base_y, w, h, u, shift, Color(sil, 0.42))
		"hills":
			for k in 3:
				var col := Color(sil, 0.22 + 0.12 * k)
				var y := base_y - (90 - 45 * k) * u
				var pts := PackedVector2Array([Vector2(0, h)])
				for i in 25:
					var x := w * i / 24.0
					pts.append(Vector2(x, y + sin(i * 0.7 + k * 1.3) * 26 * u + shift * 0.5))
				pts.append(Vector2(w, h))
				draw_colored_polygon(pts, col)
		"peaks":
			var peaks := [[0.0, 260.0], [0.22, 380.0], [0.45, 300.0], [0.68, 420.0], [0.9, 320.0], [1.1, 360.0]]
			for pk in peaks:
				var px: float = w * float(pk[0]) + shift
				var ph: float = float(pk[1]) * u
				draw_colored_polygon(PackedVector2Array([Vector2(px - ph, h), Vector2(px - ph * 0.9, base_y + 40 * u), Vector2(px, base_y - ph * 0.6), Vector2(px + ph * 0.9, base_y + 40 * u), Vector2(px + ph, h)]), Color(Color("a9c9ee"), 0.6))
				draw_colored_polygon(PackedVector2Array([Vector2(px - ph * 0.28, base_y - ph * 0.6 + ph * 0.28), Vector2(px, base_y - ph * 0.6), Vector2(px + ph * 0.28, base_y - ph * 0.6 + ph * 0.28), Vector2(px + ph * 0.08, base_y - ph * 0.6 + ph * 0.22), Vector2(px - ph * 0.06, base_y - ph * 0.6 + ph * 0.26)]), Color(1, 1, 1, 0.85))
	if String(THEMES[theme_id]["lights"]) != "":
		_string_lights(Rect2(0, h * 0.02, w, 60 * u), u)
	if theme_id == "theme_tihar":
		_garland(w, u)


## Calm: only a faint skyline at the very bottom and a soft vignette.
func _draw_calm(w: float, h: float, u: float) -> void:
	var sil := pal("sil")
	match String(THEMES[theme_id]["skyline"]):
		"roofs":
			_roofs(h * 0.92, w, h, u, 0.0, Color(sil.darkened(0.4), 0.35))
		_:
			var pts := PackedVector2Array([Vector2(0, h)])
			for i in 13:
				pts.append(Vector2(w * i / 12.0, h * 0.9 - sin(i * 0.8) * 30 * u))
			pts.append(Vector2(w, h))
			draw_colored_polygon(pts, Color(sil.darkened(0.4), 0.3))
	# Vignette: darker edges keep the eye on the jars.
	for k in 6:
		var a := 0.05
		draw_rect(Rect2(0, 0, w * (0.05 + k * 0.012), h), Color(0, 0, 0.05, a))
		draw_rect(Rect2(w - w * (0.05 + k * 0.012), 0, w * (0.05 + k * 0.012), h), Color(0, 0, 0.05, a))


## Kathmandu-style rooftops: sloped tiled roofs, a few tall Newari houses.
func _roofs(base_y: float, w: float, h: float, u: float, shift: float, col: Color) -> void:
	var x := -40.0 * u + shift
	var i := 0
	var lit := String(THEMES[theme_id]["lights"]) != ""
	while x < w + 40 * u:
		var bw := (110.0 + 40.0 * ((i * 7) % 3)) * u
		var bh := (120.0 + 70.0 * ((i * 5) % 4)) * u
		var top := base_y - bh
		draw_rect(Rect2(x, top, bw, h - top), col)
		# Sloped roof with eaves.
		draw_colored_polygon(PackedVector2Array([Vector2(x - 14 * u, top + 6 * u), Vector2(x + bw * 0.5, top - 46 * u), Vector2(x + bw + 14 * u, top + 6 * u)]), col)
		# Little windows.
		var wc := Color(pal("lights"), 0.55) if lit else Color(1, 1, 1, 0.08)
		for row in 2:
			for k in 2:
				draw_rect(Rect2(x + bw * (0.22 + 0.36 * k), top + 30 * u + row * 54 * u, bw * 0.2, 28 * u), wc)
		x += bw + 6 * u
		i += 1


func _string_lights(r: Rect2, u: float) -> void:
	var col := pal("lights")
	var prev := Vector2.ZERO
	for i in 19:
		var t := i / 18.0
		var p := Vector2(r.position.x + r.size.x * t, r.position.y + 20 * u + sin(t * PI * 3.0) * 16 * u)
		if i > 0:
			draw_line(prev, p, Color(0, 0, 0, 0.35), 2 * u, true)
		prev = p
		draw_circle(p + Vector2(0, 8 * u), 14 * u, Color(col, 0.25), true, -1.0, true)
		draw_circle(p + Vector2(0, 8 * u), 7 * u, col, true, -1.0, true)


func _garland(w: float, u: float) -> void:
	for i in 26:
		var t := i / 25.0
		var p := Vector2(w * t, 110 * u + sin(t * PI) * 50 * u)
		draw_circle(p, 13 * u, Color("f39a1e") if i % 2 == 0 else Color("f7c52e"), true, -1.0, true)


func _draw_twinkles() -> void:
	if calm:
		return
	var w := size.x
	var h := size.y
	var u := w / 1080.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(theme_id) + 7
	for i in 16:
		var p := Vector2(rng.randf() * w, rng.randf() * h * 0.85)
		var phase := rng.randf() * TAU
		var speed := rng.randf_range(1.2, 2.6)
		var a := maxf(0.0, sin(_t * speed + phase))
		if a < 0.05:
			continue
		var s := rng.randf_range(8, 18) * u * (0.6 + 0.4 * a)
		var col := Color(1, 1, 1, 0.75 * a)
		_twinkles.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.22, -s * 0.22), p + Vector2(s, 0), p + Vector2(s * 0.22, s * 0.22), p + Vector2(0, s), p + Vector2(-s * 0.22, s * 0.22), p + Vector2(-s, 0), p + Vector2(-s * 0.22, -s * 0.22)]), col)
