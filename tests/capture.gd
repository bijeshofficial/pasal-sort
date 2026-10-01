extends SceneTree
## Renders screens to PNG for visual review (needs a window, not --headless).
##   godot --path . --resolution 540x960 --script res://tests/capture.gd -- --out=/tmp/shots [--set=boot|hub|play|twists|popups|themes]
## Uses a throwaway save file, never the player's.

var out_dir := "user://captures"
var which := "all"
var S: Node
var SM: Node
var PM: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--set="):
			which = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _fresh(level: int, coins: int = 640, stars: int = 3) -> void:
	S.data = S.defaults()
	S.data["coins"] = coins
	S.data["current_level"] = level
	S.data["game"]["stars"] = stars
	S.data["game"]["tutorial_steps"] = {"tap": true, "stack": true, "empty": true, "undo": true, "extra_jar": true, "shuffle": true,
		"twist_wrapped": true, "twist_cloth": true, "twist_lock": true, "twist_tall": true, "first_task": true, "story_intro": true}
	for i in range(1, 11):
		S.data["game"]["tutorial_steps"]["arrive_%d" % i] = true


## Marks the first `n` tasks of `area` done (style 0, 1, 2, ...).
func _reno(area: int, n: int) -> void:
	var rm := root.get_node("RenovationManager")
	S.data["game"]["renovation"]["area"] = area
	var st: Dictionary = rm.area_state(area)
	var k := 0
	for t in rm.tasks(area):
		if k >= n:
			break
		st["tasks"][t["id"]] = k % 3
		k += 1
	for a in range(1, area):
		var prev: Dictionary = rm.area_state(a)
		for t in rm.tasks(a):
			prev["tasks"][t["id"]] = 0
		prev["complete"] = true
		prev["chest_claimed"] = true


func _run() -> void:
	await process_frame
	S = root.get_node("SaveManager")
	SM = root.get_node("ScreenManager")
	PM = root.get_node("ProgressionManager")
	S.set_save_path("user://capture_save.json")
	root.get_node("TimeManager").force_hour = 11
	root.get_node("AudioManager").set_ad_mute(true)
	root.get_node("AdManager").mock_duration = 0.05

	if which in ["all", "boot"]:
		_fresh(1)
		change_scene_to_file("res://scenes/main/boot.tscn")
		await _wait(0.45)
		await _save("00_boot_shutter")
		await _wait(0.6)
		await _save("01_boot_filling")
		await _wait(1.4)

	if which in ["all", "hub"]:
		_fresh(37)
		_reno(1, 6)
		SM.hub_tab = "home"
		await _scene("res://scenes/main/hub.tscn", 0.8)
		await _save("02_home")
		current_scene.select_tab(0)
		await _wait(0.5)
		await _save("03_shop")
		var shop = current_scene.shop
		shop.scroll.scroll_vertical = 1500
		await _wait(0.3)
		await _save("04_shop_cosmetics")
		shop.scroll.scroll_vertical = 3200
		await _wait(0.3)
		await _save("05_shop_themes")
		current_scene.select_tab(2)
		await _wait(0.5)
		await _save("06_profile")
		_fresh(160, 5000)
		_reno(2, 9)
		SM.hub_tab = "home"
		await _scene("res://scenes/main/hub.tscn", 0.8)
		await _save("07_home_area2")

	if which in ["all", "reno"]:
		_fresh(12, 900, 6)
		_reno(1, 3)
		SM.hub_tab = "home"
		await _scene("res://scenes/main/hub.tscn", 0.9)
		await _save("70_home_area1")
		var home = current_scene.home
		home.open_tasks()
		await _wait(0.6)
		await _save("71_tasks_panel")
		SM.close_all_modals()
		home.do_task("hang_lights")
		await _wait(1.25)
		await _save("72_stars_landing")
		await _wait(1.0)
		await _save("73_style_picker")
		var picker = SM.find_modal("style_picker")
		if picker:
			picker.pick(1)
			await _wait(0.5)
			await _save("74_style_preview")
			picker._choose()
		await _wait(0.8)
		await _save("75_dialogue")
		var dm := root.get_node("DialogueManager")
		while dm.is_playing():
			dm.current_box().advance()
			dm.current_box().advance()
			await _wait(0.1)
		await _wait(0.6)
		home.open_gallery()
		await _wait(0.5)
		await _save("76_areas_gallery")
		SM.close_all_modals()
		var ba = load("res://scripts/ui/before_after.gd").new()
		ba.setup(1)
		SM.push_modal(ba)
		await _wait(1.6)
		await _save("77_before_after")
		SM.close_all_modals()
		load("res://scripts/ui/chest_popup.gd").open("Chapter 1 chest", {"coins": 300, "boosters": {"undo": 2, "shuffle": 1}, "unlimited_lives_min": 30}, "capture")
		await _wait(2.8)
		await _save("78_chest")
		SM.close_all_modals()
		_fresh(300, 900, 4)
		_reno(3, 5)
		SM.hub_tab = "home"
		await _scene("res://scenes/main/hub.tscn", 0.9)
		await _save("79_home_area3")
		root.get_node("TimeManager").force_hour = 21
		_fresh(300, 900, 4)
		_reno(2, 12)
		S.data["game"]["renovation"]["areas"]["2"]["chest_claimed"] = true
		S.data["game"]["tutorial_steps"]["outro_2"] = true
		await _scene("res://scenes/main/hub.tscn", 1.2)
		await _save("80_home_area2_night")
		root.get_node("TimeManager").force_hour = 11

	if which in ["all", "play"]:
		for spec in [[1, "10_level1"], [2, "11_level2"], [7, "12_level7"], [25, "13_level25"], [60, "14_level60"], [200, "15_level200"]]:
			_fresh(int(spec[0]))
			if spec[0] <= 2:
				S.data["game"]["tutorial_steps"] = {}
			await _scene("res://scenes/gameplay/gameplay.tscn", 1.6)
			await _save(String(spec[1]))
		# Selection and a move in flight.
		_fresh(12)
		await _scene("res://scenes/gameplay/gameplay.tscn", 1.4)
		var g = current_scene
		var mv: Array = g.board.useful_moves()[0]
		g.tap_jar(mv[0])
		await _wait(0.25)
		await _save("16_selected")
		g.tap_jar(mv[1])
		await _wait(0.2)
		await _save("17a_pour_tilt")
		await _wait(0.12)
		await _save("17b_pouring")
		await _wait(0.12)
		await _save("17_flying")
		await _wait(0.6)
		# Finish with the solver and capture the win.
		var sol: Array = Solver.solve(g.board, 50000)["moves"]
		for m in sol:
			g.do_move(m[0], m[1])
			await _wait(0.02)
		await _wait(0.9)
		await _save("18_celebrate")
		await _wait(1.4)
		await _save("19_win_panel")
		SM.close_all_modals()

	if which in ["all", "twists"]:
		for spec in [[15, "20_wrapped"], [30, "21_cloth"], [50, "22_lock"], [80, "23_tall"]]:
			_fresh(int(spec[0]))
			await _scene("res://scenes/gameplay/gameplay.tscn", 1.6)
			await _save(String(spec[1]))
		_fresh(50)
		S.data["game"]["tutorial_steps"].erase("twist_lock")
		await _scene("res://scenes/gameplay/gameplay.tscn", 1.8)
		await _save("24_twist_card")
		SM.close_all_modals()

	if which in ["all", "popups"]:
		_fresh(40)
		await _scene("res://scenes/gameplay/gameplay.tscn", 1.4)
		current_scene.show_stuck()
		await _wait(0.4)
		await _save("30_stuck")
		SM.close_all_modals()
		current_scene.open_pause()
		await _wait(0.4)
		await _save("31_pause")
		SM.close_all_modals()
		paused = false
		root.get_node("LivesManager").lose_life()
		root.get_node("LivesManager").lose_life()
		load("res://scripts/ui/popups.gd").lives(true)
		await _wait(0.4)
		await _save("32_lives")
		SM.close_all_modals()
		SM.push_modal(load("res://scenes/ui/settings.tscn").instantiate())
		await _wait(0.4)
		await _save("33_settings")
		SM.close_all_modals()
		load("res://scripts/ui/popups.gd").buy_booster("shuffle")
		await _wait(0.4)
		await _save("34_buy_booster")
		SM.close_all_modals()

	if which in ["all", "themes"]:
		for t in ["theme_thamel", "theme_hill", "theme_tihar", "theme_snow"]:
			_fresh(45)
			S.data["unlocked_items"] = [t, "jar_festival", "wrap_foil"]
			S.data["selected_items"] = {"theme": t, "jar": "jar_festival" if t == "theme_tihar" else "jar_classic", "wrapper": "wrap_foil" if t == "theme_snow" else "wrap_classic"}
			await _scene("res://scenes/gameplay/gameplay.tscn", 1.5)
			await _save("40_" + t)
	if which in ["all", "extra"]:
		# L4: a wasteful move makes Undo pulse.
		_fresh(4)
		S.data["game"]["tutorial_steps"].erase("undo")
		S.data["game"]["tutorial_steps"].erase("grant_undo")
		await _scene("res://scenes/gameplay/gameplay.tscn", 1.4)
		var g = current_scene
		for mv in g.board.useful_moves():
			if g.board.size_of(mv[1]) == 0:
				g.do_move(mv[0], mv[1])
				break
		await _wait(0.8)
		await _save("50_undo_hint")
		_fresh(6)
		S.data["game"]["tutorial_steps"].erase("extra_jar")
		await _scene("res://scenes/gameplay/gameplay.tscn", 1.6)
		await _save("51_extra_jar_hint")
		_fresh(30)
		SM.hub_tab = "profile"
		await _scene("res://scenes/main/hub.tscn", 0.6)
		current_scene.profile._pick_avatar()
		await _wait(0.5)
		await _save("52_avatars")
		SM.close_all_modals()
		_fresh(4)
		S.data["game"]["tutorial_steps"].erase("first_task")
		SM.hub_tab = "home"
		await _scene("res://scenes/main/hub.tscn", 1.4)
		await _save("53_first_task_tutorial")
		SM.close_all_modals()
	if which in ["all", "candies"]:
		# All 12 candies large on the game backdrop (plus wrapped and selected).
		SM.close_all_modals()
		var sheet := Control.new()
		sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var bd = load("res://scripts/visuals/shop_backdrop.gd").new()
		bd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sheet.add_child(bd)
		var art := Control.new()
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.draw.connect(func() -> void:
			var ca = load("res://scripts/visuals/candy_art.gd")
			var w: float = art.size.x
			var d := w / 4.6
			for t in 12:
				var cx := w * (0.14 + 0.24 * (t % 4))
				var cy := 260.0 + d * 1.15 * (t / 4)
				ca.draw_candy(art, Vector2(cx, cy), d, t)
			ca.draw_candy(art, Vector2(w * 0.3, 260.0 + d * 3.6), d, 0, "classic", true)
			ca.draw_candy(art, Vector2(w * 0.7, 260.0 + d * 3.6), d, 2, "classic", false, true))
		sheet.add_child(art)
		var old := current_scene
		root.add_child(sheet)
		current_scene = sheet
		if old:
			old.queue_free()
		await _wait(0.4)
		await _save("60_candy_sheet")
	print("captures written to ", ProjectSettings.globalize_path(out_dir))
	quit(0)


func _scene(path: String, delay: float) -> void:
	SM.close_all_modals()
	paused = false
	change_scene_to_file(path)
	await _wait(delay)


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))


func _wait(sec: float) -> void:
	await create_timer(sec, true).timeout
