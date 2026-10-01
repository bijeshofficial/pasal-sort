extends Node
## Lives: max 5, one regenerates every 30 minutes of real time. The last
## regeneration time is saved, so lives keep coming back while the app is
## closed. A saved time in the future (clock set back) is clamped to now
## instead of granting lives.

signal lives_changed(lives: int)

## Test/debug aid: seconds added to the clock (forwards to TimeManager).
var time_offset: float:
	get:
		return TimeManager.debug_offset
	set(v):
		TimeManager.debug_offset = v

var _accum := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.loaded.connect(tick)
	SaveManager.progress_reset.connect(tick)
	tick()


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= 0.5:
		_accum = 0.0
		tick()


func now() -> float:
	return TimeManager.now()


func max_lives() -> int:
	return int(GameData.economy()["lives"]["max"])


func regen_seconds() -> float:
	return float(GameData.economy()["lives"]["regen_seconds"])


func free_levels() -> int:
	return int(GameData.economy()["lives"].get("free_levels", 10))


func lives() -> int:
	return int(SaveManager.game().get("lives", max_lives()))


func is_full() -> bool:
	return lives() >= max_lives()


## Early tutorial levels never cost lives and can always be played.
func level_costs_life(level: int) -> bool:
	return level > free_levels()


func can_play(level: int) -> bool:
	return not level_costs_life(level) or lives() > 0 or unlimited_active()


# --- Unlimited lives (timer item from chests and events) --------------------

func unlimited_active() -> bool:
	return unlimited_seconds_left() > 0


func unlimited_seconds_left() -> int:
	return maxi(0, int(float(SaveManager.game().get("unlimited_lives_until", 0)) - now()))


## Adds `seconds` of unlimited lives (stacks with a running timer).
func add_unlimited(seconds: int) -> void:
	var g := SaveManager.game()
	var start := maxf(now(), float(g.get("unlimited_lives_until", 0)))
	g["unlimited_lives_until"] = int(start + seconds)
	lives_changed.emit(lives())
	SaveManager.save_game()


## Applies regeneration. Returns the number of lives gained.
func tick() -> int:
	if SaveManager.data.is_empty():
		return 0
	var g := SaveManager.game()
	var t := now()
	var last := float(g.get("last_life_time", 0))
	if lives() >= max_lives():
		g["last_life_time"] = t
		return 0
	if last <= 0.0 or last > t:
		# Missing, or in the future (clock tampering): restart the timer.
		g["last_life_time"] = t
		return 0
	var gained := int(floor((t - last) / regen_seconds()))
	if gained <= 0:
		return 0
	var before := lives()
	g["lives"] = mini(max_lives(), before + gained)
	g["last_life_time"] = last + gained * regen_seconds() if lives() < max_lives() else t
	lives_changed.emit(lives())
	SaveManager.save_game()
	return lives() - before


func lose_life() -> bool:
	if unlimited_active():
		return true
	if lives() <= 0:
		return false
	var g := SaveManager.game()
	if lives() >= max_lives():
		g["last_life_time"] = now()
	g["lives"] = lives() - 1
	lives_changed.emit(lives())
	SaveManager.save_game()
	_schedule_full_notification()
	return true


## "Your lives are full!" local notification for when the last life returns.
func _schedule_full_notification() -> void:
	if is_full():
		NotificationManager.cancel("lives_full")
		return
	var missing := max_lives() - lives()
	var secs := seconds_to_next() + (missing - 1) * int(regen_seconds())
	NotificationManager.schedule("lives_full", secs, "Pasal Sort", "Your lives are full! Come sort some candies.")


func add_lives(n: int = 1) -> void:
	SaveManager.game()["lives"] = mini(max_lives(), lives() + n)
	if is_full():
		SaveManager.game()["last_life_time"] = now()
		NotificationManager.cancel("lives_full")
	lives_changed.emit(lives())
	SaveManager.save_game()


func refill() -> void:
	add_lives(max_lives())


func refill_price() -> int:
	return int(GameData.economy()["lives"]["refill_price"])


func buy_refill() -> bool:
	if is_full() or not CurrencyManager.spend(refill_price()):
		return false
	refill()
	return true


func seconds_to_next() -> int:
	if is_full():
		return 0
	var last := float(SaveManager.game().get("last_life_time", now()))
	return maxi(0, int(ceil(regen_seconds() - (now() - last))))


## "12:34" until the next life, or "Full".
func countdown_text() -> String:
	if unlimited_active():
		return TimeManager.short_duration(unlimited_seconds_left())
	if is_full():
		return "Full"
	var s := seconds_to_next()
	return "%d:%02d" % [s / 60, s % 60]
