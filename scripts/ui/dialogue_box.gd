class_name DialogueBox
extends Control
## Story dialogue: the speaker's portrait slides in, their name sits on a
## ribbon and the line types out in a speech bubble. Tap to finish the line,
## tap again for the next one. "Skip" ends the scene.

signal finished

const CharacterScene := preload("res://scenes/components/character_visual.tscn")
const TYPE_SPEED := 55.0   # characters per second

var story_id := ""
var lines: Array = []
var opts: Dictionary = {}
var index := -1
var portrait: CharacterVisual
var name_badge: PanelContainer
var name_label: Label
var text_label: Label
var bubble: PanelContainer

var _typing: Tween
var _done := false
var _side := -1.0


func setup(id: String, story_lines: Array, options: Dictionary = {}) -> void:
	story_id = id
	lines = story_lines
	opts = options


func _ready() -> void:
	set_meta("popup_id", "dialogue")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vp := get_viewport_rect().size
	var insets := GameManager.get_safe_insets()
	# Darker towards the bottom so the scene stays visible above.
	var shade := Control.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.draw.connect(func() -> void:
		var top := vp.y * 0.35
		shade.draw_rect(Rect2(0, 0, vp.x, top), Color(0.06, 0.03, 0.18, 0.25))
		DrawKit.gradient_fill(shade, PackedVector2Array([Vector2(0, top), Vector2(vp.x, top), Vector2(vp.x, vp.y), Vector2(0, vp.y)]), Color(0.06, 0.03, 0.18, 0.25), Color(0.06, 0.03, 0.18, 0.85)))
	add_child(shade)
	if opts.has("title"):
		var rib := UIKit.ribbon(String(opts["title"]), 860, UIKit.GOLD, UIKit.GOLD_EDGE, 56)
		rib.position = Vector2((vp.x - 860) * 0.5, insets.x + 180)
		add_child(rib)
		UIKit.pop_in(rib)
	var holder := Node2D.new()
	add_child(holder)
	portrait = CharacterScene.instantiate()
	portrait.unit = 1.25
	holder.add_child(portrait)
	bubble = PanelContainer.new()
	var sb := UIKit.card_box(Color.WHITE, 40, UIKit.PANEL_EDGE)
	sb.content_margin_top = 56
	bubble.add_theme_stylebox_override("panel", sb)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.position = Vector2(40, vp.y - insets.y - 520)
	bubble.size = Vector2(vp.x - 80, 400)
	bubble.custom_minimum_size = Vector2(vp.x - 80, 400)
	add_child(bubble)
	text_label = UIKit.label("", 50, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, false)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	text_label.custom_minimum_size = Vector2(vp.x - 160, 280)
	bubble.add_child(text_label)
	name_badge = UIKit.badge("", UIKit.PINK, 46)
	add_child(name_badge)
	name_label = name_badge.get_child(0)
	var hint := UIKit.title(tr("Tap to continue"), 34, Color(1, 1, 1, 0.8))
	hint.position = Vector2(0, vp.y - insets.y - 104)
	hint.size = Vector2(vp.x, 60)
	add_child(hint)
	UIKit.pulse(hint, 1.05, 1.4)
	var skip := UIKit.button(tr("Skip"), "neutral", "", 40, Vector2(220, 110))
	skip.position = Vector2(vp.x - 260, insets.x + 40)
	skip.pressed.connect(_finish)
	add_child(skip)
	next_line()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		advance()
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()


## Tap: finish typing, or go to the next line.
func advance() -> void:
	if _done:
		return
	if _typing and _typing.is_running():
		_typing.kill()
		text_label.visible_ratio = 1.0
		return
	next_line()


func next_line() -> void:
	index += 1
	if index >= lines.size():
		_finish()
		return
	var line: Dictionary = lines[index]
	var who := String(line.get("who", "maya"))
	var vp := get_viewport_rect().size
	var side := -1.0 if who == "maya" or who == "bhai" else 1.0
	var changed := portrait.id != who or index == 0
	portrait.id = who
	portrait.mood = String(line.get("mood", "neutral"))
	portrait.unit = 0.95 if CharacterArt.is_cat(who) else 1.2
	var target := Vector2(vp.x * 0.5 + side * vp.x * 0.22, bubble.position.y + 70)
	if changed:
		portrait.position = target + Vector2(side * 600, 0)
		var tw := portrait.create_tween()
		tw.tween_property(portrait, "position", target, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		portrait.position = target
		UIKit.bounce(portrait, 1.05)
	if portrait.mood in ["laugh", "happy"]:
		portrait.pose = "idle"
	_side = side
	name_label.text = tr(CharacterArt.display_name(who))
	name_badge.reset_size()
	name_badge.position = Vector2(110 if side < 0 else vp.x - 110 - name_badge.size.x, bubble.position.y - name_badge.size.y * 0.5)
	text_label.text = tr(String(line.get("text", "")))
	text_label.visible_ratio = 0.0
	if _typing:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_property(text_label, "visible_ratio", 1.0, maxf(0.2, text_label.text.length() / TYPE_SPEED))
	AudioManager.play("pop", 1.0 + randf_range(-0.05, 0.08), -8.0)


func _finish() -> void:
	if _done:
		return
	_done = true
	ScreenManager.close_modal(self)
	finished.emit()


func on_back() -> void:
	_finish()
