extends Node
## Two win streaks:
##   Dami streak - consecutive wins without failing or leaving; the next
##     level starts with free pre-level boosters (1: Peek, 2: + Open Jar,
##     3+: + Lucky Start). Failing or leaving resets it.
##   Treasure streak - win 7 levels in a row to open Hajurama's Trunk.
##   game.streaks = {dami, best_dami, treasure, trunks_opened}

signal changed(dami: int, treasure: int)
signal trunk_ready


static func save_defaults() -> Dictionary:
	return {"dami": 0, "best_dami": 0, "treasure": 0, "trunks_opened": 0}


static func migrate_block(block: Dictionary, _from_version: int) -> Dictionary:
	return block


func block() -> Dictionary:
	var g := SaveManager.game()
	if typeof(g.get("streaks")) != TYPE_DICTIONARY:
		g["streaks"] = save_defaults()
	return g["streaks"]


func dami() -> int:
	return int(block().get("dami", 0))


func treasure() -> int:
	return int(block().get("treasure", 0))


func treasure_goal() -> int:
	return int(GameData.economy().get("treasure_streak", {}).get("wins", 7))


## Free pre-level boosters the current Dami streak gives the next level.
func free_boosters() -> Array:
	var table: Dictionary = GameData.economy().get("dami_streak", {})
	var n := mini(dami(), 3)
	if n <= 0:
		return []
	return (table.get(str(n), []) as Array).duplicate()


## Called on every win. Returns true when the trunk is ready to open.
func on_win() -> bool:
	var b := block()
	b["dami"] = dami() + 1
	b["best_dami"] = maxi(int(b.get("best_dami", 0)), dami())
	b["treasure"] = treasure() + 1
	SaveManager.max_stat("best_combo", dami())
	changed.emit(dami(), treasure())
	var ready := treasure() >= treasure_goal()
	if ready:
		trunk_ready.emit()
	return ready


## Failing a level or leaving it after a move resets both streaks.
func on_fail() -> void:
	var b := block()
	b["dami"] = 0
	b["treasure"] = 0
	changed.emit(0, 0)
	SaveManager.save_game()


func trunk_is_ready() -> bool:
	return treasure() >= treasure_goal()


## Opens Hajurama's Trunk (resets the treasure streak). Returns the contents.
func claim_trunk() -> Dictionary:
	if not trunk_is_ready():
		return {}
	var b := block()
	b["treasure"] = 0
	b["trunks_opened"] = int(b.get("trunks_opened", 0)) + 1
	SaveManager.save_game()
	changed.emit(dami(), 0)
	return (GameData.economy().get("treasure_streak", {}).get("chest", {"coins": 300}) as Dictionary).duplicate(true)
