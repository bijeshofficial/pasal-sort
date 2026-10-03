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
		v.add_child(_booster_hint())
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


## The Dami streak: a flame, three steps (one per win in a row) and what
## the next win adds. Below it, progress to Hajurama's Trunk.
func _streak_meter() -> Control:
	var n := StreakManager.dami()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.card_box(UIKit.PAPER_DARK, 20, UIKit.LINE))
	box.add_child(card)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	card.add_child(h)
	_streak = Control.new()
	_streak.custom_minimum_size = Vector2(120, 140)
	_streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_streak.draw.connect(_draw_streak)
	h.add_child(_streak)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	h.add_child(col)
	col.add_child(UIKit.label(tr("Dami streak: %d") % n if n > 0 else tr("Dami streak"), 38, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT))
	var steps := Control.new()
	steps.custom_minimum_size = Vector2(0, 30)
	steps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	steps.draw.connect(_draw_steps.bind(steps, mini(n, 3)))
	col.add_child(steps)
	var cap := UIKit.label(_streak_caption(n), 28, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(cap)
	var trunk := HBoxContainer.new()
	trunk.alignment = BoxContainer.ALIGNMENT_CENTER
	trunk.add_theme_constant_override("separation", 10)
	trunk.add_child(UIKit.icon("chest", 44, Color("2f6f8f")))
	trunk.add_child(UIKit.label(tr("Hajurama's Trunk: %d / %d wins in a row") % [StreakManager.treasure(), StreakManager.treasure_goal()], 28, UIKit.INK_SOFT))
	box.add_child(trunk)
	return box


func _streak_caption(n: int) -> String:
	if n >= 3:
		return tr("Top streak! All three boosters are free.")
	if n <= 0:
		return tr("Win without failing for free boosters")
	var table: Dictionary = GameData.economy().get("dami_streak", {})
	var next: Array = (table.get(str(n + 1), []) as Array)
	for id in next:
		if not free.has(id):
			return tr("Win again without failing: %s free next time") % BoosterManager.display_name(String(id))
	return tr("Win without failing for free boosters")


## What the player can do with the booster row, in plain words.
func _booster_hint() -> Label:
	var cap := int(GameData.economy().get("pre_boosters_max", 2))
	var text := tr("Tap a booster to bring it (up to %d)") % cap
	if free.size() >= BoosterManager.PRE_IDS.size():
		text = tr("Your streak turned every booster on for free")
	elif not free.is_empty():
		text = tr("Gold ones are free. Tap another to add it")
	var l := UIKit.label(text, 32, UIKit.INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _process(delta: float) -> void:
	_t += delta
	if _streak:
		_streak.queue_redraw()


## One soft, layered flame (red-orange, orange, yellow core) that sways a
## little; grey when there is no streak yet.
func _draw_streak() -> void:
	var lit := StreakManager.dami() > 0
	var base := Vector2(_streak.size.x * 0.5, _streak.size.y - 14)
	_streak.draw_colored_polygon(DrawKit.ellipse(base + Vector2(0, 8), 40, 8, 20), Color(0, 0, 0, 0.12))
	var sway := sin(_t * 3.1) * 0.06 + sin(_t * 7.3) * 0.025 if lit else 0.0
	var breathe := 1.0 + (sin(_t * 5.0) * 0.03 if lit else 0.0)
	var layers := [
		[1.0, Color("ff5a36"), Color("e0342a")],
		[0.72, Color("ff9f1c"), Color("ff7a1a")],
		[0.44, Color("ffe066"), Color("ffc61f")],
	]
	for layer in layers:
		var k: float = layer[0]
		var top: Color = layer[1] if lit else Color(UIKit.INK_SOFT, 0.18 + 0.12 * (1.0 - k))
		var bottom: Color = layer[2] if lit else Color(UIKit.INK_SOFT, 0.25)
		var pts := _flame_shape(base + Vector2(0, -6 * (1.0 - k)), 46.0 * k, 116.0 * k * breathe, sway * (1.4 - k))
		DrawKit.gradient_fill(_streak, pts, top, bottom)


## A teardrop: round bottom at `base`, a tip `height` above it that leans
## with `sway`.
func _flame_shape(base: Vector2, r: float, height: float, sway: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 36:
		var a := TAU * i / 36.0
		var up := (1.0 + cos(a)) * 0.5          # 1 at the tip, 0 at the bottom
		var x := sin(a) * pow(absf(sin(a * 0.5)), 1.4) * r
		pts.append(Vector2(base.x + x + sway * height * up * up, base.y - up * height))
	return pts


## Three steps, lit up to the streak.
func _draw_steps(ci: Control, n: int) -> void:
	var gap := 12.0
	var w := minf((ci.size.x - gap * 2.0) / 3.0, 150.0)
	for k in 3:
		var r := Rect2(k * (w + gap), 4, w, ci.size.y - 8)
		var on := k < n
		DrawKit.rrect(ci, r, r.size.y * 0.5, Color("ff8a1f") if on else Color(UIKit.INK_SOFT, 0.16))
		if on:
			DrawKit.rrect(ci, Rect2(r.position + Vector2(6, 3), Vector2(r.size.x - 12, r.size.y * 0.35)), r.size.y * 0.2, Color(1, 1, 1, 0.3))


func _slot(id: String) -> Control:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(220, 250)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.draw.connect(func() -> void:
		var r := Rect2(Vector2(10, 10), Vector2(200, 200))
		var fill := UIKit.SECONDARY
		var edge := UIKit.SECONDARY_EDGE
		if free.has(id):
			fill = UIKit.GOLD
			edge = UIKit.GOLD_EDGE
		elif selected.has(id):
			fill = UIKit.PRIMARY
			edge = UIKit.PRIMARY_EDGE
		DrawKit.glossy_rrect(b, r, 40, fill, edge, 0.0, 6.0, 12.0, true))
	var ic := UIKit.icon(BoosterManager.icon_for(id), 110, Color.WHITE)
	ic.shadow = true
	ic.position = Vector2(55, 40)
	ic.size = Vector2(110, 110)
	b.add_child(ic)
	var name_l := UIKit.label(BoosterManager.display_name(id), 28, UIKit.INK)
	name_l.position = Vector2(0, 214)
	name_l.size = Vector2(220, 36)
	b.add_child(name_l)
	b.pressed.connect(func() -> void: toggle(id))
	slots[id] = b
	_refresh_slot(id)
	return b


## The corner tag: FREE (streak), a tick (picked), the stock count, or +.
func _refresh_slot(id: String) -> void:
	var b: Button = slots[id]
	if b.has_meta("tag"):
		(b.get_meta("tag") as Node).queue_free()
	var tag: PanelContainer
	if free.has(id):
		tag = UIKit.badge(tr("FREE"), UIKit.DANGER, 30)
	elif selected.has(id):
		tag = UIKit.badge(tr("ON"), UIKit.PRIMARY_EDGE, 30)
	else:
		var n := BoosterManager.count(id)
		tag = UIKit.badge(str(n) if n > 0 else "+", UIKit.SECONDARY_EDGE if n > 0 else UIKit.HEART, 30)
	tag.position = Vector2(150, -6)
	b.add_child(tag)
	b.set_meta("tag", tag)
	b.queue_redraw()


## Select/deselect a booster (max 2 besides the free ones). With none in
## stock, offer to buy one.
func toggle(id: String) -> void:
	if free.has(id):
		AudioManager.play("button_click")
		UIKit.bounce(slots[id], 1.05)
		VFXManager.toast(tr("Already on: a gift from your Dami streak"))
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
