extends Node
## App lifecycle: Android back button, app pause/resume, quit, safe-area
## insets and play-time tracking.

signal app_paused
signal app_resumed
## Game event bus: missions, events, races and achievements listen here.
## ids: win, hard_win, clean_win, twist_win, jar, candies, booster, task,
## style, stars, chest, challenge, daily_claim, sticker, order, helper.
signal game_event(id: String, amount: int)

## Desktop testing aid: pretend the device has a notch (pass -- --safe-debug).
var debug_safe_insets := Vector2.ZERO

var _play_time_accum := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameData.preload_all()
	apply_accessibility()
	SaveManager.loaded.connect(apply_accessibility)
	SaveManager.setting_changed.connect(_on_setting_changed)
	if "--safe-debug" in OS.get_cmdline_user_args():
		debug_safe_insets = Vector2(110, 70)


func _exit_tree() -> void:
	# Static caches hold fonts and textures; release them so nothing leaks at quit.
	UIKit._fonts.clear()
	DrawKit._textures.clear()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_play_time_accum += delta
	if _play_time_accum >= 1.0:
		var whole := int(_play_time_accum)
		_play_time_accum -= whole
		SaveManager.add_stat("play_time_sec", whole)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			handle_back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			app_paused.emit()
			SaveManager.save_game()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			app_resumed.emit()
		NOTIFICATION_WM_CLOSE_REQUEST:
			quit_game()


func _input(event: InputEvent) -> void:
	# Escape mirrors the Android back button on desktop.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		handle_back()
		get_viewport().set_input_as_handled()


## Back button: close the top modal, otherwise let the current screen decide.
func handle_back() -> void:
	if AdManager.is_showing() or ScreenManager.is_busy():
		return
	if ScreenManager.handle_back_on_modal():
		return
	var scene := get_tree().current_scene
	if scene and scene.has_method("on_back"):
		scene.on_back()


## Saves everything (the current level included) and quits.
func quit_game() -> void:
	app_paused.emit()
	SaveManager.save_game()
	get_tree().quit()


## Language, colour-blind markings and text size from the settings.
func apply_accessibility() -> void:
	if SaveManager.data.is_empty():
		return
	TranslationServer.set_locale(String(SaveManager.setting_value("language", "en")))
	CandyArt.colorblind = bool(SaveManager.setting_value("colorblind", false))
	UIKit.text_scale = clampf(float(SaveManager.setting_value("text_scale", 1.0)), 0.8, 1.3)


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key in ["language", "colorblind", "text_scale"]:
		apply_accessibility()


func emit_event(id: String, amount: int = 1) -> void:
	if amount > 0:
		game_event.emit(id, amount)


## Returns (top, bottom) safe-area insets in viewport (logical) pixels.
func get_safe_insets() -> Vector2:
	if debug_safe_insets != Vector2.ZERO:
		return debug_safe_insets
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.y <= 0 or safe.size.y <= 0:
		return Vector2.ZERO
	var vp := get_viewport().get_visible_rect().size
	var k := vp.y / float(screen.y)
	return Vector2(maxf(0.0, safe.position.y * k), maxf(0.0, (screen.y - safe.end.y) * k))


## Local calendar date "YYYY-MM-DD" (daily gift), from the debug-aware clock.
func today() -> String:
	return TimeManager.today()
