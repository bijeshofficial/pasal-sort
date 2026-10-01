class_name LivesChip
extends Button
## Heart with the number of lives and "Full" or the countdown to the next
## life. Tap to open the lives popup.

var _count: Label
var _timer: Label
var _heart: IconView


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(300, 104)
	add_theme_stylebox_override("normal", UIKit.chip_box(8))
	add_theme_stylebox_override("hover", UIKit.chip_box(8))
	var pressed_box := UIKit.chip_box(8)
	pressed_box.bg_color = Color(0.08, 0.04, 0.24, 0.8)
	add_theme_stylebox_override("pressed", pressed_box)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_right = -12
	add_child(row)
	var heart_box := Control.new()
	heart_box.custom_minimum_size = Vector2(96, 96)
	heart_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heart_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(heart_box)
	_heart = UIKit.icon("heart", 96, UIKit.HEART)
	_heart.shadow = true
	_heart.shadow_color = Color("8f0d2a")
	heart_box.add_child(_heart)
	_count = UIKit.title("5", 42, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, Color("8f0d2a"))
	_count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_count.offset_top = -4
	heart_box.add_child(_count)
	_timer = UIKit.title("Full", 42, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	_timer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_timer)
	pressed.connect(func() -> void:
		AudioManager.play("button_click")
		Popups.lives())
	LivesManager.lives_changed.connect(_on_lives_changed)
	_refresh()
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	add_child(t)
	t.timeout.connect(_refresh)


func _on_lives_changed(_n: int) -> void:
	_refresh()
	UIKit.bounce(_heart, 1.2)


func _refresh() -> void:
	_count.text = str(LivesManager.lives())
	_timer.text = LivesManager.countdown_text()
