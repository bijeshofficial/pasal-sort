class_name SettingsPanel
extends Control
## Sound and Music (on/off + volume), Haptics, Idle hints, Colour-blind
## markings, Language (English / नेपाली), Text size, Reset progress (double
## confirm), Credits, Privacy policy and the version (5 taps: debug menu).

const ROWS := [["sound", "Sound", "sound"], ["music", "Music", "music"], ["haptics", "Haptics", "vibrate"], ["hints", "Idle hints", "bulb"], ["colorblind", "Colour-blind patterns", "eye"]]

## Toggle id -> volume setting shown as a slider under it.
const VOLUMES := {"sound": "sfx_volume", "music": "music_volume"}
const LANGUAGES := [["en", "English"], ["ne", "नेपाली"]]
const PRIVACY_URL := "https://example.com/pasal-sort/privacy"

var toggles: Dictionary = {}
var sliders: Dictionary = {}
var language_button: GameButton
var text_button: GameButton
var version_label: Label
var _save_timer: Timer
var _last_slider := ""
var _taps := 0
var _tap_time := 0


func _ready() -> void:
	set_meta("popup_id", "settings")
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.35
	_save_timer.timeout.connect(_on_volume_settled)
	add_child(_save_timer)
	var outer := UIKit.modal_frame(self, 900, tr("SETTINGS"))
	UIKit.attach_close(self, close)
	var scroll := WheelScroll.new()
	scroll.custom_minimum_size = Vector2(0, minf(get_viewport_rect().size.y * 0.66, 1300))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	outer.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 18)
	scroll.add_child(v)
	for r in ROWS:
		var t := UIKit.button("", "secondary", "", 40, Vector2(190, 108))
		t.pressed.connect(func() -> void:
			SaveManager.set_setting(r[0], not _on(r[0]))
			_refresh())
		v.add_child(_row(r[2], r[1], t))
		toggles[r[0]] = t
		if VOLUMES.has(r[0]):
			v.add_child(_volume_row(VOLUMES[r[0]]))
	language_button = UIKit.button("", "purple", "", 38, Vector2(240, 108))
	language_button.pressed.connect(_next_language)
	v.add_child(_row("map", "Language", language_button))
	text_button = UIKit.button("", "purple", "", 38, Vector2(240, 108))
	text_button.pressed.connect(_next_text_size)
	v.add_child(_row("pencil", "Text size", text_button))
	var links := HBoxContainer.new()
	links.add_theme_constant_override("separation", 16)
	var credits := UIKit.button(tr("Credits"), "neutral", "star", 36, Vector2(0, 110))
	credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits.pressed.connect(_credits)
	links.add_child(credits)
	var privacy := UIKit.button(tr("Privacy"), "neutral", "lock", 36, Vector2(0, 110))
	privacy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	privacy.pressed.connect(_privacy)
	links.add_child(privacy)
	v.add_child(links)
	var reset := UIKit.button(tr("Reset progress"), "danger", "retry", 40, Vector2(0, 120))
	reset.pressed.connect(_reset)
	v.add_child(reset)
	version_label = UIKit.label("Pasal Sort  v%s" % ProjectSettings.get_setting("application/config/version", "0.1"), 32, UIKit.INK_SOFT)
	version_label.mouse_filter = Control.MOUSE_FILTER_STOP
	version_label.gui_input.connect(_on_version_input)
	v.add_child(version_label)
	_refresh()


func _row(icon: String, text: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.add_child(UIKit.disk(icon, 88, UIKit.SECONDARY, UIKit.SECONDARY_EDGE))
	var l := UIKit.label(tr(text), 42, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	return row


func _on(key: String) -> bool:
	return bool(SaveManager.setting_value(key, key != "colorblind"))


func _volume_row(key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.add_child(UIKit.hspacer(108))
	var sl := UIKit.slider(SaveManager.get_volume(key))
	row.add_child(sl)
	var pct := UIKit.label("%d%%" % roundi(sl.value * 100.0), 36, UIKit.INK_SOFT)
	pct.custom_minimum_size = Vector2(120, 0)
	row.add_child(pct)
	sl.value_changed.connect(func(val: float) -> void:
		SaveManager.data["settings"][key] = snappedf(val, 0.01)
		AudioManager.apply_volumes()
		pct.text = "%d%%" % roundi(val * 100.0)
		_last_slider = key
		_save_timer.start())
	sliders[key] = sl
	return row


## Saves shortly after the slider stops moving, with a preview sound.
func _on_volume_settled() -> void:
	SaveManager.save_game()
	if _last_slider == "sfx_volume":
		AudioManager.play("pop")


func _refresh() -> void:
	for k in toggles.keys():
		var on := _on(k)
		var t: GameButton = toggles[k]
		t.set_kind("primary" if on else "neutral")
		t.set_label(tr("ON") if on else tr("OFF"))
	var lang := String(SaveManager.setting_value("language", "en"))
	for l in LANGUAGES:
		if l[0] == lang:
			language_button.set_label(l[1])
	text_button.set_label(tr("Large") if float(SaveManager.setting_value("text_scale", 1.0)) > 1.05 else tr("Normal"))


## Switching language or text size rebuilds the screen.
func _next_language() -> void:
	var lang := String(SaveManager.setting_value("language", "en"))
	var idx := 0
	for i in LANGUAGES.size():
		if LANGUAGES[i][0] == lang:
			idx = i
	SaveManager.set_setting("language", LANGUAGES[(idx + 1) % LANGUAGES.size()][0])
	_rebuild_screen()


func _next_text_size() -> void:
	var big := float(SaveManager.setting_value("text_scale", 1.0)) > 1.05
	SaveManager.set_setting("text_scale", 1.0 if big else 1.15)
	_rebuild_screen()


func _rebuild_screen() -> void:
	close()
	var path := ScreenManager.current_path if ScreenManager.current_path != "" else ScreenManager.HUB
	if path == ScreenManager.GAMEPLAY:
		get_tree().paused = false
	ScreenManager.change_screen(path)


func _reset() -> void:
	Popups.confirm(tr("Reset progress?"), tr("This erases your levels, coins, stars, renovations and stickers. Settings are kept."), tr("Reset"), func() -> void:
		Popups.confirm(tr("Are you sure?"), tr("This can't be undone."), tr("Erase everything"), func() -> void:
			SaveManager.reset_progress()
			close()
			VFXManager.toast(tr("Progress reset"))
			ScreenManager.go_hub("home"), "danger"), "danger")


func _credits() -> void:
	Popups.show({"id": "credits", "title": tr("Credits"), "art": "star", "art_color": UIKit.GOLD,
		"body": tr("Pasal Sort: Sort & Renovate\nMade with Godot Engine\nFonts: Lilita One and Baloo 2 (SIL Open Font License)\nAll art and sounds are made in code.\nThank you for playing!"),
		"buttons": [{"id": "ok", "text": tr("OK"), "kind": "primary"}]})


func _privacy() -> void:
	Popups.show({"id": "privacy", "title": tr("Privacy"), "art": "lock", "art_color": UIKit.SECONDARY,
		"body": tr("Pasal Sort keeps your progress on this device only. No account, no personal data.") + "\n" + PRIVACY_URL,
		"buttons": [{"id": "open", "text": tr("Open link"), "kind": "secondary", "cb": func() -> void: OS.shell_open(PRIVACY_URL)}, {"id": "ok", "text": tr("OK"), "kind": "primary"}]})


## 5 quick taps on the version opens the debug menu (debug builds only).
func _on_version_input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch and event.pressed):
		return
	var now := Time.get_ticks_msec()
	_taps = _taps + 1 if now - _tap_time < 600 else 1
	_tap_time = now
	if _taps >= 5 and OS.is_debug_build():
		_taps = 0
		DebugMenu.open()


func close() -> void:
	if not _save_timer.is_stopped():
		_save_timer.stop()
		SaveManager.save_game()
	ScreenManager.close_modal(self)


func on_back() -> void:
	close()
