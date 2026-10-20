extends SceneTree
## Renders reference pictures for the art brief: every area at world size
## (1800x1500) before and after renovation, plus a copy with each object's
## box outlined and labelled with the PNG filename stem it needs.
##   godot --path . --resolution 540x960 --script res://tools/make_art_brief.gd -- --out=DIR

var out_dir := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	root.get_node("SaveManager").set_save_path("user://art_brief_save.json")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var GD = load("res://scripts/data/game_data.gd")
	for ai in range(1, GD.area_count() + 1):
		var data: Dictionary = GD.area(ai)
		var id := String(data["id"])
		for m in ["before", "after"]:
			await _render(ai, m, id + "_" + m + ".png", null)
		await _render(ai, "after", id + "_layout.png", data)
	print("art brief layouts written to ", out_dir)
	quit()


func _render(index: int, mode: String, file: String, boxes: Variant) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1800, 1500)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene: Node2D = load("res://scripts/visuals/area_scene.gd").new()
	vp.add_child(scene)
	scene.build(index, mode)
	if boxes != null:
		var overlay := Node2D.new()
		vp.add_child(overlay)
		overlay.draw.connect(func() -> void: _draw_boxes(overlay, boxes))
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out_dir.path_join(file))
	vp.queue_free()
	await process_frame


func _draw_boxes(ci: Node2D, data: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	var objs: Array = (data["objects"] as Array).duplicate()
	objs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("z", 0)) < int(b.get("z", 0)))
	var k := 0
	for o in objs:
		var r: Array = o["rect"]
		var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		var col := Color.from_hsv(fmod(k * 0.17, 1.0), 0.9, 1.0)
		ci.draw_rect(rect, Color(col, 0.10), true)
		ci.draw_rect(rect, col, false, 4.0)
		var label := "%s  (%dx%d)" % [o["id"], int(r[2]), int(r[3])]
		var pos := rect.position + Vector2(8, 30 + (k % 3) * 30)
		ci.draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 8, Color.BLACK)
		ci.draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col)
		k += 1
