class_name HexCell
extends Control

signal hex_pressed()

var cell_q: int
var cell_r: int
var biome_color: Color = Color(0.4, 0.4, 0.4)
var elevation: float = 0.5
var is_player_hex: bool = false
var is_selected: bool = false
var discovered: bool = false
var _hovered: bool = false

var _label: Label

const RADIUS := 27.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	custom_minimum_size = Vector2(RADIUS * 2 + 2, RADIUS * 2 + 2)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 2)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_label)


func set_text(t: String) -> void:
	if is_instance_valid(_label):
		_label.text = t


func set_text_color(c: Color) -> void:
	if is_instance_valid(_label):
		_label.add_theme_color_override("font_color", c)


func _draw() -> void:
	var center := size / 2
	var pts := PackedVector2Array()
	for i in range(6):
		var a := deg_to_rad(60.0 * i - 30.0)
		pts.append(center + Vector2(cos(a), sin(a)) * RADIUS)

	# Fill — biome color shaded by elevation, dimmed if undiscovered
	var fill := biome_color
	var elev_shade := clampf((1.0 - elevation) * 0.2, 0.0, 0.2)
	fill = fill.darkened(elev_shade)
	if not discovered:
		fill = fill.darkened(0.5)
	draw_colored_polygon(pts, fill)

	# Hover overlay
	if _hovered and not is_player_hex:
		var hl := Color(1, 1, 1, 0.08)
		draw_colored_polygon(pts, hl)

	# Border
	var border_color := Color(0.3, 0.25, 0.35, 0.5)
	var border_width := 1.0
	if is_player_hex:
		border_color = Color(1.0, 0.95, 0.6, 1.0)
		border_width = 2.5
	elif is_selected:
		border_color = Color(0.7, 0.9, 1.0, 0.9)
		border_width = 2.0
	elif _hovered:
		border_color = Color(0.9, 0.9, 1.0, 0.6)
		border_width = 1.5
	elif not discovered:
		border_color = Color(0.2, 0.18, 0.25, 0.4)
		border_width = 0.5
	for i in range(6):
		draw_line(pts[i], pts[(i + 1) % 6], border_color, border_width)


func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hex_pressed.emit()
		accept_event()
