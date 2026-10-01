class_name Rewards
extends RefCounted
## Grants a reward bundle from data and describes it for the UI.
## Bundle keys: coins, stars, lives, unlimited_lives_min, boosters {id: n},
## sticker_packs, event_currency. Other systems register extra keys by
## listening to `granted` (e.g. the sticker album).

## Applies the bundle. Returns display items: [{icon, text, color, key}].
static func grant(bundle: Dictionary, source: String = "") -> Array:
	var items: Array = []
	var coins := int(bundle.get("coins", 0))
	if coins > 0:
		CurrencyManager.add_coins(coins, false)
		items.append({"icon": "coin", "text": "+%d" % coins, "color": UIKit.GOLD, "key": "coins"})
	var stars := int(bundle.get("stars", 0))
	if stars > 0:
		CurrencyManager.add_stars(stars, false)
		items.append({"icon": "star", "text": "+%d" % stars, "color": UIKit.GOLD, "key": "stars"})
	var lives := int(bundle.get("lives", 0))
	if lives > 0:
		LivesManager.add_lives(lives)
		items.append({"icon": "heart", "text": "+%d" % lives, "color": UIKit.HEART, "key": "lives"})
	var unlimited := int(bundle.get("unlimited_lives_min", 0))
	if unlimited > 0:
		LivesManager.add_unlimited(unlimited * 60)
		items.append({"icon": "infinity", "text": "%d min" % unlimited, "color": UIKit.HEART, "key": "unlimited"})
	var boosters: Dictionary = bundle.get("boosters", {})
	for id in boosters:
		var n := int(boosters[id])
		if n > 0:
			BoosterManager.grant(String(id), n, false)
			items.append({"icon": BoosterManager.icon_for(String(id)), "text": "+%d" % n, "color": UIKit.SECONDARY, "key": "booster_" + String(id)})
	if Engine.get_main_loop().root.has_node("AlbumManager"):
		var album: Node = Engine.get_main_loop().root.get_node("AlbumManager")
		var packs := int(bundle.get("sticker_packs", 0))
		for k in packs:
			for s in album.open_pack(source):
				items.append({"icon": "sticker", "text": String(s["name"]), "color": UIKit.PINK, "key": "sticker", "sticker": s})
	if Engine.get_main_loop().root.has_node("EventManager"):
		var ev := int(bundle.get("event_currency", 0))
		if ev > 0:
			var em: Node = Engine.get_main_loop().root.get_node("EventManager")
			em.add_currency(ev)
			items.append({"icon": em.currency_icon(), "text": "+%d" % ev, "color": UIKit.PURPLE, "key": "event"})
	SaveManager.save_game()
	if Engine.get_main_loop().root.has_node("AnalyticsManager"):
		Engine.get_main_loop().root.get_node("AnalyticsManager").log_event("reward_granted", {"source": source, "items": items.size()})
	return items


## One-line summary: "+300 coins, +2 Undo".
static func describe(bundle: Dictionary) -> String:
	var parts: PackedStringArray = []
	if int(bundle.get("coins", 0)) > 0:
		parts.append(UIKit.t("+%d coins") % int(bundle["coins"]))
	if int(bundle.get("stars", 0)) > 0:
		parts.append(UIKit.t("+%d stars") % int(bundle["stars"]))
	if int(bundle.get("lives", 0)) > 0:
		parts.append(UIKit.t("+%d lives") % int(bundle["lives"]))
	if int(bundle.get("unlimited_lives_min", 0)) > 0:
		parts.append(UIKit.t("%d min unlimited lives") % int(bundle["unlimited_lives_min"]))
	var b: Dictionary = bundle.get("boosters", {})
	for id in b:
		parts.append("+%d %s" % [int(b[id]), BoosterManager.display_name(String(id))])
	if int(bundle.get("sticker_packs", 0)) > 0:
		parts.append(UIKit.t("%d sticker packs") % int(bundle["sticker_packs"]) if int(bundle["sticker_packs"]) > 1 else UIKit.t("1 sticker pack"))
	return ", ".join(parts)
