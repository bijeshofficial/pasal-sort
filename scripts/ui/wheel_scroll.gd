class_name WheelScroll
extends ScrollContainer
## A ScrollContainer that also scrolls with the mouse wheel or trackpad when
## the cursor is over its items. Item cards and buttons stop wheel events
## before a plain ScrollContainer sees them. Only the innermost WheelScroll
## under the cursor reacts, and nothing reacts under a covering popup.

const WHEEL_STEP := 110.0


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
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
	scroll_vertical += int(delta.y)
	scroll_horizontal += int(delta.x)
	get_viewport().set_input_as_handled()


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
