class_name BeforeAfter
extends Control
## Full-screen before/after reveal of a finished area: the shabby "before"
## on the left of a draggable divider, the restored "after" on the right.
## The divider sweeps across once by itself, then follows the finger.

signal closed

var area_index := 1
var divider := 0.0          # 0..1 across the frame
var continue_button: GameButton

var _frame: Control
var _after_clip: Control
var _before_clip: Control
var _after_scene: AreaScene
var _before_scene: AreaScene
var _handle: Control
var _dragging := false


func setup(index: int) -> void:
	area_index = index


func _ready() -> void:
	set_meta("popup_id", "before_after")
	var vp := get_viewport_rect().size
	var v := UIKit.modal_frame(self, vp.x - 60, tr("Area complete!"))
	var sub := UIKit.label(tr(RenovationManager.area_name(area_index)), 44, UIKit.INK_SOFT)
	v.add_child(sub)
	_frame = Control.new()
	_frame.custom_minimum_size = Vector2(vp.x - 160, minf(vp.y * 0.5, 1000))
	_frame.clip_contents = true
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.gui_input.connect(_on_frame_input)
	v.add_child(_frame)
	_after_clip = Control.new()
	_after_clip.clip_contents = true
	_after_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_after_clip)
	_after_scene = AreaScene.new()
	_after_clip.add_child(_after_scene)
	_after_scene.build(area_index, "after")
	_before_clip = Control.new()
	_before_clip.clip_contents = true
	_before_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_before_clip)
	_before_scene = AreaScene.new()
	_before_clip.add_child(_before_scene)
	_before_scene.build(area_index, "before")
	_handle = Control.new()
	_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_handle.draw.connect(_draw_handle)
	_frame.add_child(_handle)
	var labels := HBoxContainer.new()
	var lb := UIKit.badge(tr("BEFORE"), Color("8f8274"), 34)
	labels.add_child(lb)
	labels.add_child(UIKit.hspacer())
	labels.add_child(UIKit.badge(tr("AFTER"), UIKit.PRIMARY, 34))
	v.add_child(labels)
	continue_button = UIKit.button(tr("Continue"), "primary", "play", 60, Vector2(0, 170))
	continue_button.pressed.connect(close)
	v.add_child(continue_button)
	_frame.resized.connect(_layout)
	_layout.call_deferred()
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_method(set_divider, 1.0, 0.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(set_divider, 0.0, 0.5, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _layout() -> void:
	var fs := _frame.size
	if fs.x <= 0:
		return
	for sc in [_after_scene, _before_scene]:
		var k := maxf(fs.x / sc.world_size.x, fs.y / sc.world_size.y)
		sc.scale = Vector2(k, k)
		sc.position = (fs - sc.world_size * k) * 0.5
	_after_clip.size = fs
	_handle.size = fs
	set_divider(divider)


func set_divider(v: float) -> void:
	divider = clampf(v, 0.0, 1.0)
	_before_clip.size = Vector2(_frame.size.x * divider, _frame.size.y)
	_handle.queue_redraw()


func _draw_handle() -> void:
	var x := _frame.size.x * divider
	_handle.draw_line(Vector2(x, 0), Vector2(x, _frame.size.y), Color.WHITE, 8.0)
	DrawKit.glossy_circle(_handle, Vector2(x, _frame.size.y * 0.5), 46, UIKit.GOLD, UIKit.GOLD_EDGE, 5.0, 6.0)
	for s in [-1.0, 1.0]:
		var c := Vector2(x + s * 16, _frame.size.y * 0.5 - 3)
		_handle.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 10, 0), c + Vector2(-s * 4, -12), c + Vector2(-s * 4, 12)]), Color.WHITE)


func _on_frame_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_dragging = event.pressed
		if event.pressed:
			set_divider(event.position.x / _frame.size.x)
	elif event is InputEventScreenDrag and _dragging:
		set_divider(event.position.x / _frame.size.x)


func close() -> void:
	ScreenManager.close_modal(self)
	closed.emit()


func on_back() -> void:
	close()
