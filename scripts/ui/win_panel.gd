class_name WinPanel
extends Control
## LEVEL COMPLETE: the star flies to the star counter, coins count up and
## fly to the coin counter, optional x2 coins via rewarded ad (once), and a
## big CONTINUE straight to the next level. "Home" lights up when a
## renovation task is affordable; after level 3 CONTINUE becomes "Renovate!".

signal continue_pressed
signal home_pressed

var level := 1
var summary: Dictionary = {}
var coins_shown := 0
var doubled := false
var double_button: GameButton
var continue_button: GameButton
var coin_chip: CoinChip
var star_chip: StarChip
var home_button: GameButton
var renovate := false

var _count_label: Label
var _star_label: Label
var _star_icon: IconView


func setup(level_value: int, summary_value: Dictionary, renovate_next: bool = false) -> void:
	level = level_value
	summary = summary_value
	renovate = renovate_next


func _ready() -> void:
	set_meta("popup_id", "win")
	var v := UIKit.modal_frame(self, 900, "LEVEL COMPLETE")
	_add_sunburst()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.add_child(UIKit.hspacer())
	star_chip = StarChip.new()
	top.add_child(star_chip)
	coin_chip = CoinChip.new()
	coin_chip.show_plus = false
	top.add_child(coin_chip)
	v.add_child(top)
	var daily := bool(summary.get("daily", false))
	var sub := HBoxContainer.new()
	sub.alignment = BoxContainer.ALIGNMENT_CENTER
	sub.add_theme_constant_override("separation", 16)
	sub.add_child(UIKit.label(tr("Daily Challenge") if daily else tr("Level %d") % level, 44, UIKit.INK_SOFT))
	var badge := UIKit.tier_badge(String(summary.get("tier", "normal")), 30)
	if badge:
		sub.add_child(badge)
	v.add_child(sub)
	var reward_row := HBoxContainer.new()
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_row.add_theme_constant_override("separation", 18)
	_star_icon = UIKit.icon("star", 120, UIKit.GOLD)
	_star_icon.shadow = true
	_star_icon.shadow_color = Color("9c4a00")
	reward_row.add_child(_star_icon)
	_star_label = UIKit.title("+%d" % int(summary.get("stars", 1)), 110, Color("ffd23f"), HORIZONTAL_ALIGNMENT_CENTER, Color("8a4100"))
	reward_row.add_child(_star_label)
	reward_row.add_child(UIKit.hspacer(30))
	if daily:
		_star_icon.visible = false
		_star_label.visible = false
		star_chip.visible = false
	reward_row.add_child(UIKit.icon("coin", 120))
	_count_label = UIKit.title("+0", 110, Color("ffd23f"), HORIZONTAL_ALIGNMENT_CENTER, Color("8a4100"))
	reward_row.add_child(_count_label)
	v.add_child(reward_row)
	double_button = UIKit.button("x2 COINS", "purple", "ad", 52)
	double_button.pressed.connect(_on_double)
	v.add_child(double_button)
	if daily:
		v.add_child(UIKit.label(tr("Challenge streak: %d days") % int(summary.get("streak", 1)), 40, UIKit.PINK_EDGE))
	var extras := HBoxContainer.new()
	extras.alignment = BoxContainer.ALIGNMENT_CENTER
	extras.add_theme_constant_override("separation", 26)
	if int(summary.get("event", 0)) > 0:
		var er := HBoxContainer.new()
		er.add_child(UIKit.icon(EventManager.currency_icon(), 64, UIKit.SECONDARY))
		er.add_child(UIKit.label("+%d %s" % [int(summary["event"]), EventManager.currency_name()], 36, UIKit.SECONDARY_EDGE))
		extras.add_child(er)
	if int(summary.get("order_bonus", 0)) > 0:
		var orr := HBoxContainer.new()
		orr.add_child(UIKit.icon("order", 56, UIKit.PURPLE))
		orr.add_child(UIKit.label(tr("Orders +%d coins") % int(summary["order_bonus"]), 32, UIKit.PURPLE_EDGE))
		extras.add_child(orr)
	if RaceManager.block().get("state", "") == "running":
		var rr := HBoxContainer.new()
		rr.add_child(UIKit.icon("race", 56, Color("ff7a3d")))
		rr.add_child(UIKit.label(tr("Race %d/%d") % [RaceManager.player_wins(), RaceManager.goal()], 32, Color("cc4a10")))
		extras.add_child(rr)
	if extras.get_child_count() > 0:
		v.add_child(extras)
	continue_button = UIKit.button(tr("Renovate!") if renovate else (tr("HOME") if daily else tr("CONTINUE")), "primary", "brush" if renovate else ("home" if daily else "play"), 70, Vector2(0, 190))
	continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	v.add_child(continue_button)
	var can_renovate := RenovationManager.affordable_count() > 0 and not renovate and not daily
	home_button = UIKit.button(tr("You can renovate!") if can_renovate else tr("Home"), "gold" if can_renovate else "neutral", "brush" if can_renovate else "home", 40, Vector2(0, 120))
	home_button.pressed.connect(func() -> void: home_pressed.emit())
	v.add_child(home_button)
	if can_renovate:
		UIKit.pulse.call_deferred(home_button, 1.04, 1.0)
	if renovate:
		UIKit.pulse.call_deferred(continue_button, 1.05, 1.0)
	# The chips start at the old balances, then count up as rewards land.
	var reward := int(summary.get("coins", 0))
	coin_chip.display(CurrencyManager.get_coins() - reward)
	star_chip.display(CurrencyManager.get_stars() - int(summary.get("stars", 1)))
	if daily:
		home_button.visible = false
	_count_up.call_deferred(reward)
	_fly_star.call_deferred()


## Slowly turning golden rays behind the panel.
func _add_sunburst() -> void:
	var vp := get_viewport_rect().size
	var rays := Node2D.new()
	rays.position = vp * 0.5 - Vector2(0, 120)
	rays.draw.connect(func() -> void:
		var n := 16
		for i in n:
			var a0 := TAU * i / n
			var a1 := a0 + TAU / n * 0.5
			rays.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(cos(a0), sin(a0)) * 1400.0, Vector2(cos(a1), sin(a1)) * 1400.0]), Color(1.0, 0.85, 0.3, 0.16))
		for k in 4:
			rays.draw_circle(Vector2.ZERO, 360.0 - k * 70.0, Color(1.0, 0.9, 0.5, 0.06), true, -1.0, true))
	add_child(rays)
	move_child(rays, 1)  # above the dim, below the panel
	var tw := rays.create_tween().set_loops()
	tw.tween_property(rays, "rotation", TAU, 24.0).from(0.0)


## The level's star flies from the reward row to the star counter.
func _fly_star() -> void:
	var stars := int(summary.get("stars", 1))
	if stars <= 0:
		return
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void:
		VFXManager.star_fly(_star_icon.get_global_rect().get_center(), star_chip.icon_global_center(), stars, _on_star_landed))


func _on_star_landed() -> void:
	star_chip.display(CurrencyManager.get_stars())
	UIKit.bounce(star_chip, 1.12)


func _count_up(reward: int) -> void:
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_method(_show_count, 0.0, float(reward), 0.6)
	tw.tween_callback(func() -> void:
		AudioManager.play("coin_pickup")
		_fly_coins(reward))


func _show_count(v: float) -> void:
	coins_shown = int(v)
	_count_label.text = "+%d" % coins_shown


var _fly_before := 0
var _fly_amount := 0
var _fly_count := 1
var _fly_landed := 0


func _fly_coins(amount: int) -> void:
	var from := _count_label.get_global_rect().get_center()
	var to := coin_chip.icon_global_center()
	_fly_count = clampi(amount / 2, 5, 12)
	_fly_before = CurrencyManager.get_coins() - amount
	_fly_amount = amount
	_fly_landed = 0
	# A bound method (not a lambda) stops being called once the panel is gone.
	VFXManager.coin_fly(from, to, _fly_count, _on_coin_landed)


func _on_coin_landed() -> void:
	_fly_landed += 1
	coin_chip.display(_fly_before + int(round(float(_fly_amount) * _fly_landed / _fly_count)))
	UIKit.bounce(coin_chip, 1.06)


func _on_double() -> void:
	if doubled:
		return
	double_button.disabled = true
	AdManager.show_rewarded_double_reward(func(ok: bool) -> void:
		if not ok:
			double_button.disabled = false
			VFXManager.toast("Ad not available right now")
			return
		doubled = true
		var extra := int(summary.get("coins", 0))
		CurrencyManager.add_coins(extra)
		_count_label.text = "+%d" % (extra * 2)
		UIKit.bounce(_count_label, 1.3)
		double_button.set_label("Coins doubled!")
		_fly_coins(extra))


func on_back() -> void:
	home_pressed.emit()
