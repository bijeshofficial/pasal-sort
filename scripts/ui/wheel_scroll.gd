class_name WheelScroll
extends ScrollContainer
## A ScrollContainer that scrolls however the player reaches it:
## - a finger or mouse drag that starts anywhere on it, cards and buttons
##   included. (A plain ScrollContainer only drags from its bare background:
##   a card or button takes the press, so the list never starts a drag.)
##   Once a drag passes a small deadzone, the press on whatever was under the
##   finger is cancelled so that button doesn't fire; a tap still works.
##   Letting go keeps a little momentum. Phones deliver touches as emulated
##   mouse events too, so one mouse-based path covers both.
## - the mouse wheel or trackpad, with the cursor anywhere over its items.
## Only the innermost WheelScroll under the pointer reacts, and nothing
## reacts under a covering popup.

const WHEEL_STEP := 110.0
const DRAG_DEADZONE := 22.0
const FRICTION := 5.0          # momentum decay per second
const MIN_SPEED := 30.0        # px/s below which momentum stops
const CANCEL_POS := Vector2(-100000, -100000)

var _press_pos := Vector2.INF  # where a press inside this list started
var _dragging := false
var _velocity := Vector2.ZERO
var _last_motion_ms := 0


func _ready() -> void:
	# Drags are handled here; the built-in background drag would double them.
	scroll_deadzone = 1000000
	set_process(false)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouse and (event as InputEventMouse).position == CANCEL_POS:
		return  # our own synthetic events (see _cancel_press): let the GUI have them
	# Touch events mirror the emulated mouse ones; swallow them mid-drag.
	if _dragging and (event is InputEventScreenDrag or event is InputEventScreenTouch):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_on_left_button(event)
		return
	if event is InputEventMouseMotion and _press_pos != Vector2.INF and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_on_drag(event)
		return
	var delta := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed:
		var f: float = event.factor if event.factor > 0.0 else 1.0
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				delta.y = -WHEEL_STEP * f
			MOUSE_BUTTON_WHEEL_DOWN:
				delta.y = WHEEL_STEP * f
			MOUSE_BUTTON_WHEEL_LEFT:
				delta.x = -WHEEL_STEP * f
			MOUSE_BUTTON_WHEEL_RIGHT:
				delta.x = WHEEL_STEP * f
	elif event is InputEventPanGesture:
		delta = event.delta * 18.0
	if delta == Vector2.ZERO or not _owns_point(event.position):
		return
	# Horizontal-only lists scroll sideways with a normal wheel.
	if vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and delta.x == 0.0:
		delta = Vector2(delta.y, 0)
	_stop_momentum()
	_scroll_by(delta)
	get_viewport().set_input_as_handled()


func _on_left_button(event: InputEventMouseButton) -> void:
	if event.pressed:
		_stop_momentum()
		_dragging = false
		_press_pos = event.position if _owns_point(event.position) else Vector2.INF
		return
	if _dragging:
		get_viewport().set_input_as_handled()
		if _velocity.length() > MIN_SPEED and Time.get_ticks_msec() - _last_motion_ms < 80:
			set_process(true)
	_press_pos = Vector2.INF
	_dragging = false


func _on_drag(event: InputEventMouseMotion) -> void:
	var vertical := vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
	var moved: Vector2 = event.position - _press_pos
	var along := absf(moved.y if vertical else moved.x)
	var across := absf(moved.x if vertical else moved.y)
	if not _dragging:
		if along < DRAG_DEADZONE or along < across:
			return
		_dragging = true
		_cancel_press()
	var step: Vector2 = -event.relative
	step = Vector2(0, step.y) if vertical else Vector2(step.x, 0)
	_scroll_by(step)
	var now := Time.get_ticks_msec()
	var dt := maxf(0.008, (now - _last_motion_ms) / 1000.0)
	_velocity = _velocity.lerp(step / dt, 0.5) if now - _last_motion_ms < 100 else step / dt
	_last_motion_ms = now
	get_viewport().set_input_as_handled()


## Moves the pointer off the button (or card) under the finger and releases
## it there, so it lets go without firing when the touch turns out to be a
## scroll. (The move matters: the button only sees the drag's motions we
## swallow, so it would still think the release happened on it.)
func _cancel_press() -> void:
	var away := InputEventMouseMotion.new()
	away.button_mask = MOUSE_BUTTON_MASK_LEFT
	away.position = CANCEL_POS
	away.global_position = CANCEL_POS
	get_viewport().push_input.call_deferred(away, true)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = CANCEL_POS
	up.global_position = CANCEL_POS
	get_viewport().push_input.call_deferred(up, true)


func _process(delta: float) -> void:
	_scroll_by(_velocity * delta)
	_velocity *= exp(-FRICTION * delta)
	if _velocity.length() < MIN_SPEED:
		_stop_momentum()


func _stop_momentum() -> void:
	_velocity = Vector2.ZERO
	set_process(false)


func _scroll_by(d: Vector2) -> void:
	scroll_vertical += int(round(d.y))
	scroll_horizontal += int(round(d.x))


## True when `p` is over this list, no popup covers the list, and no
## scroll list nested inside it is under `p` (that one scrolls instead).
func _owns_point(p: Vector2) -> bool:
	if not get_global_rect().has_point(p):
		return false
	var top := ScreenManager.top_modal()
	if top != null and not top.is_ancestor_of(self):
		return false
	for n in find_children("*", "ScrollContainer", true, false):
		var inner := n as ScrollContainer
		if inner.is_visible_in_tree() and inner.get_global_rect().has_point(p):
			return false
	return true
