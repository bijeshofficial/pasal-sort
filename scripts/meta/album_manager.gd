extends Node
## The Pasal Album: 8 sets x 9 stickers with 1-3 star rarity. Packs (from
## chests, events, the calendar and the sticker shop) give 3 stickers;
## duplicates turn into sticker stars that buy more packs. A finished set
## pays its reward once.
##   game.album = {owned: {sticker_id: count}, stars: n, sets_claimed: [ids], new: [ids]}

signal changed
signal set_completed(set_id: String)

const ALBUM := "res://data/album.json"


static func save_defaults() -> Dictionary:
	return {"owned": {}, "stars": 0, "sets_claimed": [], "new": []}


static func migrate_block(block: Dictionary, _from_version: int) -> Dictionary:
	return block


func data() -> Dictionary:
	return GameData.load_json(ALBUM)


func block() -> Dictionary:
	var g := SaveManager.game()
	if typeof(g.get("album")) != TYPE_DICTIONARY:
		g["album"] = save_defaults()
	return g["album"]


func sets() -> Array:
	return data().get("sets", [])


func sticker(id: String) -> Dictionary:
	for s in sets():
		for st in s["stickers"]:
			if st["id"] == id:
				var out: Dictionary = (st as Dictionary).duplicate()
				out["set"] = s["id"]
				out["color"] = s["color"]
				return out
	return {}


func count(id: String) -> int:
	return int(block()["owned"].get(id, 0))


func owns(id: String) -> bool:
	return count(id) > 0


func unique_count() -> int:
	var n := 0
	for k in block()["owned"]:
		if int(block()["owned"][k]) > 0:
			n += 1
	return n


func set_progress(set_id: String) -> int:
	var n := 0
	for s in sets():
		if s["id"] == set_id:
			for st in s["stickers"]:
				if owns(st["id"]):
					n += 1
	return n


func is_set_complete(set_id: String) -> bool:
	return set_progress(set_id) >= 9


func can_claim_set(set_id: String) -> bool:
	return is_set_complete(set_id) and not (block()["sets_claimed"] as Array).has(set_id)


func claim_set(set_id: String) -> Dictionary:
	if not can_claim_set(set_id):
		return {}
	(block()["sets_claimed"] as Array).append(set_id)
	SaveManager.add_game_stat("sets_completed")
	for s in sets():
		if s["id"] == set_id:
			var r: Dictionary = (s.get("reward", {"coins": 300}) as Dictionary).duplicate(true)
			Rewards.grant(r, "album_set")
			SaveManager.save_game()
			changed.emit()
			return r
	return {}


func claimable_sets() -> int:
	var n := 0
	for s in sets():
		if can_claim_set(s["id"]):
			n += 1
	return n


func sticker_stars() -> int:
	return int(block().get("stars", 0))


## Draws `n` stickers (weighted by rarity; `min_rarity` for gold packs) and
## adds them. Duplicates add sticker stars. Returns the sticker dictionaries
## (with "duplicate": bool).
func open_pack(source: String = "", n: int = -1, min_rarity: int = 1) -> Array:
	if n < 0:
		n = int(data().get("pack_size", 3))
	var weights: Array = data().get("rarity_weights", [70, 24, 6])
	var dup_stars: Array = data().get("duplicate_stars", [1, 2, 3])
	var out: Array = []
	for k in n:
		var rarity := _roll_rarity(weights, min_rarity if k == 0 else 1)
		var pool: Array = []
		for s in sets():
			for st in s["stickers"]:
				if int(st["rarity"]) == rarity:
					pool.append(st["id"])
		var id: String = pool[randi() % pool.size()]
		var dup := owns(id)
		var owned: Dictionary = block()["owned"]
		owned[id] = count(id) + 1
		if dup:
			block()["stars"] = sticker_stars() + int(dup_stars[clampi(rarity - 1, 0, 2)])
		else:
			(block()["new"] as Array).append(id)
		var info := sticker(id)
		info["duplicate"] = dup
		out.append(info)
		for s in sets():
			if s["id"] == info["set"] and is_set_complete(s["id"]) and not dup:
				set_completed.emit(s["id"])
	SaveManager.set_game_stat("stickers_unique", unique_count())
	GameManager.emit_event("sticker", n)
	SaveManager.save_game()
	changed.emit()
	return out


func _roll_rarity(weights: Array, min_rarity: int) -> int:
	var total := 0
	for i in range(min_rarity - 1, weights.size()):
		total += int(weights[i])
	var r := randi() % maxi(1, total)
	for i in range(min_rarity - 1, weights.size()):
		r -= int(weights[i])
		if r < 0:
			return i + 1
	return weights.size()


## The sticker shop: packs for sticker stars. Returns the stickers or [].
func buy_with_stars(pack_id: String) -> Array:
	for p in data().get("shop", []):
		if p["id"] == pack_id:
			var cost := int(p["stars"])
			if sticker_stars() < cost:
				return []
			block()["stars"] = sticker_stars() - cost
			return open_pack("sticker_shop", int(p.get("stickers", 3)), int(p.get("min_rarity", 1)))
	return []


func coin_pack_price() -> int:
	return int(data().get("coin_pack_price", 300))


func buy_with_coins() -> Array:
	if not CurrencyManager.spend(coin_pack_price()):
		return []
	return open_pack("shop_coins")


func has_new() -> bool:
	return not (block().get("new", []) as Array).is_empty()


func mark_seen() -> void:
	block()["new"] = []
	changed.emit()
