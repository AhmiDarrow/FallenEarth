class_name ActionBarV110
extends Control
## Bottom-center combat action bar with Move, Attack, End Turn, and Retreat.
## Adapted from the v0.10.1 _build_bottom_action_bar() for the v0.11.0 arch.

const BUTTON_WIDTH := 140
const BUTTON_HEIGHT := 36

var _move_btn: Button
var _attack_btn: Button
var _end_turn_btn: Button
var _retreat_btn: Button
var on_move: Callable = Callable()
var on_attack: Callable = Callable()
var on_end_turn: Callable = Callable()
var on_retreat: Callable = Callable()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_children()


func _build_children() -> void:
	var hbox := HBoxContainer.new()
	hbox.name = "Buttons"
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)

	_move_btn = _make_button("Move", Color(0.4, 0.85, 1.0))
	_move_btn.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	_move_btn.pressed.connect(_on_move_pressed)
	hbox.add_child(_move_btn)

	_attack_btn = _make_button("Attack", Color(1.0, 0.4, 0.4))
	_attack_btn.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	_attack_btn.pressed.connect(_on_attack_pressed)
	hbox.add_child(_attack_btn)

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


func show_move_button(enabled: bool) -> void:
	if _move_btn:
		_move_btn.visible = enabled
		_move_btn.disabled = not enabled


func show_attack_button(enabled: bool) -> void:
	if _attack_btn:
		_attack_btn.visible = enabled
		_attack_btn.disabled = not enabled


func show_end_turn(enabled: bool) -> void:
	if _end_turn_btn:
		_end_turn_btn.visible = enabled


func show_retreat(enabled: bool) -> void:
	if _retreat_btn:
		_retreat_btn.visible = enabled


func _on_move_pressed() -> void:
	if on_move.is_valid():
		on_move.call()


func _on_attack_pressed() -> void:
	if on_attack.is_valid():
		on_attack.call()


func _on_end_turn_pressed() -> void:
	if on_end_turn.is_valid():
		on_end_turn.call()


func _on_retreat_pressed() -> void:
	if on_retreat.is_valid():
		on_retreat.call()
