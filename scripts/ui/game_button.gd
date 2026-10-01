class_name GameButton
extends Button
## Chunky glossy game button: gradient body, dark outline, a 3D lip that the
## body sinks into when pressed, a gloss highlight and outlined white text.
## Press feedback: squash bounce, click sound and a light haptic.

var kind := "primary"
var _label: Label
var _icon: IconView
var _row: HBoxContainer
var _press := 0.0
var _font_size := 52
## Optional: stay pinned to this control's top-right corner (+ offset).
var follow: Control
var follow_offset := Vector2.ZERO


func setup(text_value: String, kind_value: String = "primary", icon_name: String = "", font_size: int = 52, min_size: Vector2 = Vector2(0, 150)) -> void:
	kind = kind_value
	_font_size = font_size
	text = ""
	custom_minimum_size = min_size
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_row = HBoxContainer.new()
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 14)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	if icon_name != "":
		_icon = UIKit.icon(icon_name, font_size * 1.15, Color.WHITE)
		_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_row.add_child(_icon)
	_label = UIKit.label(text_value, font_size, Color.WHITE)
	_label.visible = text_value != ""
	_row.add_child(_label)
	_apply_colors()
	_layout_row()
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	pressed.connect(_on_pressed)
	resized.connect(func() -> void:
		pivot_offset = size * 0.5
		_layout_row()
		queue_redraw())


func set_label(value: String) -> void:
	if _label:
		_label.text = value
		_label.visible = value != ""


func get_label() -> String:
	return _label.text if _label else ""


func set_kind(kind_value: String) -> void:
	kind = kind_value
	_apply_colors()
	queue_redraw()


func _colors() -> Array:
	if disabled:
		return [UIKit.DISABLED, UIKit.DISABLED_EDGE, Color.WHITE, Color("6d6888")]
	return UIKit.BUTTON_KINDS.get(kind, UIKit.BUTTON_KINDS["primary"])


func _apply_colors() -> void:
	var c := _colors()
	var fg: Color = c[2]
	var ol: Color = c[3]
	if _label:
		_label.add_theme_color_override("font_color", fg)
		if ol.a > 0.0:
			UIKit.game_text(_label, ol, _font_size)
		else:
			_label.add_theme_constant_override("outline_size", 0)
			_label.add_theme_constant_override("shadow_outline_size", 0)
			_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	if _icon:
		_icon.color = fg
		_icon.accent = c[0]
		_icon.shadow = ol.a > 0.0
		_icon.shadow_color = ol


func _lip() -> float:
	return clampf(size.y * 0.09, 6.0, 14.0)


## Keeps the text centred on the body (above the lip) and sinks it on press.
func _layout_row() -> void:
	if _row == null:
		return
	var lip := _lip()
	_row.offset_top = lip * _press
	_row.offset_bottom = -lip + lip * _press - 2


func _draw() -> void:
	var c := _colors()
	var r := minf(size.y * 0.42, 64.0)
	DrawKit.glossy_rrect(self, Rect2(Vector2.ZERO, size), r, c[0], c[1], _press, clampf(size.y * 0.04, 4.0, 6.0), _lip(), true)


func _process(_delta: float) -> void:
	if follow != null:
		if is_instance_valid(follow):
			var r := follow.get_global_rect()
			global_position = Vector2(r.end.x, r.position.y) + follow_offset
		else:
			follow = null
	# Disabled state can change from outside: keep colours in sync.
	var want := 1 if disabled else 0
	if want != int(get_meta("_dis", -1)):
		set_meta("_dis", want)
		_apply_colors()
		queue_redraw()


func _set_press(v: float) -> void:
	_press = v
	_layout_row()
	queue_redraw()


func _on_down() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_method(_set_press, _press, 1.0, 0.05)
	tw.tween_property(self, "scale", Vector2(1.04, 0.94), 0.06)


func _on_up() -> void:
	var tw := create_tween()
	tw.tween_method(_set_press, _press, 0.0, 0.08)
	tw.parallel().tween_property(self, "scale", Vector2(0.97, 1.05), 0.07)
	tw.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_pressed() -> void:
	AudioManager.play("button_click")
	HapticsManager.light()
