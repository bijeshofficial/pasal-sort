class_name UIKit
extends RefCounted
## Game-style UI kit: a bright candy palette, a chunky display font with
## outlined text, glossy 3D buttons and panels with ribbon titles.

# Text on light panels.
const INK := Color("2b1f63")
const INK_SOFT := Color("6b5fa8")
# Dark outline used under white game text.
const OUTLINE := Color("26165e")
# Panel body (top -> bottom) and lines.
const PAPER := Color("fdfcff")
const PAPER_DARK := Color("e7e1ff")
const LINE := Color("cbc2ff")
const PANEL_EDGE := Color("5a45d8")
# Button colours.
const PRIMARY := Color("5fd02c")        # green: play / continue / confirm
const PRIMARY_EDGE := Color("2b8f12")
const SECONDARY := Color("2f9bff")      # blue
const SECONDARY_EDGE := Color("1756c8")
const GOLD := Color("ffc61f")
const GOLD_EDGE := Color("e27a00")
const NEUTRAL := Color("f3f1ff")
const NEUTRAL_EDGE := Color("9d93dc")
const DANGER := Color("ff4f5e")
const DANGER_EDGE := Color("c41c35")
const PURPLE := Color("a35cff")
const PURPLE_EDGE := Color("6a2ad2")
const PINK := Color("ff4fa3")
const PINK_EDGE := Color("c7177a")
const DISABLED := Color("c9c5dc")
const DISABLED_EDGE := Color("8f8aa8")
const DIM := Color(0.06, 0.03, 0.18, 0.68)
const HEART := Color("ff3b5c")
# Warm wood is only for the illustrated shop, never for UI chrome.
const WOOD := Color("c47a45")
const WOOD_DARK := Color("8a4b28")
const WOOD_LIGHT := Color("e29a5c")

const TIER_COLORS := {
	"hard": Color("ff8a1f"),
	"super": Color("ff3b5c"),
}

## kind -> [base, edge, text colour, text outline]
const BUTTON_KINDS := {
	"primary": [PRIMARY, PRIMARY_EDGE, Color.WHITE, Color("1d6608")],
	"secondary": [SECONDARY, SECONDARY_EDGE, Color.WHITE, Color("0f3a94")],
	"gold": [GOLD, GOLD_EDGE, Color.WHITE, Color("9c4a00")],
	"neutral": [NEUTRAL, NEUTRAL_EDGE, INK, Color(0, 0, 0, 0)],
	"paper": [NEUTRAL, NEUTRAL_EDGE, INK, Color(0, 0, 0, 0)],
	"danger": [DANGER, DANGER_EDGE, Color.WHITE, Color("870b20")],
	"purple": [PURPLE, PURPLE_EDGE, Color.WHITE, Color("4a1699")],
	"pink": [PINK, PINK_EDGE, Color.WHITE, Color("8a0d52")],
}

static var _fonts: Dictionary = {}


## heavy = the chunky display face (titles, buttons, numbers);
## otherwise a rounded bold body face.
static func font(heavy: bool = true) -> Font:
	var key := "heavy" if heavy else "regular"
	if _fonts.has(key):
		return _fonts[key]
	var f: Font
	if heavy:
		var ff: FontFile = load("res://assets/fonts/LilitaOne-Regular.ttf")
		f = ff
	else:
		var fv := FontVariation.new()
		fv.base_font = load("res://assets/fonts/Baloo2-Variable.ttf")
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
		f = fv
	_fonts[key] = f
	return f


static func label(text: String, size: int = 44, color: Color = INK, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, heavy: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(heavy))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## White game title: thick dark outline and a drop shadow.
static func title(text: String, size: int = 64, color: Color = Color.WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, outline: Color = OUTLINE) -> Label:
	var l := label(text, size, color, align, true)
	game_text(l, outline, size)
	return l


static func game_text(l: Label, outline: Color, size: int) -> Label:
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", maxi(6, int(size * 0.22)))
	l.add_theme_color_override("font_shadow_color", Color(outline, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(3, int(size * 0.09)))
	l.add_theme_constant_override("shadow_outline_size", maxi(6, int(size * 0.22)))
	return l


## Kept for older call sites: outline size here is the old pixel width.
static func outlined(l: Label, outline: Color, size: int) -> Label:
	return game_text(l, outline, size * 4)


static func box(fill: Color, radius: float = 40.0, edge: Color = Color.TRANSPARENT, edge_width: int = 0, margin: float = 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(int(radius))
	s.corner_detail = 10
	s.anti_aliasing = true
	if edge_width > 0:
		s.border_color = edge
		s.border_width_bottom = edge_width
	s.set_content_margin_all(margin)
	return s


## Light card with an outline all round and a thicker 3D bottom edge.
static func card_box(fill: Color = PAPER, margin: float = 24.0, edge: Color = LINE) -> StyleBoxFlat:
	var s := box(fill, 36, edge, 0, margin)
	s.border_color = edge.darkened(0.12)
	s.set_border_width_all(5)
	s.border_width_bottom = 12
	return s


## Dark translucent pill (currency chips, HUD info).
static func chip_box(margin: float = 12.0) -> StyleBoxFlat:
	var s := box(Color(0.08, 0.04, 0.24, 0.6), 60, Color.TRANSPARENT, 0, margin)
	s.border_color = Color(1, 1, 1, 0.25)
	s.set_border_width_all(4)
	return s


## Glossy panel (popups): thick indigo frame, gradient body, inner highlight.
static func panel(fill: Color = PAPER, radius: float = 56.0, margin: float = 44.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(margin)
	p.add_theme_stylebox_override("panel", sb)
	p.draw.connect(func() -> void: draw_panel(p, Rect2(Vector2.ZERO, p.size), radius, fill))
	return p


static func draw_panel(ci: CanvasItem, rect: Rect2, radius: float, fill: Color = PAPER) -> void:
	ci.draw_colored_polygon(DrawKit.rounded_rect(Rect2(rect.position + Vector2(0, 14), rect.size), radius, 10), Color(0.04, 0.01, 0.15, 0.35))
	var outer := DrawKit.rounded_rect(rect, radius, 10)
	ci.draw_colored_polygon(outer, PANEL_EDGE.darkened(0.4))
	DrawKit.aa_rim(ci, outer, PANEL_EDGE.darkened(0.4))
	ci.draw_colored_polygon(DrawKit.rounded_rect(rect.grow(-6), radius - 6, 10), PANEL_EDGE)
	var body := rect.grow(-16)
	DrawKit.gradient_fill(ci, DrawKit.rounded_rect(body, radius - 16, 10), fill, fill.lerp(PAPER_DARK, 0.85))
	DrawKit.outline(ci, DrawKit.rounded_rect(body.grow(-5), radius - 21, 10), Color(1, 1, 1, 0.9), 3.0)


static func button(text: String, kind: String = "primary", icon: String = "", font_size: int = 52, min_size: Vector2 = Vector2(0, 150)) -> GameButton:
	var b := GameButton.new()
	b.setup(text, kind, icon, font_size, min_size)
	return b


## Game-styled horizontal slider (0..1): dark track, green fill, glossy knob.
static func slider(value: float) -> HSlider:
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.01
	sl.value = value
	sl.focus_mode = Control.FOCUS_NONE
	sl.custom_minimum_size = Vector2(0, 80)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track := box(Color(INK, 0.18), 16, Color.TRANSPARENT, 0, 0)
	track.content_margin_top = 13
	track.content_margin_bottom = 13
	track.border_color = Color(INK, 0.25)
	track.set_border_width_all(3)
	var fill := box(PRIMARY, 16, Color.TRANSPARENT, 0, 0)
	fill.content_margin_top = 13
	fill.content_margin_bottom = 13
	fill.border_color = PRIMARY_EDGE
	fill.set_border_width_all(3)
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob_texture()
	sl.add_theme_icon_override("grabber", knob)
	sl.add_theme_icon_override("grabber_highlight", knob)
	return sl


static func _knob_texture() -> Texture2D:
	if _fonts.has("knob"):
		return _fonts["knob"]
	var d := 64
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d * 0.5, d * 0.5)
	for y in d:
		for x in d:
			var p := Vector2(x + 0.5, y + 0.5)
			var r := p.distance_to(c)
			var col := Color(0, 0, 0, 0)
			if r <= 30.0:
				col = PANEL_EDGE.darkened(0.3)
			if r <= 25.0:
				# White knob, a touch darker at the bottom, glossy at the top.
				col = Color.WHITE.lerp(Color("d9d2ff"), clampf((p.y - c.y + 25.0) / 50.0, 0.0, 1.0))
				if p.distance_to(c - Vector2(5, 9)) < 9.0:
					col = Color.WHITE
			col.a *= clampf(31.0 - r, 0.0, 1.0)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_fonts["knob"] = tex
	return tex


## Round red close button.
static func close_button(size: float = 110.0) -> GameButton:
	return button("", "danger", "close", int(size * 0.36), Vector2(size, size))


static func icon(name: String, size: float = 64.0, color: Color = INK) -> IconView:
	var i := IconView.new()
	i.icon = name
	i.color = color
	i.custom_minimum_size = Vector2(size, size)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


## Glossy round disk with an icon (popup art, achievement medals).
static func disk(icon_name: String, size: float = 220.0, base: Color = SECONDARY, edge: Color = SECONDARY_EDGE, icon_color: Color = Color.WHITE) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void: DrawKit.glossy_circle(c, c.size * 0.5, size * 0.5 - 6, base, edge, 7.0, 10.0))
	var ic := icon(icon_name, size * 0.54, icon_color)
	ic.shadow = icon_color == Color.WHITE
	ic.accent = base
	ic.position = Vector2(size * 0.23, size * 0.2)
	ic.size = Vector2(size * 0.54, size * 0.54)
	c.add_child(ic)
	return c


static func spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func hspacer(width: float = 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 0)
	if width == 0.0:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## A ribbon banner with a title (popup headers, LEVEL COMPLETE).
static func ribbon(text: String, width: float, color: Color = PINK, edge: Color = PINK_EDGE, font_size: int = 60) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 150)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.z_index = 2
	c.draw.connect(func() -> void:
		var w := c.size.x
		var h := 118.0
		var y := 10.0
		# Folded tails behind the band.
		for s in [-1.0, 1.0]:
			var x_out: float = w * 0.5 + s * (w * 0.5)
			var x_in: float = w * 0.5 + s * (w * 0.5 - 120)
			var tail := PackedVector2Array([
				Vector2(x_in, y + 34), Vector2(x_out, y + 34),
				Vector2(x_out - s * 34, y + 34 + (h - 6) * 0.45),
				Vector2(x_out, y + h + 14), Vector2(x_in, y + h + 14)])
			c.draw_colored_polygon(tail, edge.darkened(0.45))
			var inner := PackedVector2Array([
				Vector2(x_in, y + 41), Vector2(x_out - s * 6, y + 41),
				Vector2(x_out - s * 37, y + 34 + (h - 6) * 0.45),
				Vector2(x_out - s * 6, y + h + 7), Vector2(x_in, y + h + 7)])
			c.draw_colored_polygon(inner, edge)
		DrawKit.glossy_rrect(c, Rect2(74, y, w - 148, h), 30, color, edge, 0.0, 6.0, 10.0, true))
	# Shrink long titles to fit the band.
	var fs := font_size
	var room := width - 148.0 - 70.0
	while fs > 30 and font(true).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 2
	var l := title(text, fs)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.offset_top = 6
	l.offset_bottom = -30
	c.add_child(l)
	c.set_meta("label", l)
	return c


## Full-rect dimmed overlay with a centred glossy panel. With a title, a
## ribbon sits across the top of the panel. Returns the panel's VBox.
static func modal_frame(root: Control, width: float = 900.0, title_text: String = "") -> VBoxContainer:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", -80)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(stack)
	var p := panel(PAPER, 56.0, 46.0)
	p.name = "Panel"
	p.custom_minimum_size = Vector2(width, 0)
	if title_text != "":
		var rib := ribbon(title_text, width * 0.9)
		rib.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(rib)
		root.set_meta("ribbon", rib)
		(p.get_theme_stylebox("panel") as StyleBoxEmpty).content_margin_top = 100
	stack.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 26)
	p.add_child(v)
	root.set_meta("panel", p)
	pop_in(stack)
	return v


## Places a round close button on the panel's top-right corner.
static func attach_close(root: Control, on_close: Callable) -> GameButton:
	var p: Control = root.get_meta("panel")
	var b := close_button(112)
	b.z_index = 5
	root.add_child(b)
	# The button keeps itself on the panel's corner (see GameButton._process).
	b.follow = p
	b.follow_offset = Vector2(-88, -28)
	b.pressed.connect(on_close)
	return b


## Pops a panel in. The tween belongs to the panel, so nothing runs if the
## panel is closed in the same frame.
static func pop_in(c: Control) -> void:
	c.modulate.a = 0.0
	c.scale = Vector2(0.8, 0.8)
	var tw := c.create_tween()
	tw.tween_callback(func() -> void: c.pivot_offset = c.size * 0.5)
	tw.tween_property(c, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(c, "modulate:a", 1.0, 0.14)


static func bounce(c: CanvasItem, amount: float = 1.18, duration: float = 0.22) -> void:
	if not is_instance_valid(c):
		return
	if c is Control:
		(c as Control).pivot_offset = (c as Control).size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(amount, amount), duration * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, duration * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Glossy pill badge ("HARD", "SUPER HARD", counts).
static func badge(text: String, fill: Color, size: int = 30, fg: Color = Color.WHITE) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(fill, 40, Color.TRANSPARENT, 0, 0)
	sb.border_color = fill.darkened(0.45)
	sb.set_border_width_all(4)
	sb.border_width_bottom = 8
	sb.content_margin_left = size * 0.7
	sb.content_margin_right = size * 0.7
	sb.content_margin_top = size * 0.12
	sb.content_margin_bottom = size * 0.12
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(title(text, size, fg, HORIZONTAL_ALIGNMENT_CENTER, fill.darkened(0.55)))
	return p


## Tier badge for a level ("" -> null).
static func tier_badge(tier: String, size: int = 30) -> PanelContainer:
	var text := ProgressionManager.tier_label(tier)
	if text == "":
		return null
	return badge(text, TIER_COLORS.get(tier, PRIMARY), size)


## Red notification dot.
static func red_dot(size: float = 34.0) -> Control:
	var d := Control.new()
	d.custom_minimum_size = Vector2(size, size)
	d.size = Vector2(size, size)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.draw.connect(func() -> void:
		d.draw_circle(d.size * 0.5, size * 0.5, Color.WHITE, true, -1.0, true)
		d.draw_circle(d.size * 0.5, size * 0.5 - 4, HEART, true, -1.0, true)
		d.draw_circle(d.size * 0.5 - Vector2(size * 0.12, size * 0.14), size * 0.1, Color(1, 1, 1, 0.8), true, -1.0, true))
	return d


static func pulse(c: CanvasItem, amount: float = 1.1, period: float = 0.9) -> Tween:
	if c is Control:
		(c as Control).pivot_offset = (c as Control).size * 0.5
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "scale", Vector2(amount, amount), period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw


static func safe_top() -> float:
	return GameManager.get_safe_insets().x


static func safe_bottom() -> float:
	return GameManager.get_safe_insets().y
