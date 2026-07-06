class_name TopPromptV110
extends Control
## Top-center styled banner that displays the current turn
## instruction. Adapted from the v0.10.1 TopPrompt for the
## v0.11.0 architecture — takes the CombatLevel as input
## and shows the prompt based on the current participant's
## stage.

const PANEL_BG_PATH := "res://assets/battle_ui/top_prompt_panel.png"
const DEFAULT_BG := Color(0.05, 0.05, 0.10, 0.92)
const COLOR_BORDER := Color(0.40, 0.55, 0.75, 1.0)
const COLOR_TEXT := Color(1.0, 0.97, 0.92)
const COLOR_DIM := Color(0.85, 0.85, 0.95)
const WIDTH := 360
const HEIGHT := 48

var _label: Label
var _sub: Label
var _panel: PanelContainer


func _ready() -> void:
	offset_top = 124
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_bottom = 124 + HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_children()
	visible = false


func _build_children() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var sb := StyleBoxFlat.new()
	sb.bg_color = DEFAULT_BG
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = COLOR_BORDER
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	_panel.add_child(vbox)
	_label = Label.new()
	_label.name = "Title"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", COLOR_TEXT)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_label)
	_sub = Label.new()
	_sub.name = "Sub"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_color", COLOR_DIM)
	_sub.add_theme_color_override("font_outline_color", Color.BLACK)
	_sub.add_theme_constant_override("outline_size", 2)
	_sub.add_theme_font_size_override("font_size", 10)
	_sub.visible = false
	vbox.add_child(_sub)


## v0.11.0: Show a prompt. Replaces the v0.10.1 show_prompt().
func show_prompt(text: String, sub: String = "") -> void:
	_label.text = text
	if sub.is_empty():
		_sub.visible = false
		_sub.text = ""
	else:
		_sub.visible = true
		_sub.text = sub
	visible = true


## v0.11.0: Hide the prompt.
func hide_prompt() -> void:
	visible = false
