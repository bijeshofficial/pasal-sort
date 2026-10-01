extends Node
## Achievements: progress comes from saved stats, rewards are claimed by hand.

signal claimable_changed(count: int)
signal claimed(id: String)

var _last_claimable := -1


func _ready() -> void:
	SaveManager.loaded.connect(refresh)
	SaveManager.progress_reset.connect(refresh)
	refresh.call_deferred()


func definitions() -> Array:
	return GameData.achievements()


func definition(id: String) -> Dictionary:
	for a in definitions():
		if a["id"] == id:
			return a
	return {}


func _entry(id: String) -> Dictionary:
	var all: Dictionary = SaveManager.game()["achievements"]
	if not all.has(id):
		all[id] = {"progress": 0, "claimed": false}
	return all[id]


func raw_progress(id: String) -> int:
	var a := definition(id)
	match String(a.get("stat", "")):
		"highest_level":
			return ProgressionManager.highest_completed()
		"cosmetics_owned":
			return ProgressionManager.owned_cosmetic_count()
		"":
			return 0
		var key:
			return SaveManager.game_stat(key)


func target(id: String) -> int:
	return int(definition(id).get("target", 1))


func progress(id: String) -> int:
	return mini(raw_progress(id), target(id))


func is_complete(id: String) -> bool:
	return raw_progress(id) >= target(id)


func is_claimed(id: String) -> bool:
	return bool(_entry(id).get("claimed", false))


func can_claim(id: String) -> bool:
	return is_complete(id) and not is_claimed(id)


func claimable_count() -> int:
	var n := 0
	for a in definitions():
		if can_claim(a["id"]):
			n += 1
	return n


## Copies live progress into the save and announces claimable changes.
func refresh() -> void:
	if SaveManager.data.is_empty():
		return
	for a in definitions():
		_entry(a["id"])["progress"] = progress(a["id"])
	var n := claimable_count()
	if n != _last_claimable:
		_last_claimable = n
		claimable_changed.emit(n)


## Grants the reward. Returns it ({coins, undo, ...}) or {} if not claimable.
func claim(id: String) -> Dictionary:
	if not can_claim(id):
		return {}
	var reward: Dictionary = definition(id).get("reward", {})
	_entry(id)["claimed"] = true
	for k in reward.keys():
		if k == "coins":
			CurrencyManager.add_coins(int(reward[k]), false)
		else:
			BoosterManager.grant(k, int(reward[k]), false)
	SaveManager.save_game()
	claimed.emit(id)
	refresh()
	return reward


static func reward_text(reward: Dictionary) -> String:
	var parts := PackedStringArray()
	if reward.has("coins"):
		parts.append("%d coins" % int(reward["coins"]))
	for k in ["undo", "extra_jar", "shuffle"]:
		if reward.has(k):
			parts.append("%d %s" % [int(reward[k]), BoosterManager.display_name(k)])
	return " + ".join(parts)
