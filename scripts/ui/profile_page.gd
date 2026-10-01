class_name ProfilePage
extends Control
## Profile: avatar, editable name, level, stats and achievements.

signal changed

var list: VBoxContainer
var avatar: AvatarView
var name_edit: LineEdit
var claim_buttons: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 30
	add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 36)
	pad.add_theme_constant_override("margin_bottom", 60)
	scroll.add_child(pad)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 24)
	pad.add_child(list)
	build()
	AchievementManager.claimed.connect(_on_claimed)


func _on_claimed(_id: String) -> void:
	build()


func build() -> void:
	for ch in list.get_children():
		ch.queue_free()
	claim_buttons.clear()
	AchievementManager.refresh()
	var rib := UIKit.ribbon("PROFILE", 620, UIKit.PURPLE, UIKit.PURPLE_EDGE, 64)
	rib.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.add_child(rib)
	list.add_child(_header())
	list.add_child(_stats())
	list.add_child(UIKit.title(tr("Achievements"), 54, Color("ffe066"), HORIZONTAL_ALIGNMENT_LEFT))
	# Claimable first, then in progress, then finished.
	var defs: Array = AchievementManager.definitions().duplicate()
	defs.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return _rank(x["id"]) < _rank(y["id"]))
	for a in defs:
		list.add_child(_achievement_card(a))


func _rank(id: String) -> int:
	if AchievementManager.can_claim(id):
		return 0
	if AchievementManager.is_claimed(id):
		return 2
	return 1


func _card(fill: Color = UIKit.PAPER) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.card_box(fill, 26, UIKit.GOLD if fill == Color("fff6cf") else UIKit.LINE))
	return p


func _header() -> Control:
	var card := _card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	card.add_child(row)
	var ab := Button.new()
	ab.flat = true
	ab.focus_mode = Control.FOCUS_NONE
	ab.custom_minimum_size = Vector2(220, 220)
	for st in ["normal", "hover", "pressed", "focus"]:
		ab.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	avatar = AvatarView.new()
	avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.index = int(SaveManager.game()["profile"]["avatar"])
	ab.add_child(avatar)
	var edit := UIKit.icon("pencil", 56, Color.WHITE)
	edit.position = Vector2(160, 160)
	var edit_bg := Control.new()
	edit_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edit_bg.position = Vector2(150, 150)
	edit_bg.size = Vector2(76, 76)
	edit_bg.draw.connect(func() -> void: DrawKit.glossy_circle(edit_bg, Vector2(38, 38), 38, UIKit.PRIMARY, UIKit.PRIMARY_EDGE, 4.0, 5.0))
	ab.add_child(edit_bg)
	ab.add_child(edit)
	ab.pressed.connect(_pick_avatar)
	row.add_child(ab)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	name_edit = LineEdit.new()
	name_edit.text = String(SaveManager.game()["profile"]["name"])
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(200, 110)
	name_edit.add_theme_font_override("font", UIKit.font(true))
	name_edit.add_theme_font_size_override("font_size", 50)
	name_edit.add_theme_color_override("font_color", UIKit.INK)
	name_edit.add_theme_stylebox_override("normal", UIKit.box(UIKit.PAPER_DARK, 26, UIKit.NEUTRAL_EDGE, 4, 18))
	name_edit.add_theme_stylebox_override("focus", UIKit.box(Color.WHITE, 26, UIKit.PRIMARY, 4, 18))
	name_edit.text_submitted.connect(func(_t: String) -> void: name_edit.release_focus())
	name_edit.focus_exited.connect(func() -> void: set_player_name(name_edit.text))
	col.add_child(name_edit)
	col.add_child(UIKit.title(tr("Level %d") % ProgressionManager.current_level(), 48, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, Color("8a4100")))
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 12)
	chips.add_child(_chip("star", UIKit.GOLD, str(CurrencyManager.get_stars())))
	chips.add_child(_chip("home", UIKit.PRIMARY, tr("%d areas") % RenovationManager.completed_area_count()))
	col.add_child(chips)
	return card


func _chip(icon: String, color: Color, text: String) -> Control:
	var p := PanelContainer.new()
	var sb := UIKit.box(Color(color, 0.18), 30, Color.TRANSPARENT, 0, 8)
	sb.content_margin_left = 12
	sb.content_margin_right = 18
	p.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	p.add_child(row)
	var ic := UIKit.icon(icon, 44, color.darkened(0.1))
	row.add_child(ic)
	row.add_child(UIKit.label(text, 32, UIKit.INK))
	return p


func set_player_name(value: String) -> void:
	var clean := value.strip_edges()
	if clean == "":
		clean = "Player"
	SaveManager.game()["profile"]["name"] = clean
	SaveManager.save_game()
	if name_edit and name_edit.text != clean:
		name_edit.text = clean


func set_avatar(idx: int) -> void:
	SaveManager.game()["profile"]["avatar"] = idx
	SaveManager.save_game()
	if avatar:
		avatar.index = idx
	changed.emit()


func _pick_avatar() -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	var popup: GamePopup
	for i in GameData.avatars().size():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(170, 170)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var av := AvatarView.new()
		av.index = i
		av.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(av)
		b.pressed.connect(func() -> void:
			AudioManager.play("button_click")
			set_avatar(i)
			Popups.close_id("avatars"))
		grid.add_child(b)
	popup = Popups.show({"id": "avatars", "title": "Choose your avatar", "content": grid, "closable": true})


func _stats() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	var secs := SaveManager.stat("play_time_sec")
	var play := "%dh %02dm" % [secs / 3600, (secs / 60) % 60] if secs >= 3600 else "%dm" % (secs / 60)
	var rows := [
		[tr("Levels completed"), str(SaveManager.game_stat("levels_completed")), "flag", UIKit.SECONDARY],
		[tr("Jars filled"), str(SaveManager.game_stat("jars_filled")), "jar", UIKit.PRIMARY],
		[tr("Candies moved"), str(SaveManager.game_stat("candies_moved")), "candy", UIKit.PINK],
		[tr("Boosters used"), str(SaveManager.game_stat("boosters_used")), "shuffle", UIKit.PURPLE],
		[tr("Best streak"), str(int(SaveManager.game().get("streaks", {}).get("best_dami", 0))), "fire", Color("ff7a1a")],
		[tr("Daily challenges"), str(SaveManager.game_stat("daily_challenges")), "calendar", UIKit.GOLD],
		[tr("Tasks done"), str(SaveManager.game_stat("tasks_completed")), "brush", UIKit.SECONDARY],
		[tr("Play time"), play, "clock", UIKit.INK_SOFT],
	]
	for r in rows:
		var c := _card(UIKit.PAPER)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		c.add_child(h)
		var col: Color = r[3]
		h.add_child(UIKit.disk(String(r[2]), 92, col, col.darkened(0.35)))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(UIKit.label(r[1], 46, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT))
		var cap := UIKit.label(String(r[0]), 26, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, false)
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(cap)
		h.add_child(v)
		grid.add_child(c)
	return grid


func _achievement_card(a: Dictionary) -> Control:
	var id: String = a["id"]
	var complete := AchievementManager.is_complete(id)
	var claimed := AchievementManager.is_claimed(id)
	var card := _card(Color("fff6cf") if complete and not claimed else UIKit.PAPER)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	card.add_child(row)
	# Medal colour by tier: bronze, silver, gold (grey until reached).
	var t := mini(AchievementManager.tier(id), 2)
	var medal: Array = [[Color("d9884a"), Color("8a4b20")], [Color("c9d1d9"), Color("6b7b88")], [UIKit.GOLD, UIKit.GOLD_EDGE]][t]
	if not complete and not claimed:
		medal = [UIKit.DISABLED, UIKit.DISABLED_EDGE]
	var medal_box := UIKit.disk("trophy", 104, medal[0], medal[1])
	if AchievementManager.tier_count(id) > 1:
		var rn := UIKit.badge(AchievementManager.ROMAN[mini(AchievementManager.tier(id), AchievementManager.tier_count(id) - 1)], UIKit.PURPLE, 24)
		rn.position = Vector2(58, 64)
		medal_box.add_child(rn)
	row.add_child(medal_box)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	col.add_child(UIKit.label(AchievementManager.title(id), 40, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT))
	var desc := UIKit.label("%s  -  %s" % [AchievementManager.description(id), AchievementManager.reward_text(AchievementManager.current_reward(id))], 28, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, false)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(300, 0)
	col.add_child(desc)
	var prog := AchievementManager.progress(id)
	var tgt := AchievementManager.target(id)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 30)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		DrawKit.rrect(bar, Rect2(Vector2.ZERO, bar.size), 15, Color(UIKit.INK, 0.15))
		var fw := bar.size.x * clampf(float(prog) / float(tgt), 0.0, 1.0)
		if fw > 2:
			var fill := Rect2(Vector2(3, 3), Vector2(maxf(fw, 30) - 6, bar.size.y - 6))
			var base := UIKit.PRIMARY if not complete else UIKit.GOLD
			DrawKit.gradient_fill(bar, DrawKit.rounded_rect(fill, 12, 4), base.lightened(0.35), base)
			DrawKit.rrect(bar, Rect2(fill.position + Vector2(8, 3), Vector2(fill.size.x - 16, 6)), 3, Color(1, 1, 1, 0.45)))
	col.add_child(bar)
	col.add_child(UIKit.label("%d / %d" % [prog, tgt], 26, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, false))
	var btn: GameButton
	if claimed:
		btn = UIKit.button(tr("Done"), "neutral", "check", 30, Vector2(200, 110))
		btn.disabled = true
	else:
		btn = UIKit.button("CLAIM", "primary", "", 34, Vector2(200, 110))
		btn.disabled = not complete
		btn.pressed.connect(func() -> void: claim(id))
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(btn)
	claim_buttons[id] = btn
	return card


func claim(id: String) -> void:
	var reward := AchievementManager.claim(id)
	if reward.is_empty():
		return
	Popups.reward(tr(String(AchievementManager.definition(id)["title"])), AchievementManager.reward_text(reward), "trophy")
	changed.emit()
