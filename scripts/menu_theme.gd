# MenuTheme.gd (Godot 4.x)
# Call MenuTheme.apply_to(root) to apply theme
# NO font loading here - fonts loaded in main_menu.gd

extends RefCounted

class_name MenuTheme

# --- Palette: "Vespera Pop" ---
const C_BG          := Color("#070A12")
const C_PANEL       := Color("#0E1426")
const C_PANEL_2     := Color("#111B33")
const C_STROKE      := Color("#2A3B6B")
const C_TEXT        := Color("#EAF2FF")
const C_TEXT_MUTED  := Color("#A9B8D6")

const C_ACCENT_TEAL := Color("#2EF2D0")
const C_ACCENT_EMBER:= Color("#FF7A2A")
const C_ACCENT_VIO  := Color("#A66BFF")
const C_DANGER      := Color("#FF3B5C")

const C_GLOW_TEAL   := Color("#88FFF0")
const C_GLOW_EMBER  := Color("#FFC29A")

const SURFBOARD_PAD_H  := 32
const SURFBOARD_PAD_V  := 14
const PANEL_RADIUS := 18
const PANEL_PAD_H  := 22
const PANEL_PAD_V  := 14

static func apply_to(root: Control) -> void:
	var theme := Theme.new()
	
	# Default font sizes
	theme.set_default_font_size(18)
	theme.set_font_size("font_size", "Label", 18)
	theme.set_font_size("font_size", "Button", 18)
	theme.set_font_size("font_size", "LineEdit", 18)
	
	# Labels
	theme.set_color("font_color", "Label", C_TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 2)
	
	# TitleLabel
	theme.add_type("TitleLabel")
	theme.set_font_size("font_size", "TitleLabel", 72)
	theme.set_color("font_color", "TitleLabel", Color("#F5E6D3"))
	theme.set_color("font_shadow_color", "TitleLabel", Color(0, 0, 0, 0.8))
	theme.set_constant("shadow_offset_x", "TitleLabel", 2)
	theme.set_constant("shadow_offset_y", "TitleLabel", 3)
	
	# SubLabel
	theme.add_type("SubLabel")
	theme.set_font_size("font_size", "SubLabel", 20)
	theme.set_color("font_color", "SubLabel", C_TEXT_MUTED)
	
	# Panels
	theme.set_stylebox("panel", "Panel", _panel_style(C_PANEL, C_STROKE, 2))
	theme.set_stylebox("panel", "PanelContainer", _panel_style(C_PANEL, C_STROKE, 2))
	
	theme.add_type("CardPanel")
	theme.set_stylebox("panel", "CardPanel", _panel_style(C_PANEL_2, C_STROKE, 2))
	
	# Buttons - SURFBOARD PILL STYLE
	theme.set_stylebox("normal",  "Button", _surfboard_style(C_ACCENT_TEAL, C_GLOW_TEAL, 0.75, 0))
	theme.set_stylebox("hover",   "Button", _surfboard_style(C_ACCENT_TEAL, C_GLOW_TEAL, 0.85, 2))
	theme.set_stylebox("pressed", "Button", _surfboard_style(C_ACCENT_TEAL, C_GLOW_TEAL, 0.95, -1))
	theme.set_stylebox("disabled","Button", _surfboard_style(Color("#3A455F"), Color("#465170"), 0.4, 0))
	
	theme.set_color("font_color",          "Button", C_BG)
	theme.set_color("font_hover_color",    "Button", C_BG)
	theme.set_color("font_pressed_color",  "Button", Color("#0A0F18"))
	theme.set_color("font_disabled_color", "Button", Color("#808890"))
	theme.set_constant("h_separation", "Button", 10)
	
	# SecondaryButton
	theme.add_type("SecondaryButton")
	theme.set_stylebox("normal",  "SecondaryButton", _surfboard_style(C_ACCENT_EMBER, C_GLOW_EMBER, 0.75, 0))
	theme.set_stylebox("hover",   "SecondaryButton", _surfboard_style(C_ACCENT_EMBER, C_GLOW_EMBER, 0.85, 2))
	theme.set_stylebox("pressed", "SecondaryButton", _surfboard_style(C_ACCENT_EMBER, C_GLOW_EMBER, 0.95, -1))
	theme.set_stylebox("disabled","SecondaryButton", _surfboard_style(Color("#3A455F"), Color("#465170"), 0.4, 0))
	theme.set_color("font_color", "SecondaryButton", C_BG)
	theme.set_color("font_hover_color", "SecondaryButton", C_BG)
	theme.set_color("font_pressed_color", "SecondaryButton", Color("#0A0F18"))
	theme.set_color("font_disabled_color", "SecondaryButton", Color("#808890"))
	
	# GhostButton
	theme.add_type("GhostButton")
	theme.set_stylebox("normal",  "GhostButton", _ghost_surfboard(C_STROKE, 2, 0.0))
	theme.set_stylebox("hover",   "GhostButton", _ghost_surfboard(C_ACCENT_TEAL, 2, 0.08))
	theme.set_stylebox("pressed", "GhostButton", _ghost_surfboard(C_ACCENT_TEAL, 2, 0.15))
	theme.set_stylebox("disabled","GhostButton", _ghost_surfboard(Color("#2C3448"), 2, 0.0))
	theme.set_color("font_color", "GhostButton", C_TEXT)
	theme.set_color("font_hover_color", "GhostButton", C_GLOW_TEAL)
	theme.set_color("font_pressed_color", "GhostButton", C_TEXT)
	theme.set_color("font_disabled_color", "GhostButton", Color("#606878"))
	
	# LineEdit
	theme.set_stylebox("normal", "LineEdit", _input_style(C_PANEL_2, C_STROKE, 2))
	theme.set_stylebox("focus",  "LineEdit", _input_style(C_PANEL_2, C_ACCENT_TEAL, 2))
	theme.set_color("font_color", "LineEdit", C_TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", Color(C_TEXT_MUTED, 0.65))
	theme.set_color("caret_color", "LineEdit", C_ACCENT_TEAL)
	
	root.theme = theme

static func _surfboard_style(accent: Color, glow: Color, fill_alpha: float, lift: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r, accent.g, accent.b, fill_alpha)
	sb.border_color = Color(glow.r, glow.g, glow.b, 0.9)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 999
	sb.corner_radius_top_right = 999
	sb.corner_radius_bottom_left = 999
	sb.corner_radius_bottom_right = 999
	sb.content_margin_left = SURFBOARD_PAD_H
	sb.content_margin_right = SURFBOARD_PAD_H
	sb.content_margin_top = SURFBOARD_PAD_V
	sb.content_margin_bottom = SURFBOARD_PAD_V
	if lift > 0:
		sb.expand_margin_top = -lift
		sb.expand_margin_bottom = lift
	elif lift < 0:
		sb.expand_margin_top = -lift
		sb.expand_margin_bottom = lift
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.5
	return sb

static func _ghost_surfboard(stroke: Color, stroke_w: int, fill_alpha: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, fill_alpha)
	sb.border_color = stroke
	sb.border_width_left = stroke_w
	sb.border_width_right = stroke_w
	sb.border_width_top = stroke_w
	sb.border_width_bottom = stroke_w
	sb.corner_radius_top_left = 999
	sb.corner_radius_top_right = 999
	sb.corner_radius_bottom_left = 999
	sb.corner_radius_bottom_right = 999
	sb.content_margin_left = SURFBOARD_PAD_H
	sb.content_margin_right = SURFBOARD_PAD_H
	sb.content_margin_top = SURFBOARD_PAD_V
	sb.content_margin_bottom = SURFBOARD_PAD_V
	sb.anti_aliasing = true
	return sb

static func _panel_style(fill: Color, stroke: Color, stroke_w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = stroke
	sb.border_width_left = stroke_w
	sb.border_width_right = stroke_w
	sb.border_width_top = stroke_w
	sb.border_width_bottom = stroke_w
	sb.corner_radius_top_left = PANEL_RADIUS
	sb.corner_radius_top_right = PANEL_RADIUS
	sb.corner_radius_bottom_left = PANEL_RADIUS
	sb.corner_radius_bottom_right = PANEL_RADIUS
	sb.content_margin_left = PANEL_PAD_H
	sb.content_margin_right = PANEL_PAD_H
	sb.content_margin_top = PANEL_PAD_V
	sb.content_margin_bottom = PANEL_PAD_V
	return sb

static func _input_style(fill: Color, stroke: Color, stroke_w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = stroke
	sb.border_width_left = stroke_w
	sb.border_width_right = stroke_w
	sb.border_width_top = stroke_w
	sb.border_width_bottom = stroke_w
	sb.corner_radius_top_left = PANEL_RADIUS
	sb.corner_radius_top_right = PANEL_RADIUS
	sb.corner_radius_bottom_left = PANEL_RADIUS
	sb.corner_radius_bottom_right = PANEL_RADIUS
	sb.content_margin_left = PANEL_PAD_H
	sb.content_margin_right = PANEL_PAD_H
	sb.content_margin_top = PANEL_PAD_V
	sb.content_margin_bottom = PANEL_PAD_V
	return sb
