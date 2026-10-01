class_name BoosterButton
extends Button
## Big glossy round booster button: coloured disk with a white icon, a label
## underneath and a count badge (green number, or an orange "+" at 0).

const COLORS := {
	"undo": [Color("2f9bff"), Color("1756c8")],
	"extra_jar": [Color("a35cff"), Color("6a2ad2")],
	"shuffle": [Color("ff7a3d"), Color("cc4a10")],
}

var booster_id := "undo"
var _icon: IconView
var _label: Label
var _badge: Label
var _pulse: Tween
var _free := false
var _press := 0.0


func setup(id: String) -> void:
	booster_id = id
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(230, 250)
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_icon = UIKit.icon({"undo": "undo", "extra_jar": "jar_plus", "shuffle": "shuffle"}[id], 92, Color.WHITE)
	_icon.accent = COLORS[id][0]
	_icon.shadow = true
	_icon.shadow_color = COLORS[id][1].darkened(0.4)
	add_child(_icon)
	_label = UIKit.title(BoosterManager.display_name(id), 36)
	add_child(_label)
	_badge = UIKit.title("0", 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, Color("1d4d08"))
	add_child(_badge)
	button_down.connect(func() -> void:
		_press = 1.0
		queue_redraw()
		create_tween().tween_property(self, "scale", Vector2(0.92, 0.92), 0.06))
	button_up.connect(func() -> void:
		_press = 0.0
		queue_redraw()
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.06, 1.06), 0.07)
		tw.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	pressed.connect(func() -> void:
		AudioManager.play("button_click")
		HapticsManager.light())
	resized.connect(_layout)
	BoosterManager.changed.connect(_on_booster_changed)
	refresh()


func _on_booster_changed(_id: String, _n: int) -> void:
	refresh()


func _layout() -> void:
	pivot_offset = size * 0.5
	var c := Vector2(size.x * 0.5, 98)
	_icon.position = c - Vector2(46, 50)
	_icon.size = Vector2(92, 92)
	_label.position = Vector2(-20, 192)
	_label.size = Vector2(size.x + 40, 50)
	_badge.position = c + Vector2(48, -92)
	_badge.size = Vector2(64, 64)
	queue_redraw()


func set_free(v: bool) -> void:
	_free = v
	refresh()


func refresh() -> void:
	var n := BoosterManager.count(booster_id)
	_badge.text = "free" if _free else (str(n) if n > 0 else "+")
	_badge.add_theme_font_size_override("font_size", 24 if _free else 38)
	var ol := Color("1d4d08") if (n > 0 or _free) else Color("8a3000")
	UIKit.game_text(_badge, ol, 36)
	queue_redraw()


func _draw() -> void:
	var c := Vector2(size.x * 0.5, 98)
	var cols: Array = COLORS[booster_id]
	DrawKit.glossy_circle(self, c + Vector2(0, _press * 5.0), 88, cols[0], cols[1], 6.0, 12.0 * (1.0 - _press))
	var n := BoosterManager.count(booster_id)
	var bc := c + Vector2(80, -60)
	if n > 0 or _free:
		DrawKit.glossy_circle(self, bc, 36, UIKit.PRIMARY, UIKit.PRIMARY_EDGE, 4.0, 5.0)
	else:
		DrawKit.glossy_circle(self, bc, 36, UIKit.GOLD, UIKit.GOLD_EDGE, 4.0, 5.0)


func start_pulse() -> void:
	stop_pulse()
	_pulse = UIKit.pulse(self, 1.12, 0.8)


func stop_pulse() -> void:
	if _pulse:
		_pulse.kill()
		_pulse = null
	scale = Vector2.ONE


func is_pulsing() -> bool:
	return _pulse != null
