class_name TutorialDirector
extends Node
## First levels teach by doing: an animated hand and one short line of text.
##   L1 "tap":      forced sequence; only the right jars respond.
##   L2 "stack":    hand appears if the player idles 4 s.
##   L3 "empty":    text only.
##   L4 "undo":     after the first wasteful move, Undo pulses.
##   L6 "extra_jar" / L8 "shuffle": the booster pulses from the start.
## Every step is saved once complete, so it never repeats, and every hint
## goes away by simply playing. Twists get a one-screen intro card.

var game: Node            # Gameplay
var step := ""            # active tutorial id for this level ("" = none)
var forced: Array = []    # L1 moves still to make
var hand: IconView
var text_panel: PanelContainer
var text_label: Label

var _idle := 0.0
var _hand_tween: Tween
var _hand_shown := false
var _undo_hinted := false


## `moves_done` > 0 when an interrupted level was resumed.
func setup(gameplay: Node, layer: CanvasLayer, level: Dictionary, moves_done: int = 0) -> void:
	game = gameplay
	text_panel = PanelContainer.new()
	var sb := UIKit.card_box(Color.WHITE, 26, UIKit.PURPLE)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	text_panel.add_theme_stylebox_override("panel", sb)
	text_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_panel.visible = false
	layer.add_child(text_panel)
	text_label = UIKit.label("", 48, UIKit.INK)
	text_panel.add_child(text_label)
	hand = UIKit.icon("hand", 150, Color.WHITE)
	hand.shadow = true
	hand.size = Vector2(150, 150)
	hand.visible = false
	hand.z_index = 30
	layer.add_child(hand)
	var id := String(level.get("tutorial", ""))
	# The Haat Helper joins the booster bar at its level (generated, no data).
	if id == "" and int(level.get("level", 0)) == int(GameData.economy().get("helper_from", 60)) and not ProgressionManager.tutorial_done("helper"):
		id = "helper"
	if id != "" and not ProgressionManager.tutorial_done(id):
		step = id
		if id == "tap":
			forced = (level.get("forced", []) as Array).duplicate(true)
			# Resumed mid-tutorial: skip the moves already made.
			forced = forced.slice(mini(moves_done, forced.size()))


## Called once the jars have landed.
func start() -> void:
	match step:
		"tap":
			_show_forced()
		"stack":
			say("Same candy on top? You can stack them.")
		"empty":
			say("Empty jars can take anything.")
		"undo":
			var n := BoosterManager.grant_tutorial("undo")
			if n > 0:
				VFXManager.toast(tr("%d free Undos!") % n)
		"extra_jar":
			var n := BoosterManager.grant_tutorial("extra_jar")
			if n > 0:
				VFXManager.toast(tr("%d free Extra Jars!") % n)
			say("Need space? Add a jar.")
			game.booster_buttons["extra_jar"].start_pulse()
		"shuffle":
			var n := BoosterManager.grant_tutorial("shuffle")
			if n > 0:
				VFXManager.toast(tr("%d free Shuffles!") % n)
			say("All mixed up? Try a Shuffle.")
			game.booster_buttons["shuffle"].start_pulse()
		"helper":
			var n := BoosterManager.grant_tutorial("helper")
			if n > 0:
				VFXManager.toast(tr("New: the Haat Helper! %d free") % n)
			say(tr("The Haat Helper gathers one candy for you."))
			if game.booster_buttons.has("helper"):
				game.booster_buttons["helper"].start_pulse()


func is_active() -> bool:
	return step != ""


## L1: only the expected jar responds.
func allows_tap(i: int, selected: int) -> bool:
	if step != "tap" or forced.is_empty():
		return true
	var mv: Array = forced[0]
	return i == (int(mv[0]) if selected < 0 else int(mv[1]))


func on_select(i: int) -> void:
	_idle = 0.0
	if step == "tap" and not forced.is_empty():
		_point_at_jar(int(forced[0][1]))
		say("Tap where it goes")


func on_move(a: int, b: int, board_before: Board) -> void:
	_idle = 0.0
	_hide_hand()
	match step:
		"tap":
			if not forced.is_empty():
				forced.pop_front()
			if forced.is_empty():
				hide_text()
			else:
				_show_forced()
		"stack":
			if board_before.size_of(b) > 0:
				hide_text()
				complete()
		"empty":
			if board_before.size_of(b) == 0:
				hide_text()
				complete()
		"undo":
			if not _undo_hinted and _is_wasteful(a, b, board_before):
				_undo_hinted = true
				say("Oops? Tap Undo.")
				game.booster_buttons["undo"].start_pulse()
		"extra_jar", "shuffle", "helper":
			hide_text()
			if game.booster_buttons.has(step):
				game.booster_buttons[step].stop_pulse()


func on_booster(id: String) -> void:
	if step == id:
		game.booster_buttons[id].stop_pulse()
		hide_text()
		complete()


func on_win() -> void:
	_hide_hand()
	hide_text()
	if step != "":
		for id in ["undo", "extra_jar", "shuffle", "helper"]:
			if game.booster_buttons.has(id):
				game.booster_buttons[id].stop_pulse()
		complete()


func complete() -> void:
	if step != "":
		ProgressionManager.mark_tutorial(step)
	step = ""


func _process(delta: float) -> void:
	if step == "stack" and not _hand_shown and game.is_playing():
		_idle += delta
		if _idle >= 4.0:
			var mv := _stack_move()
			if not mv.is_empty():
				_point_at_jar(int(mv[0]))
				_after(1.1, func() -> void:
					if _hand_shown:
						_point_at_jar(int(mv[1])))


func _stack_move() -> Array:
	var b: Board = game.board
	for mv in b.useful_moves():
		if b.size_of(mv[1]) > 0:
			return mv
	var all := b.useful_moves()
	return all[0] if not all.is_empty() else []


## Wasteful: into an empty jar although a same-candy top had room, or a
## move that leaves the board unsolvable.
func _is_wasteful(a: int, b: int, before: Board) -> bool:
	if before.size_of(b) == 0:
		for k in before.jar_count():
			if k != a and k != b and before.can_move(a, k) and before.size_of(k) > 0:
				return true
	return not Solver.solve(game.board, 3000)["solvable"]


func _show_forced() -> void:
	if forced.is_empty():
		return
	_point_at_jar(int(forced[0][0]))
	say("Tap a jar")


func say(text: String) -> void:
	text_label.text = text
	text_panel.visible = true
	text_panel.reset_size()
	var vp := game.get_viewport().get_visible_rect().size
	text_panel.position = Vector2((vp.x - text_panel.size.x) * 0.5, game.hint_text_y())
	text_panel.modulate.a = 0.0
	text_panel.create_tween().tween_property(text_panel, "modulate:a", 1.0, 0.2)


func hide_text() -> void:
	if text_panel.visible:
		var tw := text_panel.create_tween()
		tw.tween_property(text_panel, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func() -> void: text_panel.visible = false)


func _point_at_jar(i: int) -> void:
	var p: Vector2 = game.view.jar_top(i) + Vector2(-20, -30)
	_hand_shown = true
	hand.visible = true
	if _hand_tween:
		_hand_tween.kill()
	hand.position = p
	_hand_tween = hand.create_tween().set_loops()
	_hand_tween.tween_property(hand, "position", p + Vector2(0, 40), 0.35).set_trans(Tween.TRANS_SINE)
	_hand_tween.tween_property(hand, "position", p, 0.35).set_trans(Tween.TRANS_SINE)


func _hide_hand() -> void:
	_hand_shown = false
	if _hand_tween:
		_hand_tween.kill()
		_hand_tween = null
	if hand:
		hand.visible = false


## One-screen intro card for twists this player hasn't seen yet.
static func twist_card(twist_id: String, on_close: Callable) -> GamePopup:
	var info: Dictionary = GameData.difficulty()["twists"].get(twist_id, {})
	return Popups.show({
		"id": "twist_" + twist_id,
		"title": String(info.get("title", "New twist")),
		"art": func(c: Control) -> void: _draw_twist_art(c, twist_id),
		"art_size": 360,
		"body": String(info.get("text", "")),
		"buttons": [{"id": "ok", "text": "Got it", "kind": "primary", "icon": "check", "cb": on_close}],
		"on_back": on_close,
	})


static func _draw_twist_art(c: Control, twist_id: String) -> void:
	var cx := c.size.x * 0.5
	var bottom := c.size.y - 16
	match twist_id:
		"wrapped":
			CandyArt.draw_candy(c, Vector2(cx - 90, c.size.y * 0.5), 170, 0, "classic", true)
			CandyArt.draw_candy(c, Vector2(cx + 90, c.size.y * 0.5), 170, 2)
			c.draw_line(Vector2(cx - 20, c.size.y * 0.5), Vector2(cx + 10, c.size.y * 0.5), UIKit.INK_SOFT, 8, true)
		"cloth":
			CandyArt.draw_mini_jar(c, Vector2(cx, bottom), 100, [1, 3, 2, 0])
			var poly := DrawKit.rounded_rect(Rect2(cx - 64, bottom - 300, 128, 300), 44, 8)
			c.draw_colored_polygon(poly, Color("a8302b"))
			for k in 6:
				var p := Vector2(cx - 40 + (k % 3) * 40, bottom - 200 + (k / 3) * 90)
				c.draw_colored_polygon(DrawKit.regular(p, 14, 4, 0.0), Color("f2b632") if k % 2 == 0 else Color("fff3e0"))
		"lock":
			CandyArt.draw_mini_jar(c, Vector2(cx, bottom), 100, [1, 3, 2, 0])
			var lc := Vector2(cx, bottom - 130)
			c.draw_arc(lc + Vector2(0, -20), 30, PI, TAU, 16, Color("8e6a1c"), 14, true)
			DrawKit.rrect(c, Rect2(lc.x - 50, lc.y - 20, 100, 80), 16, Color("d6a53a"))
			CandyArt.draw_candy(c, lc + Vector2(0, 20), 70, 4)
		"tall":
			CandyArt.draw_mini_jar(c, Vector2(cx - 80, bottom), 70, [0, 1, 2, 3])
			CandyArt.draw_mini_jar(c, Vector2(cx + 80, bottom), 70, [0, 1, 2, 3, 3, 2])
		"cat":
			CandyArt.draw_mini_jar(c, Vector2(cx - 90, bottom), 80, [1, 3, 2, 0])
			CandyArt.draw_mini_jar(c, Vector2(cx + 90, bottom), 80, [2, 0, 1])
			CharacterArt.draw_cat(c, Vector2(cx - 90, bottom - 250), 0.36, "happy", 0.0)
			c.draw_arc(Vector2(cx, bottom - 250), 90, PI * 1.1, PI * 1.9, 16, UIKit.INK_SOFT, 6, true)
			c.draw_colored_polygon(PackedVector2Array([Vector2(cx + 80, bottom - 270), Vector2(cx + 100, bottom - 236), Vector2(cx + 66, bottom - 240)]), UIKit.INK_SOFT)
		"gift":
			CandyArt.draw_mini_jar(c, Vector2(cx, bottom), 110, [5, 5, 5])
			var gb := Rect2(cx - 40, bottom - 80, 80, 56)
			DrawKit.rrect(c, gb, 8, Color("e8457a"))
			c.draw_rect(Rect2(cx - 7, gb.position.y, 14, gb.size.y), Color("ffd23f"))
			DrawKit.rrect(c, Rect2(cx - 46, gb.position.y - 18, 92, 20), 6, Color("ff6b9a"))


## Runs `fn` after `sec` seconds on a tween owned by this node, so it never
## fires after the node is gone (unlike a SceneTree timer).
func _after(sec: float, fn: Callable) -> void:
	var tw := create_tween()
	tw.tween_interval(sec)
	tw.tween_callback(fn)
