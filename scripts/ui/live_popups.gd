class_name LivePopups
extends RefCounted
## Popups for the live features on Home: the sticker album (sets, pages,
## sticker shop), pack openings, the weekly event track and the Bazaar Race.


static func _t(s: String) -> String:
	return UIKit.t(s)


# --- Sticker album -----------------------------------------------------------

static func open_album(on_changed: Callable = Callable()) -> GamePopup:
	AlbumManager.mark_seen()
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.add_child(UIKit.icon("star", 56, Color("ff6b9a")))
	top.add_child(UIKit.label(_t("Sticker stars: %d") % AlbumManager.sticker_stars(), 38, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT))
	top.add_child(UIKit.hspacer())
	top.add_child(UIKit.label("%d / 72" % AlbumManager.unique_count(), 38, UIKit.INK_SOFT))
	body.add_child(top)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	var p: GamePopup
	for s in AlbumManager.sets():
		grid.add_child(_set_tile(s, func() -> void:
			ScreenManager.close_modal(p)
			open_set(String(s["id"]), on_changed)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 760)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.add_child(grid)
	body.add_child(scroll)
	var shop := HBoxContainer.new()
	shop.add_theme_constant_override("separation", 14)
	for pack in AlbumManager.data().get("shop", []):
		var b := UIKit.button("%s  %d" % [_t(String(pack["name"])), int(pack["stars"])], "pink", "sticker", 32, Vector2(0, 120))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = AlbumManager.sticker_stars() < int(pack["stars"])
		var pid := String(pack["id"])
		b.pressed.connect(func() -> void:
			var got := AlbumManager.buy_with_stars(pid)
			if not got.is_empty():
				ScreenManager.close_modal(p)
				open_pack_result(got, on_changed))
		shop.add_child(b)
	body.add_child(shop)
	p = Popups.show({"id": "album", "title": _t("Pasal Album"), "content": body, "closable": true, "width": 980})
	return p


static func _set_tile(s: Dictionary, on_open: Callable) -> Control:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(420, 230)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var col := Color.html(String(s["color"]))
	var n := AlbumManager.set_progress(String(s["id"]))
	var claim := AlbumManager.can_claim_set(String(s["id"]))
	var first: Dictionary = (s["stickers"] as Array)[0]
	b.draw.connect(func() -> void:
		DrawKit.glossy_rrect(b, Rect2(Vector2(4, 4), b.size - Vector2(8, 8)), 30, col, col.darkened(0.35), 0.0, 5.0, 10.0, true)
		StickerArt.draw_glyph(b, Rect2(Vector2(22, 30), Vector2(150, 150)), String(first["glyph"]))
		var bar := Rect2(Vector2(190, 150), Vector2(200, 30))
		b.draw_colored_polygon(DrawKit.rounded_rect(bar, 15, 6), Color(0, 0, 0, 0.3))
		if n > 0:
			b.draw_colored_polygon(DrawKit.rounded_rect(Rect2(bar.position + Vector2(4, 4), Vector2(maxf(22.0, (bar.size.x - 8) * n / 9.0), 22)), 11, 6), Color("ffe680")))
	var name_l := UIKit.title(_t(String(s["name"])), 36)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.position = Vector2(180, 30)
	name_l.size = Vector2(220, 110)
	b.add_child(name_l)
	var cnt := UIKit.title("%d / 9" % n, 28)
	cnt.position = Vector2(190, 182)
	cnt.size = Vector2(200, 36)
	b.add_child(cnt)
	if claim:
		var dot := UIKit.badge(_t("Reward!"), UIKit.HEART, 26)
		dot.position = Vector2(270, -10)
		b.add_child(dot)
	b.pressed.connect(on_open)
	return b


static func open_set(set_id: String, on_changed: Callable = Callable()) -> GamePopup:
	var s: Dictionary = {}
	for x in AlbumManager.sets():
		if x["id"] == set_id:
			s = x
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for st in s.get("stickers", []):
		var info := AlbumManager.sticker(String(st["id"]))
		var owned := AlbumManager.owns(String(st["id"]))
		var dupes := AlbumManager.count(String(st["id"])) - 1
		var c := Control.new()
		c.custom_minimum_size = Vector2(270, 300)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.draw.connect(func() -> void: StickerArt.draw_card(c, Rect2(Vector2(6, 6), c.size - Vector2(12, 12)), info, owned))
		if dupes > 0:
			var b := UIKit.badge("x%d" % (dupes + 1), UIKit.PURPLE, 26)
			b.position = Vector2(190, 4)
			c.add_child(b)
		grid.add_child(c)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.add_child(grid)
	var p: GamePopup
	var buttons: Array = []
	if AlbumManager.can_claim_set(set_id):
		buttons.append({"id": "claim", "text": _t("Claim set reward"), "kind": "gold", "icon": "gift", "cb": func() -> void:
			var r := AlbumManager.claim_set(set_id)
			if not r.is_empty():
				Popups.reward(_t("Set complete!"), Rewards.describe(r), "album")
				if on_changed.is_valid():
					on_changed.call()})
	else:
		body.add_child(UIKit.label(_t("Complete the set: %s") % Rewards.describe(s.get("reward", {})), 30, UIKit.INK_SOFT))
	buttons.append({"id": "back", "text": _t("Back"), "kind": "neutral", "icon": "back", "cb": func() -> void: open_album(on_changed)})
	p = Popups.show({"id": "album_set", "title": _t(String(s.get("name", ""))), "content": body, "buttons": buttons, "width": 960})
	return p


## New stickers flip in one by one.
static func open_pack_result(stickers: Array, on_changed: Callable = Callable()) -> GamePopup:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for i in stickers.size():
		var info: Dictionary = stickers[i]
		var c := Control.new()
		c.custom_minimum_size = Vector2(250, 300)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.draw.connect(func() -> void: StickerArt.draw_card(c, Rect2(Vector2(6, 6), c.size - Vector2(12, 12)), info, true))
		if bool(info.get("duplicate", false)):
			var d := UIKit.badge(_t("+%d stars") % int(info.get("rarity", 1)), UIKit.PURPLE, 24)
			d.position = Vector2(40, 270)
			c.add_child(d)
		else:
			var d := UIKit.badge(_t("NEW"), UIKit.HEART, 26)
			d.position = Vector2(160, -8)
			c.add_child(d)
		c.scale = Vector2(0, 1)
		c.pivot_offset = Vector2(125, 150)
		var tw := c.create_tween()
		tw.tween_interval(0.25 + i * 0.3)
		tw.tween_callback(func() -> void: AudioManager.play("pop", 1.0 + i * 0.1))
		tw.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		row.add_child(c)
	AudioManager.play("reward")
	return Popups.show({"id": "pack", "title": _t("Sticker pack!"), "content": row, "width": 940,
		"buttons": [{"id": "ok", "text": _t("Into the album"), "kind": "primary", "icon": "album", "cb": func() -> void:
			if on_changed.is_valid():
				on_changed.call()}]})


# --- Weekly event ------------------------------------------------------------

static func open_event(on_changed: Callable = Callable()) -> GamePopup:
	var ev := EventManager.current()
	if ev.is_empty():
		return null
	var col := Color.html(String(ev.get("color", "2f9bff")))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.add_child(UIKit.disk(String(ev["icon"]), 130, col, col.darkened(0.35)))
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var txt := UIKit.label(_t(String(ev.get("text", ""))), 30, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, false)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(txt)
	var timer := UIKit.label("", 30, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT)
	hv.add_child(timer)
	head.add_child(hv)
	body.add_child(head)
	body.add_child(UIKit.title(_t("You have %d %s") % [EventManager.currency(), EventManager.currency_name()], 42, col, HORIZONTAL_ALIGNMENT_CENTER, col.darkened(0.5)))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 700)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.add_child(list)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var p: GamePopup
	var holder := [Callable()]
	var rebuild := func() -> void:
		for ch in list.get_children():
			ch.queue_free()
		var track: Array = EventManager.track()
		for i in track.size():
			list.add_child(_milestone_row(i, track[i], col, func(premium: bool) -> void:
				var r := EventManager.claim(i, premium)
				if not r.is_empty():
					AudioManager.play("reward")
					VFXManager.toast(Rewards.describe(r))
					(holder[0] as Callable).call()
					if on_changed.is_valid():
						on_changed.call()))
	holder[0] = rebuild
	rebuild.call()
	var buttons: Array = []
	if not EventManager.has_pass():
		buttons.append({"id": "pass", "text": _t("Event Pass  %s") % String(GameData.iap_product("event_pass").get("price_label", "")), "kind": "purple", "icon": "flag", "close": false, "cb": func() -> void:
			IAPManager.buy("event_pass", func(ok: bool) -> void:
				if ok:
					ScreenManager.close_modal(p)
					open_event(on_changed))})
	p = Popups.show({"id": "event", "title": _t(String(ev["name"])), "content": body, "closable": true, "width": 980, "buttons": buttons})
	DailyPopups._tick_timer(p, timer, func() -> String: return _t("Ends in %s") % TimeManager.short_duration(TimeManager.seconds_to_week_end()))
	return p


static func _milestone_row(i: int, m: Dictionary, col: Color, on_claim: Callable) -> Control:
	var reached := EventManager.milestone_reached(i)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.card_box(Color("fff6cf") if reached else Color.WHITE, 14, UIKit.LINE))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var num := UIKit.badge(str(int(m["target"])), col if reached else UIKit.DISABLED, 30)
	num.custom_minimum_size = Vector2(110, 0)
	row.add_child(num)
	for premium in [false, true]:
		var r: Dictionary = m["pass" if premium else "free"]
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := UIKit.label(Rewards.describe(r), 24, UIKit.INK if not premium else UIKit.PURPLE_EDGE, HORIZONTAL_ALIGNMENT_CENTER, false)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(260, 0)
		cell.add_child(l)
		var claimed: bool = (EventManager.block()["claimed_pass" if premium else "claimed_free"] as Array).has(i)
		var b: GameButton
		if claimed:
			b = UIKit.button("", "neutral", "check", 26, Vector2(0, 80))
			b.disabled = true
		elif premium and not EventManager.has_pass():
			b = UIKit.button(_t("Pass"), "neutral", "lock", 26, Vector2(0, 80))
			b.disabled = true
		else:
			b = UIKit.button(_t("Claim"), "primary" if not premium else "purple", "", 28, Vector2(0, 80))
			b.disabled = not reached
			var pr: bool = premium
			b.pressed.connect(func() -> void: on_claim.call(pr))
		cell.add_child(b)
		row.add_child(cell)
	return card


# --- Bazaar Race -------------------------------------------------------------

static func open_race(on_changed: Callable = Callable()) -> GamePopup:
	RaceManager.update()
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	var intro := UIKit.label(_t("Race the shopkeepers of the bazaar to %d wins! (They're friendly characters, not real players.)") % RaceManager.goal(), 30, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, false)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)
	var st := RaceManager.state()
	var p: GamePopup
	var buttons: Array = []
	if st == "running" or st == "done":
		for row in RaceManager.standings():
			body.add_child(_racer_row(row))
		var timer := UIKit.label("", 30, UIKit.INK)
		body.add_child(timer)
		if st == "running":
			DailyPopups._tick_timer(body, timer, func() -> String: return _t("Race ends in %s") % TimeManager.short_duration(int(float(RaceManager.block()["end"]) - TimeManager.now())))
		else:
			var rk := RaceManager.rank()
			timer.text = (_t("You finished #%d!") % rk) if rk > 0 else _t("The race is over. Better luck next time!")
			buttons.append({"id": "claim", "text": _t("Collect") if rk >= 1 and rk <= 3 else _t("OK"), "kind": "gold", "icon": "trophy", "cb": func() -> void:
				var r := RaceManager.claim()
				if not r.is_empty():
					Popups.reward(_t("Bazaar Race"), Rewards.describe(r), "trophy")
				if on_changed.is_valid():
					on_changed.call()})
	else:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		for k in 3:
			var r := RaceManager.reward_for(k + 1)
			var v := VBoxContainer.new()
			v.add_child(UIKit.disk("trophy", 110, [UIKit.GOLD, Color("c9d1d9"), Color("d9884a")][k], [UIKit.GOLD_EDGE, Color("6b7b88"), Color("8a4b20")][k]))
			var l := UIKit.label(Rewards.describe(r), 24, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, false)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(250, 0)
			v.add_child(l)
			row.add_child(v)
		body.add_child(row)
		if RaceManager.can_join():
			buttons.append({"id": "join", "text": _t("Join the race"), "kind": "primary", "icon": "race", "cb": func() -> void:
				RaceManager.join()
				open_race(on_changed)
				if on_changed.is_valid():
					on_changed.call()})
		else:
			var timer := UIKit.label("", 32, UIKit.INK)
			body.add_child(timer)
			DailyPopups._tick_timer(body, timer, func() -> String: return _t("Next race in %s") % TimeManager.short_duration(RaceManager.seconds_until_open()))
	p = Popups.show({"id": "race", "title": _t("Bazaar Race"), "content": body, "closable": true, "width": 960, "buttons": buttons})
	return p


static func _racer_row(row: Dictionary) -> Control:
	var me := bool(row["player"])
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.card_box(Color("e9f8df") if me else Color.WHITE, 12, UIKit.PRIMARY if me else UIKit.LINE))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)
	var av := AvatarView.new()
	av.index = int(row["avatar"])
	av.frame = ProgressionManager.selected_cosmetic("frame") if me else "frame_plain"
	av.custom_minimum_size = Vector2(96, 96)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(av)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label("%s  -  %s" % [String(row["name"]), String(row["shop"])], 30, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT))
	var wins := int(row["wins"])
	var goal := RaceManager.goal()
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 34)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		DrawKit.rrect(bar, Rect2(Vector2.ZERO, bar.size), 17, Color(UIKit.INK, 0.15))
		var k := float(wins) / goal
		if k > 0.0:
			var c := UIKit.PRIMARY if me else UIKit.SECONDARY
			DrawKit.gradient_fill(bar, DrawKit.rounded_rect(Rect2(Vector2(3, 3), Vector2(maxf(28.0, (bar.size.x - 6) * k), bar.size.y - 6)), 14, 6), c.lightened(0.3), c))
	v.add_child(bar)
	h.add_child(v)
	h.add_child(UIKit.label("%d/%d" % [wins, goal], 34, UIKit.INK))
	return card
