class_name DebugMenu
extends RefCounted
## Cheat/debug menu (debug builds only): 5 taps on the version in Settings.
## Jump to a level, add coins/stars/boosters/lives, finish the current area,
## move the clock, reset tutorials, write the level report, show the
## solver's solution and read the analytics summary.

static var jump_to := 1


static func open() -> GamePopup:
	if not OS.is_debug_build():
		return null
	jump_to = ProgressionManager.current_level()
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	var lvl_row := HBoxContainer.new()
	lvl_row.add_theme_constant_override("separation", 8)
	var lvl_label := UIKit.label("Level %d" % jump_to, 40, UIKit.INK)
	lvl_label.custom_minimum_size = Vector2(220, 0)
	for d in [-10, -1]:
		lvl_row.add_child(_small("%+d" % d, func() -> void:
			jump_to = maxi(1, jump_to + d)
			lvl_label.text = "Level %d" % jump_to))
	lvl_row.add_child(lvl_label)
	for d in [1, 10, 100]:
		lvl_row.add_child(_small("%+d" % d, func() -> void:
			jump_to = maxi(1, jump_to + d)
			lvl_label.text = "Level %d" % jump_to))
	body.add_child(lvl_row)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var actions := [
		["Jump to level", func() -> void:
			SaveManager.data["current_level"] = jump_to
			SaveManager.game()["in_progress_level"] = null
			SaveManager.save_game()
			VFXManager.toast("Now at level %d" % jump_to)],
		["+1000 coins", func() -> void: CurrencyManager.add_coins(1000)],
		["+10 stars", func() -> void: CurrencyManager.add_stars(10)],
		["+5 every booster", func() -> void:
			for id in BoosterManager.ALL:
				BoosterManager.grant(id, 5, false)
			SaveManager.save_game()],
		["Refill lives", func() -> void: LivesManager.refill()],
		["Lose a life", func() -> void: LivesManager.lose_life()],
		["Finish this area", func() -> void:
			RenovationManager.debug_complete_area()
			VFXManager.toast("Area complete: open Home")],
		["Clock +1 hour", func() -> void: _clock(3600)],
		["Clock +1 day", func() -> void: _clock(86400)],
		["Clock +7 days", func() -> void: _clock(86400 * 7)],
		["Reset clock", func() -> void:
			TimeManager.debug_offset = 0.0
			SaveManager.game()["time"]["max_seen"] = TimeManager.now()
			VFXManager.toast("Clock reset")],
		["Reset tutorials", func() -> void:
			SaveManager.game()["tutorial_steps"] = {}
			SaveManager.save_game()
			VFXManager.toast("Tutorials reset")],
		["Level report (1-200)", func() -> void:
			var path := "user://level_report.csv"
			VFXManager.toast("Writing level report...")
			WorkerThreadPool.add_task(func() -> void: LevelReport.write(200, path))
			VFXManager.toast(ProjectSettings.globalize_path(path))],
		["Show solution", func() -> void:
			var scene: Node = (Engine.get_main_loop() as SceneTree).current_scene
			if scene and scene.has_method("debug_show_solution"):
				ScreenManager.close_all_modals()
				(Engine.get_main_loop() as SceneTree).paused = false
				scene.debug_show_solution()
			else:
				VFXManager.toast("Open a level first")],
		["Analytics", func() -> void: _analytics()],
		["Open a sticker pack", func() -> void: LivePopups.open_pack_result(AlbumManager.open_pack("debug"))],
	]
	for a in actions:
		var b := UIKit.button(String(a[0]), "secondary", "", 30, Vector2(0, 96))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(a[1])
		grid.add_child(b)
	body.add_child(grid)
	var clock := UIKit.label("", 28, UIKit.INK_SOFT)
	body.add_child(clock)
	var p := Popups.show({"id": "debug", "title": "DEBUG", "content": body, "closable": true, "width": 960})
	DailyPopups._tick_timer(p, clock, func() -> String: return "Clock offset: %s  (%s)" % [TimeManager.short_duration(int(TimeManager.debug_offset)), TimeManager.today()])
	return p


static func _small(text: String, cb: Callable) -> GameButton:
	var b := UIKit.button(text, "neutral", "", 30, Vector2(110, 90))
	b.pressed.connect(cb)
	return b


static func _clock(seconds: int) -> void:
	TimeManager.advance(seconds)
	LivesManager.tick()
	DailyManager.roll()
	EventManager.roll()
	VFXManager.toast("Clock: %s ahead" % TimeManager.short_duration(int(TimeManager.debug_offset)))


static func _analytics() -> void:
	var s := AnalyticsManager.summary()
	var lines := PackedStringArray()
	lines.append("%d events, %d wins" % [int(s["events"]), int(s["wins"])])
	lines.append("Average win: %.1f moves, %.0f s" % [float(s["avg_moves"]), float(s["avg_seconds"])])
	var fails: Dictionary = s["fails"]
	for k in fails:
		lines.append("Fails (%s): %d" % [k, int(fails[k])])
	var counts: Dictionary = s["counts"]
	var keys := counts.keys()
	keys.sort()
	for k in keys:
		lines.append("%s: %d" % [k, int(counts[k])])
	var l := UIKit.label("\n".join(lines), 30, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 900)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	l.custom_minimum_size = Vector2(760, 0)
	scroll.add_child(l)
	Popups.show({"id": "analytics", "title": "Analytics", "content": scroll, "closable": true,
		"buttons": [{"id": "clear", "text": "Clear log", "kind": "danger", "cb": func() -> void: AnalyticsManager.clear()}]})
