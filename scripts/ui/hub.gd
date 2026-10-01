class_name Hub
extends Control
## Hub screen: top bar (lives, coins, stars, settings), three pages (Shop |
## Home | Profile) that slide horizontally, and the bottom navigation. Home
## is the renovation scene, drawn full-screen behind the bars; it slides with
## the Home page. Swipe left/right (on Home: on the nav bar, since dragging
## the scene pans it) or tap a tab. Back: other tab -> Home; Home -> quit.

const TAB_NAMES := ["shop", "home", "profile"]

var current := 1
var pages: Array[Control] = []
var home: HomePage
var shop: ShopPage
var profile: ProfilePage
var nav: BottomNav
var coin_chip: CoinChip
var star_chip: StarChip
var lives_chip: LivesChip
var backdrop: ShopBackdrop
var home_view: HomeView

var _page_area: Control
var _swipe_start := Vector2.ZERO
var _swipe_time := 0
var _swiping := false


func _ready() -> void:
	VFXManager.toast_anchor = "top"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop = ShopBackdrop.new()
	backdrop.theme_id = ProgressionManager.selected_cosmetic("theme")
	backdrop.horizon = 0.62
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	home_view = HomeView.new()
	home_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(home_view)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top bar inside the safe area.
	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", int(UIKit.safe_top()) + 24)
	top.add_theme_constant_override("margin_left", 30)
	top.add_theme_constant_override("margin_right", 30)
	top.add_theme_constant_override("margin_bottom", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(bar)
	lives_chip = LivesChip.new()
	bar.add_child(lives_chip)
	bar.add_child(UIKit.hspacer())
	coin_chip = CoinChip.new()
	coin_chip.plus_pressed.connect(func() -> void: select_tab(0))
	bar.add_child(coin_chip)
	star_chip = StarChip.new()
	star_chip.pressed.connect(func() -> void:
		select_tab(1)
		home.open_tasks())
	bar.add_child(star_chip)
	var gear := UIKit.button("", "secondary", "gear", 50, Vector2(112, 112))
	gear.pressed.connect(open_settings)
	bar.add_child(gear)

	_page_area = Control.new()
	_page_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_area.clip_contents = true
	_page_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_page_area)
	shop = ShopPage.new()
	home = HomePage.new()
	profile = ProfilePage.new()
	pages = [shop, home, profile]
	for p in pages:
		_page_area.add_child(p)
	_page_area.resized.connect(_place_pages)

	nav = BottomNav.new()
	nav.tab_selected.connect(select_tab)
	root.add_child(nav)

	shop.changed.connect(_refresh_dots)
	profile.changed.connect(_refresh_dots)
	AchievementManager.claimable_changed.connect(_on_claimable_changed)
	ProgressionManager.cosmetic_changed.connect(_on_cosmetic_changed)
	SaveManager.progress_reset.connect(_rebuild)

	current = maxi(0, TAB_NAMES.find(ScreenManager.hub_tab))
	nav.select(current, false)
	home.attach_view(home_view, self)
	_place_pages()
	_refresh_dots()
	AdManager.banner_opportunity("hub")
	# Prepare the next level while the player looks around.
	ProgressionManager.prefetch(ProgressionManager.current_level())
	if current == 1:
		home.on_shown.call_deferred()


func _on_claimable_changed(_n: int) -> void:
	_refresh_dots()


func _on_cosmetic_changed(_c: String, _i: String) -> void:
	home.refresh()
	backdrop.theme_id = ProgressionManager.selected_cosmetic("theme")


func _rebuild() -> void:
	home.back_to_current()
	shop.build()
	profile.build()
	_refresh_dots()


func _refresh_dots() -> void:
	nav.set_dot(0, ShopPage.daily_available())
	nav.set_dot(2, AchievementManager.claimable_count() > 0)


func _place_pages(animate: bool = false) -> void:
	var w := _page_area.size.x
	for i in pages.size():
		var p := pages[i]
		p.size = _page_area.size
		var target := Vector2((i - current) * w, 0)
		if animate:
			var tw := p.create_tween()
			tw.tween_property(p, "position", target, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			if p == home:
				tw.parallel().tween_property(home_view, "position:x", target.x, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			p.position = target
			if p == home:
				home_view.position.x = target.x


func select_tab(index: int) -> void:
	index = clampi(index, 0, pages.size() - 1)
	if index == current:
		return
	current = index
	ScreenManager.hub_tab = TAB_NAMES[index]
	nav.select(index)
	_place_pages(true)
	match index:
		0:
			shop._refresh_buttons()
		1:
			home.on_shown()
		2:
			profile.build()
	_refresh_dots()


func open_settings() -> void:
	ScreenManager.push_modal(load("res://scenes/ui/settings.tscn").instantiate())


## Horizontal swipe between tabs (does not consume the event, so vertical
## scrolling and button taps keep working).
func _input(event: InputEvent) -> void:
	if ScreenManager.has_modal() or ScreenManager.is_busy():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_start = event.position
			_swipe_time = Time.get_ticks_msec()
			# On Home a drag pans the scene; only the nav bar swipes tabs.
			_swiping = current != 1 or nav.get_global_rect().has_point(event.position)
		elif _swiping:
			_swiping = false
			var d: Vector2 = event.position - _swipe_start
			var dt := Time.get_ticks_msec() - _swipe_time
			if absf(d.x) > 170.0 and absf(d.x) > absf(d.y) * 1.6 and dt < 700:
				select_tab(current + (1 if d.x < 0 else -1))


func on_back() -> void:
	if current != 1:
		select_tab(1)
		return
	Popups.confirm("Leave the pasal?", "Your progress is saved.", "Quit", func() -> void: GameManager.quit_game(), "danger", "Stay")
