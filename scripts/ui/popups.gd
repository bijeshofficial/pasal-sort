class_name Popups
extends RefCounted
## Builders for the standard popups, all using GamePopup.


static func show(spec: Dictionary) -> GamePopup:
	var p := GamePopup.create(spec)
	ScreenManager.push_modal(p)
	return p


## Closes an open popup by its id. (Button callbacks can't hold the popup
## variable itself: lambdas capture locals by value when they are created,
## before Popups.show() has returned it.)
static func close_id(id: String) -> void:
	var m := ScreenManager.find_modal(id)
	if m:
		ScreenManager.close_modal(m)


static func confirm(title: String, body: String, yes_text: String, on_yes: Callable, yes_kind: String = "primary", no_text: String = "Cancel") -> GamePopup:
	return show({
		"id": "confirm",
		"title": title,
		"body": body,
		"buttons": [
			{"id": "no", "text": no_text, "kind": "neutral"},
			{"id": "yes", "text": yes_text, "kind": yes_kind, "cb": on_yes},
		],
	})


static func reward(title: String, body: String, icon: String = "coin_pile", on_close: Callable = Callable()) -> GamePopup:
	AudioManager.play("reward")
	HapticsManager.medium()
	return show({
		"id": "reward",
		"title": title,
		"art": icon,
		"body": body,
		"body_size": 52,
		"buttons": [{"id": "ok", "text": "Nice!", "kind": "primary", "icon": "check", "cb": on_close}],
		"on_back": on_close,
	})


## Lives popup: count, countdown, refill for coins, +1 via rewarded ad.
static func lives(out_of_lives: bool = false, on_refilled: Callable = Callable()) -> GamePopup:
	var full := LivesManager.is_full()
	var body := "Lives are full. Go sort some candies!" if full else "Next life in %s" % LivesManager.countdown_text()
	if out_of_lives:
		body = "You're out of lives.\nNext life in %s" % LivesManager.countdown_text()
	var price := LivesManager.refill_price()
	var p := show({
		"id": "out_of_lives" if out_of_lives else "lives",
		"title": "Out of lives" if out_of_lives else "Lives: %d / %d" % [LivesManager.lives(), LivesManager.max_lives()],
		"art": "heart",
		"art_color": UIKit.HEART,
		"body": body,
		"closable": true,
		"vertical": true,
		"buttons": [
			{"id": "refill", "text": "Refill all  %d" % price, "kind": "gold", "icon": "coin", "disabled": full or not CurrencyManager.can_afford(price), "close": false, "cb": func() -> void:
				if LivesManager.buy_refill():
					AudioManager.play("heart")
					VFXManager.toast("Lives refilled!")
					ScreenManager.close_modal(ScreenManager.find_modal("out_of_lives" if out_of_lives else "lives"))
					if on_refilled.is_valid():
						on_refilled.call()
				else:
					VFXManager.toast("Not enough coins")},
			{"id": "ad", "text": "+1 life  (Watch ad)", "kind": "secondary", "icon": "ad", "disabled": full, "close": false, "cb": func() -> void:
				AdManager.show_rewarded("life", func(ok: bool) -> void:
					if ok:
						LivesManager.add_lives(1)
						AudioManager.play("heart")
						VFXManager.toast("+1 life")
						ScreenManager.close_modal(ScreenManager.find_modal("out_of_lives" if out_of_lives else "lives"))
						if on_refilled.is_valid():
							on_refilled.call()
					else:
						VFXManager.toast("Ad not available right now"))},
			{"id": "wait", "text": "Wait", "kind": "neutral"},
		],
	})
	# Keep the countdown ticking while the popup is open.
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	p.add_child(t)
	t.timeout.connect(func() -> void:
		if p.body_label:
			if LivesManager.is_full():
				p.body_label.text = "Lives are full. Go sort some candies!"
			else:
				p.body_label.text = ("You're out of lives.\n" if out_of_lives else "") + "Next life in %s" % LivesManager.countdown_text())
	return p


## Booster at zero: buy with coins or watch an ad for one.
static func buy_booster(id: String, on_got: Callable = Callable()) -> GamePopup:
	var price := BoosterManager.price(id)
	var icon: String = BoosterManager.icon_for(id)
	var desc: String = BoosterManager.description(id)
	return show({
		"id": "buy_booster",
		"title": BoosterManager.display_name(id),
		"art": icon,
		"art_color": UIKit.SECONDARY,
		"body": desc,
		"closable": true,
		"vertical": true,
		"buttons": [
			{"id": "buy", "text": "Buy 1  %d" % price, "kind": "gold", "icon": "coin", "disabled": not CurrencyManager.can_afford(price), "cb": func() -> void:
				if BoosterManager.buy(id):
					AudioManager.play("coin_pickup")
					if on_got.is_valid():
						on_got.call()},
			{"id": "ad", "text": "Get 1 free  (Watch ad)", "kind": "secondary", "icon": "ad", "cb": func() -> void:
				AdManager.show_rewarded("booster_" + id, func(ok: bool) -> void:
					if ok:
						BoosterManager.grant(id, 1)
						VFXManager.toast("+1 %s" % BoosterManager.display_name(id))
						if on_got.is_valid():
							on_got.call()
					else:
						VFXManager.toast("Ad not available right now"))},
		],
	})
