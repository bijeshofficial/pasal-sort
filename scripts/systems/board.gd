class_name Board
extends RefCounted
## The puzzle model: jars of candies, move rules, jar completion and twists.
## Pure data (no nodes), so it is safe on worker threads and in tests.
##
## A jar is complete when it holds exactly `capacity` candies of one type.
## Twists are derived from the stacks, so undo just restores the stacks:
##   cloth  - covered until `cloth_after` jars are complete
##   lock   - locked until a jar of that candy type is complete
##   caps   - a tall jar has a larger capacity (it still completes at `capacity`)
##   hidden - wrapped candies; a wrapper opens when the candy becomes the top
##   gifts  - a gift box under the candies (cosmetic for the rules: the jar
##            holds `capacity` candies); it opens when the jar completes
##   cat    - Biralo naps on cat_path[(move_count / cat_every) % size]; that
##            jar is sealed. The cat hops every `cat_every` moves, so the
##            move count is part of the state (undo restores it).

var capacity := 4
var cloth_after := 2
var stacks: Array = []   # Array of Array[int], bottom -> top
var hidden: Array = []   # Array of Array[bool], parallel to stacks
var caps: Array = []     # Array[int]
var cloth: Array = []    # Array[bool]
var locks: Array = []    # Array[int], candy type or -1
var gifts: Array = []    # Array[bool]
var cat_path: Array = [] # jar indices the cat visits in order
var cat_every := 5
var move_count := 0


static func from_level(level: Dictionary) -> Board:
	var b := Board.new()
	b.capacity = int(level.get("capacity", 4))
	b.cloth_after = int(level.get("cloth_after", 2))
	for k in level.get("cat", []):
		b.cat_path.append(int(k))
	b.cat_every = maxi(1, int(level.get("cat_every", 5)))
	b.move_count = int(level.get("move_count", 0))
	for j in level.get("jars", []):
		var c: Array = []
		for t in j.get("c", []):
			c.append(int(t))
		var h: Array = []
		h.resize(c.size())
		h.fill(false)
		for idx in j.get("h", []):
			if int(idx) < c.size():
				h[int(idx)] = true
		if not c.is_empty():
			h[c.size() - 1] = false  # the top candy is always visible
		b.stacks.append(c)
		b.hidden.append(h)
		b.caps.append(int(j.get("cap", b.capacity)))
		b.cloth.append(bool(j.get("cloth", false)))
		b.locks.append(int(j.get("lock", -1)))
		b.gifts.append(bool(j.get("gift", false)))
	return b


func duplicate_board() -> Board:
	var b := Board.new()
	b.capacity = capacity
	b.cloth_after = cloth_after
	b.stacks = stacks.duplicate(true)
	b.hidden = hidden.duplicate(true)
	b.caps = caps.duplicate()
	b.cloth = cloth.duplicate()
	b.locks = locks.duplicate()
	b.gifts = gifts.duplicate()
	b.cat_path = cat_path.duplicate()
	b.cat_every = cat_every
	b.move_count = move_count
	return b


func to_dict() -> Dictionary:
	var jars: Array = []
	for i in stacks.size():
		var j := {"c": (stacks[i] as Array).duplicate()}
		var h: Array = []
		for k in (hidden[i] as Array).size():
			if hidden[i][k]:
				h.append(k)
		if not h.is_empty():
			j["h"] = h
		if caps[i] != capacity:
			j["cap"] = caps[i]
		if cloth[i]:
			j["cloth"] = true
		if locks[i] >= 0:
			j["lock"] = locks[i]
		if gifts[i]:
			j["gift"] = true
		jars.append(j)
	var d := {"capacity": capacity, "cloth_after": cloth_after, "jars": jars}
	if not cat_path.is_empty():
		d["cat"] = cat_path.duplicate()
		d["cat_every"] = cat_every
		d["move_count"] = move_count
	return d


func jar_count() -> int:
	return stacks.size()


func size_of(i: int) -> int:
	return (stacks[i] as Array).size()


func top(i: int) -> int:
	var s: Array = stacks[i]
	return -1 if s.is_empty() else int(s[s.size() - 1])


## Number of consecutive same-type candies on top of jar i.
func top_run(i: int) -> int:
	var s: Array = stacks[i]
	if s.is_empty():
		return 0
	var t: int = s[s.size() - 1]
	var n := 0
	for k in range(s.size() - 1, -1, -1):
		if s[k] != t:
			break
		n += 1
	return n


func space(i: int) -> int:
	return int(caps[i]) - size_of(i)


func is_uniform(i: int) -> bool:
	var s: Array = stacks[i]
	return not s.is_empty() and top_run(i) == s.size()


func is_done(i: int) -> bool:
	return size_of(i) == capacity and is_uniform(i)


func done_count() -> int:
	var n := 0
	for i in stacks.size():
		if is_done(i):
			n += 1
	return n


func is_type_completed(t: int) -> bool:
	for i in stacks.size():
		if is_done(i) and top(i) == t:
			return true
	return false


func is_cloth_on(i: int) -> bool:
	return bool(cloth[i]) and done_count() < cloth_after


func is_locked(i: int) -> bool:
	return int(locks[i]) >= 0 and not is_type_completed(int(locks[i]))


## The jar Biralo is sitting on (-1 = no cat).
func cat_jar() -> int:
	if cat_path.is_empty():
		return -1
	return int(cat_path[(move_count / cat_every) % cat_path.size()])


func is_cat_on(i: int) -> bool:
	return cat_jar() == i


## Moves until the cat hops (0 = no cat).
func moves_until_cat_hops() -> int:
	if cat_path.is_empty():
		return 0
	return cat_every - move_count % cat_every


## Covered by cloth, padlocked or under the cat: cannot give or take candies.
func is_sealed(i: int) -> bool:
	return is_cloth_on(i) or is_locked(i) or is_cat_on(i)


func can_select(i: int) -> bool:
	return i >= 0 and i < stacks.size() and size_of(i) > 0 and not is_done(i) and not is_sealed(i)


func can_move(a: int, b: int) -> bool:
	if a == b or not can_select(a) or b < 0 or b >= stacks.size():
		return false
	if is_done(b) or is_sealed(b) or space(b) <= 0:
		return false
	return size_of(b) == 0 or top(b) == top(a)


func move_amount(a: int, b: int) -> int:
	return mini(top_run(a), space(b))


## Pointless: pouring a jar that holds only one candy type into an empty jar.
func is_pointless(a: int, b: int) -> bool:
	return size_of(b) == 0 and is_uniform(a)


## Applies a legal move. Returns what happened so the view can animate it:
## {count, type, completed (bool), revealed [jar], unsealed [jar], won}.
func apply_move(a: int, b: int) -> Dictionary:
	if not can_move(a, b):
		return {}
	var sealed_before: Array = []
	for i in stacks.size():
		sealed_before.append(is_sealed(i))
	var cat_before := cat_jar()
	var n := move_amount(a, b)
	var t := top(a)
	var src: Array = stacks[a]
	var dst: Array = stacks[b]
	for k in n:
		src.pop_back()
		(hidden[a] as Array).pop_back()
		dst.append(t)
		(hidden[b] as Array).append(false)
	var revealed: Array = []
	if not src.is_empty() and hidden[a][src.size() - 1]:
		hidden[a][src.size() - 1] = false
		revealed.append(a)
	var completed := is_done(b)
	if completed:
		# A completed jar shows all its candies.
		for k in (hidden[b] as Array).size():
			hidden[b][k] = false
	move_count += 1
	var unsealed: Array = []
	for i in stacks.size():
		if sealed_before[i] and not is_sealed(i) and i != cat_before:
			unsealed.append(i)
	var gift := completed and bool(gifts[b])
	return {"count": n, "type": t, "completed": completed, "revealed": revealed, "unsealed": unsealed, "won": is_won(),
		"cat_from": cat_before, "cat_to": cat_jar(), "gift": gift}


func is_won() -> bool:
	for i in stacks.size():
		if size_of(i) > 0 and not is_done(i):
			return false
	return true


## Legal moves minus pointless ones.
func useful_moves() -> Array:
	var out: Array = []
	for a in stacks.size():
		if not can_select(a):
			continue
		for b in stacks.size():
			if can_move(a, b) and not is_pointless(a, b):
				out.append([a, b])
	return out


func has_useful_move() -> bool:
	for a in stacks.size():
		if not can_select(a):
			continue
		for b in stacks.size():
			if can_move(a, b) and not is_pointless(a, b):
				return true
	# With the cat, any legal move passes time until it hops.
	if not cat_path.is_empty():
		for a in stacks.size():
			for b in stacks.size():
				if can_move(a, b):
					return true
	return false


func add_jar(cap: int = -1) -> int:
	stacks.append([])
	hidden.append([])
	caps.append(capacity if cap <= 0 else cap)
	cloth.append(false)
	locks.append(-1)
	gifts.append(false)
	return stacks.size() - 1


## Haat Helper: the moves that gather `type` from jar tops into an empty jar
## (up to `capacity`). Returns [[from, to], ...] or [] when there is no
## empty jar or nothing to gather. Doesn't change the board.
func helper_moves(type: int) -> Array:
	var target := -1
	for i in stacks.size():
		if size_of(i) == 0 and not is_sealed(i):
			target = i
			break
	if target < 0:
		return []
	var sim := duplicate_board()
	var out: Array = []
	var guard := 0
	while sim.size_of(target) < capacity and guard < 64:
		guard += 1
		var best := -1
		for i in sim.stacks.size():
			if i != target and sim.can_move(i, target) and sim.top(i) == type and (sim.size_of(target) == 0 or sim.top(target) == type):
				best = i
				break
		if best < 0:
			break
		sim.apply_move(best, target)
		sim.move_count -= 1   # the helper isn't a move
		out.append([best, target])
	return out


## Candy types currently on top of a jar that can give candies.
func top_types() -> Array:
	var out: Array = []
	for i in stacks.size():
		if can_select(i) and not out.has(top(i)):
			out.append(top(i))
	out.sort()
	return out


## Jars whose candies a Shuffle may redistribute: unfinished and not sealed.
func shuffle_jars() -> Array:
	var out: Array = []
	for i in stacks.size():
		if not is_done(i) and not is_sealed(i) and size_of(i) > 0:
			out.append(i)
	return out


## Redistributes the candies of shuffle_jars() randomly, keeping each jar's
## count. Wrappers open. Rejects arrangements that are unsolvable or that
## complete a jar for free. Returns false if no good arrangement was found
## (the board is then unchanged).
func shuffle(rng: RandomNumberGenerator, tries: int = 30, budget: int = 8000) -> bool:
	var jars := shuffle_jars()
	if jars.size() < 2:
		return false
	var pool: Array = []
	for i in jars:
		pool.append_array(stacks[i])
	var original := stacks.duplicate(true)
	var original_hidden := hidden.duplicate(true)
	for attempt in tries:
		_shuffle_array(pool, rng)
		var k := 0
		for i in jars:
			var n := size_of(i)
			stacks[i] = pool.slice(k, k + n)
			var h: Array = []
			h.resize(n)
			h.fill(false)
			hidden[i] = h
			k += n
		var instant := false
		var unchanged := true
		for i in jars:
			if is_done(i):
				instant = true
			if stacks[i] != original[i]:
				unchanged = false
		if instant or unchanged:
			continue
		if Solver.solve(self, budget, true)["solvable"]:
			return true
	stacks = original
	hidden = original_hidden
	return false


static func _shuffle_array(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = a[i]
		a[i] = a[j]
		a[j] = tmp


## Candy count per type (for invariant checks).
func type_counts() -> Dictionary:
	var out := {}
	for s in stacks:
		for t in s:
			out[t] = int(out.get(t, 0)) + 1
	return out


func total_candies() -> int:
	var n := 0
	for s in stacks:
		n += (s as Array).size()
	return n
