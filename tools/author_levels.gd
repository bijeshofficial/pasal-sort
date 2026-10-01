extends SceneTree
## Curates levels 11-30 into data/levels_authored.json (levels 1-10 are
## hand-made and kept as they are). Re-running is deterministic.
##   godot --headless --path . --script res://tools/author_levels.gd
## Uses LevelGenerator.build with the normal ramp, so the authored early
## curve matches the generated one it hands over to at level 31.

const PATH := "res://data/levels_authored.json"
const KEEP := ["level", "tier", "types", "twists", "teach", "tutorial", "forced", "cloth_after", "jars", "seed", "solution"]


func _initialize() -> void:
	GameData.preload_all()
	var data := GameData.load_json(PATH)
	var levels: Array = []
	for l in data.get("levels", []):
		if int(l["level"]) <= 10:
			levels.append(_ints(l))
	# Forget previously curated 11-30 so their old tiers don't feed back in.
	data["levels"] = levels.duplicate()
	for n in range(11, 31):
		var p := LevelGenerator.params_for(n)
		var lvl := LevelGenerator.build(n, p)
		var slim := {}
		for k in KEEP:
			if lvl.has(k) and not (typeof(lvl[k]) == TYPE_STRING and lvl[k] == "") and not (typeof(lvl[k]) == TYPE_ARRAY and (lvl[k] as Array).is_empty()):
				slim[k] = lvl[k]
		levels.append(slim)
		print("L%d %s types=%d twists=%s solution=%d" % [n, lvl["tier"], lvl["types"], lvl["twists"], lvl["solution"]])
	var lines := PackedStringArray()
	for l in levels:
		lines.append("\t\t" + JSON.stringify(l, "", false))
	var text := "{\n\t\"_comment\": %s,\n\t\"levels\": [\n%s\n\t]\n}\n" % [JSON.stringify(data.get("_comment", "")), ",\n".join(lines)]
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("wrote ", levels.size(), " levels")
	quit()


## JSON numbers load as floats; write whole numbers back as ints.
func _ints(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if is_equal_approx(v, roundf(v)) else v
		TYPE_ARRAY:
			var a: Array = []
			for x in v:
				a.append(_ints(x))
			return a
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[k] = _ints(v[k])
			return d
	return v
