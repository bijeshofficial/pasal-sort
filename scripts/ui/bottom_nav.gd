class_name BottomNav
extends PanelContainer
## Shop | Home | Profile. The selected tab's icon is bigger and raised.
## Red dots mark free shop gifts and claimable achievements.

signal tab_selected(index: int)

const TABS := [["shop", "Shop"], ["home", "Home"], ["profile", "Profile"]]

var current := 1
var _buttons: Array[Button] = []
var _icons: Array[IconView] = []
var _labels: Array[Label] = []
var _dots: Array[Control] = []
var _bgs: Array[Control] = []


func _ready() -> void:
	var bottom := UIKit.safe_bottom()
	var sb := UIKit.box(Color(0.07, 0.03, 0.22, 0.88), 0, Color.TRANSPARENT, 0, 0)
	sb.corner_radius_top_left = 54
	sb.corner_radius_top_right = 54
	sb.border_color = Color(1, 1, 1, 0.22)
	sb.border_width_top = 5
	sb.content_margin_bottom = bottom + 14
	sb.content_margin_top = 18
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	for i in TABS.size():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 170)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		row.add_child(b)
		var bg := Control.new()
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.draw.connect(func() -> void: DrawKit.glossy_rrect(bg, Rect2(Vector2.ZERO, bg.size), 44, UIKit.PURPLE, UIKit.PURPLE_EDGE, 0.0, 5.0, 12.0, true))
		b.add_child(bg)
		var ic := UIKit.icon(TABS[i][0], 84, Color.WHITE)
		ic.shadow = true
		b.add_child(ic)
		var l := UIKit.title(TABS[i][1], 36)
		b.add_child(l)
		var dot := UIKit.red_dot(36)
		dot.visible = false
		b.add_child(dot)
		b.pressed.connect(func() -> void:
			AudioManager.play("button_click")
			HapticsManager.light()
			tab_selected.emit(i))
		b.resized.connect(_layout.bind(i))
		_buttons.append(b)
		_icons.append(ic)
		_labels.append(l)
		_dots.append(dot)
		_bgs.append(bg)
	select(current, false)


func set_dot(index: int, on: bool) -> void:
	_dots[index].visible = on


func has_dot(index: int) -> bool:
	return _dots[index].visible


func select(index: int, animate: bool = true) -> void:
	current = index
	for i in _buttons.size():
		var on := i == index
		_bgs[i].visible = on
		_icons[i].accent = UIKit.PURPLE if on else Color(0.12, 0.06, 0.3)
		_icons[i].modulate.a = 1.0 if on else 0.7
		_labels[i].modulate.a = 1.0 if on else 0.7
		_layout(i, animate)


func _layout(i: int, animate: bool = false) -> void:
	var b := _buttons[i]
	var on := i == current
	var s := 118.0 if on else 84.0
	var lift := -34.0 if on else 0.0
	var ic := _icons[i]
	var target := Vector2((b.size.x - s) * 0.5, 14 + lift)
	_bgs[i].offset_top = lift
	if animate:
		var tw := ic.create_tween().set_parallel(true)
		tw.tween_property(ic, "size", Vector2(s, s), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(ic, "position", target, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		ic.size = Vector2(s, s)
		ic.position = target
	var l := _labels[i]
	l.size = Vector2(b.size.x, 44)
	l.position = Vector2(0, b.size.y - 50)
	_dots[i].position = Vector2(b.size.x * 0.5 + 34, 4 + lift)
