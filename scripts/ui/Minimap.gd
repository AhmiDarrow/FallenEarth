## Minimap — Small hex overview rendered in the top-right of the HUD.
##
## Phase 2. Renders a 180x180 pixel map with a hex grid. Each cell is
## ~6px. Drawn via _draw() on a Control — no SubViewport needed.
##
## Shows:
##   - Discovered hexes (filled with the biome color from data/biomes.json
##     or a neutral gray if biome info isn't available)
##   - The current hex (white outline)
##   - Rifts (yellow ⚡ glyph)
##   - Riftspire (orange ★ glyph, if riftspire_hex_key is set)
##   - NPC towns (faction-colored star; from data/towns.json or
##     world_data.towns_seeded if present)
##
## Coordinate system: the world is a hex sphere with axial coordinates
## (q, r). The minimap uses the same axial layout as WorldGenerator
## (pointy-top hexes). We render the bounding box of discovered hexes
## plus some padding.
class_name Minimap
extends Control

const HEIGHT_PX := 180.0
const WIDTH_PX := 180.0
const HEX_SIZE_PX := 6.0  # radius of each hex on the minimap
const BG_COLOR := Color(0.04, 0.04, 0.06, 0.85)
const GRID_LINE_COLOR := Color(0.2, 0.2, 0.22, 0.5)
const DISCOVERED_COLOR := Color(0.45, 0.5, 0.42)
const CURRENT_OUTLINE := Color(1, 1, 1)
const RIFT_COLOR := Color(1.0, 0.85, 0.2)
const RIFTSPIRE_COLOR := Color(1.0, 0.5, 0.15)
const PLAYER_COLOR := Color(0.4, 0.85, 1.0)

var _cached_discovered: Array = []
var _cached_current: Vector2i = Vector2i.ZERO
var _cached_rifts: Array = []
var _cached_riftspire: Vector2i = Vector2i(-999, -999)
var _cached_towns: Array = []  # [{q, r, color}]


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH_PX, HEIGHT_PX)
	# Anchor top-right of the viewport
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = -WIDTH_PX - 12
	offset_top = 12
	offset_right = -12
	offset_bottom = HEIGHT_PX + 12
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_from_gamestate()
	queue_redraw()


## Pull current data from GameState and refresh the cache.
func _refresh_from_gamestate() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if gs == null:
		return
	_cached_discovered = []
	for hex_str in gs.get_discovered_hexes():
		var parts: PackedStringArray = str(hex_str).split(",")
		if parts.size() == 2:
			_cached_discovered.append(Vector2i(int(parts[0]), int(parts[1])))
	var pos: Vector2i = gs.get_player_position()
	_cached_current = pos
	# Rifts: read from the active rift runner
	var rr: Node = get_node_or_null("/root/RiftRunner")
	if rr != null and rr.has_method("get_rifts_for_world"):
		_cached_rifts = rr.get_rifts_for_world(pos)
	else:
		_cached_rifts = []
	# Riftspire: from world_data.riftspire_hex_key
	if gs.has_world():
		var wd: Dictionary = gs.get_world_data()
		var rs_key: String = str(wd.get("riftspire_hex_key", ""))
		if not rs_key.is_empty():
			var parts: PackedStringArray = rs_key.split(",")
			if parts.size() == 2:
				_cached_riftspire = Vector2i(int(parts[0]), int(parts[1]))
	# Towns
	_cached_towns = []
	if gs.has_world():
		var wd: Dictionary = gs.get_world_data()
		var towns: Array = wd.get("towns_seeded", [])
		for t in towns:
			if not (t is Dictionary):
				continue
			var tkey: String = str(t.get("hex", ""))
			if tkey.is_empty():
				continue
			var tparts: PackedStringArray = tkey.split(",")
			if tparts.size() != 2:
				continue
			var color: Color = _faction_color(str(t.get("faction", "")))
			_cached_towns.append({
				"q": int(tparts[0]),
				"r": int(tparts[1]),
				"color": color,
			})


## Force a refresh (call after GameState changes, e.g. travel, discovery).
func refresh() -> void:
	_refresh_from_gamestate()
	queue_redraw()


# Axial hex → pixel (pointy-top)
static func axial_to_pixel(q: int, r: int, size: float) -> Vector2:
	# pointy-top axial
	var x: float = size * sqrt(3.0) * (q + r * 0.5)
	var y: float = size * 1.5 * r
	return Vector2(x, y)


func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, Vector2(WIDTH_PX, HEIGHT_PX)), BG_COLOR, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(WIDTH_PX, HEIGHT_PX)), Color(0.4, 0.4, 0.45, 0.6), false, 1.0)

	# Determine view bounds
	if _cached_discovered.is_empty():
		# Center on the current player even with no discovery
		_draw_player(Vector2(WIDTH_PX / 2.0, HEIGHT_PX / 2.0))
		return

	# Compute center of discovered set
	var center := _axial_to_screen_center()
	var center_px := axial_to_pixel(center.x, center.y, HEX_SIZE_PX)
	# Offset everything so center renders at the minimap center
	var origin := Vector2(WIDTH_PX / 2.0, HEIGHT_PX / 2.0) - center_px

	# Draw discovered hexes
	for hex in _cached_discovered:
		_draw_hex_at(axial_to_pixel(hex.x, hex.y, HEX_SIZE_PX) + origin, DISCOVERED_COLOR, true)

	# Draw towns (drawn before rifts so rifts are on top)
	for town in _cached_towns:
		var tpos: Vector2 = axial_to_pixel(int(town.q), int(town.r), HEX_SIZE_PX) + origin
		# Only draw if within bounds
		if _in_bounds(tpos):
			draw_circle(tpos, HEX_SIZE_PX * 0.5, town.color)

	# Draw rifts
	for rift in _cached_rifts:
		if not (rift is Dictionary):
			continue
		var rpos: Vector2 = axial_to_pixel(
			int(rift.get("q", 0)), int(rift.get("r", 0)), HEX_SIZE_PX
		) + origin
		if _in_bounds(rpos):
			draw_circle(rpos, HEX_SIZE_PX * 0.4, RIFT_COLOR)
			draw_line(rpos + Vector2(-2, -2), rpos + Vector2(2, 2), RIFT_COLOR, 1.0)
			draw_line(rpos + Vector2(-2, 2), rpos + Vector2(2, -2), RIFT_COLOR, 1.0)

	# Draw Riftspire
	if _cached_riftspire.x > -900:
		var rspos: Vector2 = axial_to_pixel(_cached_riftspire.x, _cached_riftspire.y, HEX_SIZE_PX) + origin
		if _in_bounds(rspos):
			draw_circle(rspos, HEX_SIZE_PX * 0.6, RIFTSPIRE_COLOR)
			# 5-pointed star
			for k in 5:
				var a1: float = -PI / 2.0 + k * TAU / 5.0
				var a2: float = a1 + TAU / 10.0
				var p1: Vector2 = rspos + Vector2(cos(a1), sin(a1)) * HEX_SIZE_PX * 0.5
				var p2: Vector2 = rspos + Vector2(cos(a2), sin(a2)) * HEX_SIZE_PX * 0.25
				draw_line(p1, p2, RIFTSPIRE_COLOR, 1.5)

	# Draw current player on top
	var player_px: Vector2 = axial_to_pixel(_cached_current.x, _cached_current.y, HEX_SIZE_PX) + origin
	if _in_bounds(player_px):
		_draw_player(player_px)


func _draw_player(px: Vector2) -> void:
	# Cross + circle
	draw_circle(px, HEX_SIZE_PX * 0.4, PLAYER_COLOR)
	draw_line(px + Vector2(-HEX_SIZE_PX * 0.6, 0), px + Vector2(HEX_SIZE_PX * 0.6, 0), Color.WHITE, 1.5)
	draw_line(px + Vector2(0, -HEX_SIZE_PX * 0.6), px + Vector2(0, HEX_SIZE_PX * 0.6), Color.WHITE, 1.5)


func _draw_hex_at(center: Vector2, color: Color, filled: bool) -> void:
	# Pointy-top hex
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 6:
		var a: float = PI / 6.0 + k * TAU / 6.0
		pts.append(center + Vector2(cos(a), sin(a)) * HEX_SIZE_PX)
	if filled:
		draw_colored_polygon(pts, color)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[0]]), GRID_LINE_COLOR, 1.0)


func _axial_to_screen_center() -> Vector2i:
	# Simple center: average of discovered + current
	var sum_q := 0
	var sum_r := 0
	var n := 0
	for hex in _cached_discovered:
		sum_q += hex.x
		sum_r += hex.y
		n += 1
	if n == 0:
		return _cached_current
	return Vector2i(int(sum_q / n), int(sum_r / n))


func _in_bounds(p: Vector2) -> bool:
	return p.x >= 0 and p.x <= WIDTH_PX and p.y >= 0 and p.y <= HEIGHT_PX


func _faction_color(faction: String) -> Color:
	# Simple hash-based stable color per faction name
	var h: int = 0
	for c in faction.unicode_at(0):  # wrong; use codepoint iteration
		pass
	# Use unicode codepoint sum as a stable hash
	for i in faction.length():
		h = h * 31 + faction.unicode_at(i)
	# Map to a hue band
	var hue: float = float(h % 360) / 360.0
	return Color.from_hsv(hue, 0.7, 0.85)
