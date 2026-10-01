class_name LevelGenerator
extends RefCounted
## Levels 1-30 come from data/levels_authored.json. From 31 on, a level is
## generated from its number: the number seeds every random choice, so level
## 500 is always the same puzzle. Each candidate board is verified with the
## Solver; unsolvable or over-budget boards move on to seed+1, seed+2, ...
## Difficulty = solution length + weighted dead ends, and the tier decides
## which verified candidate is kept (easiest, median or hardest).
##
## Pure static code (no nodes): runs on a worker thread.

const TWIST_ORDER := ["wrapped", "cloth", "lock", "tall", "cat", "gift"]


static func generate(level: int) -> Dictionary:
	var authored := GameData.authored_level(level)
	if not authored.is_empty():
		var out: Dictionary = authored.duplicate(true)
		if not out.has("tier"):
			out["tier"] = tier_for(level)
		if not out.has("capacity"):
			out["capacity"] = GameData.capacity()
		return decorate(level, out)
	var p := params_for(level)
	return decorate(level, build(level, p))


## Goal variants on top of the board, from the level number:
##   customer orders (from L25, sometimes): cards asking for candy types,
##     each with a patience (jar completions) - optional bonus coins;
##   move limit (SUPER HARD from L60): solution length x factor + slack.
static func decorate(level: int, lvl: Dictionary) -> Dictionary:
	var d := GameData.difficulty()
	var rng := RandomNumberGenerator.new()
	rng.seed = base_seed(level) ^ 0x2545f491
	var types := int(lvl.get("types", 0))
	if types <= 0:
		var seen := {}
		for j in lvl.get("jars", []):
			for t in j.get("c", []):
				seen[int(t)] = true
		types = seen.size()
	var oc: Dictionary = d.get("orders", {})
	var tier := String(lvl.get("tier", "normal"))
	var ml: Dictionary = d.get("move_limit", {})
	if tier == "super" and level >= int(ml.get("from", 60)) and lvl.has("solution"):
		lvl["move_limit"] = int(ceil(float(lvl["solution"]) * float(ml.get("factor", 1.5)))) + int(ml.get("slack", 3))
	elif level >= int(oc.get("from", 25)) and types >= 3 and String(lvl.get("teach", "")) == "" \
			and (level == int(oc.get("teach_level", 25)) or rng.randf() < float(oc.get("chance", 0.4))):
		var count := rng.randi_range(1, mini(int(oc.get("max_cards", 3)), maxi(1, types - 2)))
		if level == int(oc.get("teach_level", 25)):
			count = 1
		var pool: Array = range(types)
		Board._shuffle_array(pool, rng)
		var orders: Array = []
		for k in count:
			orders.append({"type": int(pool[k]), "patience": k + 2 + rng.randi_range(0, 1),
				"bonus": rng.randi_range(int(oc.get("bonus_min", 5)), int(oc.get("bonus_max", 10)))})
		lvl["orders"] = orders
	return lvl


static func base_seed(level: int) -> int:
	return (level * 7919 + 104729) % 2147483647


## Difficulty tier from the sawtooth rhythm: every 5th level HARD, every 10th
## SUPER HARD, the level after a hard one is easier. A twist's first level is
## always a gentle teaching level.
static func tier_for(level: int) -> String:
	var authored := GameData.authored_level(level)
	if authored.has("tier"):
		return String(authored["tier"])
	if teaching_twist(level) != "":
		return "easy"
	var r: Dictionary = GameData.difficulty()["rhythm"]
	var hard_every := int(r.get("hard_every", 5))
	var super_every := int(r.get("super_every", 10))
	if level % super_every == 0:
		return "super"
	if level % hard_every == 0:
		return "hard"
	if bool(r.get("easy_after_hard", true)) and level > 1 and (level - 1) % hard_every == 0 and tier_for(level - 1) in ["hard", "super"]:
		return "easy"
	return "normal"


static func teaching_twist(level: int) -> String:
	var tw: Dictionary = GameData.difficulty()["twists"]
	for id in TWIST_ORDER:
		if tw.has(id) and int(tw[id]["from"]) == level:
			return id
	return ""


static func band_for(level: int) -> Dictionary:
	var chosen: Dictionary = {}
	for b in GameData.difficulty()["bands"]:
		if level >= int(b["from"]):
			chosen = b
	return chosen


static func params_for(level: int) -> Dictionary:
	var d := GameData.difficulty()
	var rng := RandomNumberGenerator.new()
	rng.seed = base_seed(level) ^ 0x5bd1e995
	var band := band_for(level)
	var types := int(band.get("types", 4))
	if band.has("types_max"):
		types = rng.randi_range(types, int(band["types_max"]))
	var tier := tier_for(level)
	match tier:
		"easy":
			types = maxi(3, types + int(d["rhythm"].get("easy_types_delta", -1)))
		"hard":
			types += int(d["rhythm"].get("hard_types_delta", 0))
		"super":
			types += int(d["rhythm"].get("super_types_delta", 1))
	types = clampi(types, 2, GameData.candies().size())
	var empty := int(band.get("empty", d.get("empty_jars", 2)))
	var twists: Array = []
	var teach := teaching_twist(level)
	if teach != "":
		twists = [teach]
	else:
		var avail: Array = []
		var tw: Dictionary = d["twists"]
		for id in TWIST_ORDER:
			if tw.has(id) and level > int(tw[id]["from"]):
				avail.append(id)
		# Never more than 2 twist types in one level (max_twists).
		var roll := rng.randf()
		if level >= int(d.get("twist_combo_from", 120)) and avail.size() >= 2 and roll < float(d.get("twist_combo_chance", 0.35)):
			var first: String = avail[rng.randi_range(0, avail.size() - 1)]
			var second: String = first
			while second == first:
				second = avail[rng.randi_range(0, avail.size() - 1)]
			twists = [first, second]
		elif not avail.is_empty() and roll < float(d.get("twist_chance", 0.45)):
			twists = [avail[rng.randi_range(0, avail.size() - 1)]]
	var tier_def: Dictionary = d["tiers"].get(tier, {})
	return {
		"types": types,
		"empty": empty,
		"tier": tier,
		"twists": twists,
		"teach": teach,
		"candidates": int(tier_def.get("candidates", 3)),
		"pick": String(tier_def.get("pick", "median")),
	}


## Builds a verified level. `p` comes from params_for() (or a tool script).
static func build(level: int, p: Dictionary) -> Dictionary:
	var d := GameData.difficulty()
	var gen: Dictionary = d["generator"]
	var budget := int(gen.get("node_budget", 20000))
	var max_attempts := int(gen.get("max_attempts", 40))
	var weight := float(gen.get("dead_end_weight", 0.5))
	var cap := GameData.capacity()
	var wanted := maxi(1, int(p.get("candidates", 3)))
	var seed0 := int(p.get("seed", base_seed(level)))
	var found: Array = []
	# Deterministic effort cap: once this many solver nodes have been spent,
	# keep the candidates found so far (big boards stay under ~1 s).
	var total_budget := int(gen.get("total_node_budget", 9000))
	var spent := 0
	for attempt in max_attempts:
		if not found.is_empty() and spent > total_budget:
			break
		var rng := RandomNumberGenerator.new()
		rng.seed = seed0 + attempt
		var lvl := _random_board(level, p, cap, rng)
		if lvl.is_empty():
			continue
		var board := Board.from_level(lvl)
		var r := Solver.solve(board, budget)
		spent += int(r["nodes"])
		if not r["solvable"]:
			continue
		if lvl.has("_wants_cat"):
			lvl.erase("_wants_cat")
			var path := _plan_cat(lvl, r["moves"], rng)
			if path.is_empty():
				continue
			lvl["cat"] = path
			# Replay the solution with the cat to be sure every move is legal.
			var check := Board.from_level(lvl)
			var legal := true
			for mv in r["moves"]:
				if not check.can_move(int(mv[0]), int(mv[1])):
					legal = false
					break
				check.apply_move(int(mv[0]), int(mv[1]))
			if not legal or not check.is_won():
				continue
			lvl["solution_moves"] = r["moves"]
		lvl["seed"] = seed0 + attempt
		lvl["solution"] = (r["moves"] as Array).size()
		lvl["dead_ends"] = r["dead_ends"]
		lvl["score"] = snappedf((r["moves"] as Array).size() + weight * float(r["dead_ends"]), 0.1)
		found.append(lvl)
		if found.size() >= wanted:
			break
	if found.is_empty():
		# Extremely unlikely: fall back to the same size with no twists.
		push_warning("LevelGenerator: no solvable board for level %d; dropping twists" % level)
		var q := p.duplicate()
		q["twists"] = []
		q["seed"] = seed0 + 1000
		q["_depth"] = int(p.get("_depth", 0)) + 1
		if p.get("twists", []).is_empty():
			q["types"] = maxi(2, int(p["types"]) - 1)
		return build(level, q)
	return _pick(found, String(p.get("pick", "median")))


static func _pick(found: Array, how: String) -> Dictionary:
	var order: Array = range(found.size())
	order.sort_custom(func(x: int, y: int) -> bool:
		var sx := float(found[x]["score"])
		var sy := float(found[y]["score"])
		if sx != sy:
			return sx < sy
		return x < y)
	var idx: int
	match how:
		"min":
			idx = order[0]
		"max":
			idx = order[order.size() - 1]
		_:
			idx = order[order.size() / 2]
	return found[idx]


static func _random_board(level: int, p: Dictionary, cap: int, rng: RandomNumberGenerator) -> Dictionary:
	var types := int(p["types"])
	var empty := int(p["empty"])
	var pool: Array = []
	for t in types:
		for k in cap:
			pool.append(t)
	Board._shuffle_array(pool, rng)
	var jars: Array = []
	for j in types:
		var c: Array = pool.slice(j * cap, (j + 1) * cap)
		var uniform := true
		for x in c:
			if x != c[0]:
				uniform = false
		if uniform:
			return {}  # never start with a finished jar
		jars.append({"c": c})
	for j in empty:
		jars.append({"c": []})
	var twists: Array = p.get("twists", [])
	var tw: Dictionary = GameData.difficulty()["twists"]
	var special := {}  # jar index -> twist id (one twist per jar)
	var wants_cat := false
	for id in twists:
		match id:
			"wrapped":
				var ratio := float(tw["wrapped"].get("hidden_ratio", 0.45))
				for j in types:
					var h: Array = []
					for k in cap - 1:
						if rng.randf() < ratio:
							h.append(k)
					if not h.is_empty():
						jars[j]["h"] = h
			"cloth":
				var j := _free_filled_jar(types, special, rng)
				if j >= 0:
					jars[j]["cloth"] = true
					special[j] = "cloth"
			"lock":
				var j := _free_filled_jar(types, special, rng)
				if j >= 0:
					var inside: Array = jars[j]["c"]
					var options: Array = []
					for t in types:
						if not inside.has(t):
							options.append(t)
					if options.is_empty():
						for t in types:
							options.append(t)
					jars[j]["lock"] = options[rng.randi_range(0, options.size() - 1)]
					special[j] = "lock"
			"tall":
				var j := _free_filled_jar(types, special, rng)
				if j >= 0:
					jars[j]["cap"] = cap + int(tw["tall"].get("extra", 2))
					special[j] = "tall"
			"gift":
				for k in rng.randi_range(1, int(tw["gift"].get("max", 2))):
					var j := _free_filled_jar(types, special, rng)
					if j >= 0:
						jars[j]["gift"] = true
						special[j] = "gift"
			"cat":
				# The route is planned after solving (see _plan_cat).
				wants_cat = true
	var out := {
		"level": level,
		"capacity": cap,
		"cloth_after": int(tw.get("cloth", {}).get("unlock_after", 2)),
		"types": types,
		"tier": String(p.get("tier", "normal")),
		"twists": twists.duplicate(),
		"teach": String(p.get("teach", "")),
		"jars": jars,
	}
	if wants_cat:
		out["cat_every"] = int(tw["cat"].get("every", 5))
		out["_wants_cat"] = true
	return out


## Biralo's route, planned from a known solution so the level stays
## solvable by construction: in each window of `every` moves the cat sits on
## a jar that the solution doesn't touch in that window (filled jars first,
## never twice in a row). Returns [] if no route exists.
static func _plan_cat(lvl: Dictionary, solution: Array, rng: RandomNumberGenerator) -> Array:
	var every := int(lvl.get("cat_every", 5))
	var n := (lvl["jars"] as Array).size()
	var windows := int(ceil(float(solution.size()) / every)) + 1
	var path: Array = []
	var prev := -1
	for w in windows:
		var used := {}
		for k in range(w * every, mini((w + 1) * every, solution.size())):
			used[int(solution[k][0])] = true
			used[int(solution[k][1])] = true
		var filled: Array = []
		var others: Array = []
		for i in n:
			if used.has(i) or i == prev:
				continue
			if ((lvl["jars"][i] as Dictionary).get("c", []) as Array).is_empty():
				others.append(i)
			else:
				filled.append(i)
		var pick: Array = filled if not filled.is_empty() else others
		if pick.is_empty():
			return []
		prev = int(pick[rng.randi_range(0, pick.size() - 1)])
		path.append(prev)
	return path


static func _free_filled_jar(types: int, special: Dictionary, rng: RandomNumberGenerator) -> int:
	var options: Array = []
	for j in types:
		if not special.has(j):
			options.append(j)
	if options.is_empty():
		return -1
	return options[rng.randi_range(0, options.size() - 1)]
