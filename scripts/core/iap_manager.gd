extends Node
## Mock in-app purchases. Never talks to a real store: buy() shows a
## "TEST PURCHASE" confirmation and grants the product on confirm. A real
## store adapter would replace only buy()'s body.

signal purchased(product_id: String)

## Tests skip the confirmation popup.
var auto_confirm := false


func product(product_id: String) -> Dictionary:
	return GameData.coin_pack(product_id)


func buy(product_id: String, on_done: Callable) -> void:
	var p := product(product_id)
	if p.is_empty():
		on_done.call(false)
		return
	if auto_confirm:
		_finish(product_id, true, on_done)
		return
	var popup := GamePopup.create({
		"title": "TEST PURCHASE",
		"art": "coin_pile",
		"body": "%s: %d coins\n%s (test only, nothing is charged)" % [p["name"], int(p["coins"]), p.get("price_label", "")],
		"buttons": [
			{"text": "Cancel", "kind": "neutral", "cb": func() -> void: _finish(product_id, false, on_done)},
			{"text": "Confirm", "kind": "primary", "cb": func() -> void: _finish(product_id, true, on_done)},
		],
		"on_back": func() -> void: _finish(product_id, false, on_done),
	})
	ScreenManager.push_modal(popup)


func _finish(product_id: String, ok: bool, on_done: Callable) -> void:
	if ok:
		grant(product_id)
	on_done.call(ok)


func grant(product_id: String) -> void:
	var p := product(product_id)
	if p.is_empty():
		return
	CurrencyManager.add_coins(int(p["coins"]))
	purchased.emit(product_id)
