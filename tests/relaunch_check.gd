extends SceneTree
## Two-process persistence check (a real relaunch, not just a reload):
##   godot --headless --path . --script res://tests/relaunch_check.gd -- --phase=write
##   godot --headless --path . --script res://tests/relaunch_check.gd -- --phase=verify
## "write" plays 3 moves on level 24 and quits without finishing (like the
## app being killed); "verify" relaunches, reopens the level and checks the
## board, undo history, coins, cosmetics, settings and lives regeneration.
## Exits 0 on success, 1 on failure. Uses its own save file.

const SAVE := "user://relaunch_check_save.json"
const GAMEPLAY := "res://scenes/gameplay/gameplay.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var phase := "verify"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--phase="):
			phase = a.substr(8)
	var S := root.get_node("SaveManager")
	var PM := root.get_node("ProgressionManager")
	var CM := root.get_node("CurrencyManager")
	var LM := root.get_node("LivesManager")
	S.set_save_path(SAVE)
	if phase == "write":
		S.data = S.defaults()
		S.data["current_level"] = 24
		for k in ["tap", "stack", "empty", "undo", "extra_jar", "shuffle", "twist_wrapped", "twist_cloth"]:
			S.game()["tutorial_steps"][k] = true
		CM.add_coins(900, false)
		PM.buy_cosmetic("jar_blue")
		S.set_setting("haptics", false)
		LM.lose_life()
		LM.lose_life()
		# Pretend the lives were lost 31 minutes ago.
		S.game()["last_life_time"] = LM.now() - 31.0 * 60.0
		change_scene_to_file(GAMEPLAY)
		await create_timer(1.5).timeout
		var g := current_scene
		for k in 3:
			var mv: Array = g.board.useful_moves()[0]
			g.do_move(mv[0], mv[1])
			await create_timer(0.1).timeout
		await create_timer(0.7).timeout
		var f := FileAccess.open("user://relaunch_expected.json", FileAccess.WRITE)
		f.store_string(JSON.stringify({"stacks": g.board.stacks, "history": g.history.size()}))
		f.close()
		print("wrote save: ", ProjectSettings.globalize_path(SAVE))
		quit(0)
		return
	S.load_game()
	LM.tick()
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://relaunch_expected.json"))
	change_scene_to_file(GAMEPLAY)
	await create_timer(1.5).timeout
	var g := current_scene
	var want: Array = []
	for st in expected["stacks"]:
		want.append((st as Array).map(func(x): return int(x)))
	var stacks_ok: bool = g.board.stacks == want
	var ok: bool = stacks_ok \
		and g.history.size() == int(expected["history"]) \
		and g.resumed \
		and CM.get_coins() == 900 - 150 \
		and PM.selected_cosmetic("jar") == "jar_blue" \
		and S.get_setting("haptics") == false \
		and LM.lives() == 4
	var undo_ok: bool = g.use_booster("undo") and g.history.size() == int(expected["history"]) - 1
	ok = ok and undo_ok
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://relaunch_expected.json"))
	print("RELAUNCH CHECK ", "PASSED" if ok else "FAILED (board %s, history %d, coins %d, lives %d, undo %s)" % [stacks_ok, g.history.size(), CM.get_coins(), LM.lives(), undo_ok])
	g.queue_free()
	await process_frame
	quit(0 if ok else 1)
