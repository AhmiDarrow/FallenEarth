## BattleCell — One cell of the battle grid.
##
## Renders the terrain tile as a diamond (rotated 45°), optional
## height offset, and a range highlight. Click routes back to the
## parent grid view. v0.10.5: isometric diamond with Polygon2D
## highlights that match the diamond geometry exactly.
class_name BattleCell extends Node2D

const HIGHLIGHT_NONE := 0
const HIGHLIGHT_MOVE := 1
const HIGHLIGHT_ATTACK := 2
const HIGHLIGHT_SKILL := 3
const HIGHLIGHT_CURSOR := 4

const COLOR_MOVE := Color(1.0, 1.0, 1.0, 0.42)
const COLOR_ATTACK := Color(0.95, 0.20, 0.20, 0.55)
const COLOR_SKILL := Color(0.65, 0.20, 0.90, 0.55)
const COLOR_CURSOR := Color(1.0, 0.95, 0.4, 0.65)
const HEIGHT_COLOR := Color(0.20, 0.18, 0.30, 0.85)
const BLOCKED_TINT := Color(0.15, 0.10, 0.08, 0.85)
const COLOR_BLOCKED_X := Color(0.85, 0.20, 0.20, 0.90)

const CELL_SIZE := 56
const BORDER_THICKNESS := 3
const TILE_NATIVE := 24.0
const DIAMOND_DIAG := 33.94
const DIAMOND_SCALE := CELL_SIZE / DIAMOND_DIAG

var grid_x: int = 0
var grid_y: int = 0
var height: int = 0
var is_blocked: bool = false
var terrain_kind: int = 0

var _base: Sprite2D
var _height_label: Label
var _highlight: Polygon2D
var _highlight_border: Node2D
var _blocked_x: Node2D
var _area: Area2D

signal clicked(x: int, y: int)
signal hover_changed(x: int, y: int, hovered: bool)


func _ready() -> void:
	_build_children()
	_area.input_event.connect(_on_input_event)
	_area.mouse_entered.connect(_on_mouse_entered)
	_area.mouse_exited.connect(_on_mouse_exited)
	set_highlight(HIGHLIGHT_NONE)


## Diamond vertices centered in the CELL_SIZE box.
## Top, right, bottom, left: a diamond fitting a 56×56 bounding square.
func _diamond_pts() -> PackedVector2Array:
	var hw: float = CELL_SIZE * 0.5
	return PackedVector2Array([
		Vector2(hw, 0),           # top
		Vector2(CELL_SIZE, hw),   # right
		Vector2(hw, CELL_SIZE),   # bottom
		Vector2(0, hw),           # left
	])


func _build_children() -> void:
	_base = Sprite2D.new()
	_base.name = "Base"
	_base.centered = true
	_base.position = Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	_base.z_index = 0
	_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # keep pixel art crisp at 45° rotation
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

	# Highlight: a filled Polygon2D diamond (default invisible).
	_highlight = Polygon2D.new()
	_highlight.name = "Highlight"
	_highlight.polygon = _diamond_pts()
	_highlight.color = Color(0, 0, 0, 0)
	_highlight.z_index = 3
	add_child(_highlight)

	# Border: an outline Polygon2D diamond drawn as a ring.
	_highlight_border = _build_diamond_outline()
	_highlight_border.visible = false
	add_child(_highlight_border)

	# Blocked-X overlay (two crossed lines inside the diamond).
	_blocked_x = _build_blocked_diamond_x()
	_blocked_x.visible = false
	add_child(_blocked_x)

	# Area2D with a convex polygon shape matching the diamond.
	_area = Area2D.new()
	_area.name = "Area2D"
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var poly := ConvexPolygonShape2D.new()
	poly.points = _diamond_pts()
	shape.shape = poly
	_area.add_child(shape)
	_area.position = Vector2.ZERO
	_area.input_pickable = true
	_area.z_index = 2
	add_child(_area)


## Diamond border outline using 4 Line2Ds at the diamond edges.
## This gives the FFT-style "highlighted tile" outline without
## relying on self-intersecting Polygon2D (which doesn't support
## holes in Godot's renderer).
func _build_diamond_outline() -> Node2D:
	var wrap := Node2D.new()
	wrap.name = "OutlineBorder"
	wrap.z_index = 4
	var hw: float = CELL_SIZE * 0.5
	var color: Color = Color(0, 0, 0, 0)
	# Top-left edge: (0, hw) → (hw, 0)
	_add_line(wrap, PackedVector2Array([Vector2(0, hw), Vector2(hw, 0)]), color, "EdgeTL")
	# Top-right edge: (hw, 0) → (CELL_SIZE, hw)
	_add_line(wrap, PackedVector2Array([Vector2(hw, 0), Vector2(CELL_SIZE, hw)]), color, "EdgeTR")
	# Bottom-right edge: (CELL_SIZE, hw) → (hw, CELL_SIZE)
	_add_line(wrap, PackedVector2Array([Vector2(CELL_SIZE, hw), Vector2(hw, CELL_SIZE)]), color, "EdgeBR")
	# Bottom-left edge: (hw, CELL_SIZE) → (0, hw)
	_add_line(wrap, PackedVector2Array([Vector2(hw, CELL_SIZE), Vector2(0, hw)]), color, "EdgeBL")
	return wrap


func _add_line(parent: Node2D, pts: PackedVector2Array, color: Color, name_: String) -> void:
	var line := Line2D.new()
	line.name = name_
	line.width = BORDER_THICKNESS
	line.default_color = color
	line.points = pts
	parent.add_child(line)


## Red X overlay using two Line2Ds crossed at the diamond center.
func _build_blocked_diamond_x() -> Node2D:
	var wrap := Node2D.new()
	wrap.name = "BlockedX"
	wrap.z_index = 5
	var pad := BORDER_THICKNESS
	# Diagonal from top-left to bottom-right
	_add_line(wrap, PackedVector2Array([Vector2(pad, pad), Vector2(CELL_SIZE - pad, CELL_SIZE - pad)]), COLOR_BLOCKED_X, "Diag1")
	# Diagonal from top-right to bottom-left
	_add_line(wrap, PackedVector2Array([Vector2(CELL_SIZE - pad, pad), Vector2(pad, CELL_SIZE - pad)]), COLOR_BLOCKED_X, "Diag2")
	return wrap


func setup_iso(x: int, y: int, terrain: int, h: int, blocked: bool, base_tex: Texture2D, iso_pos: Vector2, cell_size: int) -> void:
	grid_x = x
	grid_y = y
	terrain_kind = terrain
	height = h
	is_blocked = blocked
	position = iso_pos
	if base_tex != null:
		var clipped := AtlasTexture.new()
		clipped.atlas = base_tex
		var row: int = clampi(terrain, 0, 4)
		clipped.region = Rect2(0, row * TILE_NATIVE, TILE_NATIVE, TILE_NATIVE)
		_base.texture = clipped
		_base.rotation = PI / 4.0
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


func setup(x: int, y: int, terrain: int, h: int, blocked: bool, base_tex: Texture2D) -> void:
	setup_iso(x, y, terrain, h, blocked, base_tex, Vector2(x * CELL_SIZE, y * CELL_SIZE), CELL_SIZE)


func set_highlight(kind: int) -> void:
	if _highlight == null:
		return
	match kind:
		HIGHLIGHT_MOVE:
			_highlight.color = COLOR_MOVE
			_highlight.visible = true
			_set_border_visible(false)
		HIGHLIGHT_ATTACK:
			_highlight.color = Color(0, 0, 0, 0)
			_highlight.visible = false
			_set_border_line_colors(COLOR_ATTACK)
			_set_border_visible(true)
		HIGHLIGHT_SKILL:
			_highlight.color = Color(0, 0, 0, 0)
			_highlight.visible = false
			_set_border_line_colors(COLOR_SKILL)
			_set_border_visible(true)
		HIGHLIGHT_CURSOR:
			_highlight.color = COLOR_CURSOR
			_highlight.visible = true
			_set_border_visible(false)
		_:
			_highlight.visible = false
			_set_border_visible(false)


func _set_border_visible(v: bool) -> void:
	if _highlight_border == null:
		return
	_highlight_border.visible = v


func _set_border_line_colors(c: Color) -> void:
	if _highlight_border == null:
		return
	for child in _highlight_border.get_children():
		if child is Line2D:
			(child as Line2D).default_color = c


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
