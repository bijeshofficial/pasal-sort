extends SceneTree
## Loads every script and scene after the autoloads exist and reports any
## that fail to compile. Exit code 1 on failure.
##   godot --headless --path . --script res://tools/parse_check.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var bad := 0
	for dir in ["res://scripts", "res://scenes"]:
		for path in _files(dir):
			if path.ends_with(".gd"):
				var s: GDScript = load(path)
				if s == null or not s.can_instantiate():
					print("FAILED ", path)
					bad += 1
			elif path.ends_with(".tscn"):
				var p: PackedScene = load(path)
				if p == null:
					print("FAILED ", path)
					bad += 1
	print("parse check: %d failing" % bad)
	quit(1 if bad > 0 else 0)


func _files(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_files(dir.path_join(sub)))
	return out
