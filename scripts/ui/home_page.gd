class_name HomePage
extends Control
## "Your pasal": logo, the shop counter illustration and a big PLAY button.

const PasalScene := preload("res://scenes/components/pasal_visual.tscn")

var play_button: GameButton
var pasal: PasalVisual
var _badge_holder: CenterContainer
var _next_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	v.add_child(_logo())
	pasal = PasalScene.instantiate()
	pasal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pasal.custom_minimum_size = Vector2(0, 700)
	v.add_child(pasal)
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bottom)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 120)
	pad.add_theme_constant_override("margin_top", 26)
	pad.add_theme_constant_override("margin_bottom", 20)
	bottom.add_child(pad)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	pad.add_child(stack)
	_badge_holder = CenterContainer.new()
	stack.add_child(_badge_holder)
	play_button = UIKit.button("Level 1", "primary", "play", 80, Vector2(0, 200))
	play_button.pressed.connect(_on_play)
	stack.add_child(play_button)
	UIKit.pulse(play_button, 1.04, 1.3)
	_next_label = UIKit.title("", 34)
	stack.add_child(_next_label)
	refresh()


func _logo() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 300)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void: GameLogo.draw(c, Vector2(c.size.x * 0.5, 18), 1.0))
	return c


func refresh() -> void:
	var level := ProgressionManager.current_level()
	play_button.set_label("Level %d" % level)
	for ch in _badge_holder.get_children():
		ch.queue_free()
	var badge := UIKit.tier_badge(ProgressionManager.tier_for(level), 34)
	if badge:
		_badge_holder.add_child(badge)
	else:
		_badge_holder.add_child(UIKit.spacer(50))
	var next := ProgressionManager.next_decoration()
	_next_label.text = "Next for your pasal: %s at level %d" % [String(next["name"]).to_lower(), int(next["level"])] if not next.is_empty() else "Your pasal is fully decorated!"
	pasal.theme_id = ProgressionManager.selected_cosmetic("theme")
	var shown: Array = (SaveManager.game()["pasal_decorations"] as Array).duplicate()
	for id in ProgressionManager.unrevealed_decorations():
		shown.erase(id)
	pasal.set_decorations(shown)


## New decorations pop in when the player returns Home.
func reveal_new_decorations() -> void:
	var fresh := ProgressionManager.unrevealed_decorations()
	if fresh.is_empty():
		return
	ProgressionManager.mark_decorations_revealed()
	var delay := 0.5
	for id in fresh:
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func() -> void:
			pasal.reveal(id)
			pasal.shopkeeper.wave()
			for d in GameData.decorations():
				if d["id"] == id:
					VFXManager.toast("New for your pasal: %s" % String(d["name"]).to_lower()))
		delay += 0.9


func _on_play() -> void:
	var level := ProgressionManager.current_level()
	if not LivesManager.can_play(level):
		Popups.lives(true)
		return
	ScreenManager.start_level()
