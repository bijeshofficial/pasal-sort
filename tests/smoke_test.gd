extends SceneTree
## Headless smoke test for Pasal Sort.
##   godot --headless --path . --script res://tests/smoke_test.gd
## Uses its own save file (user://smoke_test_save.json), never the player's.
## Exits with code 0 when every check passes, 1 otherwise.
##
## Only pure-logic classes (Board, Solver, LevelGenerator, GameData) are
## referenced by name: UI/gameplay classes compile before autoloads exist in
## --script mode, so they are reached through scene instances instead.

const TEST_SAVE := "user://smoke_test_save.json"
const HUB := "res://scenes/main/hub.tscn"
const GAMEPLAY := "res://scenes/gameplay/gameplay.tscn"
const POPUPS := "res://scripts/ui/popups.gd"
const ST_PLAYING := 1
const ST_WON := 3
const ST_FAILED := 4

var failures: Array[String] = []
var checks := 0

var S: Node
var CM: Node
var PM: Node
var LM: Node
var BM: Node
var ACH: Node
var AD: Node
var AU: Node
var HM: Node
var SM: Node
var GM: Node
var IAP: Node
var VFX: Node
var POOL: Node
var DM: Node
var RM: Node


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	await process_frame
	S = root.get_node_or_null("SaveManager")
	if S == null:
		_fail("autoloads are not available")
		_finish()
		return
	CM = root.get_node("CurrencyManager")
	PM = root.get_node("ProgressionManager")
	LM = root.get_node("LivesManager")
	BM = root.get_node("BoosterManager")
	ACH = root.get_node("AchievementManager")
	AD = root.get_node("AdManager")
	AU = root.get_node("AudioManager")
	HM = root.get_node("HapticsManager")
	SM = root.get_node("ScreenManager")
	GM = root.get_node("GameManager")
	IAP = root.get_node("IAPManager")
	VFX = root.get_node("VFXManager")
	POOL = root.get_node("PoolManager")
	DM = root.get_node("DialogueManager")
	RM = root.get_node("RenovationManager")
	DM.instant = true
	IAP.offer_shown_this_session = true
	IAP.force_store = true

	S.set_save_path(TEST_SAVE)
	_remove_test_files()
	S.load_game()
	AD.mock_duration = 0.05
	AD.mock_fail_rate = 0.0

	_test_move_rules()
	_test_twist_rules()
	_test_solver_and_levels()
	_test_generator_sample()
	_test_shuffle()
	_test_lives_logic()
	await _test_level1_by_taps()
	await _test_tutorial_not_repeated()
	await _test_boosters_in_level()
	await _test_idle_hint()
	await _test_resume()
	await _test_give_up_and_leave()
	await _test_stuck_popup()
	await _test_autosort()
	await _test_hub_and_back()
	await _test_ads()
	await _test_shop_iap_achievements()
	_test_save_load()
	_test_corrupt_and_migration()
	_test_layout_aspects()
	_test_hooks()
	_finish()


# --- Board rules -------------------------------------------------------------

func _board(jars: Array, extra: Dictionary = {}) -> Board:
	var lvl := {"capacity": 4, "jars": []}
	for j in jars:
		lvl["jars"].append({"c": j} if typeof(j) == TYPE_ARRAY else j)
	lvl.merge(extra, true)
	return Board.from_level(lvl)


func _test_move_rules() -> void:
	var b := _board([[0, 1, 1], [2, 1], [], [0, 0, 2, 2]])
	_check(b.can_select(0) and b.can_select(1) and not b.can_select(2), "can select non-empty jars, not empty ones")
	_check(b.can_move(0, 1), "legal: same candy on top")
	_check(b.can_move(0, 2), "legal: empty jar takes anything")
	_check(not b.can_move(1, 3), "illegal: different candy on top")
	_check(not b.can_move(0, 0), "illegal: same jar")
	# Multi-candy move: the two 1s on top of jar 0 move together (jar 1 has 2 free).
	var r := b.apply_move(0, 1)
	_check(int(r.get("count", 0)) == 2 and b.stacks[0] == [0] and b.stacks[1] == [2, 1, 1, 1], "multi-candy move carries the whole same-type run (%s)" % [b.stacks])
	_check(not b.can_move(3, 1), "illegal: target full")
	# Partial move: only what fits.
	var p := _board([[1, 1, 1], [0, 1, 1], []])
	var r2 := p.apply_move(0, 1)
	_check(int(r2["count"]) == 1 and p.stacks[0] == [1, 1] and p.stacks[1] == [0, 1, 1, 1], "a run moves only as many candies as fit")
	# Completion.
	var c := _board([[2, 2, 2], [0, 2], []])
	var r3 := c.apply_move(1, 0)
	_check(bool(r3["completed"]) and c.is_done(0), "a jar with 4 of one candy completes")
	_check(not c.can_select(0), "a completed jar can't be selected")
	_check(not c.can_move(1, 0), "nothing can be poured into a completed jar")
	var w := _board([[0, 0, 0], [0], [1, 1, 1, 1]])
	var r4 := w.apply_move(1, 0)
	_check(bool(r4["won"]) and w.is_won(), "level complete when every non-empty jar is complete")
	# Stuck detection (pointless moves ignored).
	var stuck := _board([[0, 1, 0, 1], [1, 0, 1, 0]])
	_check(not stuck.has_useful_move(), "stuck: no legal move")
	var pointless := _board([{"c": [0, 1, 0, 1], "cloth": true}, {"c": [1, 0, 1, 0], "cloth": true}, [2, 2], []])
	_check(pointless.can_move(2, 3) and not pointless.has_useful_move(), "stuck ignores pouring a one-candy jar into an empty jar")
	_check(_board([[0, 1], [1], []]).has_useful_move(), "not stuck when a real move exists")
	# The 0s can only pour from one jar to the other and back; nothing completes.
	var loop := _board([[3, 0, 0], [2, 0, 0], [1, 2, 3, 1], [2, 3, 1, 2]])
	var t0 := Time.get_ticks_msec()
	_check(loop.has_useful_move() and loop.is_stuck(), "stuck: the only moves swap candies back and forth")
	_check(not _board([[0, 1, 1, 1], [1, 0, 0, 0], [0], []]).is_stuck(), "not stuck when a few moves lead to a full jar")
	_check(not Board.from_level(LevelGenerator.generate(40)).is_stuck() and Time.get_ticks_msec() - t0 < 600, "stuck check is quick (%d ms)" % (Time.get_ticks_msec() - t0))
	# Round trip through to_dict (used by undo and the save).
	var d := _board([[0, 1], [1, 0, 0], []], {})
	_check(Board.from_level(d.to_dict()).stacks == d.stacks, "board serialises and restores exactly")


func _test_twist_rules() -> void:
	# Wrapped: hidden candies open when they become the top.
	var h := Board.from_level({"capacity": 4, "jars": [{"c": [0, 1, 2], "h": [0, 1]}, {"c": [2]}, {"c": []}]})
	_check(h.hidden[0][1] and not h.hidden[0][2], "wrapped candies start hidden; the top one is visible")
	var r := h.apply_move(0, 1)
	_check(r["revealed"] == [0] and not h.hidden[0][1] and h.hidden[0][0], "a wrapper opens when its candy reaches the top")
	# Cloth: sealed until 2 jars are complete.
	var cl := Board.from_level({"capacity": 4, "cloth_after": 2, "jars": [{"c": [0, 1], "cloth": true}, {"c": [2, 2, 2]}, {"c": [3, 3, 3]}, {"c": [2]}, {"c": [3]}, {"c": [0, 0, 0]}, {"c": [1, 1, 1]}]})
	_check(cl.is_sealed(0) and not cl.can_select(0) and not cl.can_move(6, 0), "cloth jar can't give or take")
	cl.apply_move(3, 1)
	_check(cl.is_sealed(0), "cloth stays after 1 completed jar")
	var r2 := cl.apply_move(4, 2)
	_check(not cl.is_sealed(0) and r2["unsealed"] == [0], "cloth slides off after 2 completed jars")
	# Padlock: opens when a jar of its candy type completes.
	var lk := Board.from_level({"capacity": 4, "jars": [{"c": [0, 1], "lock": 2}, {"c": [2, 2, 2]}, {"c": [2]}, {"c": []}]})
	_check(lk.is_locked(0) and not lk.can_select(0), "padlocked jar is sealed")
	var r3 := lk.apply_move(2, 1)
	_check(not lk.is_locked(0) and r3["unsealed"] == [0], "padlock opens when its candy's jar is filled")
	# Tall jar holds capacity+2 but still completes at capacity.
	var tall := Board.from_level({"capacity": 4, "jars": [{"c": [0, 0, 0, 1, 1], "cap": 6}, {"c": [0]}, {"c": [1, 1]}]})
	_check(tall.space(0) == 1, "tall jar has room for 6")
	tall.apply_move(0, 2)
	tall.apply_move(1, 0)
	_check(tall.is_done(0) and tall.is_done(2), "tall jar completes with 4 of a kind")


# --- Solver, authored levels, generator --------------------------------------

func _test_solver_and_levels() -> void:
	var ok := true
	var bad := []
	for n in range(1, 31):
		var lvl := LevelGenerator.generate(n)
		var r := Solver.solve(Board.from_level(lvl), 60000)
		if not r["solvable"]:
			ok = false
			bad.append(n)
		# Every candy type appears exactly `capacity` times.
		for t in Board.from_level(lvl).type_counts().values():
			if int(t) != 4:
				ok = false
				bad.append("count %d" % n)
	_check(ok, "authored levels 1-30 are all solvable with 4 of each candy %s" % [bad])
	var l1 := LevelGenerator.generate(1)
	_check((l1["jars"] as Array).size() == 3 and int(l1["types"]) == 2, "level 1: 2 candy types in 3 jars")
	var b1 := Board.from_level(l1)
	for mv in l1["forced"]:
		b1.apply_move(mv[0], mv[1])
	_check(b1.is_won(), "level 1 forced tutorial sequence solves it in 3 moves")
	_check(LevelGenerator.generate(15)["twists"] == ["wrapped"] and LevelGenerator.generate(35)["twists"] == ["cloth"] and LevelGenerator.generate(55)["twists"] == ["lock"], "wrapped candies at 15, dhaka cloth at 35, padlock at 55")
	_check(LevelGenerator.tier_for(5) == "hard" and LevelGenerator.tier_for(10) == "super" and LevelGenerator.tier_for(11) == "easy", "sawtooth: every 5th HARD, every 10th SUPER HARD, then easier")
	var hint := Solver.hint(Board.from_level(LevelGenerator.generate(12)))
	_check(hint.size() >= 2 and Board.from_level(LevelGenerator.generate(12)).can_move(hint[0], hint[1]), "solver hint is a legal move")


func _test_generator_sample() -> void:
	var same := true
	var solvable := true
	for n in [31, 57, 99, 150, 233, 500]:
		var a := LevelGenerator.generate(n)
		var b := LevelGenerator.generate(n)
		if JSON.stringify(a) != JSON.stringify(b):
			same = false
		if not Solver.solve(Board.from_level(a), 80000)["solvable"]:
			solvable = false
	_check(same, "same level number -> identical board (seeded)")
	_check(solvable, "generated sample levels are solvable (full 31-400 run: tests/generator_test.gd)")
	_check(JSON.stringify(LevelGenerator.generate(41)["jars"]) != JSON.stringify(LevelGenerator.generate(42)["jars"]), "different levels differ")
	var t0 := Time.get_ticks_msec()
	var big := {}
	for n in range(171, 400):
		if LevelGenerator.params_for(n)["types"] == 12:
			big = LevelGenerator.build(n, LevelGenerator.params_for(n))
			break
	var ms := Time.get_ticks_msec() - t0
	_check(int(big.get("types", 0)) == 12 and ms < 1000, "a 12-type level generates in under 1 s (%d ms)" % ms)
	var jars_40 := (LevelGenerator.generate(41)["jars"] as Array).size()
	var jars_200 := (LevelGenerator.generate(201)["jars"] as Array).size()
	_check(jars_200 > jars_40 and int(LevelGenerator.generate(21)["types"]) > int(LevelGenerator.generate(4)["types"]), "difficulty ramps: more jars and candy types later (%d -> %d jars)" % [jars_40, jars_200])


func _test_shuffle() -> void:
	var rng := RandomNumberGenerator.new()
	var ok := true
	var counts_ok := true
	var locked_ok := true
	for n in [12, 33, 64, 128]:
		rng.seed = n
		var b := Board.from_level(LevelGenerator.generate(n))
		# Play a few moves so it's mid-game, then shuffle.
		for k in 3:
			var mvs := b.useful_moves()
			if mvs.is_empty():
				break
			b.apply_move(mvs[0][0], mvs[0][1])
		var before := b.type_counts()
		var done_before := []
		for i in b.jar_count():
			if b.is_done(i):
				done_before.append([i, b.stacks[i].duplicate()])
		if b.shuffle(rng, 30, 8000):
			if not Solver.solve(b, 60000)["solvable"]:
				ok = false
		if b.type_counts() != before:
			counts_ok = false
		for d in done_before:
			if b.stacks[d[0]] != d[1]:
				locked_ok = false
	_check(ok, "shuffle result is always solvable")
	_check(counts_ok, "shuffle preserves candy counts")
	_check(locked_ok, "shuffle leaves completed jars alone")


func _test_lives_logic() -> void:
	S.data = S.defaults()
	LM.time_offset = 0.0
	_check(LM.lives() == 5 and LM.is_full(), "fresh save: 5 lives")
	LM.lose_life()
	LM.lose_life()
	_check(LM.lives() == 3 and LM.countdown_text().contains(":"), "losing lives starts a countdown (%s)" % LM.countdown_text())
	S.save_game()
	# Simulated restart 65 minutes later: the save is reloaded, 2 lives come back.
	S.load_game()
	LM.time_offset = 65.0 * 60.0
	LM.tick()
	_check(LM.lives() == 5, "lives regenerate across a restart from saved real time (%d)" % LM.lives())
	LM.time_offset = 0.0
	LM.lose_life()
	S.game()["last_life_time"] = LM.now() + 99999.0
	var gained: int = LM.tick()
	_check(gained == 0 and LM.lives() == 4 and float(S.game()["last_life_time"]) <= LM.now() + 1.0, "clock tamper: a future timestamp is clamped, no free lives")
	_check(LM.can_play(3) and not LM.level_costs_life(10) and LM.level_costs_life(11), "levels 1-10 never cost lives")
	S.game()["lives"] = 0
	_check(not LM.can_play(20) and LM.can_play(5), "0 lives blocks level 20 but not tutorial levels")
	CM.add_coins(500, false)
	_check(LM.buy_refill() and LM.lives() == 5, "refill lives for coins")


# --- Level flow --------------------------------------------------------------

func _fresh(level: int) -> void:
	S.data = S.defaults()
	S.data["current_level"] = level
	if level > 1:
		for k in ["tap", "stack", "empty", "undo", "extra_jar", "shuffle", "twist_wrapped", "twist_cloth", "twist_lock", "twist_tall", "story_intro", "first_task"]:
			S.game()["tutorial_steps"][k] = true
	LM.time_offset = 0.0


func _open_level() -> Node:
	SM.close_all_modals()
	paused = false
	var old_id := current_scene.get_instance_id() if current_scene else 0
	change_scene_to_file(GAMEPLAY)
	await _until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id, 3.0)
	var g := current_scene
	var t := 0.0
	while g.state != ST_PLAYING and t < 4.0:
		await _wait(0.05)
		t += 0.05
	await _frames(2)
	return g


func _tap(g: Node, i: int) -> void:
	var p: Vector2 = g.view.jar_center(i)
	var screen: Vector2 = g.get_canvas_transform() * g.view.to_global(p)
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = screen
	ev.pressed = true
	root.push_input(ev, true)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = screen
	up.pressed = false
	root.push_input(up, true)
	await _frames(2)


func _test_level1_by_taps() -> void:
	_fresh(1)
	var coins_before: int = CM.get_coins()
	var lives_before: int = LM.lives()
	# Start from the hub like a player: Home -> Play.
	SM.hub_tab = "home"
	change_scene_to_file(HUB)
	await _wait(0.3)
	var hub := current_scene
	_check(hub != null and hub.home != null and hub.home.play_button.get_label() == "Level 1", "hub opens on Home with a Level 1 button")
	hub.home.play_button.pressed.emit()
	await _until(func() -> bool: return current_scene != null and current_scene.has_method("tap_jar") and current_scene.state == ST_PLAYING, 5.0)
	var g := current_scene
	_check(g.has_method("tap_jar"), "Play starts the level in one tap")
	_check(g.tutorial.step == "tap" and g.tutorial.hand.visible, "fresh save: level 1 starts with the hand tutorial")
	# A wrong jar does nothing during the forced tutorial.
	await _tap(g, 1)
	_check(g.selected == -1, "tutorial: only the highlighted jar responds")
	# Solve with simulated taps.
	for mv in [[0, 2], [1, 0], [1, 2]]:
		await _tap(g, mv[0])
		_check(g.selected == mv[0], "tap selects jar %d" % mv[0])
		await _tap(g, mv[1])
		await _wait(0.45)
	_check(g.board.is_won() and g.state == ST_WON, "level 1 solved by simulated taps")
	_check(PM.current_level() == 2, "win advances to level 2")
	_check(CM.get_coins() == coins_before + 10, "level reward: 10 coins (%d)" % (CM.get_coins() - coins_before))
	_check(CM.get_stars() == 1, "every win earns a star")
	_check(LM.lives() == lives_before, "winning never costs a life")
	_check(bool(S.game()["tutorial_steps"].get("tap", false)), "tutorial step saved as complete")
	_check(S.game_stat("jars_filled") == 2 and S.game_stat("candies_moved") == 6, "stats: jars filled and candies moved")
	await _until(func() -> bool: return SM.find_modal("win") != null, 4.0)
	var win: Node = SM.find_modal("win")
	_check(win != null, "win screen appears")
	_check(DM.played.has("intro"), "level 1: Hajurama introduces the story before the win screen")
	if win:
		await _wait(1.2)
		_check(win.coins_shown == 10, "win screen counts coins up")
		var c0: int = CM.get_coins()
		win.double_button.pressed.emit()
		await _until(func() -> bool: return win.doubled, 2.0)
		_check(CM.get_coins() == c0 + 10 and win.double_button.disabled, "x2 coins via rewarded ad, once")
		win.continue_button.pressed.emit()
		var gid := g.get_instance_id()
		await _until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != gid and current_scene.has_method("tap_jar") and not SM.is_busy(), 5.0)
		_check(current_scene.level == 2, "CONTINUE goes straight into level 2")
	_check(ACH.can_claim("first_lid"), "First Lid achievement unlocked")


func _test_tutorial_not_repeated() -> void:
	# Replay level 1 with the tutorial done: no hand.
	S.data["current_level"] = 1
	var g := await _open_level()
	_check(g.tutorial.step == "" and not g.tutorial.hand.visible, "completed tutorial never shows again")
	# Level 2 tutorial text shows once.
	S.data["current_level"] = 2
	S.game()["tutorial_steps"].erase("stack")
	g = await _open_level()
	_check(g.tutorial.step == "stack" and g.tutorial.text_panel.visible, "level 2 shows the stacking hint")


func _test_autosort() -> void:
	_fresh(12)
	var g := await _open_level()
	var real: Board = g.board
	g.board = _board([[0, 0], [0, 0], [1, 1, 1], [1], [2, 2, 2, 2], []])
	_check((g.autosort_moves() as Array).size() == 2, "auto-sort: only single-candy jars left -> 2 pours finish it")
	g.board = _board([[0, 1], [1, 0], [0, 0], [1, 1], []])
	_check((g.autosort_moves() as Array).is_empty(), "auto-sort waits while candies still alternate")
	g.board = _board([[0, 0], [0, 0], [1, 1, 1, 1], []])
	g.board.hidden[0] = [true, false]
	_check((g.autosort_moves() as Array).is_empty(), "auto-sort waits while a wrapped candy is hidden")
	g.board = real
	# Play the solver's solution until the game takes over, then it wins alone.
	var sol: Array = Solver.solve(g.board)["moves"]
	var played := 0
	for mv in sol:
		if g.state != ST_PLAYING:
			break
		g.do_move(mv[0], mv[1])
		played += 1
		await _wait(0.5)
	await _until(func() -> bool: return g.state == ST_WON, 8.0)
	_check(g.state == ST_WON and played < sol.size(), "auto-sort finishes an obvious ending (%d of %d moves by hand)" % [played, sol.size()])
	SM.close_all_modals()


func _test_boosters_in_level() -> void:
	_fresh(20)
	S.game()["boosters"]["undo"] = 10
	var g := await _open_level()
	var start: Array = g.board.stacks.duplicate(true)
	var mv: Array = g.board.useful_moves()[0]
	g.tap_jar(mv[0])
	g.tap_jar(mv[1])
	await _wait(0.5)
	_check(g.history.size() == 1 and g.moves == 1, "a move is recorded in the undo history")
	var undo0: int = BM.count("undo")
	_check(g.use_booster("undo") and g.board.stacks == start and BM.count("undo") == undo0 - 1, "Undo restores the board and uses one Undo")
	_check(SM.modal_count() == 0, "no popup while boosters are in stock")
	await _wait(0.5)
	_check(_view_matches(g), "undo: the jars on screen match the board")
	# Multiple undo steps.
	for k in 3:
		var m2: Array = g.board.useful_moves()[0]
		g.do_move(m2[0], m2[1])
		await _wait(0.1)
	g.use_booster("undo")
	g.use_booster("undo")
	_check(g.history.size() == 1, "undo walks back several steps")
	await _wait(0.5)
	# Extra jar.
	var n0: int = g.board.jar_count()
	_check(g.use_booster("extra_jar") and g.board.jar_count() == n0 + 1 and g.view.jars.size() == n0 + 1, "Extra Jar adds an empty jar")
	_check(not g.use_booster("extra_jar"), "only one Extra Jar per level")
	_check(g.use_booster("undo") and g.board.jar_count() == n0 + 1, "undo keeps the extra jar")
	await _wait(0.5)
	# Shuffle.
	var counts: Dictionary = g.board.type_counts()
	_check(g.use_booster("shuffle") and g.history.is_empty(), "Shuffle works and clears undo history")
	await _wait(1.3)
	_check(g.board.type_counts() == counts and Solver.solve(g.board, 60000)["solvable"], "shuffled board keeps candy counts and is solvable")
	_check(_view_matches(g), "shuffle: the jars on screen match the board")
	_check(not g.use_booster("undo"), "cannot undo past a Shuffle")
	# Booster at 0 -> purchase popup.
	S.game()["boosters"]["shuffle"] = 0
	S.data["coins"] = 1000
	g.use_booster("shuffle")
	var pop: Node = SM.find_modal("buy_booster")
	_check(pop != null, "booster at 0 opens the buy popup")
	if pop:
		pop.press("buy")
		await _wait(1.4)
		_check(int(S.data["coins"]) == 1000 - int(GameData.price("shuffle")), "buying a booster costs coins, then it is used (coins %d)" % int(S.data["coins"]))
	_check(g.boosters_used, "level remembers boosters were used")
	SM.close_all_modals()


func _view_matches(g: Node) -> bool:
	for i in g.board.jar_count():
		var list: Array = g.view.stacks[i]
		if list.size() != g.board.stacks[i].size():
			return false
		for k in list.size():
			if list[k].type != int(g.board.stacks[i][k]):
				return false
	return true


func _test_idle_hint() -> void:
	_fresh(13)
	var g := await _open_level()
	S.set_setting("hints", false)
	g._idle = 999.0
	await _wait(0.3)
	_check(not g._hint_shown, "idle hint respects the Settings toggle")
	S.set_setting("hints", true)
	g._idle = 999.0
	await _wait(0.5)
	var pulsing := false
	for j in g.view.jars:
		if not j.scale.is_equal_approx(Vector2.ONE):
			pulsing = true
	_check(g._hint_shown and pulsing, "after idling, a useful move gently pulses")


func _test_resume() -> void:
	_fresh(22)
	var g := await _open_level()
	for k in 3:
		var mv: Array = g.board.useful_moves()[0]
		g.do_move(mv[0], mv[1])
		await _wait(0.1)
	var stacks: Array = g.board.stacks.duplicate(true)
	await _wait(0.7)  # debounced save
	var ip: Variant = S.game()["in_progress_level"]
	_check(typeof(ip) == TYPE_DICTIONARY and int(ip["level"]) == 22 and (ip["history"] as Array).size() == 3, "in-progress board is saved after moves")
	# "Kill" the app: reload the save from disk and reopen the level.
	S.load_game()
	var lives_before: int = LM.lives()
	g = await _open_level()
	_check(g.resumed and g.board.stacks == stacks and g.history.size() == 3, "relaunch restores the board and undo history")
	_check(LM.lives() == lives_before, "closing the app mid-level costs no life")
	_check(_view_matches(g), "restored jars match on screen")
	_check(g.use_booster("undo"), "undo works after resuming")


func _test_give_up_and_leave() -> void:
	_fresh(15)
	var g := await _open_level()
	var mv: Array = g.board.useful_moves()[0]
	g.do_move(mv[0], mv[1])
	var lives0: int = LM.lives()
	g.give_up()
	var sc: Node = SM.find_modal("so_close")
	_check(sc != null and LM.lives() == lives0 and g.state == ST_PLAYING, "give up first offers a second chance (So close!)")
	if sc:
		sc.press("give_up")
	_check(LM.lives() == lives0 - 1 and g.state == ST_FAILED, "give up on level 15 costs 1 life")
	_check(S.game()["in_progress_level"] == null, "give up clears the saved board")
	_check(SM.find_modal("failed") != null, "failed popup offers Retry / Home")
	SM.close_all_modals()
	# Restart after a move asks and costs a life.
	g = await _open_level()
	mv = g.board.useful_moves()[0]
	g.do_move(mv[0], mv[1])
	var lives1: int = LM.lives()
	g.leave_level("restart")
	var confirm: Node = SM.find_modal("confirm")
	_check(confirm != null and confirm.body_label.text.contains("cost 1 life"), "restart after a move warns: leaving will cost 1 life")
	if confirm:
		confirm.press("yes")
	var gid1 := g.get_instance_id()
	await _until(func() -> bool: return not SM.is_busy() and current_scene != null and current_scene.get_instance_id() != gid1, 4.0)
	_check(LM.lives() == lives1 - 1, "restart after a move costs a life")
	# Restart always asks, even before any move (and is then free).
	g = await _open_level()
	var lives_r: int = LM.lives()
	g.leave_level("restart")
	var ask: Node = SM.find_modal("confirm")
	_check(ask != null and current_scene == g, "restart asks for confirmation even with no moves")
	if ask:
		ask.press("yes")
	var gid_r := g.get_instance_id()
	await _until(func() -> bool: return not SM.is_busy() and current_scene != null and current_scene.get_instance_id() != gid_r, 4.0)
	_check(LM.lives() == lives_r and current_scene.has_method("tap_jar"), "confirmed restart before moving costs no life")
	# Leaving without moving is free.
	g = await _open_level()
	var lives2: int = LM.lives()
	g.leave_level("home")
	var gid2 := g.get_instance_id()
	await _until(func() -> bool: return not SM.is_busy() and current_scene != null and current_scene.get_instance_id() != gid2, 4.0)
	_check(LM.lives() == lives2 and current_scene.name == "Hub", "leaving before any move is free")
	# Tutorial levels never cost lives.
	_fresh(6)
	g = await _open_level()
	mv = g.board.useful_moves()[0]
	g.do_move(mv[0], mv[1])
	g.confirm_fail()
	_check(LM.lives() == 5, "give up on level 6 is free")
	SM.close_all_modals()
	# Out of lives: Play shows the popup instead.
	_fresh(30)
	S.game()["lives"] = 0
	S.game()["last_life_time"] = LM.now()
	SM.hub_tab = "home"
	change_scene_to_file(HUB)
	await _wait(0.3)
	current_scene.home.play_button.pressed.emit()
	await _wait(0.2)
	var ool: Node = SM.find_modal("out_of_lives")
	_check(ool != null and current_scene.name == "Hub", "0 lives: Play shows the Out of lives popup")
	if ool:
		ool.press("ad")
		await _until(func() -> bool: return LM.lives() == 1, 2.0)
		_check(LM.lives() == 1, "+1 life via rewarded ad")
	SM.close_all_modals()


func _test_stuck_popup() -> void:
	_fresh(12)
	var g := await _open_level()
	# Force a stuck board.
	g.board = Board.from_level({"capacity": 4, "jars": [{"c": [0, 1, 0, 1]}, {"c": [1, 0, 1, 0]}]})
	g.view.board = g.board
	g.view.build(g.board, g.view.area, {}, "classic", false)
	g._stuck_shown = false
	g._check_stuck()
	var pop: Node = SM.find_modal("stuck")
	_check(pop != null, "no legal move -> Stuck? popup")
	if pop:
		_check(pop.button("undo") != null and pop.button("extra_jar") != null and pop.button("shuffle") != null and pop.button("give_up") != null, "Stuck offers Undo, Extra Jar, Shuffle and Give up")
		var ej: int = BM.count("extra_jar")
		pop.press("extra_jar")
		await _wait(0.3)
		_check(g.board.jar_count() == 3 and BM.count("extra_jar") == ej - 1, "level 12: the Stuck popup fix adds a jar and uses a booster")
	SM.close_all_modals()
	# On tutorial levels the stuck fix is free.
	_fresh(7)
	g = await _open_level()
	g.board = Board.from_level({"capacity": 4, "jars": [{"c": [0, 1, 0, 1]}, {"c": [1, 0, 1, 0]}]})
	g.view.board = g.board
	g.view.build(g.board, g.view.area, {}, "classic", false)
	g._stuck_shown = false
	g._check_stuck()
	pop = SM.find_modal("stuck")
	var found := pop != null
	var ej2: int = BM.count("extra_jar")
	if pop:
		pop.press("extra_jar")
		await _wait(0.3)
	_check(found and g.board.jar_count() == 3 and BM.count("extra_jar") == ej2, "levels 1-10: the Stuck popup fix is free (jars %d, boosters %d->%d)" % [g.board.jar_count(), ej2, BM.count("extra_jar")])
	SM.close_all_modals()


func _test_hub_and_back() -> void:
	_fresh(12)
	S.data["coins"] = 50
	SM.hub_tab = "home"
	change_scene_to_file(HUB)
	await _wait(0.3)
	var hub := current_scene
	hub.select_tab(0)
	_check(hub.current == 0 and hub.nav.current == 0, "bottom nav switches to Shop")
	GM.handle_back()
	_check(hub.current == 1, "back on Shop returns to Home")
	# On Home a drag pans the renovation scene instead of switching tabs.
	# (Zoom in first: headless windows are wide enough to show the whole width.)
	hub.home_view.zoom_at(hub.home_view.size * 0.5, hub.home_view.zoom * 1.6)
	var pos0: Vector2 = hub.home_view.scene.position
	for k in 3:
		var ev: InputEvent
		if k == 0:
			ev = InputEventScreenTouch.new()
			ev.pressed = true
			ev.position = Vector2(900, 1000)
		elif k == 1:
			ev = InputEventScreenDrag.new()
			ev.position = Vector2(500, 1005)
			ev.relative = Vector2(-400, 5)
		else:
			ev = InputEventScreenTouch.new()
			ev.pressed = false
			ev.position = Vector2(500, 1005)
		root.push_input(ev, true)
		await _frames(1)
	_check(hub.current == 1 and hub.home_view.scene.position.x < pos0.x, "dragging Home pans the scene (%.0f -> %.0f) and keeps the tab" % [pos0.x, hub.home_view.scene.position.x])
	# Swiping on the nav bar still changes tabs.
	var ny: float = hub.nav.get_global_rect().get_center().y
	for k in 3:
		var ev: InputEvent
		if k == 1:
			ev = InputEventScreenDrag.new()
			ev.position = Vector2(300, ny + 10)
			ev.relative = Vector2(-600, 10)
		else:
			ev = InputEventScreenTouch.new()
			ev.pressed = k == 0
			ev.position = Vector2(900, ny) if k == 0 else Vector2(300, ny + 10)
		root.push_input(ev, true)
		await _frames(1)
	_check(hub.current == 2, "swipe left on the nav bar moves to the Profile tab")
	hub.select_tab(1)
	GM.handle_back()
	var q: Node = SM.find_modal("confirm")
	_check(q != null, "back on Home asks to quit")
	SM.close_all_modals()
	hub.coin_chip.plus_pressed.emit()
	_check(hub.current == 0, "coin + jumps to the Shop")
	# Back in gameplay opens Pause.
	var g := await _open_level()
	GM.handle_back()
	_check(SM.find_modal("pause") != null and paused, "back during a level opens Pause")
	GM.handle_back()
	await _frames(2)
	_check(SM.find_modal("pause") == null and not paused, "back again resumes")
	# App pause saves the board.
	var mv: Array = g.board.useful_moves()[0]
	g.do_move(mv[0], mv[1])
	GM.app_paused.emit()
	_check(typeof(S.game()["in_progress_level"]) == TYPE_DICTIONARY and SM.find_modal("pause") != null, "app pause saves the level and opens Pause")
	SM.close_all_modals()
	paused = false


func _test_ads() -> void:
	AD.reset_session_state()
	AD.mock_fail_rate = 0.0
	var got := [null]
	AD.show_rewarded("test", func(ok: bool) -> void: got[0] = ok)
	await _until(func() -> bool: return got[0] != null, 2.0)
	_check(got[0] == true, "mock rewarded ad success path")
	AD.mock_fail_rate = 1.0
	got[0] = null
	S.game()["daily_free_claimed_date"] = ""
	var coins0: int = CM.get_coins()
	SM.hub_tab = "shop"
	change_scene_to_file(HUB)
	await _wait(0.3)
	current_scene.shop.claim_daily()
	await _wait(0.4)
	_check(CM.get_coins() == coins0 and VFX.last_toast().contains("not available"), "failed ad grants nothing and shows a friendly toast")
	AD.mock_fail_rate = 0.0
	current_scene.shop.claim_daily()
	await _wait(0.4)
	_check(CM.get_coins() == coins0 + 50 and not current_scene.shop.daily_available(), "daily free gift via ad, once per day")
	SM.close_all_modals()
	# Rewarded ads only: never an ad break between levels.
	AD.reset_session_state()
	for k in 10:
		AD.on_run_finished()
	_check(not AD.can_show_interstitial(), "no interstitial ads, ever (rewarded only)")


func _test_shop_iap_achievements() -> void:
	_fresh(12)
	S.data["coins"] = 1000
	SM.hub_tab = "shop"
	change_scene_to_file(HUB)
	await _wait(0.3)
	var shop: Node = current_scene.shop
	# Cosmetic purchase (via its confirm popup).
	shop.press_cosmetic("jar_blue")
	var c: Node = SM.find_modal("confirm")
	if c:
		c.press("yes")
	_check(PM.is_owned("jar_blue") and PM.selected_cosmetic("jar") == "jar_blue" and CM.get_coins() == 850, "buy a jar skin: owned, selected immediately, coins spent")
	shop.press_cosmetic("jar_classic")
	_check(PM.selected_cosmetic("jar") == "jar_classic", "switch back to a free skin")
	S.data["coins"] = 100
	shop.press_cosmetic("theme_snow")
	_check(SM.find_modal("confirm") == null and not PM.is_owned("theme_snow"), "can't buy what you can't afford")
	# Bundles.
	S.data["coins"] = 850
	var u0: int = BM.count("undo")
	_check(shop.buy_bundle("bundle_undo") and BM.count("undo") == u0 + 5, "Undo x5 bundle")
	# Mock IAP with the TEST PURCHASE popup.
	var done := [null]
	IAP.buy("coins_small", func(ok: bool) -> void: done[0] = ok)
	var tp: Node = SM.top_modal()
	_check(tp != null and tp.spec.get("title", "") == "TEST PURCHASE", "IAP shows a TEST PURCHASE confirmation")
	var coins1: int = CM.get_coins()
	if tp:
		tp.press("1")
	_check(done[0] == true and CM.get_coins() == coins1 + 500, "mock purchase grants coins")
	SM.close_all_modals()
	# Achievements.
	S.game()["stats"]["jars_filled"] = 1
	ACH.refresh()
	var coins2: int = CM.get_coins()
	_check(ACH.can_claim("first_lid") and ACH.claimable_count() >= 1, "achievement becomes claimable")
	var reward: Dictionary = ACH.claim("first_lid")
	_check(int(reward.get("coins", 0)) == 20 and CM.get_coins() == coins2 + 20 and ACH.claim("first_lid").is_empty(), "claim pays once")
	S.data["unlocked_items"] = ["jar_steel", "jar_blue", "jar_festival", "wrap_striped", "theme_hill"]
	_check(ACH.is_complete("collector"), "Collector: own 5 cosmetics")
	S.data["current_level"] = 11
	_check(ACH.is_complete("pasal_opened"), "Pasal Opened after level 10")
	current_scene.select_tab(2)
	await _wait(0.2)
	_check(current_scene.nav.has_dot(2), "profile tab shows a red dot for claimable achievements")
	# Profile edits persist.
	current_scene.profile.set_player_name("  Maya  ")
	current_scene.profile.set_avatar(3)
	S.load_game()
	_check(S.game()["profile"]["name"] == "Maya" and int(S.game()["profile"]["avatar"]) == 3, "profile name and avatar persist")
	# Milestone gift every 10 levels; every win is a star.
	_fresh(10)
	var sum: Dictionary = PM.complete_level(10, false)
	_check(sum["milestone"] and int(sum["stars"]) == 1 and CM.get_stars() == 1, "level 10: milestone gift and a star")
	var CH := root.get_node("ChestManager")
	var gift: Dictionary = CH.claim_level_chest(10)
	_check(int(gift.get("coins", 0)) == 100 and CH.claim_level_chest(10).is_empty() and not CH.level_chest_due(10), "the level chest opens once")
	_check(PM.coin_reward(25) == 15 and PM.coin_reward(20) == 25 and PM.coin_reward(12) == 10, "coins: 10, HARD 15, SUPER HARD 25")


func _test_save_load() -> void:
	S.data = S.defaults()
	S.data["coins"] = 0
	CM.add_coins(345, false)
	S.data["current_level"] = 88
	BM.grant("shuffle", 4, false)
	S.set_setting("music", false)
	S.set_setting("hints", false)
	S.save_game()
	_check(FileAccess.file_exists(TEST_SAVE) and not FileAccess.file_exists(TEST_SAVE.get_basename() + ".tmp"), "atomic save leaves no temp file")
	S.data = {}
	S.load_game()
	_check(CM.get_coins() == 345 and PM.current_level() == 88 and BM.count("shuffle") == 5, "coins, level and boosters survive save + reload")
	_check(S.get_setting("music") == false and S.get_setting("hints") == false and S.get_setting("sound") == true, "settings persist")
	S.data["settings"]["sfx_volume"] = 0.4
	S.data["settings"]["music_volume"] = 0.25
	S.save_game()
	S.data = {}
	S.load_game()
	AU.apply_volumes()
	var sfx_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	_check(is_equal_approx(S.get_volume("sfx_volume"), 0.4) and is_equal_approx(S.get_volume("music_volume"), 0.25) and absf(sfx_db - (AU.SFX_BASE_DB + linear_to_db(0.4))) < 0.05, "volume sliders persist and set the bus level (%.1f dB)" % sfx_db)
	S.data["settings"]["sfx_volume"] = 1.0
	S.data["settings"]["music_volume"] = 0.7
	AU.apply_volumes()
	_check(S.game().has("tutorial_steps") and S.game().has("achievements") and S.game()["achievements"].has("bazaar_legend"), "game block has every default field")
	S.set_setting("music", true)
	S.set_setting("hints", true)


func _test_corrupt_and_migration() -> void:
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	S.load_game()
	_check(FileAccess.file_exists(S.corrupt_path()) and CM.get_coins() == 200 and PM.current_level() == 1, "corrupt save is backed up and defaults load (200 starting coins)")
	var old := {"coins": 70, "lives": 2, "boosters": {"undo": 9}}
	var m: Dictionary = S.migrate(old)
	_check(int(m["version"]) == S.CURRENT_VERSION and int(m["game"]["lives"]) == 2 and int(m["game"]["boosters"]["undo"]) == 9, "v0 save migrates lives/boosters into the game block")
	S.data = S._merge(S.defaults(), m)
	_check(S.game()["boosters"].has("shuffle") and S.game()["stats"].has("jars_filled"), "merge adds missing fields to old saves")


func _test_layout_aspects() -> void:
	var ok := true
	var sizes := [Vector2(1080, 1920), Vector2(1080, 2400), Vector2(1440, 1920)]
	for vp in sizes:
		S.data = S.defaults()
		for n in [1, 12, 60, 201]:
			var lvl := LevelGenerator.generate(n)
			var b := Board.from_level(lvl)
			b.add_jar()
			var view: Node = load("res://scripts/gameplay/board_view.gd").new()
			root.add_child(view)
			var area := Rect2(24, 230, vp.x - 48, vp.y - 560)
			view.build(b, area, {}, "classic", false)
			if view.jar_width < 110.0:
				ok = false
			for i in view.jars.size():
				var j: Node2D = view.jars[i]
				var top: float = j.home_position.y - j.total_height()
				if j.home_position.x - view.jar_width * 0.5 < 0 or j.home_position.x + view.jar_width * 0.5 > vp.x or top < area.position.y - 10 or j.home_position.y > area.end.y + 10:
					ok = false
			view.free()
	_check(ok, "jars fit on screen at 1080x1920, 1080x2400 and 1440x1920 (min width 110)")


func _test_hooks() -> void:
	AU.played_log.clear()
	var hooks := ["button_click", "gameplay_interaction", "success", "perfect", "failure", "combo", "reward", "level_complete", "coin_pickup", "clack", "nope", "lid_pop", "shuffle", "extra_jar", "undo", "shutter", "reveal", "unlock", "cloth", "star", "poof", "renovate", "chest_open", "page_turn", "area_complete", "tick"]
	for id in hooks:
		AU.play(id)
	_check(AU.played_log.size() == hooks.size(), "all audio hooks resolve to a sound")
	S.set_setting("haptics", true)
	var h0: int = HM.fired_count
	HM.light()
	S.set_setting("haptics", false)
	HM.light()
	_check(HM.fired_count == h0 + 1, "haptics fire and respect the setting")
	S.set_setting("haptics", true)
	_check(POOL.created_count > 0 and VFX.sparkle_count > 0, "pooled VFX were used (sparkles)")


# --- Helpers -----------------------------------------------------------------

func _check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  ok   ", label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	failures.append(label)
	print("  FAIL ", label)


func _wait(sec: float) -> void:
	await create_timer(sec, true).timeout


func _frames(n: int) -> void:
	for i in n:
		await process_frame


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
	_remove_test_files()
	print("\n%d checks, %d failed" % [checks, failures.size()])
	for f in failures:
		print("  - ", f)
	if current_scene:
		current_scene.queue_free()
	await _frames(3)
	quit(0 if failures.is_empty() else 1)
