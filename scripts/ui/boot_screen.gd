class_name BootScreen
extends Control
## Loading screen: the pasal's rolling shutter slides up to reveal the
## counter while a candy jar fills with candies as the real progress bar
## (threaded scene loads + save load). Stays at least 1.2 s so it never
## flashes, with a rotating tip.

const MIN_TIME := 1.2
const LOAD := ["res://scenes/main/hub.tscn", "res://scenes/gameplay/gameplay.tscn"]
const JarScene := preload("res://scenes/components/jar_visual.tscn")
const CandyScene := preload("res://scenes/components/candy_visual.tscn")
const FILL := [2, 2, 2, 2]
const PRELOAD_SCRIPTS := ["res://scripts/ui/hub.gd", "res://scripts/gameplay/gameplay.gd"]

var progress := 0.0
var _elapsed := 0.0
var _done := false
var _jar: JarVisual
var _shutter: ShutterView
var _bar: Control
var _tip: Label
var _tips: Array = []
var _tip_i := 0
var _candies := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bd := ShopBackdrop.new()
	bd.theme_id = "theme_asan"
	bd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bd)
	var vp := get_viewport_rect().size
	# A glowing glass shelf the jar stands on.
	var counter := Control.new()
	counter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.draw.connect(func() -> void:
		var y := vp.y * 0.66 + 4
		for k in 4:
			counter.draw_colored_polygon(DrawKit.ellipse(Vector2(vp.x * 0.5, y), 300.0 - k * 50.0, 60.0 - k * 10.0, 40), Color(1, 1, 1, 0.05))
		var plank := DrawKit.rounded_rect(Rect2(vp.x * 0.5 - 220, y, 440, 30), 15, 6)
		DrawKit.gradient_fill(counter, plank, Color(1, 1, 1, 0.6), Color(0.78, 0.72, 1.0, 0.3))
		DrawKit.outline(counter, plank, Color(1, 1, 1, 0.6), 3.0))
	add_child(counter)
	var logo := Control.new()
	logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.draw.connect(func() -> void: GameLogo.draw(logo, Vector2(vp.x * 0.5, vp.y * 0.12), 1.1))
	add_child(logo)
	var jar_layer := Node2D.new()
	add_child(jar_layer)
	_jar = JarScene.instantiate()
	jar_layer.add_child(_jar)
	_jar.setup(180, 4, GameData.cosmetic("jar_classic"))
	_jar.place(Vector2(vp.x * 0.5, vp.y * 0.66 + 4))
	_bar = Control.new()
	_bar.position = Vector2(vp.x * 0.5 - 330, vp.y * 0.66 + 110)
	_bar.size = Vector2(660, 52)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(func() -> void:
		var track := DrawKit.rounded_rect(Rect2(Vector2.ZERO, _bar.size), 24, 6)
		_bar.draw_colored_polygon(track, Color(0.07, 0.03, 0.22, 0.7))
		DrawKit.outline(_bar, track, Color(1, 1, 1, 0.3), 3.0)
		var fw := maxf(44.0, _bar.size.x * progress)
		var fill := Rect2(Vector2(6, 6), Vector2(fw - 12, _bar.size.y - 12))
		DrawKit.gradient_fill(_bar, DrawKit.rounded_rect(fill, 18, 6), Color("ffe680"), Color("ff9f1a"))
		DrawKit.rrect(_bar, Rect2(fill.position + Vector2(10, 4), Vector2(maxf(0.0, fill.size.x - 20), 8)), 4, Color(1, 1, 1, 0.55)))
	add_child(_bar)
	_tips = GameData.tips()
	_tip_i = randi() % _tips.size()
	_tip = UIKit.title(_tips[_tip_i], 40)
	_tip.position = Vector2(60, vp.y * 0.66 + 190)
	_tip.size = Vector2(vp.x - 120, 120)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_tip)
	_shutter = ShutterView.new()
	_shutter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shutter.cover = 1.0
	add_child(_shutter)
	var up := create_tween()
	up.tween_interval(0.15)
	up.tween_property(_shutter, "cover", 0.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# Compile the screens' scripts here first: compiling GDScript on the
	# loader thread leaks a couple of objects in Godot 4.7.
	for sp in PRELOAD_SCRIPTS:
		load(sp)
	for p in LOAD:
		ResourceLoader.load_threaded_request(p)
	var tips := Timer.new()
	tips.wait_time = 2.2
	tips.autostart = true
	add_child(tips)
	tips.timeout.connect(func() -> void:
		_tip_i = (_tip_i + 1) % _tips.size()
		_tip.text = _tips[_tip_i])


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	var real := 0.0
	for p in LOAD:
		var arr := []
		var st := ResourceLoader.load_threaded_get_status(p, arr)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			real += 1.0
		elif st == ResourceLoader.THREAD_LOAD_IN_PROGRESS and not arr.is_empty():
			real += float(arr[0])
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			real += 1.0
	# Save is loaded by the SaveManager autoload before this scene exists.
	real = (real + 1.0) / (LOAD.size() + 1.0)
	# Never faster than the minimum time, so the jar visibly fills.
	var shown := minf(real, _elapsed / MIN_TIME)
	progress = maxf(progress, shown)
	_bar.queue_redraw()
	while _candies < int(progress * FILL.size() + 0.001) and _candies < FILL.size():
		_drop_candy(_candies)
		_candies += 1
	if progress >= 1.0 and _elapsed >= MIN_TIME + 0.25:
		_done = true
		for p in LOAD:
			var res := ResourceLoader.load_threaded_get(p)
			if res is PackedScene:
				ScreenManager.preloaded[p] = res
		ScreenManager.go_hub("home")


func _drop_candy(i: int) -> void:
	var c: CandyVisual = CandyScene.instantiate()
	_jar.candies.add_child(c)
	c.setup(FILL[i], false, "classic", _jar.candy_diameter())
	var target := _jar.slot_position(i)
	c.position = target - Vector2(0, 700)
	var tw := c.create_tween()
	tw.tween_property(c, "position", target, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: AudioManager.play("clack", 1.0 + 0.1 * i))
	tw.tween_property(c, "scale", Vector2(1.15, 0.85), 0.06)
	tw.tween_property(c, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if i == FILL.size() - 1:
		tw.tween_callback(func() -> void: _jar.close_lid(GameData.candy_color(2)))
