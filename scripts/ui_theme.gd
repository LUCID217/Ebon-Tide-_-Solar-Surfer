extends Node

# UITheme.gd - Canonical UI Color Palette for Ebon Tide
# Inspired by early-2000s animated adventure (Treasure Planet / Atlantis / Sinbad)
# Add to Project Settings > Autoload as "UITheme"

# ============ CANONICAL PALETTE ============

# Neutrals / Ink
const INK_BLACK = Color("#0E0E14")
const DEEP_SLATE = Color("#30354A")
const STEEL_SHADOW = Color("#3B445D")
const UI_GRAPHITE = Color("#545966")

# Sky / Atmosphere
const SKY_MID = Color("#8CA1D9")
const SKY_LOW = Color("#7B90C4")
const SKY_MIST = Color("#A7C8EC")
const SKY_STEEL = Color("#778BB6")

# Bone / Light
const BONE_HIGHLIGHT = Color("#E5EFEB")
const WEATHERED_GREY = Color("#9AA29C")

# Warm Accent (use sparingly - 5-10% max)
const RUST_WOOD = Color("#553025")

# ============ SEMANTIC ROLE MAPPING ============

# Backgrounds
const BG_TOP = SKY_MIST
const BG_MID = SKY_MID
const BG_LOW = SKY_LOW
const BG_VIGNETTE = INK_BLACK

# Panels / Cards / Containers
const PANEL_FILL = DEEP_SLATE
const PANEL_BORDER = STEEL_SHADOW
const PANEL_HIGHLIGHT = SKY_STEEL

# Text
const TEXT_PRIMARY = BONE_HIGHLIGHT
const TEXT_SECONDARY = WEATHERED_GREY
const TEXT_DISABLED = UI_GRAPHITE
const TEXT_ON_LIGHT = INK_BLACK

# Buttons
const BUTTON_DEFAULT = STEEL_SHADOW
const BUTTON_HOVER = SKY_STEEL
const BUTTON_PRESSED = DEEP_SLATE
const BUTTON_FOCUS_OUTLINE = SKY_MIST
const BUTTON_ACCENT_TRIM = RUST_WOOD

# Icons
const ICON_DEFAULT = BONE_HIGHLIGHT
const ICON_MUTED = WEATHERED_GREY
const ICON_ACCENT = SKY_MIST

# Currency Display
const CURRENCY_GOLD = Color("#D4A84B")  # Warm gold for marks/sovereigns
const CURRENCY_SILVER = Color("#A8B4C4")  # Cool silver for bits

# ============ HELPER FUNCTIONS ============

func get_button_style_normal() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#FFFFFF")  # White button
	style.border_color = DEEP_SLATE
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	# Add shadow for depth
	style.shadow_color = Color(0, 0, 0, 0.2)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style

func get_button_style_hover() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#E8F4FF")  # Light blue tint on hover
	style.border_color = SKY_MID
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	return style

func get_button_style_pressed() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#D0E8FF")  # Pressed blue
	style.border_color = SKY_STEEL
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.1)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	return style

func get_button_style_focus() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#FFFFFF")
	style.border_color = Color("#FFD700")  # Gold focus ring
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.2)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style

func get_button_style_disabled() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#E0E0E0")  # Grey disabled
	style.border_color = Color("#AAAAAA")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func get_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = PANEL_FILL
	style.bg_color.a = 0.9
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func get_panel_style_highlighted() -> StyleBoxFlat:
	var style = get_panel_style()
	style.border_color = PANEL_HIGHLIGHT
	style.set_border_width_all(3)
	return style

func apply_button_theme(button: Button) -> void:
	button.add_theme_stylebox_override("normal", get_button_style_normal())
	button.add_theme_stylebox_override("hover", get_button_style_hover())
	button.add_theme_stylebox_override("pressed", get_button_style_pressed())
	button.add_theme_stylebox_override("focus", get_button_style_focus())
	button.add_theme_stylebox_override("disabled", get_button_style_disabled())
	# Dark text on white buttons
	button.add_theme_color_override("font_color", INK_BLACK)
	button.add_theme_color_override("font_hover_color", DEEP_SLATE)
	button.add_theme_color_override("font_pressed_color", STEEL_SHADOW)
	button.add_theme_color_override("font_disabled_color", Color("#999999"))

func apply_label_theme(label: Label, is_primary: bool = true) -> void:
	# Dark text on bright sky background
	if is_primary:
		label.add_theme_color_override("font_color", INK_BLACK)
	else:
		label.add_theme_color_override("font_color", DEEP_SLATE)

func apply_title_theme(label: Label) -> void:
	# Bold dark text with subtle shadow for readability on bright sky
	label.add_theme_color_override("font_color", INK_BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.5))  # White shadow for glow effect

# ============ BACKGROUND GRADIENT ============

func create_sky_gradient_texture(height: int = 720) -> GradientTexture2D:
	var gradient = Gradient.new()
	gradient.set_color(0, BG_TOP)
	gradient.add_point(0.5, BG_MID)
	gradient.set_color(1, BG_LOW)
	
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0)
	texture.fill_to = Vector2(0.5, 1)
	texture.width = 1
	texture.height = height
	
	return texture

func create_vignette_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = BG_VIGNETTE
	style.border_color.a = 0.4
	style.set_border_width_all(80)
	style.set_corner_radius_all(0)
	style.set_expand_margin_all(-40)
	return style
