extends SceneTree
## Generates levels 31-400 headless and checks every one is solvable and
## deterministic (same number -> same board). Also checks the difficulty
## rhythm: SUPER HARD levels need more moves than normal ones on average.
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
	for n in range(FROM, TO + 1):
		var ts := Time.get_ticks_msec()
		var a := LevelGenerator.generate(n)
		var dt := Time.get_ticks_msec() - ts
		if dt > slowest[1]:
			slowest = [n, dt]
		var b := LevelGenerator.generate(n)
		if JSON.stringify(a) != JSON.stringify(b):
			nondet.append(n)
		var board := Board.from_level(a)
		var r := Solver.solve(board, 80000)
		var counts_ok := true
		for c in board.type_counts().values():
			if int(c) != board.capacity:
				counts_ok = false
		if not r["solvable"] or not counts_ok:
			bad.append(n)
		var tier := String(a["tier"])
		if sums.has(tier):
			sums[tier][0] += int(a.get("solution", 0))
			sums[tier][1] += 1
	var avg := {}
	for k in sums.keys():
		avg[k] = float(sums[k][0]) / maxf(1.0, float(sums[k][1]))
	print("levels %d-%d in %.1f s (slowest: level %d, %d ms)" % [FROM, TO, (Time.get_ticks_msec() - t0) / 1000.0, slowest[0], slowest[1]])
	print("average solution length by tier: ", avg)
	var ok := true
	if not bad.is_empty():
		print("FAIL unsolvable or bad counts: ", bad)
		ok = false
	if not nondet.is_empty():
		print("FAIL not deterministic: ", nondet)
		ok = false
	if float(avg["super"]) <= float(avg["normal"]):
		print("FAIL super hard levels are not longer than normal ones")
		ok = false
	if float(avg["easy"]) >= float(avg["normal"]):
		print("FAIL easy levels are not shorter than normal ones")
		ok = false
	print("GENERATOR TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)
