class_name ChestPopup
extends Control
## Chest opening: the chest shakes, the lid bursts open with light rays and
## the rewards pop out one by one. Rewards are granted the moment it opens,
## so closing early never loses anything.
##   ChestPopup.open("Chapter chest", {coins: 300, boosters: {undo: 2}}, "area_1", on_done)

signal closed

const STYLES := {
	"wood": [Color("a8672f"), Color("6b3d1a"), Color("d6a53a")],
	"gold": [Color("f2b632"), Color("b07c14"), Color("fff2a8")],
	"trunk": [Color("2f6f8f"), Color("17405a"), Color("f2b632")],
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


func _draw_chest() -> void:
	var cols: Array = STYLES.get(style, STYLES["wood"])
	var base: Color = cols[0]
	var dark: Color = cols[1]
	var metal: Color = cols[2]
	var c := Vector2(_chest.size.x * 0.5, _chest.size.y * 0.72)
	var t := Time.get_ticks_msec() / 1000.0
	if _rays > 0.0:
		for k in 14:
			var a := t * 0.4 + TAU * k / 14.0
			var pts := PackedVector2Array([c + Vector2(0, -60), c + Vector2(cos(a), sin(a)) * 520, c + Vector2(cos(a + 0.18), sin(a + 0.18)) * 520])
			_chest.draw_colored_polygon(pts, Color(1.0, 0.88, 0.4, 0.18 * _rays))
	var wob := sin(Time.get_ticks_msec() * 0.06) * 0.08 * _shake
	_chest.draw_set_transform(c, wob, Vector2(1.0 + 0.04 * _shake, 1.0 - 0.04 * _shake))
	var w := 360.0
	var h := 200.0
	_chest.draw_colored_polygon(DrawKit.ellipse(Vector2(0, 8), w * 0.6, 26, 28), Color(0, 0, 0, 0.25))
	var body := Rect2(-w * 0.5, -h, w, h)
	DrawKit.glossy_rrect(_chest, body, 22, base, dark, 0.0, 7.0, 12.0, false)
	for x in [-w * 0.32, w * 0.32 - 30]:
		_chest.draw_rect(Rect2(x, -h + 6, 30, h - 12), metal)
	if _lid > 0.0:
		# Glow inside.
		_chest.draw_colored_polygon(DrawKit.ellipse(Vector2(0, -h), w * 0.42, 40, 24), Color(1.0, 0.95, 0.6, 0.95))
	# Lid: rotates back when opening.
	_chest.draw_set_transform(c + Vector2(0, -h).rotated(wob) + Vector2(0, -_lid * 60), wob - _lid * 0.5, Vector2.ONE)
	var lid := PackedVector2Array()
	for k in 17:
		var a := PI + PI * k / 16.0
		lid.append(Vector2(cos(a) * w * 0.52, sin(a) * 110))
	_chest.draw_colored_polygon(lid, dark.darkened(0.3))
	var inner := PackedVector2Array()
	for p in lid:
		inner.append(p * 0.94)
	DrawKit.gradient_fill(_chest, inner, base.lightened(0.25), base)
	_chest.draw_rect(Rect2(-w * 0.52, -12, w * 1.04, 22), metal)
	DrawKit.rrect(_chest, Rect2(-34, -40, 68, 66), 12, metal.darkened(0.1))
	_chest.draw_circle(Vector2(0, -8), 10, dark, true, -1.0, true)
	_chest.draw_set_transform(Vector2.ZERO)


func close() -> void:
	ScreenManager.close_modal(self)
	closed.emit()
	if _on_done.is_valid():
		_on_done.call()


func on_back() -> void:
	if not collect_button.disabled:
		close()
