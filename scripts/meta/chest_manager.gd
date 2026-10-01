extends Node
## Chests: a level chest every 10 levels and a star chest for every 15
## stars spent on renovation. (The mission chest lives in DailyManager.)
## Opening is the ChestPopup; this only decides what's due and what's inside.
##   game.chests = {level_claimed: [levels], star_claimed: n}

signal changed

const CHESTS := "res://data/chests.json"


static func save_defaults() -> Dictionary:
	return {"level_claimed": [], "star_claimed": 0}


static func migrate_block(block: Dictionary, _from_version: int) -> Dictionary:
	return block


func _ready() -> void:
	RenovationManager.task_completed.connect(func(_a: int, _t: String, _s: int) -> void: changed.emit())


func data() -> Dictionary:
	return GameData.load_json(CHESTS)


func block() -> Dictionary:
	var g := SaveManager.game()
	if typeof(g.get("chests")) != TYPE_DICTIONARY:
		g["chests"] = save_defaults()
	return g["chests"]


func level_every() -> int:
	return int(GameData.economy().get("milestone_every", 10))


func level_chest_due(level: int) -> bool:
	return level > 0 and level % level_every() == 0 and not (block()["level_claimed"] as Array).has(level)


## The level chest for `level` (once). Rotates through data/chests.json.
func claim_level_chest(level: int) -> Dictionary:
	if not level_chest_due(level):
		return {}
	(block()["level_claimed"] as Array).append(level)
	var table: Array = data().get("level", [{"coins": 100}])
	var contents: Dictionary = (table[posmod(level / level_every() - 1, table.size())] as Dictionary).duplicate(true)
	SaveManager.save_game()
	changed.emit()
	return contents


func star_every() -> int:
	return int(data().get("star_every", 15))


func stars_spent() -> int:
	return int(RenovationManager.block().get("stars_spent", 0))


func star_chests_available() -> int:
	return maxi(0, stars_spent() / star_every() - int(block().get("star_claimed", 0)))


## Stars still to spend before the next star chest.
func stars_to_next() -> int:
	return star_every() - stars_spent() % star_every()


func claim_star_chest() -> Dictionary:
	if star_chests_available() <= 0:
		return {}
	block()["star_claimed"] = int(block().get("star_claimed", 0)) + 1
	SaveManager.save_game()
	changed.emit()
	return (data().get("star", {"coins": 150}) as Dictionary).duplicate(true)


## Every chest opening (any kind) counts for missions and achievements.
func note_opened(_source: String) -> void:
	SaveManager.add_game_stat("chests_opened")
	GameManager.emit_event("chest")
