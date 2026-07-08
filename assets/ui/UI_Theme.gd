## UI_Theme — Programmatic Theme resource builder.
##
## Call `UI_Theme.build()` once at game start (e.g. in Splash._ready())
## to generate and apply the centralized Theme to the scene tree root.
##
## This replaces hundreds of per-node theme_override_* calls with a
## single Theme resource that cascades through the entire UI.
class_name UI_Theme
extends RefCounted

const UI := preload("res://assets/ui/UI_Colors.gd")
const SB := preload("res://scripts/StyleBoxHelper.gd")


## Build the centralized Theme and apply it to the root Window.
## In Godot 4, setting theme on the Window cascades to all Controls
## globally, including new scenes loaded after this call.
static func apply_to(window: Window) -> void:
	var theme := _build()
	window.theme = theme


## Build the complete Theme resource.
static func _build() -> Theme:
	var t := Theme.new()

	# ---- Default font sizes ----
	t.default_font_size = UI.FS_BODY
	_set_font_size(t, "Label", "font_size", UI.FS_BODY)
	_set_font_size(t, "Button", "font_size", UI.FS_BUTTON)
	_set_font_size(t, "LineEdit", "font_size", UI.FS_BODY)
	_set_font_size(t, "ProgressBar", "font_size", UI.FS_SMALL)
	_set_font_size(t, "CheckBox", "font_size", UI.FS_SMALL)
	_set_font_size(t, "RichTextLabel", "font_size", UI.FS_BODY)

	# ---- Default colors ----
	var default_colors := {
		"Label": {font_color = UI.TEXT_PRIMARY, font_outline_color = Color.BLACK},
		"Button": {font_color = UI.TEXT_PRIMARY, font_hover_color = Color.WHITE,
			font_pressed_color = UI.TEXT_PRIMARY, font_disabled_color = UI.TEXT_MUTED,
			font_focus_color = Color.WHITE, font_outline_color = Color.BLACK},
		"LineEdit": {font_color = UI.TEXT_PRIMARY, font_placeholder_color = UI.TEXT_MUTED,
			font_outline_color = Color.BLACK},
		"ProgressBar": {font_color = UI.TEXT_PRIMARY, font_outline_color = Color.BLACK},
		"CheckBox": {font_color = UI.TEXT_PRIMARY},
	}
	for node_type_str in default_colors:
		var color_map: Dictionary = default_colors[node_type_str]
		for key in color_map:
			t.set_color(node_type_str, key, color_map[key])

	# ---- Constants ----
	t.set_constant("Label", "outline_size", 2)
	t.set_constant("Button", "outline_size", 2)
	t.set_constant("ProgressBar", "outline_size", 1)

	# ---- Styles ----
	# Panel / PanelContainer
	var panel_style := SB.panel()
	t.set_stylebox("Panel", "panel", panel_style)
	t.set_stylebox("PanelContainer", "panel", panel_style)

	# Button default
	var btn_normal := SB.button("primary", "normal")
	var btn_hover := SB.button("primary", "hover")
	var btn_pressed := SB.button("primary", "pressed")
	var btn_disabled := SB.button("primary", "disabled")
	var btn_focus := SB.button("primary", "focus")
	t.set_stylebox("Button", "normal", btn_normal)
	t.set_stylebox("Button", "hover", btn_hover)
	t.set_stylebox("Button", "pressed", btn_pressed)
	t.set_stylebox("Button", "disabled", btn_disabled)
	t.set_stylebox("Button", "focus", btn_focus)

	# LineEdit
	t.set_stylebox("LineEdit", "normal", SB.input_field())
	t.set_stylebox("LineEdit", "focus", SB.focus_ring())
	t.set_stylebox("LineEdit", "read_only", SB.input_field())

	# ProgressBar
	t.set_stylebox("ProgressBar", "background", SB.bar_background())

	# Scrollbar
	t.set_stylebox("VScrollBar", "grabber", SB.scrollbar_grabber())
	t.set_stylebox("HScrollBar", "grabber", SB.scrollbar_grabber())
	t.set_stylebox("VScrollBar", "grabber_highlight", SB.scrollbar_grabber())
	t.set_stylebox("HScrollBar", "grabber_highlight", SB.scrollbar_grabber())

	# CheckBox
	t.set_stylebox("CheckBox", "normal", SB.panel(UI.BG_INPUT, UI.BORDER_INPUT, UI.RADIUS_SM, 1))
	t.set_stylebox("CheckBox", "pressed", SB.panel(UI.ACCENT_PRIMARY, UI.ACCENT_PRIMARY, UI.RADIUS_SM, 1))
	t.set_stylebox("CheckBox", "hover", SB.panel(UI.BG_ELEVATED, UI.BORDER_STRONG, UI.RADIUS_SM, 1))
	t.set_stylebox("CheckBox", "disabled", SB.panel(Color(0.08, 0.08, 0.12), UI.BORDER_SUBTLE, UI.RADIUS_SM, 1))

	# Tooltip
	t.set_stylebox("Tooltip", "panel", SB.tooltip())

	return t


## Apply theme defaults to a specific control (for fine-grained overrides).
static func apply_to_control(control: Control) -> void:
	var t := _build()
	control.theme = t


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------
static func _set_font_size(t: Theme, node_type: String, key: String, value: int) -> void:
	t.set_font_size(node_type, key, value)
