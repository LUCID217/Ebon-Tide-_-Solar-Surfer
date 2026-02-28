extends CanvasLayer

@onready var charge_bar: ProgressBar = $ChargeBar
@onready var charge_label: Label = $ChargeLabel
@onready var distance_label: Label = $DistanceLabel
@onready var coins_label: Label = $CoinsLabel
@onready var zone_label: Label = $ZoneLabel
@onready var speed_label: Label = $SpeedLabel
@onready var death_message: Label = $DeathMessage
@onready var restart_prompt: Label = $RestartPrompt
@onready var controls_hint: Label = $ControlsHint
@onready var near_miss_label: Label = $NearMissLabel
@onready var screen_flash: ColorRect = $ScreenFlash
@onready var run_summary: Control = $RunSummary
@onready var summary_distance: Label = $RunSummary/SummaryDistance
@onready var summary_coins: Label = $RunSummary/SummaryCoins
@onready var summary_tier: Label = $RunSummary/SummaryTier
@onready var summary_best: Label = $RunSummary/SummaryBest
@onready var damage_label: Label = $DamageLabel

# Boost touch indicator
var boost_icon: Control
var boost_label: Label
var boost_ring: ColorRect
var is_boost_active: bool = false

enum Zone { SHADOW, LIGHT, SUPER_LIGHT }

var speed_up_timer: float = 0.0
var near_miss_timer: float = 0.0
var warning_timer: float = 0.0
var damage_timer: float = 0.0
var flash_alpha: float = 0.0
var zone_label_tween: Tween = null

# Stats tracking
var current_distance: float = 0.0
var current_coins: int = 0
var current_tier: int = 0
var best_distance: float = 0.0

func _ready() -> void:
	death_message.visible = false
	restart_prompt.visible = false
	speed_label.visible = false
	near_miss_label.visible = false
	run_summary.visible = false
	damage_label.visible = false
	screen_flash.color = Color(1, 1, 1, 0)
	
	# Replace controls hint with now playing track info
	_update_now_playing()
	_create_skip_button()
	
	# Create boost touch indicator
	create_boost_indicator()
	
	# Load best distance from GameData (single source of truth)
	if Engine.has_singleton("GameData") or get_node_or_null("/root/GameData"):
		best_distance = GameData.best_distance

func _update_now_playing() -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and controls_hint:
		var track_name = audio_mgr.get_current_track_name()
		controls_hint.text = "~ Ebon Tide Original - " + track_name + " ~"
		controls_hint.add_theme_font_size_override("font_size", 14)
		controls_hint.add_theme_color_override("font_color", Color(0.92, 0.965, 1.0, 0.8))

var skip_button: Button

func _create_skip_button() -> void:
	skip_button = Button.new()
	skip_button.text = ">>"
	# Position right of the now-playing text (bottom center)
	skip_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skip_button.offset_left = 160.0   # Right of center text
	skip_button.offset_top = -45.0
	skip_button.offset_right = 260.0  # 100px wide (was 50px)
	skip_button.offset_bottom = -10.0 # 35px tall (was 30px)
	skip_button.add_theme_font_size_override("font_size", 28)  # Was 14 — 200% bigger
	skip_button.add_theme_color_override("font_color", Color(0.92, 0.965, 1.0, 0.8))
	skip_button.mouse_filter = Control.MOUSE_FILTER_STOP
	skip_button.focus_mode = Control.FOCUS_NONE
	
	# Subtle transparent style matching the now playing text
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.18, 0.3)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	skip_button.add_theme_stylebox_override("normal", style)
	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.12, 0.15, 0.25, 0.5)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(4)
	skip_button.add_theme_stylebox_override("hover", hover)
	skip_button.add_theme_stylebox_override("pressed", hover)
	
	skip_button.pressed.connect(_on_skip_track)
	add_child(skip_button)

func _on_skip_track() -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.rotate_track(2.0)
		# Small delay then update the label
		await get_tree().create_timer(0.1).timeout
		_update_now_playing()

func create_boost_indicator() -> void:
	# Container for boost icon - bottom right corner
	boost_icon = Control.new()
	boost_icon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	boost_icon.position = Vector2(-120, -120)
	boost_icon.size = Vector2(80, 80)
	add_child(boost_icon)
	
	# Outer ring/glow
	boost_ring = ColorRect.new()
	boost_ring.size = Vector2(80, 80)
	boost_ring.color = Color(0.12, 0.66, 0.83, 0.3)  # Teal Ion Glow, semi-transparent
	boost_icon.add_child(boost_ring)
	
	# Inner circle (darker)
	var inner = ColorRect.new()
	inner.size = Vector2(60, 60)
	inner.position = Vector2(10, 10)
	inner.color = Color(0.04, 0.07, 0.14, 0.5)
	boost_icon.add_child(inner)
	
	# Boost text
	boost_label = Label.new()
	boost_label.text = "HOLD\nBOOST"
	boost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boost_label.size = Vector2(80, 80)
	boost_label.add_theme_font_size_override("font_size", 12)
	boost_label.add_theme_color_override("font_color", Color(0.37, 0.91, 1.0, 0.8))
	boost_icon.add_child(boost_label)
	
	# Start semi-transparent
	boost_icon.modulate.a = 0.5

func _process(delta: float) -> void:
	if speed_up_timer > 0:
		speed_up_timer -= delta
		# Hold solid for 80% of duration, fade in final 20%
		speed_label.modulate.a = clamp(speed_up_timer / 0.6, 0.0, 1.0)
		if speed_up_timer <= 0:
			speed_label.visible = false
	
	if near_miss_timer > 0:
		near_miss_timer -= delta
		near_miss_label.modulate.a = clamp(near_miss_timer / 0.3, 0.0, 1.0)
		if near_miss_timer <= 0:
			near_miss_label.visible = false
	
	if damage_timer > 0:
		damage_timer -= delta
		# Hold fully opaque, only fade in the final 0.5s
		damage_label.modulate.a = clamp(damage_timer / 0.5, 0.0, 1.0)
		if damage_timer <= 0:
			damage_label.visible = false
	
	if warning_timer > 0:
		warning_timer -= delta
	
	if flash_alpha > 0:
		flash_alpha = max(0, flash_alpha - delta * 8.0)
		screen_flash.color.a = flash_alpha
	
	# Update boost indicator glow
	update_boost_indicator(delta)

func update_boost_indicator(_delta: float) -> void:
	if not boost_icon:
		return
	
	if is_boost_active:
		# Glowing when boosting
		boost_icon.modulate.a = 1.0
		boost_ring.color = Color(0.37, 0.91, 1.0, 0.8)
		boost_label.text = "BOOST\nACTIVE"
		boost_label.add_theme_color_override("font_color", Color(0.92, 0.965, 1.0, 1.0))
		# Pulse effect
		var pulse = sin(Time.get_ticks_msec() / 100.0) * 0.1 + 0.9
		boost_icon.scale = Vector2(pulse, pulse)
	else:
		# Dim when not boosting
		boost_icon.modulate.a = 0.4
		boost_ring.color = Color(0.12, 0.66, 0.83, 0.3)
		boost_label.text = "HOLD\nBOOST"
		boost_label.add_theme_color_override("font_color", Color(0.37, 0.91, 1.0, 0.6))
		boost_icon.scale = Vector2(1.0, 1.0)

func set_boost_active(active: bool) -> void:
	is_boost_active = active

func update_charge(value: float) -> void:
	charge_bar.value = value
	
	var style = charge_bar.get("theme_override_styles/fill")
	if style == null:
		style = StyleBoxFlat.new()
		charge_bar.add_theme_stylebox_override("fill", style)
	
	if value > 60:
		style.bg_color = Color(1.0, 0.85, 0.4)  # Solar Gold
	elif value > 30:
		style.bg_color = Color(1.0, 0.54, 0.12)  # Solar Amber
	else:
		style.bg_color = Color(0.77, 0.23, 0.11)  # Ember Red #C43A1C

func update_distance(value: float) -> void:
	current_distance = value
	distance_label.text = "Distance: " + str(int(value)) + "m"

func update_coins(value: int) -> void:
	current_coins = value
	coins_label.text = "Coins: " + str(value)
	
	var tween = create_tween()
	tween.tween_property(coins_label, "scale", Vector2(1.3, 1.3), 0.05)
	tween.tween_property(coins_label, "scale", Vector2(1.0, 1.0), 0.1)

func show_super_warning() -> void:
	warning_timer = 2.0
	
	zone_label.text = "⚠ SUPER LIGHT INCOMING ⚠"
	zone_label.modulate = Color(1.0, 0.78, 0.29)
	
	if zone_label_tween:
		zone_label_tween.kill()
	zone_label_tween = create_tween().set_loops(4)
	zone_label_tween.tween_property(zone_label, "modulate", Color(1.0, 0.85, 0.4), 0.25)
	zone_label_tween.tween_property(zone_label, "modulate", Color(1.0, 0.54, 0.12), 0.25)
	
	flash_alpha = 0.2
	screen_flash.color = Color(1.0, 0.78, 0.29, flash_alpha)

func update_zone(zone: int) -> void:
	if zone_label_tween:
		zone_label_tween.kill()
		zone_label_tween = null
	warning_timer = 0.0
	
	match zone:
		Zone.SHADOW:
			zone_label.text = "☾ SHADOW ZONE"
			zone_label.modulate = Color(0.24, 0.66, 1.0)  # Electric Blue
			flash_alpha = 0.15
			screen_flash.color = Color(0.067, 0.1, 0.23, flash_alpha)  # Abyss Blue
		Zone.LIGHT:
			zone_label.text = "☀ LIGHT ZONE"
			zone_label.modulate = Color(1.0, 0.85, 0.4)  # Solar Gold
			flash_alpha = 0.15
			screen_flash.color = Color(1.0, 0.85, 0.4, flash_alpha)
		Zone.SUPER_LIGHT:
			zone_label.text = "✦ SUPER LIGHT ✦"
			zone_label.modulate = Color(0.92, 0.965, 1.0)  # Cold Star White
			flash_alpha = 0.25
			screen_flash.color = Color(0.37, 0.91, 1.0, flash_alpha)  # Aurora Cyan
			zone_label_tween = create_tween().set_loops(0)
			zone_label_tween.tween_property(zone_label, "modulate", Color(0.37, 0.91, 1.0), 0.3)
			zone_label_tween.tween_property(zone_label, "modulate", Color(0.92, 0.965, 1.0), 0.3)

func show_speed_up(tier: int) -> void:
	current_tier = tier
	speed_label.text = "SPEED UP! (Tier " + str(tier) + ")"
	speed_label.visible = true
	speed_label.modulate = Color(1.0, 0.85, 0.4)
	speed_up_timer = 2.0
	
	var tween = create_tween()
	tween.tween_property(speed_label, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(speed_label, "scale", Vector2(1.0, 1.0), 0.2)

func show_near_miss() -> void:
	near_miss_label.visible = true
	near_miss_label.modulate.a = 1.0
	near_miss_timer = 1.0
	
	flash_alpha = 0.1
	
	var tween = create_tween()
	tween.tween_property(near_miss_label, "scale", Vector2(1.4, 1.4), 0.05)
	tween.tween_property(near_miss_label, "scale", Vector2(1.0, 1.0), 0.15)

func show_damage(level: int) -> void:
	damage_label.visible = true
	damage_label.modulate.a = 1.0
	damage_timer = 3.0
	
	match level:
		1:
			damage_label.text = "⚠ SAIL DESTROYED! ⚠\nNo charge regeneration!"
			damage_label.modulate = Color(1.0, 0.78, 0.29)  # Molten Core Gold
			flash_alpha = 0.3
			screen_flash.color = Color(1.0, 0.54, 0.12, flash_alpha)  # Solar Amber
		2:
			damage_label.text = "⚠ ENGINE DEAD! ⚠\nNo boost available!"
			damage_label.modulate = Color(0.77, 0.23, 0.11)  # Ember Red
			flash_alpha = 0.4
			screen_flash.color = Color(0.77, 0.23, 0.11, flash_alpha)
		3:
			damage_label.text = ""  # Death message handles this
	
	var tween = create_tween()
	tween.tween_property(damage_label, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(damage_label, "scale", Vector2(1.0, 1.0), 0.2)

func show_powerup(powerup_name: String, duration: float, color: Color) -> void:
	damage_label.visible = true
	damage_label.text = "✦ " + powerup_name + " ✦\n" + str(int(duration)) + " seconds"
	damage_label.modulate = color
	damage_label.modulate.a = 1.0
	damage_timer = 2.5
	
	var tween = create_tween()
	tween.tween_property(damage_label, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(damage_label, "scale", Vector2(1.0, 1.0), 0.15)

func show_shield_break() -> void:
	damage_label.visible = true
	damage_label.text = "⚡ SHIELD ABSORBED HIT! ⚡"
	damage_label.modulate = Color(0.37, 0.91, 1.0)  # Aurora Cyan
	damage_label.modulate.a = 1.0
	damage_timer = 2.5
	
	flash_alpha = 0.3
	screen_flash.color = Color(0.37, 0.91, 1.0, flash_alpha)
	
	var tween = create_tween()
	tween.tween_property(damage_label, "scale", Vector2(1.4, 1.4), 0.1)
	tween.tween_property(damage_label, "scale", Vector2(1.0, 1.0), 0.15)

func show_path_sight() -> void:
	damage_label.visible = true
	damage_label.text = "◇ SAW THE PATH ◇"
	damage_label.modulate = Color(0.4, 0.3, 0.7)  # Nebula Violet (brightened for readability)
	damage_label.modulate.a = 1.0
	damage_timer = 2.0
	
	flash_alpha = 0.2
	screen_flash.color = Color(0.3, 0.25, 0.5, flash_alpha)
	
	var tween = create_tween()
	tween.tween_property(damage_label, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(damage_label, "scale", Vector2(1.0, 1.0), 0.15)

func show_storm_warning() -> void:
	damage_label.visible = true
	damage_label.text = "☄ MICROMETEORITE STORM ☄"
	damage_label.modulate = Color(1.0, 0.54, 0.12)  # Solar Amber
	damage_label.modulate.a = 1.0
	damage_timer = 2.5
	
	flash_alpha = 0.15
	screen_flash.color = Color(1.0, 0.54, 0.12, flash_alpha)
	
	var tween = create_tween()
	tween.tween_property(damage_label, "scale", Vector2(1.5, 1.5), 0.15)
	tween.tween_property(damage_label, "scale", Vector2(1.0, 1.0), 0.2)

func show_repair(remaining_damage: int) -> void:
	damage_label.visible = true
	damage_label.modulate = Color(0.12, 0.79, 0.83)
	damage_label.modulate.a = 1.0
	damage_timer = 2.0
	
	if remaining_damage == 0:
		damage_label.text = "✦ FULLY REPAIRED! ✦"
	else:
		damage_label.text = "✦ REPAIR! ✦\nDamage remaining: " + str(remaining_damage)
	
	flash_alpha = 0.25
	screen_flash.color = Color(0.12, 0.79, 0.83, flash_alpha)
	
	var tween = create_tween()
	tween.tween_property(damage_label, "scale", Vector2(1.4, 1.4), 0.1)
	tween.tween_property(damage_label, "scale", Vector2(1.0, 1.0), 0.15)

func show_death_message() -> void:
	death_message.visible = true
	controls_hint.visible = false
	if skip_button:
		skip_button.visible = false
	
	if zone_label_tween:
		zone_label_tween.kill()
	
	screen_flash.color = Color(0.77, 0.23, 0.11, 0.4)
	flash_alpha = 0.4
	
	death_message.scale = Vector2(2.0, 2.0)
	var tween = create_tween()
	tween.tween_property(death_message, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Show run summary after a short delay
	await get_tree().create_timer(0.5).timeout
	show_run_summary()

func show_run_summary() -> void:
	# GameData.record_run() already tracks best — just read it
	if Engine.has_singleton("GameData") or get_node_or_null("/root/GameData"):
		best_distance = GameData.best_distance
	var is_new_best = current_distance > best_distance  # P2 fix: > not >= so equal runs don't falsely show NEW BEST
	
	# Populate summary
	summary_distance.text = "Distance: " + str(int(current_distance)) + "m"
	summary_coins.text = "Coins: " + str(current_coins)
	summary_tier.text = "Speed Tier: " + str(current_tier)
	
	if is_new_best:
		summary_best.text = "★ NEW BEST! ★"
		summary_best.modulate = Color(1.0, 0.85, 0.4)  # Solar Gold
	else:
		summary_best.text = "Best: " + str(int(best_distance)) + "m"
		summary_best.modulate = Color(0.7, 0.7, 0.7)
	
	run_summary.visible = true
	run_summary.modulate.a = 0.0
	
	# Fade in
	var tween = create_tween()
	tween.tween_property(run_summary, "modulate:a", 1.0, 0.3)

func show_restart_prompt() -> void:
	if restart_prompt.visible:
		return  # Already showing
	restart_prompt.visible = true
	_create_death_buttons()

# Touch-friendly death menu buttons
var play_again_btn: Button
var menu_btn: Button
var death_buttons_container: HBoxContainer

signal restart_requested
signal menu_requested

func _create_death_buttons() -> void:
	# Don't recreate if already built
	if death_buttons_container and is_instance_valid(death_buttons_container):
		death_buttons_container.visible = true
		return
	
	# Hide the old text prompt
	restart_prompt.text = ""
	
	# Container centered below run summary
	death_buttons_container = HBoxContainer.new()
	death_buttons_container.set_anchors_preset(Control.PRESET_CENTER)
	death_buttons_container.position = Vector2(-160, 180)
	death_buttons_container.size = Vector2(320, 60)
	death_buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	death_buttons_container.add_theme_constant_override("separation", 24)
	add_child(death_buttons_container)
	
	# Play Again button
	play_again_btn = Button.new()
	play_again_btn.text = "PLAY AGAIN"
	play_again_btn.custom_minimum_size = Vector2(140, 54)
	_style_death_button(play_again_btn, true)
	play_again_btn.pressed.connect(_on_play_again_pressed)
	death_buttons_container.add_child(play_again_btn)
	
	# Menu button
	menu_btn = Button.new()
	menu_btn.text = "MENU"
	menu_btn.custom_minimum_size = Vector2(140, 54)
	_style_death_button(menu_btn, false)
	menu_btn.pressed.connect(_on_menu_pressed)
	death_buttons_container.add_child(menu_btn)
	
	# Fade in
	death_buttons_container.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(death_buttons_container, "modulate:a", 1.0, 0.3)

func _style_death_button(btn: Button, is_primary: bool) -> void:
	# Use UITheme if available, otherwise fall back to inline styles
	var normal_style = StyleBoxFlat.new()
	var hover_style = StyleBoxFlat.new()
	var pressed_style = StyleBoxFlat.new()
	
	if is_primary:
		# Play Again — Solar Gold, draws the eye
		normal_style.bg_color = Color(1.0, 0.85, 0.4)  # Solar Gold
		hover_style.bg_color = Color(1.0, 0.9, 0.5)
		pressed_style.bg_color = Color(0.8, 0.65, 0.25)
	else:
		# Menu — cool indigo, secondary action
		normal_style.bg_color = Color(0.067, 0.1, 0.23)  # Abyss Blue
		hover_style.bg_color = Color(0.1, 0.14, 0.3)
		pressed_style.bg_color = Color(0.043, 0.063, 0.15)
	
	for style in [normal_style, hover_style, pressed_style]:
		style.set_corner_radius_all(10)
		style.set_border_width_all(2)
		style.border_color = Color(1, 1, 1, 0.15)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		style.shadow_color = Color(0, 0, 0, 0.3)
		style.shadow_size = 4
		style.shadow_offset = Vector2(0, 2)
	
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus", hover_style)
	
	# Text styling
	var text_color = Color(0.05, 0.05, 0.08) if is_primary else Color(0.9, 0.9, 0.9)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color)
	btn.add_theme_font_size_override("font_size", 18)

func _on_play_again_pressed() -> void:
	emit_signal("restart_requested")

func _on_menu_pressed() -> void:
	emit_signal("menu_requested")

func hide_death_ui() -> void:
	death_message.visible = false
	restart_prompt.visible = false
	run_summary.visible = false
	damage_label.visible = false
	controls_hint.visible = true
	if skip_button:
		skip_button.visible = true
	_update_now_playing()
	speed_label.visible = false
	near_miss_label.visible = false
	current_tier = 0
	
	# Hide death buttons
	if death_buttons_container and is_instance_valid(death_buttons_container):
		death_buttons_container.visible = false

