extends SceneTree
## Balancing report: generates levels 1-1000 and writes one CSV row per level
## (see LevelReport for the columns).
##   godot --headless --path . --script res://tools/level_report.gd -- [--to=1000] [--out=user://level_report.csv]


func _initialize() -> void:
	var to := 1000
	var out := "user://level_report.csv"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--to="):
			to = int(a.substr(5))
		elif a.begins_with("--out="):
			out = a.substr(6)
	GameData.preload_all()
	var t0 := Time.get_ticks_msec()
	if not LevelReport.write(to, out):
		push_error("level_report: cannot write %s" % out)
		quit(1)
		return
	print("wrote %s (%d levels, %.1f s)" % [ProjectSettings.globalize_path(out), to, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)
