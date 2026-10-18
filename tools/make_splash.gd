extends SceneTree
## Renders the startup image (assets/app_icon/splash.png): the loading
## screen's first frame, the pasal's closed rolling shutter. Godot's boot
## splash and the iOS launch screen show it, so the app opens straight onto
## the shutter that then rolls up (without it, iOS shows Godot's logo).
##   godot --path . --script res://tools/make_splash.gd
## Rendered offscreen at 1080x1920, so any monitor works. Re-run it after
## changing ShutterView.

const OUT := "res://assets/app_icon/splash.png"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var vp := SubViewport.new()
	vp.size = Vector2i(1080, 1920)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var shutter: Control = load("res://scripts/visuals/shutter_view.gd").new()
	shutter.size = Vector2(1080, 1920)
	shutter.cover = 1.0
	vp.add_child(shutter)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(OUT)
	print("wrote %s (%dx%d), top colour %s" % [OUT, img.get_width(), img.get_height(), img.get_pixel(540, 4).to_html(false)])
	quit()
