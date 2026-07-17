class_name CombatActionPanel
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")

const BUTTON_WIDTH := 120
const BUTTON_HEIGHT := 36

var _move_btn: Button
var _attack_btn: Button
var _tame_btn: Button
var _end_turn_btn: Button
var _retreat_btn: Button

var on_move: Callable = Callable()
var on_attack: Callable = Callable()
var on_tame: Callable = Callable()
var on_end_turn: Callable = Callable()
var on_retreat: Callable = Callable()


func _ready() -> void:
	_build_children()


func _build_children() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", MT.panel(MT.BG_DEEP, MT.BORDER_STRONG, MT.RADIUS_LG, 2))
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	_move_btn = _make_button("Move", Color(0.4, 0.85, 1.0))
	_move_btn.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	_move_btn.pressed.connect(_on_move_pressed)
	vbox.add_child(_move_btn)

	_attack_btn = _make_button("Attack", Color(1.0, 0.4, 0.4))
	_attack_btn.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	_attack_btn.pressed.connect(_on_attack_pressed)
	vbox.add_child(_attack_btn)

	_tame_btn = _make_button("Tame", Color(0.5, 0.9, 0.4))
	_tame_btn.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	_tame_btn.pressed.connect(_on_tame_pressed)
	_tame_btn.visible = false
	vbox.add_child(_tame_btn)

	_end_turn_btn = _make_button("End Turn", Color(0.95, 0.85, 0.55))
	_end_turn_btn.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	vbox.add_child(_end_turn_btn)

	_retreat_btn = _make_button("Retreat", Color(0.95, 0.7, 0.55))
	_retreat_btn.custom_minimum_size = Vector2(BUTTON_WIDTH - 20, BUTTON_HEIGHT)
	_retreat_btn.pressed.connect(_on_retreat_pressed)
	vbox.add_child(_retreat_btn)


func _make_button(label_text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.add_theme_color_override("font_color", accent)
	btn.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_theme_constant_override("outline_size", 3)
	btn.add_theme_stylebox_override("normal", MT.button_stylebox("primary", "normal"))
	btn.add_theme_stylebox_override("hover", MT.button_stylebox("primary", "hover"))
	btn.add_theme_stylebox_override("pressed", MT.button_stylebox("primary", "pressed"))
	btn.add_theme_stylebox_override("disabled", MT.button_stylebox("primary", "disabled"))
	btn.add_theme_stylebox_override("focus", MT.focus_ring())
	return btn


func show_main_buttons(enabled: bool) -> void:
	for btn in [_move_btn, _attack_btn, _end_turn_btn, _retreat_btn]:
		btn.visible = enabled
		btn.disabled = not enabled


func set_tame_visible(visible: bool) -> void:
	if _tame_btn:
		_tame_btn.visible = visible


func set_tame_enabled(enabled: bool) -> void:
	if _tame_btn:
		_tame_btn.disabled = not enabled


func _on_move_pressed() -> void:
	if on_move.is_valid():
		on_move.call()


func _on_attack_pressed() -> void:
	if on_attack.is_valid():
		on_attack.call()


func _on_tame_pressed() -> void:
	if on_tame.is_valid():
		on_tame.call()


func _on_end_turn_pressed() -> void:
	if on_end_turn.is_valid():
		on_end_turn.call()


func _on_retreat_pressed() -> void:
	if on_retreat.is_valid():
		on_retreat.call()
