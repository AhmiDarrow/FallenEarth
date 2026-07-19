## RemotePlayer — Visual placeholder for a remote player on the local map.
## A colored rectangle with the player name above it.
class_name RemotePlayer extends Node2D

var player_name: String = ""
var peer_id: int = 0
var cell_size: int = 24

var _bg: ColorRect
var _name_label: Label
var _frame: ColorRect


func _init() -> void:
	z_index = 9
	_bg = ColorRect.new()
	_bg.size = Vector2(cell_size - 2, cell_size - 2)
	_bg.color = Color(0.2, 0.6, 1.0, 0.7)
	_bg.position = Vector2(1, 1)
	add_child(_bg)

	_frame = ColorRect.new()
	_frame.size = Vector2(cell_size, cell_size)
	_frame.color = Color(0.2, 0.6, 1.0, 0.9)
	_frame.position = Vector2.ZERO
	_frame.z_index = 0
	add_child(_frame)

	_name_label = Label.new()
	_name_label.text = ""
	_name_label.position = Vector2(-20, -14)
	_name_label.size = Vector2(cell_size + 40, 14)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_name_label)


func set_player_info(p_name: String, p_id: int) -> void:
	player_name = p_name
	peer_id = p_id
	_name_label.text = p_name
	_bg.color = Color(
		float(p_id % 10) * 0.1,
		0.3 + float((p_id * 3) % 7) * 0.1,
		0.6,
		0.7
	)
	_frame.color = _bg.color
	_frame.color.a = 0.9


func set_grid_pos(grid_x: int, grid_y: int) -> void:
	position = Vector2(
		grid_x * cell_size + cell_size * 0.5,
		grid_y * cell_size + cell_size * 0.5
	)
