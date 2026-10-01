class_name SettingsPanel
extends Control
## Sound and Music (on/off + volume), Haptics, Idle hints, Reset progress, version.

const ROWS := [["sound", "Sound", "sound"], ["music", "Music", "music"], ["haptics", "Haptics", "vibrate"], ["hints", "Idle hints", "bulb"]]

## Toggle id -> volume setting shown as a slider under it.
const VOLUMES := {"sound": "sfx_volume", "music": "music_volume"}

var toggles: Dictionary = {}
var sliders: Dictionary = {}
var _save_timer: Timer
var _last_slider := ""


func _ready() -> void:
	set_meta("popup_id", "settings")
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.35
	_save_timer.timeout.connect(_on_volume_settled)
	add_child(_save_timer)
	var v := UIKit.modal_frame(self, 880, "SETTINGS")
	UIKit.attach_close(self, close)
	for r in ROWS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 22)
		row.add_child(UIKit.disk(r[2], 96, UIKit.SECONDARY, UIKit.SECONDARY_EDGE))
		var l := UIKit.label(r[1], 48, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var t := UIKit.button("", "secondary", "", 42, Vector2(200, 120))
		t.pressed.connect(func() -> void:
			SaveManager.set_setting(r[0], not SaveManager.get_setting(r[0]))
			_refresh())
		row.add_child(t)
		toggles[r[0]] = t
		v.add_child(row)
		if VOLUMES.has(r[0]):
			v.add_child(_volume_row(VOLUMES[r[0]]))
	v.add_child(UIKit.spacer(10))
	var reset := UIKit.button("Reset progress", "danger", "retry", 44)
	reset.pressed.connect(func() -> void:
		Popups.confirm("Reset progress?", "This erases your levels, coins, boosters and cosmetics. Settings are kept.", "Reset", func() -> void:
			SaveManager.reset_progress()
			close()
			VFXManager.toast("Progress reset")
			ScreenManager.go_hub("home"), "danger"))
	v.add_child(reset)
	v.add_child(UIKit.label("Pasal Sort  v%s" % ProjectSettings.get_setting("application/config/version", "0.1"), 34, UIKit.INK_SOFT))
	_refresh()


func _volume_row(key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.add_child(UIKit.hspacer(118))
	var sl := UIKit.slider(SaveManager.get_volume(key))
	row.add_child(sl)
	var pct := UIKit.label("%d%%" % roundi(sl.value * 100.0), 38, UIKit.INK_SOFT)
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
		var on := SaveManager.get_setting(k)
		var t: GameButton = toggles[k]
		t.set_kind("primary" if on else "neutral")
		t.set_label("ON" if on else "OFF")


func close() -> void:
	if not _save_timer.is_stopped():
		_save_timer.stop()
		SaveManager.save_game()
	ScreenManager.close_modal(self)


func on_back() -> void:
	close()
