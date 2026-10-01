class_name LevelStartCard
extends Control
## "Level N" card before a level: difficulty badge, goal, the Dami streak
## meter and up to 2 pre-level boosters (Open Jar, Peek, Lucky Start).
## Boosters are only used up when the level actually starts.

signal play_pressed

var level := 1
var selected: Array = []
var free: Array = []
var slots: Dictionary = {}     # id -> Button
var play_button: GameButton

var _streak: Control
var _t := 0.0


static func open(level_number: int) -> LevelStartCard:
	var c := LevelStartCard.new()
	c.level = level_number
	ScreenManager.push_modal(c)
	return c


func _ready() -> void:
	set_meta("popup_id", "level_start")
	free = StreakManager.free_boosters()
	var v := UIKit.modal_frame(self, 920, tr("Level %d") % level)
	UIKit.attach_close(self, on_back)
	var tier := ProgressionManager.tier_for(level)
	var badge := UIKit.tier_badge(tier, 38)
	if badge:
		var c := CenterContainer.new()
		c.add_child(badge)
		v.add_child(c)
	v.add_child(_goal_row())
	if BoosterManager.pre_unlocked(level):
		# First time: one of each pre-level booster on the house.
		var granted := 0
		for id in BoosterManager.PRE_IDS:
			granted += BoosterManager.grant_tutorial(id)
		v.add_child(_streak_meter())
		var hint := UIKit.label(tr("Pick up to %d boosters") % int(GameData.economy().get("pre_boosters_max", 2)), 34, UIKit.INK_SOFT)
		v.add_child(hint)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 26)
		v.add_child(row)
		for id in BoosterManager.PRE_IDS:
			row.add_child(_slot(id))
		if granted > 0:
			VFXManager.toast(tr("New! Free boosters to try before you play"))
	play_button = UIKit.button(tr("PLAY"), "primary", "play", 72, Vector2(0, 190))
	play_button.pressed.connect(_on_play)
	v.add_child(play_button)
	UIKit.pulse.call_deferred(play_button, 1.04, 1.2)


func _goal_row() -> Control:
	var goal := ProgressionManager.goal_for(level)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	var icon := "jar"
	var text := tr("Sort every jar")
	var col := UIKit.SECONDARY
	match String(goal.get("type", "sort")):
		"moves":
			icon = "moves"
			text = tr("Finish in %d moves") % int(goal["moves"])
			col = UIKit.DANGER
		"orders":
			icon = "order"
			text = tr("Sort every jar. Fill customer orders for bonus coins!")
			col = UIKit.PURPLE
	row.add_child(UIKit.disk(icon, 120, col, col.darkened(0.35)))
	var l := UIKit.label(text, 42, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	row.add_child(l)
	return row


## Three marigold flames: lit by the Dami streak, flickering.
func _streak_meter() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_streak = Control.new()
	_streak.custom_minimum_size = Vector2(0, 120)
	_streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_streak.draw.connect(_draw_streak)
	box.add_child(_streak)
	var n := StreakManager.dami()
	var text := tr("Dami streak: win without failing for free boosters!")
	if n > 0:
		var names: PackedStringArray = []
		for id in free:
			names.append(BoosterManager.display_name(id))
		text = tr("Dami streak %d! Free: %s") % [n, ", ".join(names)]
	var l := UIKit.label(text, 32, UIKit.INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	return box


func _process(delta: float) -> void:
	_t += delta
	if _streak:
		_streak.queue_redraw()


func _draw_streak() -> void:
	var n := mini(StreakManager.dami(), 3)
	var w := _streak.size.x
	for k in 3:
		var c := Vector2(w * 0.5 + (k - 1) * 150, 70)
		var lit := k < n
		var flick := 1.0 + (0.08 * sin(_t * 9.0 + k * 2.0) if lit else 0.0)
		var flame := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			var r := 34.0 * flick
			var y := sin(a) * r
			if y < 0:
				y *= 1.0 + 0.8 * absf(cos(a * 0.5))
			flame.append(c + Vector2(cos(a) * r * 0.85, y))
		var outer := Color("ff7a1a") if lit else Color(UIKit.INK, 0.15)
		var inner := Color("ffd23f") if lit else Color(UIKit.INK, 0.08)
		_streak.draw_colored_polygon(flame, outer)
		_streak.draw_colored_polygon(DrawKit.ellipse(c + Vector2(0, 6), 16, 20, 14), inner)
		if lit:
			# Marigold petals around the flame.
			for i in 8:
				var a := TAU * i / 8.0 + _t * 0.8
				_streak.draw_circle(c + Vector2(cos(a), sin(a)) * 50, 9, Color("ff9f1c"), true, -1.0, true)


func _slot(id: String) -> Control:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(220, 250)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.draw.connect(func() -> void:
		var on := selected.has(id) or free.has(id)
		var r := Rect2(Vector2(10, 10), Vector2(200, 200))
		DrawKit.glossy_rrect(b, r, 40, UIKit.PRIMARY if on else UIKit.SECONDARY, UIKit.PRIMARY_EDGE if on else UIKit.SECONDARY_EDGE, 0.0, 6.0, 12.0, true))
	var ic := UIKit.icon(BoosterManager.icon_for(id), 110, Color.WHITE)
	ic.shadow = true
	ic.position = Vector2(55, 40)
	ic.size = Vector2(110, 110)
	b.add_child(ic)
	var name_l := UIKit.label(BoosterManager.display_name(id), 28, UIKit.INK)
	name_l.position = Vector2(0, 214)
	name_l.size = Vector2(220, 36)
	b.add_child(name_l)
	var tag := UIKit.badge("", UIKit.HEART, 30)
	tag.position = Vector2(150, -6)
	b.add_child(tag)
	b.set_meta("tag", tag)
	b.pressed.connect(func() -> void: toggle(id))
	slots[id] = b
	_refresh_slot(id)
	return b


func _refresh_slot(id: String) -> void:
	var b: Button = slots[id]
	var tag: PanelContainer = b.get_meta("tag")
	var l: Label = tag.get_child(0)
	if free.has(id):
		l.text = tr("FREE")
	elif selected.has(id):
		l.text = tr("ON")
	else:
		var n := BoosterManager.count(id)
		l.text = str(n) if n > 0 else "+"
	b.queue_redraw()


## Select/deselect a booster (max 2). With none in stock, offer to buy one.
func toggle(id: String) -> void:
	if free.has(id):
		VFXManager.toast(tr("Free from your Dami streak!"))
		return
	AudioManager.play("button_click")
	if selected.has(id):
		selected.erase(id)
	elif BoosterManager.count(id) <= 0:
		Popups.buy_booster(id, func() -> void:
			if is_inside_tree():
				_refresh_slot(id))
		return
	elif selected.size() >= int(GameData.economy().get("pre_boosters_max", 2)):
		VFXManager.toast(tr("Up to %d boosters per level") % int(GameData.economy().get("pre_boosters_max", 2)))
		return
	else:
		selected.append(id)
		UIKit.bounce(slots[id], 1.08)
	_refresh_slot(id)


func _on_play() -> void:
	if not LivesManager.can_play(level):
		Popups.lives(true)
		return
	ProgressionManager.set_pre_boosters(selected, free)
	play_pressed.emit()
	ScreenManager.start_level()


func on_back() -> void:
	ScreenManager.close_modal(self)
