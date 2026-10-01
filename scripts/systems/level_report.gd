class_name LevelReport
extends RefCounted
## Balancing CSV: one row per level (tier, types, jars, twists, solution
## length, dead ends, score, goal variant, generation ms). Used by
## tools/level_report.gd and the debug menu.


static func header() -> String:
	return "level,tier,types,jars,empty,twists,solution,dead_ends,score,move_limit,orders,ms"


static func row(n: int) -> String:
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
		var r := Solver.solve(Board.from_level(lvl), 80000)
		solution = (r["moves"] as Array).size()
		dead = int(r["dead_ends"])
	var twists := "+".join(PackedStringArray(lvl.get("twists", [])))
	return "%d,%s,%d,%d,%d,%s,%d,%d,%.1f,%d,%d,%d" % [n, lvl.get("tier", ""), int(lvl.get("types", jars.size() - empty)), jars.size(), empty, twists, solution, dead,
		float(lvl.get("score", solution + 0.5 * dead)), int(lvl.get("move_limit", 0)), (lvl.get("orders", []) as Array).size(), ms]


## Writes levels 1..to to `path`. Returns false if the file can't be written.
static func write(to: int, path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_line(header())
	for n in range(1, to + 1):
		f.store_line(row(n))
	f.close()
	return true
