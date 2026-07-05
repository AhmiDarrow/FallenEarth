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


## Visual tile helper for hand-drawn assets. Uses TileSetBuilder when available for dynamic scanning of curated + generated tiles.
var _visual_tile_cache: Dictionary = {}  # biome -> list of texture paths
var _tile_builder = null

func get_visual_tile(biome_name: String) -> String:
	if _visual_tile_cache.is_empty():
		_load_visual_tiles()
	var key = biome_name.replace("_", " ").capitalize()
	if key in _visual_tile_cache and _visual_tile_cache[key].size() > 0:
		var list = _visual_tile_cache[key]
		return list[randi() % list.size()]
	# fallback any
	for b in _visual_tile_cache:
		if _visual_tile_cache[b].size() > 0:
			return _visual_tile_cache[b][randi() % _visual_tile_cache[b].size()]
	return ""

func _load_visual_tiles():
	_visual_tile_cache.clear()
	# Dynamic scan using TileSetBuilder or direct dir scan so all 10 biomes work as files are generated
	if _tile_builder == null:
		var b = load("res://scripts/TileSetBuilder.gd")
		if b:
			_tile_builder = b.new()
			add_child(_tile_builder)

	var known_biomes = ["Ash Wastes", "Rust Canyons", "Neon Bogs", "Scorched Plains", "Ironwood Thicket", "Glass Dunes", "Corpse Fields", "Stormspire Highlands", "Toxin Marshes", "Dead City Outskirts"]

	if _tile_builder and _tile_builder.has_method("get_paths_for_biome"):
		for bn in known_biomes:
			var paths = _tile_builder.get_paths_for_biome(bn)
			if paths.size() > 0:
				_visual_tile_cache[bn] = paths
	else:
		# Fallback direct scan for any biome folder with pngs
		var da = DirAccess.open("res://assets/tilesets/")
		if da:
			da.list_dir_begin()
			var bname = da.get_next()
			while bname != "":
				if da.current_is_dir() and bname != ".." and bname != ".":
					var bpath = "res://assets/tilesets/" + bname + "/"
					var files = []
					for sub in ["selected", "ground", "debris", "vegetation"]:
						var sda = DirAccess.open(bpath + sub)
						if sda:
							sda.list_dir_begin()
							var sf = sda.get_next()
							while sf != "":
								if sf.ends_with(".png"): files.append(bpath + sub + "/" + sf)
								sf = sda.get_next()
							sda.list_dir_end()
					if files.size() > 0:
						_visual_tile_cache[bname.replace("_", " ").capitalize()] = files
				bname = da.get_next()
			da.list_dir_end()

	# Ensure fallbacks for all 10 (use available good tiles until generated)
	if not _visual_tile_cache.has("Ash Wastes"):
		_visual_tile_cache["Ash Wastes"] = ["res://assets/tilesets/ash_wastes/selected/ash_wastes_ground_001.png"]
	if not _visual_tile_cache.has("Rust Canyons"):
		_visual_tile_cache["Rust Canyons"] = ["res://assets/tilesets/rust_canyons/rust_canyons_tile_001.png"]
	if not _visual_tile_cache.has("Neon Bogs"):
		_visual_tile_cache["Neon Bogs"] = ["res://assets/tilesets/neon_bogs/neon_tile_00001_.png"]
	if not _visual_tile_cache.has("Glass Dunes"):
		_visual_tile_cache["Glass Dunes"] = ["res://assets/tilesets/glass_dunes/tile_glass_dunes_ground_00001_.png"]
	if not _visual_tile_cache.has("Toxin Marshes"):
		_visual_tile_cache["Toxin Marshes"] = ["res://assets/tilesets/toxin_marshes/tile_toxin_marshes_ground_00001_.png"]
	if not _visual_tile_cache.has("Scorched Plains"):
		_visual_tile_cache["Scorched Plains"] = ["res://assets/tilesets/scorched_plains/tile_scorched_plains_ground_00001_.png"]
	if not _visual_tile_cache.has("Corpse Fields"):
		_visual_tile_cache["Corpse Fields"] = ["res://assets/tilesets/corpse_fields/tile_corpse_fields_ground_00001_.png"]
	if not _visual_tile_cache.has("Stormspire Highlands"):
		_visual_tile_cache["Stormspire Highlands"] = ["res://assets/tilesets/stormspire_highlands/tile_stormspire_highlands_ground_00001_.png"]
	if not _visual_tile_cache.has("Dead City Outskirts"):
		_visual_tile_cache["Dead City Outskirts"] = ["res://assets/tilesets/dead_city_outskirts/tile_dead_city_outskirts_ground_00001_.png"]
	for bn in known_biomes:
		if not _visual_tile_cache.has(bn):
			_visual_tile_cache[bn] = _visual_tile_cache["Ash Wastes"]  # fallback to good ash until generated

	print("[WorldGenerator] Visual tiles loaded dynamically for all available biomes (style ref: master_test_01.png). Biomes with visuals: ", _visual_tile_cache.size())


func get_tile_visual(biome_name: String, q: int, r: int) -> String:
	# Prefer dynamic from builder (curated + scanned files)
	if _tile_builder == null:
		var b = load("res://scripts/TileSetBuilder.gd")
		if b:
			_tile_builder = b.new()
			add_child(_tile_builder)

	var paths := []
	if _tile_builder and _tile_builder.has_method("get_paths_for_biome"):
		paths = _tile_builder.get_paths_for_biome(biome_name)
		if paths.size() == 0:
			paths = _tile_builder.get_paths_for_biome("Ash Wastes")

	if paths.size() > 0:
		return paths[(abs(q) + abs(r)) % paths.size()]

	# Hard fallback (matches current curated passing assets)
	var visuals := []
	match biome_name:
		"Ash Wastes":
			visuals = [
				"res://assets/tilesets/ash_wastes/selected/ash_wastes_ground_001.png",
				"res://assets/tilesets/ash_wastes/selected/ash_wastes_debris_003.png",
				"res://assets/tilesets/ash_wastes/selected/ash_wastes_vegetation_001.png",
			]
		"Rust Canyons":
			visuals = [
				"res://assets/tilesets/rust_canyons/selected/rust_canyons_tile_001.png",
				"res://assets/tilesets/rust_canyons/selected/rust_canyons_tile_003.png",
			]
		"Neon Bogs":
			visuals = [
				"res://assets/tilesets/neon_bogs/selected/neon_tile_00001_.png",
			]
		"Glass Dunes":
			visuals = [
				"res://assets/tilesets/glass_dunes/tile_glass_dunes_ground_00001_.png",
				"res://assets/tilesets/glass_dunes/tile_glass_dunes_debris_00001_.png",
				"res://assets/tilesets/glass_dunes/tile_glass_dunes_vegetation_00001_.png",
			]
		"Toxin Marshes":
			visuals = [
				"res://assets/tilesets/toxin_marshes/tile_toxin_marshes_ground_00001_.png",
				"res://assets/tilesets/toxin_marshes/tile_toxin_marshes_debris_00001_.png",
				"res://assets/tilesets/toxin_marshes/tile_toxin_marshes_vegetation_00001_.png",
			]
		"Scorched Plains":
			visuals = [
				"res://assets/tilesets/scorched_plains/tile_scorched_plains_ground_00001_.png",
				"res://assets/tilesets/scorched_plains/tile_scorched_plains_debris_00001_.png",
				"res://assets/tilesets/scorched_plains/tile_scorched_plains_vegetation_00001_.png",
			]
		"Corpse Fields":
			visuals = [
				"res://assets/tilesets/corpse_fields/tile_corpse_fields_ground_00001_.png",
				"res://assets/tilesets/corpse_fields/tile_corpse_fields_debris_00001_.png",
			]
		"Stormspire Highlands":
			visuals = [
				"res://assets/tilesets/stormspire_highlands/tile_stormspire_highlands_ground_00001_.png",
				"res://assets/tilesets/stormspire_highlands/tile_stormspire_highlands_debris_00001_.png",
			]
		"Dead City Outskirts":
			visuals = [
				"res://assets/tilesets/dead_city_outskirts/tile_dead_city_outskirts_ground_00001_.png",
				"res://assets/tilesets/dead_city_outskirts/tile_dead_city_outskirts_debris_00001_.png",
			]
		"Ironwood Thicket":
			visuals = [
				"res://assets/tilesets/ironwood_thicket/tile_ironwood_thicket_ground_00001_.png",
				"res://assets/tilesets/ironwood_thicket/tile_ironwood_thicket_debris_00001_.png",
			]
		_:
			visuals = ["res://assets/tilesets/ash_wastes/selected/ash_wastes_ground_001.png"]
	if visuals.size() > 0:
		return visuals[(abs(q) + abs(r)) % visuals.size()]
	return ""
