extends Node
## Weekly events (offline): data/events.json rotates one event per week
## (Monday 00:00 local). Wins drop the event's currency; 15 milestones pay a
## free reward and, with the mock Event Pass, a premium one. A new week
## starts a new event with fresh progress.
##   game.events = {week, event_id, currency, claimed_free: [i], claimed_pass: [i], pass}

signal changed

const EVENTS := "res://data/events.json"


static func save_defaults() -> Dictionary:
	return {"week": -1, "event_id": "", "currency": 0, "claimed_free": [], "claimed_pass": [], "pass": false}


static func migrate_block(block: Dictionary, _from_version: int) -> Dictionary:
	return block


func _ready() -> void:
	SaveManager.loaded.connect(roll)
	TimeManager.day_changed.connect(func(_d: String) -> void: roll())
	roll.call_deferred()


func data() -> Dictionary:
	return GameData.load_json(EVENTS)


func block() -> Dictionary:
	var g := SaveManager.game()
	if typeof(g.get("events")) != TYPE_DICTIONARY:
		g["events"] = save_defaults()
	return g["events"]


## Starts this week's event when the week changes (never backwards).
func roll() -> void:
	if SaveManager.data.is_empty():
		return
	var week := TimeManager.week_number()
	var b := block()
	if week == int(b.get("week", -1)):
		return
	if week < int(b.get("week", -1)) and TimeManager.clock_rewound():
		return
	var list: Array = data().get("events", [])
	if list.is_empty():
		return
	var ev: Dictionary = list[posmod(week, list.size())]
	b["week"] = week
	b["event_id"] = ev["id"]
	b["currency"] = 0
	b["claimed_free"] = []
	b["claimed_pass"] = []
	b["pass"] = false
	SaveManager.save_game()
	changed.emit()


func current() -> Dictionary:
	roll()
	for ev in data().get("events", []):
		if ev["id"] == block().get("event_id", ""):
			return ev
	return {}


func is_active() -> bool:
	return not current().is_empty()


func currency() -> int:
	return int(block().get("currency", 0))


func currency_icon() -> String:
	return String(current().get("icon", "star"))


func currency_name() -> String:
	return tr(String(current().get("currency", "tokens")))


func add_currency(n: int) -> void:
	if n <= 0 or not is_active():
		return
	block()["currency"] = currency() + n
	changed.emit()


## Currency a won level drops (by tier). Added immediately; returns it.
func on_win(tier: String) -> int:
	if not is_active():
		return 0
	var d := data()
	var n := int(d.get("per_win", 1))
	if tier == "hard":
		n += int(d.get("hard_bonus", 1))
	elif tier == "super":
		n += int(d.get("super_bonus", 2))
	add_currency(n)
	SaveManager.save_game()
	return n


func track() -> Array:
	return current().get("track", [])


func milestone_reached(i: int) -> bool:
	var t := track()
	return i >= 0 and i < t.size() and currency() >= int(t[i]["target"])


func has_pass() -> bool:
	return bool(block().get("pass", false))


func buy_pass() -> void:
	block()["pass"] = true
	SaveManager.save_game()
	changed.emit()


func can_claim(i: int, premium: bool) -> bool:
	if not milestone_reached(i) or TimeManager.clock_rewound():
		return false
	if premium and not has_pass():
		return false
	var list: Array = block()["claimed_pass" if premium else "claimed_free"]
	return not list.has(i)


func claim(i: int, premium: bool) -> Dictionary:
	if not can_claim(i, premium):
		return {}
	(block()["claimed_pass" if premium else "claimed_free"] as Array).append(i)
	SaveManager.add_game_stat("event_milestones")
	var r: Dictionary = (track()[i]["pass" if premium else "free"] as Dictionary).duplicate(true)
	Rewards.grant(r, "event_" + String(current().get("id", "")))
	SaveManager.save_game()
	changed.emit()
	return r


func claimable_count() -> int:
	var n := 0
	for i in track().size():
		if can_claim(i, false):
			n += 1
		if can_claim(i, true):
			n += 1
	return n


func next_target() -> int:
	for m in track():
		if currency() < int(m["target"]):
			return int(m["target"])
	return 0
