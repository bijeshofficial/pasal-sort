class_name TaskPanel
extends Control
## The task list: slides up from the Tasks button. Open tasks first (with a
## star-cost button), then tasks waiting on another one, then finished ones.

signal task_chosen(task_id: String)
signal play_pressed

var area_index := 1
var buttons: Dictionary = {}     # task id -> GameButton
var _holder: Control             # slides; holds the sheet, ribbon and close
var _sheet: PanelContainer
var _list: VBoxContainer
var _only := ""                  # tutorial: only this task is enabled


func setup(index: int, only_task: String = "") -> void:
	area_index = index
	_only = only_task


func _ready() -> void:
	set_meta("popup_id", "tasks")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vp := get_viewport_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.03, 0.18, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventScreenTouch and e.pressed and _only == "":
			close())
	add_child(dim)
	var h := minf(vp.y * 0.74, 1460.0)
	_sheet = UIKit.panel(UIKit.PAPER, 60, 40)
	(_sheet.get_theme_stylebox("panel") as StyleBoxEmpty).content_margin_top = 110
	(_sheet.get_theme_stylebox("panel") as StyleBoxEmpty).content_margin_bottom = 40 + UIKit.safe_bottom()
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.position = Vector2(20, vp.y - h + 40)
	_holder.size = Vector2(vp.x - 40, h)
	add_child(_holder)
	_sheet.position = Vector2.ZERO
	_sheet.size = Vector2(vp.x - 40, h)
	_holder.add_child(_sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	_sheet.add_child(v)
	var rib := UIKit.ribbon(tr("Tasks"), 700, UIKit.SECONDARY, UIKit.SECONDARY_EDGE, 60)
	rib.position = Vector2((_sheet.size.x - 700) * 0.5, -70)
	_holder.add_child(rib)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	var name_l := UIKit.label(tr(RenovationManager.area_name(area_index)), 46, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	head.add_child(UIKit.icon("star", 64, UIKit.GOLD))
	head.add_child(UIKit.label(str(CurrencyManager.get_stars()), 50, UIKit.INK))
	v.add_child(head)
	v.add_child(_progress_bar())
	var scroll := WheelScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 16)
	scroll.add_child(_list)
	_build_list()
	if _only == "":
		var x := UIKit.close_button(112)
		x.position = Vector2(_sheet.size.x - 130, -40)
		x.size = Vector2(112, 112)
		x.pressed.connect(close)
		_holder.add_child(x)
	# Slide up.
	_holder.position.y += h
	var tw := _holder.create_tween()
	tw.tween_property(_holder, "position:y", vp.y - h + 40, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _progress_bar() -> Control:
	var done := RenovationManager.done_count(area_index)
	var total := RenovationManager.total_count(area_index)
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 56)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		c.draw_colored_polygon(DrawKit.rounded_rect(r, 28, 8), Color(UIKit.INK, 0.15))
		var k := 0.0 if total == 0 else float(done) / total
		if k > 0.0:
			var fr := Rect2(Vector2(6, 6), Vector2(maxf(44.0, (r.size.x - 12) * k), r.size.y - 12))
			DrawKit.gradient_fill(c, DrawKit.rounded_rect(fr, 22, 8), UIKit.PRIMARY.lightened(0.2), UIKit.PRIMARY))
	var l := UIKit.title("%d / %d" % [done, total], 36)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(l)
	return c


func _build_list() -> void:
	var open: Array = []
	var waiting: Array = []
	var finished: Array = []
	for t in RenovationManager.tasks(area_index):
		var id := String(t["id"])
		if RenovationManager.is_task_done(area_index, id):
			finished.append(t)
		elif RenovationManager.is_task_unlocked(area_index, id):
			open.append(t)
		else:
			waiting.append(t)
	for t in open:
		_list.add_child(_card(t, "open"))
	for t in waiting:
		_list.add_child(_card(t, "waiting"))
	for t in finished:
		_list.add_child(_card(t, "done"))
	if open.is_empty() and waiting.is_empty():
		_list.add_child(UIKit.label(tr("Every task here is done!"), 44, UIKit.INK_SOFT))


func _card(t: Dictionary, state: String) -> Control:
	var id := String(t["id"])
	var card := PanelContainer.new()
	var fill := Color.WHITE if state == "open" else Color("f1eefc")
	card.add_theme_stylebox_override("panel", UIKit.card_box(fill, 20, UIKit.LINE))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	card.add_child(row)
	row.add_child(_thumb(t, state == "done"))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_l := UIKit.label(tr(String(t.get("name", id))), 42, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(name_l)
	var sub := String(t.get("desc", ""))
	if state == "waiting":
		var need: PackedStringArray = []
		for r in t.get("requires", []):
			if not RenovationManager.is_task_done(area_index, String(r)):
				need.append(tr(String(RenovationManager.task(area_index, String(r)).get("name", r))))
		sub = tr("First: %s") % ", ".join(need)
	elif state == "done":
		var st: Array = t.get("styles", [])
		var idx := RenovationManager.task_style(area_index, id)
		sub = tr("Done: %s. Tap it in the scene to change.") % tr(String(st[idx].get("name", ""))) if idx >= 0 and idx < st.size() else tr("Done")
	var desc := UIKit.label(sub, 32, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, false)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(desc)
	row.add_child(text)
	match state:
		"open":
			var cost := int(t.get("cost", 1))
			var b := UIKit.button(str(cost), "gold" if CurrencyManager.get_stars() >= cost else "neutral", "star", 50, Vector2(190, 130))
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.disabled = _only != "" and _only != id
			b.pressed.connect(_on_task_pressed.bind(id))
			row.add_child(b)
			buttons[id] = b
		"waiting":
			var lock := UIKit.icon("lock", 80, UIKit.INK_SOFT)
			lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(lock)
		"done":
			var ok := UIKit.disk("check", 110, UIKit.PRIMARY, UIKit.PRIMARY_EDGE)
			ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(ok)
	return card


## A small drawing of the object (in its chosen style, or the first one).
func _thumb(t: Dictionary, done: bool) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(170, 150)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var obj_id: String = (t.get("objects", [""]) as Array)[0]
	var kind := "box"
	var osize := Vector2(100, 100)
	for o in RenovationManager.area(area_index).get("objects", []):
		if o["id"] == obj_id:
			kind = String(o["kind"])
			osize = Vector2(float(o["rect"][2]), float(o["rect"][3]))
	var styles: Array = t.get("styles", [{}])
	var idx := maxi(0, RenovationManager.task_style(area_index, String(t["id"])))
	var style: Dictionary = styles[mini(idx, styles.size() - 1)] if not styles.is_empty() else {}
	c.draw.connect(func() -> void:
		DrawKit.glossy_rrect(c, Rect2(Vector2.ZERO, c.size), 26, Color("fff3dc") if done else Color("e9f4ff"), UIKit.LINE.darkened(0.1), 0.0, 4.0, 8.0, false)
		var k := minf((c.size.x - 30) / osize.x, (c.size.y - 30) / osize.y)
		var off := (c.size - osize * k) * 0.5
		RenoArt.draw_object(c, kind, osize, style, false, 0.0, false, Transform2D(0.0, Vector2(k, k), 0.0, off)))
	return c


func _on_task_pressed(id: String) -> void:
	if not RenovationManager.can_do(area_index, id):
		var need := RenovationManager.task_cost(area_index, id) - CurrencyManager.get_stars()
		VFXManager.toast(tr("You need %d more star(s). Win a level!") % need)
		UIKit.bounce(buttons[id], 1.1)
		return
	close(false)
	task_chosen.emit(id)


func close(animate: bool = true) -> void:
	if not animate:
		ScreenManager.close_modal(self)
		return
	var tw := _holder.create_tween()
	tw.tween_property(_holder, "position:y", get_viewport_rect().size.y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: ScreenManager.close_modal(self))


func on_back() -> void:
	if _only == "":
		close()
