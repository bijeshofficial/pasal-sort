extends Node
## Screen shake, flashes, floating text, sparkles, confetti, flying coins and
## toasts. Everything spawned often is pooled through PoolManager.

const TEXT_POPUP := preload("res://scenes/components/text_popup.tscn")
const SPARKLE := preload("res://scenes/components/sparkle_burst.tscn")
const CONFETTI := preload("res://scenes/components/confetti_burst.tscn")
const COIN := preload("res://scenes/components/coin_visual.tscn")

var shake_count := 0
var flash_count := 0
var sparkle_count := 0
## "bottom" (above the booster bar) or "top" (below the hub's top bar).
var toast_anchor := "bottom"

var _camera: Camera2D
var _shake_time := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0
var _flash: ColorRect
var _flash_tween: Tween
var _fx_layer: CanvasLayer
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 40
	add_child(flash_layer)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	flash_layer.add_child(_flash)

	# Above modals: coins fly from the win panel to the coin counter.
	_fx_layer = CanvasLayer.new()
	_fx_layer.layer = 80
	add_child(_fx_layer)

	var toast_layer := CanvasLayer.new()
	toast_layer.layer = 90
	add_child(toast_layer)
	_toast = PanelContainer.new()
	var tb := UIKit.box(Color(0.1, 0.05, 0.3, 0.92), 50, Color.TRANSPARENT, 0, 28)
	tb.border_color = Color(1, 1, 1, 0.3)
	tb.set_border_width_all(4)
	_toast.add_theme_stylebox_override("panel", tb)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	toast_layer.add_child(_toast)
	_toast_label = UIKit.title("", 42)
	_toast.add_child(_toast_label)


func fx_layer() -> CanvasLayer:
	return _fx_layer


func register_camera(cam: Camera2D) -> void:
	_camera = cam


func shake(strength: float = 16.0, duration: float = 0.22) -> void:
	shake_count += 1
	if strength >= _shake_strength * (_shake_time / maxf(_shake_duration, 0.001)):
		_shake_strength = strength
		_shake_duration = duration
		_shake_time = duration


func _process(delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = null
		return
	if get_tree().paused:
		return
	if _shake_time > 0.0:
		_shake_time = maxf(0.0, _shake_time - delta)
		var k := _shake_time / _shake_duration
		_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength * k * k
	else:
		_camera.offset = Vector2.ZERO


func flash(color: Color = Color.WHITE, duration: float = 0.3, strength: float = 0.6) -> void:
	flash_count += 1
	if _flash_tween:
		_flash_tween.kill()
	_flash.color = Color(color.r, color.g, color.b, strength)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func popup_text(parent: Node, text: String, pos: Vector2, color: Color, size: int = 72, rise: float = 110.0, duration: float = 0.85) -> void:
	var p: TextPopup = PoolManager.acquire(TEXT_POPUP, parent)
	p.show_text(text, pos, color, size, rise, duration)


func sparkle(parent: Node, pos: Vector2, color: Color, amount_scale: float = 1.0) -> void:
	sparkle_count += 1
	var s: SparkleBurst = PoolManager.acquire(SPARKLE, parent)
	s.burst(pos, color, amount_scale)


## Paper confetti falling from the top of `parent`'s visible area.
func confetti(parent: Node, width: float, top: float = -40.0) -> void:
	for i in 3:
		var c: ConfettiBurst = PoolManager.acquire(CONFETTI, parent)
		c.burst(Vector2(width * (0.2 + 0.3 * i), top), width)


## Coins fly from `from` to `to` (global canvas positions on the FX layer).
## `on_each` is called as each coin lands.
func coin_fly(from: Vector2, to: Vector2, count: int = 8, on_each: Callable = Callable()) -> void:
	for i in count:
		var c: CoinVisual = PoolManager.acquire(COIN, _fx_layer)
		var start := from + Vector2(randf_range(-60, 60), randf_range(-40, 40))
		c.fly(start, to, i * 0.05, func() -> void:
			AudioManager.play("coin_pickup", 1.0 + 0.04 * i, -6.0)
			if on_each.is_valid():
				on_each.call())


func toast(text: String, duration: float = 1.8) -> void:
	_toast_label.text = text
	_toast.visible = true
	_toast.reset_size()
	var vp := get_viewport().get_visible_rect().size
	var insets := GameManager.get_safe_insets()
	var y := insets.x + 170.0 if toast_anchor == "top" else vp.y - insets.y - 480.0
	_toast.position = Vector2((vp.x - _toast.size.x) * 0.5, y)
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.25)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


func is_toast_visible() -> bool:
	return _toast.visible


func last_toast() -> String:
	return _toast_label.text
