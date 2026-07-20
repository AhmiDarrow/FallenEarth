## Minimap — Local overworld map showing the player's 512×512 hex region.
##
## v0.4.0 polish: terrain-tinted cell colours, category-coloured entity
## dots, and a forward-facing player-direction arrow.
##
## Layers in render order (back-to-front):
##   1. Background + OOB corner tints
##   2. Terrain tint rect per cell (ground / debris / vegetation / blocked / water)
##   3. Faint grid lines every 4 cells
##   4. Category-coloured entity dots (resource / mob-hostile / mob-neutral /
##      rift / NPC / town)
##   5. Player marker (yellow circle + white cross + 4-direction arrow
##      showing facing direction)
##
## Earlier revisions of this minimap added a strategic hex-sphere view
## to the top of the same panel — that was removed (use the WorldMapScreen
## press-M for it) so this panel focuses on the LOCAL overworld only.
class_name Minimap
extends Control

const WIDTH_PX := 240.0
const HEIGHT_PX := 160.0
const CELL_PX := 1.5  # one local cell == 1.5 minimap pixels
const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")

const BG_COLOR := Color(0.04, 0.04, 0.06, 0.85)
const OOB_COLOR := Color(0.10, 0.10, 0.12, 0.85)
var PLAYER_COLOR: Color = Color(0.20, 0.85, 0.95, 1.0)
const PLAYER_OUTLINE := Color(0.95, 0.95, 0.95, 1.0)
const GRID_COLOR := Color(0.18, 0.18, 0.20, 0.40)

# Terrain tints — one per LocalMapGenerator terrain index.
const TERRAIN_TINTS: Array[Color] = [
	Color(0.78, 0.69, 0.50, 1.0),    # 0 GROUND        — beige
	Color(0.45, 0.38, 0.30, 1.0),    # 1 DEBRIS        — darker brown
	Color(0.30, 0.50, 0.30, 1.0),    # 2 VEGETATION    — forest green
	Color(0.18, 0.16, 0.14, 1.0),    # 3 BLOCKED        — slate
	Color(0.25, 0.55, 0.65, 1.0),    # 4 WATER          — teal
]

# Entity category colours.
const RESOURCE_TREE_COLOR  := Color(0.55, 0.85, 0.45, 1.0)  # green
const RESOURCE_ORE_COLOR   := Color(0.85, 0.65, 0.30, 1.0)  # amber
const RESOURCE_CRYST_COLOR := Color(0.65, 0.50, 0.95, 1.0)  # purple
const RESOURCE_DEFAULT_COLOR := Color(0.85, 0.75, 0.50, 1.0) # amber
const MOB_HOSTILE_COLOR := MT.MM_MOB_HOSTILE
const MOB_NEUTRAL_COLOR := MT.MM_MOB_NEUTRAL
const RIFT_COLOR := MT.MM_RIFT
const NPC_COLOR := Color(0.50, 0.85, 0.95, 1.0)
const TOWN_COLOR := Color(0.42, 0.78, 0.88, 1.0)

const DARKEN_FACTOR := 0.85  # muted shade of base colour for non-resource dots

var _terrain: PackedByteArray = PackedByteArray()
var _cell_range_x: int = 80   # cells horizontally visible (240/CELL_PX)
var _cell_range_y: int = 53   # cells vertically visible (160/CELL_PX)
var _player_cell: Vector2i = Vector2i.ZERO
var _player_facing: int = 0   # 0=S 1=SW 2=W 3=NW 4=N 5=NE 6=E 7=SE
var _mobs: Array = []         # [{local_x, local_y, hostile}]
var _resources: Array = []    # [{local_x, local_y, sprite_id}]
var _rifts: Array = []        # [{local_x, local_y}]
var _npcs: Array = []         # [{local_x, local_y, name}]
var _terrain_summary: String = ""

var _last_cell_change_msec: int = 0  # throttle heavy draw ops


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH_PX, HEIGHT_PX)
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -WIDTH_PX - 12
	offset_top = 12
	offset_right = -12
	offset_bottom = HEIGHT_PX + 12
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(WIDTH_PX, HEIGHT_PX)
	# Theme colours resolved at runtime so the constants don't need to
	# be initialised early.
	if MT != null:
		if "MM_PLAYER" in MT:
			PLAYER_COLOR = MT.MM_PLAYER
	call_deferred("_refresh_from_gamestate")
	call_deferred("queue_redraw")


func _cell_to_pos(lx: int, ly: int, center: Vector2) -> Vector2:
	var dx: float = float(lx - _player_cell.x) * CELL_PX
	var dy: float = float(ly - _player_cell.y) * CELL_PX
	return center + Vector2(dx, dy)


func _in_bounds(p: Vector2) -> bool:
	return p.x >= 0 and p.x <= WIDTH_PX and p.y >= 0 and p.y <= HEIGHT_PX


## Pull current data from GameState and refresh the cache.
func _refresh_from_gamestate() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if gs == null:
		return
	var local_pos: Vector2i = gs.get_local_position()
	_player_cell = local_pos
	_terrain_summary = "%s  %s" % [str(gs.get_current_hex_state().get("biome", "?")), str(local_pos)]
	# Mobs in the current hex
	var prefix: String = "%d,%d|" % [gs.get_player_position().x, gs.get_player_position().y]
	_mobs = []
	var mobs: Dictionary = gs.get_overworld_mobs()
	for mob_key in mobs.keys():
		if not str(mob_key).begins_with(prefix):
			continue
		var rest: String = str(mob_key).substr(prefix.length())
		var mparts: PackedStringArray = rest.split(",")
		if mparts.size() < 2:
			continue
		var mob_data: Dictionary = mobs[mob_key] as Dictionary
		_mobs.append({
			"local_x": int(mparts[0]),
			"local_y": int(mparts[1]),
			"hostile": bool(mob_data.get("hostile", true)),
		})
	# Resources and terrain
	_resources = []
	_rifts = []
	_npcs = []
	var root_node := get_tree().root if get_tree() != null else null
	var mv: Node = null
	if root_node != null:
		mv = root_node.find_child("LocalMapView", true, false)
	if mv != null and mv.has_method("get_resource_nodes"):
		for n in mv.get_resource_nodes():
			if not (n is Node2D):
				continue
			var nd: Dictionary = n.get("node_data") if "node_data" in n else {}
			var cell: Vector2i = n.get_cell()
			_resources.append({
				"local_x": cell.x,
				"local_y": cell.y,
				"sprite_id": str(nd.get("sprite", "")),
			})
	# Pull terrain PackedByteArray snapshot from cached map_data
	if mv != null and mv.has_method("get_map_data"):
		var md: Dictionary = mv.get_map_data()
		_terrain = md.get("terrain", PackedByteArray())
	# Pull terrain summary + player facing from OverworldHUDManager
	# — single source of truth so the minimap never reads GameState directly.
	var hmgr: Node = root_node.find_child("HUDManager", true, false) if root_node != null else null
	if hmgr != null:
		if hmgr.has_method("get_region_info"):
			_terrain_summary = str(hmgr.call("get_region_info"))
		if hmgr.has_method("get_player_facing"):
			_player_facing = int(hmgr.call("get_player_facing"))


## Force refresh (called by HubWorld.cell_changed).
func refresh() -> void:
	_refresh_from_gamestate()
	queue_redraw()


## v0.4.0 polish: full visual overhaul. Terrain-tinted cells, category
## entity dots, and a forward-facing arrow on the player marker.
func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, Vector2(WIDTH_PX, HEIGHT_PX)), BG_COLOR, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(WIDTH_PX, HEIGHT_PX)), Color(0.45, 0.45, 0.50, 0.7), false, 1.0)

	_draw_terrain()
	_draw_grid()
	_draw_resources()
	_draw_rifts()
	_draw_npcs()
	_draw_mobs()

	# N arrow at the top edge
	_draw_compass_arrow()

	# Player at centre (always drawn last so it's on top)
	var center := Vector2(WIDTH_PX * 0.5, HEIGHT_PX * 0.5)
	_draw_player(center)

	# Title strip at top
	_draw_title()


## Layer 2: paint each visible cell with its TERRAIN_* tint.
func _draw_terrain() -> void:
	if _terrain.is_empty():
		return
	var size: int = int(LocalMapGen.MAP_SIZE)
	var half_w: int = _cell_range_x
	var half_h: int = _cell_range_y
	var start_x: int = _player_cell.x - half_w
	var start_y: int = _player_cell.y - half_h
	for dy in range(-half_h, half_h + 1):
		for dx in range(-half_w, half_w + 1):
			var lx: int = _player_cell.x + dx
			var ly: int = _player_cell.y + dy
			var pos := _cell_to_pos(lx, ly, Vector2(WIDTH_PX * 0.5, HEIGHT_PX * 0.5))
			if not _in_bounds(pos):
				continue
			var idx: int = ly * size + lx
			if idx < 0 or idx >= _terrain.size():
				continue
			var t := int(_terrain[idx])
			if t < 0 or t >= TERRAIN_TINTS.size():
				continue
			var cell_rect := Rect2(pos - Vector2(CELL_PX * 0.5, CELL_PX * 0.5),
				Vector2(CELL_PX, CELL_PX))
			draw_rect(cell_rect, TERRAIN_TINTS[t], true)
			# Slight border so cells read distinctly
			draw_rect(cell_rect, Color(0, 0, 0, 0.15), false, 0.5)


## Layer 3: faint grid lines every 4 cells.
func _draw_grid() -> void:
	var center := Vector2(WIDTH_PX * 0.5, HEIGHT_PX * 0.5)
	for gx in range(-32, 33, 4):
		var px: float = center.x + gx * CELL_PX
		draw_line(Vector2(px, 0), Vector2(px, HEIGHT_PX), GRID_COLOR, 1.0)
	for gy in range(-24, 25, 4):
		var py: float = center.y + gy * CELL_PX
		draw_line(Vector2(0, py), Vector2(WIDTH_PX, py), GRID_COLOR, 1.0)


## Layer 4a: resource nodes coloured by category.
func _draw_resources() -> void:
	for r in _resources:
		var pos: Vector2 = _cell_to_pos(int(r.get("local_x", 0)), int(r.get("local_y", 0)),
			Vector2(WIDTH_PX * 0.5, HEIGHT_PX * 0.5))
		if not _in_bounds(pos):
			continue
		var sprite_id: String = str(r.get("sprite_id", ""))
		var col: Color = _category_color_for_sprite(sprite_id)
		# Big icon: 4px radius dot for visibility
		draw_circle(pos, 3.0, col)
		draw_circle(pos, 1.0, Color.WHITE)


## Layer 4b: rift markers (purple glow).
func _draw_rifts() -> void:
	for r in _rifts:
		var pos: Vector2 = _cell_to_pos(int(r.get("local_x", 0)), int(r.get("local_y", 0)),
			Vector2(WIDTH_PX * 0.5, HEIGHT_PX * 0.5))
		if not _in_bounds(pos):
			continue
		draw_circle(pos, 4.0, RIFT_COLOR)
		draw_circle(pos, 2.0, MOB_HOSTILE_COLOR)
		draw_line(pos + Vector2(-3, -3), pos + Vector2(3, 3), RIFT_COLOR, 1.0)
		draw_line(pos + Vector2(-3, 3), pos + Vector2(3, -3), RIFT_COLOR, 1.0)


## Layer 4c: NPC population dots (cyan).
func _draw_npcs() -> void:
	for n in _npcs:
		var pos: Vector2 = _cell_to_pos(int(n.get("local_x", 0)), int(n.get("local_y", 0)),
			Vector2(WIDTH_PX * 0.5, HEIGHT_PX * 0.5))
		if not _in_bounds(pos):
			continue
		draw_circle(pos, 2.5, NPC_COLOR)
		draw_circle(pos, 1.0, Color.WHITE)


## Layer 4d: mob dots coloured by hostility.
func _draw_mobs() -> void:
	for m in _mobs:
		var pos: Vector2 = _cell_to_pos(int(m.get("local_x", 0)), int(m.get("local_y", 0)),
			Vector2(WIDTH_PX * 0.5, HEIGHT_PX * 0.5))
		if not _in_bounds(pos):
			continue
		var hostile: bool = bool(m.get("hostile", true))
		var c: Color = MOB_HOSTILE_COLOR if hostile else MOB_NEUTRAL_COLOR
		draw_circle(pos, 2.5, c)
		draw_circle(pos, 0.8, Color.WHITE)


## Player marker: cyan dot + 4-direction facing arrow.
func _draw_player(px: Vector2) -> void:
	# Outer ring + dot
	draw_circle(px, 5.5, PLAYER_OUTLINE)
	draw_circle(px, 4.0, PLAYER_COLOR)
	draw_circle(px, 1.5, Color.WHITE)
	# Cross
	draw_line(px + Vector2(-6, 0), px + Vector2(6, 0), Color.WHITE, 1.0)
	draw_line(px + Vector2(0, -6), px + Vector2(0, 6), Color.WHITE, 1.0)
	# Facing arrow — points where the player is moving / looking.
	# 8-direction arrow vector (Y inverted for Godot screen space).
	var facing: Vector2 = _facing_vector(_player_facing)
	if facing.length() > 0.001:
		var tip: Vector2 = px + facing * 10.0
		var left: Vector2 = px + facing.rotated(deg_to_rad(150.0)) * 5.0
		var right: Vector2 = px + facing.rotated(deg_to_rad(-150.0)) * 5.0
		draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(1.0, 0.95, 0.6, 0.95))
		draw_line(tip, left, Color.WHITE, 1.0)
		draw_line(tip, right, Color.WHITE, 1.0)


## Convert CharacterVisual direction (0..7) to a screen-space unit vector.
## 0=S (+Y), 1=SW, 2=W, 3=NW, 4=N (-Y), 5=NE, 6=E, 7=SE
func _facing_vector(direction: int) -> Vector2:
	match direction:
		0: return Vector2(0, 1)    # S (down)
		1: return Vector2(-1, 0.5) # SW
		2: return Vector2(-1, 0)   # W
		3: return Vector2(-1, -0.5) # NW
		4: return Vector2(0, -1)   # N (up)
		5: return Vector2(1, -0.5)  # NE
		6: return Vector2(1, 0)    # E
		7: return Vector2(1, 0.5)  # SE
	return Vector2.ZERO


## Map a resource sprite_id to its category colour (tree / ore / crystal / other).
func _category_color_for_sprite(sprite_id: String) -> Color:
	if sprite_id.begins_with("tree_"):
		return RESOURCE_TREE_COLOR
	if sprite_id.begins_with("ore_") or sprite_id.begins_with("stone_"):
		return RESOURCE_ORE_COLOR
	if sprite_id.begins_with("crystal_"):
		return RESOURCE_CRYST_COLOR
	return RESOURCE_DEFAULT_COLOR


## Top-edge N arrow + label.
func _draw_compass_arrow() -> void:
	var arrow_centre := Vector2(WIDTH_PX * 0.5, 14)
	# Triangle pointing up for "N"
	var tip := arrow_centre + Vector2(0, -7)
	var left := arrow_centre + Vector2(-5, 4)
	var right := arrow_centre + Vector2(5, 4)
	draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(0.85, 0.85, 0.95, 0.85))
	draw_line(tip, left, Color(0.5, 0.5, 0.6, 0.7), 1.0)
	draw_line(tip, right, Color(0.5, 0.5, 0.6, 0.7), 1.0)


## Terrain summary at the bottom edge: readable string + summary dots.
func _draw_title() -> void:
	var rect := Rect2(Vector2(0, HEIGHT_PX - 16), Vector2(WIDTH_PX, 16))
	draw_rect(rect, Color(0.02, 0.02, 0.03, 0.78), true)
	# Draw readable text using the default font
	var font: Font = MT._ensure_font()
	if font != null:
		var text: String = _terrain_summary if not _terrain_summary.is_empty() else "Local Map"
		draw_string(font, Vector2(8, HEIGHT_PX - 4), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.92, 0.94, 0.96, 0.95))
	# Resource mix legend on the right (3 dots)
	_draw_summary_dots(Vector2(WIDTH_PX - 56, HEIGHT_PX - 8))


## Visual surrogate for the terrain summary text (no font needed).
func _draw_summary_dots(centre: Vector2) -> void:
	for i in range(5):
		var i_off := i * 8
		var c: Color
		match i:
			0: c = Color(0.55, 0.85, 0.45, 1.0)
			1: c = Color(0.85, 0.65, 0.30, 1.0)
			2: c = Color(0.65, 0.50, 0.95, 1.0)
			3: c = Color(0.42, 0.78, 0.88, 1.0)
			4: c = Color(0.92, 0.30, 0.30, 1.0)
		draw_circle(centre + Vector2(i_off, 0), 2.5, c)
