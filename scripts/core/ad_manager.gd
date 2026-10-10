extends Node
## Rewarded ads. On a phone with the AdMob plugin, ads come from Google AdMob
## (consent form first, then the SDK, then a preloaded rewarded ad; the reward
## is given only from the "earned reward" callback). Debug builds without
## AdMob (desktop, tests) show a labelled mock ad. A release build without
## AdMob shows no ad and gives nothing, so a fake ad can never hand out free
## rewards. Gameplay never knows which backend runs, and every request gets
## its own callback so each reward is handled by the code that asked for it.
## IDs live in data/ads.json.

signal ad_started(placement: String)
signal ad_finished(placement: String, rewarded: bool)

## Set > 0 to test failure paths (or launch with -- --ad-fail).
@export var mock_fail_rate: float = 0.0
@export var interstitial_every_n_runs: int = 3
@export var interstitial_min_seconds: float = 120.0
## How long the mock overlay stays up.
@export var mock_duration: float = 1.0
## No interstitial within this many seconds after a rewarded ad.
@export var rewarded_grace_seconds: float = 45.0

var interstitials_shown := 0

var _runs_since_interstitial := 0
var _session_runs := 0
var _last_interstitial_time := -9999.0
var _last_rewarded_time := -9999.0
var _showing := false
## The real backend (AdMobProvider) when available, else null.
var provider: AdProvider = null
var cfg: Dictionary = {}
var _pending: Dictionary = {}   # placement -> Callable(ok: bool)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--ad-fail" in OS.get_cmdline_user_args():
		mock_fail_rate = 1.0
	var inter: Dictionary = GameData.economy().get("interstitial", {})
	interstitial_every_n_runs = int(inter.get("every_n_levels", interstitial_every_n_runs))
	interstitial_min_seconds = float(inter.get("min_seconds", interstitial_min_seconds))
	cfg = GameData.load_json("res://data/ads.json")
	# Only phones can run AdMob. (Its callbacks hold the provider, so a
	# throwaway one on desktop would never be freed.)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var real := AdMobProvider.new()
		if real.available():
			provider = real
			provider.finished.connect(_on_provider_finished)
			provider.initialize.call_deferred()


## Rewarded ad unit for this platform: Google's test unit in debug builds,
## the live unit only in release builds. "" on desktop.
func ad_unit_id(release: bool = not OS.is_debug_build()) -> String:
	var plat := "ios" if OS.has_feature("ios") else ("android" if OS.has_feature("android") else "")
	if plat == "":
		return ""
	return String(cfg.get("ad_units" if release else "test_ad_units", {}).get(plat, ""))


## False in a release build without AdMob: rewarded buttons then report
## "no ad right now" and give nothing.
func ads_available() -> bool:
	return provider != null or OS.is_debug_build()


## Settings shows "Ad privacy options" when this is true (EEA/UK consent).
func privacy_options_required() -> bool:
	return provider != null and provider.privacy_options_required()


func show_privacy_options(on_done: Callable = Callable()) -> void:
	if provider != null:
		provider.show_privacy_options(on_done)
	elif on_done.is_valid():
		on_done.call()


func is_showing() -> bool:
	return _showing


func is_rewarded_ready(_placement: String) -> bool:
	return not _showing and ads_available()


func show_rewarded(placement: String, on_done: Callable) -> void:
	if _showing or not ads_available():
		on_done.call(false)
		return
	if provider != null:
		_showing = true
		_pending[placement] = on_done
		AudioManager.set_ad_mute(true)
		ad_started.emit(placement)
		provider.show_rewarded(placement)
		return
	ad_started.emit(placement)
	await _show_mock_overlay("REWARDED TEST AD\n" + placement.replace("_", " "))
	var ok := randf() >= mock_fail_rate
	_last_rewarded_time = _now()
	ad_finished.emit(placement, ok)
	if get_tree().root.has_node("AnalyticsManager"):
		get_tree().root.get_node("AnalyticsManager").log_event("ad_mock", {"placement": placement, "rewarded": ok})
	on_done.call(ok)


func _on_provider_finished(placement: String, rewarded: bool) -> void:
	_showing = false
	AudioManager.set_ad_mute(false)
	_last_rewarded_time = _now()
	ad_finished.emit(placement, rewarded)
	if get_tree().root.has_node("AnalyticsManager"):
		get_tree().root.get_node("AnalyticsManager").log_event("ad_rewarded", {"placement": placement, "rewarded": rewarded})
	var cb: Callable = _pending.get(placement, Callable())
	_pending.erase(placement)
	if cb.is_valid():
		cb.call(rewarded)


func show_rewarded_revive(on_done: Callable) -> void:
	show_rewarded("revive", on_done)


func show_rewarded_double_reward(on_done: Callable) -> void:
	show_rewarded("double_reward", on_done)


func show_rewarded_bonus(on_done: Callable) -> void:
	show_rewarded("bonus", on_done)


func on_run_finished() -> void:
	_runs_since_interstitial += 1
	_session_runs += 1


## Frequency cap: never on the first run of a session, never right after a
## rewarded ad, at most once every N runs and every X seconds.
func can_show_interstitial() -> bool:
	# The game only uses rewarded ads; interstitials are off in economy.json.
	if not bool(GameData.economy().get("interstitial", {}).get("enabled", false)):
		return false
	if _showing or IAPManager.has_no_ads():
		return false
	if _session_runs <= 1:
		return false
	if _now() - _last_rewarded_time < rewarded_grace_seconds:
		return false
	if _runs_since_interstitial < interstitial_every_n_runs:
		return false
	if _now() - _last_interstitial_time < interstitial_min_seconds:
		return false
	return true


func show_interstitial(on_closed: Callable) -> void:
	_last_interstitial_time = _now()
	_runs_since_interstitial = 0
	interstitials_shown += 1
	ad_started.emit("interstitial")
	await _show_mock_overlay("INTERSTITIAL TEST AD")
	ad_finished.emit("interstitial", false)
	on_closed.call()


func banner_opportunity(_screen_name: String) -> void:
	pass  # hook only


## Test helper: forget session history.
func reset_session_state() -> void:
	_runs_since_interstitial = 0
	_session_runs = 0
	_last_interstitial_time = -9999.0
	_last_rewarded_time = -9999.0
	interstitials_shown = 0


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _show_mock_overlay(text: String) -> void:
	_showing = true
	var was_paused := get_tree().paused
	get_tree().paused = true
	AudioManager.set_ad_mute(true)

	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("1f2530")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)
	var label := UIKit.label(text, 64, Color("f4efe6"))
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(label)
	var counter := UIKit.label("", 120, UIKit.GOLD)
	counter.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	counter.position.y -= 420
	counter.custom_minimum_size = Vector2(300, 160)
	counter.position.x -= 150
	layer.add_child(counter)

	var remaining := mock_duration
	while remaining > 0.0:
		counter.text = str(ceili(remaining))
		var step := minf(remaining, 0.25)
		await get_tree().create_timer(step, true).timeout
		remaining -= step

	layer.queue_free()
	AudioManager.set_ad_mute(false)
	get_tree().paused = was_paused
	_showing = false
