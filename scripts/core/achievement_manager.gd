extends Node
## Achievements with tiers (I, II, III...). Progress comes from saved stats;
## each tier's reward is claimed by hand, then the next tier opens.
##   game.achievements[id] = {"tier": tiers claimed, "progress": cached}

signal claimable_changed(count: int)
signal claimed(id: String)

const ROMAN := ["I", "II", "III", "IV", "V"]

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
	if typeof(all.get(id)) != TYPE_DICTIONARY:
		all[id] = {"tier": 0, "progress": 0}
	var e: Dictionary = all[id]
	if not e.has("tier"):
		# Saves from before tiers: a claimed achievement = its first tier.
		e["tier"] = 1 if bool(e.get("claimed", false)) else 0
	return e


func tiers(id: String) -> Array:
	return definition(id).get("tiers", [])


func tier_count(id: String) -> int:
	return tiers(id).size()


## Tiers already claimed.
func tier(id: String) -> int:
	return clampi(int(_entry(id).get("tier", 0)), 0, tier_count(id))


func raw_progress(id: String) -> int:
	var a := definition(id)
	match String(a.get("stat", "")):
		"highest_level":
			return ProgressionManager.highest_completed()
		"cosmetics_owned":
			return ProgressionManager.owned_cosmetic_count()
		"total_coins_earned":
			return SaveManager.stat("total_coins_earned")
		"play_hours":
			return SaveManager.stat("play_time_sec") / 3600
		"best_dami":
			return int(SaveManager.game().get("streaks", {}).get("best_dami", 0))
		"trunks_opened":
			return int(SaveManager.game().get("streaks", {}).get("trunks_opened", 0))
		"":
			return 0
		var key:
			return SaveManager.game_stat(key)


## Target of the tier being worked on (the last one once all are claimed).
func target(id: String) -> int:
	var t := tiers(id)
	if t.is_empty():
		return 1
	return int(t[mini(tier(id), t.size() - 1)]["target"])


func progress(id: String) -> int:
	return mini(raw_progress(id), target(id))


## The current tier's target is reached (or every tier is done).
func is_complete(id: String) -> bool:
	return raw_progress(id) >= target(id)


## Every tier claimed.
func is_claimed(id: String) -> bool:
	return tier(id) >= tier_count(id)


func can_claim(id: String) -> bool:
	return not is_claimed(id) and raw_progress(id) >= target(id)


func claimable_count() -> int:
	var n := 0
	for a in definitions():
		if can_claim(a["id"]):
			n += 1
	return n


## "Jar Filler II" for the tier being worked on.
func title(id: String) -> String:
	var a := definition(id)
	var t := tr(String(a.get("title", id)))
	if tier_count(id) > 1:
		t += " " + ROMAN[mini(tier(id), tier_count(id) - 1)]
	return t


func description(id: String) -> String:
	return tr(String(definition(id).get("desc", ""))).replace("{n}", _num(target(id)))


func current_reward(id: String) -> Dictionary:
	var t := tiers(id)
	if t.is_empty():
		return {}
	return t[mini(tier(id), t.size() - 1)].get("reward", {})


static func _num(n: int) -> String:
	var s := str(n)
	if n < 1000:
		return s
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out


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


## Grants the current tier's reward. Returns it or {} if not claimable.
func claim(id: String) -> Dictionary:
	if not can_claim(id):
		return {}
	var reward := current_reward(id).duplicate(true)
	_entry(id)["tier"] = tier(id) + 1
	Rewards.grant(reward, "achievement_" + id)
	SaveManager.save_game()
	claimed.emit(id)
	refresh()
	return reward


static func reward_text(reward: Dictionary) -> String:
	return Rewards.describe(reward)
