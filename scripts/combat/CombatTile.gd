class_name CombatTile
extends Node2D
## One tile of the combat grid. The visual; reads its state from
## the TileResource it owns.
##
## Adapted from ramaureirac/godot-tactical-rpg `TacticsTile` —
## same flag-driven visual update, same area2d for input.
##
## The CombatTile is much simpler than the reference: the
## Resource owns the state, the tile only renders.

const CELL_SIZE: int = 60
const BORDER_THICKNESS: int = 1
const TILE_NATIVE: float = 24.0

## v0.11.0: The TileResource this tile reads from. Set by
## CombatArena when it builds the grid.
var res: TileResource

## v0.11.0: Visual children
var _base: Sprite2D
var _highlight: ColorRect
var _border: Node2D
var _blocked_x: Node2D
var _area: Area2D

## v0.11.0: Default border color (subtle, always visible)
const COLOR_BORDER := Color(0.18, 0.16, 0.12, 0.55)
## v0.11.0: Highlight colors
const COLOR_MOVE := Color(0.30, 0.85, 1.0, 0.40)
const COLOR_ATTACK := Color(0.95, 0.20, 0.20, 0.50)
const COLOR_CURSOR := Color(1.0, 0.95, 0.4, 0.55)
## v0.11.0: Border colors for attack/skill range
const COLOR_BORDER_ATTACK := Color(0.95, 0.20, 0.20, 0.90)
const COLOR_BORDER_SKILL := Color(0.65, 0.20, 0.90, 0.90)

signal clicked(grid_x: int, grid_y: int)
signal hover_changed(grid_x: int, grid_y: int, hovered: bool)


func _ready() -> void:
	_build_children()
	_area.input_event.connect(_on_input)
	_area.mouse_entered.connect(_on_mouse_in)
	_area.mouse_exited.connect(_on_mouse_out)


## v0.11.0: Build the visual children. We rebuild them on
## _ready because each tile has the same structure; the
## `setup()` call below sets the texture + size.
func _build_children() -> void:
	# Base terrain sprite (set texture on setup)
	_base = Sprite2D.new()
	_base.name = "Base"
	_base.centered = true
	_base.position = Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	_base.z_index = 0
	_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_base)

	# Highlight color rect (set color on update)
	_highlight = ColorRect.new()
	_highlight.name = "Highlight"
	_highlight.color = Color(0, 0, 0, 0)
	_highlight.position = Vector2.ZERO
	_highlight.size = Vector2(CELL_SIZE, CELL_SIZE)
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight.z_index = 3
	add_child(_highlight)

	# Always-visible thin border (4 Line2Ds)
	_border = _build_border()
	_border.z_index = 4
	add_child(_border)

	# Blocked-X overlay
	_blocked_x = _build_blocked_x()
	_blocked_x.visible = false
	add_child(_blocked_x)

	# Click + hover area
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


func _build_border() -> Node2D:
	var wrap := Node2D.new()
	wrap.name = "Border"
	var s: float = float(CELL_SIZE)
	_add_line(wrap, PackedVector2Array([Vector2(0, 0), Vector2(s, 0)]), COLOR_BORDER, "EdgeTop")
	_add_line(wrap, PackedVector2Array([Vector2(s, 0), Vector2(s, s)]), COLOR_BORDER, "EdgeRight")
	_add_line(wrap, PackedVector2Array([Vector2(s, s), Vector2(0, s)]), COLOR_BORDER, "EdgeBottom")
	_add_line(wrap, PackedVector2Array([Vector2(0, s), Vector2(0, 0)]), COLOR_BORDER, "EdgeLeft")
	return wrap


func _add_line(parent: Node2D, pts: PackedVector2Array, color: Color, name_: String) -> void:
	var line := Line2D.new()
	line.name = name_
	line.width = BORDER_THICKNESS
	line.default_color = color
	line.points = pts
	parent.add_child(line)


func _build_blocked_x() -> Node2D:
	var wrap := Node2D.new()
	wrap.name = "BlockedX"
	wrap.z_index = 5
	var pad: float = 6.0
	var s: float = float(CELL_SIZE)
	_add_line(wrap, PackedVector2Array([Vector2(pad, pad), Vector2(s - pad, s - pad)]), COLOR_BORDER_ATTACK, "Diag1")
	_add_line(wrap, PackedVector2Array([Vector2(s - pad, pad), Vector2(pad, s - pad)]), COLOR_BORDER_ATTACK, "Diag2")
	return wrap


## v0.11.0: Configure the tile with its grid coordinates,
## terrain kind, and base texture. Called by CombatArena when
## it builds the grid.
func setup(grid_x: int, grid_y: int, terrain: int, base_tex: Texture2D) -> void:
	res = TileResource.new()
	res.grid_x = grid_x
	res.grid_y = grid_y
	res.terrain_kind = terrain
	res.blocked = (terrain == 3)  # TERRAIN_BLOCKED
	position = Vector2(grid_x * CELL_SIZE, grid_y * CELL_SIZE)
	if base_tex != null:
		# Use AtlasTexture to clip the right terrain row out of
		# the biome atlas (24x120 → 5 rows of 24x24).
		var clipped := AtlasTexture.new()
		clipped.atlas = base_tex
		var row: int = clampi(terrain, 0, 4)
		clipped.region = Rect2(0, row * TILE_NATIVE, TILE_NATIVE, TILE_NATIVE)
		_base.texture = clipped
		var scl: float = float(CELL_SIZE) / TILE_NATIVE
		_base.scale = Vector2(scl, scl)
	else:
		_base.texture = null
	_blocked_x.visible = res.blocked
	_area.input_pickable = not res.blocked


## v0.11.0: Refresh the visual based on the TileResource's
## state flags. Called every frame from CombatArena.
func refresh() -> void:
	if res == null:
		return
	# Move highlight
	if res.reachable and not res.attackable:
		_highlight.color = COLOR_MOVE
		_highlight.visible = true
		_set_border_color(COLOR_BORDER)
	# Attack highlight
	elif res.attackable:
		_highlight.color = Color(0, 0, 0, 0)
		_highlight.visible = false
		_set_border_color(COLOR_BORDER_ATTACK)
	# Cursor hover (on top of move highlight)
	elif res.hover:
		_highlight.color = COLOR_CURSOR
		_highlight.visible = true
		_set_border_color(COLOR_BORDER)
	# Default: border only
	else:
		_highlight.color = Color(0, 0, 0, 0)
		_highlight.visible = false
		_set_border_color(COLOR_BORDER)
	# Tile visibility if blocked
	_blocked_x.visible = res.blocked


func _set_border_color(color: Color) -> void:
	if _border == null:
		return
	for child in _border.get_children():
		if child is Line2D:
			(child as Line2D).default_color = color


func _on_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(res.grid_x, res.grid_y)


func _on_mouse_in() -> void:
	hover_changed.emit(res.grid_x, res.grid_y, true)


func _on_mouse_out() -> void:
	hover_changed.emit(res.grid_x, res.grid_y, false)
