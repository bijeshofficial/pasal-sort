class_name CandyVisual
extends Node2D
## One candy. Placeholder art drawn by CandyArt; swap this scene's script or
## add a Sprite2D to replace it without touching gameplay code.

var type := 0
var hidden_wrapper := false
var style := "classic"
var diameter := 120.0
var selected := false:
	set(v):
		if selected != v:
			selected = v
			queue_redraw()

var tween: Tween


func setup(type_value: int, hidden_value: bool, style_value: String, d: float) -> void:
	type = type_value
	hidden_wrapper = hidden_value
	style = style_value
	diameter = d
	selected = false
	scale = Vector2.ONE
	rotation = 0.0
	modulate = Color.WHITE
	queue_redraw()


func set_hidden(v: bool) -> void:
	if hidden_wrapper != v:
		hidden_wrapper = v
		queue_redraw()


## The paper wrapper opens: a quick squash and the real candy appears.
func reveal() -> void:
	if not hidden_wrapper:
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.25, 0.7), 0.08)
	tw.tween_callback(func() -> void:
		hidden_wrapper = false
		queue_redraw())
	tw.tween_property(self, "scale", Vector2(0.9, 1.12), 0.08)
	tw.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	CandyArt.draw_candy(self, Vector2.ZERO, diameter, type, style, hidden_wrapper, selected)
