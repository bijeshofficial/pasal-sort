extends SceneTree
## Balancing report: generates levels 1-1000 and writes one CSV row per level.
##   godot --headless --path . --script res://tools/level_report.gd -- [--to=1000] [--out=user://level_report.csv]
## Columns: level, tier, types, jars, empty, twists, solution length, dead
## ends, difficulty score, generation time (ms).

var to := 1000
var out := "user://level_report.csv"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--to="):
			to = int(a.substr(5))
		elif a.begins_with("--out="):
			out = a.substr(6)
	GameData.preload_all()
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		push_error("level_report: cannot write %s" % out)
		quit(1)
		return
	f.store_line("level,tier,types,jars,empty,twists,solution,dead_ends,score,ms")
	var t0 := Time.get_ticks_msec()
	for n in range(1, to + 1):
		var ts := Time.get_ticks_msec()
		var lvl := LevelGenerator.generate(n)
		var ms := Time.get_ticks_msec() - ts
		var jars: Array = lvl.get("jars", [])
		var empty := 0
		for j in jars:
			if (j.get("c", []) as Array).is_empty():
				empty += 1
		var solution := int(lvl.get("solution", -1))
		var dead := int(lvl.get("dead_ends", -1))
		if solution < 0:
			# Authored levels carry no stats: solve them for the report.
			var r := Solver.solve(Board.from_level(lvl), 80000)
			solution = (r["moves"] as Array).size()
			dead = int(r["dead_ends"])
		var twists := "+".join(PackedStringArray(lvl.get("twists", [])))
		f.store_line("%d,%s,%d,%d,%d,%s,%d,%d,%.1f,%d" % [n, lvl.get("tier", ""), int(lvl.get("types", jars.size() - empty)), jars.size(), empty, twists, solution, dead, float(lvl.get("score", solution + 0.5 * dead)), ms])
		if n % 100 == 0:
			print("level %d (%.1f s)" % [n, (Time.get_ticks_msec() - t0) / 1000.0])
	f.close()
	print("wrote %s" % ProjectSettings.globalize_path(out))
	quit(0)
