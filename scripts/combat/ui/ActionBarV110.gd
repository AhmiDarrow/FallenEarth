class_name ActionBarV110
extends Control
## Bottom-center End Turn + Retreat bar. Adapted from the
## v0.10.1 _build_bottom_action_bar() for the v0.11.0 arch.

const BUTTON_WIDTH := 160
const BUTTON_HEIGHT := 36

var _end_turn_btn: Button
var _retreat_btn: Button
var on_end_turn: Callable = Callable()
var on_retreat: Callable = Callable()


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -180
	offset_right = 180
	offset_top = -160
	offset_bottom = -124
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_children()


func _build_children() -> void:
	var hbox := HBoxContainer.new()
	hbox.name = "Buttons"
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)
	_end_turn_btn = _make_button("End Turn", Color(0.95, 0.85, 0.55))
	_end_turn_btn.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	hbox.add_child(_end_turn_btn)
	_retreat_btn = _make_button("Retreat", Color(0.95, 0.7, 0.55))
	_retreat_btn.custom_minimum_size = Vector2(120, BUTTON_HEIGHT)
	_retreat_btn.pressed.connect(_on_retreat_pressed)
	hbox.add_child(_retreat_btn)


func _make_button(label_text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", accent)
	btn.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_theme_constant_override("outline_size", 3)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.12, 0.85)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.45, 0.45, 0.55, 1.0)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color(0.20, 0.18, 0.25, 0.92)
	sb_hover.border_color = Color(0.95, 0.80, 0.35, 1.0)
	btn.add_theme_stylebox_override("hover", sb_hover)
	return btn


func _on_end_turn_pressed() -> void:
	if on_end_turn.is_valid():
		on_end_turn.call()


func _on_retreat_pressed() -> void:
	if on_retreat.is_valid():
		on_retreat.call()
