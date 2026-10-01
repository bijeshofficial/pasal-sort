extends Node
## Local notifications (mock). The backend is a no-op that only records what
## would be scheduled; an Android/iOS adapter replaces _backend_* only.
## Gameplay calls schedule()/cancel() and never knows which backend exists.

signal scheduled(id: String, seconds: int)

## id -> {fire_at, title, body}
var pending: Dictionary = {}


func schedule(id: String, seconds: int, title: String, body: String) -> void:
	if seconds <= 0:
		return
	pending[id] = {"fire_at": TimeManager.now() + seconds, "title": title, "body": body}
	_backend_schedule(id, seconds, title, body)
	scheduled.emit(id, seconds)


func cancel(id: String) -> void:
	if pending.erase(id):
		_backend_cancel(id)


func cancel_all() -> void:
	for id in pending.keys():
		_backend_cancel(id)
	pending.clear()


func is_scheduled(id: String) -> bool:
	return pending.has(id)


# --- Backend (replace for a real device) ------------------------------------

func _backend_schedule(_id: String, _seconds: int, _title: String, _body: String) -> void:
	pass


func _backend_cancel(_id: String) -> void:
	pass
