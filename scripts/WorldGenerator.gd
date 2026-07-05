## WorldGenerator -- Procedural hexagonal sphere world (RimWorld-inspired).
## Uses axial hex coordinates (q,r) for sphere-like topology.
## Biomes assigned via simulated latitude (temp), elevation noise, rainfall.
## Player can choose starting tile like RimWorld landing site selection.
class_name WorldGenerator
extends Node

signal world_generated(seed_string: String)

const VERSION := "0.2.0"
const DATA_PATH := "res://data/biomes.json"
var _hex_radius: int = 12  # Size of hex "sphere" patch (axial); set via generate() size param

var _seed: String = ""
var _tile_map: Dictionary = {}  # key "q,r" -> tile dict
var _biome_definitions: Array[Dictionary] = []
var _active_rift_nodes: Array[Dictionary] = []


## Deterministic seed from string for Godot's rand
func randseed_from_string(s: String) -> void:
	seed(s.hash())


func initialize() -> bool:
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if not file:
		push_error("[WorldGenerator] Could not load biomes.json at %s" % DATA_PATH)
		return false
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY or (parsed as Array).size() < 1:
		push_error("[WorldGenerator] biomes.json has wrong number of entries")
		return false

	# JSON.parse_string returns a plain Array (Variant), not a typed Array[Dictionary].
	# Direct "as Array[Dictionary]" cast fails at runtime with "Trying to assign an array of type "Array" to...".
	# We must manually construct the typed array.
	_biome_definitions = []
	for item in (parsed as Array):
		if item is Dictionary:
			_biome_definitions.append(item as Dictionary)

	if _biome_definitions.size() < 1:
		push_error("[WorldGenerator] biomes.json has wrong number of entries")
		return false

	return true


## Generate hex sphere world (axial coords q,r). RimWorld-like: lat/temp + elev + noise for biome.
## size: desired hex radius (small=6, medium=12, large=18)
func generate(world_seed: String, difficulty_modifier: float = 1.0, size: int = 12) -> Dictionary:
	_seed = world_seed
	_hex_radius = size
	randseed_from_string(world_seed)

	var tile_map: Dictionary = {}
	var biomes = _biome_definitions

	# Generate hex tiles in a large "sphere" patch using axial coords
	for q in range(-_hex_radius, _hex_radius + 1):
		for r in range(max(-_hex_radius, -q - _hex_radius), min(_hex_radius, -q + _hex_radius) + 1):
			# Simulate latitude from r (polar bias)
			var lat = float(r) / float(_hex_radius) * 90.0  # -90 to 90
			var abs_lat = abs(lat)

			# Elevation noise (RimWorld hilliness/elev)
			var elev_noise = (randf() - 0.5) * 2.0 + sin(lat * 0.05) * 0.3
			var elevation = clamp(0.5 + elev_noise * 0.5, 0.0, 1.0)

			# Temperature bias (colder poles)
			var temp = 1.0 - (abs_lat / 90.0) * 0.8 - (elevation - 0.5) * 0.4
			temp = clamp(temp, 0.0, 1.0)

			# Rainfall / moisture noise (RimWorld rain)
			var rain = clamp(0.5 + (randf() - 0.5) * 1.2 - (elevation - 0.5) * 0.6, 0.0, 1.0)

			# Pick biome based on temp/rain/elev like RimWorld
			var chosen_biome = _pick_biome_by_climate(temp, rain, elevation, biomes)

			var tile: Dictionary = chosen_biome.duplicate(true)
			if not tile.has("rift_chance"):
				tile["rift_chance"] = 0.3
			tile["rift_chance"] *= difficulty_modifier
			tile["q"] = q
			tile["r"] = r
			tile["elevation"] = elevation
			tile["temperature"] = temp
			tile["rainfall"] = rain
			tile["features"] = tile.get("features", []) + _get_features(elevation, rain)
			tile["is_start_candidate"] = _is_good_start(tile)

			var key = "%d,%d" % [q, r]
			tile_map[key] = tile

	_tile_map = tile_map
	world_generated.emit(world_seed)
	return tile_map


func _pick_biome_by_climate(temp: float, rain: float, elev: float, biomes: Array) -> Dictionary:
	# Simple scoring like RimWorld biome assignment
	var best_score = -999.0
	var best = biomes[0] if biomes.size() > 0 else {"name": "Ash Wastes"}
	for b in biomes:
		var score = 0.0
		var name = b.get("name", "")
		if temp > 0.6 and ("Wastes" in name or "Plains" in name or "Bogs" in name):
			score += 2.0
		if temp < 0.4 and ("Canyons" in name or "Highlands" in name or "Marshes" in name):
			score += 1.5
		if rain > 0.6 and ("Bogs" in name or "Thicket" in name):
			score += 1.5
		if rain < 0.4 and ("Wastes" in name or "Dunes" in name or "Canyons" in name):
			score += 1.5
		if elev > 0.7 and ("Highlands" in name or "Canyons" in name):
			score += 1.0
		if elev < 0.3 and ("Bogs" in name or "Marshes" in name):
			score += 0.8
		if score > best_score:
			best_score = score
			best = b
	return best.duplicate(true)


func _get_features(elev: float, rain: float) -> Array:
	var feats = []
	if elev > 0.7: feats.append("high_elevation")
	if rain > 0.7: feats.append("wetlands")
	if elev < 0.3 and rain > 0.5: feats.append("flood_prone")
	return feats


func _is_good_start(tile: Dictionary) -> bool:
	# RimWorld-like good start: decent temp/rain, not extreme
	var temp = tile.get("temperature", 0.5)
	var rain = tile.get("rainfall", 0.5)
	var elev = tile.get("elevation", 0.5)
	return temp > 0.35 and temp < 0.75 and rain > 0.3 and elev < 0.85


func load_from_tile_map(tile_map: Dictionary, world_seed: String = "") -> void:
	_tile_map = tile_map.duplicate(true)
	_seed = world_seed


func get_tile_at(q: int, r: int) -> Dictionary:
	var key = "%d,%d" % [q, r]
	if _tile_map.has(key):
		return _tile_map[key].duplicate(true)
	return {}


static func hex_distance(q1: int, r1: int, q2: int, r2: int) -> int:
	var s1 := -q1 - r1
	var s2 := -q2 - r2
	return int((abs(q1 - q2) + abs(r1 - r2) + abs(s1 - s2)) / 2)


static func axial_to_pixel(q: int, r: int, hex_size: float) -> Vector2:
	var x := hex_size * (sqrt(3.0) * float(q) + sqrt(3.0) / 2.0 * float(r))
	var y := hex_size * (1.5 * float(r))
	return Vector2(x, y)


## Return the 6 vertices of a pointy-top hex polygon centered at origin.
static func hex_shape(size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)
		points.append(Vector2(cos(angle) * size, sin(angle) * size))
	return points


func get_hex_radius() -> int:
	return _hex_radius


## Get axial neighbors for hex movement (RimWorld tile travel)
func get_neighbors(q: int, r: int) -> Array:
	var dirs = [[+1, 0], [+1, -1], [0, -1], [-1, 0], [-1, +1], [0, +1]]
	var neigh = []
	for d in dirs:
		var nq = q + d[0]
		var nr = r + d[1]
		var t = get_tile_at(nq, nr)
		if not t.is_empty():
			neigh.append({"q": nq, "r": nr, "tile": t})
	return neigh


## Return list of good starting tiles (RimWorld "select random site" / browse)
func get_starting_candidates(count: int = 5) -> Array:
	var cands = []
	for key in _tile_map.keys():
		var t = _tile_map[key]
		if t.get("is_start_candidate", false):
			cands.append({"key": key, "tile": t})
	if cands.size() == 0:
		for key in _tile_map.keys():
			cands.append({"key": key, "tile": _tile_map[key]})
			if cands.size() >= count: break
	cands.shuffle()
	return cands.slice(0, min(count, cands.size()))


func find_nearest_high_rift_biome(center_q: int, center_r: int, max_search_radius: int = 20) -> Dictionary:
	var best = {}
	var highest = 0.0
	for key in _tile_map:
		var t = _tile_map[key]
		var parts = key.split(",")
		var dist = abs(int(parts[0]) - center_q) + abs(int(parts[1]) - center_r)
		if dist > max_search_radius: continue
		var chance = float(t.get("rift_chance", 0.0))
		if chance > highest:
			highest = chance
			best = t.duplicate()
	return best


func get_biomes() -> Array[Dictionary]:
	return _biome_definitions.duplicate(true)


# TODO Methods -- not yet implemented

func add_rift_node(x: int, y: int, is_active: bool = true) -> void:
	_active_rift_nodes.append({"x": x, "y": y, "active": is_active})


## get_visual_tile / get_tile_visual removed in v0.3.0 — tile rendering is now
## handled by TileSetService + LocalMapView (Godot 4.3 TileMapLayer). WorldGenerator
## only owns sphere-gen + biome classification, not visuals.
