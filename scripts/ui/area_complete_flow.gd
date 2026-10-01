class_name AreaCompleteFlow
extends RefCounted
## What happens when the last task of an area is done:
##   confetti -> before/after reveal -> chapter chest -> story cutscene ->
##   page-turn to the next area -> "New area" banner and its arrival story.
## Each step is saved, so a closed app resumes at the right place.


static func run(home: HomePage) -> void:
	var index := RenovationManager.current_area()
	if not RenovationManager.is_area_complete(index) or home.busy:
		return
	home.busy = true
	var state := RenovationManager.area_state(index)
	if bool(state.get("chest_claimed", false)):
		_outro(home, index)
		return
	AudioManager.play("area_complete")
	HapticsManager.heavy()
	VFXManager.confetti(home, home.size.x)
	home.view.focus_on(home.view.scene.focus_point(), home.view.min_zoom, 0.6)
	for ch in home.view.scene.cast.keys():
		home.view.scene.react(ch, "cheer")
	var ba := BeforeAfter.new()
	ba.setup(index)
	ba.closed.connect(func() -> void: _chest(home, index))
	var tw := home.create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(func() -> void: ScreenManager.push_modal(ba))


static func _chest(home: HomePage, index: int) -> void:
	var contents := RenovationManager.claim_area_chest(index)
	if contents.is_empty():
		_outro(home, index)
		return
	ChestPopup.open(UIKit.t("Chapter %d chest") % index, contents, "area_%d" % index, func() -> void: _outro(home, index), "gold")


static func _outro(home: HomePage, index: int) -> void:
	var story := String(RenovationManager.area(index).get("outro_story", ""))
	var key := "outro_%d" % index
	if story != "" and not ProgressionManager.tutorial_done(key):
		ProgressionManager.mark_tutorial(key)
		DialogueManager.play(story, func() -> void: _next(home, index), {"title": UIKit.t("Chapter %d complete!") % index})
	else:
		_next(home, index)


static func _next(home: HomePage, index: int) -> void:
	if not RenovationManager.has_next_area():
		home.busy = false
		home.refresh()
		Popups.show({
			"id": "all_done",
			"title": UIKit.t("Every area restored!"),
			"art": "trophy",
			"art_color": UIKit.GOLD,
			"body": UIKit.t("Chiya Tole has never looked better. New areas are on their way. Keep playing levels for coins, chests and stickers!"),
			"buttons": [{"id": "ok", "text": UIKit.t("Ramro!"), "kind": "primary", "icon": "check"}],
		})
		return
	ScreenManager.page_turn(func() -> void:
		RenovationManager.advance_area()
		home.back_to_current(), func() -> void:
		home.busy = false
		home.refresh()
		_banner(home, index + 1))


static func _banner(home: HomePage, index: int) -> void:
	var vp := home.get_viewport_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 65
	home.add_child(layer)
	var rib := UIKit.ribbon(UIKit.t("New area: %s") % UIKit.t(RenovationManager.area_name(index)), vp.x - 80, UIKit.GOLD, UIKit.GOLD_EDGE, 54)
	rib.position = Vector2(40, vp.y * 0.36)
	layer.add_child(rib)
	UIKit.pop_in(rib)
	AudioManager.play("reward")
	var tw := rib.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(rib, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		layer.queue_free()
		home.on_shown())
