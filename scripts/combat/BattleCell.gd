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

# FFT-style: move range is a soft white tint (semi-transparent so the
# ground texture still shows through), attack is a red X-overlay, and
# skill is a purple X-overlay. Stronger alpha than the old full-cell
# tints so the cells really pop without hiding the ground.
const COLOR_MOVE := Color(1.0, 1.0, 1.0, 0.42)
const COLOR_ATTACK := Color(0.95, 0.20, 0.20, 0.55)
const COLOR_SKILL := Color(0.65, 0.20, 0.90, 0.55)
const COLOR_CURSOR := Color(1.0, 0.95, 0.4, 0.65)
const HEIGHT_COLOR := Color(0.20, 0.18, 0.30, 0.85)
# v0.10.4: blocked cells are now a very dark version of the
# ground texture (not pure black), with a red X overlay so the
# player reads "can't walk here" without it looking like a
# rendering bug.
const BLOCKED_TINT := Color(0.15, 0.10, 0.08, 0.85)
const COLOR_BLOCKED_X := Color(0.85, 0.20, 0.20, 0.90)

const CELL_SIZE := 56
# Border thickness for the FFT-style edge frame. Chunky enough to
# read as a "highlighted tile" without obscuring the ground.
const BORDER_THICKNESS := 3
# v0.10.5: the ground tile is 24x24 native. When rotated 45°, its
# diagonal (tip-to-tip) is 24 * sqrt(2) ≈ 34 px. We scale by
# CELL_SIZE/DIAMOND_DIAG so the diamond fills the cell footprint.
const TILE_NATIVE := 24.0
const DIAMOND_DIAG := 33.94  # TILE_NATIVE * sqrt(2)
const DIAMOND_SCALE := CELL_SIZE / DIAMOND_DIAG  # ~1.65 at 56

var grid_x: int = 0
var grid_y: int = 0
var height: int = 0
var is_blocked: bool = false
var terrain_kind: int = 0

var _base: Sprite2D
var _height_label: Label
var _highlight: ColorRect
var _highlight_border: Control
var _blocked_x: Control
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
	# v0.10.5: diamond border built as a Polygon2D.
	_highlight_border = _build_border()
	_highlight_border.visible = false
	add_child(_highlight_border)
	# v0.10.4: red X overlay for blocked cells.
	_blocked_x = _build_blocked_x()
	_blocked_x.visible = false
	add_child(_blocked_x)

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
	setup_iso(x, y, terrain, h, blocked, base_tex, Vector2(x * CELL_SIZE, y * CELL_SIZE), CELL_SIZE)


## v0.10.5: isometric variant. The cell is positioned at `iso_pos`
## (the output of BattleGridView.cell_to_iso) and the base sprite is
## rotated 45° to form a diamond. cell_size is the tip-to-tip size
## of the diamond (typically BattleGridView.CELL_SIZE).
func setup_iso(x: int, y: int, terrain: int, h: int, blocked: bool, base_tex: Texture2D, iso_pos: Vector2, cell_size: int) -> void:
	grid_x = x
	grid_y = y
	terrain_kind = terrain
	height = h
	is_blocked = blocked
	position = iso_pos
	if base_tex != null:
		# v0.10.5: extract the 24x24 terrain row via AtlasTexture,
		# then set the sprite rotation to 45° and apply the diamond
		# scale so the tile forms a clean diamond at the cell size.
		var clipped := AtlasTexture.new()
		clipped.atlas = base_tex
		var row: int = clampi(terrain, 0, 4)
		clipped.region = Rect2(0, row * TILE_NATIVE, TILE_NATIVE, TILE_NATIVE)
		_base.texture = clipped
		_base.rotation = PI / 4.0  # 45° for diamond
		var scl: float = float(cell_size) / DIAMOND_DIAG
		_base.scale = Vector2(scl, scl)
		_base.modulate = Color.WHITE
	else:
		_base.texture = null
		_base.rotation = PI / 4.0
		_base.modulate = _default_color(terrain)
		_base.scale = Vector2.ONE
	if height > 0:
		_height_label.text = str(height)
		_height_label.visible = true
	else:
		_height_label.text = ""
		_height_label.visible = false
	if blocked:
		_base.modulate = BLOCKED_TINT
		_blocked_x.visible = true
		_area.input_pickable = false
	else:
		_blocked_x.visible = false
		_area.input_pickable = true
	refresh_height_visual()


func set_highlight(kind: int) -> void:
	if _highlight == null:
		return
	match kind:
		HIGHLIGHT_MOVE:
			_highlight.color = COLOR_MOVE
			_highlight.visible = true
			_set_border_color(COLOR_MOVE)
		HIGHLIGHT_ATTACK:
			_highlight.color = Color(0, 0, 0, 0)
			_highlight.visible = false
			_set_border_color(COLOR_ATTACK)
			_highlight_border.visible = true
			return
		HIGHLIGHT_SKILL:
			_highlight.color = Color(0, 0, 0, 0)
			_highlight.visible = false
			_set_border_color(COLOR_SKILL)
			_highlight_border.visible = true
			return
		HIGHLIGHT_CURSOR:
			_highlight.color = COLOR_CURSOR
			_highlight.visible = true
			_set_border_color(COLOR_CURSOR)
		_:
			_highlight.visible = false
			_highlight_border.visible = false


## Build a 4-edge diamond border via Polygon2D. The border uses
## a hollow diamond (four strips at the edge) so the highlight
## reads as a "target tile outline" not a solid fill.
func _build_border() -> Control:
	var wrap := Control.new()
	wrap.name = "HighlightBorder"
	wrap.set_anchors_preset(Control.PRESET_TOP_LEFT)
	wrap.size = Vector2(CELL_SIZE, CELL_SIZE)
	wrap.position = Vector2.ZERO
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.z_index = 4
	# Top edge
	var t := _mk_edge_rect(Vector2(CELL_SIZE * 0.5 - CELL_SIZE * 0.4, 0), Vector2(CELL_SIZE * 0.8, BORDER_THICKNESS))
	wrap.add_child(t)
	# Bottom edge
	var b := _mk_edge_rect(Vector2(CELL_SIZE * 0.5 - CELL_SIZE * 0.4, CELL_SIZE - BORDER_THICKNESS), Vector2(CELL_SIZE * 0.8, BORDER_THICKNESS))
	wrap.add_child(b)
	# Left edge
	var l := _mk_edge_rect(Vector2(0, CELL_SIZE * 0.5 - CELL_SIZE * 0.4), Vector2(BORDER_THICKNESS, CELL_SIZE * 0.8))
	wrap.add_child(l)
	# Right edge
	var r := _mk_edge_rect(Vector2(CELL_SIZE - BORDER_THICKNESS, CELL_SIZE * 0.5 - CELL_SIZE * 0.4), Vector2(BORDER_THICKNESS, CELL_SIZE * 0.8))
	wrap.add_child(r)
	return wrap


func _mk_edge_rect(pos: Vector2, sz: Vector2) -> ColorRect:
	var cr := ColorRect.new()
	cr.color = COLOR_MOVE
	cr.size = sz
	cr.position = pos
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cr


func _set_border_color(c: Color) -> void:
	if _highlight_border == null:
		return
	for child in _highlight_border.get_children():
		(child as ColorRect).color = c


## Build a red X overlay (two crossed ColorRects) for blocked
## cells. The X is sized to the cell minus 8px padding so the
## border is visible.
func _build_blocked_x() -> Control:
	var wrap := Control.new()
	wrap.name = "BlockedX"
	wrap.set_anchors_preset(Control.PRESET_TOP_LEFT)
	wrap.size = Vector2(CELL_SIZE, CELL_SIZE)
	wrap.position = Vector2.ZERO
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.z_index = 5
	var diag1 := ColorRect.new()
	diag1.color = COLOR_BLOCKED_X
	diag1.size = Vector2(CELL_SIZE - 8, 3)
	diag1.position = Vector2(4, CELL_SIZE * 0.5 - 1.5)
	diag1.rotation = 0.7854  # 45 deg in radians
	diag1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(diag1)
	var diag2 := ColorRect.new()
	diag2.color = COLOR_BLOCKED_X
	diag2.size = Vector2(CELL_SIZE - 8, 3)
	diag2.position = Vector2(4, CELL_SIZE * 0.5 - 1.5)
	diag2.rotation = -0.7854  # -45 deg in radians
	diag2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(diag2)
	return wrap


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
