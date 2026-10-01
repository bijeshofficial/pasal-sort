class_name DailyPopups
extends RefCounted
## The daily feature popups opened from Home: reward calendar, missions
## (with the mission chest), daily challenge (with a month calendar) and
## the star chest.

const TWIST_NAMES := {"wrapped": "Wrapped candies", "cloth": "Dhaka-cloth jars", "lock": "Padlocked jars", "tall": "Tall jars"}
const TWIST_ICONS := {"wrapped": "candy", "cloth": "cloth", "lock": "lock", "tall": "jar"}


static func _t(s: String) -> String:
	return UIKit.t(s)


# --- Reward calendar ---------------------------------------------------------

static func open_calendar(on_changed: Callable = Callable()) -> GamePopup:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	var cal: Array = DailyManager.calendar()
	var idx := DailyManager.calendar_index()
	var can := DailyManager.can_claim_calendar()
	for i in cal.size():
		var state := "future"
		if i < idx:
			state = "claimed"
		elif i == idx:
			state = "today" if can else "next"
		grid.add_child(_day_card(i, cal[i], state))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.add_child(grid)
	var timer := UIKit.label("", 34, UIKit.INK_SOFT)
	body.add_child(timer)
	var p: GamePopup
	p = Popups.show({
		"id": "calendar",
		"title": _t("Daily rewards"),
		"content": body,
		"closable": true,
		"width": 960,
		"buttons": [{"id": "claim", "text": _t("Claim") if can else _t("Come back tomorrow"), "kind": "primary" if can else "neutral", "icon": "gift" if can else "clock", "disabled": not can, "close": false, "cb": func() -> void:
			var items := DailyManager.claim_calendar()
			if items.is_empty():
				return
			AudioManager.play("reward")
			ScreenManager.close_modal(p)
			ChestPopup.show_granted(_t("Day %d reward") % (idx + 1), items, on_changed, "gold")},
		],
	})
	_tick_timer(p, timer, func() -> String:
		return _t("Next reward in %s") % TimeManager.short_duration(TimeManager.seconds_to_midnight()) if not DailyManager.can_claim_calendar() else _t("A reward is waiting!"))
	return p


static func _day_card(i: int, reward: Dictionary, state: String) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(200, 230) if i < 6 else Vector2(200, 230)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := _bundle_icon(reward)
	c.draw.connect(func() -> void:
		var r := Rect2(Vector2(4, 4), c.size - Vector2(8, 8))
		var base := UIKit.GOLD if state == "today" else (Color("e9e4fb") if state == "claimed" else Color.WHITE)
		var edge := UIKit.GOLD_EDGE if state == "today" else UIKit.LINE.darkened(0.1)
		DrawKit.glossy_rrect(c, r, 28, base, edge, 0.0, 5.0, 10.0, true))
	var day := UIKit.title(_t("Day %d") % (i + 1), 32, Color.WHITE if state == "today" else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, UIKit.GOLD_EDGE.darkened(0.3) if state == "today" else Color(0, 0, 0, 0))
	if state != "today":
		day.add_theme_constant_override("outline_size", 0)
		day.add_theme_constant_override("shadow_outline_size", 0)
		day.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	day.position = Vector2(0, 14)
	day.size = Vector2(200, 40)
	c.add_child(day)
	var ic := UIKit.icon(String(icon[0]), 90, icon[1])
	ic.position = Vector2(55, 64)
	ic.size = Vector2(90, 90)
	ic.shadow = true
	c.add_child(ic)
	var amt := UIKit.label(String(icon[2]), 30, UIKit.INK)
	amt.position = Vector2(0, 166)
	amt.size = Vector2(200, 40)
	c.add_child(amt)
	if state == "claimed":
		var ok := UIKit.disk("check", 76, UIKit.PRIMARY, UIKit.PRIMARY_EDGE)
		ok.position = Vector2(112, 104)
		c.add_child(ok)
		c.modulate = Color(1, 1, 1, 0.75)
	if state == "today":
		UIKit.pulse.call_deferred(c, 1.05, 1.0)
	return c


## [icon, colour, text] that best represents a reward bundle.
static func _bundle_icon(b: Dictionary) -> Array:
	if int(b.get("sticker_packs", 0)) > 0:
		return ["sticker", UIKit.PINK, _t("Stickers!")]
	if int(b.get("unlimited_lives_min", 0)) > 0:
		return ["infinity", UIKit.HEART, "%d min" % int(b["unlimited_lives_min"])]
	var boosters: Dictionary = b.get("boosters", {})
	if not boosters.is_empty() and int(b.get("coins", 0)) < 100:
		var id: String = boosters.keys()[0]
		return [BoosterManager.icon_for(id), UIKit.SECONDARY, "x%d" % int(boosters[id])]
	return ["coin", Color.WHITE, "+%d" % int(b.get("coins", 0))]


# --- Missions ----------------------------------------------------------------

static func open_missions(on_changed: Callable = Callable()) -> GamePopup:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	var p: GamePopup
	# Lambdas capture by value, so the rebuild refers to itself through an array.
	var holder := [Callable()]
	var rebuild := func() -> void:
		for ch in body.get_children():
			ch.queue_free()
		body.add_child(_points_bar())
		var list := DailyManager.missions()
		for i in list.size():
			body.add_child(_mission_row(i, list[i], func() -> void:
				var coins := DailyManager.claim_mission(i)
				if coins >= 0:
					AudioManager.play("coin_pickup")
					VFXManager.toast(_t("+%d coins") % coins)
					(holder[0] as Callable).call()
					if on_changed.is_valid():
						on_changed.call()))
		if DailyManager.can_open_mission_chest():
			var b := UIKit.button(_t("Open the mission chest"), "gold", "chest", 46, Vector2(0, 150))
			b.pressed.connect(func() -> void:
				var contents := DailyManager.claim_mission_chest()
				if not contents.is_empty():
					ScreenManager.close_modal(p)
					ChestPopup.open(_t("Mission chest"), contents, "mission_chest", on_changed, "mission"))
			body.add_child(b)
			UIKit.pulse.call_deferred(b, 1.04, 1.0)
		var timer := UIKit.label("", 32, UIKit.INK_SOFT)
		body.add_child(timer)
		_tick_timer(body, timer, func() -> String: return _t("New missions in %s") % TimeManager.short_duration(TimeManager.seconds_to_midnight()))
	holder[0] = rebuild
	rebuild.call()
	p = Popups.show({"id": "missions", "title": _t("Daily missions"), "content": body, "closable": true, "width": 960})
	return p


static func _points_bar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 64)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pts := DailyManager.points()
	var need := DailyManager.chest_points()
	bar.draw.connect(func() -> void:
		var r := Rect2(Vector2(0, 8), Vector2(bar.size.x, 48))
		bar.draw_colored_polygon(DrawKit.rounded_rect(r, 24, 8), Color(UIKit.INK, 0.15))
		var k := clampf(float(pts) / need, 0.0, 1.0)
		if k > 0.0:
			DrawKit.gradient_fill(bar, DrawKit.rounded_rect(Rect2(r.position + Vector2(5, 5), Vector2(maxf(40.0, (r.size.x - 10) * k), r.size.y - 10)), 19, 8), Color("ffe680"), Color("ff9f1a")))
	var l := UIKit.title("%d / %d" % [mini(pts, need), need], 34)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(l)
	row.add_child(bar)
	row.add_child(UIKit.disk("chest", 110, UIKit.PURPLE, UIKit.PURPLE_EDGE))
	return row


static func _mission_row(i: int, m: Dictionary, on_claim: Callable) -> Control:
	var d := DailyManager.mission_def(String(m["id"]))
	var done := DailyManager.mission_done(m)
	var claimed := bool(m.get("claimed", false))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.card_box(Color("fff6cf") if done and not claimed else Color.WHITE, 20, UIKit.GOLD if done and not claimed else UIKit.LINE))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(_t(String(d.get("text", ""))), 38, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT))
	var target := int(d.get("target", 1))
	var prog := mini(int(m.get("progress", 0)), target)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 30)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		DrawKit.rrect(bar, Rect2(Vector2.ZERO, bar.size), 15, Color(UIKit.INK, 0.15))
		var fw := bar.size.x * float(prog) / target
		if fw > 2:
			DrawKit.gradient_fill(bar, DrawKit.rounded_rect(Rect2(Vector2(3, 3), Vector2(maxf(fw, 26) - 6, bar.size.y - 6)), 12, 4), UIKit.PRIMARY.lightened(0.3), UIKit.PRIMARY))
	col.add_child(bar)
	col.add_child(UIKit.label("%d / %d   +%d coins, +%d points" % [prog, target, int(d.get("coins", 20)), int(d.get("points", 10))], 26, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, false))
	row.add_child(col)
	var b: GameButton
	if claimed:
		b = UIKit.button("", "neutral", "check", 34, Vector2(150, 110))
		b.disabled = true
	else:
		b = UIKit.button(_t("Claim"), "primary", "", 34, Vector2(180, 110))
		b.disabled = not done
		b.pressed.connect(on_claim)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	card.set_meta("button", b)
	card.name = "mission_%d" % i
	return card


# --- Daily challenge ---------------------------------------------------------

static func open_challenge() -> GamePopup:
	DailyManager.prefetch_challenge()
	var twist := DailyManager.challenge_twist()
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UIKit.disk(TWIST_ICONS.get(twist, "jar"), 130, UIKit.PURPLE, UIKit.PURPLE_EDGE))
	var col := VBoxContainer.new()
	col.add_child(UIKit.label(_t("Today: %s") % _t(String(TWIST_NAMES.get(twist, twist))), 40, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT))
	col.add_child(UIKit.label(_t("Reward: %d coins. Free to play, no lives.") % DailyManager.challenge_reward(), 30, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, false))
	var streak := HBoxContainer.new()
	streak.add_child(UIKit.icon("fire", 52, Color("ff7a1a")))
	streak.add_child(UIKit.label(_t("Streak: %d days") % DailyManager.challenge_streak(), 32, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT))
	col.add_child(streak)
	row.add_child(col)
	body.add_child(row)
	body.add_child(_month_calendar())
	var done := DailyManager.challenge_done_today()
	var timer := UIKit.label("", 32, UIKit.INK_SOFT)
	body.add_child(timer)
	var p := Popups.show({
		"id": "challenge",
		"title": _t("Daily Challenge"),
		"content": body,
		"closable": true,
		"width": 960,
		"buttons": [{"id": "play", "text": _t("PLAY") if not done else _t("Done for today!"), "kind": "primary" if not done else "neutral", "icon": "play" if not done else "check", "disabled": done, "cb": func() -> void: ScreenManager.start_daily()}],
	})
	_tick_timer(p, timer, func() -> String: return _t("New challenge in %s") % TimeManager.short_duration(TimeManager.seconds_to_midnight()))
	return p


## This month: days with a finished challenge get a check, today a ring.
static func _month_calendar() -> Control:
	var now := Time.get_datetime_dict_from_unix_time(int(TimeManager.now()) + TimeManager.tz_bias())
	var year := int(now["year"])
	var month := int(now["month"])
	var first := Time.get_unix_time_from_datetime_string("%04d-%02d-01T00:00:00" % [year, month])
	var weekday := int(Time.get_datetime_dict_from_unix_time(int(first))["weekday"])   # 0 = Sunday
	var days_in: int = [31, 29 if (year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
	var done: Array = DailyManager.challenge_history()
	var today := int(now["day"])
	var c := Control.new()
	var rows := int(ceil((weekday + days_in) / 7.0))
	c.custom_minimum_size = Vector2(0, 70 + rows * 86)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var f := UIKit.font(true)
		var cw := c.size.x / 7.0
		var heads := ["S", "M", "T", "W", "T", "F", "S"]
		for k in 7:
			var hw := f.get_string_size(heads[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
			c.draw_string(f, Vector2(k * cw + (cw - hw) * 0.5, 40), heads[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UIKit.INK_SOFT)
		for d in range(1, days_in + 1):
			var slot := weekday + d - 1
			var center := Vector2((slot % 7 + 0.5) * cw, 70 + (slot / 7 + 0.5) * 86)
			var date := "%04d-%02d-%02d" % [year, month, d]
			if done.has(date):
				DrawKit.glossy_circle(c, center, 34, UIKit.PRIMARY, UIKit.PRIMARY_EDGE, 4.0, 5.0)
			elif d == today:
				c.draw_arc(center, 34, 0, TAU, 32, UIKit.GOLD_EDGE, 6.0, true)
			var txt := str(d)
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			c.draw_string(f, center + Vector2(-tw * 0.5, 11), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE if done.has(date) else (UIKit.INK if d <= today else Color(UIKit.INK, 0.35))))
	return c


# --- Star chest --------------------------------------------------------------

static func open_star_chest(on_changed: Callable = Callable()) -> void:
	var contents := ChestManager.claim_star_chest()
	if contents.is_empty():
		VFXManager.toast(_t("Spend %d more stars on your shop for the next star chest") % ChestManager.stars_to_next())
		return
	ChestPopup.open(_t("Star chest"), contents, "star_chest", on_changed, "gold")


static func _tick_timer(owner: Control, label: Label, text: Callable) -> void:
	label.text = text.call()
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	owner.add_child(t)
	t.timeout.connect(func() -> void:
		if is_instance_valid(label):
			label.text = text.call())
