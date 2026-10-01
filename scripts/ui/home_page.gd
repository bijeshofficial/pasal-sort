class_name HomePage
extends Control
## Home = the current renovation area. The scene itself (HomeView) is owned
## by the Hub and fills the whole screen behind the top bar; this page holds
## the overlay: area title + progress, feature icons in two slim side
## columns, the Tasks button (badge = tasks you can afford) and PLAY.
##
## Doing a task: stars fly from the counter to the object -> dust poof ->
## style picker -> the object pops in -> a short dialogue -> coins.

signal feature_pressed(id: String)

const HintScript := preload("res://scripts/ui/hint_hand.gd")

var view: HomeView
var hub: Control
var play_button: GameButton
var tasks_button: GameButton
var tasks_badge: PanelContainer
var left_col: VBoxContainer
var right_col: VBoxContainer
var title_pill: PanelContainer
var visiting := -1           # area shown in visit mode (-1 = current area)
var busy := false            # a renovation sequence is running
var features: Dictionary = {}  # id -> FeatureButton

var _badge_holder: CenterContainer
var _title_label: Label
var _progress: Control
var _back_button: GameButton
var _hint: Control
var _bottom: HBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Area title and progress.
	title_pill = PanelContainer.new()
	var sb := UIKit.chip_box(10)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	title_pill.add_theme_stylebox_override("panel", sb)
	title_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	title_pill.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventScreenTouch and not e.pressed:
			open_gallery())
	add_child(title_pill)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_pill.add_child(tv)
	_title_label = UIKit.title("", 44)
	tv.add_child(_title_label)
	_progress = Control.new()
	_progress.custom_minimum_size = Vector2(420, 30)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.draw.connect(_draw_progress)
	tv.add_child(_progress)
	# Feature columns.
	left_col = VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 22)
	add_child(left_col)
	right_col = VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 22)
	add_child(right_col)
	add_feature("areas", "map", "left", tr("Areas"), UIKit.SECONDARY)
	add_feature("gift", "gift", "right", tr("Gift"), UIKit.PINK)
	# Bottom row: Tasks + PLAY.
	_bottom = HBoxContainer.new()
	_bottom.add_theme_constant_override("separation", 24)
	add_child(_bottom)
	tasks_button = UIKit.button(tr("Tasks"), "gold", "tasks", 40, Vector2(250, 200))
	tasks_button.pressed.connect(func() -> void: open_tasks())
	_bottom.add_child(tasks_button)
	tasks_badge = UIKit.badge("0", UIKit.HEART, 40)
	tasks_badge.position = Vector2(180, -26)
	tasks_badge.z_index = 3
	tasks_button.add_child(tasks_badge)
	var play_col := VBoxContainer.new()
	play_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_col.add_theme_constant_override("separation", 0)
	play_col.alignment = BoxContainer.ALIGNMENT_END
	_bottom.add_child(play_col)
	_badge_holder = CenterContainer.new()
	_badge_holder.custom_minimum_size = Vector2(0, 54)
	play_col.add_child(_badge_holder)
	play_button = UIKit.button("Level 1", "primary", "play", 76, Vector2(0, 200))
	play_button.pressed.connect(_on_play)
	play_col.add_child(play_button)
	UIKit.pulse(play_button, 1.035, 1.4)
	_back_button = UIKit.button(tr("Back to my shop"), "secondary", "back", 44, Vector2(0, 150))
	_back_button.visible = false
	_back_button.pressed.connect(back_to_current)
	add_child(_back_button)
	resized.connect(_layout)
	RenovationManager.task_completed.connect(_on_reno_changed)
	RenovationManager.style_changed.connect(_on_reno_changed)
	CurrencyManager.stars_changed.connect(_on_stars_changed)
	_layout()


func attach_view(home_view: HomeView, hub_node: Control) -> void:
	view = home_view
	hub = hub_node
	view.object_tapped.connect(_on_object_tapped)
	view.show_area(RenovationManager.current_area())
	refresh()


func _layout() -> void:
	var w := size.x
	var h := size.y
	title_pill.reset_size()
	title_pill.position = Vector2((w - title_pill.size.x) * 0.5, 14)
	left_col.position = Vector2(26, 170)
	right_col.reset_size()
	right_col.position = Vector2(w - right_col.size.x - 26, 170)
	_bottom.position = Vector2(40, h - 270)
	_bottom.size = Vector2(w - 80, 254)
	_back_button.position = Vector2(140, h - 200)
	_back_button.size = Vector2(w - 280, 150)
	if view:
		var top := global_position.y + 120
		var bottom := view.size.y - (global_position.y + h - 250)
		if not is_equal_approx(top, view.safe_top) or not is_equal_approx(bottom, view.safe_bottom):
			view.safe_top = top
			view.safe_bottom = bottom
			view._fit()
			view.center_on(view.scene.focus_point(), view.min_zoom)


func add_feature(id: String, icon: String, side: String, label: String, color: Color) -> FeatureButton:
	var f := FeatureButton.new()
	f.setup(id, icon, label, color)
	f.pressed.connect(func() -> void: _on_feature(id))
	(left_col if side == "left" else right_col).add_child(f)
	features[id] = f
	return f


func _on_feature(id: String) -> void:
	match id:
		"areas":
			open_gallery()
		"gift":
			if hub:
				hub.select_tab(0)
	feature_pressed.emit(id)


func refresh() -> void:
	var level := ProgressionManager.current_level()
	play_button.set_label(tr("Level %d") % level)
	for ch in _badge_holder.get_children():
		ch.queue_free()
	var badge := UIKit.tier_badge(ProgressionManager.tier_for(level), 34)
	if badge:
		_badge_holder.add_child(badge)
	var n := RenovationManager.affordable_count()
	tasks_badge.visible = n > 0 and visiting < 0
	(tasks_badge.get_child(0) as Label).text = str(n)
	if n > 0 and visiting < 0:
		if not tasks_button.has_meta("pulsing"):
			tasks_button.set_meta("pulsing", UIKit.pulse(tasks_button, 1.06, 1.0))
	elif tasks_button.has_meta("pulsing"):
		(tasks_button.get_meta("pulsing") as Tween).kill()
		tasks_button.remove_meta("pulsing")
		tasks_button.scale = Vector2.ONE
	var idx := visiting if visiting > 0 else RenovationManager.current_area()
	_title_label.text = tr(RenovationManager.area_name(idx))
	_progress.queue_redraw()
	if features.has("gift"):
		features["gift"].set_dot(ShopPage.daily_available())
		features["gift"].visible = ShopPage.daily_available()
	_layout.call_deferred()


func _draw_progress() -> void:
	var idx := visiting if visiting > 0 else RenovationManager.current_area()
	var k := RenovationManager.progress(idx)
	var r := Rect2(Vector2.ZERO, _progress.size)
	_progress.draw_colored_polygon(DrawKit.rounded_rect(r, 15, 6), Color(0, 0, 0, 0.35))
	if k > 0.0:
		DrawKit.gradient_fill(_progress, DrawKit.rounded_rect(Rect2(Vector2(4, 4), Vector2(maxf(22.0, (r.size.x - 8) * k), r.size.y - 8)), 11, 6), Color("ffe680"), Color("ff9f1a"))
	var f := UIKit.font(true)
	var txt := "%d / %d" % [RenovationManager.done_count(idx), RenovationManager.total_count(idx)]
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	_progress.draw_string_outline(f, Vector2((r.size.x - tw) * 0.5, 23), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, UIKit.OUTLINE)
	_progress.draw_string(f, Vector2((r.size.x - tw) * 0.5, 23), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)


func _on_reno_changed(_a: int, _t: String, _s: int) -> void:
	refresh()


func _on_stars_changed(_total: int, _delta: int) -> void:
	refresh()


func _on_play() -> void:
	if busy:
		return
	var level := ProgressionManager.current_level()
	if not LivesManager.can_play(level):
		Popups.lives(true)
		return
	ScreenManager.start_level()


# --- Tasks -------------------------------------------------------------------

func open_tasks(only: String = "") -> TaskPanel:
	if busy or visiting > 0:
		return null
	var p := TaskPanel.new()
	p.setup(RenovationManager.current_area(), only)
	p.task_chosen.connect(do_task)
	ScreenManager.push_modal(p)
	return p


## The whole renovation sequence for one task.
func do_task(task_id: String) -> void:
	var index := RenovationManager.current_area()
	if busy or not RenovationManager.can_do(index, task_id):
		return
	busy = true
	view.interactive = false
	var rect := view.scene.task_rect(task_id)
	view.focus_on(rect.get_center(), view.zoom_for(rect), 0.45)
	var t := RenovationManager.task(index, task_id)
	var cost := int(t.get("cost", 1))
	# Spend now (style 0), so a closed app never loses the stars or the task.
	var result := RenovationManager.complete_task(task_id, 0)
	if not result.get("ok", false):
		busy = false
		view.interactive = true
		return
	view.scene.preview_style(task_id, -1)
	var from := Vector2(size.x * 0.5, 80)
	if hub and hub.get("star_chip"):
		from = hub.star_chip.icon_global_center()
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_callback(func() -> void:
		VFXManager.star_fly(from, view.world_to_global(rect.get_center()), cost))
	tw.tween_interval(0.75 + 0.05 * cost)
	tw.tween_callback(func() -> void:
		AudioManager.play("renovate")
		HapticsManager.medium()
		view.scene.clear_preview(task_id)
		view.scene.preview_style(task_id, 0)
		view.scene.play_restore(task_id)
		view.scene.react("maya", "cheer"))
	tw.tween_interval(0.7)
	tw.tween_callback(_pick_style.bind(task_id, result))


func _pick_style(task_id: String, result: Dictionary) -> void:
	var index := RenovationManager.current_area()
	var t := RenovationManager.task(index, task_id)
	var picker := StylePicker.new()
	picker.setup(index, t, 0, false)
	picker.previewed.connect(func(i: int) -> void:
		view.scene.preview_style(task_id, i)
		_pop_task(t)
		AudioManager.play("pop"))
	picker.chosen.connect(func(i: int) -> void:
		RenovationManager.set_style(index, task_id, i, false)
		view.scene.clear_preview(task_id)
		for id in t.get("objects", []):
			if view.scene.objects.has(id):
				var o: RenoObject = view.scene.objects[id]
				VFXManager.sparkle(view.scene, o.center(), UIKit.GOLD, 2.0)
		_pop_task(t)
		AudioManager.play("success")
		_after_task.call_deferred(task_id, result))
	ScreenManager.push_modal(picker)
	if _hint:
		_hint.call("point_at", picker.choose_button, tr("Pick the one you like!"))


func _pop_task(t: Dictionary) -> void:
	for id in t.get("objects", []):
		if view.scene.objects.has(id):
			(view.scene.objects[id] as RenoObject).pop()


func _after_task(task_id: String, result: Dictionary) -> void:
	var index := RenovationManager.current_area()
	var prefix := String(RenovationManager.area(index).get("story_prefix", "a%d" % index))
	var story_id := String(RenovationManager.task(index, task_id).get("story", "%s.%s" % [prefix, task_id]))
	_clear_hint()
	DialogueManager.play(story_id, _finish_task.bind(task_id, result))


func _finish_task(task_id: String, result: Dictionary) -> void:
	var coins := int(result.get("coins", 0))
	if coins > 0 and hub and hub.get("coin_chip"):
		var rect := view.scene.task_rect(task_id)
		VFXManager.coin_fly(view.world_to_global(rect.get_center()), hub.coin_chip.icon_global_center(), clampi(coins / 2, 4, 8))
		VFXManager.toast(tr("+%d coins") % coins)
	if not ProgressionManager.tutorial_done("first_task"):
		ProgressionManager.mark_tutorial("first_task")
	busy = false
	view.interactive = true
	refresh()
	if bool(result.get("area_complete", false)):
		_after(0.6, func() -> void: AreaCompleteFlow.run(self))
	else:
		view.focus_on(view.scene.focus_point(), view.min_zoom, 0.6)


# --- Tapping objects: change style for free ---------------------------------

func _on_object_tapped(object_id: String) -> void:
	if busy or ScreenManager.has_modal():
		return
	var index := visiting if visiting > 0 else RenovationManager.current_area()
	var t := RenovationManager.task_for_object(index, object_id)
	if t.is_empty():
		return
	var task_id := String(t["id"])
	var node: RenoObject = view.scene.objects.get(object_id)
	if node:
		node.wiggle()
	if not RenovationManager.is_task_done(index, task_id):
		if visiting > 0:
			return
		VFXManager.toast(tr("%s: %d star(s)") % [tr(String(t.get("name", ""))), int(t.get("cost", 1))])
		open_tasks()
		return
	var old := RenovationManager.task_style(index, task_id)
	var rect := view.scene.task_rect(task_id)
	view.focus_on(rect.get_center(), view.zoom_for(rect), 0.4)
	var picker := StylePicker.new()
	picker.setup(index, t, old, true)
	picker.previewed.connect(func(i: int) -> void:
		view.scene.preview_style(task_id, i)
		_pop_task(t))
	picker.chosen.connect(func(i: int) -> void:
		RenovationManager.set_style(index, task_id, i)
		view.scene.clear_preview(task_id)
		AudioManager.play("success"))
	picker.cancelled.connect(func() -> void:
		view.scene.clear_preview(task_id)
		_pop_task(t))
	ScreenManager.push_modal(picker)


# --- Areas gallery / visiting ------------------------------------------------

func open_gallery() -> void:
	if busy:
		return
	AreasGallery.open(self)


func visit_area(index: int) -> void:
	if index == RenovationManager.current_area():
		back_to_current()
		return
	visiting = index
	view.show_area(index, "live")
	_bottom.visible = false
	_back_button.visible = true
	refresh()


func back_to_current() -> void:
	visiting = -1
	view.show_area(RenovationManager.current_area())
	_bottom.visible = true
	_back_button.visible = false
	refresh()


# --- Things that should happen when Home opens -------------------------------

## Called by the Hub when Home is shown: finishes an interrupted area
## completion, plays the area's arrival story once, and runs the first-task
## tutorial after level 3.
func on_shown() -> void:
	refresh()
	if busy or ScreenManager.has_modal():
		return
	var index := RenovationManager.current_area()
	if RenovationManager.is_area_complete(index):
		_after(0.4, func() -> void: AreaCompleteFlow.run(self))
		return
	var seen_key := "arrive_%d" % index
	var arrive := String(RenovationManager.area(index).get("intro_story", ""))
	if index > 1 and arrive != "" and not ProgressionManager.tutorial_done(seen_key):
		ProgressionManager.mark_tutorial(seen_key)
		_after(0.5, func() -> void: DialogueManager.play(arrive))
		return
	if wants_first_task_tutorial():
		_after(0.5, start_first_task_tutorial)


func wants_first_task_tutorial() -> bool:
	return not ProgressionManager.tutorial_done("first_task") and ProgressionManager.highest_completed() >= 3 \
		and RenovationManager.current_area() == 1 and RenovationManager.can_do(1, "clean_counter")


func start_first_task_tutorial() -> void:
	if not wants_first_task_tutorial() or ScreenManager.has_modal():
		return
	_clear_hint()
	var layer := CanvasLayer.new()
	layer.layer = 70
	add_child(layer)
	_hint = HintScript.new()
	layer.add_child(_hint)
	_hint.call("point_at", tasks_button, tr("Use your star to clean the counter"))
	tasks_button.pressed.connect(_tutorial_open_panel, CONNECT_ONE_SHOT)


func _tutorial_open_panel() -> void:
	# The normal panel opened first; swap it for one limited to the tutorial task.
	var p := ScreenManager.find_modal("tasks")
	if p:
		ScreenManager.close_modal(p)
	var only := open_tasks("clean_counter")
	if only:
		var tw := create_tween()
		tw.tween_interval(0.4)
		tw.tween_callback(func() -> void:
			if is_instance_valid(only) and only.buttons.has("clean_counter") and _hint:
				_hint.call("point_at", only.buttons["clean_counter"], tr("Tap to spend 1 star")))


func _clear_hint() -> void:
	if _hint and is_instance_valid(_hint):
		_hint.get_parent().queue_free()
	_hint = null


func is_tutorial_active() -> bool:
	return _hint != null and is_instance_valid(_hint)


func _after(sec: float, fn: Callable) -> void:
	var tw := create_tween()
	tw.tween_interval(sec)
	tw.tween_callback(fn)
