extends Node
## Booster inventory: Undo, Extra Jar and Shuffle.

signal changed(id: String, count: int)

const IDS := ["undo", "extra_jar", "shuffle"]
const NAMES := {"undo": "Undo", "extra_jar": "Extra Jar", "shuffle": "Shuffle"}


func count(id: String) -> int:
	return int(SaveManager.game()["boosters"].get(id, 0))


func grant(id: String, n: int = 1, save: bool = true) -> void:
	if not IDS.has(id) or n <= 0:
		return
	SaveManager.game()["boosters"][id] = count(id) + n
	changed.emit(id, count(id))
	if save:
		SaveManager.save_game()


## Uses one from the inventory. Returns false when there are none.
func consume(id: String) -> bool:
	if count(id) <= 0:
		return false
	SaveManager.game()["boosters"][id] = count(id) - 1
	SaveManager.add_game_stat("boosters_used")
	changed.emit(id, count(id))
	SaveManager.save_game()
	return true


func price(id: String) -> int:
	return GameData.price(id)


func buy(id: String) -> bool:
	if not CurrencyManager.spend(price(id)):
		return false
	grant(id, 1)
	return true


## One-time tutorial grant (L4 Undo, L6 Extra Jar, L8 Shuffle).
func grant_tutorial(id: String) -> int:
	var key := "grant_" + id
	if ProgressionManager.tutorial_done(key):
		return 0
	var n := int(GameData.economy()["tutorial_grants"].get(id, 1))
	grant(id, n, false)
	ProgressionManager.mark_tutorial(key)
	return n


func display_name(id: String) -> String:
	return NAMES.get(id, id)
