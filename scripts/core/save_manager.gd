extends Node
## Persists progress to user://save.json.
## Saves are written to a temp file and renamed over the real one, so killing
## the app mid-save never leaves a half-written file. A corrupt save is backed
## up as save.corrupt.json and the game starts from defaults instead of crashing.

signal saved
signal loaded
signal progress_reset
signal setting_changed(key: String, value: Variant)

const CURRENT_VERSION := 2

## Meta systems own their block of game data: each script has
## `static func save_defaults() -> Dictionary` and
## `static func migrate_block(block: Dictionary, from_version: int) -> Dictionary`.
## SaveManager only stitches the blocks together.
const SYSTEM_BLOCKS := {
	"renovation": "res://scripts/meta/renovation_manager.gd",
	"purchases": "res://scripts/core/iap_manager.gd",
	"streaks": "res://scripts/meta/streak_manager.gd",
	"daily": "res://scripts/meta/daily_manager.gd",
	"chests": "res://scripts/meta/chest_manager.gd",
	"album": "res://scripts/meta/album_manager.gd",
	"events": "res://scripts/meta/event_manager.gd",
	"race": "res://scripts/meta/race_manager.gd",
}

var save_path := "user://save.json"
var data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


func defaults() -> Dictionary:
	var econ := GameData.economy()
	var achievements := {}
	for a in GameData.achievements():
		achievements[a["id"]] = {"tier": 0, "progress": 0}
	var d := {
		"version": CURRENT_VERSION,
		"coins": int(econ.get("starting_coins", 0)),
		"best_score": 0,
		"current_level": 1,
		"unlocked_items": [],
		"selected_items": {},
		"upgrades": {},
		"tutorial_done": false,
		"settings": {"sound": true, "music": true, "haptics": true, "hints": true, "sfx_volume": 1.0, "music_volume": 0.7},
		"statistics": {
			"games_played": 0,
			"total_coins_earned": 0,
			"best_combo": 0,
			"play_time_sec": 0,
		},
		"game": {
			"lives": int(econ["lives"]["max"]),
			"last_life_time": 0,
			"unlimited_lives_until": 0,
			"stars": 0,
			"time": {"max_seen": 0},
			"boosters": (econ["starting_boosters"] as Dictionary).duplicate(),
			"tutorial_steps": {},
			"achievements": achievements,
			"profile": {"name": "Player", "avatar": 0},
			"stats": {
				"levels_completed": 0,
				"jars_filled": 0,
				"candies_moved": 0,
				"boosters_used": 0,
				"no_booster_streak": 0,
				"best_no_booster_streak": 0,
				"no_booster_wins": 0,
				"hard_completed": 0,
				"super_completed": 0,
				"stars_earned": 0,
			},
			"daily_free_claimed_date": "",
			"in_progress_level": null,
		},
	}
	for key in SYSTEM_BLOCKS:
		d["game"][key] = load(SYSTEM_BLOCKS[key]).save_defaults()
	return d


func set_save_path(path: String) -> void:
	save_path = path


func corrupt_path() -> String:
	return save_path.get_basename() + ".corrupt.json"


func load_game() -> void:
	var base := defaults()
	if not FileAccess.file_exists(save_path):
		data = base
		loaded.emit()
		return
	var json := JSON.new()
	var text := FileAccess.get_file_as_string(save_path)
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("SaveManager: %s is corrupt; backed up to %s and starting fresh." % [save_path, corrupt_path()])
		_backup_corrupt()
		data = base
	else:
		var migrated := migrate(_normalize(json.data))
		data = _merge(base, migrated)
	loaded.emit()


func save_game() -> bool:
	if data.is_empty():
		return false
	data["version"] = CURRENT_VERSION
	var tmp := save_path.get_basename() + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var err := DirAccess.rename_absolute(tmp, save_path)
	if err != OK:
		# Some platforms refuse to rename over an existing file.
		DirAccess.remove_absolute(save_path)
		err = DirAccess.rename_absolute(tmp, save_path)
	if err != OK:
		push_error("SaveManager: rename failed (%s)" % error_string(err))
		return false
	saved.emit()
	return true


## Upgrades an older save dictionary one version at a time.
func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 0))
	while v < CURRENT_VERSION:
		match v:
			0:
				# Unversioned prototype saves kept lives and boosters at the top level.
				if not d.has("game") or typeof(d["game"]) != TYPE_DICTIONARY:
					d["game"] = {}
				for key in ["lives", "last_life_time", "boosters"]:
					if d.has(key):
						d["game"][key] = d[key]
						d.erase(key)
			1:
				# v2: the renovation meta replaces "a decoration every 10 levels".
				# Every past win would have earned a star, so grant them now.
				var g: Dictionary = d.get("game", {})
				var done := int(g.get("stats", {}).get("levels_completed", 0))
				done = maxi(done, int(d.get("current_level", 1)) - 1)
				g["stars"] = int(g.get("stars", 0)) + done
				g.erase("pasal_decorations")
				g.erase("decorations_revealed")
				d["game"] = g
		for key in SYSTEM_BLOCKS:
			var g2: Dictionary = d.get("game", {})
			if typeof(g2.get(key)) == TYPE_DICTIONARY:
				g2[key] = load(SYSTEM_BLOCKS[key]).migrate_block(g2[key], v)
		v += 1
		d["version"] = v
	return d


func reset_progress() -> void:
	var settings: Dictionary = data.get("settings", {}).duplicate()
	data = defaults()
	data["settings"] = _merge(data["settings"], settings)
	save_game()
	progress_reset.emit()


func get_setting(key: String) -> bool:
	return bool(data["settings"].get(key, true))


## Volume settings, 0..1.
func get_volume(key: String) -> float:
	return clampf(float(data["settings"].get(key, 1.0)), 0.0, 1.0)


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	save_game()
	setting_changed.emit(key, value)


func game() -> Dictionary:
	return data["game"]


## Game-specific counters live in game.stats (profile screen, achievements).
func add_game_stat(key: String, amount: int = 1) -> void:
	var stats: Dictionary = data["game"]["stats"]
	stats[key] = int(stats.get(key, 0)) + amount


func game_stat(key: String) -> int:
	return int(data["game"]["stats"].get(key, 0))


func set_game_stat(key: String, value: int) -> void:
	data["game"]["stats"][key] = value


func add_stat(key: String, amount: int) -> void:
	var stats: Dictionary = data["statistics"]
	stats[key] = int(stats.get(key, 0)) + amount


func max_stat(key: String, value: int) -> void:
	var stats: Dictionary = data["statistics"]
	stats[key] = maxi(int(stats.get(key, 0)), value)


func stat(key: String) -> int:
	return int(data["statistics"].get(key, 0))


func _backup_corrupt() -> void:
	var from := ProjectSettings.globalize_path(save_path)
	var to := ProjectSettings.globalize_path(corrupt_path())
	var err := DirAccess.copy_absolute(from, to)
	if err != OK:
		push_error("SaveManager: could not back up corrupt save (%s)" % error_string(err))


## Deep-merges saved values over defaults so newly added fields always exist.
func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key in over.keys():
		var incoming: Variant = over[key]
		if not out.has(key):
			out[key] = incoming
			continue
		var current: Variant = out[key]
		if current == null:
			out[key] = incoming  # nullable slots (e.g. in_progress_level)
			continue
		if typeof(current) == TYPE_DICTIONARY and typeof(incoming) == TYPE_DICTIONARY:
			out[key] = _merge(current, incoming)
		elif typeof(current) == typeof(incoming) or (_is_number(current) and _is_number(incoming)):
			out[key] = incoming
		# otherwise the saved value has the wrong type: keep the default
	return out


func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


## JSON has no integers; turn whole-number floats back into ints.
func _normalize(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			if absf(f) < 1e15 and is_equal_approx(f, roundf(f)):
				return int(roundf(f))
			return f
		TYPE_DICTIONARY:
			var d: Dictionary = v
			for k in d.keys():
				d[k] = _normalize(d[k])
			return d
		TYPE_ARRAY:
			var a: Array = v
			for i in a.size():
				a[i] = _normalize(a[i])
			return a
	return v
