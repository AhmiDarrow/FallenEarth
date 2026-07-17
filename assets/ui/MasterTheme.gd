## MasterTheme — Single consolidated UI theming module for Fallen Earth
## Import once: `const MT = preload("res://assets/ui/MasterTheme.gd")`
## Provides colors, sizes, styleboxes, button styling, backgrounds, depth overlay,
## and theme builder — every UI token the game needs.
class_name MasterTheme
extends RefCounted

# =============================================================================
# SECTION 1 — Color Palette (warm earth tones)
# =============================================================================

const BG_DEEP       := Color(0.141, 0.118, 0.102)  # #241E1A
const BG_SURFACE    := Color(0.180, 0.157, 0.141)  # #2E2824
const BG_ELEVATED   := Color(0.227, 0.200, 0.180)  # #3A332E
const BG_INPUT      := Color(0.141, 0.118, 0.102)  # #241E1A
const BG_PANEL      := Color(0.180, 0.157, 0.141)  # #2E2824

const BORDER_SUBTLE := Color(0.235, 0.208, 0.188)  # #3C3530
const BORDER_STRONG := Color(0.353, 0.314, 0.282)  # #5A5048
const BORDER_INPUT  := Color(0.235, 0.208, 0.188)  # #3C3530

const ACCENT_PRIMARY   := Color(0.788, 0.722, 0.588)  # #C9B896
const ACCENT_SECONDARY := Color(0.459, 0.620, 0.682)  # #759EAE
const ACCENT_DANGER    := Color(0.769, 0.251, 0.251)  # #C44040
const ACCENT_SUCCESS   := Color(0.439, 0.608, 0.478)  # #709B7A
const ACCENT_NEON      := Color(0.494, 0.427, 0.718)  # #7E6DB7

const TEXT_PRIMARY     := Color(0.910, 0.863, 0.773)  # #E8DCC5
const TEXT_SECONDARY   := Color(0.651, 0.620, 0.580)  # #A69E94
const TEXT_MUTED       := Color(0.475, 0.451, 0.420)  # #79736B
const TEXT_ACCENT      := Color(0.788, 0.722, 0.588)  # #C9B896
const TEXT_DANGER      := Color(0.769, 0.251, 0.251)  # #C44040
const TEXT_SUCCESS     := Color(0.439, 0.608, 0.478)  # #709B7A
const TEXT_LINK        := Color(0.459, 0.620, 0.682)  # #759EAE

const HP_FILL    := Color(0.769, 0.251, 0.251)  # #C44040
const HP_BG      := Color(0.329, 0.157, 0.157)  # #542828
const MP_FILL    := Color(0.376, 0.518, 0.675)  # #6084AC
const MP_BG      := Color(0.173, 0.263, 0.373)  # #2C435F
const XP_FILL    := Color(0.439, 0.608, 0.478)  # #709B7A
const XP_BG      := Color(0.192, 0.325, 0.255)  # #315341

const RARITY_COMMON    := Color(0.651, 0.620, 0.580)  # #A69E94
const RARITY_UNCOMMON  := Color(0.439, 0.608, 0.478)  # #709B7A
const RARITY_RARE      := Color(0.459, 0.620, 0.682)  # #759EAE
const RARITY_EPIC      := Color(0.494, 0.427, 0.718)  # #7E6DB7
const RARITY_LEGENDARY := Color(0.788, 0.722, 0.588)  # #C9B896

const OVERLAY_DARK  := Color(0.102, 0.082, 0.071, 0.85)  # #1A1512 @ 85%
const OVERLAY_LIGHT := Color(0.141, 0.118, 0.102, 0.60)  # #241E1A @ 60%

const GLOW_PRIMARY := Color(0.788, 0.722, 0.588)  # #C9B896
const GLOW_RIFT    := Color(0.494, 0.427, 0.718)  # #7E6DB7

const MM_PLAYER      := Color(0.400, 0.851, 1.000)  # #66D9FF
const MM_DISCOVERED  := Color(0.451, 0.502, 0.424)  # #73806A
const MM_CURRENT     := Color(1, 1, 1)
const MM_RIFT        := Color(1.000, 0.851, 0.200)  # #FFD930
const MM_RIFTSPIRE   := Color(1.000, 0.502, 0.149)  # #FF8026
const MM_MOB_HOSTILE := Color(1.000, 0.502, 0.400)  # #FF8066
const MM_MOB_NEUTRAL := Color(0.702, 0.851, 0.702)  # #B3D9B3
const MM_GRID_LINE   := Color(0.200, 0.200, 0.220, 0.5)

# =============================================================================
# SECTION 2 — Size & Spacing Tokens
# =============================================================================

const FS_HERO  := 42
const FS_H1    := 28
const FS_H2    := 22
const FS_H3    := 18
const FS_BODY  := 14
const FS_SMALL := 12
const FS_TINY  := 10
const FS_STAT  := 16
const FS_BUTTON := 16

const SPACE_XS  := 4
const SPACE_SM  := 8
const SPACE_MD  := 12
const SPACE_LG  := 16
const SPACE_XL  := 24
const SPACE_2XL := 32
const SPACE_3XL := 48

const RADIUS_SM := 2
const RADIUS_MD := 4
const RADIUS_LG := 6
const RADIUS_XL := 8

const BORDER_WIDTH      := 2
const BORDER_WIDTH_THIN := 1

const BAR_HEIGHT_SM := 14
const BAR_HEIGHT_MD := 16
const BAR_HEIGHT_LG := 18

const CELL_SM := 36
const CELL_MD := 48
const CELL_LG := 64

# =============================================================================
# SECTION 3 — StyleBox Factory
# =============================================================================

static func panel(bg: Color = BG_DEEP, border: Color = BORDER_SUBTLE,
		radius: int = RADIUS_LG, border_width: int = BORDER_WIDTH_THIN) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	_set_border(sb, border_width, border)
	_set_corners(sb, radius)
	return sb


static func input_field() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_INPUT
	_set_border(sb, BORDER_WIDTH, BORDER_INPUT)
	_set_corners(sb, RADIUS_MD)
	return sb


static func focus_ring(radius: int = RADIUS_MD) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	_set_border(sb, BORDER_WIDTH, Color.WHITE)
	_set_corners(sb, radius)
	return sb


static func button_stylebox(variant: String, state: String = "normal") -> StyleBoxFlat:
	var data := _button_style_data(variant)
	var bg := data.bg as Color
	var border := data.border as Color
	match state:
		"hover":
			bg = bg.lightened(0.15)
			border = border.lightened(0.2)
		"pressed":
			bg = bg.darkened(0.15)
		"disabled":
			bg = Color(0.120, 0.102, 0.090)
			border = Color(0.235, 0.208, 0.188)
		"focus":
			border = Color.WHITE
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	_set_border(sb, BORDER_WIDTH, border)
	_set_corners(sb, RADIUS_MD)
	return sb


static func bar_background() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.070, 0.055, 0.045, 0.9)
	_set_border(sb, BORDER_WIDTH_THIN, Color(0.150, 0.130, 0.110, 0.8))
	_set_corners(sb, RADIUS_SM)
	return sb


static func bar_fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	_set_corners(sb, RADIUS_SM)
	return sb


static func scrollbar_grabber() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.310, 0.275, 0.255)
	_set_corners(sb, RADIUS_MD)
	return sb


static func tooltip() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.141, 0.118, 0.102, 0.95)
	_set_border(sb, BORDER_WIDTH_THIN, BORDER_STRONG)
	_set_corners(sb, RADIUS_SM)
	return sb


static func _set_border(sb: StyleBoxFlat, width: int, color: Color) -> void:
	sb.border_width_left = width
	sb.border_width_top = width
	sb.border_width_right = width
	sb.border_width_bottom = width
	if width > 0:
		sb.border_color = color


static func _set_corners(sb: StyleBoxFlat, radius: int) -> void:
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius


static func _button_style_data(variant: String) -> Dictionary:
	match variant:
		"primary":
			return {bg = Color(0.165, 0.141, 0.118), border = ACCENT_PRIMARY, text = TEXT_PRIMARY}
		"secondary":
			return {bg = Color(0.180, 0.157, 0.141), border = ACCENT_SECONDARY, text = Color(0.690, 0.769, 0.882)}
		"danger":
			return {bg = Color(0.251, 0.110, 0.110), border = ACCENT_DANGER, text = Color(1.0, 0.80, 0.80)}
		"success":
			return {bg = Color(0.149, 0.224, 0.165), border = ACCENT_SUCCESS, text = Color(0.80, 1.0, 0.80)}
		"ghost":
			return {bg = Color.TRANSPARENT, border = Color.TRANSPARENT, text = TEXT_SECONDARY}
		_:
			return {bg = Color(0.165, 0.141, 0.118), border = ACCENT_PRIMARY, text = TEXT_PRIMARY}

# =============================================================================
# SECTION 4 — Button Styles
# =============================================================================

static func apply_button_style(btn: Button, style_key: String = "primary") -> void:
	if btn == null:
		return

	var style_data: Dictionary = _button_style_data(style_key)
	var text_color: Color = style_data.get("text", TEXT_PRIMARY)
	btn.add_theme_stylebox_override("normal", button_stylebox(style_key, "normal"))
	btn.add_theme_stylebox_override("hover", button_stylebox(style_key, "hover"))
	btn.add_theme_stylebox_override("pressed", button_stylebox(style_key, "pressed"))
	btn.add_theme_stylebox_override("disabled", button_stylebox(style_key, "disabled"))
	btn.add_theme_stylebox_override("focus", button_stylebox(style_key, "focus"))

	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	btn.add_theme_font_size_override("font_size", FS_BUTTON)


static func apply_primary(btn: Button) -> void:
	apply_button_style(btn, "primary")


static func apply_secondary(btn: Button) -> void:
	apply_button_style(btn, "secondary")


static func apply_danger(btn: Button) -> void:
	apply_button_style(btn, "danger")


static func apply_success(btn: Button) -> void:
	apply_button_style(btn, "success")


static func apply_ghost(btn: Button) -> void:
	apply_button_style(btn, "ghost")


static func apply_focus(control: Control) -> void:
	control.add_theme_stylebox_override("focus", focus_ring())


static func get_button_styles() -> Array[String]:
	return ["primary", "secondary", "danger", "success", "ghost"]

# =============================================================================
# SECTION 6 — Theme Builder
# =============================================================================

static func apply_to(window: Window) -> void:
	var theme := _build_theme()
	window.theme = theme


static func _build_theme() -> Theme:
	var t := Theme.new()

	t.default_font_size = FS_BODY
	_set_theme_font_size(t, "Label", "font_size", FS_BODY)
	_set_theme_font_size(t, "Button", "font_size", FS_BUTTON)
	_set_theme_font_size(t, "LineEdit", "font_size", FS_BODY)
	_set_theme_font_size(t, "ProgressBar", "font_size", FS_SMALL)
	_set_theme_font_size(t, "CheckBox", "font_size", FS_SMALL)
	_set_theme_font_size(t, "RichTextLabel", "font_size", FS_BODY)

	var default_colors := {
		"Label": {font_color = TEXT_PRIMARY, font_outline_color = Color.BLACK},
		"Button": {font_color = TEXT_PRIMARY, font_hover_color = Color.WHITE,
			font_pressed_color = TEXT_PRIMARY, font_disabled_color = TEXT_MUTED,
			font_focus_color = Color.WHITE, font_outline_color = Color.BLACK},
		"LineEdit": {font_color = TEXT_PRIMARY, font_placeholder_color = TEXT_MUTED,
			font_outline_color = Color.BLACK},
		"ProgressBar": {font_color = TEXT_PRIMARY, font_outline_color = Color.BLACK},
		"CheckBox": {font_color = TEXT_PRIMARY},
	}
	for node_type_str in default_colors:
		var color_map: Dictionary = default_colors[node_type_str]
		for key in color_map:
			t.set_color(node_type_str, key, color_map[key])

	t.set_constant("Label", "outline_size", 2)
	t.set_constant("Button", "outline_size", 2)
	t.set_constant("ProgressBar", "outline_size", 1)

	var panel_transparent := StyleBoxFlat.new()
	panel_transparent.bg_color = Color.TRANSPARENT
	t.set_stylebox("Panel", "panel", panel_transparent)
	t.set_stylebox("PanelContainer", "panel", panel_transparent)

	var btn_norm := button_stylebox("primary", "normal")
	var btn_hover := button_stylebox("primary", "hover")
	var btn_pressed := button_stylebox("primary", "pressed")
	var btn_disabled := button_stylebox("primary", "disabled")
	var btn_focus := button_stylebox("primary", "focus")
	t.set_stylebox("Button", "normal", btn_norm)
	t.set_stylebox("Button", "hover", btn_hover)
	t.set_stylebox("Button", "pressed", btn_pressed)
	t.set_stylebox("Button", "disabled", btn_disabled)
	t.set_stylebox("Button", "focus", btn_focus)

	t.set_stylebox("LineEdit", "normal", input_field())
	t.set_stylebox("LineEdit", "focus", focus_ring())
	t.set_stylebox("LineEdit", "read_only", input_field())

	t.set_stylebox("ProgressBar", "background", bar_background())

	t.set_stylebox("VScrollBar", "grabber", scrollbar_grabber())
	t.set_stylebox("HScrollBar", "grabber", scrollbar_grabber())
	t.set_stylebox("VScrollBar", "grabber_highlight", scrollbar_grabber())
	t.set_stylebox("HScrollBar", "grabber_highlight", scrollbar_grabber())

	t.set_stylebox("CheckBox", "normal", panel(BG_INPUT, BORDER_INPUT, RADIUS_SM, 1))
	t.set_stylebox("CheckBox", "pressed", panel(ACCENT_PRIMARY, ACCENT_PRIMARY, RADIUS_SM, 1))
	t.set_stylebox("CheckBox", "hover", panel(BG_ELEVATED, BORDER_STRONG, RADIUS_SM, 1))
	t.set_stylebox("CheckBox", "disabled", panel(Color(0.120, 0.102, 0.090), BORDER_SUBTLE, RADIUS_SM, 1))

	t.set_stylebox("Tooltip", "panel", tooltip())

	return t


static func apply_theme_to_control(control: Control) -> void:
	var t := _build_theme()
	control.theme = t


static func _set_theme_font_size(t: Theme, node_type: String, key: String, value: int) -> void:
	t.set_font_size(node_type, key, value)
