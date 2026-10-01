class_name LivePopups
extends RefCounted
## Popups for the sticker album on Home: sets, pages, the sticker shop and
## pack openings.


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
			Popups.close_id("album")
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
				Popups.close_id("album")
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
