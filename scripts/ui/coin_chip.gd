class_name CoinChip
extends PanelContainer
## Coin balance pill with an optional "+" that jumps to the Shop.
## Counts up/down when the balance changes.

signal plus_pressed

var show_plus := true
var _label: Label
var _shown := 0
var _icon: IconView
var _held := false


func _init() -> void:
	var sb := UIKit.chip_box(8)
	sb.content_margin_left = 6
	sb.content_margin_right = 8
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(290, 104)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = UIKit.icon("coin", 92)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	_label = UIKit.title("0", 50, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_label)
	if show_plus:
		var plus := UIKit.button("", "primary", "plus", 30, Vector2(80, 80))
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.pressed.connect(func() -> void: plus_pressed.emit())
		row.add_child(plus)
	if not _held:
		_shown = CurrencyManager.get_coins()
	_label.text = str(_shown)
	CurrencyManager.coins_changed.connect(_on_coins_changed)


## Shows a value without following the balance (win screen count-up).
func display(value: int) -> void:
	_held = true
	_shown = value
	if _label:
		_label.text = str(value)


func _on_coins_changed(total: int, _delta: int) -> void:
	if _held:
		return
	var from := _shown
	_shown = total
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _label.text = str(int(v)), float(from), float(total), 0.5)
	UIKit.bounce(self, 1.06)


func icon_global_center() -> Vector2:
	if _icon:
		return _icon.get_global_rect().get_center()
	return global_position + Vector2(60, size.y * 0.5)
