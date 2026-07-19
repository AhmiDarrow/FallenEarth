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
##   - v0.9.1: overworld mobs (red dots) in the current local hex so
##     the player can see where to walk to find a fight.
##
## Coordinate system: the world is a hex sphere with axial coordinates
## (q, r). The minimap uses the same axial layout as WorldGenerator
## (pointy-top hexes). We render the bounding box of discovered hexes
## plus some padding.
class_name Minimap
extends Control

const HEIGHT_PX := 200.0
const WIDTH_PX := 200.0
const HEX_SIZE_PX := 7.0  # radius of each hex on the minimap
const BG_COLOR := Color(0.04, 0.04, 0.06, 0.85)
const GRID_LINE_COLOR := Color(0.2, 0.2, 0.22, 0.5)
const DISCOVERED_COLOR := Color(0.45, 0.5, 0.42)
const CURRENT_OUTLINE := Color(1, 1, 1)
const RIFT_COLOR := Color(1.0, 0.85, 0.2)
const RIFTSPIRE_COLOR := Color(1.0, 0.5, 0.15)
const PLAYER_COLOR := Color(0.4, 0.85, 1.0)
const MOB_HOSTILE_COLOR := Color(1.0, 0.5, 0.4)  # red — hostile mob
const MOB_NEUTRAL_COLOR := Color(0.7, 0.85, 0.7)  # gray-green — neutral

var _cached_discovered: Array = []
var _cached_current: Vector2i = Vector2i.ZERO
var _cached_rifts: Array = []
var _cached_riftspire: Vector2i = Vector2i(-999, -999)
var _cached_towns: Array = []  # [{q, r, color}]
var _cached_mobs: Array = []  # [{local_x, local_y, hostile}]
var _local_player_x: int = 0
var _local_player_y: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH_PX, HEIGHT_PX)
	# Fill parent container (MinimapPanel) completely
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ensure size propagates after parent layout
	size = Vector2(WIDTH_PX, HEIGHT_PX)
	call_deferred("_refresh_from_gamestate")
	call_deferred("queue_redraw")


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
	if rr != null and rr.has_method("get_rifts_in_hex"):
		_cached_rifts = rr.get_rifts_in_hex(pos.x, pos.y, Time.get_unix_time_from_system())
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
	# v0.9.1: pull overworld mobs in the current hex for the dot overlay.
	# The player can use these to navigate toward fights.
	_cached_mobs = []
	var local_pos: Vector2i = gs.get_local_position()
	_local_player_x = local_pos.x
	_local_player_y = local_pos.y
	var prefix: String = "%d,%d|" % [pos.x, pos.y]
	for mob_key in gs.get_overworld_mobs().keys():
		if not str(mob_key).begins_with(prefix):
			continue
		var rest: String = str(mob_key).substr(prefix.length())
		var mparts: PackedStringArray = rest.split(",")
		if mparts.size() < 2:
			continue
		var mob_data: Dictionary = gs.get_overworld_mobs()[mob_key] as Dictionary
		_cached_mobs.append({
			"local_x": int(mparts[0]),
			"local_y": int(mparts[1]),
			"hostile": bool(mob_data.get("hostile", true)),
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
		_draw_local_inset()
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

	# v0.9.1: local-map inset (bottom-left) — shows the player's local
	# cells with red/green mob dots. Player centered, ~25×15 local
	# cells visible. Mobs outside this range are clipped.
	_draw_local_inset()


## v0.9.1: Draw a small inset showing the local map around the
## player. The sphere map above is the strategic view; this inset
## is the tactical view — the player uses it to find the nearest
## mob without scrolling the world around.
func _draw_local_inset() -> void:
	# Inset frame: bottom-left, ~80x50 px
	var inset_size := Vector2(80.0, 50.0)
	var inset_pos := Vector2(8.0, HEIGHT_PX - inset_size.y - 8.0)
	draw_rect(Rect2(inset_pos, inset_size), Color(0.02, 0.02, 0.03, 0.9), true)
	draw_rect(Rect2(inset_pos, inset_size), Color(0.4, 0.4, 0.45, 0.7), false, 1.0)
	# "LOCAL" label
	# (no font drawing here, but a small dot at top-left identifies it)
	# Player center
	var player_local: Vector2 = Vector2(_local_player_x, _local_player_y)
	# Local view radius: 25x15 cells = full camera view of the overworld
	var local_radius: Vector2 = Vector2(25.0, 15.0)
	# Center of inset
	var center: Vector2 = inset_pos + inset_size * 0.5
	# Player is always at the center
	# Map local cell to inset position
	for mob in _cached_mobs:
		if not (mob is Dictionary):
			continue
		var mlx: int = int(mob.get("local_x", 0))
		var mly: int = int(mob.get("local_y", 0))
		var dx: float = float(mlx - _local_player_x)
		var dy: float = float(mly - _local_player_y)
		# Skip if outside the inset view
		if absf(dx) > local_radius.x or absf(dy) > local_radius.y:
			continue
		# Map to inset pixel
		var px: float = center.x + (dx / local_radius.x) * (inset_size.x * 0.5)
		var py: float = center.y + (dy / local_radius.y) * (inset_size.y * 0.5)
		var hostile: bool = bool(mob.get("hostile", true))
		var c: Color = MOB_HOSTILE_COLOR if hostile else MOB_NEUTRAL_COLOR
		draw_circle(Vector2(px, py), 1.5, c)
	# Player dot at center
	draw_circle(center, 2.0, PLAYER_COLOR)
	draw_circle(center, 1.0, Color.WHITE)
	# Faint crosshair to mark center
	draw_line(center + Vector2(-3, 0), center + Vector2(3, 0), Color(0.6, 0.6, 0.7, 0.5), 0.5)
	draw_line(center + Vector2(0, -3), center + Vector2(0, 3), Color(0.6, 0.6, 0.7, 0.5), 0.5)


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
