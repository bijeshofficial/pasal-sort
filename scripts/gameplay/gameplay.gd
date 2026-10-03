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
## "level" (the main ladder) or "daily" (the daily challenge: no lives, no
## star, separate rewards and resume slot).
var mode := "level"
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
## Pre-level boosters applied at the start (saved with the board).
var pre_applied: Array = []
var lucky_left := 0
var second_chance_used := false
var _lucky_move: Array = []
var _lucky_t := 0.0
var _trunk_ready := false
## Move-limit levels: moves used (undo gives one back) and the +5 offer.
var move_limit := 0
var moves_used := 0
var moves_offer_used := false
var moves_label: Label
## Customer orders: [{type, patience, bonus, state: waiting|filled|left, left}]
var orders: Array = []
var order_cards: HBoxContainer
## Gift box jars already paid out (undo never pays twice).
var gifts_paid: Array = []
## Moves still to play when the end is obvious and the game finishes it.
var autosort_queue: Array = []
var order_bonus := 0


func _ready() -> void:
	VFXManager.toast_anchor = "bottom"
	mode = ProgressionManager.play_mode
	ProgressionManager.play_mode = "level"
	if mode == "daily":
		level = 0
		level_data = DailyManager.challenge_level()
	else:
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
	backdrop.calm = true
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(backdrop)

	view = BoardViewScript.new()
	add_child(view)

	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	_build_top_bar(insets)
	_build_booster_bar(vp, insets)

	move_limit = int(level_data.get("move_limit", 0))
	var restored := _try_resume()
	var pre := ProgressionManager.take_pre_boosters()
	if not restored:
		board = Board.from_level(level_data)
		_apply_pre_boosters(pre)
		orders = []
		for o in level_data.get("orders", []):
			var c: Dictionary = (o as Dictionary).duplicate()
			c["state"] = "waiting"
			c["left"] = int(c.get("patience", 3))
			orders.append(c)
	_build_level_hud(insets)
	var top := insets.x + (330.0 if (move_limit > 0 or not orders.is_empty()) else 230.0)
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
	_log("level_start", {"level": level, "mode": mode, "tier": String(level_data.get("tier", "normal")), "resumed": resumed, "pre": pre_applied})
	var twists: Array = level_data.get("twists", [])
	_show_twist_cards(twists.duplicate(), func() -> void:
		tutorial.start()
		if resumed:
			VFXManager.toast(tr("Welcome back! Your jars are just as you left them."))
		elif not pre_applied.is_empty():
			var names: PackedStringArray = []
			for id in pre_applied:
				names.append(BoosterManager.display_name(id))
			VFXManager.toast(tr("Boosters on: %s") % ", ".join(names))
		_lucky_hint()
		_check_stuck())


## Open Jar adds an empty jar, Peek unwraps every candy, Lucky Start
## highlights the first 3 moves. Paid ones are used up only now.
func _apply_pre_boosters(pre: Dictionary) -> void:
	var ids: Array = []
	for id in pre.get("paid", []):
		if not ids.has(id) and BoosterManager.consume(id):
			ids.append(id)
			boosters_used = true
			GameManager.emit_event("booster")
	for id in pre.get("free", []):
		if not ids.has(id):
			ids.append(id)
	for id in ids:
		match id:
			"open_jar":
				board.add_jar()
			"peek":
				for i in board.jar_count():
					var h: Array = board.hidden[i]
					for k in h.size():
						h[k] = false
			"lucky":
				lucky_left = 3
	pre_applied = ids


func _lucky_hint() -> void:
	_lucky_move = []
	if lucky_left <= 0 or state != State.PLAYING:
		return
	var mv := Solver.hint(board, int(GameData.difficulty()["hint"]["node_budget"]))
	if mv.is_empty():
		var all := board.useful_moves()
		mv = all[0] if not all.is_empty() else []
	if mv.size() >= 2:
		_lucky_move = mv
		_lucky_t = 0.0
		view.pulse_hint(int(mv[0]), int(mv[1]))


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
	level_label = UIKit.title(tr("Daily Challenge") if mode == "daily" else tr("Level %d") % level, 76 if mode != "daily" else 64)
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
	row.add_theme_constant_override("separation", 60 if BoosterManager.bar_ids().size() <= 3 else 22)
	row.position = Vector2(0, vp.y - insets.y - 290)
	row.size = Vector2(vp.x, 260)
	hud.add_child(row)
	for id in BoosterManager.bar_ids():
		var b := BoosterButton.new()
		b.setup(id)
		b.pressed.connect(func() -> void: use_booster(id))
		row.add_child(b)
		booster_buttons[id] = b


## Moves left (move-limit levels) and customer order cards under the title.
func _build_level_hud(insets: Vector2) -> void:
	var vp := get_viewport_rect().size
	if move_limit > 0:
		var pill := PanelContainer.new()
		var sb := UIKit.chip_box(10)
		sb.content_margin_left = 28
		sb.content_margin_right = 28
		pill.add_theme_stylebox_override("panel", sb)
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		pill.add_child(row)
		row.add_child(UIKit.icon("moves", 56, UIKit.DANGER))
		moves_label = UIKit.title("", 46)
		row.add_child(moves_label)
		hud.add_child(pill)
		pill.position = Vector2(vp.x * 0.5 - 150, insets.x + 196)
		pill.size = Vector2(300, 80)
		_update_moves()
	if not orders.is_empty():
		order_cards = HBoxContainer.new()
		order_cards.alignment = BoxContainer.ALIGNMENT_CENTER
		order_cards.add_theme_constant_override("separation", 18)
		order_cards.position = Vector2(0, insets.x + 190)
		order_cards.size = Vector2(vp.x, 120)
		order_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(order_cards)
		_refresh_orders()


func _update_moves() -> void:
	if moves_label:
		var left := move_limit - moves_used
		moves_label.text = tr("%d moves") % left
		moves_label.add_theme_color_override("font_color", Color("ff6b6b") if left <= 3 else Color.WHITE)
		if left <= 3:
			UIKit.bounce(moves_label, 1.15)


func _refresh_orders() -> void:
	if order_cards == null:
		return
	for c in order_cards.get_children():
		c.queue_free()
	for o in orders:
		order_cards.add_child(_order_card(o))


## A customer card: who's asking, the candy, patience dots, the bonus.
func _order_card(o: Dictionary) -> Control:
	var st := String(o.get("state", "waiting"))
	var c := Control.new()
	c.custom_minimum_size = Vector2(230, 120)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := int(o["type"])
	var who: String = ["sunita", "kanchha", "bhai"][t % 3]
	c.draw.connect(func() -> void:
		var r := Rect2(Vector2(4, 4), c.size - Vector2(8, 8))
		var base := Color.WHITE if st == "waiting" else (Color("c9f2b5") if st == "filled" else Color("d6d2e6"))
		DrawKit.glossy_rrect(c, r, 24, base, UIKit.PRIMARY_EDGE if st == "filled" else UIKit.LINE.darkened(0.1), 0.0, 4.0, 8.0, true)
		CharacterArt.draw(c, who, Vector2(48, 112), 0.16, "happy" if st == "filled" else ("grumpy" if st == "left" else "neutral"), 0.0)
		CandyArt.draw_candy(c, Vector2(128, 54), 70, t)
		if st == "waiting":
			for k in int(o.get("left", 0)):
				c.draw_circle(Vector2(102 + k * 18, 100), 6, UIKit.GOLD_EDGE, true, -1.0, true)
		var f := UIKit.font(true)
		var txt := "+%d" % int(o.get("bonus", 5)) if st != "left" else "x"
		c.draw_string_outline(f, Vector2(168, 70), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 6, UIKit.OUTLINE)
		c.draw_string(f, Vector2(168, 70), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UIKit.GOLD if st != "left" else Color.WHITE)
		if st == "filled":
			c.draw_circle(Vector2(200, 28), 18, UIKit.PRIMARY, true, -1.0, true)
			c.draw_polyline(PackedVector2Array([Vector2(191, 28), Vector2(198, 35), Vector2(210, 21)]), Color.WHITE, 5.0, true))
	return c


## A jar of `type` was just completed: serve a waiting customer (bonus
## coins) or make the others a little less patient.
func _on_jar_completed(type: int) -> void:
	if orders.is_empty():
		return
	var served := false
	for o in orders:
		if String(o["state"]) == "waiting" and int(o["type"]) == type and not served:
			o["state"] = "filled"
			served = true
			var bonus := int(o.get("bonus", 5))
			CurrencyManager.add_coins(bonus, false)
			order_bonus += bonus
			SaveManager.add_game_stat("orders_filled")
			GameManager.emit_event("order")
			AudioManager.play("coin_pickup")
			VFXManager.toast(tr("Order filled! +%d coins") % bonus)
	for o in orders:
		if String(o["state"]) == "waiting" and not (served and int(o["type"]) == type):
			o["left"] = int(o["left"]) - 1
			if int(o["left"]) <= 0:
				o["state"] = "left"
	_refresh_orders()


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
				VFXManager.toast(tr("Covered! Fill %d jars to lift the cloth.") % board.cloth_after)
			else:
				VFXManager.toast(tr("Locked! Fill a jar of %s to open it.") % GameData.candy(int(board.locks[i]))["name"])
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
	moves_used += 1
	_update_moves()
	SaveManager.add_game_stat("candies_moved", int(result["count"]))
	GameManager.emit_event("candies", int(result["count"]))
	if result["completed"]:
		SaveManager.add_game_stat("jars_filled")
		GameManager.emit_event("jar")
		_on_jar_completed(int(result["type"]))
		if bool(result.get("gift", false)) and not gifts_paid.has(b):
			gifts_paid.append(b)
			_pay_gift(b)
	var dur := view.animate_move(a, b, result)
	tutorial.on_move(a, b, before)
	if lucky_left > 0:
		lucky_left -= 1
		_lucky_move = []
		if lucky_left > 0:
			_after(dur + 0.1, _lucky_hint)
	_queue_save()
	if result["won"]:
		_win(dur)
		return
	if move_limit > 0 and moves_used >= move_limit:
		_after(dur + 0.2, out_of_moves)
		return
	_after(dur + (0.05 if state == State.BUSY else 0.15), _after_move)


func _after_move() -> void:
	if state == State.BUSY and not autosort_queue.is_empty():
		var m: Array = autosort_queue.pop_front()
		do_move(int(m[0]), int(m[1]))
		return
	if state == State.PLAYING and start_autosort():
		return
	_check_stuck()


# --- Auto-sort ---------------------------------------------------------------

## The end is obvious when nothing is hidden or sealed and every unfinished
## jar holds a single kind of candy: all that is left is pouring the smaller
## piles onto the bigger ones. Returns those moves, or [] when the board is
## not obvious yet.
func autosort_moves() -> Array:
	var b := board.duplicate_board()
	if not b.cat_path.is_empty() or b.is_won():
		return []
	for i in b.jar_count():
		if b.size_of(i) == 0 or b.is_done(i):
			continue
		if b.is_sealed(i) or not b.is_uniform(i) or (b.hidden[i] as Array).has(true):
			return []
	var out: Array = []
	for guard in 64:
		if b.is_won():
			return out
		var by_type: Dictionary = {}
		for i in b.jar_count():
			if b.size_of(i) > 0 and not b.is_done(i):
				if not by_type.has(b.top(i)):
					by_type[b.top(i)] = []
				(by_type[b.top(i)] as Array).append(i)
		var moved := false
		for t in by_type:
			var jars: Array = by_type[t]
			if jars.size() < 2:
				continue
			jars.sort_custom(func(x: int, y: int) -> bool: return b.size_of(x) > b.size_of(y))
			var src: int = jars[jars.size() - 1]
			var dst: int = jars[0]
			if b.can_move(src, dst) and not b.apply_move(src, dst).is_empty():
				out.append([src, dst])
				moved = true
				break
		if not moved:
			return []
	return []


## Starts finishing the level by itself (input is blocked while it runs).
func start_autosort() -> bool:
	if tutorial.is_active() or ScreenManager.has_modal():
		return false
	var plan := autosort_moves()
	if plan.is_empty():
		return false
	if move_limit > 0 and moves_used + plan.size() > move_limit:
		return false
	_deselect()
	_clear_hint()
	state = State.BUSY
	autosort_queue = plan
	VFXManager.popup_text(hud, tr("Auto-sort!"), get_viewport_rect().size * Vector2(0.5, 0.3), UIKit.GOLD, 90, 40, 1.0)
	_after(0.35, _after_move)
	return true


## Gift box: a small reward when its jar is completed.
func _pay_gift(jar: int) -> void:
	var table: Array = GameData.economy().get("gift_box", [{"coins": 15}])
	var reward: Dictionary = table[posmod(level * 7 + jar, table.size())]
	var items := Rewards.grant(reward, "gift_box")
	if not items.is_empty():
		_after(0.9, func() -> void: VFXManager.toast(tr("Gift box: %s") % Rewards.describe(reward)))


## Move limit reached: "So close!" offers +5 moves once, else the level fails.
func out_of_moves() -> void:
	if state != State.PLAYING or board.is_won():
		return
	var cfg: Dictionary = GameData.economy().get("fail_offers", {})
	var price := int(cfg.get("moves", 200))
	var extra := int(cfg.get("moves_amount", 5))
	if moves_offer_used:
		confirm_fail()
		return
	Popups.show({
		"id": "out_of_moves",
		"title": tr("Out of moves!"),
		"art": func(c: Control) -> void: CharacterArt.draw(c, "maya", Vector2(c.size.x * 0.5, c.size.y), 0.6, "worried", 0.0),
		"art_size": 260,
		"body": tr("So close! Keep going with %d more moves?") % extra,
		"vertical": true,
		"buttons": [
			{"id": "coins", "text": tr("+%d moves  %d") % [extra, price], "kind": "gold", "icon": "coin", "disabled": not CurrencyManager.can_afford(price), "cb": func() -> void:
				if CurrencyManager.spend(price):
					SaveManager.save_game()
					_add_moves(extra)},
			{"id": "ad", "text": tr("+%d moves  (Watch ad)") % extra, "kind": "secondary", "icon": "ad", "cb": func() -> void:
				AdManager.show_rewarded("revive", func(ok: bool) -> void:
					if ok:
						_add_moves(extra)
					else:
						VFXManager.toast(tr("Ad not available right now"))
						confirm_fail())},
			{"id": "give_up", "text": tr("Give up  (-1 life)") if LivesManager.level_costs_life(level) else tr("Start over"), "kind": "danger", "cb": confirm_fail},
		],
		"on_back": confirm_fail,
	})


func _add_moves(n: int) -> void:
	moves_offer_used = true
	move_limit += n
	_update_moves()
	_queue_save()
	VFXManager.toast(tr("+%d moves!") % n)


func _check_stuck() -> void:
	if state != State.PLAYING or board.is_won() or _stuck_shown:
		return
	if board.is_stuck():
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
				VFXManager.toast(tr("Nothing left to shuffle"))
				return false
		"helper":
			if not _has_free_empty_jar():
				VFXManager.toast(tr("The Haat Helper needs an empty jar"))
				return false
			if board.top_types().is_empty():
				return false
	if id == "helper" and not free and BoosterManager.count(id) > 0:
		_pick_helper_type()
		return true
	if not free:
		if BoosterManager.count(id) <= 0:
			Popups.buy_booster(id, func() -> void: use_booster(id))
			return false
		BoosterManager.consume(id)
	else:
		SaveManager.add_game_stat("boosters_used")
	GameManager.emit_event("booster")
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
		"helper":
			_pick_helper_type()
			return true
	tutorial.on_booster(id)
	_stuck_shown = false
	_queue_save()
	return true


func _has_free_empty_jar() -> bool:
	for i in board.jar_count():
		if board.size_of(i) == 0 and not board.is_sealed(i):
			return true
	return false


## Haat Helper: pick a candy; the helper gathers it from the jar tops.
func _pick_helper_type() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	var popup: GamePopup
	for t in board.top_types():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(170, 170)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var tt: int = t
		b.draw.connect(func() -> void:
			DrawKit.glossy_rrect(b, Rect2(Vector2(6, 6), b.size - Vector2(12, 12)), 30, Color.WHITE, UIKit.LINE.darkened(0.1), 0.0, 4.0, 8.0, true)
			CandyArt.draw_candy(b, b.size * 0.5 - Vector2(0, 6), 120, tt))
		b.pressed.connect(func() -> void:
			Popups.close_id("helper")
			apply_helper(tt))
		grid.add_child(b)
	popup = Popups.show({"id": "helper", "title": tr("Haat Helper"), "art": "basket", "art_color": UIKit.GOLD, "body": tr("Which candy should the helper gather?"), "content": grid, "closable": true})


## Gathers `type` into an empty jar (one undo step, not a move).
func apply_helper(type: int) -> bool:
	var mvs := board.helper_moves(type)
	if mvs.is_empty():
		VFXManager.toast(tr("Nothing to gather"))
		return false
	if BoosterManager.count("helper") > 0:
		BoosterManager.consume("helper")
	else:
		SaveManager.add_game_stat("boosters_used")
	boosters_used = true
	SaveManager.add_game_stat("helper_used")
	GameManager.emit_event("booster")
	GameManager.emit_event("helper")
	_deselect()
	var snapshot := board.to_dict()
	state = State.BUSY
	var delay := 0.0
	var won := false
	for mv in mvs:
		var a := int(mv[0])
		var b := int(mv[1])
		var result := board.apply_move(a, b)
		board.move_count -= 1
		result["cat_to"] = result.get("cat_from", -1)
		if result["completed"]:
			SaveManager.add_game_stat("jars_filled")
			GameManager.emit_event("jar")
			_on_jar_completed(int(result["type"]))
		_after(delay, view.animate_move.bind(a, b, result))
		delay += 0.45
		won = bool(result["won"])
	history.append({"board": snapshot, "move": [-1, -1], "count": 0, "helper": true})
	AudioManager.play("reward")
	_queue_save()
	_after(delay + 0.5, func() -> void:
		view.sync_all()
		if won:
			state = State.PLAYING
			_win(0.1)
		elif state == State.BUSY:
			state = State.PLAYING
			_check_stuck())
	return true


func _apply_undo() -> void:
	var e: Dictionary = history.pop_back()
	if bool(e.get("completed", false)):
		SaveManager.add_game_stat("jars_filled", -1)
	board = Board.from_level(e["board"])
	view.board = board
	if bool(e.get("helper", false)):
		view.sync_all()
		AudioManager.play("undo")
		return
	moves_used = maxi(0, moves_used - 1)
	_update_moves()
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


## "So close!": one second chance per level (an Extra Jar for coins or a
## rewarded ad), otherwise give up for a life.
func give_up() -> void:
	if state == State.WON or state == State.FAILED:
		return
	var can_jar := not extra_used and not second_chance_used
	if not can_jar:
		confirm_fail()
		return
	var cost := LivesManager.level_costs_life(level)
	var price := int(GameData.economy().get("fail_offers", {}).get("extra_jar", 150))
	Popups.show({
		"id": "so_close",
		"title": tr("So close!"),
		"art": func(c: Control) -> void: CharacterArt.draw(c, "maya", Vector2(c.size.x * 0.5, c.size.y), 0.6, "worried", 0.0),
		"art_size": 260,
		"body": tr("One more jar might do it. Second chance?"),
		"vertical": true,
		"buttons": [
			{"id": "coins", "text": tr("Extra Jar  %d") % price, "kind": "gold", "icon": "coin", "disabled": not CurrencyManager.can_afford(price), "cb": func() -> void:
				if CurrencyManager.spend(price):
					SaveManager.save_game()
					_second_chance()},
			{"id": "ad", "text": tr("Extra Jar  (Watch ad)"), "kind": "secondary", "icon": "ad", "cb": func() -> void:
				AdManager.show_rewarded("second_chance", func(ok: bool) -> void:
					if ok:
						_second_chance()
					else:
						VFXManager.toast(tr("Ad not available right now"))
						confirm_fail())},
			{"id": "give_up", "text": tr("Give up  (-1 life)") if cost else tr("Start over"), "kind": "danger", "cb": confirm_fail},
		],
		"on_back": confirm_fail,
	})


func _second_chance() -> void:
	second_chance_used = true
	if state != State.PLAYING or extra_used:
		return
	_apply_extra_jar()
	_stuck_shown = false
	_queue_save()
	VFXManager.toast(tr("Here's an extra jar. You can do it!"))


func confirm_fail() -> void:
	if state == State.WON or state == State.FAILED:
		return
	state = State.FAILED
	var cost := LivesManager.level_costs_life(level)
	if cost:
		LivesManager.lose_life()
	StreakManager.on_fail()
	_clear_progress()
	AudioManager.play("failure")
	HapticsManager.heavy()
	AdManager.on_run_finished()
	_log("level_fail", {"level": level, "reason": "out_of_moves" if move_limit > 0 and moves_used >= move_limit else "give_up", "moves": moves})
	var p := Popups.show({
		"id": "failed",
		"title": tr("Level failed"),
		"art": "heart",
		"art_color": UIKit.HEART,
		"body": (tr("You lost a life. %d left.") % LivesManager.lives()) if cost else tr("No lives lost on the early levels. Try again!"),
		"buttons": [
			{"id": "home", "text": tr("Home"), "kind": "neutral", "icon": "home", "cb": func() -> void: ScreenManager.go_hub("home")},
			{"id": "retry", "text": tr("Retry"), "kind": "primary", "icon": "retry", "cb": retry},
		],
		"on_back": func() -> void: ScreenManager.go_hub("home"),
	})
	if cost:
		_break_heart(p)


## The lost life: the heart wobbles, cracks and fades.
func _break_heart(p: Control) -> void:
	var vp := get_viewport_rect().size
	var h := UIKit.icon("heart", 160, UIKit.HEART)
	h.shadow = true
	h.position = Vector2(vp.x * 0.5 - 80, vp.y * 0.28)
	h.pivot_offset = Vector2(80, 80)
	h.z_index = 10
	p.add_child(h)
	var tw := h.create_tween()
	tw.tween_property(h, "rotation", 0.25, 0.08)
	tw.tween_property(h, "rotation", -0.25, 0.12)
	tw.tween_property(h, "rotation", 0.0, 0.08)
	tw.tween_property(h, "scale", Vector2(1.3, 1.3), 0.15)
	tw.parallel().tween_property(h, "modulate:a", 0.0, 0.45)
	tw.parallel().tween_property(h, "position:y", h.position.y - 120, 0.45)


## Debug menu: highlight the solver's next move and say how long the
## solution is.
func debug_show_solution() -> void:
	var r := Solver.solve(board, 80000, true)
	var mv: Array = r["moves"]
	if mv.is_empty():
		VFXManager.toast(tr("No solution found (%d nodes)") % int(r["nodes"]))
		return
	view.pulse_hint(int(mv[0][0]), int(mv[0][1]))
	VFXManager.toast(tr("Solution: %d moves. Next: %d -> %d") % [mv.size(), int(mv[0][0]) + 1, int(mv[0][1]) + 1])


func _log(event: String, data: Dictionary) -> void:
	if get_tree().root.has_node("AnalyticsManager"):
		get_tree().root.get_node("AnalyticsManager").log_event(event, data)


func retry() -> void:
	if mode == "daily":
		ScreenManager.start_daily()
		return
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
		Popups.confirm(tr("Leave level?") if to == "home" else tr("Restart level?"), tr("Leaving will cost 1 life."), tr("Leave") if to == "home" else tr("Restart"), func() -> void:
			state = State.FAILED
			LivesManager.lose_life()
			StreakManager.on_fail()
			AdManager.on_run_finished()
			_log("level_fail", {"level": level, "reason": "leave", "moves": moves})
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
	if mode == "daily":
		_summary = DailyManager.complete_challenge()
		_summary["daily"] = true
		_summary["stars"] = 0
		_summary["tier"] = "hard"
		SaveManager.game()["in_progress_level"] = null
		SaveManager.save_game()
	else:
		_summary = ProgressionManager.complete_level(level, boosters_used)
		_trunk_ready = StreakManager.on_win()
		_summary["dami"] = StreakManager.dami()
		_summary["milestone"] = ChestManager.level_chest_due(level)
		_summary["order_bonus"] = order_bonus
		var tier := String(_summary.get("tier", "normal"))
		GameManager.emit_event("win")
		if tier == "hard" or tier == "super":
			GameManager.emit_event("hard_win")
		if not boosters_used:
			GameManager.emit_event("clean_win")
		if not (level_data.get("twists", []) as Array).is_empty():
			SaveManager.add_game_stat("twist_wins")
			GameManager.emit_event("twist_win")
		SaveManager.save_game()
	_log("level_win", {"level": level, "mode": mode, "moves": moves, "time": int(_t), "boosters_used": boosters_used, "pre": pre_applied})
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
	if mode == "level" and level == 1 and not ProgressionManager.tutorial_done("story_intro"):
		ProgressionManager.mark_tutorial("story_intro")
		DialogueManager.play("intro", _show_win_panel)
	else:
		_show_win_panel()


func _show_win_panel() -> void:
	var panel: WinPanel = WinPanelScript.new()
	panel.setup(level, _summary, renovate_first() and mode == "level")
	panel.continue_pressed.connect(continue_next)
	panel.home_pressed.connect(_go_home)
	ScreenManager.push_modal(panel)
	if _new_achievement:
		VFXManager.toast(tr("Achievement unlocked! Claim it in your Profile."))
	if _summary.get("milestone", false):
		_after(1.3, _milestone_gift)
	elif _trunk_ready:
		_after(1.3, _open_trunk)


## Seven wins in a row: Hajurama's Trunk.
func _open_trunk() -> void:
	var contents := StreakManager.claim_trunk()
	if not contents.is_empty():
		ChestPopup.open(tr("Hajurama's Trunk"), contents, "treasure_streak", Callable(), "trunk")


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


## Every 10 levels: the level chest.
func _milestone_gift() -> void:
	var contents := ChestManager.claim_level_chest(level)
	if not contents.is_empty():
		ChestPopup.open(tr("Level %d chest") % level, contents, "level_chest", func() -> void:
			if _trunk_ready:
				_open_trunk(), "wood")


func continue_next() -> void:
	if mode == "daily":
		_go_home()
		return
	# After level 3 the first renovation task is taught on Home.
	if renovate_first():
		_go_home()
		return
	var next := ProgressionManager.current_level()
	if not LivesManager.can_play(next):
		Popups.lives(true, continue_next)
		return
	# No ad breaks between levels: only rewarded ads the player chooses.
	HomePage.start_next_level()


# --- In-progress save --------------------------------------------------------

func _try_resume() -> bool:
	var ip: Variant = SaveManager.game().get("in_progress_level")
	if typeof(ip) != TYPE_DICTIONARY or int(ip.get("level", -1)) != level:
		return false
	if String(ip.get("mode", "level")) != mode or (mode == "daily" and String(ip.get("day", "")) != TimeManager.today()):
		return false
	board = Board.from_level(ip["board"])
	history = ip.get("history", [])
	moves = int(ip.get("moves", 0))
	extra_used = bool(ip.get("extra_used", false))
	boosters_used = bool(ip.get("boosters_used", false))
	pre_applied = ip.get("pre_applied", [])
	lucky_left = int(ip.get("lucky_left", 0))
	second_chance_used = bool(ip.get("second_chance_used", false))
	moves_used = int(ip.get("moves_used", moves))
	move_limit = int(ip.get("move_limit", move_limit))
	moves_offer_used = bool(ip.get("moves_offer_used", false))
	orders = ip.get("orders", [])
	gifts_paid = ip.get("gifts_paid", [])
	resumed = moves > 0
	return true


func _in_progress() -> Dictionary:
	return {
		"level": level,
		"mode": mode,
		"day": TimeManager.today(),
		"board": board.to_dict(),
		"history": history.duplicate(true),
		"moves": moves,
		"extra_used": extra_used,
		"boosters_used": boosters_used,
		"pre_applied": pre_applied.duplicate(),
		"lucky_left": lucky_left,
		"second_chance_used": second_chance_used,
		"moves_used": moves_used,
		"move_limit": move_limit,
		"moves_offer_used": moves_offer_used,
		"orders": orders.duplicate(true),
		"gifts_paid": gifts_paid.duplicate(),
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
	if _save_timer > 0.0:
		_save_timer -= delta
		if _save_timer <= 0.0:
			_save_progress()
	_poll_hint()
	if not _lucky_move.is_empty() and is_playing():
		_lucky_t += delta
		if _lucky_t >= 1.6:
			_lucky_t = 0.0
			view.pulse_hint(int(_lucky_move[0]), int(_lucky_move[1]))
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
