extends Node
## Short vibrations on handheld devices. Respects the Haptics setting.

## Number of haptic requests that passed the settings check (debug/tests).
var fired_count := 0


func vibrate(ms: int) -> void:
	if not SaveManager.get_setting("haptics"):
		return
	fired_count += 1
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func light() -> void:
	vibrate(12)


func medium() -> void:
	vibrate(28)


func heavy() -> void:
	vibrate(55)
