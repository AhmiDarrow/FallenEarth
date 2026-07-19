class_name TopPromptV110
extends Control
## Top-center styled banner that displays the current turn
## instruction. Adapted from the v0.10.1 TopPrompt for the
## v0.11.0 architecture — takes the CombatLevel as input
## and shows the prompt based on the current participant's
## stage.

const MT = preload("res://assets/ui/MasterTheme.gd")

const DEFAULT_BG := Color(0.05, 0.05, 0.10, 0.92)
const COLOR_BORDER := Color(0.40, 0.55, 0.75, 1.0)
const COLOR_TEXT := Color(1.0, 0.97, 0.92)
const COLOR_DIM := Color(0.85, 0.85, 0.95)
const WIDTH := 360
const HEIGHT := 64

var _label: Label
var _sub: Label
var _panel: PanelContainer


func _ready() -> void:
	# v0.11.0: Anchors and offsets are set by CombatLevel._apply_layout()
	# which reads the actual viewport size from DisplayManager. Do not
	# hardcode positions here — the orchestrator handles it.
	_build_children()
	visible = false


func _build_children() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_panel.add_theme_stylebox_override("panel", MT.panel(DEFAULT_BG, COLOR_BORDER, 6, 2))
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_label)
	_sub = Label.new()
	_sub.name = "Sub"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_color", COLOR_DIM)
	_sub.add_theme_color_override("font_outline_color", Color.BLACK)
	_sub.add_theme_constant_override("outline_size", 2)
	_sub.add_theme_font_size_override("font_size", 12)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
