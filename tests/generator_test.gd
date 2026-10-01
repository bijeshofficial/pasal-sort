extends SceneTree
## Generates levels 31-400 headless and checks every one is solvable and
## deterministic (same number -> same board; checked on a sample). Also the
## difficulty rhythm, twist coverage (cat, gift boxes), customer orders and
## move limits (SUPER HARD only, from level 60).
##   godot --headless --path . --script res://tests/generator_test.gd
## Exit code 0 on success.

const FROM := 31
const TO := 400


func _initialize() -> void:
	GameData.preload_all()
	var t0 := Time.get_ticks_msec()
	var bad: Array = []
	var nondet: Array = []
	var sums := {"normal": [0, 0], "super": [0, 0], "hard": [0, 0], "easy": [0, 0]}
	var slowest := [0, 0]
	var cats := 0
	var gifts := 0
	var orders := 0
	var limits := 0
	var ok := true
	for n in range(FROM, TO + 1):
		var ts := Time.get_ticks_msec()
		var a := LevelGenerator.generate(n)
		var dt := Time.get_ticks_msec() - ts
		if dt > slowest[1]:
			slowest = [n, dt]
		if n % 7 == 0:
			var b := LevelGenerator.generate(n)
			if JSON.stringify(a) != JSON.stringify(b):
				nondet.append(n)
		var board := Board.from_level(a)
		var solvable := false
		if a.has("cat"):
			# Cat levels carry the solution their route was planned from.
			var replay := Board.from_level(a)
			solvable = true
			for mv in a.get("solution_moves", []):
				if not replay.can_move(int(mv[0]), int(mv[1])):
					solvable = false
					break
				replay.apply_move(int(mv[0]), int(mv[1]))
			solvable = solvable and replay.is_won()
			cats += 1
		else:
			solvable = bool(Solver.solve(board, 80000)["solvable"])
		var counts_ok := true
		for c in board.type_counts().values():
			if int(c) != board.capacity:
				counts_ok = false
		if not solvable or not counts_ok:
			bad.append(n)
		for j in a["jars"]:
			if bool(j.get("gift", false)):
				gifts += 1
				break
		if not (a.get("orders", []) as Array).is_empty():
			orders += 1
		if int(a.get("move_limit", 0)) > 0:
			limits += 1
			if String(a["tier"]) != "super" or n < 60:
				print("FAIL move limit on a non-SUPER-HARD level ", n)
				ok = false
		if (a.get("twists", []) as Array).size() > 2:
			print("FAIL more than 2 twist types on level ", n)
			ok = false
		var tier := String(a["tier"])
		if sums.has(tier):
			sums[tier][0] += int(a.get("solution", 0))
			sums[tier][1] += 1
	var avg := {}
	for k in sums.keys():
		avg[k] = float(sums[k][0]) / maxf(1.0, float(sums[k][1]))
	print("levels %d-%d in %.1f s (slowest: level %d, %d ms)" % [FROM, TO, (Time.get_ticks_msec() - t0) / 1000.0, slowest[0], slowest[1]])
	print("average solution length by tier: ", avg)
	print("cat levels %d, gift boxes %d, customer orders %d, move limits %d" % [cats, gifts, orders, limits])
	if not bad.is_empty():
		print("FAIL unsolvable or bad counts: ", bad)
		ok = false
	if not nondet.is_empty():
		print("FAIL not deterministic: ", nondet)
		ok = false
	if cats == 0 or gifts == 0 or orders == 0 or limits == 0:
		print("FAIL a twist or goal variant never appears")
		ok = false
	if float(avg["super"]) <= float(avg["normal"]):
		print("FAIL super hard levels are not longer than normal ones")
		ok = false
	if float(avg["easy"]) >= float(avg["normal"]):
		print("FAIL easy levels are not shorter than normal ones")
		ok = false
	print("GENERATOR TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)
