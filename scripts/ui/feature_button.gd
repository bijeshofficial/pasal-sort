class_name FeatureButton
extends Button
## Round glossy icon button for the Home side columns (daily reward, events,
## album...). Red dot when something is waiting, optional timer underneath.

var id := ""
var icon_name := ""
var color := UIKit.SECONDARY
var _dot: Control
var _label: Label
var _timer: Label
var _icon: IconView


func setup(feature_id: String, icon: String, text: String, fill: Color) -> void:
	id = feature_id
	icon_name = icon
	color = fill
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(140, 172)
	for st in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_icon = UIKit.icon(icon, 74, Color.WHITE)
	_icon.shadow = true
	_icon.position = Vector2(33, 26)
	_icon.size = Vector2(74, 74)
	add_child(_icon)
	_label = UIKit.title(text, 30)
	_label.position = Vector2(-20, 116)
	_label.size = Vector2(180, 40)
	add_child(_label)
	_timer = UIKit.title("", 26, Color("ffe680"))
	_timer.position = Vector2(-20, 146)
	_timer.size = Vector2(180, 30)
	_timer.visible = false
	add_child(_timer)
	_dot = UIKit.red_dot(38)
	_dot.position = Vector2(100, 4)
	_dot.visible = false
	add_child(_dot)
	pressed.connect(func() -> void:
		AudioManager.play("button_click")
		HapticsManager.light()
		UIKit.bounce(self, 1.1))
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func _draw() -> void:
	DrawKit.glossy_circle(self, Vector2(70, 62), 58, color, color.darkened(0.35), 6.0, 9.0)


func set_icon(icon: String) -> void:
	icon_name = icon
	_icon.icon = icon


func set_dot(on: bool) -> void:
	_dot.visible = on


func has_dot() -> bool:
	return _dot.visible


func set_timer(text: String) -> void:
	_timer.text = text
	_timer.visible = text != ""
