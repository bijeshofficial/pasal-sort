class_name AdProvider
extends RefCounted
## Rewarded-ad backend interface. AdManager talks only to this API, so swapping the test provider for a real
## network (AdMob, AppLovin, ...) needs no UI or reward changes. Ads are ALWAYS opt-in: the game never shows
## an ad the player did not ask for. Implementations must emit `finished(placement, rewarded)` exactly once per show().

signal finished(placement: String, rewarded: bool)

var is_test := false


func available() -> bool:
	return false


## Show a rewarded ad for `placement`; emit finished(placement, true) only if the player watched it through.
func show_rewarded(placement: String) -> void:
	finished.emit.call_deferred(placement, false)


## Called once at startup. Real networks ask for consent first (Google UMP), then initialise the SDK and
## pre-load an ad. on_ready() is called when setup is finished (or skipped).
func initialize(on_ready: Callable = Callable()) -> void:
	if on_ready.is_valid():
		on_ready.call_deferred()


## True when the player must be able to reopen their ad-consent choice (EEA/UK consent regions).
func privacy_options_required() -> bool:
	return false


## Reopen the consent form. on_done() is called when it closes.
func show_privacy_options(on_done: Callable = Callable()) -> void:
	if on_done.is_valid():
		on_done.call_deferred()
