extends SceneTree
## Runs every test suite in its own headless Godot process and prints a
## summary. Exit code 0 only when all suites pass.
##   godot --headless --path . --script res://tests/run_all.gd [-- --quick]
## --quick skips the slow generator sweep (levels 31-400).

const SUITES := [
	["smoke", "res://tests/smoke_test.gd", []],
	["meta", "res://tests/meta_test.gd", []],
	["relaunch write", "res://tests/relaunch_check.gd", ["--", "--phase=write"]],
	["relaunch verify", "res://tests/relaunch_check.gd", ["--", "--phase=verify"]],
	["generator", "res://tests/generator_test.gd", []],
]


func _initialize() -> void:
	var quick := "--quick" in OS.get_cmdline_user_args()
	var exe := OS.get_executable_path()
	var project := ProjectSettings.globalize_path("res://")
	var results: Array = []
	var all_ok := true
	for suite in SUITES:
		if quick and suite[0] == "generator":
			continue
		var args := PackedStringArray(["--headless", "--path", project, "--script", suite[1]])
		args.append_array(PackedStringArray(suite[2]))
		var out: Array = []
		var t0 := Time.get_ticks_msec()
		var code := OS.execute(exe, args, out, true)
		var secs := (Time.get_ticks_msec() - t0) / 1000.0
		var text := "\n".join(PackedStringArray(out))
		var summary := ""
		for line in text.split("\n"):
			if line.contains("checks,") or line.contains("PASSED") or line.contains("FAILED") or line.contains("RELAUNCH"):
				summary = line.strip_edges()
		for line in text.split("\n"):
			if line.contains("FAIL ") or line.contains("SCRIPT ERROR") or line.contains("Parse Error"):
				print("   ", suite[0], ": ", line.strip_edges())
		var ok := code == 0
		all_ok = all_ok and ok
		results.append("%s %-16s %5.1fs  %s" % ["PASS" if ok else "FAIL", suite[0], secs, summary])
	print("\n== Test summary ==")
	for r in results:
		print(r)
	print("ALL TESTS PASSED" if all_ok else "SOME TESTS FAILED")
	quit(0 if all_ok else 1)
