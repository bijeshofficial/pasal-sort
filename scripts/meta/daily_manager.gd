extends Node
## Things to do every day (offline, device clock, local midnight):
##   calendar  - 7-day reward cycle; a missed day just waits.
##   missions  - 3 a day from a pool, picked by the date. Each pays coins
##               and points; points fill the mission chest.
##   challenge - one puzzle per day seeded by the date; its own streak and a
##               calendar of completed days. Free to play, no lives.
## Nothing is granted while the clock is behind the latest time seen.
##   game.daily = {cal_index, cal_last_day, mission_day, missions: [{id,
##                 progress, claimed}], points, chest_claimed, challenge:
##                 {done: [dates], streak, best, last_day}}

signal changed

const DAILY := "res://data/daily.json"

var _challenge_cache: Dictionary = {}   # day number -> level
var _challenge_task := -1
var _challenge_day := -1
var _mutex := Mutex.new()
var _pending: Dictionary = {}


static func save_defaults() -> Dictionary:
	return {"cal_index": 0, "cal_last_day": -1, "mission_day": -1, "missions": [], "points": 0, "chest_claimed": false,
		"challenge": {"done": [], "streak": 0, "best": 0, "last_day": -1}}


static func migrate_block(block: Dictionary, _from_version: int) -> Dictionary:
	return block


func _ready() -> void:
	GameManager.game_event.connect(_on_event)
	TimeManager.day_changed.connect(func(_d: String) -> void:
		roll()
		changed.emit())
	SaveManager.loaded.connect(roll)
	roll.call_deferred()


func _exit_tree() -> void:
	if _challenge_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_challenge_task)
		_challenge_task = -1


func data() -> Dictionary:
	return GameData.load_json(DAILY)


func block() -> Dictionary:
	var g := SaveManager.game()
	if typeof(g.get("daily")) != TYPE_DICTIONARY:
		g["daily"] = save_defaults()
	return g["daily"]


func today_num() -> int:
	return TimeManager.day_number()


func blocked() -> bool:
	return TimeManager.clock_rewound()


# --- Calendar ----------------------------------------------------------------

func calendar() -> Array:
	return data().get("calendar", [])


func calendar_index() -> int:
	return posmod(int(block().get("cal_index", 0)), maxi(1, calendar().size()))


func can_claim_calendar() -> bool:
	return not blocked() and today_num() > int(block().get("cal_last_day", -1))


## Claims today's calendar reward. Returns display items or [] if not now.
func claim_calendar() -> Array:
	if not can_claim_calendar():
		return []
	var b := block()
	var idx := calendar_index()
	var reward: Dictionary = calendar()[idx]
	b["cal_index"] = (idx + 1) % calendar().size()
	b["cal_last_day"] = today_num()
	SaveManager.add_game_stat("daily_claims")
	var items := Rewards.grant(reward, "daily_calendar")
	GameManager.emit_event("daily_claim")
	_log("daily_claim", {"day": idx + 1})
	changed.emit()
	return items


# --- Missions ----------------------------------------------------------------

## New missions (and an empty chest) at the start of each day.
func roll() -> void:
	if SaveManager.data.is_empty():
		return
	var b := block()
	var day := today_num()
	if int(b.get("seen_day", -1)) < day and not blocked():
		b["seen_day"] = day
		SaveManager.add_game_stat("days_played")
	if int(b.get("mission_day", -1)) == day and not (b.get("missions", []) as Array).is_empty():
		return
	if blocked() and int(b.get("mission_day", -1)) > day:
		return
	b["mission_day"] = day
	b["points"] = 0
	b["chest_claimed"] = false
	var list: Array = []
	for m in pick_missions(day):
		list.append({"id": m["id"], "progress": 0, "claimed": false})
	b["missions"] = list
	SaveManager.save_game()


## The day's missions: a date-seeded shuffle of the pool, one per event type.
func pick_missions(day: int) -> Array:
	var pool: Array = (data().get("missions", []) as Array).duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 2654435761 % 4294967291
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out: Array = []
	var events := {}
	for m in pool:
		if events.has(m["event"]):
			continue
		events[m["event"]] = true
		out.append(m)
		if out.size() >= int(data().get("mission_count", 3)):
			break
	return out


func mission_def(id: String) -> Dictionary:
	for m in data().get("missions", []):
		if m["id"] == id:
			return m
	return {}


func missions() -> Array:
	return block().get("missions", [])


func mission_done(m: Dictionary) -> bool:
	return int(m.get("progress", 0)) >= int(mission_def(String(m["id"])).get("target", 1))


func _on_event(id: String, amount: int) -> void:
	var touched := false
	for m in missions():
		var d := mission_def(String(m["id"]))
		if String(d.get("event", "")) == id and not mission_done(m):
			m["progress"] = mini(int(m.get("progress", 0)) + amount, int(d.get("target", 1)))
			touched = true
	if touched:
		changed.emit()


func can_claim_mission(index: int) -> bool:
	var list := missions()
	return index >= 0 and index < list.size() and mission_done(list[index]) and not bool(list[index].get("claimed", false)) and not blocked()


## Pays a finished mission (coins + points). Returns the coins or -1.
func claim_mission(index: int) -> int:
	if not can_claim_mission(index):
		return -1
	var m: Dictionary = missions()[index]
	var d := mission_def(String(m["id"]))
	m["claimed"] = true
	block()["points"] = int(block().get("points", 0)) + int(d.get("points", 10))
	CurrencyManager.add_coins(int(d.get("coins", 20)), false)
	SaveManager.add_game_stat("missions_completed")
	SaveManager.save_game()
	changed.emit()
	return int(d.get("coins", 20))


func points() -> int:
	return int(block().get("points", 0))


func chest_points() -> int:
	return int(data().get("chest_points", 30))


func can_open_mission_chest() -> bool:
	return points() >= chest_points() and not bool(block().get("chest_claimed", false)) and not blocked()


func claim_mission_chest() -> Dictionary:
	if not can_open_mission_chest():
		return {}
	block()["chest_claimed"] = true
	SaveManager.save_game()
	changed.emit()
	return (data().get("mission_chest", {"coins": 100}) as Dictionary).duplicate(true)


func missions_attention() -> bool:
	if can_open_mission_chest():
		return true
	for i in missions().size():
		if can_claim_mission(i):
			return true
	return false


# --- Daily challenge ---------------------------------------------------------

func challenge_done_today() -> bool:
	return (block()["challenge"]["done"] as Array).has(TimeManager.today())


func challenge_streak() -> int:
	var c: Dictionary = block()["challenge"]
	# A streak only survives if yesterday (or today) was played.
	if int(c.get("last_day", -1)) < today_num() - 1:
		return 0
	return int(c.get("streak", 0))


func challenge_twist(day: int = -1) -> String:
	if day < 0:
		day = today_num()
	var tw: Array = data()["challenge"]["twists_by_weekday"]
	return String(tw[posmod(day - 4, 7)])


func challenge_params(day: int) -> Dictionary:
	var cfg: Dictionary = data()["challenge"]
	var types := int((cfg["types_by_weekday"] as Array)[posmod(day - 4, 7)])
	return {"types": types, "empty": 2, "tier": "hard", "twists": [challenge_twist(day)], "teach": "",
		"candidates": 3, "pick": "max", "seed": (day * 7919 + 31337) % 2147483647}


## Today's puzzle (cached; generated on a worker thread by prefetch).
func challenge_level(day: int = -1) -> Dictionary:
	if day < 0:
		day = today_num()
	if _challenge_cache.has(day):
		return (_challenge_cache[day] as Dictionary).duplicate(true)
	if _challenge_task >= 0 and _challenge_day == day:
		WorkerThreadPool.wait_for_task_completion(_challenge_task)
		_challenge_task = -1
		_collect()
		if _challenge_cache.has(day):
			return (_challenge_cache[day] as Dictionary).duplicate(true)
	var lvl := _build(day)
	_challenge_cache[day] = lvl
	return lvl.duplicate(true)


func prefetch_challenge() -> void:
	var day := today_num()
	if _challenge_cache.has(day) or _challenge_task >= 0:
		return
	_challenge_day = day
	_challenge_task = WorkerThreadPool.add_task(func() -> void:
		var lvl := _build(day)
		_mutex.lock()
		_pending[day] = lvl
		_mutex.unlock())


func _process(_delta: float) -> void:
	if _challenge_task >= 0 and WorkerThreadPool.is_task_completed(_challenge_task):
		WorkerThreadPool.wait_for_task_completion(_challenge_task)
		_challenge_task = -1
		_collect()


func _collect() -> void:
	_mutex.lock()
	for d in _pending:
		_challenge_cache[d] = _pending[d]
	_pending.clear()
	_mutex.unlock()


func _build(day: int) -> Dictionary:
	var lvl := LevelGenerator.build(900000 + day, challenge_params(day))
	lvl["daily"] = true
	lvl["tier"] = "hard"
	return lvl


func challenge_reward() -> int:
	var cfg: Dictionary = data()["challenge"]
	var bonus := mini(int(cfg.get("streak_bonus", 10)) * challenge_streak(), int(cfg.get("streak_bonus_max", 70)))
	return int(cfg.get("coins", 60)) + bonus


## Records today's challenge. Returns {coins, streak} ({} if already done).
func complete_challenge() -> Dictionary:
	if challenge_done_today() or blocked():
		return {}
	var c: Dictionary = block()["challenge"]
	var day := today_num()
	var streak := (challenge_streak() + 1) if int(c.get("last_day", -1)) < day else challenge_streak()
	var coins := challenge_reward()
	(c["done"] as Array).append(TimeManager.today())
	c["streak"] = streak
	c["best"] = maxi(int(c.get("best", 0)), streak)
	c["last_day"] = day
	SaveManager.add_game_stat("daily_challenges")
	CurrencyManager.add_coins(coins, false)
	SaveManager.save_game()
	GameManager.emit_event("challenge")
	changed.emit()
	return {"coins": coins, "streak": streak}


func challenge_history() -> Array:
	return block()["challenge"]["done"]


func _log(event: String, d: Dictionary) -> void:
	if get_tree().root.has_node("AnalyticsManager"):
		get_tree().root.get_node("AnalyticsManager").log_event(event, d)
