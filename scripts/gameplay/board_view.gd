class_name BoardView
extends Node2D
## Visual side of the board: lays jars out on wooden shelves, keeps one
## CandyVisual per candy in the model, and animates moves (candies fly along
## an arc one after another), lids, cloth, padlocks, shuffles and the level
## intro. It never changes the Board; Gameplay does that and calls in here.

const JarScene := preload("res://scenes/components/jar_visual.tscn")
const CandyScene := preload("res://scenes/components/candy_visual.tscn")

const FLY_TIME := 0.3
const STAGGER := 0.04
# Pouring: candies leave the tilted jar this far apart and take this long
# to tumble from its mouth into the target.
const POUR_STEP := 0.075
const DROP_TIME := 0.34
const POUR_ANGLE := 62.0

var board: Board
var jars: Array[JarVisual] = []
var stacks: Array = []            # Array of Array[CandyVisual], mirrors board.stacks
var area := Rect2()
var jar_width := 180.0
var skin: Dictionary = {}
var wrapper_style := "classic"

var fly_layer: Node2D
var _jar_layer: Node2D
var _rows: Array = []            # [{y, x0, x1}]
var _busy_until := 0.0
var _glint_t := 2.0


func _init() -> void:
	_jar_layer = Node2D.new()
	_jar_layer.name = "Jars"
	add_child(_jar_layer)
	fly_layer = Node2D.new()
	fly_layer.name = "Flying"
	fly_layer.z_index = 20
	add_child(fly_layer)


func build(b: Board, rect: Rect2, skin_data: Dictionary, style: String, intro: bool = true) -> void:
	board = b
	area = rect
	skin = skin_data
	wrapper_style = style
	for j in jars:
		j.queue_free()
	jars.clear()
	stacks.clear()
	for i in board.jar_count():
		_create_jar(i)
	layout(false)
	sync_all()
	if intro:
		_intro()


func _create_jar(i: int) -> JarVisual:
	var j: JarVisual = JarScene.instantiate()
	_jar_layer.add_child(j)
	jars.append(j)
	stacks.append([])
	j.lid_closed.connect(_on_lid_closed.bind(j))
	return j


# --- Layout ------------------------------------------------------------------

func rows_for(n: int) -> int:
	if n <= 5:
		return 1
	if n <= 14:
		return 2
	return 3


func layout(animate: bool = true) -> void:
	var n := jars.size()
	if n == 0:
		return
	var rows := rows_for(n)
	var per_row := ceili(float(n) / rows)
	var max_slots := 4
	for i in n:
		max_slots = maxi(max_slots, int(board.caps[i]))
	var gap := 22.0
	var by_width := (area.size.x - gap * (per_row + 1)) / per_row
	# Jar height ~ width * (0.42 + 0.64 * slots); keep head-room for lifts/lids.
	var h_factor := 0.42 + 0.64 * max_slots + 0.55
	var by_height := (area.size.y - 30.0 * rows) / (rows * h_factor)
	jar_width = clampf(minf(by_width, by_height), 110.0, 230.0)
	var row_h := jar_width * h_factor
	var total_h := row_h * rows + 30.0 * (rows - 1)
	var top := area.position.y + maxf(0.0, (area.size.y - total_h) * 0.45)
	_rows.clear()
	var idx := 0
	for r in rows:
		var count := mini(per_row, n - idx)
		if r == rows - 1:
			count = n - idx
		var pitch := jar_width + gap + (8.0 if count <= 4 else 0.0) + (40.0 if count <= 3 else 0.0)
		var row_w := pitch * count - gap
		var x0 := area.position.x + (area.size.x - row_w) * 0.5 + jar_width * 0.5
		var y := top + row_h * (r + 1) + 30.0 * r - jar_width * 0.08
		_rows.append({"y": y, "x0": x0 - jar_width * 0.5 - 30.0, "x1": x0 + pitch * (count - 1) + jar_width * 0.5 + 30.0})
		for k in count:
			var j := jars[idx]
			j.setup(jar_width, int(board.caps[idx]), skin)
			var pos := Vector2(x0 + pitch * k, y)
			if animate:
				j.move_home(pos)
			else:
				j.place(pos)
			_restack(idx, animate)
			idx += 1
	queue_redraw()


## Snaps (or eases) a jar's settled candies to their slots after a resize.
func _restack(i: int, animate: bool) -> void:
	var j := jars[i]
	var list: Array = stacks[i]
	for k in list.size():
		var c: CandyVisual = list[k]
		if c.get_parent() != j.candies:
			continue
		c.diameter = j.candy_diameter()
		c.queue_redraw()
		if animate:
			c.create_tween().tween_property(c, "position", j.slot_position(k), 0.25)
		else:
			c.position = j.slot_position(k)


func _process(delta: float) -> void:
	_glint_t -= delta
	if _glint_t <= 0.0 and not jars.is_empty():
		_glint_t = randf_range(2.0, 4.0)
		var j: JarVisual = jars[randi() % jars.size()]
		if j.rotation == 0.0:
			j.glint()


## Glass shelves under each row of jars.
func _draw() -> void:
	for r in _rows:
		var y: float = r["y"]
		var x0: float = r["x0"]
		var x1: float = r["x1"]
		var th := 30.0
		# A glowing glass shelf.
		var cx := (x0 + x1) * 0.5
		var half := (x1 - x0) * 0.5
		for k in 3:
			draw_colored_polygon(DrawKit.ellipse(Vector2(cx, y + th * 0.5), half * (1.0 - k * 0.12), 46.0 - k * 12.0, 40), Color(1, 1, 1, 0.04))
		var plank := DrawKit.rounded_rect(Rect2(x0, y, x1 - x0, th), th * 0.5, 6)
		DrawKit.gradient_fill(self, plank, Color(1, 1, 1, 0.55), Color(0.78, 0.72, 1.0, 0.28))
		DrawKit.outline(self, plank, Color(1, 1, 1, 0.6), 3.0)
		draw_line(Vector2(x0 + th, y + 6), Vector2(x1 - th, y + 6), Color(1, 1, 1, 0.8), 3.0, true)


## Index of the jar under a board-space point, or -1.
func jar_at(p: Vector2) -> int:
	for i in jars.size():
		var j := jars[i]
		var r := j.hit_rect()
		r.position += j.home_position
		if r.has_point(p):
			return i
	return -1


func jar_top(i: int) -> Vector2:
	var j := jars[i]
	return j.home_position + Vector2(0, -j.total_height())


func jar_center(i: int) -> Vector2:
	var j := jars[i]
	return j.home_position + Vector2(0, -j.total_height() * 0.5)


# --- State sync --------------------------------------------------------------

## Makes jar i's candy nodes match the model exactly (instantly).
func sync_jar(i: int) -> void:
	var j := jars[i]
	var list: Array = stacks[i]
	var model: Array = board.stacks[i]
	var ok := list.size() == model.size()
	if ok:
		for k in list.size():
			if (list[k] as CandyVisual).type != int(model[k]):
				ok = false
				break
	if not ok:
		for c in list:
			(c as CandyVisual).queue_free()
		list.clear()
		for k in model.size():
			var c: CandyVisual = CandyScene.instantiate()
			j.candies.add_child(c)
			c.setup(int(model[k]), false, wrapper_style, j.candy_diameter())
			list.append(c)
	for k in list.size():
		var c: CandyVisual = list[k]
		if c.get_parent() == fly_layer:
			continue
		if c.get_parent() != j.candies:
			c.reparent(j.candies, false)
		if c.tween:
			c.tween.kill()
		c.position = j.slot_position(k)
		c.rotation = 0.0
		c.scale = Vector2.ONE
		c.selected = false
		c.set_hidden(bool(board.hidden[i][k]))
	_sync_jar_state(i, false)


func sync_all() -> void:
	for i in jars.size():
		sync_jar(i)


func _sync_jar_state(i: int, animate: bool) -> void:
	var j := jars[i]
	var done := board.is_done(i)
	if done and not j.done:
		j.close_lid(GameData.candy_color(board.top(i)), animate)
	elif not done and j.done:
		j.open_lid()
	j.set_cloth(board.is_cloth_on(i), animate)
	j.set_lock(int(board.locks[i]), board.is_locked(i), animate)
	j.set_dimmed(board.is_sealed(i))


func refresh_states(animate: bool = true) -> void:
	for i in jars.size():
		_sync_jar_state(i, animate)


# --- Selection ---------------------------------------------------------------

func select(i: int, on: bool) -> void:
	if i < 0 or i >= jars.size():
		return
	jars[i].set_selected(on)
	var list: Array = stacks[i]
	var run := board.top_run(i) if on else list.size()
	for k in list.size():
		(list[k] as CandyVisual).selected = on and k >= list.size() - run


# --- Moves -------------------------------------------------------------------

## Animates the model move a -> b that just happened. Returns its duration.
func animate_move(a: int, b: int, result: Dictionary) -> float:
	var n := int(result.get("count", 0))
	var src: Array = stacks[a]
	var dst: Array = stacks[b]
	var moving: Array = src.slice(src.size() - n)
	# The last candy on top leaves first.
	moving.reverse()
	for k in n:
		src.pop_back()
	var base := dst.size()
	# The source jar flies over the target and tips; candies pour out of it.
	var ja := jars[a]
	var jb := jars[b]
	var pb := jb.home_position + Vector2(0, -jb.total_height())
	# Prefer tipping so the body hangs towards the middle of the screen, but
	# use whichever side keeps the whole jar on screen.
	var prefer := 1.0 if pb.x > area.get_center().x else -1.0
	if absf(pb.x - area.get_center().x) < jb.jar_width * 0.3:
		prefer = 1.0 if ja.home_position.x < pb.x else -1.0
	var gap := jb.jar_width * 0.45
	var best := {}
	for dir_try in [prefer, -prefer]:
		var ang := deg_to_rad(POUR_ANGLE) * float(dir_try)
		var p := pb + Vector2(0, -gap) - ja.mouth_local().rotated(ang)
		var over := _overflow(ja, p, ang)
		if best.is_empty() or over < float(best["over"]) - 0.5:
			best = {"dir": float(dir_try), "angle": ang, "pos": p, "over": over}
	var dir: float = best["dir"]
	var angle: float = best["angle"]
	var pos: Vector2 = best["pos"]
	# Still poking out? Slide it back in a little.
	pos.x -= _shift_into(ja, pos, angle)
	var start := JarVisual.POUR_TRAVEL + JarVisual.POUR_TILT
	ja.pour(pos, angle, POUR_STEP * (n - 1) + DROP_TIME * 0.45)
	for k in n:
		var c: CandyVisual = moving[k]
		c.selected = false
		dst.append(c)
		var last := k == n - 1
		_pour_candy(c, a, b, base + k, start + k * POUR_STEP, dir, 1.0 + 0.09 * (base + k), last and bool(result.get("completed", false)))
	for jar_idx in result.get("revealed", []):
		var lst: Array = stacks[jar_idx]
		if not lst.is_empty():
			var top: CandyVisual = lst[lst.size() - 1]
			_after(0.12, func() -> void:
				if is_instance_valid(top):
					top.reveal()
					AudioManager.play("reveal"))
	var dur := start + POUR_STEP * (n - 1) + DROP_TIME + 0.05
	var unsealed: Array = result.get("unsealed", [])
	if not unsealed.is_empty():
		_after(dur + 0.35, func() -> void:
			for u in unsealed:
				_unseal(int(u)))
		dur += 0.5
	if bool(result.get("completed", false)):
		dur += 0.35
	return dur


## How far (px) a jar placed at `pos` with rotation `angle` sticks out of
## the board area horizontally.
func _overflow(j: JarVisual, pos: Vector2, angle: float) -> float:
	var xs := _corner_xs(j, pos, angle)
	return maxf(0.0, area.position.x - 8.0 - xs.x) + maxf(0.0, xs.y - area.end.x - 8.0)


func _shift_into(j: JarVisual, pos: Vector2, angle: float) -> float:
	var xs := _corner_xs(j, pos, angle)
	if xs.x < area.position.x - 8.0:
		return xs.x - (area.position.x - 8.0)
	if xs.y > area.end.x + 8.0:
		return xs.y - (area.end.x + 8.0)
	return 0.0


## (min x, max x) of the jar's rotated outline.
func _corner_xs(j: JarVisual, pos: Vector2, angle: float) -> Vector2:
	var hw := j.jar_width * 0.5
	var h := j.total_height()
	var lo := INF
	var hi := -INF
	for corner: Vector2 in [Vector2(-hw, 0), Vector2(hw, 0), Vector2(-hw, -h), Vector2(hw, -h)]:
		var x := (pos + corner.rotated(angle)).x
		lo = minf(lo, x)
		hi = maxf(hi, x)
	return Vector2(lo, hi)


## One candy slides out of the tilted source jar's mouth and tumbles into
## its slot in the target, spinning once, then lands with a squash.
func _pour_candy(c: CandyVisual, source: int, target: int, slot: int, delay: float, dir: float, pitch: float, closes: bool) -> void:
	if c.tween:
		c.tween.kill()
	var sj := jars[source]
	var tj := jars[target]
	var st := {"start": Vector2.ZERO, "mouth": Vector2.ZERO, "rot": 0.0}
	var tw := c.create_tween()
	c.tween = tw
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		if c.get_parent() != fly_layer:
			c.reparent(fly_layer, true)
		st["start"] = c.position
		st["rot"] = c.rotation
		st["mouth"] = fly_layer.to_local(sj.to_global(sj.mouth_local() + Vector2(0, sj.jar_width * 0.1))))
	tw.tween_method(func(t: float) -> void:
		var from: Vector2 = st["start"]
		var mouth: Vector2 = st["mouth"]
		var to := fly_layer.to_local(tj.to_global(tj.slot_position(slot)))
		if t < 0.35:
			# Slide along the jar and out of its mouth.
			var k := t / 0.35
			c.position = from.lerp(mouth, k * k)
		else:
			# Fall with gravity, drifting over to the slot.
			var k := (t - 0.35) / 0.65
			var x := lerpf(mouth.x, to.x, 1.0 - pow(1.0 - k, 2.0))
			var y := lerpf(mouth.y, to.y, k * k)
			c.position = Vector2(x, y)
		c.rotation = lerpf(float(st["rot"]), dir * TAU, t), 0.0, 1.0, DROP_TIME)
	tw.tween_callback(func() -> void:
		c.reparent(tj.candies, false)
		c.position = tj.slot_position(slot)
		c.rotation = 0.0
		tj.land_bump()
		AudioManager.play("clack", pitch)
		if closes:
			_sync_jar_state(target, true)
			AudioManager.play("lid_pop")
			HapticsManager.medium())
	tw.tween_property(c, "scale", Vector2(1.18, 0.82), 0.05)
	tw.tween_property(c, "scale", Vector2(0.94, 1.06), 0.06)
	tw.tween_property(c, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fly(c: CandyVisual, target: int, slot: int, delay: float, pitch: float, closes: bool) -> void:
	if c.tween:
		c.tween.kill()
	var tj := jars[target]
	var st := {"start": Vector2.ZERO}
	var tw := c.create_tween()
	c.tween = tw
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		if c.get_parent() != fly_layer:
			c.reparent(fly_layer, true)
		c.rotation = 0.0
		st["start"] = c.position)
	tw.tween_method(func(t: float) -> void:
		var from: Vector2 = st["start"]
		var to := fly_layer.to_local(tj.to_global(tj.slot_position(slot)))
		var peak := minf(from.y, to.y) - 90.0 - absf(to.x - from.x) * 0.18
		var mid := Vector2((from.x + to.x) * 0.5, peak)
		c.position = from.lerp(mid, t).lerp(mid.lerp(to, t), t)
		c.rotation = sin(t * PI) * 0.35 * signf(to.x - from.x), 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		c.reparent(tj.candies, false)
		c.position = tj.slot_position(slot)
		c.rotation = 0.0
		AudioManager.play("clack", pitch)
		if closes:
			_sync_jar_state(target, true)
			AudioManager.play("lid_pop")
			HapticsManager.medium())
	tw.tween_property(c, "scale", Vector2(1.14, 0.86), 0.05)
	tw.tween_property(c, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_lid_closed(j: JarVisual) -> void:
	var top := j.to_global(Vector2(0, -j.total_height()))
	VFXManager.sparkle(fly_layer, top, UIKit.GOLD, 1.4)
	VFXManager.sparkle(fly_layer, top + Vector2(0, j.total_height() * 0.4), j.lid_color.lightened(0.3), 0.8)


func _unseal(i: int) -> void:
	var j := jars[i]
	if bool(board.cloth[i]) and not board.is_cloth_on(i):
		AudioManager.play("cloth")
	if int(board.locks[i]) >= 0 and not board.is_locked(i):
		AudioManager.play("unlock")
		VFXManager.sparkle(fly_layer, j.to_global(Vector2(0, -j.body_height() * 0.45)), Color("d6a53a"), 1.0)
	_sync_jar_state(i, true)
	j.bounce(1.06)


## Undo of a -> b (count candies): they fly back to a. The model has already
## been restored, so everything is re-synced after the flight.
func animate_undo(a: int, b: int, count: int) -> float:
	var src: Array = stacks[b]
	var dst: Array = stacks[a]
	var n := mini(count, src.size())
	var moving: Array = src.slice(src.size() - n)
	moving.reverse()
	for k in n:
		src.pop_back()
	var base := dst.size()
	for k in n:
		var c: CandyVisual = moving[k]
		dst.append(c)
		_fly(c, a, base + k, k * STAGGER, 1.3 - 0.05 * k, false)
	refresh_states(false)
	var dur := FLY_TIME + STAGGER * n + 0.1
	_after(dur, sync_all)
	return dur


# --- Boosters ----------------------------------------------------------------

## Extra jar: the new model jar pops in and the others slide to make room.
func add_jar(i: int) -> void:
	var j := _create_jar(i)
	layout(true)
	_sync_jar_state(i, false)
	j.scale = Vector2(0.2, 0.2)
	var tw := j.create_tween()
	tw.tween_property(j, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(j, "scale", Vector2.ONE, 0.12)
	VFXManager.sparkle(fly_layer, j.home_position + Vector2(0, -j.total_height() * 0.5), UIKit.PAPER, 1.2)


## Shuffle: jars shake, candies swirl to the middle and land in their new
## places. `jar_ids` are the jars whose candies were redistributed.
func animate_shuffle(jar_ids: Array) -> float:
	var pool := {}
	for i in jar_ids:
		jars[i].shake(0.45)
		for c in stacks[i]:
			var t: int = (c as CandyVisual).type
			if not pool.has(t):
				pool[t] = []
			pool[t].append(c)
		stacks[i] = []
	var center := area.get_center()
	var k := 0
	for i in jar_ids:
		var model: Array = board.stacks[i]
		for s in model.size():
			var t := int(model[s])
			var c: CandyVisual
			if pool.has(t) and not (pool[t] as Array).is_empty():
				c = pool[t].pop_back()
			else:
				c = CandyScene.instantiate()
				jars[i].candies.add_child(c)
				c.setup(t, false, wrapper_style, jars[i].candy_diameter())
			c.set_hidden(false)
			c.selected = false
			stacks[i].append(c)
			_swirl(c, i, s, center, k * 0.012)
			k += 1
	# Anything left over (should not happen) is removed.
	for t in pool.keys():
		for c in pool[t]:
			(c as CandyVisual).queue_free()
	return 0.95 + k * 0.012


func _swirl(c: CandyVisual, target: int, slot: int, center: Vector2, delay: float) -> void:
	if c.tween:
		c.tween.kill()
	var tj := jars[target]
	var st := {"start": Vector2.ZERO}
	var ang := randf() * TAU
	var tw := c.create_tween()
	c.tween = tw
	tw.tween_interval(0.3 + delay)
	tw.tween_callback(func() -> void:
		c.reparent(fly_layer, true)
		st["start"] = c.position)
	tw.tween_method(func(t: float) -> void:
		var from: Vector2 = st["start"]
		var to := fly_layer.to_local(tj.to_global(tj.slot_position(slot)))
		var orbit := center + Vector2(cos(ang + t * 5.0), sin(ang + t * 5.0)) * 170.0 * sin(t * PI)
		var p := from.lerp(orbit, minf(1.0, t * 2.0)) if t < 0.5 else orbit.lerp(to, (t - 0.5) * 2.0)
		c.position = p
		c.rotation = t * TAU, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		c.reparent(tj.candies, false)
		c.position = tj.slot_position(slot)
		c.rotation = 0.0
		AudioManager.play("clack", 1.0 + randf() * 0.4, -8.0))


# --- Intro / celebration -----------------------------------------------------

## Jars drop in from above one after another; candies settle with a jiggle.
func _intro() -> void:
	for i in jars.size():
		var j := jars[i]
		var home := j.home_position
		j.position = home + Vector2(0, -1500)
		var tw := j.create_tween()
		tw.tween_interval(0.12 + i * 0.06)
		tw.tween_property(j, "position", home, 0.42).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			for c in stacks[i]:
				var cv := c as CandyVisual
				var jt := cv.create_tween()
				jt.tween_interval(randf() * 0.06)
				jt.tween_property(cv, "rotation", randf_range(-0.2, 0.2), 0.06)
				jt.tween_property(cv, "rotation", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	_busy_until = Time.get_ticks_msec() / 1000.0 + 0.12 + jars.size() * 0.06 + 0.42


func intro_time() -> float:
	return 0.12 + jars.size() * 0.06 + 0.45


## Level complete: every lid pops in sequence.
func celebrate() -> float:
	var order: Array = []
	for i in jars.size():
		if jars[i].done:
			order.append(i)
	for k in order.size():
		var j := jars[order[k]]
		_after(k * 0.09, func() -> void:
			j.bounce(1.12)
			AudioManager.play("pop", 1.0 + 0.05 * k)
			VFXManager.sparkle(fly_layer, j.to_global(Vector2(0, -j.total_height())), UIKit.GOLD, 0.7))
	return order.size() * 0.09 + 0.3


## Hint: pulse two jars.
func pulse_hint(a: int, b: int) -> void:
	if a >= 0 and a < jars.size():
		jars[a].start_pulse()
	if b >= 0 and b < jars.size():
		_after(0.35, func() -> void:
			if b < jars.size():
				jars[b].start_pulse())


## Runs `fn` after `sec` seconds on a tween owned by this node, so it never
## fires after the node is gone (unlike a SceneTree timer).
func _after(sec: float, fn: Callable) -> void:
	var tw := create_tween()
	tw.tween_interval(sec)
	tw.tween_callback(fn)
