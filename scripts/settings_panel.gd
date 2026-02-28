extends CanvasLayer

# SettingsPanel - Overlay panel for game settings
# Shows/hides on top of whatever screen is active

signal closed

var panel: PanelContainer
var is_open: bool = false

# UI references
var music_slider: HSlider
var sfx_slider: HSlider
var shake_toggle: CheckButton
var haptic_toggle: CheckButton
var quality_option: OptionButton
var track_label: Label

func _ready() -> void:
	layer = 50  # Above most UI, below debug
	_build_ui()
	visible = false

func _build_ui() -> void:
	# Dark overlay background
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks to things behind
	add_child(overlay)
	
	# Center panel
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -180
	panel.offset_right = 180
	panel.offset_top = -220
	panel.offset_bottom = 220
	
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.95)
	style.border_color = Color(0.3, 0.5, 0.7, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
	vbox.add_child(title)
	
	# Separator
	var sep1 = HSeparator.new()
	sep1.add_theme_constant_override("separation", 8)
	vbox.add_child(sep1)
	
	# === MUSIC VOLUME ===
	var music_row = _create_label("Music Volume")
	vbox.add_child(music_row)
	
	var music_hbox = HBoxContainer.new()
	music_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(music_hbox)
	
	music_slider = HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.value = GameData.music_volume
	music_slider.custom_minimum_size = Vector2(280, 30)
	music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_slider.value_changed.connect(_on_music_volume_changed)
	music_hbox.add_child(music_slider)
	
	# Now Playing label
	track_label = Label.new()
	track_label.add_theme_font_size_override("font_size", 11)
	track_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	track_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_track_label()
	vbox.add_child(track_label)
	
	# === SFX VOLUME ===
	var sfx_row = _create_label("SFX Volume")
	vbox.add_child(sfx_row)
	
	var sfx_hbox = HBoxContainer.new()
	sfx_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(sfx_hbox)
	
	sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = GameData.sfx_volume
	sfx_slider.custom_minimum_size = Vector2(280, 30)
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	sfx_hbox.add_child(sfx_slider)
	
	var sep2 = HSeparator.new()
	sep2.add_theme_constant_override("separation", 8)
	vbox.add_child(sep2)
	
	# === SCREEN SHAKE ===
	shake_toggle = CheckButton.new()
	shake_toggle.text = "Screen Shake"
	shake_toggle.button_pressed = GameData.screen_shake
	shake_toggle.add_theme_font_size_override("font_size", 16)
	shake_toggle.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	shake_toggle.toggled.connect(_on_shake_toggled)
	vbox.add_child(shake_toggle)
	
	# === HAPTIC FEEDBACK ===
	haptic_toggle = CheckButton.new()
	haptic_toggle.text = "Haptic Feedback"
	haptic_toggle.button_pressed = GameData.haptic_feedback
	haptic_toggle.add_theme_font_size_override("font_size", 16)
	haptic_toggle.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	haptic_toggle.toggled.connect(_on_haptic_toggled)
	vbox.add_child(haptic_toggle)
	
	# === GRAPHICS QUALITY ===
	var quality_row = _create_label("Graphics Quality")
	vbox.add_child(quality_row)
	
	quality_option = OptionButton.new()
	quality_option.add_item("Low", 0)
	quality_option.add_item("Medium", 1)
	quality_option.add_item("High", 2)
	quality_option.selected = GameData.graphics_quality
	quality_option.custom_minimum_size = Vector2(280, 36)
	quality_option.add_theme_font_size_override("font_size", 16)
	quality_option.item_selected.connect(_on_quality_changed)
	vbox.add_child(quality_option)
	
	var sep3 = HSeparator.new()
	sep3.add_theme_constant_override("separation", 8)
	vbox.add_child(sep3)
	
	# === CLOSE BUTTON ===
	var close_btn = Button.new()
	close_btn.text = "DONE"
	close_btn.custom_minimum_size = Vector2(280, 48)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(close)
	vbox.add_child(close_btn)

func _create_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	return label

func _update_track_label() -> void:
	if track_label and is_instance_valid(track_label):
		var mgr = get_node_or_null("/root/AudioManager")
		if mgr:
			track_label.text = "Now Playing: " + mgr.get_current_track_name()
		else:
			track_label.text = ""

func open() -> void:
	# Refresh values from GameData
	if music_slider:
		music_slider.value = GameData.music_volume
	if sfx_slider:
		sfx_slider.value = GameData.sfx_volume
	if shake_toggle:
		shake_toggle.button_pressed = GameData.screen_shake
	if haptic_toggle:
		haptic_toggle.button_pressed = GameData.haptic_feedback
	if quality_option:
		quality_option.selected = GameData.graphics_quality
	_update_track_label()
	visible = true
	is_open = true

func close() -> void:
	visible = false
	is_open = false
	GameData.save_game()
	emit_signal("closed")

func _on_music_volume_changed(value: float) -> void:
	GameData.music_volume = value
	var mgr = get_node_or_null("/root/AudioManager")
	if mgr:
		mgr.apply_music_volume(value)

func _on_sfx_volume_changed(value: float) -> void:
	GameData.sfx_volume = value
	var mgr = get_node_or_null("/root/AudioManager")
	if mgr:
		mgr.apply_sfx_volume(value)

func _on_shake_toggled(pressed: bool) -> void:
	GameData.screen_shake = pressed

func _on_haptic_toggled(pressed: bool) -> void:
	GameData.haptic_feedback = pressed

func _on_quality_changed(index: int) -> void:
	GameData.graphics_quality = index
