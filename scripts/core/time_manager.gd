extends Node
## The single source of "now" for lives, dailies, events and races.
##
## debug_offset (seconds) moves the clock forward for testing; the debug menu
## and tests change it. Day boundaries are local midnight. If the device clock
## goes backwards (now < the latest time ever seen), clock_rewound() is true
## until real time catches up, and time-gated rewards must not be granted.

signal clock_changed
signal day_changed(day: String)

## Tolerance before a backwards clock counts as tampering.
const REWIND_TOLERANCE := 120.0

var debug_offset := 0.0:
	set(v):
		debug_offset = v
		clock_changed.emit()
		_check_day()

## Debug/screenshots: pretend it is this local hour for scene lighting (-1 = off).
var force_hour := -1

var _last_day := ""
var _accum := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.loaded.connect(_on_loaded)
	_on_loaded()


func _on_loaded() -> void:
	_last_day = today()
	_remember()


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= 1.0:
		_accum = 0.0
		_remember()
		_check_day()


func now() -> float:
	return Time.get_unix_time_from_system() + debug_offset


func now_int() -> int:
	return int(now())


## Seconds east of UTC for the device's time zone.
func tz_bias() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


## Local date "YYYY-MM-DD" at unix time `t` (default: now).
func date_string(t: float = -1.0) -> String:
	if t < 0.0:
		t = now()
	var d := Time.get_date_dict_from_unix_time(int(t) + tz_bias())
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


func today() -> String:
	return date_string()


## Whole local days since 1970-01-01 (for rotation and streak maths).
func day_number(t: float = -1.0) -> int:
	if t < 0.0:
		t = now()
	return int(floor((t + tz_bias()) / 86400.0))


## Day number of a "YYYY-MM-DD" string (or -1).
func day_number_of(date: String) -> int:
	if date.length() < 10:
		return -1
	var unix := Time.get_unix_time_from_datetime_string(date + "T00:00:00")
	return int(floor(unix / 86400.0))


## Weeks since an epoch Monday (1970-01-05), for weekly events.
func week_number(t: float = -1.0) -> int:
	return int(floor((day_number(t) - 4) / 7.0))


func seconds_to_midnight() -> int:
	var t := now() + tz_bias()
	return int(86400.0 - fmod(t, 86400.0))


## Seconds until the next weekly rollover (Monday 00:00 local).
func seconds_to_week_end() -> int:
	var days_in := posmod(day_number() - 4, 7)
	return (6 - days_in) * 86400 + seconds_to_midnight()


## True while the device clock is behind the latest time we have seen.
func clock_rewound() -> bool:
	if SaveManager.data.is_empty():
		return false
	var seen := float(SaveManager.game().get("time", {}).get("max_seen", 0))
	return now() + REWIND_TOLERANCE < seen


## Debug: move the clock forward.
func advance(seconds: float) -> void:
	debug_offset += seconds


## "1h 05m", "12m 30s", "45s".
static func short_duration(seconds: int) -> String:
	seconds = maxi(0, seconds)
	if seconds >= 86400:
		return "%dd %02dh" % [seconds / 86400, (seconds % 86400) / 3600]
	if seconds >= 3600:
		return "%dh %02dm" % [seconds / 3600, (seconds % 3600) / 60]
	if seconds >= 60:
		return "%dm %02ds" % [seconds / 60, seconds % 60]
	return "%ds" % seconds


func _remember() -> void:
	if SaveManager.data.is_empty():
		return
	var block: Dictionary = SaveManager.game().get("time", {})
	if not SaveManager.game().has("time"):
		SaveManager.game()["time"] = block
	block["max_seen"] = maxf(float(block.get("max_seen", 0)), now())


func _check_day() -> void:
	var d := today()
	if d != _last_day:
		_last_day = d
		day_changed.emit(d)
