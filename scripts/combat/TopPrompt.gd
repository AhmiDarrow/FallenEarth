## TopPrompt — Top-center styled banner that displays an instruction
## like "Select a white tile to move" or "Choose a target". The
## panel asset is preferred when present (battle_ui/top_prompt_panel.png);
## otherwise a styled rect is used. Auto-fades after a duration.
class_name TopPrompt extends Control

const PANEL_BG_PATH := "res://assets/battle_ui/top_prompt_panel.png"
const DEFAULT_BG := Color(0.05, 0.05, 0.10, 0.92)
const COLOR_BORDER := Color(0.40, 0.55, 0.75, 1.0)
const COLOR_TEXT := Color(1.0, 0.97, 0.92)
const COLOR_DIM := Color(0.85, 0.85, 0.95)
const WIDTH := 460
const HEIGHT := 56

var _label: Label
var _sub: Label
var _panel: PanelContainer
var _tween: Tween = null
var _current_text: String = ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_top = 110
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_bottom = 110 + HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_children()
	visible = false


func _build_children() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
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
	if ResourceLoader.exists(PANEL_BG_PATH):
		var bg_tex := TextureRect.new()
		bg_tex.name = "PanelBg"
		bg_tex.texture = load(PANEL_BG_PATH)
		bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_tex.anchor_right = 1.0
		bg_tex.anchor_bottom = 1.0
		bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg_tex.modulate = Color(1, 1, 1, 0.85)
		_panel.add_child(bg_tex)
		_panel.move_child(bg_tex, 0)
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


## Show a prompt. text is the main line (e.g. "Select a white tile to
## move"). sub is the secondary line (e.g. "Then choose Skill / Attack").
## If `fade_after` > 0, the prompt fades and hides after that many seconds.
func show_prompt(text: String, sub: String = "", fade_after: float = 0.0) -> void:
	_current_text = text
	_label.text = text
	if sub.is_empty():
		_sub.visible = false
		_sub.text = ""
	else:
		_sub.visible = true
		_sub.text = sub
	if not visible:
		visible = true
		modulate = Color(1, 1, 1, 0)
		var t := create_tween()
		t.tween_property(self, "modulate:a", 1.0, 0.18)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if fade_after > 0.0:
		_tween = create_tween()
		_tween.tween_interval(fade_after)
		_tween.tween_property(self, "modulate:a", 0.0, 0.5)
		_tween.tween_callback(func():
			visible = false
			modulate = Color(1, 1, 1, 1.0)
		)


func hide_prompt() -> void:
	visible = false
	_current_text = ""


func get_current_text() -> String:
	return _current_text
