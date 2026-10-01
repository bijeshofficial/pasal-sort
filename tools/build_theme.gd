extends SceneTree
## Builds res://assets/ui/game_theme.tres, the project-wide Theme: chunky
## display font with a Devanagari fallback, rounded glossy-looking buttons
## with a thick darker bottom edge, light game panels, hidden scrollbars and
## a styled text field. Most UI is built by UIKit in code; this theme makes
## sure nothing ever falls back to Godot's default grey look.
##   godot --headless --path . --script res://tools/build_theme.gd

const OUT := "res://assets/ui/game_theme.tres"


func _initialize() -> void:
	var t := Theme.new()
	var heavy := FontVariation.new()
	heavy.base_font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	var deva := FontVariation.new()
	deva.base_font = load("res://assets/fonts/Baloo2-Variable.ttf")
	deva.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	heavy.fallbacks = [deva]
	t.default_font = heavy
	t.default_font_size = 44
	var ink := Color("2b1f63")
	t.set_color("font_color", "Label", ink)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(state, "Button", _button(state))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("eeeaf8"))
	t.set_color("font_outline_color", "Button", Color("1d6608"))
	t.set_constant("outline_size", "Button", 10)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("fdfcff")
	panel.set_corner_radius_all(48)
	panel.border_color = Color("5a45d8")
	panel.set_border_width_all(10)
	panel.border_width_bottom = 18
	panel.set_content_margin_all(40)
	panel.shadow_color = Color(0.04, 0.01, 0.15, 0.35)
	panel.shadow_size = 12
	panel.shadow_offset = Vector2(0, 10)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)
	var field := StyleBoxFlat.new()
	field.bg_color = Color("e7e1ff")
	field.set_corner_radius_all(26)
	field.border_color = Color("9d93dc")
	field.border_width_bottom = 6
	field.set_content_margin_all(18)
	t.set_stylebox("normal", "LineEdit", field)
	var focus := field.duplicate()
	focus.bg_color = Color.WHITE
	focus.border_color = Color("5fd02c")
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_color("font_color", "LineEdit", ink)
	for bar in ["VScrollBar", "HScrollBar"]:
		for part in ["scroll", "grabber", "grabber_highlight", "grabber_pressed", "scroll_focus"]:
			t.set_stylebox(part, bar, StyleBoxEmpty.new())
	t.set_constant("scrollbar_h_separation", "ScrollContainer", 0)
	t.set_constant("scrollbar_v_separation", "ScrollContainer", 0)
	var tip := StyleBoxFlat.new()
	tip.bg_color = Color(0.1, 0.05, 0.3, 0.92)
	tip.set_corner_radius_all(30)
	tip.set_content_margin_all(18)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", Color.WHITE)
	var err := ResourceSaver.save(t, OUT)
	print("saved %s (%s)" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


func _button(state: String) -> StyleBoxFlat:
	var base := Color("5fd02c")
	var edge := Color("2b8f12")
	if state == "disabled":
		base = Color("c9c5dc")
		edge = Color("8f8aa8")
	elif state == "hover":
		base = base.lightened(0.08)
	var s := StyleBoxFlat.new()
	s.bg_color = base
	s.set_corner_radius_all(40)
	s.border_color = edge
	s.set_border_width_all(5)
	s.border_width_bottom = 4 if state == "pressed" else 14
	s.set_content_margin_all(24)
	if state == "pressed":
		s.content_margin_top = 32
	s.shadow_color = Color(0.05, 0.02, 0.15, 0.28)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 8)
	if state == "focus":
		s.draw_center = false
		s.set_border_width_all(0)
		s.shadow_size = 0
	return s
