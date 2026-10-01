extends Node
## Renders contact sheets of the code-drawn renovation art, the cast and
## every area (before/after) as PNGs for review. Runs as a scene so the
## autoloads exist (needs a window, not --headless):
##   godot --path . --resolution 1080x1920 res://tools/art_sheet.tscn -- --out=/tmp/sheets

const KINDS := ["counter", "shelf", "window", "wall_sign", "pendant_lamp", "cash_box", "scale", "basket", "garland", "stool", "counter_jars",
	"shutter", "awning", "steps", "plant_pot", "street_lamp", "bench", "string_lights", "bicycle", "ceiling_fan", "cabinet", "sacks",
	"ladder", "crates", "curtain", "wall_clock", "stove", "table", "sofa", "rug", "frames", "water_tank", "kite", "railing", "umbrella",
	"clothesline", "tea_stall", "tree", "lantern", "bunting", "boat", "dock", "chair", "flower_bed", "hut", "door", "rack"]
const STYLES := [
	{"base": "8b5a2b", "accent": "e0a458", "pattern": "carved"},
	{"base": "2f7fc1", "accent": "ffd166", "pattern": "painted"},
	{"base": "9aa5b1", "accent": "51606e", "pattern": "steel"},
]

var out_dir := "user://sheets"


var root: Window


func _ready() -> void:
	root = get_tree().root
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	var per_page := 6
	var page := 0
	var i := 0
	while i < KINDS.size():
		var batch: Array = KINDS.slice(i, i + per_page)
		await _render_kinds(batch, "kinds_%02d" % page)
		i += per_page
		page += 1
	await _render_cast()
	for ai in range(1, GameData.area_count() + 1):
		for m in ["before", "after"]:
			await _render_area(ai, m)
	get_tree().quit()


func _render_area(index: int, mode: String) -> void:
	var c := _canvas()
	var scene := AreaScene.new()
	c.add_child(scene)
	scene.build(index, mode)
	var vp := root.get_visible_rect().size
	var k: float = vp.x / scene.world_size.x
	scene.scale = Vector2(k, k)
	await _shot("area_%02d_%s" % [index, mode])
	c.queue_free()


func _canvas() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("efe6d6")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(bg)
	root.add_child(c)
	return c


func _render_kinds(kinds: Array, name: String) -> void:
	var c := _canvas()
	var vp := root.get_visible_rect().size
	var cell := Vector2(vp.x / 4.0, vp.y / kinds.size())
	for r in kinds.size():
		var kind: String = kinds[r]
		for k in 4:
			var holder := Node2D.new()
			var sz := Vector2(cell.x - 60, cell.y - 70)
			holder.position = Vector2(k * cell.x + 30, r * cell.y + 50)
			var style: Dictionary = {} if k == 0 else STYLES[k - 1]
			holder.draw.connect(func() -> void: RenoArt.draw_object(holder, kind, sz, style, k == 0, 1.0, false))
			c.add_child(holder)
		var l := Label.new()
		l.text = kind
		l.position = Vector2(8, r * cell.y + 4)
		l.add_theme_color_override("font_color", Color.BLACK)
		c.add_child(l)
	await _shot(name)
	c.queue_free()


func _render_cast() -> void:
	var c := _canvas()
	var vp := root.get_visible_rect().size
	var ids := ["maya", "hajurama", "bhai", "kanchha", "sunita", "biralo"]
	var moods: Array = CharacterArt.MOODS
	var cell := Vector2(vp.x / moods.size(), vp.y / ids.size())
	for r in ids.size():
		for k in moods.size():
			var holder := Node2D.new()
			holder.position = Vector2((k + 0.5) * cell.x, (r + 1) * cell.y - 8)
			var id: String = ids[r]
			var mood: String = moods[k]
			var unit := cell.y / 470.0 if not CharacterArt.is_cat(id) else cell.y / 360.0
			holder.draw.connect(func() -> void: CharacterArt.draw(holder, id, Vector2.ZERO, unit, mood, 0.5))
			c.add_child(holder)
	await _shot("cast")
	c.queue_free()


func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)
