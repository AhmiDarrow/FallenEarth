## StyleBoxHelper — Utility for creating consistent StyleBoxFlat instances
## across the entire Fallen Earth UI.
##
## Every StyleBox originates from one of these helpers so that corner
## radii, border widths, and color defaults stay in sync.
class_name StyleBoxHelper
extends RefCounted

const UI := preload("res://assets/ui/UI_Colors.gd")


## Standard panel background.
static func panel(bg: Color = UI.BG_DEEP, border: Color = UI.BORDER_SUBTLE,
		radius: int = UI.RADIUS_LG, border_width: int = UI.BORDER_WIDTH_THIN) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	_set_border(sb, border_width, border)
	_set_corners(sb, radius)
	return sb


## Input field style (LineEdit, TextEdit).
static func input_field() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UI.BG_INPUT
	_set_border(sb, UI.BORDER_WIDTH, UI.BORDER_INPUT)
	_set_corners(sb, UI.RADIUS_MD)
	return sb


## Focus ring (white border, no background fill).
static func focus_ring(radius: int = UI.RADIUS_MD) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	_set_border(sb, UI.BORDER_WIDTH, Color.WHITE)
	_set_corners(sb, radius)
	return sb


## Button style for a given variant and state.
static func button(variant: String, _state: String = "normal") -> StyleBoxFlat:
	var data: Dictionary = UI.button_style(variant)
	var bg := data.bg as Color
	var border := data.border as Color
	match _state:
		"hover":
			bg = bg.lightened(0.15)
			border = border.lightened(0.2)
		"pressed":
			bg = bg.darkened(0.15)
		"disabled":
			bg = Color(0.08, 0.08, 0.12)
			border = Color(0.16, 0.16, 0.24)
		"focus":
			border = Color.WHITE
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	_set_border(sb, UI.BORDER_WIDTH, border)
	_set_corners(sb, UI.RADIUS_MD)
	return sb


## Resource bar background (shared by HP/MP/XP).
static func bar_background() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.05, 0.9)
	_set_border(sb, UI.BORDER_WIDTH_THIN, Color(0.12, 0.12, 0.14, 0.8))
	_set_corners(sb, UI.RADIUS_SM)
	return sb


## Resource bar fill.
static func bar_fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	_set_corners(sb, UI.RADIUS_SM)
	return sb


## Scrollbar drag grabber.
static func scrollbar_grabber() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.23, 0.23, 0.35)
	_set_corners(sb, UI.RADIUS_MD)
	return sb


## Tooltip panel style.
static func tooltip() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.07, 0.95)
	_set_border(sb, UI.BORDER_WIDTH_THIN, UI.BORDER_STRONG)
	_set_corners(sb, UI.RADIUS_SM)
	return sb


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

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
