extends Control
## Tutorial pointer: a bobbing hand over a control plus one short line of
## text. Lives on its own CanvasLayer so it shows above popups.

var hand: IconView
var panel: PanelContainer
var label: Label
var target: Control

var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = PanelContainer.new()
	var sb := UIKit.card_box(Color.WHITE, 26, UIKit.PURPLE)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	label = UIKit.label("", 46, UIKit.INK)
	panel.add_child(label)
	hand = UIKit.icon("hand", 150, Color.WHITE)
	hand.shadow = true
	hand.size = Vector2(150, 150)
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hand)


func point_at(c: Control, text: String) -> void:
	target = c
	label.text = text
	panel.reset_size()
	_place.call_deferred()


func _place() -> void:
	if target == null or not is_instance_valid(target):
		return
	var r := target.get_global_rect()
	var vp := get_viewport_rect().size
	var p := r.get_center() + Vector2(-10, -20)
	if _tween:
		_tween.kill()
	hand.position = p
	_tween = hand.create_tween().set_loops()
	_tween.tween_property(hand, "position", p + Vector2(0, 40), 0.35).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(hand, "position", p, 0.35).set_trans(Tween.TRANS_SINE)
	var py := r.position.y - panel.size.y - 50 if r.position.y > vp.y * 0.4 else r.end.y + 180
	panel.position = Vector2(clampf(r.get_center().x - panel.size.x * 0.5, 30, vp.x - panel.size.x - 30), py)


func _process(_delta: float) -> void:
	# Follow the target if it moves (sheets sliding in).
	if target and is_instance_valid(target) and Engine.get_process_frames() % 10 == 0:
		var r := target.get_global_rect()
		if r.get_center().distance_to(hand.position + Vector2(10, 20)) > 80:
			_place()
