extends SceneTree
## Renders raw store screenshots at exact store sizes, plus transparent art
## for Canva (logo, candies, a full jar). Needs a window (not --headless).
##   godot --path . --resolution 540x960 --script res://tools/store_shots.gd -- --out=docs/store/raw
## Then run tools/store/compose_store_shots.py to add the caption bands.
##
## The window can be any size: the root viewport switches to "viewport"
## stretch so it renders at the store resolution internally (a 1080x1920
## window would not fit on most desktop screens).
## Uses a throwaway save file, never the player's.

const SIZES := {
	"play": Vector2i(1080, 1920),      # Google Play phone, 9:16
	"appstore": Vector2i(1080, 2346),  # Apple 6.9" shape; composed up to 1320x2868
}

var out_dir := "res://docs/store/raw"
var S: Node
var SM: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	S = root.get_node("SaveManager")
	SM = root.get_node("ScreenManager")
	S.set_save_path("user://store_shots_save.json")
	root.get_node("GameManager").capture_mode = true
	root.get_node("TimeManager").force_hour = 11
	root.get_node("IAPManager").offer_shown_this_session = true
	root.get_node("AudioManager").set_ad_mute(true)
	root.get_node("AdManager").mock_duration = 0.05
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	for key in SIZES.keys():
		root.content_scale_size = SIZES[key]
		var dir := _abs(out_dir.path_join(key))
		DirAccess.make_dir_recursive_absolute(dir)
		await _shots(dir)
	root.content_scale_size = Vector2i(1080, 1920)
	await _canva_art(_abs(out_dir.path_join("../canva")))
	print("store shots written to ", _abs(out_dir))
	quit(0)


func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p) if p.begins_with("res://") or p.begins_with("user://") else p


## The 8 store screens, in store order.
func _shots(dir: String) -> void:
	# 1. Gameplay with a pour in mid-air.
	_fresh(60)
	await _scene("res://scenes/gameplay/gameplay.tscn", 1.6)
	var g := current_scene
	var mv: Array = _pretty_move(g)
	g.tap_jar(mv[0])
	await _wait(0.25)
	g.tap_jar(mv[1])
	await _wait(0.38)
	await _save(dir, "01_sort")

	# 2. Renovating Hajurama's pasal.
	_fresh(12, 900, 6)
	_reno(1, 3)
	SM.hub_tab = "home"
	await _scene("res://scenes/main/hub.tscn", 1.0)
	await _save(dir, "02_renovate")

	# 3. Choosing a style.
	var home = current_scene.home
	home.do_task("hang_lights")
	await _wait(2.25)
	var picker = SM.find_modal("style_picker")
	if picker:
		picker.pick(1)
		await _wait(0.5)
	await _save(dir, "03_style")
	SM.close_all_modals()
	var dm := root.get_node("DialogueManager")
	while dm.is_playing():
		dm.current_box().advance()
		dm.current_box().advance()
		await _wait(0.05)

	# 4. Level complete.
	_fresh(24)
	await _scene("res://scenes/gameplay/gameplay.tscn", 1.5)
	g = current_scene
	for m in load("res://scripts/systems/solver.gd").solve(g.board, 60000)["moves"]:
		g.do_move(m[0], m[1])
		await _wait(0.02)
	await _wait(4.4)
	await _save(dir, "04_win")
	SM.close_all_modals()

	# 5. Twists: dhaka cloth and a padlock on a big board.
	_fresh(200)
	await _scene("res://scenes/gameplay/gameplay.tscn", 1.7)
	await _save(dir, "05_twists")

	# 6. Before and after.
	_fresh(80, 900, 4)
	_reno(2, 12)
	SM.hub_tab = "home"
	await _scene("res://scenes/main/hub.tscn", 0.8)
	var ba = load("res://scripts/ui/before_after.gd").new()
	ba.setup(1)
	SM.push_modal(ba)
	await _wait(1.8)
	await _save(dir, "06_before_after")
	SM.close_all_modals()

	# 7. Daily gifts.
	_fresh(37, 900, 4)
	_reno(1, 5)
	S.data["game"]["daily"]["cal_index"] = 3
	S.data["game"]["daily"]["cal_last_day"] = -1
	SM.hub_tab = "home"
	await _scene("res://scenes/main/hub.tscn", 0.8)
	load("res://scripts/ui/daily_popups.gd").open_calendar()
	await _wait(0.7)
	await _save(dir, "07_daily")
	SM.close_all_modals()

	# 8. A cosy theme: Tihar night with festival glass.
	_fresh(45)
	S.data["unlocked_items"] = ["theme_tihar", "jar_festival", "wrap_foil"]
	S.data["selected_items"] = {"theme": "theme_tihar", "jar": "jar_festival", "wrapper": "wrap_foil"}
	await _scene("res://scenes/gameplay/gameplay.tscn", 1.6)
	await _save(dir, "08_themes")


## A move whose candies travel a fair distance (looks good mid-pour).
func _pretty_move(g: Node) -> Array:
	var best: Array = g.board.useful_moves()[0]
	var best_d := -1.0
	for mv in g.board.useful_moves():
		var d: float = g.view.jars[mv[0]].home_position.distance_to(g.view.jars[mv[1]].home_position)
		if g.board.move_amount(mv[0], mv[1]) >= 2:
			d += 400.0
		if d > best_d:
			best_d = d
			best = mv
	return best


## Transparent PNGs for Canva: the logo, each candy, and a full jar.
func _canva_art(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	SM.close_all_modals()
	paused = false
	root.transparent_bg = true
	var logo_art = load("res://scripts/visuals/game_logo.gd")
	var candy_art = load("res://scripts/visuals/candy_art.gd")
	var data = load("res://scripts/data/game_data.gd")
	var pieces := {
		"logo": [Vector2i(1500, 620), func(c: Control) -> void: logo_art.draw(c, Vector2(750, 60), 1.4)],
		"jar_full": [Vector2i(500, 900), func(c: Control) -> void:
			candy_art.draw_mini_jar(c, Vector2(250, 860), 300, [2, 2, 2, 2], 2)],
	}
	for t in 12:
		pieces["candy_%02d_%s" % [t + 1, String(data.candy(t)["id"])]] = [Vector2i(520, 520), func(c: Control) -> void:
			candy_art.draw_candy(c, Vector2(260, 250), 480, t)]
	var old := current_scene
	for name in pieces.keys():
		var size: Vector2i = pieces[name][0]
		var fn: Callable = pieces[name][1]
		root.content_scale_size = size
		var holder := Control.new()
		holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.draw.connect(func() -> void: fn.call(holder))
		root.add_child(holder)
		current_scene = holder
		if old:
			old.queue_free()
		old = holder
		await _wait(0.25)
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png(dir.path_join(String(name) + ".png"))
	root.transparent_bg = false


func _fresh(level: int, coins: int = 640, stars: int = 3) -> void:
	S.data = S.defaults()
	S.data["coins"] = coins
	S.data["current_level"] = level
	S.data["game"]["stars"] = stars
	S.data["game"]["tutorial_steps"] = {"tap": true, "stack": true, "empty": true, "undo": true, "extra_jar": true, "shuffle": true,
		"twist_wrapped": true, "twist_cloth": true, "twist_lock": true, "twist_tall": true, "first_task": true, "story_intro": true}
	for i in range(1, 11):
		S.data["game"]["tutorial_steps"]["arrive_%d" % i] = true


## Marks the first `n` tasks of `area` done (and earlier areas complete).
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


func _scene(path: String, delay: float) -> void:
	SM.close_all_modals()
	paused = false
	change_scene_to_file(path)
	await _wait(delay)


func _save(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)  # stores reject alpha in screenshots
	img.save_png(dir.path_join(name + ".png"))
	print("  ", name, " ", img.get_size())


func _wait(sec: float) -> void:
	await create_timer(sec, true).timeout
