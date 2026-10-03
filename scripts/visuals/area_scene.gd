class_name AreaScene
extends Node2D
## A whole renovation area as a 2D world: backdrop, renovatable objects, the
## cast and ambient life (sun shafts and dust motes inside; clouds, birds and
## people walking past outside). Lighting follows the device time: warm
## mornings, golden evenings, lamp-lit nights.
##
## mode: "live" follows RenovationManager; "before" shows everything broken;
## "after" shows every object restored (style 0 if never chosen).

const CharacterScene := preload("res://scenes/components/character_visual.tscn")

var area_index := 1
var data: Dictionary = {}
var world_size := Vector2(1800, 1500)
var mode := "live"
var night := false
var objects: Dictionary = {}   # object id -> RenoObject
var cast: Dictionary = {}      # character id -> CharacterVisual
var backdrop: AreaBackdrop

var _ambient: Node2D
var _front_fx: Node2D
var _tint: Node2D
var _light: Node2D
var _tint_color := Color.WHITE

## Kinds that glow warmly after dark (only once restored).
const LIGHT_KINDS := {"pendant_lamp": [0.5, 0.85, 260.0], "street_lamp": [0.5, 0.14, 300.0], "lantern": [0.5, 0.55, 200.0], "string_lights": [0.5, 0.6, 160.0], "window": [0.5, 0.45, 220.0]}
var _t := 0.0
var _walkers: Array = []       # [{x, speed, y, color, h, phase}]
var _birds: Array = []         # [{x, y, speed}]
var _clouds: Array = []        # [{x, y, s}]
var _motes: Array = []         # [Vector2]
var _previews: Dictionary = {} # task id -> previewed style index


func build(index: int, mode_value: String = "live") -> void:
	area_index = index
	mode = mode_value
	data = GameData.area(index)
	var ws: Array = data.get("world", [1800, 1500])
	world_size = Vector2(float(ws[0]), float(ws[1]))
	for c in get_children():
		c.queue_free()
	objects.clear()
	cast.clear()
	_previews.clear()
	night = is_night_hour()
	_tint_color = time_tint()

	# Children are added in draw order (no z_index, so the scene never sorts
	# against the UI drawn around it).
	backdrop = AreaBackdrop.new()
	backdrop.setup(String(data.get("backdrop", "interior")), world_size, night)
	add_child(backdrop)

	_ambient = Node2D.new()
	_ambient.draw.connect(_draw_ambient_back)
	add_child(_ambient)
	_setup_ambient()

	var key := String(data.get("id", "area_%d" % index))
	var layered: Array = []   # [layer, order, node]
	for o in data.get("objects", []):
		var node := RenoObject.new()
		node.setup(key, o)
		node.set_night(night)
		objects[String(o["id"])] = node
		layered.append([node.layer, layered.size(), node])
	for c in data.get("cast", []):
		var ch: CharacterVisual = CharacterScene.instantiate()
		ch.id = String(c["id"])
		ch.unit = float(c.get("unit", 0.9))
		cast[ch.id] = ch
		layered.append([int(c.get("z", 0)), layered.size(), ch])
	layered.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	for item in layered:
		add_child(item[2])

	_front_fx = Node2D.new()
	_front_fx.draw.connect(_draw_front_fx)
	add_child(_front_fx)

	# Time-of-day lighting multiplies everything below it.
	_tint = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_tint.material = mat
	_tint.draw.connect(func() -> void: _tint.draw_rect(Rect2(Vector2.ZERO, world_size), _tint_color))
	add_child(_tint)
	# Lamps glow on top of the darkened scene (additive).
	_light = Node2D.new()
	var lmat := CanvasItemMaterial.new()
	lmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light.material = lmat
	_light.draw.connect(_draw_lights)
	add_child(_light)
	refresh()


## Re-applies every object's look and the cast positions.
func refresh() -> void:
	for id in objects:
		_apply_object(id)
	_place_cast()
	var p := RenovationManager.progress(area_index) if mode == "live" else (0.0 if mode == "before" else 1.0)
	backdrop.saturation = lerpf(0.45, 1.0, p)


func _apply_object(id: String) -> void:
	var node: RenoObject = objects[id]
	var info := _object_data(id)
	var t := RenovationManager.task_for_object(area_index, id)
	if t.is_empty():
		node.set_look(info.get("style", {}), false)
		return
	var styles: Array = t.get("styles", [])
	var idx := -1
	match mode:
		"before":
			idx = -1
		"after":
			idx = maxi(0, RenovationManager.task_style(area_index, t["id"]))
		_:
			idx = RenovationManager.task_style(area_index, t["id"])
	if _previews.has(t["id"]):
		idx = int(_previews[t["id"]])
	if idx < 0 or styles.is_empty():
		node.set_look({}, true)
	else:
		node.set_look(styles[clampi(idx, 0, styles.size() - 1)], false)


func _object_data(id: String) -> Dictionary:
	for o in data.get("objects", []):
		if o["id"] == id:
			return o
	return {}


func _place_cast() -> void:
	for c in data.get("cast", []):
		var ch: CharacterVisual = cast.get(String(c["id"]))
		if ch == null:
			continue
		var pos: Array = c.get("pos", [0, 0])
		if c.has("home"):
			var home_done := mode == "after" or (mode == "live" and RenovationManager.object_style(area_index, String(c["home"])) >= 0)
			if not home_done and c.has("away_pos"):
				pos = c["away_pos"]
		ch.position = Vector2(float(pos[0]), float(pos[1]))
		ch.visible = mode != "before" or not c.has("home")


# --- Queries -----------------------------------------------------------------

## Topmost object at a world position (only objects that belong to a task).
func task_object_at(p: Vector2) -> String:
	var best := ""
	var best_z := -9999
	for id in objects:
		var node: RenoObject = objects[id]
		if node.rect().grow(10).has_point(p) and node.layer >= best_z:
			if RenovationManager.task_for_object(area_index, id).is_empty():
				continue
			best = id
			best_z = node.layer
	return best


## Union of a task's objects (world space).
func task_rect(task_id: String) -> Rect2:
	var t := RenovationManager.task(area_index, task_id)
	var r := Rect2()
	var first := true
	for id in t.get("objects", []):
		if objects.has(id):
			var o: RenoObject = objects[id]
			r = o.rect() if first else r.merge(o.rect())
			first = false
	if first:
		return Rect2(world_size * 0.5, Vector2.ONE)
	return r


func focus_point() -> Vector2:
	var f: Array = data.get("focus", [world_size.x * 0.5, world_size.y * 0.5])
	return Vector2(float(f[0]), float(f[1]))


# --- Style preview and restore -----------------------------------------------

func preview_style(task_id: String, style: int) -> void:
	_previews[task_id] = style
	for id in RenovationManager.task(area_index, task_id).get("objects", []):
		if objects.has(id):
			_apply_object(id)


func clear_preview(task_id: String) -> void:
	_previews.erase(task_id)
	for id in RenovationManager.task(area_index, task_id).get("objects", []):
		if objects.has(id):
			_apply_object(id)


## Dust poof, then the objects pop into their new look.
func play_restore(task_id: String, delay: float = 0.0) -> void:
	var t := RenovationManager.task(area_index, task_id)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		for id in t.get("objects", []):
			if not objects.has(id):
				continue
			var o: RenoObject = objects[id]
			VFXManager.dust_poof(self, o.center(), maxf(o.size.x, o.size.y))
			_apply_object(id)
			o.pop()
		_place_cast()
		refresh())


func react(character: String, how: String = "cheer") -> void:
	var ch: CharacterVisual = cast.get(character)
	if ch == null:
		return
	match how:
		"wave":
			ch.wave()
		"worry":
			ch.worry()
		_:
			ch.cheer()


# --- Time of day -------------------------------------------------------------

static func local_hour() -> int:
	if TimeManager.force_hour >= 0:
		return TimeManager.force_hour
	var t := int(TimeManager.now()) + TimeManager.tz_bias()
	return int(Time.get_datetime_dict_from_unix_time(t)["hour"])


static func is_night_hour() -> bool:
	var h := local_hour()
	return h >= 19 or h < 5


static func time_tint() -> Color:
	var h := local_hour()
	if h >= 5 and h < 8:
		return Color(1.0, 0.94, 0.86)
	if h >= 8 and h < 16:
		return Color.WHITE
	if h >= 16 and h < 19:
		return Color(1.0, 0.88, 0.78)
	return Color(0.7, 0.72, 0.92)


func _draw_lights() -> void:
	if not night:
		return
	for id in objects:
		var o: RenoObject = objects[id]
		if o.broken or not LIGHT_KINDS.has(o.kind):
			continue
		if o.kind == "window" and String(data.get("backdrop", "")) == "interior":
			continue
		var spec: Array = LIGHT_KINDS[o.kind]
		var c := o.position + o.size * Vector2(float(spec[0]), float(spec[1]))
		var r := float(spec[2])
		var flicker := 1.0 + 0.04 * sin(_t * 3.0 + c.x)
		for k in 5:
			_light.draw_circle(c, r * flicker * (1.0 - k * 0.17), Color(0.32, 0.2, 0.06, 0.12), true, -1.0, true)


# --- Ambient life ------------------------------------------------------------

func _setup_ambient() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = area_index * 97
	var kind := String(data.get("backdrop", "interior"))
	_walkers.clear()
	_birds.clear()
	_clouds.clear()
	_motes.clear()
	if kind == "interior":
		for k in 26:
			_motes.append(Vector2(rng.randf() * world_size.x, rng.randf() * world_size.y * 0.7))
		return
	for k in 4:
		_clouds.append({"x": rng.randf() * world_size.x, "y": rng.randf_range(0.05, 0.25) * world_size.y, "s": rng.randf_range(0.7, 1.3)})
	for k in 3:
		_birds.append({"x": rng.randf() * world_size.x, "y": rng.randf_range(0.08, 0.3) * world_size.y, "speed": rng.randf_range(60, 110)})
	if kind in ["exterior", "courtyard", "night", "lakeside", "mountain", "rooftop"]:
		var cols := [Color("2f7fc1"), Color("c0392b"), Color("2e8b57"), Color("8e44ad"), Color("e67e22")]
		var skins := [Color("c98b5e"), Color("a86e45"), Color("b97c55")]
		for k in 3:
			_walkers.append({"x": rng.randf() * world_size.x, "speed": rng.randf_range(55, 85) * (1.0 if k % 2 == 0 else -1.0),
				"y": world_size.y * (0.9 + 0.035 * k), "color": cols[(k + area_index) % cols.size()], "skin": skins[k % skins.size()],
				"h": rng.randf_range(250, 290), "phase": rng.randf() * TAU, "bag": rng.randf() < 0.5})


func _process(delta: float) -> void:
	_t += delta
	for c in _clouds:
		# A slow, steady drift; wrap once fully off the right edge.
		c["x"] = float(c["x"]) + delta * 9.0 * float(c["s"])
		if float(c["x"]) > world_size.x + 220:
			c["x"] = -220.0
	for b in _birds:
		b["x"] = float(b["x"]) + delta * float(b["speed"])
		if float(b["x"]) > world_size.x + 200:
			b["x"] = -200.0
	for w in _walkers:
		w["x"] = float(w["x"]) + delta * float(w["speed"])
		if float(w["x"]) > world_size.x + 200:
			w["x"] = -200.0
		elif float(w["x"]) < -200:
			w["x"] = world_size.x + 200
	_ambient.queue_redraw()
	_front_fx.queue_redraw()
	if night:
		_light.queue_redraw()


func _draw_ambient_back() -> void:
	for c in _clouds:
		var p := Vector2(float(c["x"]), float(c["y"]))
		var s := float(c["s"])
		var col := Color(1, 1, 1, 0.85) if not night else Color(0.7, 0.72, 0.9, 0.25)
		for k in 4:
			_ambient.draw_circle(p + Vector2((k - 1.5) * 60 * s, -sin(k * 1.4) * 22 * s), (52 - absf(k - 1.5) * 8) * s, col, true, -1.0, true)
	if not night:
		for b in _birds:
			var p := Vector2(float(b["x"]), float(b["y"]) + sin(_t * 2.0 + float(b["x"]) * 0.01) * 12)
			var flap := sin(_t * 10.0 + float(b["y"])) * 10
			_ambient.draw_polyline(PackedVector2Array([p + Vector2(-18, -flap), p, p + Vector2(18, -flap)]), Color("2b2b3a"), 4.0, true)


## A small cartoon passer-by: swinging arms and legs, a little bob.
func _draw_walker(w: Dictionary) -> void:
	var x := float(w["x"])
	var y := float(w["y"])
	var h := float(w["h"])
	var dir := signf(float(w["speed"]))
	var ph := _t * 6.0 + float(w["phase"])
	var bob := absf(sin(ph)) * 6.0
	var c: Color = w["color"]
	var skin: Color = w["skin"]
	if night:
		c = c.darkened(0.35)
		skin = skin.darkened(0.35)
	var hip := Vector2(x, y - h * 0.42 - bob)
	var step := sin(ph) * h * 0.1
	var trouser := c.darkened(0.45)
	_front_fx.draw_colored_polygon(DrawKit.ellipse(Vector2(x, y), h * 0.16, h * 0.035, 16), Color(0, 0, 0, 0.2))
	DrawKit.capsule(_front_fx, hip, Vector2(x + step, y - h * 0.03), h * 0.045, trouser)
	DrawKit.capsule(_front_fx, hip, Vector2(x - step, y - h * 0.03), h * 0.045, trouser)
	var sh := Vector2(x, y - h * 0.72 - bob)
	var swing := -sin(ph) * h * 0.1
	DrawKit.capsule(_front_fx, sh, sh + Vector2(swing, h * 0.27), h * 0.04, c.darkened(0.15))
	var body := DrawKit.rounded_rect(Rect2(x - h * 0.12, y - h * 0.8 - bob, h * 0.24, h * 0.42), h * 0.08, 6)
	_front_fx.draw_colored_polygon(body, c)
	DrawKit.aa_rim(_front_fx, body, c.darkened(0.4), 2.0)
	if bool(w.get("bag", false)):
		DrawKit.rrect(_front_fx, Rect2(x - dir * h * 0.2 - h * 0.06, y - h * 0.6 - bob, h * 0.13, h * 0.16), 6, Color("e0a458"))
	DrawKit.capsule(_front_fx, sh, sh + Vector2(-swing, h * 0.27), h * 0.04, c.darkened(0.05))
	var head := Vector2(x + dir * h * 0.02, y - h * 0.9 - bob)
	_front_fx.draw_circle(head, h * 0.11, skin, true, -1.0, true)
	var hair := PackedVector2Array()
	for k in 13:
		var a := PI + PI * k / 12.0
		hair.append(head + Vector2(cos(a) * h * 0.115, sin(a) * h * 0.1 - h * 0.01))
	_front_fx.draw_colored_polygon(hair, Color("2b1d16"))
	_front_fx.draw_circle(head + Vector2(dir * h * 0.05, h * 0.0), h * 0.014, Color("2b1d16"), true, -1.0, true)


func _draw_front_fx() -> void:
	# People walking past along the street.
	for w in _walkers:
		_draw_walker(w)
	# Sun shafts and floating dust inside.
	if data.has("sun") and not night:
		var s: Array = data["sun"]
		var o := Vector2(float(s[0]), float(s[1]))
		var a := 0.07 + 0.02 * sin(_t * 0.7)
		for k in 3:
			var x0 := o.x - 120 + k * 110
			_front_fx.draw_colored_polygon(PackedVector2Array([Vector2(x0, o.y - 160), Vector2(x0 + 70, o.y - 160), Vector2(x0 - 420 + 70, world_size.y), Vector2(x0 - 560, world_size.y)]), Color(1.0, 0.92, 0.6, a))
	if not night:
		for i in _motes.size():
			var m: Vector2 = _motes[i]
			var p := m + Vector2(sin(_t * 0.4 + i) * 30, fmod(_t * 8.0 + i * 37.0, 120.0) - 60)
			_front_fx.draw_circle(p, 3.0, Color(1.0, 0.95, 0.8, 0.35), true, -1.0, true)
