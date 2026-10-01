class_name StarChip
extends PanelContainer
## Star balance pill (stars are earned by winning levels and spent on
## renovation tasks). Counts up when stars arrive.

signal pressed

var _label: Label
var _icon: IconView
var _shown := 0
var _held := false


func _init() -> void:
	var sb := UIKit.chip_box(8)
	sb.content_margin_left = 6
	sb.content_margin_right = 22
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(210, 104)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = UIKit.icon("star", 88, UIKit.GOLD)
	_icon.shadow = true
	_icon.shadow_color = Color("9c4a00")
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	_label = UIKit.title("0", 50, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_label)
	if not _held:
		_shown = CurrencyManager.get_stars()
	_label.text = str(_shown)
	CurrencyManager.stars_changed.connect(_on_stars_changed)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed:
		pressed.emit()


## Shows a value without following the balance (count-up animations).
func display(value: int) -> void:
	_held = true
	_shown = value
	if _label:
		_label.text = str(value)


func release_display() -> void:
	_held = false
	display(CurrencyManager.get_stars())
	_held = false


func _on_stars_changed(total: int, _delta: int) -> void:
	if _held:
		return
	var from := _shown
	_shown = total
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _label.text = str(int(v)), float(from), float(total), 0.4)
	UIKit.bounce(self, 1.08)


func icon_global_center() -> Vector2:
	if _icon:
		return _icon.get_global_rect().get_center()
	return global_position + Vector2(50, size.y * 0.5)
