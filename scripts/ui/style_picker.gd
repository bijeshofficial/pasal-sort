class_name StylePicker
extends Control
## Pick 1 of 3 styles for a renovated object. Tapping a card previews it in
## the scene; "Choose" keeps it. When changing a finished object later there
## is also a "Cancel" that restores the old style.

signal chosen(style: int)
signal cancelled
signal previewed(style: int)

var task: Dictionary = {}
var area_index := 1
var selected := 0
var cancellable := false
var cards: Array[Control] = []
var choose_button: GameButton

var _holder: Control
var _sheet: PanelContainer
var _ribbon: Control


func setup(index: int, task_data: Dictionary, current: int, can_cancel: bool) -> void:
	area_index = index
	task = task_data
	selected = maxi(0, current)
	cancellable = can_cancel


func _ready() -> void:
	set_meta("popup_id", "style_picker")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vp := get_viewport_rect().size
	var shade := Control.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.draw.connect(func() -> void:
		DrawKit.gradient_fill(shade, PackedVector2Array([Vector2(0, vp.y * 0.45), Vector2(vp.x, vp.y * 0.45), Vector2(vp.x, vp.y), Vector2(0, vp.y)]), Color(0.06, 0.03, 0.18, 0.0), Color(0.06, 0.03, 0.18, 0.7)))
	add_child(shade)
	_sheet = UIKit.panel(UIKit.PAPER, 56, 36)
	(_sheet.get_theme_stylebox("panel") as StyleBoxEmpty).content_margin_top = 100
	(_sheet.get_theme_stylebox("panel") as StyleBoxEmpty).content_margin_bottom = 36 + UIKit.safe_bottom()
	_sheet.custom_minimum_size = Vector2(vp.x - 40, 0)
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	_holder.add_child(_sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	_sheet.add_child(v)
	_ribbon = UIKit.ribbon(tr("Choose a style"), 760, UIKit.PINK, UIKit.PINK_EDGE, 56)
	_ribbon.position = Vector2((vp.x - 40 - 760) * 0.5, -70)
	_holder.add_child(_ribbon)
	v.add_child(UIKit.label(tr(String(task.get("name", ""))), 40, UIKit.INK_SOFT))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	v.add_child(row)
	var styles: Array = task.get("styles", [])
	for i in styles.size():
		var card := _card(i, styles[i])
		row.add_child(card)
		cards.append(card)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	v.add_child(buttons)
	if cancellable:
		var cancel := UIKit.button(tr("Cancel"), "neutral", "", 46, Vector2(0, 150))
		cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cancel.pressed.connect(_cancel)
		buttons.add_child(cancel)
	choose_button = UIKit.button(tr("Choose"), "primary", "check", 54, Vector2(0, 150))
	choose_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choose_button.pressed.connect(_choose)
	buttons.add_child(choose_button)
	_select(selected, false)
	_place.call_deferred()


func _place() -> void:
	var vp := get_viewport_rect().size
	_sheet.reset_size()
	var y := vp.y - _sheet.size.y + 30
	_holder.position = Vector2(20, vp.y)
	var tw := _holder.create_tween()
	tw.tween_property(_holder, "position:y", y, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _card(i: int, style: Dictionary) -> Control:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(300, 340)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var obj_id: String = (task.get("objects", [""]) as Array)[0]
	var kind := "box"
	var osize := Vector2(100, 100)
	for o in RenovationManager.area(area_index).get("objects", []):
		if o["id"] == obj_id:
			kind = String(o["kind"])
			osize = Vector2(float(o["rect"][2]), float(o["rect"][3]))
	b.draw.connect(func() -> void:
		var on := i == selected
		var r := Rect2(Vector2(6, 6), b.size - Vector2(12, 12))
		DrawKit.glossy_rrect(b, r, 30, Color("fff3c4") if on else Color.WHITE, UIKit.GOLD_EDGE if on else UIKit.LINE.darkened(0.15), 0.0, 6.0 if on else 4.0, 10.0, true)
		var art := Rect2(r.position + Vector2(20, 20), Vector2(r.size.x - 40, r.size.y - 110))
		var k := minf(art.size.x / osize.x, art.size.y / osize.y)
		var off := art.position + (art.size - osize * k) * 0.5
		RenoArt.draw_object(b, kind, osize, style, false, 0.0, false, Transform2D(0.0, Vector2(k, k), 0.0, off))
		if on:
			b.draw_circle(r.position + Vector2(r.size.x - 20, 24), 30, UIKit.PRIMARY_EDGE, true, -1.0, true)
			b.draw_circle(r.position + Vector2(r.size.x - 20, 22), 26, UIKit.PRIMARY, true, -1.0, true)
			b.draw_polyline(PackedVector2Array([r.position + Vector2(r.size.x - 32, 22), r.position + Vector2(r.size.x - 23, 31), r.position + Vector2(r.size.x - 8, 12)]), Color.WHITE, 6.0, true))
	var l := UIKit.label(tr(String(style.get("name", ""))), 34, UIKit.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(14, 250)
	l.size = Vector2(272, 80)
	b.add_child(l)
	b.pressed.connect(func() -> void:
		AudioManager.play("button_click")
		_select(i, true))
	return b


func _select(i: int, emit: bool) -> void:
	selected = i
	for c in cards:
		c.queue_redraw()
	if cards.size() > i:
		UIKit.bounce(cards[i], 1.06)
	if emit:
		previewed.emit(i)


## Tests and tutorial.
func pick(i: int) -> void:
	_select(i, true)


func _choose() -> void:
	ScreenManager.close_modal(self)
	chosen.emit(selected)


func _cancel() -> void:
	ScreenManager.close_modal(self)
	cancelled.emit()


func on_back() -> void:
	if cancellable:
		_cancel()
	else:
		_choose()
