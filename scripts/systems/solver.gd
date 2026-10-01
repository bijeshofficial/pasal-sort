class_name Solver
extends RefCounted
## Iterative depth-first solver with visited-state hashing.
##
## Jars are encoded as short strings (one character per candy) so states are
## cheap to copy and hash. The visited key sorts jars that share the same
## signature (capacity, lock, cloth), so boards that differ only by the order
## of interchangeable jars are explored once. Hidden candies are treated as
## known (they are fixed by the level seed).
##
## Returns {solvable, moves: [[a, b], ...], nodes, dead_ends, exhausted}.
## `exhausted` is true when the node budget ran out before an answer.

const A := 97  # 'a'


static func solve(board: Board, budget: int = 20000) -> Dictionary:
	var ctx := _Ctx.new()
	ctx.capacity = board.capacity
	ctx.cloth_after = board.cloth_after
	ctx.caps = board.caps.duplicate()
	ctx.locks = board.locks.duplicate()
	ctx.cloth = board.cloth.duplicate()
	ctx.sigs = []
	for i in board.jar_count():
		ctx.sigs.append("%d.%d.%d:" % [int(board.caps[i]), int(board.locks[i]), 1 if board.cloth[i] else 0])
	var start := PackedStringArray()
	for s in board.stacks:
		var str := ""
		for t in s:
			str += String.chr(A + int(t))
		start.append(str)
	return _search(ctx, start, budget)


## First move of a solution from this position, or [] if none was found.
static func hint(board: Board, budget: int = 6000) -> Array:
	var r := solve(board, budget)
	if r["solvable"] and not (r["moves"] as Array).is_empty():
		return r["moves"][0]
	return []


class _Ctx:
	var capacity := 4
	var cloth_after := 2
	var caps: Array
	var locks: Array
	var cloth: Array
	var sigs: Array


class _Frame:
	var state: PackedStringArray
	var moves: Array
	var idx := 0


static func _search(ctx: _Ctx, start: PackedStringArray, budget: int) -> Dictionary:
	var result := {"solvable": false, "moves": [], "nodes": 0, "dead_ends": 0, "exhausted": false}
	if _won(ctx, start):
		result["solvable"] = true
		return result
	var visited := {}
	visited[_key(ctx, start)] = true
	var root := _Frame.new()
	root.state = start
	root.moves = _moves(ctx, start)
	var frames: Array[_Frame] = [root]
	var path: Array = []
	var nodes := 0
	var dead := 0
	while not frames.is_empty():
		var f: _Frame = frames[frames.size() - 1]
		if f.idx >= f.moves.size():
			frames.pop_back()
			if not path.is_empty():
				path.pop_back()
			dead += 1
			continue
		var mv: Array = f.moves[f.idx]
		f.idx += 1
		var next := _apply(f.state, mv)
		var k := _key(ctx, next)
		if visited.has(k):
			continue
		visited[k] = true
		nodes += 1
		if nodes > budget:
			result["exhausted"] = true
			break
		path.append([mv[0], mv[1]])
		if _won(ctx, next):
			result["solvable"] = true
			result["moves"] = path
			break
		var child := _Frame.new()
		child.state = next
		child.moves = _moves(ctx, next)
		frames.append(child)
	result["nodes"] = nodes
	result["dead_ends"] = dead
	return result


static func _key(ctx: _Ctx, state: PackedStringArray) -> String:
	var parts := PackedStringArray()
	parts.resize(state.size())
	for i in state.size():
		parts[i] = ctx.sigs[i] + state[i]
	parts.sort()
	return "|".join(parts)


static func _is_done(ctx: _Ctx, s: String) -> bool:
	if s.length() != ctx.capacity:
		return false
	var c := s.unicode_at(0)
	for k in range(1, s.length()):
		if s.unicode_at(k) != c:
			return false
	return true


static func _won(ctx: _Ctx, state: PackedStringArray) -> bool:
	for s in state:
		if s.length() > 0 and not _is_done(ctx, s):
			return false
	return true


static func _run(s: String) -> int:
	var n := s.length()
	if n == 0:
		return 0
	var c := s.unicode_at(n - 1)
	var r := 0
	for k in range(n - 1, -1, -1):
		if s.unicode_at(k) != c:
			break
		r += 1
	return r


## Legal, non-pointless moves, best first (deterministic order).
static func _moves(ctx: _Ctx, state: PackedStringArray) -> Array:
	var n := state.size()
	var done: Array = []
	done.resize(n)
	var done_count := 0
	var done_types := {}
	for i in n:
		var d := _is_done(ctx, state[i])
		done[i] = d
		if d:
			done_count += 1
			done_types[state[i].unicode_at(0) - A] = true
	var sealed: Array = []
	sealed.resize(n)
	for i in n:
		var s := false
		if ctx.cloth[i] and done_count < ctx.cloth_after:
			s = true
		if int(ctx.locks[i]) >= 0 and not done_types.has(int(ctx.locks[i])):
			s = true
		sealed[i] = s
	var scored: Array = []
	for a in n:
		var sa := state[a]
		if sa.length() == 0 or done[a] or sealed[a]:
			continue
		var empty_sig_seen := {}
		var run := _run(sa)
		var ta := sa.unicode_at(sa.length() - 1)
		var uniform := run == sa.length()
		for b in n:
			if b == a or done[b] or sealed[b]:
				continue
			var sb := state[b]
			var free := int(ctx.caps[b]) - sb.length()
			if free <= 0:
				continue
			var score := 0
			var moved := mini(run, free)
			if sb.length() == 0:
				if uniform:
					continue  # pointless
				# Empty jars of the same kind are interchangeable: try the first.
				if empty_sig_seen.has(ctx.sigs[b]):
					continue
				empty_sig_seen[ctx.sigs[b]] = true
				score = 10 + (6 if run <= free else 0)
			else:
				if sb.unicode_at(sb.length() - 1) != ta:
					continue
				if sb.length() + moved == ctx.capacity and _run(sb) == sb.length():
					score = 100  # completes a jar
				elif moved == run:
					score = 40 + moved + (8 if uniform else 0) + (4 if _run(sb) == sb.length() else 0)
				else:
					score = 5
			scored.append([score, a, b, moved])
	scored.sort_custom(func(x: Array, y: Array) -> bool:
		if x[0] != y[0]:
			return x[0] > y[0]
		if x[1] != y[1]:
			return x[1] < y[1]
		return x[2] < y[2])
	var out: Array = []
	for s in scored:
		out.append([s[1], s[2], s[3]])
	return out


static func _apply(state: PackedStringArray, mv: Array) -> PackedStringArray:
	var a: int = mv[0]
	var b: int = mv[1]
	var n: int = mv[2]
	var next := state.duplicate()
	var sa := state[a]
	next[a] = sa.substr(0, sa.length() - n)
	next[b] = state[b] + sa.substr(sa.length() - n)
	return next
