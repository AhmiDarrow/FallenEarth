## Minimap — Compact local overworld map (terrain + sparse markers + player).
## Footer is two clipped Labels — never overflows the panel.
class_name Minimap
extends Control

const WIDTH_PX := 196.0
const HEIGHT_PX := 140.0
const CELL_PX := 2.2
const FOOTER_H := 26.0
const MT = preload("res://assets/ui/MasterTheme.gd")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")

const BG_COLOR := Color(0.05, 0.05, 0.07, 0.94)
const BORDER_COLOR := Color(0.48, 0.50, 0.56, 0.75)
const GRID_COLOR := Color(0.22, 0.22, 0.26, 0.14)

var PLAYER_COLOR: Color = Color(0.20, 0.85, 0.95, 1.0)
const PLAYER_OUTLINE := Color(0.98, 0.98, 1.0, 1.0)

const TERRAIN_TINTS: Array[Color] = [
	Color(0.68, 0.60, 0.44, 1.0),    # GROUND
	Color(0.40, 0.34, 0.26, 1.0),    # DEBRIS
	Color(0.26, 0.44, 0.26, 1.0),    # VEGETATION
	Color(0.14, 0.12, 0.10, 1.0),    # BLOCKED
	Color(0.20, 0.44, 0.54, 1.0),    # WATER
]

const RESOURCE_TREE_COLOR  := Color(0.42, 0.72, 0.36, 0.70)
const RESOURCE_ORE_COLOR   := Color(0.82, 0.58, 0.26, 0.75)
const RESOURCE_CRYST_COLOR := Color(0.58, 0.46, 0.88, 0.75)
const RESOURCE_DEFAULT_COLOR := Color(0.70, 0.64, 0.46, 0.55)
const MOB_HOSTILE_COLOR := Color(0.90, 0.28, 0.28, 0.92)
const MOB_NEUTRAL_COLOR := Color(0.82, 0.74, 0.34, 0.85)
const RIFT_COLOR := Color(0.70, 0.34, 0.92, 0.95)
const NPC_COLOR := Color(0.48, 0.82, 0.92, 0.9)

# Only draw resource dots within this Chebyshev range of the player.
const RESOURCE_VIEW_RANGE := 42
# Cap dots so the map stays readable in dense biomes.
const MAX_RESOURCE_DOTS := 80

var _terrain: PackedByteArray = PackedByteArray()
var _player_cell: Vector2i = Vector2i.ZERO
var _player_facing: int = 0
var _mobs: Array = []
var _resources: Array = []
var _rifts: Array = []
var _npcs: Array = []
var _region_title: String = ""
var _region_sub: String = ""

var _title_label: Label = null
var _sub_label: Label = null


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH_PX, HEIGHT_PX)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

	_title_label = Label.new()
	_title_label.name = "RegionTitle"
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.add_theme_font_size_override("font_size", 10)
	_title_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96, 0.95))
	_title_label.position = Vector2(5, HEIGHT_PX - FOOTER_H + 2)
	_title_label.size = Vector2(WIDTH_PX - 10, 12)
	_title_label.clip_text = true
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_title_label)

	_sub_label = Label.new()
	_sub_label.name = "RegionSub"
	_sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_label.add_theme_font_size_override("font_size", 9)
	_sub_label.add_theme_color_override("font_color", Color(0.68, 0.72, 0.76, 0.88))
	_sub_label.position = Vector2(5, HEIGHT_PX - 12)
	_sub_label.size = Vector2(WIDTH_PX - 10, 11)
	_sub_label.clip_text = true
	_sub_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_sub_label)

	if MT != null and "MM_PLAYER" in MT:
		PLAYER_COLOR = MT.MM_PLAYER
	call_deferred("_refresh_from_gamestate")
	call_deferred("queue_redraw")


func _map_h() -> float:
	return HEIGHT_PX - FOOTER_H


func _cell_to_pos(lx: int, ly: int, center: Vector2) -> Vector2:
	return center + Vector2(float(lx - _player_cell.x) * CELL_PX, float(ly - _player_cell.y) * CELL_PX)


func _in_map_area(p: Vector2) -> bool:
	return p.x >= 2.0 and p.x <= WIDTH_PX - 2.0 and p.y >= 2.0 and p.y <= _map_h() - 2.0


func _refresh_from_gamestate() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if gs == null:
		return
	_player_cell = gs.get_local_position()
	_mobs = []
	var prefix: String = "%d,%d|" % [gs.get_player_position().x, gs.get_player_position().y]
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
	_resources = []
	_rifts = []
	_npcs = []
	var root_node := get_tree().root if get_tree() != null else null
	var mv: Node = null
	if root_node != null:
		mv = root_node.find_child("LocalMapView", true, false)
	if mv != null and mv.has_method("get_resource_nodes"):
		var candidates: Array = []
		for n in mv.get_resource_nodes():
			if not (n is Node2D):
				continue
			var nd: Dictionary = n.get("node_data") if "node_data" in n else {}
			if bool(nd.get("depleted", false)):
				continue
			var cell: Vector2i = n.get_cell()
			var dist: int = maxi(abs(cell.x - _player_cell.x), abs(cell.y - _player_cell.y))
			if dist > RESOURCE_VIEW_RANGE:
				continue
			candidates.append({
				"local_x": cell.x,
				"local_y": cell.y,
				"sprite_id": str(nd.get("sprite", "")),
				"dist": dist,
			})
		# Prefer nearer markers; thin out when over cap.
		candidates.sort_custom(func(a, b): return int(a["dist"]) < int(b["dist"]))
		var step: int = 1
		if candidates.size() > MAX_RESOURCE_DOTS:
			step = int(ceil(float(candidates.size()) / float(MAX_RESOURCE_DOTS)))
		var i := 0
		while i < candidates.size() and _resources.size() < MAX_RESOURCE_DOTS:
			_resources.append(candidates[i])
			i += step
	if mv != null and mv.has_method("get_map_data"):
		var md: Dictionary = mv.get_map_data()
		_terrain = md.get("terrain", PackedByteArray())
	var hmgr: Node = root_node.find_child("HUDManager", true, false) if root_node != null else null
	if hmgr != null and hmgr.has_method("get_player_facing"):
		_player_facing = int(hmgr.call("get_player_facing"))


func refresh() -> void:
	_refresh_from_gamestate()
	queue_redraw()


func set_region_text(text: String) -> void:
	var plain: String = _strip_bbcode(text)
	if plain.find("  ") >= 0:
		var parts: PackedStringArray = plain.split("  ", false)
		_region_title = parts[0].strip_edges() if parts.size() > 0 else plain
		_region_sub = "  ".join(parts.slice(1)).strip_edges() if parts.size() > 1 else ""
	else:
		_region_title = plain
		_region_sub = ""
	if is_instance_valid(_title_label):
		_title_label.text = _region_title
	if is_instance_valid(_sub_label):
		_sub_label.text = _region_sub


func set_region_lines(title: String, subtitle: String = "") -> void:
	_region_title = title
	_region_sub = subtitle
	if is_instance_valid(_title_label):
		_title_label.text = title
	if is_instance_valid(_sub_label):
		_sub_label.text = subtitle


func _strip_bbcode(s: String) -> String:
	var out := ""
	var i := 0
	while i < s.length():
		if s[i] == "[":
			var close := s.find("]", i)
			if close < 0:
				out += s.substr(i)
				break
			i = close + 1
			continue
		out += s[i]
		i += 1
	return out


func _draw() -> void:
	var map_h: float = _map_h()
	draw_rect(Rect2(Vector2.ZERO, Vector2(WIDTH_PX, HEIGHT_PX)), BG_COLOR, true)
	_draw_terrain(map_h)
	_draw_grid(map_h)
	_draw_resources()
	_draw_rifts()
	_draw_npcs()
	_draw_mobs()
	var center := Vector2(WIDTH_PX * 0.5, map_h * 0.5)
	_draw_player(center)
	# Footer bar
	draw_rect(Rect2(Vector2(0, map_h), Vector2(WIDTH_PX, FOOTER_H)),
		Color(0.03, 0.03, 0.04, 0.94), true)
	draw_line(Vector2(0, map_h), Vector2(WIDTH_PX, map_h), Color(0.38, 0.40, 0.46, 0.55), 1.0)
	# Outer border last so it frames everything
	draw_rect(Rect2(Vector2(0.5, 0.5), Vector2(WIDTH_PX - 1.0, HEIGHT_PX - 1.0)), BORDER_COLOR, false, 1.0)


func _draw_terrain(map_h: float) -> void:
	if _terrain.is_empty():
		return
	var size: int = int(LocalMapGen.MAP_SIZE)
	var center := Vector2(WIDTH_PX * 0.5, map_h * 0.5)
	var half_w: int = int(WIDTH_PX / (CELL_PX * 2.0)) + 1
	var half_h: int = int(map_h / (CELL_PX * 2.0)) + 1
	for dy in range(-half_h, half_h + 1):
		for dx in range(-half_w, half_w + 1):
			var lx: int = _player_cell.x + dx
			var ly: int = _player_cell.y + dy
			var pos := _cell_to_pos(lx, ly, center)
			if pos.y >= map_h - 0.5 or pos.y < 0.0:
				continue
			if pos.x < 0.0 or pos.x > WIDTH_PX:
				continue
			var idx: int = ly * size + lx
			if idx < 0 or idx >= _terrain.size():
				continue
			var t := int(_terrain[idx])
			if t < 0 or t >= TERRAIN_TINTS.size():
				continue
			var cell_rect := Rect2(pos - Vector2(CELL_PX * 0.5, CELL_PX * 0.5), Vector2(CELL_PX + 0.2, CELL_PX + 0.2))
			draw_rect(cell_rect, TERRAIN_TINTS[t], true)


func _draw_grid(map_h: float) -> void:
	var center := Vector2(WIDTH_PX * 0.5, map_h * 0.5)
	# Sparse, soft grid — every 10 cells
	for gx in range(-50, 51, 10):
		var px: float = center.x + gx * CELL_PX
		if px < 1.0 or px > WIDTH_PX - 1.0:
			continue
		draw_line(Vector2(px, 1.0), Vector2(px, map_h - 1.0), GRID_COLOR, 1.0)
	for gy in range(-40, 41, 10):
		var py: float = center.y + gy * CELL_PX
		if py < 1.0 or py > map_h - 1.0:
			continue
		draw_line(Vector2(1.0, py), Vector2(WIDTH_PX - 1.0, py), GRID_COLOR, 1.0)


func _draw_resources() -> void:
	var center := Vector2(WIDTH_PX * 0.5, _map_h() * 0.5)
	for r in _resources:
		var pos: Vector2 = _cell_to_pos(int(r.get("local_x", 0)), int(r.get("local_y", 0)), center)
		if not _in_map_area(pos):
			continue
		var col: Color = _category_color_for_sprite(str(r.get("sprite_id", "")))
		draw_circle(pos, 1.4, col)


func _draw_rifts() -> void:
	var center := Vector2(WIDTH_PX * 0.5, _map_h() * 0.5)
	for r in _rifts:
		var pos: Vector2 = _cell_to_pos(int(r.get("local_x", 0)), int(r.get("local_y", 0)), center)
		if not _in_map_area(pos):
			continue
		draw_circle(pos, 2.8, RIFT_COLOR)
		draw_circle(pos, 1.1, Color(1, 1, 1, 0.65))


func _draw_npcs() -> void:
	var center := Vector2(WIDTH_PX * 0.5, _map_h() * 0.5)
	for n in _npcs:
		var pos: Vector2 = _cell_to_pos(int(n.get("local_x", 0)), int(n.get("local_y", 0)), center)
		if not _in_map_area(pos):
			continue
		draw_circle(pos, 1.8, NPC_COLOR)


func _draw_mobs() -> void:
	var center := Vector2(WIDTH_PX * 0.5, _map_h() * 0.5)
	for m in _mobs:
		var pos: Vector2 = _cell_to_pos(int(m.get("local_x", 0)), int(m.get("local_y", 0)), center)
		if not _in_map_area(pos):
			continue
		var c: Color = MOB_HOSTILE_COLOR if bool(m.get("hostile", true)) else MOB_NEUTRAL_COLOR
		draw_circle(pos, 1.8, c)


func _draw_player(px: Vector2) -> void:
	draw_circle(px, 4.2, PLAYER_OUTLINE)
	draw_circle(px, 3.0, PLAYER_COLOR)
	draw_circle(px, 1.1, Color.WHITE)
	var facing: Vector2 = _facing_vector(_player_facing)
	if facing.length() > 0.001:
		var tip: Vector2 = px + facing * 7.0
		var left: Vector2 = px + facing.rotated(deg_to_rad(150.0)) * 3.5
		var right: Vector2 = px + facing.rotated(deg_to_rad(-150.0)) * 3.5
		draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(1.0, 0.95, 0.6, 0.95))


func _facing_vector(direction: int) -> Vector2:
	match direction:
		0: return Vector2(0, 1)
		1: return Vector2(-1, 0.5)
		2: return Vector2(-1, 0)
		3: return Vector2(-1, -0.5)
		4: return Vector2(0, -1)
		5: return Vector2(1, -0.5)
		6: return Vector2(1, 0)
		7: return Vector2(1, 0.5)
	return Vector2.ZERO


func _category_color_for_sprite(sprite_id: String) -> Color:
	if sprite_id.begins_with("tree_"):
		return RESOURCE_TREE_COLOR
	if sprite_id.begins_with("ore_") or sprite_id.begins_with("stone_") or sprite_id.begins_with("decor_rock"):
		return RESOURCE_ORE_COLOR
	if sprite_id.begins_with("crystal_"):
		return RESOURCE_CRYST_COLOR
	if sprite_id.begins_with("formation_"):
		return RESOURCE_DEFAULT_COLOR
	return RESOURCE_DEFAULT_COLOR
