class_name Gameplay
extends Node2D
## One level: tap a jar to select it, tap another to move the top candies.
## Owns the Board (rules), the BoardView (visuals), the HUD, boosters,
## undo history, the in-progress save, stuck detection, lives and the win flow.

enum State { INTRO, PLAYING, BUSY, WON, FAILED }

const BoardViewScript := preload("res://scripts/gameplay/board_view.gd")
const WinPanelScript := preload("res://scripts/ui/win_panel.gd")
const CharacterScene := preload("res://scenes/components/character_visual.tscn")
const SAVE_DELAY := 0.4

var level := 1
var level_data: Dictionary = {}
var board: Board
var view: BoardView
var history: Array = []        # [{board, move: [a, b], count, completed}]
var moves := 0
var extra_used := false
var boosters_used := false
var selected := -1
var state := State.INTRO
var resumed := false
var tutorial: TutorialDirector
var booster_buttons: Dictionary = {}
var hud: CanvasLayer
var backdrop: ShopBackdrop
var level_label: Label
var pause_button: GameButton
var restart_button: GameButton
var camera: Camera2D

var _save_timer := -1.0
var _idle := 0.0
var _hint_shown := false
var _hint_task := -1
var _hint_mutex := Mutex.new()
var _hint_result: Array = []
var _hint_ready := false
var _t := 0.0
var _stuck_shown := false
var _summary: Dictionary = {}
var _new_achievement := false


func _ready() -> void:
	VFXManager.toast_anchor = "bottom"
	level = ProgressionManager.current_level()
	level_data = ProgressionManager.get_level(level)
	var vp := get_viewport_rect().size
	var insets := GameManager.get_safe_insets()

	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)
	camera.make_current()
	VFXManager.register_camera(camera)

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	backdrop = ShopBackdrop.new()
	backdrop.theme_id = ProgressionManager.selected_cosmetic("theme")
	backdrop.horizon = 0.86
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(backdrop)

	view = BoardViewScript.new()
	add_child(view)

	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	_build_top_bar(insets)
	_build_booster_bar(vp, insets)

	var restored := _try_resume()
	if not restored:
		board = Board.from_level(level_data)
	var top := insets.x + 230.0
	var bottom := insets.y + 330.0
	var area := Rect2(24, top, vp.x - 48, vp.y - top - bottom)
	view.build(board, area, ProgressionManager.selected_cosmetic_data("jar"), String(ProgressionManager.selected_cosmetic_data("wrapper").get("style", "classic")))

	tutorial = TutorialDirector.new()
	add_child(tutorial)
	tutorial.setup(self, hud, level_data, moves)

	GameManager.app_paused.connect(_on_app_paused)
	ProgressionManager.prefetch(level + 1)
	AdManager.banner_opportunity("gameplay")

	_after(view.intro_time(), _on_intro_done)


func _on_intro_done() -> void:
	if state != State.INTRO:
		return
	state = State.PLAYING
	var twists: Array = level_data.get("twists", [])
	_show_twist_cards(twists.duplicate(), func() -> void:
		tutorial.start()
		if resumed:
			VFXManager.toast("Welcome back! Your jars are just as you left them.")
		_check_stuck())


func _show_twist_cards(list: Array, done: Callable) -> void:
	while not list.is_empty() and ProgressionManager.tutorial_done("twist_" + String(list[0])):
		list.pop_front()
	if list.is_empty():
		done.call()
		return
	var id: String = list.pop_front()
	TutorialDirector.twist_card(id, func() -> void:
		ProgressionManager.mark_tutorial("twist_" + id)
		_show_twist_cards(list, done))


# --- HUD ---------------------------------------------------------------------

func _build_top_bar(insets: Vector2) -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(30, insets.x + 28)
	bar.size = Vector2(get_viewport_rect().size.x - 60, 150)
	bar.add_theme_constant_override("separation", 20)
	hud.add_child(bar)
	pause_button = UIKit.button("", "secondary", "pause", 54, Vector2(136, 136))
	pause_button.pressed.connect(open_pause)
	bar.add_child(pause_button)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 4)
	bar.add_child(mid)
	level_label = UIKit.title("Level %d" % level, 76)
	mid.add_child(level_label)
	var badge := UIKit.tier_badge(String(level_data.get("tier", "normal")), 30)
	if badge:
		var holder := CenterContainer.new()
		holder.add_child(badge)
		mid.add_child(holder)
	restart_button = UIKit.button("", "secondary", "retry", 54, Vector2(136, 136))
	restart_button.pressed.connect(func() -> void: leave_level("restart"))
	bar.add_child(restart_button)


func _build_booster_bar(vp: Vector2, insets: Vector2) -> void:
	var strip := Control.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.position = Vector2(0, vp.y - insets.y - 300)
	strip.size = Vector2(vp.x, 300 + insets.y)
	strip.draw.connect(func() -> void:
		var tray := Rect2(36, 40, strip.size.x - 72, 250)
		strip.draw_colored_polygon(DrawKit.rounded_rect(tray, 70, 8), Color(0.07, 0.03, 0.22, 0.5))
		DrawKit.outline(strip, DrawKit.rounded_rect(tray, 70, 8), Color(1, 1, 1, 0.18), 4.0))
	hud.add_child(strip)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 60)
	row.position = Vector2(0, vp.y - insets.y - 290)
	row.size = Vector2(vp.x, 260)
	hud.add_child(row)
	for id in BoosterManager.IDS:
		var b := BoosterButton.new()
		b.setup(id)
		b.pressed.connect(func() -> void: use_booster(id))
		row.add_child(b)
		booster_buttons[id] = b


func hint_text_y() -> float:
	return GameManager.get_safe_insets().x + 200.0


func is_playing() -> bool:
	return state == State.PLAYING and not ScreenManager.has_modal() and not AdManager.is_showing() and not ScreenManager.is_busy()


# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		var p: Vector2 = get_canvas_transform().affine_inverse() * event.position
		handle_tap(view.to_local(p))


## Board-space tap (tests call this too).
func handle_tap(p: Vector2) -> void:
	if not is_playing():
		return
	var i := view.jar_at(p)
	if i < 0:
		if selected >= 0:
			_deselect()
		return
	tap_jar(i)


func tap_jar(i: int) -> void:
	if not is_playing() or i < 0 or i >= board.jar_count():
		return
	_idle = 0.0
	_clear_hint()
	if not tutorial.allows_tap(i, selected):
		return
	if selected < 0:
		if board.can_select(i):
			selected = i
			view.select(i, true)
			AudioManager.play("gameplay_interaction")
			HapticsManager.light()
			tutorial.on_select(i)
		elif board.is_sealed(i):
			_nope(i)
			if board.is_cloth_on(i):
				VFXManager.toast("Covered! Fill %d jars to lift the cloth." % board.cloth_after)
			else:
				VFXManager.toast("Locked! Fill a jar of %s to open it." % GameData.candy(int(board.locks[i]))["name"])
		elif board.is_done(i):
			view.jars[i].bounce(1.04)
		return
	if i == selected:
		_deselect()
		return
	if board.can_move(selected, i):
		do_move(selected, i)
	else:
		_nope(i)
		_deselect()


func _nope(i: int) -> void:
	view.jars[i].wobble()
	AudioManager.play("nope")
	HapticsManager.light()


func _deselect() -> void:
	if selected >= 0:
		view.select(selected, false)
		AudioManager.play("deselect", 1.0, -6.0)
	selected = -1


func do_move(a: int, b: int) -> void:
	var before := board.duplicate_board()
	var snapshot := board.to_dict()
	view.select(a, false)
	selected = -1
	var result := board.apply_move(a, b)
	if result.is_empty():
		return
	history.append({"board": snapshot, "move": [a, b], "count": result["count"], "completed": result["completed"]})
	moves += 1
	SaveManager.add_game_stat("candies_moved", int(result["count"]))
	if result["completed"]:
		SaveManager.add_game_stat("jars_filled")
	var dur := view.animate_move(a, b, result)
	tutorial.on_move(a, b, before)
	_queue_save()
	if result["won"]:
		_win(dur)
		return
	_after(dur + 0.15, _check_stuck)


func _check_stuck() -> void:
	if state != State.PLAYING or board.is_won() or _stuck_shown:
		return
	if not board.has_useful_move():
		show_stuck()


# --- Boosters ----------------------------------------------------------------

func free_fixes() -> bool:
	return not LivesManager.level_costs_life(level)


## Uses a booster. `free` skips the inventory (Stuck popup on levels 1-10).
func use_booster(id: String, free: bool = false) -> bool:
	if state != State.PLAYING or AdManager.is_showing():
		return false
	if tutorial.step == "tap" and not tutorial.forced.is_empty():
		VFXManager.toast("Follow the hand first!")
		return false
	match id:
		"undo":
			if history.is_empty():
				VFXManager.toast("Nothing to undo")
				return false
		"extra_jar":
			if extra_used:
				VFXManager.toast("Only one extra jar per level")
				return false
		"shuffle":
			if board.shuffle_jars().size() < 2:
				VFXManager.toast("Nothing left to shuffle")
				return false
	if not free:
		if BoosterManager.count(id) <= 0:
			Popups.buy_booster(id, func() -> void: use_booster(id))
			return false
		BoosterManager.consume(id)
	else:
		SaveManager.add_game_stat("boosters_used")
	boosters_used = true
	_idle = 0.0
	_clear_hint()
	_deselect()
	match id:
		"undo":
			_apply_undo()
		"extra_jar":
			_apply_extra_jar()
		"shuffle":
			if not _apply_shuffle():
				if not free:
					BoosterManager.grant(id, 1)
				return false
	tutorial.on_booster(id)
	_stuck_shown = false
	_queue_save()
	return true


func _apply_undo() -> void:
	var e: Dictionary = history.pop_back()
	if bool(e.get("completed", false)):
		SaveManager.add_game_stat("jars_filled", -1)
	board = Board.from_level(e["board"])
	view.board = board
	var mv: Array = e["move"]
	view.animate_undo(int(mv[0]), int(mv[1]), int(e["count"]))
	AudioManager.play("undo")
	HapticsManager.light()


func _apply_extra_jar() -> void:
	extra_used = true
	var i := board.add_jar()
	for e in history:
		(e["board"]["jars"] as Array).append({"c": []})
	view.add_jar(i)
	AudioManager.play("extra_jar")
	HapticsManager.medium()


func _apply_shuffle() -> bool:
	var ids := board.shuffle_jars()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var cfg: Dictionary = GameData.difficulty()["shuffle"]
	if not board.shuffle(rng, int(cfg.get("max_tries", 30)), int(cfg.get("node_budget", 8000))):
		VFXManager.toast("Couldn't find a better mix. Booster refunded.")
		return false
	history.clear()
	state = State.BUSY
	var dur := view.animate_shuffle(ids)
	AudioManager.play("shuffle")
	HapticsManager.medium()
	_after(dur, func() -> void:
		view.sync_all()
		if state == State.BUSY:
			state = State.PLAYING
		_check_stuck())
	return true


# --- Stuck / give up / leaving ----------------------------------------------

func show_stuck() -> void:
	_stuck_shown = true
	_maya_worry()
	var free := free_fixes()
	var tag := func(id: String) -> String:
		return "free" if free else (str(BoosterManager.count(id)) if BoosterManager.count(id) > 0 else "+")
	Popups.show({
		"id": "stuck",
		"title": "Stuck?",
		"art": "jar",
		"art_color": UIKit.SECONDARY,
		"body": "No moves left. A booster can fix that." if not free else "No moves left. Here's a free fix!",
		"closable": true,
		"vertical": true,
		"buttons": [
			{"id": "undo", "text": "Undo", "icon": "undo", "kind": "secondary", "badge": tag.call("undo"), "disabled": history.is_empty(), "cb": func() -> void: use_booster("undo", free)},
			{"id": "extra_jar", "text": "Extra Jar", "icon": "jar_plus", "kind": "secondary", "badge": tag.call("extra_jar"), "disabled": extra_used, "cb": func() -> void: use_booster("extra_jar", free)},
			{"id": "shuffle", "text": "Shuffle", "icon": "shuffle", "kind": "secondary", "badge": tag.call("shuffle"), "cb": func() -> void: use_booster("shuffle", free)},
			{"id": "give_up", "text": "Give up  (-1 life)" if not free else "Start over", "kind": "danger", "cb": give_up},
		],
		"on_back": func() -> void: pass,
	})


func give_up() -> void:
	if state == State.WON:
		return
	state = State.FAILED
	var cost := LivesManager.level_costs_life(level)
	if cost:
		LivesManager.lose_life()
	_clear_progress()
	AudioManager.play("failure")
	HapticsManager.heavy()
	AdManager.on_run_finished()
	Popups.show({
		"id": "failed",
		"title": "Level failed",
		"art": "heart",
		"art_color": UIKit.HEART,
		"body": ("You lost a life. %d left." % LivesManager.lives()) if cost else "No lives lost on the early levels. Try again!",
		"buttons": [
			{"id": "home", "text": "Home", "kind": "neutral", "icon": "home", "cb": func() -> void: ScreenManager.go_hub("home")},
			{"id": "retry", "text": "Retry", "kind": "primary", "icon": "retry", "cb": retry},
		],
		"on_back": func() -> void: ScreenManager.go_hub("home"),
	})


func retry() -> void:
	if not LivesManager.can_play(level):
		Popups.lives(true, retry)
		return
	ScreenManager.change_screen(ScreenManager.GAMEPLAY, level)


## Restart or Home. After at least one move this costs a life (levels 11+).
func leave_level(to: String) -> void:
	if state == State.WON or state == State.FAILED:
		return
	var go := func() -> void:
		_clear_progress()
		if to == "restart":
			retry()
		else:
			ScreenManager.go_hub("home")
	if moves > 0 and LivesManager.level_costs_life(level):
		Popups.confirm("Leave level?" if to == "home" else "Restart level?", "Leaving will cost 1 life.", "Leave" if to == "home" else "Restart", func() -> void:
			state = State.FAILED
			LivesManager.lose_life()
			AdManager.on_run_finished()
			go.call(), "danger")
	elif to == "restart":
		# Restarting always asks, even when it's free.
		Popups.confirm("Restart level?", "Start this level again from the beginning?", "Restart", func() -> void:
			state = State.FAILED
			go.call(), "danger")
	else:
		state = State.FAILED
		go.call()


func open_pause() -> void:
	if state != State.PLAYING and state != State.BUSY and state != State.INTRO:
		return
	if ScreenManager.find_modal("pause"):
		return
	_deselect()
	get_tree().paused = true
	var p := Popups.show({
		"id": "pause",
		"title": "Paused",
		"vertical": true,
		"buttons": [
			{"id": "resume", "text": "Resume", "kind": "primary", "icon": "play"},
			{"id": "restart", "text": "Restart", "kind": "neutral", "icon": "retry", "cb": func() -> void: leave_level("restart")},
			{"id": "home", "text": "Home", "kind": "neutral", "icon": "home", "cb": func() -> void: leave_level("home")},
			{"id": "settings", "text": "Settings", "kind": "neutral", "icon": "gear", "close": false, "cb": func() -> void: ScreenManager.push_modal(load("res://scenes/ui/settings.tscn").instantiate())},
		],
	})
	p.tree_exited.connect(func() -> void:
		if is_inside_tree() and ScreenManager.find_modal("pause") == null:
			get_tree().paused = false)


func on_back() -> void:
	if state == State.PLAYING or state == State.BUSY or state == State.INTRO:
		open_pause()


func _on_app_paused() -> void:
	_save_progress()
	if state == State.PLAYING and not ScreenManager.has_modal():
		open_pause()


# --- Win ---------------------------------------------------------------------

func _win(delay: float) -> void:
	state = State.WON
	_clear_hint()
	var claimable_before := AchievementManager.claimable_count()
	_summary = ProgressionManager.complete_level(level, boosters_used)
	AchievementManager.refresh()
	_new_achievement = AchievementManager.claimable_count() > claimable_before
	AdManager.on_run_finished()
	tutorial.on_win()
	_after(delay + 0.1, _celebrate)


func _celebrate() -> void:
	var t := view.celebrate()
	var vp := get_viewport_rect().size
	VFXManager.confetti(hud, vp.x)
	VFXManager.shake(8.0, 0.25)
	AudioManager.play("level_complete")
	HapticsManager.heavy()
	_maya_cheer(vp)
	_after(maxf(t, 1.2), _after_celebration)


## Level 1: Hajurama introduces the story before the first win screen.
func _after_celebration() -> void:
	if level == 1 and not ProgressionManager.tutorial_done("story_intro"):
		ProgressionManager.mark_tutorial("story_intro")
		DialogueManager.play("intro", _show_win_panel)
	else:
		_show_win_panel()


func _show_win_panel() -> void:
	var panel: WinPanel = WinPanelScript.new()
	panel.setup(level, _summary, renovate_first())
	panel.continue_pressed.connect(continue_next)
	panel.home_pressed.connect(_go_home)
	ScreenManager.push_modal(panel)
	if _new_achievement:
		VFXManager.toast("Achievement unlocked! Claim it in your Profile.")
	if _summary.get("milestone", false):
		_after(1.3, _milestone_gift)


func _go_home() -> void:
	ScreenManager.go_hub("home")


## True when the win screen should send the player to the first renovation.
func renovate_first() -> bool:
	return not ProgressionManager.tutorial_done("first_task") and ProgressionManager.highest_completed() >= 3 \
		and RenovationManager.current_area() == 1 and RenovationManager.can_do(1, "clean_counter")


func _maya_cheer(vp: Vector2) -> void:
	var sk: CharacterVisual = CharacterScene.instantiate()
	sk.id = "maya"
	sk.unit = 0.9
	sk.position = Vector2(vp.x * 0.5, vp.y + 420)
	hud.add_child(sk)
	var cheers: Array = GameData.meta().get("cheers", ["DAMI!"])
	var text: String = cheers[level % cheers.size()]
	var tw := sk.create_tween()
	tw.tween_property(sk, "position:y", vp.y - GameManager.get_safe_insets().y + 20, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		sk.cheer(2.0)
		AudioManager.play("cheer")
		VFXManager.popup_text(hud, text, Vector2(vp.x * 0.5, sk.position.y - 440), UIKit.GOLD, 110, 60, 1.4))


## Maya peeks up from the bottom looking worried while the Stuck popup is open.
func _maya_worry() -> void:
	var vp := get_viewport_rect().size
	var sk: CharacterVisual = CharacterScene.instantiate()
	sk.id = "maya"
	sk.unit = 0.8
	sk.position = Vector2(vp.x * 0.82, vp.y + 400)
	VFXManager.fx_layer().add_child(sk)
	sk.worry(4.0)
	var tw := sk.create_tween()
	tw.tween_property(sk, "position:y", vp.y - GameManager.get_safe_insets().y + 60, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.0)
	tw.tween_property(sk, "position:y", vp.y + 400, 0.3)
	tw.tween_callback(sk.queue_free)


func _milestone_gift() -> void:
	Popups.show({
		"id": "gift",
		"title": "Gift box!",
		"art": "gift",
		"art_color": UIKit.PINK,
		"body": "Every 10 levels the bazaar sends you a present.",
		"buttons": [{"id": "open", "text": "Open", "kind": "primary", "icon": "gift", "cb": func() -> void:
			var g := ProgressionManager.claim_milestone(level)
			if not g.is_empty():
				Popups.reward("Gift box", "+%d coins\n+1 %s" % [int(g["coins"]), BoosterManager.display_name(g["booster"])], "gift")},
		],
	})


func continue_next() -> void:
	# After level 3 the first renovation task is taught on Home.
	if renovate_first():
		_go_home()
		return
	var next := ProgressionManager.current_level()
	if not LivesManager.can_play(next):
		Popups.lives(true, continue_next)
		return
	var go := func() -> void: ScreenManager.start_level()
	if level > LivesManager.free_levels() and AdManager.can_show_interstitial():
		AdManager.show_interstitial(go)
	else:
		go.call()


# --- In-progress save --------------------------------------------------------

func _try_resume() -> bool:
	var ip: Variant = SaveManager.game().get("in_progress_level")
	if typeof(ip) != TYPE_DICTIONARY or int(ip.get("level", -1)) != level:
		return false
	board = Board.from_level(ip["board"])
	history = ip.get("history", [])
	moves = int(ip.get("moves", 0))
	extra_used = bool(ip.get("extra_used", false))
	boosters_used = bool(ip.get("boosters_used", false))
	resumed = moves > 0
	return true


func _in_progress() -> Dictionary:
	return {
		"level": level,
		"board": board.to_dict(),
		"history": history.duplicate(true),
		"moves": moves,
		"extra_used": extra_used,
		"boosters_used": boosters_used,
	}


func _queue_save() -> void:
	_save_timer = SAVE_DELAY


func _save_progress() -> void:
	_save_timer = -1.0
	if state == State.WON or state == State.FAILED or board == null:
		return
	SaveManager.game()["in_progress_level"] = _in_progress()
	SaveManager.save_game()


func _clear_progress() -> void:
	_save_timer = -1.0
	SaveManager.game()["in_progress_level"] = null
	SaveManager.save_game()


# --- Frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	backdrop.drift = sin(_t * 0.25)
	if _save_timer > 0.0:
		_save_timer -= delta
		if _save_timer <= 0.0:
			_save_progress()
	_poll_hint()
	if is_playing() and SaveManager.get_setting("hints") and not tutorial.is_active() and not _hint_shown:
		_idle += delta
		if _idle >= float(GameData.difficulty()["hint"]["idle_seconds"]):
			_request_hint()


func _request_hint() -> void:
	if _hint_task >= 0:
		return
	_hint_shown = true
	var copy := board.duplicate_board()
	var budget := int(GameData.difficulty()["hint"]["node_budget"])
	_hint_ready = false
	_hint_task = WorkerThreadPool.add_task(func() -> void:
		var mv := Solver.hint(copy, budget)
		if mv.is_empty():
			var all := copy.useful_moves()
			mv = all[0] if not all.is_empty() else []
		_hint_mutex.lock()
		_hint_result = mv
		_hint_ready = true
		_hint_mutex.unlock())


func _poll_hint() -> void:
	if _hint_task < 0 or not WorkerThreadPool.is_task_completed(_hint_task):
		return
	WorkerThreadPool.wait_for_task_completion(_hint_task)
	_hint_task = -1
	_hint_mutex.lock()
	var mv := _hint_result.duplicate()
	_hint_mutex.unlock()
	if mv.size() >= 2 and is_playing():
		view.pulse_hint(int(mv[0]), int(mv[1]))


func _clear_hint() -> void:
	_hint_shown = false


func _exit_tree() -> void:
	if _hint_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_hint_task)
		_hint_task = -1
	if _save_timer > 0.0:
		_save_progress()
	if get_tree():
		get_tree().paused = false


## Runs `fn` after `sec` seconds on a tween owned by this node, so it never
## fires after the node is gone (unlike a SceneTree timer).
func _after(sec: float, fn: Callable) -> void:
	var tw := create_tween()
	tw.tween_interval(sec)
	tw.tween_callback(fn)
