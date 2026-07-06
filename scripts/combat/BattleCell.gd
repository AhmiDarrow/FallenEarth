## BattleCell — One cell of the battle grid.
##
## Renders the terrain tile, optional height offset, and a range highlight
## (move/attack/skill). Click routes back to the parent grid view.
class_name BattleCell extends Node2D

const HIGHLIGHT_NONE := 0
const HIGHLIGHT_MOVE := 1
const HIGHLIGHT_ATTACK := 2
const HIGHLIGHT_SKILL := 3
const HIGHLIGHT_CURSOR := 4

const COLOR_MOVE := Color(0.20, 0.55, 0.85, 0.45)
const COLOR_ATTACK := Color(0.90, 0.20, 0.20, 0.55)
const COLOR_SKILL := Color(0.65, 0.20, 0.90, 0.50)
const COLOR_CURSOR := Color(1.0, 0.95, 0.4, 0.55)
const HEIGHT_COLOR := Color(0.20, 0.18, 0.30, 0.85)
const BLOCKED_TINT := Color(0.05, 0.04, 0.08, 1.0)

const CELL_SIZE := 24

var grid_x: int = 0
var grid_y: int = 0
var height: int = 0
var is_blocked: bool = false
var terrain_kind: int = 0

var _base: Sprite2D
var _height_label: Label
var _highlight: ColorRect
var _area: Area2D

signal clicked(x: int, y: int)
signal hover_changed(x: int, y: int, hovered: bool)


func _ready() -> void:
	_build_children()
	_area.input_event.connect(_on_input_event)
	_area.mouse_entered.connect(_on_mouse_entered)
	_area.mouse_exited.connect(_on_mouse_exited)
	set_highlight(HIGHLIGHT_NONE)


func _build_children() -> void:
	_base = Sprite2D.new()
	_base.name = "Base"
	_base.centered = true
	_base.position = Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	_base.z_index = 0
	add_child(_base)

	_height_label = Label.new()
	_height_label.name = "HeightLabel"
	_height_label.text = ""
	_height_label.add_theme_color_override("font_color", Color.WHITE)
	_height_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_height_label.add_theme_constant_override("outline_size", 2)
	_height_label.add_theme_font_size_override("font_size", 8)
	_height_label.position = Vector2(2, 2)
	_height_label.visible = false
	_height_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_height_label.z_index = 5
	add_child(_height_label)

	_highlight = ColorRect.new()
	_highlight.name = "Highlight"
	_highlight.color = Color(0, 0, 0, 0)
	_highlight.position = Vector2.ZERO
	_highlight.size = Vector2(CELL_SIZE, CELL_SIZE)
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight.z_index = 3
	add_child(_highlight)

	_area = Area2D.new()
	_area.name = "Area2D"
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(CELL_SIZE, CELL_SIZE)
	shape.shape = rect
	_area.add_child(shape)
	_area.position = Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	_area.input_pickable = true
	_area.z_index = 2
	add_child(_area)


func setup(x: int, y: int, terrain: int, h: int, blocked: bool, base_tex: Texture2D) -> void:
	grid_x = x
	grid_y = y
	terrain_kind = terrain
	height = h
	is_blocked = blocked
	position = Vector2(x * CELL_SIZE, y * CELL_SIZE)
	if base_tex != null:
		_base.texture = base_tex
		_base.modulate = Color.WHITE
	else:
		_base.texture = null
		_base.modulate = _default_color(terrain)
	if height > 0:
		_height_label.text = str(height)
		_height_label.visible = true
	else:
		_height_label.text = ""
		_height_label.visible = false
	if blocked:
		_base.modulate = BLOCKED_TINT
		_area.input_pickable = false
	else:
		_area.input_pickable = true
	refresh_height_visual()


func set_highlight(kind: int) -> void:
	if _highlight == null:
		return
	match kind:
		HIGHLIGHT_MOVE:
			_highlight.color = COLOR_MOVE
			_highlight.visible = true
		HIGHLIGHT_ATTACK:
			_highlight.color = COLOR_ATTACK
			_highlight.visible = true
		HIGHLIGHT_SKILL:
			_highlight.color = COLOR_SKILL
			_highlight.visible = true
		HIGHLIGHT_CURSOR:
			_highlight.color = COLOR_CURSOR
			_highlight.visible = true
		_:
			_highlight.visible = false


func refresh_height_visual() -> void:
	if _base == null:
		return
	if height > 0:
		_base.position = Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5 - height * 4)
		_base.modulate = _base.modulate.lerp(HEIGHT_COLOR, 0.4)
	else:
		_base.position = Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)


func _default_color(terrain: int) -> Color:
	match terrain:
		0:
			return Color(0.32, 0.30, 0.26)
		1:
			return Color(0.40, 0.32, 0.20)
		2:
			return Color(0.18, 0.32, 0.16)
		3:
			return BLOCKED_TINT
		_:
			return Color(0.25, 0.22, 0.20)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(grid_x, grid_y)


func _on_mouse_entered() -> void:
	hover_changed.emit(grid_x, grid_y, true)


func _on_mouse_exited() -> void:
	hover_changed.emit(grid_x, grid_y, false)
