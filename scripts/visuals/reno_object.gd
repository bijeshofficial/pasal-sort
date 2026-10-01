class_name RenoObject
extends Node2D
## One renovatable object in an area scene. Draws itself with RenoArt in its
## broken state or one of its task's styles. A PNG at
## res://assets/art/areas/<area>/<object>_<variant>.png (variant = "broken"
## or the style id) replaces the drawing automatically.
## Origin = top-left of the object's rect; scaling pivots at the bottom centre.

## Kinds with small idle animations (redrawn every frame).
const ANIMATED := ["garland", "plant_pot", "string_lights", "ceiling_fan", "kite", "curtain", "wall_clock", "stove", "boat", "tree", "lantern", "bunting", "clothesline", "awning", "tea_stall", "flower_bed"]

var area_id := ""
var object_id := ""
var kind := ""
var size := Vector2(100, 100)
var style: Dictionary = {}
var style_id := ""
var broken := true
var night := false
## Draw order inside the area (children are added sorted by this; z_index
## stays 0 so the scene never sorts against the UI around it).
var layer := 0

var _t := 0.0
var _sprite: Sprite2D
var _body: Node2D


func setup(area_key: String, data: Dictionary) -> void:
	area_id = area_key
	object_id = String(data["id"])
	kind = String(data.get("kind", "box"))
	var r: Array = data.get("rect", [0, 0, 100, 100])
	size = Vector2(float(r[2]), float(r[3]))
	position = Vector2(float(r[0]), float(r[1]))
	layer = int(data.get("z", 0))
	# The body sits at the bottom centre so squash-and-stretch looks right.
	_body = Node2D.new()
	_body.position = Vector2(size.x * 0.5, size.y)
	add_child(_body)
	_body.draw.connect(_draw_body)
	set_process(kind in ANIMATED)


## style_value = the style dictionary, or {} with broken = true.
func set_look(style_value: Dictionary, is_broken: bool) -> void:
	style = style_value
	broken = is_broken
	style_id = "broken" if broken else String(style.get("id", "style"))
	_apply_texture()
	_body.queue_redraw()


func set_night(on: bool) -> void:
	if night != on:
		night = on
		_body.queue_redraw()


func body() -> Node2D:
	return _body


func center() -> Vector2:
	return position + size * 0.5


func rect() -> Rect2:
	return Rect2(position, size)


func _process(delta: float) -> void:
	_t += delta
	_body.queue_redraw()


func _apply_texture() -> void:
	var path := "res://assets/art/areas/%s/%s_%s.png" % [area_id, object_id, style_id]
	if ResourceLoader.exists(path):
		if _sprite == null:
			_sprite = Sprite2D.new()
			_sprite.centered = false
			_body.add_child(_sprite)
		_sprite.texture = load(path)
		_sprite.position = Vector2(-size.x * 0.5, -size.y)
		_sprite.scale = size / _sprite.texture.get_size()
		_sprite.visible = true
	elif _sprite:
		_sprite.visible = false


func _draw_body() -> void:
	if _sprite and _sprite.visible:
		return
	RenoArt.draw_object(_body, kind, size, style, broken, _t, night, Transform2D(0.0, Vector2(-size.x * 0.5, -size.y)))


## Squash-and-stretch pop when a new style appears.
func pop() -> void:
	_body.scale = Vector2(1.18, 0.7)
	var tw := create_tween()
	tw.tween_property(_body, "scale", Vector2(0.9, 1.14), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_body, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## A gentle highlight pulse (tutorial / "tap me").
func wiggle() -> void:
	var tw := create_tween()
	tw.tween_property(_body, "rotation", 0.03, 0.08)
	tw.tween_property(_body, "rotation", -0.03, 0.12)
	tw.tween_property(_body, "rotation", 0.0, 0.1)
