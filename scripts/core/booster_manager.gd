extends Node
## Booster inventory. In-level: Undo, Extra Jar, Shuffle, Haat Helper.
## Pre-level (picked on the level start card): Open Jar, Peek, Lucky Start.

signal changed(id: String, count: int)

## In-level boosters shown on the booster bar (the helper from level 60).
const IDS := ["undo", "extra_jar", "shuffle"]
const IN_LEVEL := ["undo", "extra_jar", "shuffle", "helper"]
const PRE_IDS := ["open_jar", "peek", "lucky"]
const ALL := ["undo", "extra_jar", "shuffle", "helper", "open_jar", "peek", "lucky"]
const NAMES := {"undo": "Undo", "extra_jar": "Extra Jar", "shuffle": "Shuffle", "helper": "Haat Helper", "open_jar": "Open Jar", "peek": "Peek", "lucky": "Lucky Start"}
const DESCRIPTIONS := {
	"undo": "Take back your last move.",
	"extra_jar": "Add one empty jar to this level.",
	"shuffle": "Mix up the unfinished jars into a new solvable board.",
	"helper": "Pick a candy: the helper gathers it from the jar tops into an empty jar.",
	"open_jar": "Start the level with one more empty jar.",
	"peek": "Every wrapped candy starts unwrapped.",
	"lucky": "The first 3 moves glow as hints.",
}


func count(id: String) -> int:
	return int(SaveManager.game()["boosters"].get(id, 0))


func grant(id: String, n: int = 1, save: bool = true) -> void:
	if not ALL.has(id) or n <= 0:
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
	return tr(NAMES.get(id, id))


func description(id: String) -> String:
	return tr(DESCRIPTIONS.get(id, ""))


## The Haat Helper joins the booster bar from level 60.
func helper_unlocked() -> bool:
	return ProgressionManager.current_level() >= int(GameData.economy().get("helper_from", 60))


func bar_ids() -> Array:
	return IN_LEVEL if helper_unlocked() else IDS


## Pre-level boosters appear on the start card from level 12.
func pre_unlocked(level: int = -1) -> bool:
	if level < 0:
		level = ProgressionManager.current_level()
	return level >= int(GameData.economy().get("pre_boosters_from", 12))


func icon_for(id: String) -> String:
	return {"undo": "undo", "extra_jar": "jar_plus", "shuffle": "shuffle", "helper": "basket", "open_jar": "jar", "peek": "eye", "lucky": "clover"}.get(id, "star")
