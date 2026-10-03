class_name ChestPopup
extends Control
## Chest opening: the chest shakes, the lid bursts open with light rays and
## the rewards pop out one by one. Rewards are granted the moment it opens,
## so closing early never loses anything.
##   ChestPopup.open("Chapter chest", {coins: 300, boosters: {undo: 2}}, "area_1", on_done)

signal closed

const STYLES := {
	"wood": [Color("b8723a"), Color("6b3d1a"), Color("e3b04b")],
	"gold": [Color("e9a52a"), Color("9a6410"), Color("fff2a8")],
	"trunk": [Color("c2412f"), Color("6e1d16"), Color("f2c14e")],
	"mission": [Color("a35cff"), Color("6a2ad2"), Color("ffd23f")],
}

var title := "Chest"
var bundle: Dictionary = {}
var source := ""
var style := "wood"
var items: Array = []
## Rewards already granted elsewhere (daily calendar): just show them.
var granted_items: Array = []
var collect_button: GameButton

var _chest: Control
var _shake := 0.0
var _lid := 0.0       # 0 closed, 1 open
var _rays := 0.0
var _row: GridContainer
var _on_done: Callable


static func show_granted(title_text: String, granted: Array, on_done: Callable = Callable(), chest_style: String = "gold") -> ChestPopup:
	var p := ChestPopup.new()
	p.title = title_text
	p.granted_items = granted
	p.style = chest_style
	p._on_done = on_done
	ScreenManager.push_modal(p)
	return p


static func open(title_text: String, contents: Dictionary, source_id: String = "", on_done: Callable = Callable(), chest_style: String = "wood") -> ChestPopup:
	var p := ChestPopup.new()
	p.title = title_text
	p.bundle = contents
	p.source = source_id
	p.style = chest_style
	p._on_done = on_done
	ScreenManager.push_modal(p)
	return p


func _ready() -> void:
	set_meta("popup_id", "chest")
	var v := UIKit.modal_frame(self, 900, title)
	_chest = Control.new()
	_chest.custom_minimum_size = Vector2(0, 460)
	_chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chest.draw.connect(_draw_chest)
	v.add_child(_chest)
	# Rewards wrap into rows of four so a big chest still fits the screen.
	_row = GridContainer.new()
	_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_row.add_theme_constant_override("h_separation", 18)
	_row.add_theme_constant_override("v_separation", 14)
	_row.custom_minimum_size = Vector2(0, 190)
	v.add_child(_row)
	collect_button = UIKit.button(tr("Collect"), "primary", "check", 56, Vector2(0, 170))
	collect_button.modulate.a = 0.0
	collect_button.disabled = true
	collect_button.pressed.connect(close)
	v.add_child(collect_button)
	if not granted_items.is_empty():
		items = granted_items
	else:
		items = Rewards.grant(bundle, source)
		ChestManager.note_opened(source)
	items = compact(items)
	_row.columns = clampi(items.size(), 1, 4)
	_animate()


## One tile for all the stickers instead of one per sticker name.
static func compact(list: Array) -> Array:
	var out: Array = []
	var stickers := 0
	for it in list:
		if String(it.get("key", "")) == "sticker":
			stickers += 1
		else:
			out.append(it)
	if stickers > 0:
		out.append({"icon": "sticker", "text": "+%d" % stickers, "color": UIKit.PINK, "key": "sticker"})
	return out


func _animate() -> void:
	var tw := create_tween()
	tw.tween_interval(0.3)
	for k in 3:
		tw.tween_callback(func() -> void:
			AudioManager.play("tick", 0.9 + 0.1 * k)
			HapticsManager.light())
		tw.tween_method(_set_shake, 1.0, 0.0, 0.28)
		tw.tween_interval(0.08)
	tw.tween_callback(func() -> void:
		AudioManager.play("chest_open")
		HapticsManager.heavy()
		VFXManager.shake(10.0, 0.25)
		VFXManager.sparkle(self, _chest.get_global_rect().get_center() - Vector2(0, 40), UIKit.GOLD, 2.5))
	tw.tween_method(_set_lid, 0.0, 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in items.size():
		tw.tween_callback(_pop_item.bind(i))
		tw.tween_interval(0.22)
	tw.tween_callback(func() -> void:
		collect_button.disabled = false
		collect_button.create_tween().tween_property(collect_button, "modulate:a", 1.0, 0.2))


func _set_shake(v: float) -> void:
	_shake = v
	_chest.queue_redraw()


func _set_lid(v: float) -> void:
	_lid = v
	_rays = v
	_chest.queue_redraw()


func _process(_delta: float) -> void:
	if _rays > 0.0:
		_chest.queue_redraw()


func _pop_item(i: int) -> void:
	if i >= items.size():
		return
	var it: Dictionary = items[i]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: Color = it.get("color", UIKit.GOLD)
	box.custom_minimum_size = Vector2(170, 0)
	var d := UIKit.disk(String(it.get("icon", "star")), 116, col, col.darkened(0.35))
	d.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(d)
	var l := UIKit.title(String(it.get("text", "")), 36)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	_row.add_child(box)
	UIKit.pop_in(box)
	AudioManager.play("pop", 1.0 + 0.08 * i)


## A planked treasure chest: domed lid, metal bands with rivets, corner
## caps and a keyhole plate. Opening squashes the lid back and shows its
## dark underside, a warm glow and coins and gems inside.
func _draw_chest() -> void:
	var cols: Array = STYLES.get(style, STYLES["wood"])
	var base: Color = cols[0]
	var dark: Color = cols[1]
	var metal: Color = cols[2]
	var ink := Color("2b1640")
	var c := Vector2(_chest.size.x * 0.5, _chest.size.y * 0.78)
	var t := Time.get_ticks_msec() / 1000.0
	if _rays > 0.0:
		for k in 14:
			var a := t * 0.4 + TAU * k / 14.0
			var pts := PackedVector2Array([c + Vector2(0, -140), c + Vector2(0, -140) + Vector2(cos(a), sin(a)) * 560, c + Vector2(0, -140) + Vector2(cos(a + 0.18), sin(a + 0.18)) * 560])
			_chest.draw_colored_polygon(pts, Color(1.0, 0.88, 0.4, 0.16 * _rays))
	var wob := sin(Time.get_ticks_msec() * 0.06) * 0.08 * _shake
	_chest.draw_set_transform(c, wob, Vector2(1.0 + 0.04 * _shake, 1.0 - 0.04 * _shake))
	var w := 380.0
	var h := 190.0
	var dome := 120.0
	RenoArt.soft_shadow(_chest, Vector2(0, 10), w * 0.62, 26, 0.28)
	# Opened: the lid's underside stands up behind the body.
	if _lid > 0.5:
		var up := (_lid - 0.5) * 2.0
		var lh := 150.0 * up
		var back := PackedVector2Array([Vector2(-w * 0.5, -h), Vector2(w * 0.5, -h), Vector2(w * 0.56, -h - lh), Vector2(-w * 0.56, -h - lh)])
		RenoArt.shape(_chest, back, dark.darkened(0.35), 6.0)
		_chest.draw_rect(Rect2(-w * 0.56 + 8, -h - lh, w * 1.12 - 16, 18 * up), base)
	# Body.
	var body := DrawKit.rounded_rect(Rect2(-w * 0.5, -h, w, h), 18, 4)
	_chest.draw_colored_polygon(body, base)
	DrawKit.gradient_fill(_chest, DrawKit.rounded_rect(Rect2(-w * 0.5, -h * 0.45, w, h * 0.45), 18, 4), Color(dark, 0.0), Color(dark, 0.55))
	for k in [1, 2]:
		var y: float = -h + h * k / 3.0
		_chest.draw_line(Vector2(-w * 0.5 + 6, y), Vector2(w * 0.5 - 6, y), dark, 4.0)
		_chest.draw_line(Vector2(-w * 0.5 + 6, y + 4), Vector2(w * 0.5 - 6, y + 4), Color(1, 1, 1, 0.12), 2.0)
	if _lid > 0.0:
		# Inside glow and the loot peeking over the rim.
		_chest.draw_colored_polygon(DrawKit.ellipse(Vector2(0, -h), w * 0.44, 30, 28), Color(1.0, 0.93, 0.55, minf(1.0, _lid * 1.6)))
		var loot := clampf((_lid - 0.4) * 1.8, 0.0, 1.0)
		for coin in [[-110, 14], [-60, 26], [70, 20], [118, 10], [10, 30]]:
			var p := Vector2(coin[0], -h - coin[1] * loot)
			_chest.draw_circle(p, 22, Color("e8a10f"), true, -1.0, true)
			_chest.draw_circle(p, 17, Color("ffd23f"), true, -1.0, true)
			_chest.draw_arc(p, 22, 0, TAU, 20, ink, 3.0, true)
		for gem in [[-20, 34, Color("ff4f7a")], [40, 30, Color("2fb8ff")]]:
			var g := Vector2(gem[0], -h - gem[1] * loot)
			var gp := PackedVector2Array([g + Vector2(0, -20), g + Vector2(17, -4), g + Vector2(0, 18), g + Vector2(-17, -4)])
			RenoArt.shape(_chest, gp, gem[2], 3.0)
			_chest.draw_colored_polygon(PackedVector2Array([g + Vector2(0, -20), g + Vector2(8, -6), g + Vector2(-6, -6)]), Color(1, 1, 1, 0.55))
		# The body's front rim hides the bottom of the loot.
		_chest.draw_rect(Rect2(-w * 0.5, -h, w, 26), base)
		_chest.draw_line(Vector2(-w * 0.5, -h + 26), Vector2(w * 0.5, -h + 26), dark, 4.0)
	# Bands, corner caps, rivets.
	for x in [-w * 0.3, w * 0.3]:
		var band := Rect2(x - 18, -h, 36, h)
		_chest.draw_rect(band, metal)
		_chest.draw_rect(Rect2(band.position, Vector2(8, h)), Color(1, 1, 1, 0.25))
		_chest.draw_rect(Rect2(band.position + Vector2(28, 0), Vector2(8, h)), metal.darkened(0.25))
		for y in [-h + 22, -h * 0.5, -22]:
			_chest.draw_circle(Vector2(x, y), 5, metal.darkened(0.4), true, -1.0, true)
	for side in [-1.0, 1.0]:
		var cx: float = side * w * 0.5
		var cap := PackedVector2Array([Vector2(cx, -46), Vector2(cx, 0), Vector2(cx - side * 46, 0), Vector2(cx - side * 46, -12), Vector2(cx - side * 12, -12), Vector2(cx - side * 12, -46)])
		_chest.draw_colored_polygon(cap, metal.darkened(0.1))
	DrawKit.outline(_chest, body, ink, 6.0)
	# Closed (or squashing) domed lid.
	if _lid <= 0.5:
		var squash := 1.0 - _lid * 2.0
		var lid := PackedVector2Array()
		for k in 25:
			var a := PI + PI * k / 24.0
			lid.append(Vector2(cos(a) * w * 0.52, -h + sin(a) * dome * squash))
		lid.append(Vector2(w * 0.52, -h + 10))
		lid.append(Vector2(-w * 0.52, -h + 10))
		_chest.draw_colored_polygon(lid, base.lightened(0.08))
		var plank := PackedVector2Array()
		for k in 25:
			var a := PI + PI * k / 24.0
			plank.append(Vector2(cos(a) * w * 0.52 * 0.97, -h + sin(a) * dome * squash * 0.55))
		_chest.draw_polyline(plank, dark, 4.0, true)
		for x in [-w * 0.3, w * 0.3]:
			for part in Geometry2D.intersect_polygons(PackedVector2Array([Vector2(x - 18, -h - dome - 10), Vector2(x + 18, -h - dome - 10), Vector2(x + 18, -h + 10), Vector2(x - 18, -h + 10)]), lid):
				_chest.draw_colored_polygon(part, metal)
		# Shine along the top of the dome.
		var shine := PackedVector2Array()
		for k in range(5, 20):
			var a := PI + PI * k / 24.0
			shine.append(Vector2(cos(a) * w * 0.42, -h + sin(a) * dome * squash * 0.82))
		_chest.draw_polyline(shine, Color(1, 1, 1, 0.3), 6.0, true)
		_chest.draw_rect(Rect2(-w * 0.52, -h - 2, w * 1.04, 16), metal.darkened(0.15))
		DrawKit.outline(_chest, lid, ink, 6.0)
	# Keyhole plate on the front.
	var plate := DrawKit.rounded_rect(Rect2(-36, -h - 22, 72, 84), 14, 4)
	RenoArt.shape(_chest, plate, metal, 4.0)
	_chest.draw_circle(Vector2(0, -h + 10), 10, ink, true, -1.0, true)
	_chest.draw_colored_polygon(PackedVector2Array([Vector2(-6, -h + 12), Vector2(6, -h + 12), Vector2(9, -h + 40), Vector2(-9, -h + 40)]), ink)
	_chest.draw_set_transform(Vector2.ZERO)


func close() -> void:
	ScreenManager.close_modal(self)
	closed.emit()
	if _on_done.is_valid():
		_on_done.call()


func on_back() -> void:
	if not collect_button.disabled:
		close()
