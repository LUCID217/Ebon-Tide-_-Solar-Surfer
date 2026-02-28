# Ebon Tide UI Assets

## Folder Structure
```
ui/
├── fonts/          # Custom TTF/OTF font files
├── textures/       # Button textures for 9-slice (future upgrade)
├── theme/          # Theme resources (if using .tres files)
└── SpaceBackdrop.gdshader  # Animated starfield shader
```

## Adding Custom Fonts

### Recommended Fonts (Free, Google Fonts)
- **Cinzel** - Epic/cinematic feel, great for titles
- **Bebas Neue** - Bold poster style
- **Orbitron** - Sci-fi/space feel
- **Righteous** - Rounded, friendly adventure

### How to Add:
1. Download the .ttf file from Google Fonts
2. Place it in `res://ui/fonts/` (e.g., `Cinzel-Bold.ttf`)
3. In `menu_theme.gd`, uncomment and update the font loading code:

```gdscript
# In apply_to() function, TitleLabel section:
var title_font = load("res://ui/fonts/Cinzel-Bold.ttf")
theme.set_font("font", "TitleLabel", title_font)
```

## Upgrading to Custom Button Textures

### Current: StyleBoxFlat Pills
The surfboard buttons currently use `StyleBoxFlat` with `corner_radius = 999` for perfect pill shapes.

### Future: 9-Slice Textures
To upgrade to custom painted surfboard textures:

1. Create PNG textures (recommended 512x128):
   - `surfboard_normal.png`
   - `surfboard_hover.png`
   - `surfboard_pressed.png`
   - `surfboard_disabled.png`

2. In `menu_theme.gd`, replace `_surfboard_style()` with:
```gdscript
static func _surfboard_texture_style(texture_path: String) -> StyleBoxTexture:
    var sb := StyleBoxTexture.new()
    sb.texture = load(texture_path)
    # 9-slice margins (adjust based on your texture)
    sb.texture_margin_left = 64
    sb.texture_margin_right = 64
    sb.texture_margin_top = 32
    sb.texture_margin_bottom = 32
    sb.content_margin_left = 32
    sb.content_margin_right = 32
    sb.content_margin_top = 14
    sb.content_margin_bottom = 14
    return sb
```

## Theme Type Variations

Available variations for buttons:
- `Button` (default) - Teal surfboard
- `SecondaryButton` - Ember/orange surfboard
- `GhostButton` - Outline only, transparent fill

To use: `button.theme_type_variation = "SecondaryButton"`
