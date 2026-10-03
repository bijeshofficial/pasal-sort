extends Node
## Plays story dialogue from data/story/*.json: a portrait, the speaker's name
## and a speech bubble, one line per tap. Every line goes through tr(), so
## the translation CSV covers the story too.

signal dialogue_started(id: String)
signal dialogue_finished(id: String)

const BoxScript := preload("res://scripts/ui/dialogue_box.gd")

## Tests: finish every dialogue instantly.
var instant := false
var played: Array[String] = []

var _box: Control


func has_dialogue(id: String) -> bool:
	return GameData.has_story(id)


func is_playing() -> bool:
	return _box != null and is_instance_valid(_box) and not _box.is_queued_for_deletion()


## Plays `id`; calls on_done when the player taps through (or skips).
## opts: {title: String} shows a chapter banner above the box.
func play(id: String, on_done: Callable = Callable(), opts: Dictionary = {}) -> void:
	var lines := GameData.story(id)
	played.append(id)
	if lines.is_empty() or instant:
		dialogue_started.emit(id)
		dialogue_finished.emit(id)
		if on_done.is_valid():
			on_done.call_deferred()
		return
	var box: Control = BoxScript.new()
	box.setup(id, lines, opts)
	_box = box
	box.set_meta("modal_overlay", true)
	box.finished.connect(func() -> void:
		_box = null
		dialogue_finished.emit(id)
		if on_done.is_valid():
			on_done.call())
	ScreenManager.push_modal(box)
	dialogue_started.emit(id)


func current_box() -> Control:
	return _box if is_playing() else null
