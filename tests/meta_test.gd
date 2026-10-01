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
	root.get_node("IAPManager").offer_shown_this_session = true

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
	_test_economy_numbers()
	_test_streaks()
	_test_iap()
	await _test_start_card_and_pre_boosters()
	await _test_second_chance()
	_test_calendar()
	_test_missions()
	_test_challenge_rules()
	await _test_challenge_play()
	_test_chests()
	_test_achievement_tiers()
	_test_twist_rules()
	_test_album()
	_test_events()
	_test_race()
	await _test_cat_level_play()
	await _test_orders_and_move_limit()
	await _test_polish()
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


# --- Phase 5: economy, streaks, shop ----------------------------------------

func _test_economy_numbers() -> void:
	var BM := root.get_node("BoosterManager")
	_fresh(1)
	_check(BM.price("undo") == 60 and BM.price("extra_jar") == 150 and BM.price("shuffle") == 100 and BM.price("helper") == 200, "in-level booster prices from economy.json")
	_check(BM.price("open_jar") == 120 and BM.price("peek") == 80 and BM.price("lucky") == 80, "pre-level booster prices from economy.json")
	_check(CM.get_coins() == 200 and BM.count("undo") == 3 and BM.count("extra_jar") == 1 and BM.count("shuffle") == 1, "starting inventory: 200 coins, 3 Undo, 1 Extra Jar, 1 Shuffle")
	_check(not BM.pre_unlocked(11) and BM.pre_unlocked(12), "pre-level boosters start at level 12")


func _test_streaks() -> void:
	var ST := root.get_node("StreakManager")
	_fresh(20)
	_check(ST.dami() == 0 and ST.free_boosters().is_empty(), "no streak, no free boosters")
	ST.on_win()
	_check(ST.free_boosters() == ["peek"], "1 win: free Peek")
	ST.on_win()
	_check(ST.free_boosters() == ["peek", "open_jar"], "2 wins: + Open Jar")
	ST.on_win()
	ST.on_win()
	_check(ST.free_boosters() == ["peek", "open_jar", "lucky"], "3+ wins: + Lucky Start")
	ST.on_fail()
	_check(ST.dami() == 0 and ST.treasure() == 0, "failing resets the streaks")
	var ready := false
	for k in 7:
		ready = ST.on_win()
	_check(ready and ST.trunk_is_ready(), "7 wins in a row: Hajurama's Trunk is ready")
	var trunk: Dictionary = ST.claim_trunk()
	_check(int(trunk.get("coins", 0)) > 0 and ST.claim_trunk().is_empty() and ST.treasure() == 0, "the trunk opens once and the treasure streak restarts")


func _test_iap() -> void:
	var IAP := root.get_node("IAPManager")
	_fresh(5)
	S.game()["stats"]["levels_completed"] = 4
	_check(not IAP.is_available("starter_pack"), "no starter pack before level 10")
	S.data["current_level"] = 12
	_check(IAP.is_available("starter_pack") and IAP.pending_offer() == "" , "starter pack after level 10 (the offer popup already used this session)")
	IAP.auto_confirm = true
	var c0: int = CM.get_coins()
	var got := [null]
	IAP.buy("starter_pack", func(ok: bool) -> void: got[0] = ok)
	_check(got[0] == true and CM.get_coins() == c0 + 1000 and root.get_node("BoosterManager").count("lucky") >= 2 and LM.unlimited_active(), "starter pack grants coins, boosters and unlimited lives")
	_check(not IAP.is_available("starter_pack"), "the starter pack is one-time")
	AD.reset_session_state()
	for k in 5:
		AD.on_run_finished()
	_check(AD.can_show_interstitial(), "interstitials are allowed without No Ads")
	IAP.buy("no_ads", func(_ok: bool) -> void: pass)
	_check(IAP.has_no_ads() and not AD.can_show_interstitial(), "No Ads disables interstitials")
	S.save_game()
	S.data = {}
	S.load_game()
	_check(IAP.has_no_ads() and IAP.is_bought("starter_pack"), "purchases persist")
	IAP.auto_confirm = false
	AD.reset_session_state()
	TM.debug_offset = 0.0


func _test_start_card_and_pre_boosters() -> void:
	var BM := root.get_node("BoosterManager")
	_fresh(26)
	S.game()["tutorial_steps"]["first_task"] = true
	for k in ["twist_wrapped", "twist_cloth"]:
		S.game()["tutorial_steps"][k] = true
	S.game()["boosters"]["open_jar"] = 2
	S.game()["boosters"]["peek"] = 1
	S.game()["boosters"]["lucky"] = 1
	for k in ["grant_open_jar", "grant_peek", "grant_lucky"]:
		S.game()["tutorial_steps"][k] = true
	SM.hub_tab = "home"
	change_scene_to_file(HUB)
	await _wait(0.8)
	current_scene.home.play_button.pressed.emit()
	await _wait(0.4)
	var card: Node = SM.find_modal("level_start")
	_check(card != null, "Play opens the level start card from level 12")
	if card == null:
		return
	card.toggle("open_jar")
	card.toggle("peek")
	card.toggle("lucky")
	_check(card.selected == ["open_jar", "peek"], "at most 2 pre-level boosters")
	_check(BM.count("open_jar") == 2 and BM.count("peek") == 1, "picking a booster doesn't use it yet")
	var jars_expected: int = (PM.get_level(26)["jars"] as Array).size() + 1
	card.play_button.pressed.emit()
	await _until(func() -> bool: return current_scene != null and current_scene.has_method("tap_jar") and current_scene.state == 1, 6.0)
	var g := current_scene
	_check(g.has_method("tap_jar") and BM.count("open_jar") == 1 and BM.count("peek") == 0, "boosters are used when the level starts")
	_check(g.board.jar_count() == jars_expected, "Open Jar: one more empty jar (%d)" % g.board.jar_count())
	var hidden := 0
	for h in g.board.hidden:
		for x in h:
			if x:
				hidden += 1
	_check(hidden == 0, "Peek: every wrapped candy starts unwrapped")
	_check(g.boosters_used, "paid pre-level boosters count as boosters used")
	# Lucky Start from the Dami streak (free).
	SM.close_all_modals()
	S.game()["streaks"]["dami"] = 3
	PM.set_pre_boosters([], root.get_node("StreakManager").free_boosters())
	var l0: int = BM.count("lucky")
	var old_id := g.get_instance_id()
	change_scene_to_file("res://scenes/gameplay/gameplay.tscn")
	await _until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.state == 1, 6.0)
	g = current_scene
	await _wait(0.3)
	_check(g.lucky_left == 3 and g._lucky_move.size() == 2 and BM.count("lucky") == l0, "Dami streak 3: free Lucky Start highlights a move")
	var mv: Array = g._lucky_move
	g.do_move(int(mv[0]), int(mv[1]))
	_check(g.lucky_left == 2, "each move uses one Lucky Start hint")
	SM.close_all_modals()


func _test_second_chance() -> void:
	_fresh(30)
	S.data["coins"] = 500
	for k in ["twist_wrapped", "twist_cloth"]:
		S.game()["tutorial_steps"][k] = true
	change_scene_to_file("res://scenes/gameplay/gameplay.tscn")
	await _wait(1.6)
	var g := current_scene
	var lives0: int = LM.lives()
	var jars0: int = g.board.jar_count()
	g.give_up()
	var sc: Node = SM.find_modal("so_close")
	_check(sc != null, "giving up shows So close! with a second chance")
	if sc:
		sc.press("coins")
	await _wait(0.2)
	_check(g.board.jar_count() == jars0 + 1 and CM.get_coins() == 350 and LM.lives() == lives0 and g.state == 1, "second chance: an Extra Jar for 150 coins, no life lost")
	g.give_up()
	_check(SM.find_modal("so_close") == null and g.state == 4 and LM.lives() == lives0 - 1, "the second chance is once per level")
	SM.close_all_modals()


# --- Phase 6: daily loop -----------------------------------------------------

func _test_calendar() -> void:
	var DY := root.get_node("DailyManager")
	_fresh(5)
	S.game()["time"]["max_seen"] = TM.now()
	var c0: int = CM.get_coins()
	_check(DY.can_claim_calendar() and not DY.claim_calendar().is_empty() and CM.get_coins() == c0 + 50, "day 1 calendar reward: 50 coins")
	_check(not DY.can_claim_calendar() and DY.claim_calendar().is_empty(), "the calendar can't be claimed twice in a day")
	TM.advance(86400)
	_check(DY.can_claim_calendar() and DY.calendar_index() == 1, "the next day unlocks day 2")
	DY.claim_calendar()
	TM.advance(86400 * 3)
	_check(DY.calendar_index() == 2 and DY.can_claim_calendar(), "missing days doesn't reset the calendar, it waits")
	S.game()["time"]["max_seen"] = TM.now() + 86400.0 * 5
	_check(not DY.can_claim_calendar(), "a clock set backwards grants nothing")
	S.game()["time"]["max_seen"] = TM.now()
	TM.debug_offset = 0.0
	S.game()["time"]["max_seen"] = TM.now()


func _test_missions() -> void:
	var DY := root.get_node("DailyManager")
	var GM := root.get_node("GameManager")
	_fresh(5)
	S.game()["time"]["max_seen"] = TM.now()
	DY.roll()
	var list: Array = DY.missions()
	var events := {}
	for m in list:
		events[DY.mission_def(m["id"])["event"]] = true
	_check(list.size() == 3 and events.size() == 3, "3 daily missions with different goals")
	var ids_a: Array = DY.pick_missions(DY.today_num()).map(func(m): return m["id"])
	var ids_b: Array = DY.pick_missions(DY.today_num()).map(func(m): return m["id"])
	var ids_c: Array = DY.pick_missions(DY.today_num() + 1).map(func(m): return m["id"])
	_check(ids_a == ids_b and ids_a != ids_c, "missions are picked by the date (same day, same missions)")
	# Finish every mission by sending its event.
	for m in list:
		var d: Dictionary = DY.mission_def(m["id"])
		GM.emit_event(String(d["event"]), int(d["target"]))
	_check(DY.missions_attention() and DY.mission_done(DY.missions()[0]), "game events fill mission progress")
	var c0: int = CM.get_coins()
	var got: int = DY.claim_mission(0)
	_check(got > 0 and CM.get_coins() == c0 + got and DY.claim_mission(0) == -1, "a mission pays its coins once")
	DY.claim_mission(1)
	DY.claim_mission(2)
	_check(DY.points() >= DY.chest_points() and DY.can_open_mission_chest(), "3 missions fill the mission chest")
	_check(not DY.claim_mission_chest().is_empty() and DY.claim_mission_chest().is_empty(), "the mission chest opens once a day")
	TM.advance(86400)
	DY.roll()
	_check(DY.points() == 0 and not DY.mission_done(DY.missions()[0]), "a new day brings new missions and an empty chest")
	TM.debug_offset = 0.0
	S.game()["time"]["max_seen"] = TM.now()


func _test_challenge_rules() -> void:
	var DY := root.get_node("DailyManager")
	_fresh(5)
	S.game()["time"]["max_seen"] = TM.now()
	var a: Dictionary = DY.challenge_level()
	var b: Dictionary = DY._build(DY.today_num())
	_check(JSON.stringify(a["jars"]) == JSON.stringify(b["jars"]), "the daily challenge is the same puzzle all day (seeded by the date)")
	var other: Dictionary = DY._build(DY.today_num() + 1)
	_check(JSON.stringify(a["jars"]) != JSON.stringify(other["jars"]) and (a["twists"] as Array).size() == 1, "tomorrow brings a different puzzle with its own twist")
	_check(bool(Solver.solve(Board.from_level(a), 80000)["solvable"]), "the daily challenge is solvable")
	var r: Dictionary = DY.complete_challenge()
	_check(int(r.get("coins", 0)) == 60 and int(r.get("streak", 0)) == 1 and DY.challenge_done_today(), "finishing the challenge pays 60 coins, streak 1")
	_check(DY.complete_challenge().is_empty(), "the challenge pays once a day")
	TM.advance(86400)
	_check(DY.challenge_streak() == 1 and int(DY.complete_challenge().get("streak", 0)) == 2, "the next day continues the streak")
	TM.advance(86400 * 2)
	_check(DY.challenge_streak() == 0 and int(DY.complete_challenge().get("streak", 0)) == 1, "skipping a day restarts the streak")
	_check(DY.challenge_history().size() == 3, "completed days are kept for the calendar")
	TM.debug_offset = 0.0
	S.game()["time"]["max_seen"] = TM.now()


func _test_challenge_play() -> void:
	var DY := root.get_node("DailyManager")
	_fresh(40)
	S.game()["time"]["max_seen"] = TM.now()
	for k in ["twist_wrapped", "twist_cloth", "twist_lock", "twist_tall"]:
		S.game()["tutorial_steps"][k] = true
	S.game()["lives"] = 0
	S.game()["last_life_time"] = LM.now()
	var level0: int = PM.current_level()
	var stars0: int = CM.get_stars()
	SM.start_daily()
	await _until(func() -> bool: return current_scene != null and current_scene.has_method("tap_jar") and current_scene.state == 1, 8.0)
	var g := current_scene
	_check(g.mode == "daily" and g.level_label.text == "Daily Challenge", "the daily challenge opens with 0 lives (free to play)")
	var sol: Array = Solver.solve(g.board, 80000)["moves"]
	for mv in sol:
		g.do_move(mv[0], mv[1])
	await _until(func() -> bool: return SM.find_modal("win") != null, 6.0)
	_check(DY.challenge_done_today() and PM.current_level() == level0 and CM.get_stars() == stars0, "winning the challenge doesn't touch level progress or stars")
	var win: Node = SM.find_modal("win")
	_check(win != null and win.continue_button.get_label() == "HOME", "the challenge win screen goes Home")
	SM.close_all_modals()


func _test_chests() -> void:
	var CH := root.get_node("ChestManager")
	_fresh(5)
	_check(CH.level_chest_due(10) and not CH.level_chest_due(11), "a level chest every 10 levels")
	var c10: Dictionary = CH.claim_level_chest(10)
	var c20: Dictionary = CH.claim_level_chest(20)
	_check(not c10.is_empty() and JSON.stringify(c10) != JSON.stringify(c20), "level chests rotate their contents")
	_check(CH.star_chests_available() == 0, "no star chest before spending stars")
	CM.add_stars(20, false)
	var spent := 0
	for t in RM.open_tasks(1):
		if spent >= 15:
			break
		var r: Dictionary = RM.complete_task(t["id"], 0)
		spent += int(r.get("cost", 0))
	var guard := 0
	while spent < 15 and guard < 20:
		guard += 1
		for t in RM.open_tasks(1):
			if spent >= 15:
				break
			spent += int(RM.complete_task(t["id"], 0).get("cost", 0))
	_check(CH.star_chests_available() == 1, "15 stars spent: a star chest (%d spent)" % spent)
	_check(not CH.claim_star_chest().is_empty() and CH.star_chests_available() == 0, "the star chest opens once")


func _test_achievement_tiers() -> void:
	var ACH := root.get_node("AchievementManager")
	_fresh(5)
	S.game()["stats"]["jars_filled"] = 150
	ACH.refresh()
	_check(ACH.title("jar_filler") == "Jar Filler I" and ACH.can_claim("jar_filler"), "tier I is claimable at 100 jars")
	ACH.claim("jar_filler")
	_check(ACH.title("jar_filler") == "Jar Filler II" and ACH.target("jar_filler") == 1000 and not ACH.can_claim("jar_filler"), "claiming tier I opens tier II (1,000 jars)")
	_check(ACH.definitions().size() >= 30, "30+ achievements (%d)" % ACH.definitions().size())
	S.game()["achievements"]["first_lid"] = {"progress": 1, "claimed": true}
	_check(ACH.is_claimed("first_lid") and not ACH.can_claim("first_lid"), "old saves: a claimed achievement counts as its first tier")


# --- Phase 7: live features --------------------------------------------------

func _board_of(jars: Array, extra: Dictionary = {}) -> Board:
	var lvl := {"capacity": 4, "jars": []}
	for j in jars:
		lvl["jars"].append({"c": j} if typeof(j) == TYPE_ARRAY else j)
	lvl.merge(extra, true)
	return Board.from_level(lvl)


func _test_twist_rules() -> void:
	# Cat: sealed jar, hops every N moves, undo (snapshot) restores it.
	var b := _board_of([[0, 0, 1], [1, 1, 0], [], []], {"cat": [2, 3], "cat_every": 2})
	_check(b.cat_jar() == 2 and b.is_sealed(2) and not b.can_move(0, 2), "the cat seals the jar it sits on")
	var snap := b.to_dict()
	b.apply_move(0, 3)
	_check(b.cat_jar() == 2, "the cat stays put until its move count")
	var r := b.apply_move(1, 0)
	_check(b.cat_jar() == 3 and int(r["cat_from"]) == 2 and int(r["cat_to"]) == 3, "every 2nd move the cat hops (2 -> 3)")
	var back := Board.from_level(snap)
	_check(back.cat_jar() == 2 and back.move_count == 0, "undo restores the cat's jar")
	var stuck := _board_of([{"c": [0, 1, 0, 1]}, {"c": [1, 0, 1, 0]}, [2, 2], []], {"cat": [0], "cat_every": 5})
	_check(stuck.has_useful_move(), "with the cat around, any legal move passes time (not stuck)")
	_check(Solver.solve(_board_of([[0, 0, 0, 1], [1, 1, 1, 0], [], []], {"cat": [2, 3, 2], "cat_every": 1}), 5000)["solvable"], "the solver plays around the cat")
	# Gift box: completing the jar reports the gift.
	var g := _board_of([{"c": [3, 3, 3], "gift": true}, [3], []])
	var rg := g.apply_move(1, 0)
	_check(bool(rg["completed"]) and bool(rg["gift"]), "completing a gift jar opens the gift")
	_check(Board.from_level(g.to_dict()).gifts[0], "gift jars survive save/undo snapshots")
	# Haat Helper gathers a candy from the tops into the empty jar.
	var h := _board_of([[0, 1, 2], [1, 2], [0, 2], []])
	var mv := h.helper_moves(2)
	_check(mv.size() == 3 and h.size_of(3) == 0, "Haat Helper plans 3 moves of the chosen candy (board untouched)")
	for m in mv:
		h.apply_move(int(m[0]), int(m[1]))
	_check(h.stacks[3] == [2, 2, 2], "...and gathers them into the empty jar")
	_check(_board_of([[0, 1], [1, 0]]).helper_moves(0).is_empty(), "no empty jar: the helper can't help")


func _test_album() -> void:
	var AL := root.get_node("AlbumManager")
	_fresh(5)
	var got: Array = AL.open_pack("test")
	_check(got.size() == 3 and AL.unique_count() >= 1 and AL.unique_count() <= 3, "a sticker pack gives 3 stickers")
	# Own every sticker of set 1 except the last, then complete it.
	var set1: Dictionary = AL.sets()[0]
	for st in set1["stickers"]:
		S.game()["album"]["owned"][st["id"]] = 1
	_check(AL.is_set_complete(set1["id"]) and AL.can_claim_set(set1["id"]), "9 of 9 stickers completes a set")
	var c0: int = CM.get_coins()
	var r: Dictionary = AL.claim_set(set1["id"])
	_check(int(r.get("coins", 0)) > 0 and CM.get_coins() > c0 and not AL.can_claim_set(set1["id"]), "a set reward pays once")
	# Duplicates become sticker stars; stars buy packs.
	S.game()["album"]["stars"] = 0
	var before: int = AL.sticker_stars()
	for k in 20:
		AL.open_pack("test")
	_check(AL.sticker_stars() > before, "duplicates turn into sticker stars (%d)" % AL.sticker_stars())
	S.game()["album"]["stars"] = 40
	var gold: Array = AL.buy_with_stars("pack_gold")
	_check(gold.size() == 4 and AL.sticker_stars() < 40 and int(gold[0]["rarity"]) >= 2, "the sticker shop sells packs for stars (gold: a 2-star or better)")
	_check(S.game_stat("stickers_unique") == AL.unique_count(), "unique stickers are counted for achievements")


func _test_events() -> void:
	var EV := root.get_node("EventManager")
	var IAP := root.get_node("IAPManager")
	_fresh(5)
	S.game()["time"]["max_seen"] = TM.now()
	EV.roll()
	var id0: String = EV.current().get("id", "")
	_check(id0 != "" and EV.currency() == 0, "a weekly event is running (%s)" % id0)
	_check(EV.on_win("normal") == 1 and EV.on_win("hard") == 2 and EV.on_win("super") == 3 and EV.currency() == 6, "wins drop event currency (+1, HARD +2, SUPER HARD +3)")
	_check(EV.can_claim(0, false) and not EV.can_claim(0, true), "milestone 1: free reward yes, pass reward needs the pass")
	EV.claim(0, false)
	_check(not EV.can_claim(0, false), "a milestone pays once")
	IAP.auto_confirm = true
	IAP.buy("event_pass", func(_ok: bool) -> void: pass)
	IAP.auto_confirm = false
	_check(EV.has_pass() and EV.can_claim(0, true), "the Event Pass unlocks the premium track")
	TM.advance(86400 * 7)
	EV.roll()
	_check(String(EV.current().get("id", "")) != id0 and EV.currency() == 0 and not EV.has_pass(), "next week: a new event with fresh progress")
	TM.debug_offset = 0.0
	S.game()["time"]["max_seen"] = TM.now()


func _test_race() -> void:
	var RC := root.get_node("RaceManager")
	var GM := root.get_node("GameManager")
	_fresh(20)
	S.game()["time"]["max_seen"] = TM.now()
	_check(RC.can_join() and RC.join() and RC.state() == "running", "join a Bazaar Race")
	_check(RC.standings().size() == 5 and not RC.can_join(), "you race 4 shopkeepers; one race at a time")
	var start: Array = RC.standings().map(func(r): return int(r["wins"]))
	TM.advance(3600 * 2)
	var later := 0
	for row in RC.standings():
		if not bool(row["player"]):
			later += int(row["wins"])
	_check(later > 0, "rivals keep winning while you're away (simulated by their timetable)")
	TM.debug_offset = 0.0
	for k in 7:
		GM.emit_event("win", 1)
	_check(RC.state() == "done" and RC.rank() == 1, "7 quick wins: you finish first")
	var c0: int = CM.get_coins()
	var r: Dictionary = RC.claim()
	_check(int(r.get("coins", 0)) == 300 and CM.get_coins() >= c0 + 300 and S.game_stat("race_wins") == 1, "1st place reward and a Racer win")
	_check(not RC.can_join() and RC.seconds_until_open() > 0, "the next race opens after a cooldown")
	TM.advance(3600 * 4)
	_check(RC.can_join(), "...a few hours later")
	TM.debug_offset = 0.0
	S.game()["time"]["max_seen"] = TM.now()


## A generated cat level, played through Gameplay with its planned solution.
func _test_cat_level_play() -> void:
	var n := 110
	var lvl: Dictionary = {}
	while n < 400:
		lvl = LevelGenerator.generate(n)
		if lvl.has("cat"):
			break
		n += 1
	_check(lvl.has("cat") and lvl.has("solution_moves"), "a cat level carries its route and solution (level %d)" % n)
	_fresh(n)
	for k in ["twist_wrapped", "twist_cloth", "twist_lock", "twist_tall", "twist_cat", "twist_gift", "helper"]:
		S.game()["tutorial_steps"][k] = true
	change_scene_to_file("res://scenes/gameplay/gameplay.tscn")
	await _until(func() -> bool: return current_scene != null and current_scene.has_method("tap_jar") and current_scene.state == 1, 8.0)
	var g := current_scene
	_check(g.view.cat_node.visible and g.view.cat_jar == g.board.cat_jar(), "Biralo sits on the board")
	for mv in lvl["solution_moves"]:
		if g.state != 1:
			break
		g.do_move(int(mv[0]), int(mv[1]))
	_check(g.board.is_won(), "the planned solution wins with the cat in play")
	SM.close_all_modals()


func _test_orders_and_move_limit() -> void:
	_fresh(25)
	S.game()["tutorial_steps"]["twist_wrapped"] = true
	change_scene_to_file("res://scenes/gameplay/gameplay.tscn")
	await _until(func() -> bool: return current_scene != null and current_scene.has_method("tap_jar") and current_scene.state == 1, 8.0)
	var g := current_scene
	_check(g.orders.size() >= 1 and g.order_cards != null, "level 25 introduces a customer order")
	if not g.orders.is_empty():
		var t := int(g.orders[0]["type"])
		var c0: int = CM.get_coins()
		g._on_jar_completed(t)
		_check(String(g.orders[0]["state"]) == "filled" and CM.get_coins() > c0, "filling the asked-for jar serves the customer (bonus coins)")
	SM.close_all_modals()
	# Move limit: the first SUPER HARD level from 60.
	var n := 60
	while n < 200 and int(LevelGenerator.generate(n).get("move_limit", 0)) == 0:
		n += 1
	_fresh(n)
	S.data["coins"] = 500
	for k in ["twist_wrapped", "twist_cloth", "twist_lock", "twist_tall", "helper"]:
		S.game()["tutorial_steps"][k] = true
	change_scene_to_file("res://scenes/gameplay/gameplay.tscn")
	await _until(func() -> bool: return current_scene != null and current_scene.has_method("tap_jar") and current_scene.state == 1, 8.0)
	g = current_scene
	_check(g.move_limit > 0 and g.moves_label != null, "SUPER HARD level %d has a move limit (%d)" % [n, g.move_limit])
	g.moves_used = g.move_limit
	g.out_of_moves()
	var pop: Node = SM.find_modal("out_of_moves")
	_check(pop != null, "running out of moves offers +5 moves")
	var limit0: int = g.move_limit
	if pop:
		pop.press("coins")
	_check(g.move_limit == limit0 + 5 and CM.get_coins() == 300 and g.state == 1, "+5 moves for 200 coins, the level goes on")
	g.out_of_moves()
	_check(SM.find_modal("out_of_moves") == null and g.state == 4, "the +5 moves offer is once per level")
	SM.close_all_modals()


# --- Phase 8: polish -----------------------------------------------------------

func _test_polish() -> void:
	_fresh(12)
	# Language: Nepali translations load and the UI font can draw Devanagari.
	S.set_setting("language", "ne")
	_check(TranslationServer.get_locale().begins_with("ne"), "Language setting switches the locale")
	_check(tr("Shop") != "Shop" and tr("Tasks") != "Tasks", "UI strings have Nepali translations (%s, %s)" % [tr("Shop"), tr("Tasks")])
	_check(tr("Level %d") % 5 != "Level 5" and (tr("Level %d") % 5).contains("5"), "format strings keep their placeholders in Nepali")
	var ui_kit = load("res://scripts/ui/ui_kit.gd")
	var heavy: Font = ui_kit.font(true)
	_check(not heavy.fallbacks.is_empty() and (heavy.fallbacks[0] as Font).has_char("न".unicode_at(0)), "the display font falls back to Baloo 2 for Devanagari")
	S.set_setting("language", "en")
	_check(tr("Shop") == "Shop", "back to English")
	# Accessibility.
	S.set_setting("colorblind", true)
	_check(load("res://scripts/visuals/candy_art.gd").colorblind, "colour-blind markings switch on")
	S.set_setting("colorblind", false)
	S.set_setting("text_scale", 1.15)
	_check(is_equal_approx(ui_kit.text_scale, 1.15) and (ui_kit.label("x", 40) as Label).get_theme_font_size("font_size") == 46, "Large text scales labels")
	S.set_setting("text_scale", 1.0)
	# Analytics: a level start and a win are logged.
	var AN := root.get_node("AnalyticsManager")
	AN.clear()
	change_scene_to_file("res://scenes/gameplay/gameplay.tscn")
	await _until(func() -> bool: return current_scene != null and current_scene.has_method("tap_jar") and current_scene.state == 1, 8.0)
	var g := current_scene
	for mv in Solver.solve(g.board, 80000)["moves"]:
		g.do_move(int(mv[0]), int(mv[1]))
	await _wait(0.5)
	var sm: Dictionary = AN.summary()
	_check(int(sm["counts"].get("level_start", 0)) >= 1 and int(sm["wins"]) >= 1 and float(sm["avg_moves"]) > 0.0, "analytics logs level_start and level_win with moves")
	var personal := false
	for r in AN.read():
		if r.has("name") or JSON.stringify(r).contains("Player"):
			personal = true
	_check(not personal, "analytics never logs the player's name")
	SM.close_all_modals()
	# Debug menu, theme, export settings.
	_check(load("res://scripts/ui/debug_menu.gd").open() != null, "the debug menu opens in debug builds")
	SM.close_all_modals()
	_check(String(ProjectSettings.get_setting("gui/theme/custom", "")) == "res://assets/ui/game_theme.tres" and ResourceLoader.exists("res://assets/ui/game_theme.tres"), "a project-wide game theme is set")
	_check(int(ProjectSettings.get_setting("display/window/handheld/orientation", 0)) == 1 and String(ProjectSettings.get_setting("display/window/stretch/aspect", "")) == "expand", "portrait, stretch aspect expand")


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
