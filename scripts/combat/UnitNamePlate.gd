## UnitNamePlate — Small white-background name label with a thin
## dark border, placed above a unit. Sits between the unit's sprite
## and the turn order bar so the player can read which unit is which
## at a glance. The plate fades in/out and follows the unit's cell.
class_name UnitNamePlate extends Control

const BG_COLOR := Color(1.0, 1.0, 1.0, 0.92)
const BORDER_COLOR := Color(0.10, 0.08, 0.05, 0.95)
const BOSS_COLOR := Color(1.0, 0.85, 0.35, 1.0)
const ALLY_COLOR := Color(0.45, 0.75, 1.0, 1.0)
const PLAYER_COLOR := Color(0.45, 0.95, 0.55, 1.0)
const ENEMY_COLOR := Color(1.0, 0.55, 0.45, 1.0)
const WIDTH := 80
const HEIGHT := 16
const PADDING := 4
var _bg: ColorRect
var _label: Label
var _team_color: Color = ENEMY_COLOR
var _tween: Tween = null


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_children()


func _build_children() -> void:
	# Background panel (white) + thin border via a parent ColorRect.
	var border := ColorRect.new()
	border.name = "Border"
	border.color = BORDER_COLOR
	border.size = Vector2(WIDTH + 2, HEIGHT + 2)
	border.position = Vector2(-1, -1)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)
	# Background is a ColorRect (NinePatchRect has no `color` prop).
	_bg = ColorRect.new()
	_bg.name = "Bg"
	_bg.color = BG_COLOR
	_bg.size = Vector2(WIDTH, HEIGHT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_label = Label.new()
	_label.name = "Name"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size = Vector2(WIDTH, HEIGHT)
	_label.add_theme_color_override("font_color", _team_color)
	_label.add_theme_color_override("font_outline_color", Color.WHITE)
	_label.add_theme_constant_override("outline_size", 0)
	_label.add_theme_font_size_override("font_size", 9)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func set_unit_info(display_name: String, team: String, is_boss: bool) -> void:
	_label.text = display_name
	if is_boss:
		_team_color = BOSS_COLOR
	elif team == "player":
		_team_color = PLAYER_COLOR
	elif team == "ally":
		_team_color = ALLY_COLOR
	else:
		_team_color = ENEMY_COLOR
	_label.add_theme_color_override("font_color", _team_color)
	# Bosses get a gold tint on the bg.
	if is_boss:
		_bg.color = Color(1.0, 0.95, 0.80, 0.95)
	else:
		_bg.color = BG_COLOR


## Position the plate at a unit's cell. The plate sits above the
## unit's sprite (CELL_SIZE * 0.5 above the cell top edge).
func snap_to_cell(cell_x: int, cell_y: int, cell_size: int) -> void:
	position = Vector2(
		cell_x * cell_size + cell_size * 0.5 - WIDTH * 0.5,
		cell_y * cell_size - HEIGHT - 6
	)


func set_visible_fade(v: bool) -> void:
	if v:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		modulate = Color(1, 1, 1, 0)
		visible = true
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	else:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 0.0, 0.2)
		_tween.tween_callback(func(): visible = false)
