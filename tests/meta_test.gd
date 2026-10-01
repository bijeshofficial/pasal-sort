extends SceneTree
## Headless tests for the meta game: renovation, area/story data, save
## migration, the debug clock and an end-to-end first renovation on Home.
##   godot --headless --path . --script res://tests/meta_test.gd
## Uses its own save file. Exit code 0 when every check passes.
##
## UI and art classes are reached with load() (their scripts use autoloads,
## which don't exist yet when a --script runner compiles).

const TEST_SAVE := "user://meta_test_save.json"
const HUB := "res://scenes/main/hub.tscn"

var failures: Array[String] = []
var checks := 0

var S: Node
var CM: Node
var PM: Node
var LM: Node
var RM: Node
var DM: Node
var SM: Node
var TM: Node
var AD: Node


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	await process_frame
	S = root.get_node("SaveManager")
	CM = root.get_node("CurrencyManager")
	PM = root.get_node("ProgressionManager")
	LM = root.get_node("LivesManager")
	RM = root.get_node("RenovationManager")
	DM = root.get_node("DialogueManager")
	SM = root.get_node("ScreenManager")
	TM = root.get_node("TimeManager")
	AD = root.get_node("AdManager")
	S.set_save_path(TEST_SAVE)
	_remove_test_files()
	S.load_game()
	AD.mock_duration = 0.05
	DM.instant = true

	_test_area_data()
	_test_story_data()
	_test_renovation_rules()
	_test_area_completion()
	_test_styles_persist()
	_test_migration_v1()
	_test_clock()
	_test_unlimited_lives()
	await _test_first_renovation_end_to_end()
	await _test_area_complete_flow()
	_finish()


func _fresh(level: int = 1) -> void:
	S.data = S.defaults()
	S.data["current_level"] = level
	TM.debug_offset = 0.0
	for k in ["tap", "stack", "empty", "undo", "extra_jar", "shuffle", "story_intro"]:
		S.game()["tutorial_steps"][k] = true


# --- Data --------------------------------------------------------------------

func _test_area_data() -> void:
	var reno_art = load("res://scripts/visuals/reno_art.gd")
	_check(RM.area_count() == 10, "10 areas load from data/areas (%d)" % RM.area_count())
	var problems: Array = []
	var totals: Array = []
	for i in range(1, RM.area_count() + 1):
		var a: Dictionary = RM.area(i)
		var ids := {}
		for o in a.get("objects", []):
			ids[o["id"]] = true
			if not reno_art.has_kind(String(o["kind"])):
				problems.append("area %d: unknown kind %s" % [i, o["kind"]])
		var task_ids := {}
		for t in a.get("tasks", []):
			task_ids[t["id"]] = true
		var total := 0
		for t in a.get("tasks", []):
			total += int(t.get("cost", 0))
			if int(t.get("cost", 0)) < 1 or int(t.get("cost", 0)) > 5:
				problems.append("area %d task %s: cost %s" % [i, t["id"], t.get("cost")])
			if (t.get("styles", []) as Array).size() != 3:
				problems.append("area %d task %s: needs 3 styles" % [i, t["id"]])
			for oid in t.get("objects", []):
				if not ids.has(oid):
					problems.append("area %d task %s: missing object %s" % [i, t["id"], oid])
			for r in t.get("requires", []):
				if not task_ids.has(r):
					problems.append("area %d task %s: unknown requirement %s" % [i, t["id"], r])
			var story := "%s.%s" % [String(a.get("story_prefix", "a%d" % i)), t["id"]]
			if i <= 3 and not DM.has_dialogue(story):
				problems.append("area %d task %s: no story %s" % [i, t["id"], story])
		var n := (a.get("tasks", []) as Array).size()
		if n < 8 or n > 14:
			problems.append("area %d: %d tasks (want 8-14)" % [i, n])
		if not DM.has_dialogue(String(a.get("outro_story", ""))):
			problems.append("area %d: no outro story" % i)
		totals.append(total)
		# Every task must be reachable (no requirement cycles).
		var done := {}
		var progress := true
		while progress:
			progress = false
			for t in a.get("tasks", []):
				if done.has(t["id"]):
					continue
				var ok := true
				for r in t.get("requires", []):
					if not done.has(r):
						ok = false
				if ok:
					done[t["id"]] = true
					progress = true
		if done.size() != n:
			problems.append("area %d: requirement cycle" % i)
	_check(problems.is_empty(), "area data is valid (kinds, objects, 3 styles, requirements, stories) %s" % [problems.slice(0, 4)])
	_check(int(totals[0]) >= 16 and int(totals[0]) <= 20 and int(totals[9]) >= 36 and int(totals[9]) <= 44, "star costs: area 1 ~18, area 10 ~40 (%s)" % [totals])
	var rising := true
	for k in range(1, totals.size()):
		if int(totals[k]) + 2 < int(totals[k - 1]):
			rising = false
	_check(rising, "area costs rise with each chapter")


func _test_story_data() -> void:
	var cast_ids := ["maya", "hajurama", "bhai", "kanchha", "sunita", "biralo"]
	var moods := ["neutral", "happy", "laugh", "surprised", "worried", "grumpy"]
	var bad: Array = []
	var ids := ["intro"]
	for i in range(1, RM.area_count() + 1):
		ids.append(String(RM.area(i).get("outro_story", "")))
		for t in RM.tasks(i):
			ids.append("%s.%s" % [String(RM.area(i).get("story_prefix", "a%d" % i)), t["id"]])
	for id in ids:
		for line in GameData.story(id):
			if not cast_ids.has(String(line.get("who", ""))) or not moods.has(String(line.get("mood", ""))) or String(line.get("text", "")) == "":
				bad.append(id)
	_check(bad.is_empty(), "every story line has a known speaker, mood and text %s" % [bad.slice(0, 3)])
	var intro := GameData.story("intro")
	_check(intro.size() >= 3 and String(intro[0]["who"]) == "hajurama", "the intro story starts with Hajurama")


# --- Renovation rules --------------------------------------------------------

func _test_renovation_rules() -> void:
	_fresh(5)
	_check(RM.current_area() == 1 and RM.done_count() == 0, "a new save starts in area 1 with nothing done")
	_check(not RM.can_do(1, "clean_counter") and not RM.complete_task("clean_counter", 0).get("ok", false), "no stars: can't do a task")
	CM.add_stars(1, false)
	_check(RM.affordable_count() >= 1, "1 star: the Tasks badge counts affordable tasks (%d)" % RM.affordable_count())
	_check(not RM.can_do(1, "cash_box") and not RM.is_task_unlocked(1, "cash_box"), "a task waits for its prerequisite")
	var r: Dictionary = RM.complete_task("clean_counter", 1)
	_check(r.get("ok", false) and RM.task_style(1, "clean_counter") == 1 and CM.get_stars() == 0, "doing a task spends its stars and keeps the chosen style")
	_check(int(r.get("coins", 0)) == 10, "a task pays a small coin reward")
	_check(RM.is_task_unlocked(1, "cash_box"), "finishing a task unlocks the ones that need it")
	_check(not RM.complete_task("clean_counter", 0).get("ok", false), "a task can't be done twice")
	CM.add_stars(1, false)
	_check(not RM.complete_task("fix_shelf", 0).get("ok", false) and CM.get_stars() == 1, "a 2-star task fails with 1 star and spends nothing")
	_check(not CM.spend_stars(5) and CM.get_stars() == 1, "stars never go negative")
	_check(RM.object_style(1, "counter") == 1 and RM.object_style(1, "floor") == -1 and RM.object_style(1, "beams") == -2, "objects report restored, broken or decor")


func _test_area_completion() -> void:
	_fresh(40)
	CM.add_stars(RM.total_stars(1) + 5, false)
	var done := 0
	var guard := 0
	while not RM.is_area_complete(1) and guard < 50:
		guard += 1
		for t in RM.open_tasks(1):
			if RM.complete_task(t["id"], done % 3).get("ok", false):
				done += 1
	_check(RM.is_area_complete(1) and CM.get_stars() == 5, "every area 1 task can be done in order; exactly its stars are spent (%d left)" % CM.get_stars())
	_check(RM.current_area() == 1, "the area stays current until its completion flow runs")
	var chest: Dictionary = RM.claim_area_chest(1)
	_check(int(chest.get("coins", 0)) > 0 and RM.claim_area_chest(1).is_empty(), "the chapter chest pays once")
	_check(RM.advance_area() and RM.current_area() == 2 and RM.area_name() == "The Shop Front", "completing area 1 unlocks area 2")
	_check(not RM.advance_area(), "area 2 must be finished before area 3")
	_check(not RM.can_do(1, "stool"), "tasks of a finished area can't be bought again")


func _test_styles_persist() -> void:
	_fresh(20)
	CM.add_stars(3, false)
	RM.complete_task("clean_counter", 0)
	RM.complete_task("sweep_floor", 2)
	_check(RM.set_style(1, "clean_counter", 2) and RM.task_style(1, "clean_counter") == 2, "changing a finished task's style is free")
	_check(int(RM.block()["style_changes"]) == 1 and S.game_stat("style_changes") == 1, "style changes are counted (Stylist)")
	_check(not RM.set_style(1, "fix_shelf", 1), "unfinished tasks have no style to change")
	S.save_game()
	S.data = {}
	S.load_game()
	_check(RM.task_style(1, "clean_counter") == 2 and RM.task_style(1, "sweep_floor") == 2 and CM.get_stars() == 1, "styles and stars survive save + reload")


func _test_migration_v1() -> void:
	var v1 := {
		"version": 1, "coins": 640, "current_level": 37,
		"game": {"lives": 4, "boosters": {"undo": 2}, "pasal_decorations": ["fairy_lights", "marigold", "radio"], "decorations_revealed": ["fairy_lights"],
			"stats": {"levels_completed": 36}, "in_progress_level": null},
	}
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(v1))
	f.close()
	S.load_game()
	_check(int(S.data["version"]) == S.CURRENT_VERSION and S.CURRENT_VERSION >= 2, "a version-1 save loads into the current version")
	_check(CM.get_stars() == 36 and CM.get_coins() == 640 and PM.current_level() == 37, "v1 -> v2: one star per completed level, coins and level kept")
	_check(not S.game().has("pasal_decorations") and S.game().has("renovation") and RM.current_area() == 1, "v1 -> v2: old decorations removed, renovation block added")


func _test_clock() -> void:
	_fresh(5)
	var d0: String = TM.today()
	var n0: int = TM.day_number()
	TM.advance(86400)
	_check(TM.today() != d0 and TM.day_number() == n0 + 1, "the debug clock rolls the day (%s -> %s)" % [d0, TM.today()])
	TM.advance(86400 * 6)
	_check(TM.week_number() >= TM.week_number(TM.now() - 86400 * 7) + 1, "seven days later is a new week")
	TM.debug_offset = 0.0
	S.game()["time"]["max_seen"] = TM.now() + 86400.0 * 3
	_check(TM.clock_rewound(), "a clock behind the latest seen time is detected")
	S.game()["time"]["max_seen"] = TM.now()
	_check(not TM.clock_rewound(), "a normal clock is not flagged")
	_check(TM.day_number_of(TM.today()) == TM.day_number(), "date strings convert back to day numbers")
	_check(TM.short_duration(3725) == "1h 02m" and TM.short_duration(59) == "59s", "short durations for timers")


func _test_unlimited_lives() -> void:
	_fresh(20)
	S.game()["lives"] = 0
	_check(not LM.can_play(20), "0 lives: can't play level 20")
	LM.add_unlimited(1800)
	_check(LM.can_play(20) and LM.unlimited_active() and LM.lose_life() and LM.lives() == 0, "unlimited lives: play without spending lives")
	TM.advance(1801)
	LM.tick()
	_check(not LM.unlimited_active(), "unlimited lives run out after 30 minutes")
	TM.debug_offset = 0.0


# --- End to end --------------------------------------------------------------

## After level 3: Home teaches the first renovation, the player does it, and
## everything survives a save + reload.
func _test_first_renovation_end_to_end() -> void:
	_fresh(4)
	CM.add_stars(3, false)
	S.game()["stats"]["levels_completed"] = 3
	var coins0: int = CM.get_coins()
	SM.hub_tab = "home"
	change_scene_to_file(HUB)
	await _wait(1.2)
	var hub := current_scene
	var home: Node = hub.home
	_check(home.is_tutorial_active(), "after level 3, Home points at Tasks: clean the counter")
	_check(int(home.tasks_badge.get_child(0).text) >= 1 and home.tasks_badge.visible, "Tasks badge shows how many tasks are affordable")
	home.tasks_button.pressed.emit()
	await _wait(0.6)
	var panel: Node = SM.find_modal("tasks")
	_check(panel != null and panel.buttons.has("clean_counter") and not panel.buttons["clean_counter"].disabled, "the task list opens with the tutorial task enabled")
	var others_locked := true
	if panel:
		for id in panel.buttons:
			if id != "clean_counter" and not panel.buttons[id].disabled:
				others_locked = false
		panel.buttons["clean_counter"].pressed.emit()
	_check(others_locked, "during the tutorial only the counter can be chosen")
	await _until(func() -> bool: return SM.find_modal("style_picker") != null, 4.0)
	var picker: Node = SM.find_modal("style_picker")
	_check(picker != null and CM.get_stars() == 2, "stars fly, then the style picker opens (1 star spent)")
	if picker:
		picker.pick(2)
		await _wait(0.2)
		var counter: Node = home.view.scene.objects["counter"]
		_check(counter.style_id == "steel", "tapping a style previews it in the scene (%s)" % counter.style_id)
		picker.choose_button.pressed.emit()
	await _until(func() -> bool: return not home.busy, 4.0)
	_check(RM.task_style(1, "clean_counter") == 2 and not home.busy, "the chosen style is saved and the sequence ends")
	_check(PM.tutorial_done("first_task") and not home.is_tutorial_active(), "the first-task tutorial is marked done")
	_check(DM.played.has("a1.clean_counter"), "the task's story dialogue played")
	_check(CM.get_coins() == coins0 + 10, "the task paid its coins")
	# Tapping the restored object reopens the style picker for free.
	home.view.object_tapped.emit("counter")
	await _wait(0.4)
	var again: Node = SM.find_modal("style_picker")
	_check(again != null and again.cancellable, "tapping a restored object lets you change its style")
	if again:
		again.pick(0)
		again.choose_button.pressed.emit()
	await _wait(0.2)
	_check(RM.task_style(1, "clean_counter") == 0 and CM.get_stars() == 2, "changing style is free")
	S.save_game()
	S.data = {}
	S.load_game()
	_check(RM.task_style(1, "clean_counter") == 0 and CM.get_stars() == 2 and PM.tutorial_done("first_task"), "renovation survives save + reload")
	SM.close_all_modals()


## Finishing the last task of area 1 runs the chapter flow into area 2.
func _test_area_complete_flow() -> void:
	_fresh(60)
	S.game()["tutorial_steps"]["first_task"] = true
	for t in RM.tasks(1):
		RM.area_state(1)["tasks"][t["id"]] = 0
	RM.area_state(1)["tasks"].erase("stool")
	CM.add_stars(1, false)
	SM.hub_tab = "home"
	change_scene_to_file(HUB)
	await _wait(1.0)
	var home: Node = current_scene.home
	home.do_task("stool")
	await _until(func() -> bool: return SM.find_modal("style_picker") != null, 4.0)
	var picker: Node = SM.find_modal("style_picker")
	if picker:
		picker.choose_button.pressed.emit()
	await _until(func() -> bool: return SM.find_modal("before_after") != null, 5.0)
	var ba: Node = SM.find_modal("before_after")
	_check(ba != null, "the last task opens the before/after reveal")
	if ba:
		ba.continue_button.pressed.emit()
	await _until(func() -> bool: return SM.find_modal("chest") != null, 3.0)
	var chest: Node = SM.find_modal("chest")
	_check(chest != null, "then the chapter chest opens")
	var c0: int = CM.get_coins()
	if chest:
		await _until(func() -> bool: return not chest.collect_button.disabled, 5.0)
		chest.collect_button.pressed.emit()
	_check(CM.get_coins() > c0 - 1 and RM.area_state(1)["chest_claimed"], "the chest is claimed")
	await _until(func() -> bool: return RM.current_area() == 2 and not home.busy, 6.0)
	_check(RM.current_area() == 2 and home.view.scene.area_index == 2, "the page turns to area 2 (%d)" % RM.current_area())
	_check(DM.played.has("a1.outro"), "the chapter's story cutscene played")
	SM.close_all_modals()


# --- Helpers -----------------------------------------------------------------

func _check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  ok   ", label)
	else:
		failures.append(label)
		print("  FAIL ", label)


func _wait(sec: float) -> void:
	await create_timer(sec, true).timeout


func _until(cond: Callable, timeout: float) -> void:
	var t := 0.0
	while not cond.call() and t < timeout:
		await _wait(0.05)
		t += 0.05


func _remove_test_files() -> void:
	for p in [TEST_SAVE, TEST_SAVE.get_basename() + ".corrupt.json", TEST_SAVE.get_basename() + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _finish() -> void:
	SM.close_all_modals()
	paused = false
	TM.debug_offset = 0.0
	_remove_test_files()
	print("\n%d checks, %d failed" % [checks, failures.size()])
	for f in failures:
		print("  - ", f)
	if current_scene:
		current_scene.queue_free()
	for i in 3:
		await process_frame
	quit(0 if failures.is_empty() else 1)
