class_name AdMobProvider
extends AdProvider
## Google AdMob rewarded ads + Google UMP consent through the Poing Studios plugin v5.1 (addons/admob).
## The AdMob app id is a project setting (admob/general/android/app_id), written into the Android manifest by the
## plugin's exporter. On desktop the plugin runs a mock, so available() is true only on Android/iOS builds.
##
## Flow: initialize() -> consent info update -> consent form if REQUIRED -> MobileAds.initialize -> preload.
## show_rewarded() shows the preloaded ad; finished(placement, true) is emitted ONLY from the
## "user earned reward" listener. A new ad is preloaded after every show.

const NATIVE_SINGLETON := "PoingGodotAdMob"

var _ad: RewardedAd = null
var _loading := false
var _placement := ""
var _rewarded := false
var _ready_sdk := false   ## true only after the SDK's initialisation-complete callback
var _starting := false
var _load_cb := RewardedAdLoadCallback.new()
var _content_cb := FullScreenContentCallback.new()
var _earn := OnUserEarnedRewardListener.new()


func _init() -> void:
	_load_cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_loading = false
		ad.full_screen_content_callback = _content_cb
		_ad = ad
	_load_cb.on_ad_failed_to_load = func(_err: LoadAdError) -> void:
		_loading = false
	_content_cb.on_ad_dismissed_full_screen_content = func() -> void: _closed()
	_content_cb.on_ad_failed_to_show_full_screen_content = func(_err: AdError) -> void: _closed()
	_earn.on_user_earned_reward = func(_item: RewardedItem) -> void: _rewarded = true


func available() -> bool:
	return (OS.has_feature("android") or OS.has_feature("ios")) and Engine.has_singleton(NATIVE_SINGLETON) \
		and AdManager.ad_unit_id() != ""


# ------------------------------------------------------------------ consent + init

func initialize(on_ready: Callable = Callable()) -> void:
	if not available():
		super.initialize(on_ready)
		return
	var info := UserMessagingPlatform.consent_information
	info.update(ConsentRequestParameters.new(),
		func() -> void:
			if info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED and info.get_is_consent_form_available():
				_load_and_show_form(func() -> void: _start_sdk(on_ready))
			else:
				_start_sdk(on_ready),
		func(_err: FormError) -> void:
			_start_sdk(on_ready))   # consent service unreachable: Google then serves only non-personalised ads


func _load_and_show_form(on_closed: Callable) -> void:
	UserMessagingPlatform.load_consent_form(
		func(form: ConsentForm) -> void:
			form.show(func(_err: FormError) -> void: on_closed.call()),
		func(_err: FormError) -> void:
			on_closed.call())


## Starts the Mobile Ads SDK. Loading an ad before initialisation COMPLETES crashes the app on the current
## Google Mobile Ads SDK ("MobileAds.initialize must be called before using..."), so the first preload waits for
## the SDK's completion callback.
func _start_sdk(on_ready: Callable) -> void:
	if _starting:
		return
	_starting = true
	var done := OnInitializationCompleteListener.new()
	done.on_initialization_complete = func(_status: InitializationStatus) -> void:
		_ready_sdk = true
		_preload()
		if on_ready.is_valid():
			on_ready.call()
	MobileAds.initialize(done)


func privacy_options_required() -> bool:
	return available() and UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() \
		== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED


func show_privacy_options(on_done: Callable = Callable()) -> void:
	if not available():
		super.show_privacy_options(on_done)
		return
	UserMessagingPlatform.show_privacy_options_form(func(_err: FormError) -> void:
		if on_done.is_valid():
			on_done.call())


# ------------------------------------------------------------------ rewarded ads

func _preload() -> void:
	if _ad != null or _loading or not _ready_sdk:
		return
	_loading = true
	RewardedAdLoader.new().load(AdManager.ad_unit_id(), AdRequest.new(), _load_cb)


func show_rewarded(placement: String) -> void:
	if _ad == null:
		_preload()
		finished.emit.call_deferred(placement, false)   # nothing loaded yet: the UI says "no ad right now"
		return
	_placement = placement
	_rewarded = false
	_ad.show(_earn)


func _closed() -> void:
	if _ad != null:
		_ad.destroy()
	_ad = null
	var p := _placement
	_placement = ""
	finished.emit(p, _rewarded)
	_rewarded = false
	_preload()
