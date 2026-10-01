extends Node
## Bazaar Race (offline): race 4 friendly shopkeeper characters to 7 wins.
## Rivals are simulated: each gets a seeded list of finish times, so their
## progress is just "how many of their times are in the past" and survives
## restarts. The top 3 finishers win rewards. A new race opens a few hours
## after the last one ends.
##   game.race = {state: idle|running|done, id, start, end, wins, rivals:
##                [{id, times: [unix]}], rank, claimed, next_at}

signal changed

const RACE := "res://data/race.json"


static func save_defaults() -> Dictionary:
	return {"state": "idle", "id": 0, "start": 0, "end": 0, "wins": 0, "rivals": [], "rank": 0, "claimed": false, "next_at": 0, "player_done_at": 0}


static func migrate_block(block: Dictionary, _from_version: int) -> Dictionary:
	return block


func _ready() -> void:
	GameManager.game_event.connect(_on_event)


func data() -> Dictionary:
	return GameData.load_json(RACE)


func block() -> Dictionary:
	var g := SaveManager.game()
	if typeof(g.get("race")) != TYPE_DICTIONARY:
		g["race"] = save_defaults()
	return g["race"]


func goal() -> int:
	return int(data().get("wins", 7))


func state() -> String:
	update()
	return String(block().get("state", "idle"))


func can_join() -> bool:
	return state() == "idle" and TimeManager.now() >= float(block().get("next_at", 0)) and not TimeManager.clock_rewound()


func seconds_until_open() -> int:
	return maxi(0, int(float(block().get("next_at", 0)) - TimeManager.now()))


## Starts a race with 4 rivals and their simulated finish times.
func join() -> bool:
	if not can_join():
		return false
	var b := block()
	var now := TimeManager.now_int()
	var rid := int(b.get("id", 0)) + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = now / 60 + rid * 9973
	var pool: Array = (data().get("rivals", []) as Array).duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var rivals: Array = []
	for r in pool.slice(0, 4):
		var pace: Array = r["pace"]
		var t := float(now)
		var times: Array = []
		for k in goal():
			t += rng.randf_range(float(pace[0]), float(pace[1])) * 60.0
			times.append(int(t))
		rivals.append({"id": r["id"], "times": times})
	b["state"] = "running"
	b["id"] = rid
	b["start"] = now
	b["end"] = now + int(data().get("duration_hours", 24)) * 3600
	b["wins"] = 0
	b["rivals"] = rivals
	b["rank"] = 0
	b["claimed"] = false
	b["player_done_at"] = 0
	SaveManager.save_game()
	changed.emit()
	return true


func rival_info(id: String) -> Dictionary:
	for r in data().get("rivals", []):
		if r["id"] == id:
			return r
	return {}


func rival_wins(r: Dictionary, at: float = -1.0) -> int:
	if at < 0.0:
		at = TimeManager.now()
	var n := 0
	for t in r.get("times", []):
		if float(t) <= at:
			n += 1
	return n


func player_wins() -> int:
	return int(block().get("wins", 0))


## Standings: [{id, name, shop, avatar, wins, player, finished_at}] best first.
func standings() -> Array:
	update()
	var b := block()
	var now := TimeManager.now()
	var rows: Array = []
	var profile: Dictionary = SaveManager.game().get("profile", {})
	rows.append({"id": "you", "name": String(profile.get("name", "Player")), "shop": tr("Your pasal"), "avatar": int(profile.get("avatar", 0)),
		"wins": player_wins(), "player": true, "finished_at": float(b.get("player_done_at", 0)) if player_wins() >= goal() else INF})
	for r in b.get("rivals", []):
		var info := rival_info(String(r["id"]))
		var w := rival_wins(r)
		var times: Array = r["times"]
		rows.append({"id": r["id"], "name": tr(String(info.get("name", r["id"]))), "shop": tr(String(info.get("shop", ""))), "avatar": int(info.get("avatar", 0)),
			"wins": w, "player": false, "finished_at": float(times[goal() - 1]) if w >= goal() else INF})
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if float(x["finished_at"]) != float(y["finished_at"]):
			return float(x["finished_at"]) < float(y["finished_at"])
		if int(x["wins"]) != int(y["wins"]):
			return int(x["wins"]) > int(y["wins"])
		return bool(x["player"]) and not bool(y["player"]))
	return rows


## Ends the race when the player finishes, when 3 rivals are home first
## (no podium left) or when time runs out.
func update() -> void:
	var b := block()
	if String(b.get("state", "idle")) == "done" and bool(b.get("claimed", false)):
		b["state"] = "idle"
	if String(b.get("state", "idle")) != "running":
		return
	var now := TimeManager.now()
	var finished_rivals := 0
	for r in b.get("rivals", []):
		if rival_wins(r, now) >= goal():
			finished_rivals += 1
	if player_wins() >= goal() or finished_rivals >= 3 or now >= float(b.get("end", 0)):
		b["state"] = "done"
		b["rank"] = _rank()
		b["next_at"] = int(now) + int(data().get("cooldown_hours", 3)) * 3600
		if int(b["rank"]) == 1:
			SaveManager.add_game_stat("race_wins")
		SaveManager.save_game()
		changed.emit()


func _rank() -> int:
	if player_wins() < goal():
		return 0
	var done_at := float(block().get("player_done_at", TimeManager.now()))
	var ahead := 0
	for r in block().get("rivals", []):
		var times: Array = r["times"]
		if float(times[goal() - 1]) < done_at:
			ahead += 1
	return ahead + 1


func rank() -> int:
	return int(block().get("rank", 0))


func reward_for(rank_value: int) -> Dictionary:
	var list: Array = data().get("rewards", [])
	if rank_value < 1 or rank_value > list.size():
		return {}
	return (list[rank_value - 1] as Dictionary).duplicate(true)


func can_claim() -> bool:
	update()
	return String(block().get("state", "")) == "done" and not bool(block().get("claimed", false))


## Collects the podium reward (or just closes the race). Returns the reward.
func claim() -> Dictionary:
	if not can_claim():
		return {}
	var b := block()
	b["claimed"] = true
	var r := reward_for(rank())
	if not r.is_empty():
		Rewards.grant(r, "race")
	b["state"] = "idle"
	SaveManager.save_game()
	changed.emit()
	return r


func _on_event(id: String, amount: int) -> void:
	if id != "win" or String(block().get("state", "")) != "running":
		return
	update()
	if String(block().get("state", "")) != "running":
		return
	var b := block()
	b["wins"] = mini(goal(), player_wins() + amount)
	if player_wins() >= goal():
		b["player_done_at"] = TimeManager.now()
	update()
	changed.emit()


func attention() -> bool:
	return can_join() or can_claim()
