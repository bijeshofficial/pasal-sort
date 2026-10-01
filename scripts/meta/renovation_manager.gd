extends Node
## The renovation meta: stars won in levels are spent on tasks in the
## current area. Each task restores one or more objects; the player picks one
## of three styles and can change it later for free. Finishing every task in
## an area pays its chapter chest and unlocks the next area.
##
## Areas live in data/areas/area_NN.json; this manager only keeps state:
##   game.renovation = {area, areas: {"1": {tasks: {task_id: style}, complete,
##                      chest_claimed}}, stars_spent, style_changes}

signal task_completed(area: int, task_id: String, style: int)
signal style_changed(area: int, task_id: String, style: int)
signal area_completed(area: int)
signal area_unlocked(area: int)


static func save_defaults() -> Dictionary:
	return {"area": 1, "areas": {}, "stars_spent": 0, "style_changes": 0}


static func migrate_block(block: Dictionary, _from_version: int) -> Dictionary:
	return block


func block() -> Dictionary:
	var g := SaveManager.game()
	if typeof(g.get("renovation")) != TYPE_DICTIONARY:
		g["renovation"] = save_defaults()
	return g["renovation"]


func current_area() -> int:
	return clampi(int(block().get("area", 1)), 1, maxi(1, area_count()))


func area_count() -> int:
	return GameData.area_count()


func area(index: int = -1) -> Dictionary:
	return GameData.area(current_area() if index < 0 else index)


func area_name(index: int = -1) -> String:
	return String(area(index).get("name", "Area"))


func area_state(index: int) -> Dictionary:
	var areas: Dictionary = block()["areas"]
	var key := str(index)
	if typeof(areas.get(key)) != TYPE_DICTIONARY:
		areas[key] = {"tasks": {}, "complete": false, "chest_claimed": false}
	var st: Dictionary = areas[key]
	if typeof(st.get("tasks")) != TYPE_DICTIONARY:
		st["tasks"] = {}
	return st


func tasks(index: int = -1) -> Array:
	return area(index).get("tasks", [])


func task(index: int, task_id: String) -> Dictionary:
	return GameData.area_task(index, task_id)


## Chosen style index, or -1 if the task is not done yet.
func task_style(index: int, task_id: String) -> int:
	var t: Dictionary = area_state(index)["tasks"]
	return int(t[task_id]) if t.has(task_id) else -1


func is_task_done(index: int, task_id: String) -> bool:
	return task_style(index, task_id) >= 0


## All prerequisite tasks are done.
func is_task_unlocked(index: int, task_id: String) -> bool:
	for req in task(index, task_id).get("requires", []):
		if not is_task_done(index, String(req)):
			return false
	return true


func task_cost(index: int, task_id: String) -> int:
	return int(task(index, task_id).get("cost", 1))


func can_do(index: int, task_id: String) -> bool:
	return index == current_area() and not is_task_done(index, task_id) and is_task_unlocked(index, task_id) and CurrencyManager.get_stars() >= task_cost(index, task_id)


## Tasks that are unlocked and not yet done, in data order.
func open_tasks(index: int = -1) -> Array:
	if index < 0:
		index = current_area()
	var out: Array = []
	for t in tasks(index):
		if not is_task_done(index, t["id"]) and is_task_unlocked(index, t["id"]):
			out.append(t)
	return out


## How many open tasks the player can pay for right now (Tasks badge).
func affordable_count() -> int:
	var n := 0
	var stars := CurrencyManager.get_stars()
	for t in open_tasks():
		if int(t.get("cost", 1)) <= stars:
			n += 1
	return n


func cheapest_open_cost() -> int:
	var best := -1
	for t in open_tasks():
		var c := int(t.get("cost", 1))
		if best < 0 or c < best:
			best = c
	return best


func done_count(index: int = -1) -> int:
	if index < 0:
		index = current_area()
	var n := 0
	for t in tasks(index):
		if is_task_done(index, t["id"]):
			n += 1
	return n


func total_count(index: int = -1) -> int:
	return tasks(index).size()


func progress(index: int = -1) -> float:
	var total := total_count(index)
	return 0.0 if total == 0 else float(done_count(index)) / total


func total_stars(index: int = -1) -> int:
	var n := 0
	for t in tasks(index):
		n += int(t.get("cost", 1))
	return n


func is_area_complete(index: int) -> bool:
	var total := total_count(index)
	return total > 0 and done_count(index) >= total


func completed_area_count() -> int:
	var n := 0
	for i in range(1, area_count() + 1):
		if is_area_complete(i):
			n += 1
	return n


## Style index shown for an object: the style of the task that restores it,
## -1 while that task is not done, or -2 for decor that has no task.
func object_style(index: int, object_id: String) -> int:
	for t in tasks(index):
		if (t.get("objects", []) as Array).has(object_id):
			return task_style(index, t["id"])
	return -2


func task_for_object(index: int, object_id: String) -> Dictionary:
	for t in tasks(index):
		if (t.get("objects", []) as Array).has(object_id):
			return t
	return {}


## Spends the stars and records the chosen style. Returns
## {ok, coins, area_complete} (ok false if the task can't be done).
func complete_task(task_id: String, style: int) -> Dictionary:
	var index := current_area()
	if not can_do(index, task_id):
		return {"ok": false}
	var t := task(index, task_id)
	var cost := int(t.get("cost", 1))
	if not CurrencyManager.spend_stars(cost):
		return {"ok": false}
	var styles: Array = t.get("styles", [])
	style = clampi(style, 0, maxi(0, styles.size() - 1))
	area_state(index)["tasks"][task_id] = style
	block()["stars_spent"] = int(block().get("stars_spent", 0)) + cost
	SaveManager.add_game_stat("tasks_completed")
	var coins := int(t.get("coins", GameData.economy().get("renovation", {}).get("task_coins", 10)))
	CurrencyManager.add_coins(coins, false)
	var finished := is_area_complete(index)
	if finished:
		area_state(index)["complete"] = true
		SaveManager.add_game_stat("areas_completed")
	SaveManager.save_game()
	task_completed.emit(index, task_id, style)
	if finished:
		area_completed.emit(index)
	return {"ok": true, "coins": coins, "area_complete": finished, "cost": cost}


## Changing the style of a finished task is free. `count_change` is false
## for the first pick right after the task (not a "change" for Stylist).
func set_style(index: int, task_id: String, style: int, count_change: bool = true) -> bool:
	if not is_task_done(index, task_id):
		return false
	var styles: Array = task(index, task_id).get("styles", [])
	if style < 0 or style >= styles.size() or style == task_style(index, task_id):
		return false
	area_state(index)["tasks"][task_id] = style
	if count_change:
		block()["style_changes"] = int(block().get("style_changes", 0)) + 1
		SaveManager.add_game_stat("style_changes")
	SaveManager.save_game()
	style_changed.emit(index, task_id, style)
	return true


## The chapter chest of a completed area, once. Returns its contents or {}.
func claim_area_chest(index: int) -> Dictionary:
	if not is_area_complete(index) or bool(area_state(index).get("chest_claimed", false)):
		return {}
	area_state(index)["chest_claimed"] = true
	var chest: Dictionary = area(index).get("chest", {"coins": 200})
	SaveManager.save_game()
	return chest.duplicate(true)


func has_next_area() -> bool:
	return current_area() < area_count()


## Moves on to the next area once the current one is complete.
func advance_area() -> bool:
	var index := current_area()
	if not is_area_complete(index) or index >= area_count():
		return false
	block()["area"] = index + 1
	area_state(index + 1)
	SaveManager.save_game()
	area_unlocked.emit(index + 1)
	return true


## Debug: finish every task of the current area with style 0.
func debug_complete_area() -> void:
	var index := current_area()
	for t in tasks(index):
		if not is_task_done(index, t["id"]):
			area_state(index)["tasks"][t["id"]] = 0
	area_state(index)["complete"] = true
	SaveManager.save_game()
	area_completed.emit(index)
