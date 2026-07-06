## BattleCell — One cell of the battle grid.
##
## v0.10.10: SQUARE layout (was isometric diamond in v0.10.5+). Each
## cell is now a square sprite at the (x, y) grid position. The cell
## renders the terrain as a 40x40 sprite (was 56x56 in v0.10.10; v0.10.11
## reduced to 40px so the 7x7 grid fits cleanly with the TopPrompt
## and the bottom ActionBar/SkillBar), draws a square border, and a
## range highlight as a ColorRect on top of the terrain. This matches
## the overworld LocalMapView and reads as a proper FFT-style tactical
## grid.
class_name BattleCell extends Node2D

const HIGHLIGHT_NONE := 0
const HIGHLIGHT_MOVE := 1
const HIGHLIGHT_ATTACK := 2
const HIGHLIGHT_SKILL := 3
const HIGHLIGHT_CURSOR := 4

# v0.10.11 polish: move highlight is now a visible cyan tint
# (was white at 0.22 alpha — invisible against the light sand/
# ground terrain tiles). Cyan reads as "in move range" without
# competing with the terrain colors.
const COLOR_MOVE := Color(0.30, 0.85, 1.0, 0.40)
const COLOR_ATTACK := Color(0.95, 0.20, 0.20, 0.50)
const COLOR_SKILL := Color(0.65, 0.20, 0.90, 0.50)
const COLOR_CURSOR := Color(1.0, 0.95, 0.4, 0.55)
const HEIGHT_COLOR := Color(0.20, 0.18, 0.30, 0.85)
const BLOCKED_TINT := Color(0.15, 0.10, 0.08, 0.85)
const COLOR_BLOCKED_X := Color(0.85, 0.20, 0.20, 0.90)

# v0.10.10: cell border is a thin dark line (was 3px thick; on
# 40px square cells that looked too chunky and busy). 1px gives
# a clean grid outline without dominating the terrain.
# v0.10.11: CELL_SIZE 56 -> 40 so the 7x7 grid fits cleanly with
# the TopPrompt and the bottom ActionBar/SkillBar (no overlap).
const CELL_SIZE := 40
const BORDER_THICKNESS := 1
const TILE_NATIVE := 24.0

var grid_x: int = 0
var grid_y: int = 0
var height: int = 0
var is_blocked: bool = false
var terrain_kind: int = 0

var _base: Sprite2D
var _highlight: ColorRect
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


func _build_children() -> void:
	# v0.10.10: terrain sprite is the main visual. No dark floor
	# polygon — the terrain tile IS the floor. Scale the 24x24
	# native tile to fill the 40x40 cell with crisp nearest-neighbor
	# sampling (no rotation).
	_base = Sprite2D.new()
	_base.name = "Base"
	_base.centered = true
	_base.position = Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	_base.z_index = 0
	_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_base)

	# Highlight: a square ColorRect on top of the terrain. Default
	# invisible; HIGHLIGHT_MOVE / CURSOR fills with a tint,
	# HIGHLIGHT_ATTACK / SKILL uses the border ring instead.
	_highlight = ColorRect.new()
	_highlight.name = "Highlight"
	_highlight.color = Color(0, 0, 0, 0)
	_highlight.position = Vector2(0, 0)
	_highlight.size = Vector2(CELL_SIZE, CELL_SIZE)
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight.z_index = 3
	add_child(_highlight)

	# Border: 4 thin Line2Ds around the cell. v0.10.10 polish: always
	# visible as a dim warm-gray outline (was only visible on
	# ATTACK/SKILL). Without always-on borders, the 7x7 grid read as
	# a single mass of cells — the player couldn't see the squares.
	# HIGHLIGHT_ATTACK and HIGHLIGHT_SKILL brighten the border color
	# to make attack/skill range pop.
	_highlight_border = _build_square_outline()
	_highlight_border.visible = true
	add_child(_highlight_border)

	# Blocked-X overlay (two crossed lines).
	_blocked_x = _build_blocked_x()
	_blocked_x.visible = false
	add_child(_blocked_x)

	# Area2D with a square collision shape for click + hover routing.
	_area = Area2D.new()
	_area.name = "Area2D"
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(CELL_SIZE, CELL_SIZE)
	shape.shape = rect
	shape.position = Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	_area.add_child(shape)
	_area.position = Vector2.ZERO
	_area.input_pickable = true
	_area.z_index = 2
	add_child(_area)


## Build a square outline using 4 Line2Ds around the cell edges.
func _build_square_outline() -> Node2D:
	var wrap := Node2D.new()
	wrap.name = "OutlineBorder"
	wrap.z_index = 4
	# v0.10.10 polish: dim warm gray so the border is always visible
	# (was 0 alpha and only turned on for ATTACK/SKILL, leaving cells
	# looking like a single mass). The new value is subtle but enough
	# to read as a grid.
	var color: Color = Color(0.18, 0.16, 0.12, 0.55)
	var s: float = CELL_SIZE
	_add_line(wrap, PackedVector2Array([Vector2(0, 0), Vector2(s, 0)]), color, "EdgeTop")
	_add_line(wrap, PackedVector2Array([Vector2(s, 0), Vector2(s, s)]), color, "EdgeRight")
	_add_line(wrap, PackedVector2Array([Vector2(s, s), Vector2(0, s)]), color, "EdgeBottom")
	_add_line(wrap, PackedVector2Array([Vector2(0, s), Vector2(0, 0)]), color, "EdgeLeft")
	return wrap


func _add_line(parent: Node2D, pts: PackedVector2Array, color: Color, name_: String) -> void:
	var line := Line2D.new()
	line.name = name_
	line.width = BORDER_THICKNESS
	line.default_color = color
	line.points = pts
	parent.add_child(line)


## Red X overlay using two Line2Ds crossed at the cell center.
func _build_blocked_x() -> Node2D:
	var wrap := Node2D.new()
	wrap.name = "BlockedX"
	wrap.z_index = 5
	var pad: float = 6.0
	var s: float = CELL_SIZE
	# Diagonal from top-left to bottom-right
	_add_line(wrap, PackedVector2Array([Vector2(pad, pad), Vector2(s - pad, s - pad)]), COLOR_BLOCKED_X, "Diag1")
	# Diagonal from top-right to bottom-left
	_add_line(wrap, PackedVector2Array([Vector2(s - pad, pad), Vector2(pad, s - pad)]), COLOR_BLOCKED_X, "Diag2")
	return wrap


## v0.10.10: SQUARE grid setup. The cell sits at (x * CELL_SIZE,
## y * CELL_SIZE) with its top-left corner at the grid origin. The
## terrain sprite is centered in the cell and scaled to fill it.
func setup(x: int, y: int, terrain: int, h: int, blocked: bool, base_tex: Texture2D, cell_size: int) -> void:
	grid_x = x
	grid_y = y
	terrain_kind = terrain
	height = h
	is_blocked = blocked
	position = Vector2(x * cell_size, y * cell_size)
	if base_tex != null:
		var clipped := AtlasTexture.new()
		clipped.atlas = base_tex
		var row: int = clampi(terrain, 0, 4)
		clipped.region = Rect2(0, row * TILE_NATIVE, TILE_NATIVE, TILE_NATIVE)
		_base.texture = clipped
		# v0.10.10: scale the 24x24 terrain tile to fill the
		# cell_size x cell_size cell. No rotation, nearest-neighbor
		# for crisp pixel art.
		_base.position = Vector2(cell_size * 0.5, cell_size * 0.5)
		_base.rotation = 0.0
		var scl: float = float(cell_size) / TILE_NATIVE
		_base.scale = Vector2(scl, scl)
		_base.modulate = Color.WHITE
	else:
		_base.texture = null
		_base.modulate = _default_color(terrain)
		_base.scale = Vector2.ONE
	if height > 0:
		# Height marks: dim the base slightly to suggest elevation.
		_base.modulate = _base.modulate.lerp(HEIGHT_COLOR, 0.4)
	if blocked:
		_base.modulate = BLOCKED_TINT
		_blocked_x.visible = true
		_area.input_pickable = false
	else:
		_blocked_x.visible = false
		_area.input_pickable = true


## Legacy entry-point used by some smoke tests. Defaults to the
## square layout; the cell_size argument is accepted for callers
## passing a different size (e.g. test stubs).
func setup_iso(x: int, y: int, terrain: int, h: int, blocked: bool, base_tex: Texture2D, iso_pos: Vector2, cell_size: int) -> void:
	# v0.10.10: iso_pos is treated as the cell's top-left grid origin.
	# Callers that passed iso transforms should use setup() with (x, y)
	# now; this shim keeps legacy call sites working.
	position = iso_pos
	setup(x, y, terrain, h, blocked, base_tex, cell_size)


func set_highlight(kind: int) -> void:
	if _highlight == null:
		return
	# v0.10.10: border is always visible (dim warm gray). For ATTACK
	# / SKILL, the border color is swapped to a bright attack/skill
	# color so the range pops against the muted default border.
	match kind:
		HIGHLIGHT_MOVE:
			_highlight.color = COLOR_MOVE
			_highlight.visible = true
			_set_border_line_colors(Color(0.18, 0.16, 0.12, 0.55))
			_highlight_border.visible = true
		HIGHLIGHT_ATTACK:
			_highlight.color = Color(0, 0, 0, 0)
			_highlight.visible = false
			_set_border_line_colors(COLOR_ATTACK)
			_highlight_border.visible = true
		HIGHLIGHT_SKILL:
			_highlight.color = Color(0, 0, 0, 0)
			_highlight.visible = false
			_set_border_line_colors(COLOR_SKILL)
			_highlight_border.visible = true
		HIGHLIGHT_CURSOR:
			_highlight.color = COLOR_CURSOR
			_highlight.visible = true
			_set_border_line_colors(Color(0.18, 0.16, 0.12, 0.55))
			_highlight_border.visible = true
		_:
			_highlight.visible = false
			_set_border_line_colors(Color(0.18, 0.16, 0.12, 0.55))
			_highlight_border.visible = true


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
	# v0.10.10: height handled inline in setup() (modulate tint).
	# Kept as a no-op for backward compat.
	pass


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
