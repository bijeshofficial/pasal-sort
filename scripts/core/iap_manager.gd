extends Node
## Mock in-app purchases. Never talks to a real store: buy() shows a
## "TEST PURCHASE" confirmation and grants the product on confirm. Products
## live in data/iap_products.json. A real store adapter replaces only
## _store_purchase() / restore_purchases(); gameplay never knows which
## store exists.
##   game.purchases = {no_ads, starter_pack, bought: [ids]}

signal purchased(product_id: String)
signal no_ads_changed(on: bool)

## Tests skip the confirmation popup.
var auto_confirm := false
## At most one offer popup per session (never during a level).
var offer_shown_this_session := false


static func save_defaults() -> Dictionary:
	return {"no_ads": false, "starter_pack": false, "bought": []}


static func migrate_block(block: Dictionary, _from_version: int) -> Dictionary:
	return block


func block() -> Dictionary:
	var g := SaveManager.game()
	if typeof(g.get("purchases")) != TYPE_DICTIONARY:
		g["purchases"] = save_defaults()
	return g["purchases"]


func product(product_id: String) -> Dictionary:
	return GameData.iap_product(product_id)


func has_no_ads() -> bool:
	return bool(block().get("no_ads", false))


func is_bought(product_id: String) -> bool:
	return (block().get("bought", []) as Array).has(product_id)


## One-time products disappear once bought; the starter pack also waits
## for its level.
func is_available(product_id: String) -> bool:
	var p := product(product_id)
	if p.is_empty():
		return false
	if bool(p.get("one_time", false)) and is_bought(product_id):
		return false
	if ProgressionManager.highest_completed() < int(p.get("show_after_level", 0)):
		return false
	return true


func buy(product_id: String, on_done: Callable) -> void:
	var p := product(product_id)
	if p.is_empty() or not is_available(product_id):
		on_done.call(false)
		return
	if auto_confirm:
		_finish(product_id, true, on_done)
		return
	var body := "%s\n%s\n%s" % [tr(String(p.get("name", ""))), _describe(p), tr("%s (test only, nothing is charged)") % String(p.get("price_label", ""))]
	var popup := GamePopup.create({
		"title": "TEST PURCHASE",
		"art": String(p.get("icon", "coin_pile")),
		"body": body,
		"buttons": [
			{"text": tr("Cancel"), "kind": "neutral", "cb": func() -> void: _finish(product_id, false, on_done)},
			{"text": tr("Confirm"), "kind": "primary", "cb": func() -> void: _finish(product_id, true, on_done)},
		],
		"on_back": func() -> void: _finish(product_id, false, on_done),
	})
	ScreenManager.push_modal(popup)


func _describe(p: Dictionary) -> String:
	var c: Dictionary = p.get("contents", {})
	var text := Rewards.describe(c)
	if bool(c.get("no_ads", false)):
		text = tr("No more ad breaks between levels") + ("" if text == "" else ", " + text)
	return text


func _finish(product_id: String, ok: bool, on_done: Callable) -> void:
	if ok:
		grant(product_id)
	if Engine.get_main_loop().root.has_node("AnalyticsManager"):
		Engine.get_main_loop().root.get_node("AnalyticsManager").log_event("purchase_mock", {"product": product_id, "ok": ok})
	on_done.call(ok)


## Applies a product's contents (also used by restore and tests).
func grant(product_id: String) -> Array:
	var p := product(product_id)
	if p.is_empty():
		return []
	var c: Dictionary = (p.get("contents", {}) as Dictionary).duplicate(true)
	var bought: Array = block()["bought"]
	if not bought.has(product_id):
		bought.append(product_id)
	if product_id == "starter_pack":
		block()["starter_pack"] = true
	if bool(c.get("no_ads", false)):
		block()["no_ads"] = true
		no_ads_changed.emit(true)
	c.erase("no_ads")
	var items := Rewards.grant(c, "iap_" + product_id)
	SaveManager.save_game()
	purchased.emit(product_id)
	return items


## The product to offer right now on Home, or "" (one per session).
func pending_offer() -> String:
	if offer_shown_this_session:
		return ""
	if is_available("starter_pack"):
		return "starter_pack"
	return ""


func mark_offer_shown() -> void:
	offer_shown_this_session = true


## Store stub: a real adapter would ask the store for owned non-consumables.
func restore_purchases(on_done: Callable = Callable()) -> void:
	if has_no_ads():
		no_ads_changed.emit(true)
	if on_done.is_valid():
		on_done.call(true)
