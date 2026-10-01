class_name CharacterVisual
extends Node2D
## A story character as a scene node: idle breathing, blinking, and the
## "cheer", "wave" and "worry" reactions. Origin = bottom of the bust.
## Swap the _draw() for sprites later without touching callers.

@export var id := "maya":
	set(v):
		id = v
		queue_redraw()
@export var mood := "neutral"
@export var unit := 1.0

var pose := "idle"
var _t := 0.0
var _arm := 0.0
var _blink := 0.0
var _next_blink := 2.5
var _mood_tween: Tween


func _process(delta: float) -> void:
	_t += delta
	var target := 1.0 if pose == "cheer" else 0.0
	_arm = move_toward(_arm, target, delta * 5.0)
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 1.0
		_next_blink = randf_range(2.2, 4.5)
	_blink = maxf(0.0, _blink - delta * 7.0)
	queue_redraw()


func _draw() -> void:
	CharacterArt.draw(self, id, Vector2.ZERO, unit, mood, _t, pose, _arm, _blink)


func cheer(duration: float = 1.6) -> void:
	_react("cheer", "laugh", duration)


func wave(duration: float = 1.4) -> void:
	_react("wave", "happy", duration)


func worry(duration: float = 2.0) -> void:
	_react("idle", "worried", duration)


## Shows `new_mood` (and pose) for `duration` seconds, then back to neutral.
func _react(new_pose: String, new_mood: String, duration: float) -> void:
	pose = new_pose
	mood = new_mood
	if _mood_tween:
		_mood_tween.kill()
	_mood_tween = create_tween()
	_mood_tween.tween_interval(duration)
	_mood_tween.tween_callback(func() -> void:
		pose = "idle"
		mood = "neutral")


## Height of the drawn bust in local pixels (layout helper).
func bust_height() -> float:
	return (300.0 if CharacterArt.is_cat(id) else 440.0) * unit
