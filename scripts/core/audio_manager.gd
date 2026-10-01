extends Node
## Sound effects and music on separate buses, controlled by settings.
## If assets/audio/<id>.ogg (or .wav) exists it is used; otherwise a
## generated placeholder tone plays, so every hook is audible today.
##
## Hook ids: button_click, gameplay_interaction (select), success, perfect,
## failure, combo, reward, level_complete, coin_pickup, plus game sounds:
## select, deselect, clack, nope, lid_pop, shuffle, extra_jar, undo, shutter,
## reveal, unlock, cloth, heart, cheer, pop.

const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"
const ALIASES := {"gameplay_interaction": "select"}

## Recent ids that were requested (debug + smoke test).
var played_log: Array[String] = []

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_task := -1
var _music_mutex := Mutex.new()
var _pending_music: AudioStream
## Headless runs (CI, smoke test) use the dummy audio driver, which never
## mixes and so never releases playbacks; skip real playback there.
var _silent := DisplayServer.get_name() == "headless"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(SFX_BUS)
	_ensure_bus(MUSIC_BUS)
	_streams = ToneSynth.build_sfx()
	_load_audio_files()
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = MUSIC_BUS
	_music.volume_db = -16.0
	add_child(_music)
	apply_settings()
	SaveManager.setting_changed.connect(func(_k: String, _v: Variant) -> void: apply_settings())
	SaveManager.progress_reset.connect(apply_settings)
	_music_task = WorkerThreadPool.add_task(_build_music_async)


func _process(_delta: float) -> void:
	if _music_task < 0:
		return
	_music_mutex.lock()
	var stream := _pending_music
	_pending_music = null
	_music_mutex.unlock()
	if stream:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
		_music.stream = stream
		apply_settings()


func _exit_tree() -> void:
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
	_pending_music = null
	# Release playbacks so nothing leaks at quit.
	for p in _players:
		p.stop()
		p.stream = null
	if _music:
		_music.stop()
		_music.stream = null


func play(id: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var key: String = ALIASES.get(id, id)
	played_log.append(id)
	if played_log.size() > 128:
		played_log.pop_front()
	if not _streams.has(key):
		push_warning("AudioManager: unknown sound '%s'" % id)
		return
	if _silent:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[key]
	p.pitch_scale = pitch * randf_range(0.985, 1.015)
	p.volume_db = volume_db
	p.play()


## Combo sound rises in pitch with the streak.
func play_combo(streak: int) -> void:
	play("combo", 1.0 + 0.06 * clampi(streak, 0, 15))


func button_click() -> void: play("button_click")
func gameplay_interaction() -> void: play("gameplay_interaction")
func success() -> void: play("success")
func perfect() -> void: play("perfect")
func failure() -> void: play("failure")
func reward() -> void: play("reward")
func level_complete() -> void: play("level_complete")
func coin_pickup() -> void: play("coin_pickup")


## Bus levels at volume 1.0 (the sliders scale down from here).
const SFX_BASE_DB := -3.0
const MUSIC_BASE_DB := 0.0


func apply_settings() -> void:
	apply_volumes()
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), not SaveManager.get_setting("sound"))
	var music_on := SaveManager.get_setting("music")
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC_BUS), not music_on)
	if _music and _music.stream and not _silent:
		if music_on and not _music.playing:
			_music.play()
		elif not music_on and _music.playing:
			_music.stop()


## Applies the volume sliders without touching mute or playback.
func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), _vol_db(SaveManager.get_volume("sfx_volume"), SFX_BASE_DB))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), _vol_db(SaveManager.get_volume("music_volume"), MUSIC_BASE_DB))


func _vol_db(v: float, base: float) -> float:
	return -80.0 if v <= 0.001 else base + linear_to_db(v)


## Mutes everything while a (mock) ad is on screen.
func set_ad_mute(muted: bool) -> void:
	AudioServer.set_bus_mute(0, muted)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _load_audio_files() -> void:
	for key in _streams.keys():
		for ext in ["ogg", "wav", "mp3"]:
			var path := "res://assets/audio/%s.%s" % [key, ext]
			if ResourceLoader.exists(path):
				_streams[key] = load(path)
				break


func _build_music_async() -> void:
	var stream: AudioStream
	if ResourceLoader.exists("res://assets/audio/music.ogg"):
		stream = load("res://assets/audio/music.ogg")
	else:
		stream = ToneSynth.build_music()
	_music_mutex.lock()
	_pending_music = stream
	_music_mutex.unlock()
