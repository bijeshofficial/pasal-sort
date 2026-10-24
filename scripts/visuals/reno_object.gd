class_name RenoObject
extends Node2D
## One renovatable object in an area scene. Draws itself with RenoArt in its
## broken state or one of its task's styles. A PNG at
## res://assets/art/areas/<area>/<object>_<variant>.png/.webp (variant =
## "broken" or the style id; see Art) replaces the drawing automatically.
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
## Shop name painted over sign art (the art plates are blank).
var _sign_text: Node2D


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
	var t := Art.tex("areas/%s/%s_%s" % [area_id, object_id, style_id])
	if t:
		if _sprite == null:
			_sprite = Sprite2D.new()
			_sprite.centered = false
			_body.add_child(_sprite)
		_sprite.texture = t
		_sprite.position = Vector2(-size.x * 0.5, -size.y)
		_sprite.scale = size / _sprite.texture.get_size()
		_sprite.visible = true
		if kind in ["wall_sign", "sign_board"]:
			if _sign_text == null:
				_sign_text = Node2D.new()
				_body.add_child(_sign_text)
				_sign_text.draw.connect(_draw_sign_text)
			_sign_text.visible = true
			_sign_text.queue_redraw()
	elif _sprite:
		_sprite.visible = false
		if _sign_text:
			_sign_text.visible = false


func _draw_sign_text() -> void:
	var text := "HAJURAMA'S PASAL" if not broken else "H J R M   P S L"
	var f := UIKit.font(true)
	var fs := int(size.y * 0.4)
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while tw > size.x * 0.74 and fs > 12:
		fs -= 2
		tw = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(-tw * 0.5, -size.y * 0.5 + fs * 0.36)
	var fill := Color("ffe9a8") if not broken else Color(0.9, 0.84, 0.72, 0.55)
	var ink := Color("3a1d0e") if not broken else Color(0.2, 0.12, 0.08, 0.4)
	_sign_text.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, fs / 6), ink)
	_sign_text.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fill)


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
