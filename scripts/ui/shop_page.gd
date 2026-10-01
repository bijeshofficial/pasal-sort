class_name ShopPage
extends Control
## Shop tab: free daily gift, coin packs (mock IAP), booster bundles, lives
## refill and cosmetics (jar skins, candy wrappers, shop themes).

signal changed

var list: VBoxContainer
var scroll: ScrollContainer
var cosmetic_buttons: Dictionary = {}   # id -> GameButton
var daily_button: GameButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	scroll = ScrollContainer.new()
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
	list.add_theme_constant_override("separation", 26)
	pad.add_child(list)
	build()
	CurrencyManager.coins_changed.connect(_on_coins_changed)


func _on_coins_changed(_t: int, _d: int) -> void:
	_refresh_buttons()


func build() -> void:
	for ch in list.get_children():
		ch.queue_free()
	cosmetic_buttons.clear()
	var rib := UIKit.ribbon("SHOP", 620, UIKit.SECONDARY, UIKit.SECONDARY_EDGE, 64)
	rib.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.add_child(rib)
	list.add_child(_daily_card())
	_section("Coins")
	var packs := HBoxContainer.new()
	packs.add_theme_constant_override("separation", 18)
	list.add_child(packs)
	for p in GameData.economy()["coin_packs"]:
		packs.add_child(_coin_pack_card(p))
	_section("Boosters")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	list.add_child(grid)
	for b in GameData.economy()["bundles"]:
		grid.add_child(_bundle_card(b))
	list.add_child(_lives_card())
	for cat in GameData.cosmetic_categories():
		_section(cat["name"])
		var cg := GridContainer.new()
		cg.columns = 3
		cg.add_theme_constant_override("h_separation", 16)
		cg.add_theme_constant_override("v_separation", 16)
		list.add_child(cg)
		for item in GameData.cosmetics(cat["id"]):
			cg.add_child(_cosmetic_card(item))
	_refresh_buttons()


func _section(title: String) -> void:
	list.add_child(UIKit.spacer(6))
	list.add_child(UIKit.title(title, 54, Color("ffe066"), HORIZONTAL_ALIGNMENT_LEFT))


func _card(fill: Color = UIKit.PAPER) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.card_box(fill, 24))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


func _daily_card() -> Control:
	var card := _card(Color("fff6cf"))
	card.add_theme_stylebox_override("panel", UIKit.card_box(Color("fff6cf"), 24, UIKit.GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	card.add_child(row)
	row.add_child(UIKit.disk("gift", 130, UIKit.PINK, UIKit.PINK_EDGE))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label("Daily free coins", 44, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT))
	var sub := UIKit.label("Watch a short ad for %d coins. Once a day." % int(GameData.economy()["daily_free_coins"]), 32, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, false)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	row.add_child(col)
	daily_button = UIKit.button("Watch", "secondary", "ad", 38, Vector2(230, 130))
	daily_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	daily_button.pressed.connect(claim_daily)
	row.add_child(daily_button)
	return card


static func daily_available() -> bool:
	return String(SaveManager.game().get("daily_free_claimed_date", "")) != GameManager.today()


func claim_daily() -> void:
	if not daily_available():
		VFXManager.toast("Come back tomorrow for more")
		return
	AdManager.show_rewarded("daily_gift", func(ok: bool) -> void:
		if not ok:
			VFXManager.toast("Ad not available right now")
			return
		SaveManager.game()["daily_free_claimed_date"] = GameManager.today()
		CurrencyManager.add_coins(int(GameData.economy()["daily_free_coins"]))
		Popups.reward("Daily gift", "+%d coins" % int(GameData.economy()["daily_free_coins"]))
		_refresh_buttons()
		changed.emit())


func _coin_pack_card(p: Dictionary) -> Control:
	var card := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var art := CenterContainer.new()
	art.add_child(UIKit.icon("coin_pile", 110))
	v.add_child(art)
	v.add_child(UIKit.title("+%d" % int(p["coins"]), 50, Color("ffd23f"), HORIZONTAL_ALIGNMENT_CENTER, Color("8a4100")))
	var name_l := UIKit.label(p["name"], 28, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, false)
	v.add_child(name_l)
	var b := UIKit.button(String(p.get("price_label", "")), "primary", "", 38, Vector2(0, 120))
	b.pressed.connect(func() -> void:
		IAPManager.buy(p["id"], func(ok: bool) -> void:
			if ok:
				Popups.reward("Test purchase", "+%d coins" % int(p["coins"]))))
	v.add_child(b)
	v.add_child(UIKit.label("test only", 24, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, false))
	if p.has("ribbon"):
		var holder := VBoxContainer.new()
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_theme_constant_override("separation", -26)
		var ribbon := CenterContainer.new()
		ribbon.z_index = 2
		ribbon.add_child(UIKit.badge(String(p["ribbon"]), UIKit.DANGER, 28))
		holder.add_child(ribbon)
		holder.add_child(card)
		return holder
	return card


func _bundle_card(b: Dictionary) -> Control:
	var card := _card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var grant: Dictionary = b["grant"]
	var icon: String = "gift" if grant.size() > 1 else {"undo": "undo", "extra_jar": "jar_plus", "shuffle": "shuffle"}[grant.keys()[0]]
	row.add_child(UIKit.disk(icon, 110, UIKit.SECONDARY, UIKit.SECONDARY_EDGE))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(b["name"], 36, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT))
	var btn := UIKit.button(str(int(b["price"])), "gold", "coin", 36, Vector2(0, 110))
	btn.pressed.connect(func() -> void: buy_bundle(b["id"]))
	btn.set_meta("price", int(b["price"]))
	col.add_child(btn)
	row.add_child(col)
	return card


func buy_bundle(id: String) -> bool:
	var b := GameData.bundle(id)
	if b.is_empty() or not CurrencyManager.spend(int(b["price"])):
		VFXManager.toast("Not enough coins")
		return false
	for k in (b["grant"] as Dictionary).keys():
		BoosterManager.grant(k, int(b["grant"][k]), false)
	SaveManager.save_game()
	AudioManager.play("reward")
	VFXManager.toast("%s added" % b["name"])
	return true


func _lives_card() -> Control:
	var card := _card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	row.add_child(UIKit.disk("heart", 110, UIKit.HEART, UIKit.DANGER_EDGE))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label("Refill lives", 42, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT))
	col.add_child(UIKit.label("Back to %d lives right away" % LivesManager.max_lives(), 30, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, false))
	row.add_child(col)
	var btn := UIKit.button(str(LivesManager.refill_price()), "gold", "coin", 36, Vector2(230, 120))
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func() -> void:
		if LivesManager.is_full():
			VFXManager.toast("Lives are already full")
		elif LivesManager.buy_refill():
			AudioManager.play("heart")
			VFXManager.toast("Lives refilled!")
		else:
			VFXManager.toast("Not enough coins"))
	row.add_child(btn)
	return card


func _cosmetic_card(item: Dictionary) -> Control:
	var card := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var prev := Control.new()
	prev.custom_minimum_size = Vector2(0, 190)
	prev.clip_contents = true
	prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(prev)
	match String(item["category"]):
		"jar":
			prev.draw.connect(func() -> void:
				CandyArt.draw_mini_jar(prev, Vector2(prev.size.x * 0.5, prev.size.y - 8), 60, [7, 7, 7, 7], 7, Color.html(String(item["glass"])), Color.html(String(item["rim"]))))
		"wrapper":
			prev.draw.connect(func() -> void:
				CandyArt.draw_candy(prev, prev.size * 0.5 + Vector2(-62, 14), 120, 2, String(item["style"]))
				CandyArt.draw_candy(prev, prev.size * 0.5 + Vector2(62, -14), 120, 11, String(item["style"])))
		"theme":
			var bd := ShopBackdrop.new()
			bd.theme_id = item["id"]
			bd.wainscot = 0.6
			bd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			prev.add_child(bd)
	var name_l := UIKit.label(item["name"], 28, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size = Vector2(0, 76)
	v.add_child(name_l)
	var btn := UIKit.button("", "gold", "", 32, Vector2(0, 100))
	btn.pressed.connect(func() -> void: press_cosmetic(item["id"]))
	v.add_child(btn)
	cosmetic_buttons[item["id"]] = btn
	return card


func press_cosmetic(id: String) -> void:
	var item := GameData.cosmetic(id)
	if ProgressionManager.is_owned(id):
		ProgressionManager.select_cosmetic(id)
		AudioManager.play("success")
	elif CurrencyManager.can_afford(int(item["price"])):
		Popups.confirm("Buy %s?" % item["name"], "%d coins" % int(item["price"]), "Buy", func() -> void:
			if ProgressionManager.buy_cosmetic(id):
				AudioManager.play("reward")
				VFXManager.toast("%s unlocked!" % item["name"])
				_refresh_buttons()
				changed.emit())
		return
	else:
		VFXManager.toast("Not enough coins")
	_refresh_buttons()
	changed.emit()


func _refresh_buttons() -> void:
	if daily_button:
		var avail := daily_available()
		daily_button.set_label("Watch" if avail else "Tomorrow")
		daily_button.set_kind("secondary" if avail else "neutral")
	for id in cosmetic_buttons.keys():
		var b: GameButton = cosmetic_buttons[id]
		var item := GameData.cosmetic(id)
		var sel: bool = ProgressionManager.selected_cosmetic(String(item["category"])) == String(id)
		if sel:
			b.set_label("Selected")
			b.set_kind("secondary")
		elif ProgressionManager.is_owned(id):
			b.set_label("Select")
			b.set_kind("neutral")
		else:
			b.set_label("%d" % int(item["price"]))
			b.set_kind("gold" if CurrencyManager.can_afford(int(item["price"])) else "neutral")
