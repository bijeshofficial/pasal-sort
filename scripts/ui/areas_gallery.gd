class_name AreasGallery
extends RefCounted
## Every area as a card: finished ones can be visited, the current one shows
## its progress, later ones are locked.


static func open(home: HomePage) -> GamePopup:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(home.get_viewport_rect().size.y * 0.55, 1100))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.add_child(list)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var popup: GamePopup
	var current := RenovationManager.current_area()
	for i in range(1, RenovationManager.area_count() + 1):
		var done := RenovationManager.is_area_complete(i)
		var locked := i > current
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UIKit.card_box(Color.WHITE if not locked else Color("ece8f8"), 18, UIKit.LINE))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		card.add_child(row)
		var num := UIKit.disk("check" if done else ("lock" if locked else "home"), 110, UIKit.PRIMARY if done else (UIKit.DISABLED if locked else UIKit.GOLD), (UIKit.PRIMARY_EDGE if done else (UIKit.DISABLED_EDGE if locked else UIKit.GOLD_EDGE)))
		row.add_child(num)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_child(UIKit.label("%d. %s" % [i, UIKit.t(RenovationManager.area_name(i))], 40, UIKit.INK if not locked else UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT))
		var sub := UIKit.t("Restored") if done else (UIKit.t("Locked") if locked else UIKit.t("%d of %d tasks") % [RenovationManager.done_count(i), RenovationManager.total_count(i)])
		tv.add_child(UIKit.label(sub, 30, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, false))
		row.add_child(tv)
		if not locked:
			var b := UIKit.button(UIKit.t("Visit") if i != current else UIKit.t("Here"), "secondary" if i != current else "neutral", "", 36, Vector2(170, 110))
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.disabled = i == current and home.visiting < 0
			b.pressed.connect(func() -> void:
				Popups.close_id("areas")
				home.visit_area(i))
			row.add_child(b)
		list.add_child(card)
	popup = Popups.show({
		"id": "areas",
		"title": UIKit.t("Areas"),
		"content": scroll,
		"closable": true,
		"width": 940,
	})
	return popup
