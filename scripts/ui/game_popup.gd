class_name GamePopup
extends Control
## Reusable popup: title, illustration, body text, optional extra content and
## 1-3 big buttons. Built from a spec dictionary:
##   {id, title, art ("icon" | "candy:3" | "avatar:2" | Callable(Control)),
##    art_color, body, content (Control), buttons: [{text, kind, icon, cb,
##    close (default true), id, badge}], vertical, closable, on_back, width}

const SCENE_PATH := "res://scenes/ui/popup.tscn"

var spec: Dictionary = {}
var buttons: Dictionary = {}   # button id -> GameButton
var body_label: Label


static func create(popup_spec: Dictionary) -> GamePopup:
	var p: GamePopup = load(SCENE_PATH).instantiate()
	p.spec = popup_spec
	if popup_spec.has("id"):
		p.set_meta("popup_id", popup_spec["id"])
	return p


func _ready() -> void:
	var v := UIKit.modal_frame(self, float(spec.get("width", 880)), String(spec.get("title", "")))
	if spec.get("closable", false):
		UIKit.attach_close(self, on_back)
	if spec.has("art"):
		v.add_child(_art(spec["art"]))
	if spec.has("body") and String(spec["body"]) != "":
		body_label = UIKit.label(String(spec["body"]), int(spec.get("body_size", 42)), UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, false)
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_label.custom_minimum_size = Vector2(float(spec.get("width", 880)) - 140, 0)
		v.add_child(body_label)
	if spec.has("content") and spec["content"] is Control:
		v.add_child(spec["content"])
	var list: Array = spec.get("buttons", [])
	if list.is_empty():
		return
	var box: BoxContainer = VBoxContainer.new() if (spec.get("vertical", false) or list.size() > 2) else HBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	v.add_child(box)
	for i in list.size():
		var b: Dictionary = list[i]
		var btn := UIKit.button(String(b.get("text", "OK")), String(b.get("kind", "primary")), String(b.get("icon", "")), int(b.get("size", 48)), Vector2(0, 150))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = bool(b.get("disabled", false))
		var cb: Callable = b.get("cb", Callable())
		var closes := bool(b.get("close", true))
		btn.pressed.connect(func() -> void:
			if closes:
				close()
			if cb.is_valid():
				cb.call())
		box.add_child(btn)
		buttons[String(b.get("id", str(i)))] = btn
		if b.has("badge"):
			var badge := UIKit.badge(String(b["badge"]), UIKit.HEART, 30)
			badge.position = Vector2(-14, -22)
			badge.z_index = 3
			btn.add_child(badge)


func _art(art: Variant) -> Control:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var size := float(spec.get("art_size", 240))
	if art is Callable:
		var c := Control.new()
		c.custom_minimum_size = Vector2(size * 2.2, size)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.draw.connect(func() -> void: (art as Callable).call(c))
		holder.add_child(c)
		return holder
	var s := String(art)
	if s.begins_with("candy:"):
		var t := int(s.substr(6))
		var c := Control.new()
		c.custom_minimum_size = Vector2(size, size)
		c.draw.connect(func() -> void: CandyArt.draw_candy(c, c.size * 0.5, size * 0.95, t))
		holder.add_child(c)
		return holder
	var fill: Color = spec.get("art_color", UIKit.GOLD)
	var ic_color: Color = spec.get("art_icon_color", Color.WHITE)
	holder.add_child(UIKit.disk(s, size, fill, fill.darkened(0.35), ic_color))
	return holder


func button(id: String) -> GameButton:
	return buttons.get(id)


func press(id: String) -> void:
	var b := button(id)
	if b and not b.disabled:
		b.pressed.emit()


func close() -> void:
	ScreenManager.close_modal(self)


func on_back() -> void:
	close()
	var cb: Callable = spec.get("on_back", Callable())
	if cb.is_valid():
		cb.call()
