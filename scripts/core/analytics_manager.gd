extends Node
## Local analytics for balancing: one JSON object per line in
## user://analytics.log. Never logs personal data (no names, no ids beyond a
## per-session number). A real SDK adapter replaces _backend_send() only.
## Events: session_start/end, level_start, level_win, level_fail,
## booster_used, task_completed, area_completed, purchase_mock, ad_mock,
## daily_claim (+ reward_granted).

var log_path := "user://analytics.log"
var session := 0
var enabled := true

var _started := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = int(Time.get_unix_time_from_system())
	_started = Time.get_ticks_msec() / 1000.0
	# Test runners use their own save file: keep their events apart too.
	if SaveManager.save_path != "user://save.json":
		log_path = "user://analytics_test.log"
	log_event("session_start", {"level": ProgressionManager.current_level()})
	GameManager.app_paused.connect(_on_paused)
	GameManager.game_event.connect(_on_game_event)
	RenovationManager.task_completed.connect(func(a: int, t: String, st: int) -> void: log_event("task_completed", {"area": a, "task": t, "style": st}))
	RenovationManager.area_completed.connect(func(a: int) -> void: log_event("area_completed", {"area": a}))


func log_event(name: String, data: Dictionary = {}) -> void:
	if not enabled:
		return
	var row := {"t": int(TimeManager.now()), "s": session, "e": name}
	for k in data:
		if k in ["name", "player", "email"]:
			continue  # never personal data
		row[k] = data[k]
	var f: FileAccess
	if FileAccess.file_exists(log_path):
		f = FileAccess.open(log_path, FileAccess.READ_WRITE)
		if f:
			f.seek_end()
	else:
		f = FileAccess.open(log_path, FileAccess.WRITE)
	if f:
		f.store_line(JSON.stringify(row))
		f.close()
	_backend_send(name, row)


func _on_game_event(id: String, amount: int) -> void:
	if id == "booster":
		log_event("booster_used", {"count": amount})


func _on_paused() -> void:
	log_event("session_end", {"seconds": int(Time.get_ticks_msec() / 1000.0 - _started)})


## Reads the log back: [{...}, ...] (most recent last, up to `limit`).
func read(limit: int = 5000) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(log_path):
		return out
	var f := FileAccess.open(log_path, FileAccess.READ)
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var v: Variant = JSON.parse_string(line)
		if typeof(v) == TYPE_DICTIONARY:
			out.append(v)
	if out.size() > limit:
		out = out.slice(out.size() - limit)
	return out


## Balancing summary for the debug screen.
func summary() -> Dictionary:
	var rows := read()
	var counts := {}
	var wins := 0
	var win_moves := 0
	var win_time := 0
	var fails := {}
	for r in rows:
		var e := String(r.get("e", ""))
		counts[e] = int(counts.get(e, 0)) + 1
		if e == "level_win":
			wins += 1
			win_moves += int(r.get("moves", 0))
			win_time += int(r.get("time", 0))
		elif e == "level_fail":
			var reason := String(r.get("reason", "?"))
			fails[reason] = int(fails.get(reason, 0)) + 1
	return {"events": rows.size(), "counts": counts, "wins": wins,
		"avg_moves": 0.0 if wins == 0 else float(win_moves) / wins,
		"avg_seconds": 0.0 if wins == 0 else float(win_time) / wins, "fails": fails}


func clear() -> void:
	if FileAccess.file_exists(log_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(log_path))


## Hook for a real analytics SDK (no-op).
func _backend_send(_name: String, _row: Dictionary) -> void:
	pass
