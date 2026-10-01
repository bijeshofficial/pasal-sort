class_name ShutterView
extends Control
## A pasal's metal rolling shutter, drawn in code. `cover` 0 = rolled up
## (invisible), 1 = fully down over the screen. Used by the loading screen
## and by ScreenManager's quick screen-change wipe.

const STEEL := Color("a3acb1")
const STEEL_DARK := Color("7f898f")
const STEEL_LIGHT := Color("c3cacd")
const BAR := Color("6b747a")
const HANDLE := Color("3d4448")
const SLAT := 44.0

@export var cover := 0.0:
	set(v):
		cover = clampf(v, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var h := size.y * cover
	if h <= 0.5:
		return
	var w := size.x
	draw_rect(Rect2(0, 0, w, h), STEEL)
	# Slats roll with the bottom edge, so the pattern moves as it slides.
	var y := h - 70.0
	while y > -SLAT:
		draw_rect(Rect2(0, y - 5, w, 5), STEEL_DARK)
		draw_rect(Rect2(0, y, w, 4), STEEL_LIGHT)
		draw_rect(Rect2(0, y - SLAT * 0.5 - 1, w, 2), Color(STEEL_DARK, 0.45))
		y -= SLAT
	# Side guide rails.
	draw_rect(Rect2(0, 0, 18, h), STEEL_DARK)
	draw_rect(Rect2(w - 18, 0, 18, h), STEEL_DARK)
	# Bottom bar with a handle and two lock loops.
	var bar := Rect2(0, h - 64, w, 64)
	draw_rect(bar, BAR)
	draw_rect(Rect2(0, h - 8, w, 8), HANDLE)
	DrawKit.rrect(self, Rect2(w * 0.5 - 90, h - 50, 180, 26), 13, HANDLE)
	for side in [-1.0, 1.0]:
		var cx: float = w * 0.5 + side * 300.0
		draw_arc(Vector2(cx, h - 18), 16, PI, TAU, 14, HANDLE, 7, true)
