extends Node
## Levels, background level generation and cosmetics.
##
## Levels are generated on a WorkerThreadPool task and cached in memory.
## prefetch(n) starts one in the background; get_level(n) returns it (or
## generates synchronously if it is not ready, e.g. in tests).

signal level_ready(level: int)
signal cosmetic_changed(category: String, id: String)

const CACHE_LIMIT := 6

## Pre-level boosters picked on the start card for the next level:
## paid ones are consumed when the level starts, free ones come from the
## Dami streak.
var pending_pre: Array = []
var pending_free: Array = []
## "level" or "daily": what the next Gameplay scene plays.
var play_mode := "level"

var _cache: Dictionary = {}     # level -> Dictionary
var _tasks: Dictionary = {}     # level -> WorkerThreadPool task id
var _results: Dictionary = {}   # level -> Dictionary (written by workers)
var _mutex := Mutex.new()


func _ready() -> void:
	GameData.preload_all()


func _exit_tree() -> void:
	for level in _tasks.keys():
		WorkerThreadPool.wait_for_task_completion(_tasks[level])
	_tasks.clear()


func _process(_delta: float) -> void:
	if _tasks.is_empty():
		return
	for level in _tasks.keys():
		if WorkerThreadPool.is_task_completed(_tasks[level]):
			WorkerThreadPool.wait_for_task_completion(_tasks[level])
			_tasks.erase(level)
			_mutex.lock()
			var lvl: Dictionary = _results.get(level, {})
			_results.erase(level)
			_mutex.unlock()
			if not lvl.is_empty():
				_store(level, lvl)
				level_ready.emit(level)


# --- Level progress ----------------------------------------------------------

func current_level() -> int:
	return maxi(1, int(SaveManager.data.get("current_level", 1)))


func highest_completed() -> int:
	return current_level() - 1


func tier_for(level: int) -> String:
	return LevelGenerator.tier_for(level)


func tier_label(tier: String) -> String:
	return String(GameData.difficulty()["tiers"].get(tier, {}).get("label", ""))


func coin_reward(level: int) -> int:
	var tier := tier_for(level)
	var mult := float(GameData.difficulty()["tiers"].get(tier, {}).get("coin_mult", 1.0))
	return int(round(int(GameData.economy()["level_reward"]) * mult))


## Records a win and advances. Every win earns 1 star (renovation) plus
## coins. Returns a summary for the win screen: {coins, stars, tier, milestone}.
func complete_level(level: int, used_boosters: bool) -> Dictionary:
	var tier := tier_for(level)
	var coins := coin_reward(level)
	if level >= current_level():
		SaveManager.data["current_level"] = level + 1
	SaveManager.add_game_stat("levels_completed")
	SaveManager.add_stat("games_played", 1)
	match tier:
		"hard":
			SaveManager.add_game_stat("hard_completed")
		"super":
			SaveManager.add_game_stat("super_completed")
	if used_boosters:
		SaveManager.set_game_stat("no_booster_streak", 0)
	else:
		SaveManager.add_game_stat("no_booster_wins")
		SaveManager.add_game_stat("no_booster_streak")
		SaveManager.set_game_stat("best_no_booster_streak", maxi(SaveManager.game_stat("best_no_booster_streak"), SaveManager.game_stat("no_booster_streak")))
	var milestone := ChestManager.level_chest_due(level)
	var stars := int(GameData.economy().get("stars_per_win", 1))
	SaveManager.game()["in_progress_level"] = null
	CurrencyManager.add_coins(coins, false)
	CurrencyManager.add_stars(stars, false)
	SaveManager.save_game()
	return {"coins": coins, "stars": stars, "tier": tier, "milestone": milestone}


func set_pre_boosters(paid: Array, free: Array) -> void:
	pending_pre = paid.duplicate()
	pending_free = free.duplicate()


## Returns and clears the boosters chosen for the level about to start.
func take_pre_boosters() -> Dictionary:
	var out := {"paid": pending_pre.duplicate(), "free": pending_free.duplicate()}
	pending_pre.clear()
	pending_free.clear()
	return out


## What the player must do: "sort" (default), "orders" (bonus) or "moves".
func goal_for(level: int) -> Dictionary:
	var lvl := get_level(level) if has_level(level) or not is_generating(level) else {}
	if lvl.is_empty():
		return {"type": "sort"}
	if int(lvl.get("move_limit", 0)) > 0:
		return {"type": "moves", "moves": int(lvl["move_limit"])}
	if not (lvl.get("orders", []) as Array).is_empty():
		return {"type": "orders", "orders": lvl["orders"]}
	return {"type": "sort"}


# --- Level data & background generation --------------------------------------

func has_level(level: int) -> bool:
	return _cache.has(level)


func is_generating(level: int) -> bool:
	return _tasks.has(level)


## Starts generating `level` in the background (no-op if cached/running).
func prefetch(level: int) -> void:
	if level < 1 or _cache.has(level) or _tasks.has(level):
		return
	_tasks[level] = WorkerThreadPool.add_task(_generate_task.bind(level), false, "level %d" % level)


## The level definition. Waits for a running task, or generates now.
func get_level(level: int) -> Dictionary:
	if _cache.has(level):
		return (_cache[level] as Dictionary).duplicate(true)
	if _tasks.has(level):
		WorkerThreadPool.wait_for_task_completion(_tasks[level])
		_tasks.erase(level)
		_mutex.lock()
		var lvl: Dictionary = _results.get(level, {})
		_results.erase(level)
		_mutex.unlock()
		if not lvl.is_empty():
			_store(level, lvl)
			return lvl.duplicate(true)
	var made := LevelGenerator.generate(level)
	_store(level, made)
	return made.duplicate(true)


func _generate_task(level: int) -> void:
	var lvl := LevelGenerator.generate(level)
	_mutex.lock()
	_results[level] = lvl
	_mutex.unlock()


func _store(level: int, lvl: Dictionary) -> void:
	_cache[level] = lvl
	if _cache.size() > CACHE_LIMIT:
		var oldest: int = _cache.keys().min()
		if oldest != level:
			_cache.erase(oldest)


# --- Tutorial steps ----------------------------------------------------------

func tutorial_done(step: String) -> bool:
	return bool(SaveManager.game()["tutorial_steps"].get(step, false))


func mark_tutorial(step: String) -> void:
	SaveManager.game()["tutorial_steps"][step] = true
	if step == "tap":
		SaveManager.data["tutorial_done"] = true
	SaveManager.save_game()


# --- Cosmetics ---------------------------------------------------------------

func is_owned(id: String) -> bool:
	var item := GameData.cosmetic(id)
	if item.is_empty():
		return false
	return int(item.get("price", 0)) == 0 or (SaveManager.data["unlocked_items"] as Array).has(id)


## Paid cosmetics owned (Collector achievement).
func owned_cosmetic_count() -> int:
	return (SaveManager.data["unlocked_items"] as Array).size()


func selected_cosmetic(category: String) -> String:
	var id: String = SaveManager.data["selected_items"].get(category, "")
	if id != "" and is_owned(id):
		return id
	for c in GameData.cosmetics(category):
		if int(c.get("price", 0)) == 0:
			return c["id"]
	return ""


func selected_cosmetic_data(category: String) -> Dictionary:
	return GameData.cosmetic(selected_cosmetic(category))


func buy_cosmetic(id: String) -> bool:
	if is_owned(id):
		return select_cosmetic(id)
	var item := GameData.cosmetic(id)
	if item.is_empty() or not CurrencyManager.spend(int(item["price"])):
		return false
	(SaveManager.data["unlocked_items"] as Array).append(id)
	AchievementManager.refresh()
	return select_cosmetic(id)


func select_cosmetic(id: String) -> bool:
	if not is_owned(id):
		return false
	var category: String = GameData.cosmetic(id)["category"]
	SaveManager.data["selected_items"][category] = id
	SaveManager.save_game()
	cosmetic_changed.emit(category, id)
	return true
