class_name HomeView
extends Control
## The renovation scene on Home: drag to pan, pinch (or mouse wheel) to zoom,
## tap an object to change its style. The scene always covers the view.

signal object_tapped(object_id: String)
signal empty_tapped

const MAX_ZOOM_FACTOR := 1.9
const TAP_SLOP := 24.0

var scene: AreaScene
var zoom := 1.0
var min_zoom := 1.0
var max_zoom := 2.0
## Extra space kept free at the top/bottom (top bar, buttons) when focusing.
var safe_top := 0.0
var safe_bottom := 0.0
var interactive := true

var _touches: Dictionary = {}    # index -> position
var _press_pos := Vector2.ZERO
var _press_time := 0
var _moved := false
var _pinch_dist := 0.0
var _pinch_zoom := 1.0
var _pinch_mid := Vector2.ZERO
var _focus_tween: Tween
var _velocity := Vector2.ZERO
var _last_drag_time := 0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	scene = AreaScene.new()
	add_child(scene)
	resized.connect(_fit)


func show_area(index: int, mode: String = "live") -> void:
	scene.build(index, mode)
	_fit()
	center_on(scene.focus_point())


## The free area is the part of the screen between the top bar/title and
## the bottom buttons. Fully zoomed out, the world's height fills it (the
## backdrop extends past the world edges behind the bars).
func free_height() -> float:
	return maxf(200.0, size.y - safe_top - safe_bottom)


func _fit() -> void:
	if scene == null or size.x <= 0.0:
		return
	min_zoom = maxf(size.x / scene.world_size.x, free_height() / scene.world_size.y)
	max_zoom = min_zoom * MAX_ZOOM_FACTOR
	zoom = clampf(zoom, min_zoom, max_zoom)
	_apply()


func _apply() -> void:
	scene.scale = Vector2(zoom, zoom)
	var ws := scene.world_size * zoom
	scene.position.x = clampf(scene.position.x, minf(0.0, size.x - ws.x), maxf(0.0, size.x - ws.x))
	# Vertically the world may not leave the free area's edges.
	var a := size.y - safe_bottom - ws.y
	var b := safe_top
	scene.position.y = clampf(scene.position.y, minf(a, b), maxf(a, b))


func world_to_local(p: Vector2) -> Vector2:
	return scene.position + p * zoom


func local_to_world(p: Vector2) -> Vector2:
	return (p - scene.position) / zoom


func world_to_global(p: Vector2) -> Vector2:
	return get_global_transform() * world_to_local(p)


func center_on(world_pt: Vector2, z: float = -1.0) -> void:
	zoom = clampf(z if z > 0.0 else zoom, min_zoom, max_zoom)
	var mid_y := safe_top + (size.y - safe_top - safe_bottom) * 0.5
	scene.position = Vector2(size.x * 0.5, mid_y) - world_pt * zoom
	_apply()


## Smoothly pans/zooms so `world_pt` sits in the middle of the free area.
func focus_on(world_pt: Vector2, z: float = -1.0, duration: float = 0.45) -> void:
	if _focus_tween:
		_focus_tween.kill()
	var from_pos := scene.position
	var from_zoom := zoom
	center_on(world_pt, z)
	var to_pos := scene.position
	var to_zoom := zoom
	scene.position = from_pos
	zoom = from_zoom
	_apply()
	_focus_tween = create_tween()
	_focus_tween.tween_method(func(k: float) -> void:
		zoom = lerpf(from_zoom, to_zoom, k)
		scene.position = from_pos.lerp(to_pos, k)
		_apply(), 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


## Zoom that frames a world rect inside the free area.
func zoom_for(rect: Rect2) -> float:
	var free := Vector2(size.x, size.y - safe_top - safe_bottom)
	var z := minf(free.x / maxf(1.0, rect.size.x * 1.5), free.y / maxf(1.0, rect.size.y * 1.6))
	return clampf(z, min_zoom, max_zoom * 0.85)


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_press_pos = event.position
				_press_time = Time.get_ticks_msec()
				_moved = false
				_velocity = Vector2.ZERO
				if _focus_tween:
					_focus_tween.kill()
			elif _touches.size() == 2:
				_start_pinch()
		else:
			_touches.erase(event.index)
			if _touches.is_empty():
				if not _moved and Time.get_ticks_msec() - _press_time < 500:
					_tap(event.position)
			elif _touches.size() == 1:
				_moved = true
		accept_event()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			_update_pinch()
		else:
			if event.position.distance_to(_press_pos) > TAP_SLOP:
				_moved = true
			if _moved:
				scene.position += event.relative
				_apply()
				var now := Time.get_ticks_msec()
				var dt := maxf(1.0, float(now - _last_drag_time)) / 1000.0
				_velocity = _velocity.lerp(event.relative / dt, 0.4)
				_last_drag_time = now
		accept_event()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(event.position, zoom * 1.1)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(event.position, zoom / 1.1)
			accept_event()


func _process(delta: float) -> void:
	# A little inertia after a fling.
	if _touches.is_empty() and _velocity.length() > 20.0:
		scene.position += _velocity * delta
		_velocity = _velocity.lerp(Vector2.ZERO, clampf(delta * 6.0, 0.0, 1.0))
		_apply()


func zoom_at(local_pt: Vector2, new_zoom: float) -> void:
	var world_pt := local_to_world(local_pt)
	zoom = clampf(new_zoom, min_zoom, max_zoom)
	scene.position = local_pt - world_pt * zoom
	_apply()


func _start_pinch() -> void:
	var pts: Array = _touches.values()
	_pinch_dist = maxf(1.0, (pts[0] as Vector2).distance_to(pts[1]))
	_pinch_zoom = zoom
	_pinch_mid = ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
	_moved = true


func _update_pinch() -> void:
	var pts: Array = _touches.values()
	var d := maxf(1.0, (pts[0] as Vector2).distance_to(pts[1]))
	var mid := ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
	scene.position += mid - _pinch_mid
	_pinch_mid = mid
	zoom_at(mid, _pinch_zoom * d / _pinch_dist)


func _tap(local_pt: Vector2) -> void:
	var id := scene.task_object_at(local_to_world(local_pt))
	if id != "":
		object_tapped.emit(id)
	else:
		empty_tapped.emit()
