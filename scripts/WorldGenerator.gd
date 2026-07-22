## WorldGenerator -- Full geodesic hexasphere world (RimWorld-inspired site pick).
## Topology: icosahedron frequency-F (10*F^2+2 tiles, 12 pentagons + hexes).
## Keys remain "q,r" (q=id, r=0); adjacency via neighbor_keys, not axial offsets.
## Biomes: lat/lon climate + noise + target-share rebalance. See ARCHITECTURE.md.
class_name WorldGenerator
extends Node

signal world_generated(seed_string: String)

const VERSION := "0.2.0"
const DATA_PATH := "res://data/biomes.json"
const FACTIONS_PATH := "res://data/factions.json"
const TOWNS_PATH := "res://data/towns.json"
## Climate envelopes: [temp_lo, temp_hi, rain_lo, rain_hi, elev_lo, elev_hi]
const BIOME_CLIMATE_PROFILES: Dictionary = {
	"Ash Wastes": [0.45, 0.75, 0.25, 0.55, 0.25, 0.65],
	"Rust Canyons": [0.25, 0.55, 0.15, 0.55, 0.55, 0.95],
	"Neon Bogs": [0.45, 0.75, 0.55, 0.95, 0.0, 0.35],
	"Scorched Plains": [0.65, 1.0, 0.05, 0.35, 0.25, 0.65],
	"Ironwood Thicket": [0.35, 0.65, 0.45, 0.85, 0.25, 0.75],
	"Glass Dunes": [0.55, 0.95, 0.0, 0.30, 0.35, 0.75],
	"Corpse Fields": [0.25, 0.60, 0.25, 0.65, 0.15, 0.55],
	"Stormspire Highlands": [0.05, 0.40, 0.35, 0.75, 0.65, 1.0],
	"Toxin Marshes": [0.35, 0.70, 0.65, 1.0, 0.0, 0.35],
	"Dead City Outskirts": [0.30, 0.65, 0.25, 0.65, 0.35, 0.75],
}
## Relative target share weights (normalized at runtime). Starter biomes slightly higher.
const BIOME_TARGET_WEIGHTS: Dictionary = {
	"Ash Wastes": 1.35,
	"Rust Canyons": 0.95,
	"Neon Bogs": 0.95,
	"Scorched Plains": 1.05,
	"Ironwood Thicket": 1.15,
	"Glass Dunes": 0.90,
	"Corpse Fields": 1.00,
	"Stormspire Highlands": 0.90,
	"Toxin Marshes": 0.95,
	"Dead City Outskirts": 1.00,
}
## Soft cap: no biome may exceed this fraction after rebalance (medium worlds).
const BIOME_MAX_SHARE := 0.18
const BIOME_MIN_SHARE := 0.04
## Pack hex flat-to-flat vs min neighbor gap (higher = tighter / closer together).
const HEX_PACK_RATIO := 0.97
var _hex_radius: int = 12  # UI size knob (8/12/18); maps to hexasphere frequency
var _hex_frequency: int = 7  # geodesic frequency (tiles ≈ 10F²+2)

var _seed: String = ""
var _tile_map: Dictionary = {}  # key "q,r" -> tile dict
var _biome_definitions: Array[Dictionary] = []
## Full-sphere unit positions + adjacency (filled by generate / layout).
static var _sphere_unit: Dictionary = {}  # key -> Vector3 (unit)
static var _sphere_neighbors: Dictionary = {}  # key -> Array[String]
static var _sphere_tile_count: int = 0


## Town and Riftspire data populated by _place_towns (called from generate()).
## Stored on world_data so the same world can be reloaded.
var _towns_seeded: Array = []  # [{hex, faction, template, npc_ids}]
var _riftspire_hex_key: String = ""
var _faction_names: Array = []  # cached from data/factions.json
var _town_templates: Dictionary = {}  # cached from data/towns.json


## Deterministic seed from string using local RNG (avoids global seed() mutation).
func randseed_from_string(s: String) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = s.hash()
var _rng: RandomNumberGenerator


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

	# Cache faction names and town templates for the town placement pass.
	_load_faction_names()
	_load_town_templates()
	return true


func _load_faction_names() -> void:
	_faction_names = []
	if not ResourceLoader.exists(FACTIONS_PATH):
		return
	var raw = load(FACTIONS_PATH)
	if raw == null:
		return
	var data = raw.data if "data" in raw else raw
	if not (data is Dictionary):
		return
	for f in data.get("factions", []):
		if f is Dictionary:
			_faction_names.append(str(f.get("name", "")))


func _load_town_templates() -> void:
	_town_templates = {}
	if not ResourceLoader.exists(TOWNS_PATH):
		return
	var raw = load(TOWNS_PATH)
	if raw == null:
		return
	var data = raw.data if "data" in raw else raw
	if not (data is Dictionary):
		return
	_town_templates = data.get("templates", {})


## Generate full-sphere hex world (Goldberg / hexasphere).
## size UI knob: 8→F5(252), 12→F7(492), 18→F10(1002). Keys stay "q,r" with r=0, q=id.
func generate(world_seed: String, difficulty_modifier: float = 1.0, size: int = 12) -> Dictionary:
	_seed = world_seed
	_hex_radius = size
	_hex_frequency = size_to_hex_frequency(size)
	randseed_from_string(world_seed)

	var sphere: Dictionary = build_hexasphere(_hex_frequency, 1.0)
	var unit_positions: PackedVector3Array = sphere.get("unit_positions", PackedVector3Array())
	var neighbor_ids: Array = sphere.get("neighbor_ids", [])
	var n_tiles: int = int(sphere.get("tile_count", 0))

	var tile_map: Dictionary = {}
	var biomes = _biome_definitions

	var elev_noise_gen := FastNoiseLite.new()
	elev_noise_gen.seed = _seed.hash() + 1000
	elev_noise_gen.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elev_noise_gen.frequency = 0.55
	elev_noise_gen.fractal_octaves = 3

	var rain_noise_gen := FastNoiseLite.new()
	rain_noise_gen.seed = _seed.hash() + 2000
	rain_noise_gen.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	rain_noise_gen.frequency = 0.65
	rain_noise_gen.fractal_octaves = 2

	var biome_counts: Dictionary = {}
	var tiles_placed: int = 0
	var weight_sum: float = 0.0
	for b in biomes:
		weight_sum += float(BIOME_TARGET_WEIGHTS.get(str(b.get("name", "")), 1.0))
	if weight_sum < 1e-6:
		weight_sum = 1.0

	var assigned_biomes: Dictionary = {}
	_sphere_unit.clear()
	_sphere_neighbors.clear()
	_sphere_tile_count = n_tiles

	for i in range(n_tiles):
		var u: Vector3 = unit_positions[i]
		var key: String = tile_key_from_id(i)
		var q: int = i
		var r: int = 0

		var lat: float = asin(clampf(u.y, -1.0, 1.0))  # -PI/2..PI/2
		var lon: float = atan2(u.x, u.z)
		var lat_n: float = lat / (PI * 0.5)  # -1..1
		var abs_lat: float = absf(lat_n)

		var elev_noise: float = elev_noise_gen.get_noise_3d(u.x, u.y, u.z)
		var elevation: float = clampf(0.5 + elev_noise * 0.42 + abs_lat * 0.08, 0.0, 1.0)

		# Hot equator, cold poles
		var temp: float = 0.88 - abs_lat * 0.72 - (elevation - 0.5) * 0.35
		temp = clampf(temp, 0.0, 1.0)

		var rain_raw: float = rain_noise_gen.get_noise_3d(u.x + 3.1, u.y - 1.7, u.z + 0.4) * 0.55
		rain_raw -= (elevation - 0.5) * 0.45
		rain_raw += (1.0 - abs_lat) * 0.08  # wetter tropics
		var rain: float = clampf(0.5 + rain_raw, 0.0, 1.0)

		var neighbor_bonus: Dictionary = {}
		var nlist: Array = neighbor_ids[i] if i < neighbor_ids.size() else []
		var nkeys: Array = []
		for nid in nlist:
			var nk: String = tile_key_from_id(int(nid))
			nkeys.append(nk)
			if assigned_biomes.has(nk):
				var nb: String = assigned_biomes[nk]
				neighbor_bonus[nb] = neighbor_bonus.get(nb, 0.0) + 1.0

		var chosen_biome = _pick_biome_by_climate(
			temp, rain, elevation, biomes, neighbor_bonus, biome_counts, tiles_placed, weight_sum
		)
		var chosen_name: String = str(chosen_biome.get("name", ""))
		assigned_biomes[key] = chosen_name
		biome_counts[chosen_name] = int(biome_counts.get(chosen_name, 0)) + 1
		tiles_placed += 1

		var tile: Dictionary = chosen_biome.duplicate(true)
		if not tile.has("rift_chance"):
			tile["rift_chance"] = 0.3
		tile["rift_chance"] *= difficulty_modifier
		tile["q"] = q
		tile["r"] = r
		tile["id"] = i
		tile["unit_pos"] = [u.x, u.y, u.z]  # JSON-safe; use unit_pos_vec()
		tile["neighbor_keys"] = nkeys
		tile["elevation"] = elevation
		tile["temperature"] = temp
		tile["rainfall"] = rain
		tile["latitude"] = lat
		tile["longitude"] = lon
		tile["features"] = tile.get("features", []) + _get_features(elevation, rain)
		tile["is_start_candidate"] = _is_good_start(tile)
		tile_map[key] = tile
		_sphere_unit[key] = u
		_sphere_neighbors[key] = nkeys

	_ensure_biome_diversity(tile_map, biomes)
	_rebalance_biome_shares(tile_map, biomes)

	# Refresh unit/neighbor caches after rebalance (keys unchanged)
	for key in tile_map:
		var t: Dictionary = tile_map[key]
		if t.has("unit_pos"):
			_sphere_unit[key] = unit_pos_vec(t)
		if t.has("neighbor_keys"):
			_sphere_neighbors[key] = t["neighbor_keys"]

	_tile_map = tile_map
	_place_towns()
	world_generated.emit(world_seed)
	return tile_map


static func tile_key_from_id(id: int) -> String:
	return "%d,0" % id


## Coerce tile unit_pos (Vector3 or [x,y,z] array) to Vector3.
static func unit_pos_vec(tile: Dictionary) -> Vector3:
	return _coerce_vec3(tile.get("unit_pos", null))


## Coerce Variant (Vector3 / Array / PackedFloat32Array) to Vector3.
static func _coerce_vec3(raw: Variant) -> Vector3:
	if raw is Vector3:
		return raw
	if raw is Array:
		var a: Array = raw
		if a.size() >= 3:
			return Vector3(float(a[0]), float(a[1]), float(a[2]))
	if raw is PackedFloat32Array:
		var p: PackedFloat32Array = raw
		if p.size() >= 3:
			return Vector3(p[0], p[1], p[2])
	return Vector3(0, 0, 1)


static func size_to_hex_frequency(size: int) -> int:
	if size <= 8:
		return 5
	if size <= 12:
		return 7
	return 10


static func hexasphere_tile_count(frequency: int) -> int:
	var f: int = maxi(frequency, 1)
	return 10 * f * f + 2


func _pick_biome_by_climate(
	temp: float,
	rain: float,
	elev: float,
	biomes: Array,
	neighbor_bonus: Dictionary = {},
	biome_counts: Dictionary = {},
	tiles_placed: int = 0,
	weight_sum: float = 1.0
) -> Dictionary:
	var best_score = -999.0
	var best = biomes[0] if biomes.size() > 0 else {"name": "Ash Wastes"}
	for b in biomes:
		var name: String = str(b.get("name", ""))
		var score: float = _climate_score_for(temp, rain, elev, name)

		# Mild clustering so biomes form regions without continent-scale takeover
		score += float(neighbor_bonus.get(name, 0.0)) * 0.22

		# Soft target-share: penalize biomes already above their weight share
		if tiles_placed > 8 and weight_sum > 0.0:
			var w: float = float(BIOME_TARGET_WEIGHTS.get(name, 1.0))
			var target: float = w / weight_sum
			var share: float = float(biome_counts.get(name, 0)) / float(tiles_placed)
			if share > target:
				score -= (share - target) * 4.5
			else:
				score += (target - share) * 1.2

		score += _rng.randf_range(-0.35, 0.35)

		if score > best_score:
			best_score = score
			best = b
	return best.duplicate(true)


func _biome_def_by_name(biomes: Array, bname: String) -> Dictionary:
	for b in biomes:
		if str(b.get("name", "")) == bname:
			return b
	return {}


func _write_biome_onto_tile(tile_map: Dictionary, key: String, biome_def: Dictionary) -> void:
	if biome_def.is_empty() or not tile_map.has(key):
		return
	var old: Dictionary = tile_map[key]
	if old.get("is_riftspire", false) or old.get("is_town", false):
		return
	var forced: Dictionary = biome_def.duplicate(true)
	forced["q"] = old.get("q")
	forced["r"] = old.get("r")
	forced["id"] = old.get("id", old.get("q", 0))
	forced["unit_pos"] = old.get("unit_pos")
	forced["neighbor_keys"] = old.get("neighbor_keys", [])
	forced["latitude"] = old.get("latitude")
	forced["longitude"] = old.get("longitude")
	forced["elevation"] = old.get("elevation")
	forced["temperature"] = old.get("temperature")
	forced["rainfall"] = old.get("rainfall")
	var elev_f: float = float(old.get("elevation", 0.5))
	var rain_f: float = float(old.get("rainfall", 0.5))
	forced["features"] = forced.get("features", []) + _get_features(elev_f, rain_f)
	forced["is_start_candidate"] = _is_good_start(forced)
	if not forced.has("rift_chance"):
		forced["rift_chance"] = 0.3
	tile_map[key] = forced


func _ensure_biome_diversity(tile_map: Dictionary, biomes: Array) -> void:
	var present: Dictionary = {}
	for k in tile_map:
		present[str(tile_map[k].get("name", ""))] = true
	for b in biomes:
		var bname: String = str(b.get("name", ""))
		if present.has(bname):
			continue
		var best_k := ""
		var best_s := -999.0
		for k in tile_map:
			var t: Dictionary = tile_map[k]
			if t.get("is_riftspire", false) or t.get("is_town", false):
				continue
			var s: float = _climate_score_for(
				float(t.get("temperature", 0.5)),
				float(t.get("rainfall", 0.5)),
				float(t.get("elevation", 0.5)),
				bname
			)
			if s > best_s:
				best_s = s
				best_k = k
		if best_k != "":
			_write_biome_onto_tile(tile_map, best_k, b)
			present[bname] = true


func _rebalance_biome_shares(tile_map: Dictionary, biomes: Array) -> void:
	var total: int = tile_map.size()
	if total < 10 or biomes.is_empty():
		return
	var weight_sum: float = 0.0
	for b in biomes:
		weight_sum += float(BIOME_TARGET_WEIGHTS.get(str(b.get("name", "")), 1.0))
	if weight_sum < 1e-6:
		weight_sum = float(biomes.size())

	var max_allowed: int = maxi(int(ceil(float(total) * BIOME_MAX_SHARE)), 2)
	var min_allowed: int = maxi(int(floor(float(total) * BIOME_MIN_SHARE)), 1)

	# Count current
	var counts: Dictionary = {}
	var keys_by_biome: Dictionary = {}
	for k in tile_map:
		var t: Dictionary = tile_map[k]
		if t.get("is_riftspire", false) or t.get("is_town", false):
			continue
		var n: String = str(t.get("name", ""))
		counts[n] = int(counts.get(n, 0)) + 1
		if not keys_by_biome.has(n):
			keys_by_biome[n] = []
		keys_by_biome[n].append(k)

	# Pull from over-represented into under-represented (climate-aware)
	for _iter in range(total):  # bounded
		var donor := ""
		var donor_over := 0
		var needy := ""
		var needy_deficit := 0
		for b in biomes:
			var n: String = str(b.get("name", ""))
			var c: int = int(counts.get(n, 0))
			var w: float = float(BIOME_TARGET_WEIGHTS.get(n, 1.0))
			var ideal: int = int(round(float(total) * (w / weight_sum)))
			ideal = clampi(ideal, min_allowed, max_allowed)
			if c > max_allowed and c - max_allowed > donor_over:
				donor = n
				donor_over = c - max_allowed
			if c < min_allowed and min_allowed - c > needy_deficit:
				needy = n
				needy_deficit = min_allowed - c
			# Also prefer filling toward ideal if no hard min breach
			if needy == "" and c < ideal:
				var def: int = ideal - c
				if def > needy_deficit:
					needy = n
					needy_deficit = def
			if donor == "" and c > ideal + 2:
				var over: int = c - ideal
				if over > donor_over:
					donor = n
					donor_over = over
		if donor == "" or needy == "" or donor == needy:
			break
		var dkeys: Array = keys_by_biome.get(donor, [])
		if dkeys.is_empty():
			break
		# Pick donor tile with best climate fit for needy biome
		var best_i := 0
		var best_s := -999.0
		for i in range(dkeys.size()):
			var tk: String = str(dkeys[i])
			var t: Dictionary = tile_map[tk]
			var s: float = _climate_score_for(
				float(t.get("temperature", 0.5)),
				float(t.get("rainfall", 0.5)),
				float(t.get("elevation", 0.5)),
				needy
			)
			# Prefer weak fit to current donor biome
			s -= _climate_score_for(
				float(t.get("temperature", 0.5)),
				float(t.get("rainfall", 0.5)),
				float(t.get("elevation", 0.5)),
				donor
			) * 0.35
			if s > best_s:
				best_s = s
				best_i = i
		var move_k: String = str(dkeys[best_i])
		dkeys.remove_at(best_i)
		keys_by_biome[donor] = dkeys
		var bdef: Dictionary = _biome_def_by_name(biomes, needy)
		_write_biome_onto_tile(tile_map, move_k, bdef)
		counts[donor] = int(counts.get(donor, 1)) - 1
		counts[needy] = int(counts.get(needy, 0)) + 1
		if not keys_by_biome.has(needy):
			keys_by_biome[needy] = []
		keys_by_biome[needy].append(move_k)


## Pure climate fit (no neighbor, no jitter). Used by both picker and diversity enforcement.
func _climate_score_for(temp: float, rain: float, elev: float, biome_name: String) -> float:
	var p: Array = BIOME_CLIMATE_PROFILES.get(biome_name, [0.0, 1.0, 0.0, 1.0, 0.0, 1.0])
	var tf = _range_fit(temp, p[0], p[1])
	var rf = _range_fit(rain, p[2], p[3])
	var ef = _range_fit(elev, p[4], p[5])
	return tf + rf + ef


## Returns 0.0-1.0: how well `val` fits inside [lo, hi]. 1.0 = inside, falls off outside.
func _range_fit(val: float, lo: float, hi: float) -> float:
	if val >= lo and val <= hi:
		return 1.0
	var dist: float = 0.0
	if val < lo:
		dist = lo - val
	else:
		dist = val - hi
	return max(0.0, 1.0 - dist * 3.0)


func _get_features(elev: float, rain: float) -> Array:
	var feats = []
	if elev > 0.7: feats.append("high_elevation")
	if rain > 0.7: feats.append("wetlands")
	if elev < 0.3 and rain > 0.5: feats.append("flood_prone")
	return feats


func _is_good_start(tile: Dictionary) -> bool:
	# Only tier 1-2 biomes are valid start locations
	var tier: int = int(tile.get("difficulty_tier", 5))
	if tier > 2:
		return false
	# RimWorld-like good start: decent temp/rain, not extreme
	var temp = tile.get("temperature", 0.5)
	var rain = tile.get("rainfall", 0.5)
	var elev = tile.get("elevation", 0.5)
	return temp > 0.35 and temp < 0.75 and rain > 0.3 and elev < 0.85


func load_from_tile_map(tile_map: Dictionary, world_seed: String = "") -> void:
	_tile_map = tile_map.duplicate(true)
	_seed = world_seed
	_sphere_unit.clear()
	_sphere_neighbors.clear()
	_sphere_tile_count = _tile_map.size()
	for key in _tile_map:
		var t: Dictionary = _tile_map[key]
		if t.has("unit_pos"):
			_sphere_unit[key] = unit_pos_vec(t)
		if t.has("neighbor_keys"):
			_sphere_neighbors[key] = t["neighbor_keys"]


func get_tile_at(q: int, r: int) -> Dictionary:
	var key = "%d,%d" % [q, r]
	if _tile_map.has(key):
		return _tile_map[key].duplicate(true)
	return {}


static func hex_distance(q1: int, r1: int, q2: int, r2: int) -> int:
	var k1: String = "%d,%d" % [q1, r1]
	var k2: String = "%d,%d" % [q2, r2]
	if _sphere_unit.has(k1) and _sphere_unit.has(k2) and _sphere_tile_count > 0:
		var a: Vector3 = _coerce_vec3(_sphere_unit[k1])
		var b: Vector3 = _coerce_vec3(_sphere_unit[k2])
		var ang: float = a.angle_to(b)
		var step: float = sqrt(4.0 * PI / float(_sphere_tile_count))
		if step < 1e-6:
			return 0
		return maxi(0, int(round(ang / step)))
	var s1 := -q1 - r1
	var s2 := -q2 - r2
	return int((abs(q1 - q2) + abs(r1 - r2) + abs(s1 - s2)) / 2.0)


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


## Axial hex plane metric (flat-top), same units as create_hex_points / packing.
static func axial_to_plane(q: int, r: int) -> Vector2:
	var px: float = sqrt(3.0) * float(q) + sqrt(3.0) / 2.0 * float(r)
	var py: float = 1.5 * float(r)
	return Vector2(px, py)


## Max plane distance from origin for an axial disk of the given radius.
static func hex_disk_max_plane_dist(hex_radius: int) -> float:
	return float(maxi(hex_radius, 1)) * sqrt(3.0)


## Resolve sphere position for a tile (full hexasphere).
static func get_hex_spherical_pos(
	q: int,
	r: int,
	_hex_radius: int = 12,
	sphere_radius: float = 4.0,
	_half_span_deg: float = 72.0
) -> Vector3:
	var key: String = "%d,%d" % [q, r]
	if _sphere_unit.has(key):
		return _coerce_vec3(_sphere_unit[key]) * sphere_radius
	if r == 0 and _sphere_unit.has(tile_key_from_id(q)):
		return _coerce_vec3(_sphere_unit[tile_key_from_id(q)]) * sphere_radius
	return Vector3(0.0, 0.0, sphere_radius)


## Geodesic hexasphere: icosahedron frequency-F subdivision. Vertices = tile centers
## (12 pentagons + hexes). Count = 10*F^2 + 2.
static func build_hexasphere(frequency: int, sphere_radius: float = 1.0) -> Dictionary:
	var F: int = maxi(frequency, 1)
	var base: PackedVector3Array = _icosahedron_vertices()
	var faces: Array = _icosahedron_faces()
	var vert_list: Array[Vector3] = []
	var vert_lookup: Dictionary = {}
	var edges: Dictionary = {}

	for face in faces:
		var v0: Vector3 = base[int(face[0])]
		var v1: Vector3 = base[int(face[1])]
		var v2: Vector3 = base[int(face[2])]
		var grid: Array = []
		for i in range(F + 1):
			var row: Array = []
			for j in range(F - i + 1):
				var k: int = F - i - j
				var p: Vector3 = (v0 * float(k) + v1 * float(i) + v2 * float(j)) / float(F)
				var nrm: Vector3 = p.normalized()
				var qk: String = "%d_%d_%d" % [
					int(round(nrm.x * 100000.0)),
					int(round(nrm.y * 100000.0)),
					int(round(nrm.z * 100000.0)),
				]
				var idx: int
				if vert_lookup.has(qk):
					idx = int(vert_lookup[qk])
				else:
					idx = vert_list.size()
					vert_list.append(nrm)
					vert_lookup[qk] = idx
				row.append(idx)
			grid.append(row)
		for i in range(F + 1):
			for j in range(F - i + 1):
				var a: int = int(grid[i][j])
				if j < F - i:
					var b1: int = int(grid[i][j + 1])
					var lo1: int = mini(a, b1)
					var hi1: int = maxi(a, b1)
					edges["%d,%d" % [lo1, hi1]] = true
				if i < F and j <= F - i - 1:
					var b2: int = int(grid[i + 1][j])
					var lo2: int = mini(a, b2)
					var hi2: int = maxi(a, b2)
					edges["%d,%d" % [lo2, hi2]] = true
				if i < F and j > 0:
					var b3: int = int(grid[i + 1][j - 1])
					var lo3: int = mini(a, b3)
					var hi3: int = maxi(a, b3)
					edges["%d,%d" % [lo3, hi3]] = true

	var n: int = vert_list.size()
	var adj_sets: Array = []
	adj_sets.resize(n)
	for i in range(n):
		adj_sets[i] = {}
	for ek in edges:
		var parts: PackedStringArray = str(ek).split(",")
		var ea: int = int(parts[0])
		var eb: int = int(parts[1])
		adj_sets[ea][eb] = true
		adj_sets[eb][ea] = true

	var unit_positions := PackedVector3Array()
	unit_positions.resize(n)
	var neighbor_ids: Array = []
	neighbor_ids.resize(n)
	_sphere_unit.clear()
	_sphere_neighbors.clear()
	_sphere_tile_count = n
	for i in range(n):
		unit_positions[i] = vert_list[i]
		var ids: Array = (adj_sets[i] as Dictionary).keys()
		ids.sort()
		neighbor_ids[i] = ids
		var key: String = tile_key_from_id(i)
		_sphere_unit[key] = unit_positions[i]
		var nkeys: Array = []
		for nid in ids:
			nkeys.append(tile_key_from_id(int(nid)))
		_sphere_neighbors[key] = nkeys

	return {
		"tile_count": n,
		"frequency": F,
		"unit_positions": unit_positions,
		"neighbor_ids": neighbor_ids,
		"sphere_radius": sphere_radius,
	}


static func _icosahedron_vertices() -> PackedVector3Array:
	var t: float = (1.0 + sqrt(5.0)) / 2.0
	var raw: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	var out := PackedVector3Array()
	out.resize(12)
	for i in range(12):
		out[i] = raw[i].normalized()
	return out


static func _icosahedron_faces() -> Array:
	return [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]


## Place every tile on the full sphere; size meshes from measured neighbor gap.
static func build_hex_sphere_layout(tile_map: Dictionary, hex_radius: int, sphere_radius: float = 4.0) -> Dictionary:
	var positions: Dictionary = {}
	if not tile_map.is_empty():
		var sample_key: String = str(tile_map.keys()[0])
		var sample: Dictionary = tile_map[sample_key]
		if not sample.has("unit_pos") and not _sphere_unit.has(sample_key):
			build_hexasphere(size_to_hex_frequency(hex_radius), 1.0)

	for key in tile_map:
		var tile: Dictionary = tile_map[key]
		if tile.has("unit_pos"):
			positions[key] = unit_pos_vec(tile) * sphere_radius
		elif _sphere_unit.has(key):
			positions[key] = _coerce_vec3(_sphere_unit[key]) * sphere_radius
		else:
			var q: int = int(tile.get("q", 0))
			var r: int = int(tile.get("r", 0))
			positions[key] = get_hex_spherical_pos(q, r, hex_radius, sphere_radius)

	var min_nn: float = 1e9
	var max_nn: float = 0.0
	var nn_count: int = 0
	var sum_nn: float = 0.0
	for key in tile_map:
		var tile: Dictionary = tile_map[key]
		var p0: Vector3 = positions[key]
		var nkeys: Array = tile.get("neighbor_keys", _sphere_neighbors.get(key, []))
		var local_min: float = 1e9
		for nk in nkeys:
			if not positions.has(str(nk)):
				continue
			var dist: float = p0.distance_to(positions[str(nk)])
			if dist < 1e-6:
				continue
			if dist < local_min:
				local_min = dist
		if local_min < 1e8:
			min_nn = minf(min_nn, local_min)
			max_nn = maxf(max_nn, local_min)
			sum_nn += local_min
			nn_count += 1

	if nn_count <= 0 or min_nn >= 1e8:
		var step: float = sqrt(4.0 * PI / float(maxi(tile_map.size(), 1)))
		min_nn = 2.0 * sphere_radius * sin(step * 0.5)
		max_nn = min_nn
		sum_nn = min_nn
		nn_count = 1

	var avg_nn: float = sum_nn / float(nn_count)
	var pack_width: float = min_nn * HEX_PACK_RATIO
	var hex_size: float = pack_width / sqrt(3.0)
	var nn_ratio: float = max_nn / min_nn if min_nn > 1e-8 else 999.0
	var pack_ratio: float = pack_width / min_nn if min_nn > 1e-8 else 999.0
	return {
		"positions": positions,
		"hex_size": hex_size,
		"min_neighbor": min_nn,
		"avg_neighbor": avg_nn,
		"max_neighbor": max_nn,
		"nn_ratio": nn_ratio,
		"pack_ratio": pack_ratio,
		"sphere_radius": sphere_radius,
		"tile_count": positions.size(),
	}


## Creates a simple extruded hexagonal prism mesh (top + bottom + sides).
## size = flat to flat radius of hex, height = extrusion along local Z.
static func create_hex_prism_mesh(size: float, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts_top: Array[Vector3] = []
	var verts_bot: Array[Vector3] = []
	for i in 6:
		var a := deg_to_rad(60.0 * i - 30.0)
		verts_top.append(Vector3(cos(a) * size, sin(a) * size, height * 0.5))
		verts_bot.append(Vector3(cos(a) * size, sin(a) * size, -height * 0.5))
	var c_top := Vector3(0, 0, height * 0.5)
	var c_bot := Vector3(0, 0, -height * 0.5)
	# top cap (outward normal)
	for i in 6:
		var j := (i + 1) % 6
		st.add_vertex(c_top)
		st.add_vertex(verts_top[i])
		st.add_vertex(verts_top[j])
	# bottom cap
	for i in 6:
		var j := (i + 1) % 6
		st.add_vertex(c_bot)
		st.add_vertex(verts_bot[j])
		st.add_vertex(verts_bot[i])
	# sides
	for i in 6:
		var j := (i + 1) % 6
		var t0 := verts_top[i]
		var t1 := verts_top[j]
		var b0 := verts_bot[i]
		var b1 := verts_bot[j]
		st.add_vertex(t0)
		st.add_vertex(b0)
		st.add_vertex(t1)
		st.add_vertex(t1)
		st.add_vertex(b0)
		st.add_vertex(b1)
	st.generate_normals()
	return st.commit()


## Generate approximately uniform points on a sphere using Fibonacci lattice.
## Good for evenly distributing a fixed number of hex centers with minimal clustering.
static func make_uniform_sphere_points(count: int, radius: float) -> Array[Vector3]:
	if count <= 0:
		return []
	var pts: Array[Vector3] = []
	var golden := (1.0 + sqrt(5.0)) / 2.0
	for i in count:
		var t := float(i) / float(count - 1) if count > 1 else 0.0
		var polar := acos(1.0 - 2.0 * t)          # 0..PI
		var az := 2.0 * PI * fmod(float(i) * golden, 1.0)
		var x := sin(polar) * cos(az)
		var y := cos(polar)
		var z := sin(polar) * sin(az)
		pts.append(Vector3(x, y, z) * radius)
	return pts


func get_hex_radius() -> int:
	return _hex_radius


## Graph neighbors on the hexasphere (5 at pentagons, 6 at hexes).
func get_neighbors(q: int, r: int) -> Array:
	var key: String = "%d,%d" % [q, r]
	var tile: Dictionary = get_tile_at(q, r)
	var nkeys: Array = tile.get("neighbor_keys", _sphere_neighbors.get(key, []))
	var neigh: Array = []
	for nk in nkeys:
		var t: Dictionary = _tile_map.get(str(nk), {})
		if t.is_empty():
			continue
		neigh.append({"q": int(t.get("q", 0)), "r": int(t.get("r", 0)), "tile": t, "key": str(nk)})
	return neigh


## Return list of good starting tiles (RimWorld "select random site" / browse)
## Excludes riftspire and settlement hexes — player cannot spawn there.
func get_starting_candidates(count: int = 5) -> Array:
	var cands = []
	for key in _tile_map.keys():
		var t = _tile_map[key]
		if t.get("is_riftspire", false) or t.get("is_town", false):
			continue
		if t.get("is_start_candidate", false):
			cands.append({"key": key, "tile": t})
	if cands.size() == 0:
		for key in _tile_map.keys():
			var t = _tile_map[key]
			if t.get("is_riftspire", false) or t.get("is_town", false):
				continue
			cands.append({"key": key, "tile": t})
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


## Place the Riftspire capital hex + N NPC towns across the world.
## Called from generate() after the biome pass.
##
## Rules (per docs/PLAN_v040_crafting_progression.md §5):
##   1. One Riftspire hex, placed at a good-start candidate.
##   2. NPC towns: 1 per ~25 hexes (clamped 4-10), even percentage of
##      each faction present in data/factions.json, no two adjacent
##      (axial distance >= 2), >= 2 hexes from Riftspire, on good-start
##      candidate tiles only.
##   3. One of each faction's towns is a "large_hub" (per template pref).
##   4. The remainder are medium_settlements, with a few small_outposts
##      for flavor.
func _place_towns() -> void:
	_towns_seeded = []
	_riftspire_hex_key = ""
	if _tile_map.is_empty():
		return
	# 1. Place Riftspire on a random good-start candidate.
	var candidates: Array = get_starting_candidates(_tile_map.size())
	if candidates.is_empty():
		return
	var rift_idx: int = _rng.randi() % candidates.size()
	var rift_entry: Dictionary = candidates[rift_idx]
	_riftspire_hex_key = str(rift_entry.get("key", ""))
	# Tag the tile with a "riftspire" feature and a special marker.
	var rift_key: String = _riftspire_hex_key
	if _tile_map.has(rift_key):
		var rift_tile: Dictionary = _tile_map[rift_key]
		var feats: Array = rift_tile.get("features", [])
		feats.append("riftspire")
		rift_tile["features"] = feats
		rift_tile["is_riftspire"] = true
		# Override biome to a neutral "Riftspire" so LocalMapGenerator
		# can special-case it. The riftspire_layout.json supplies the
		# terrain / stations / NPCs at load time.
		rift_tile["name"] = "Riftspire"
		_tile_map[rift_key] = rift_tile
	print("[WorldGenerator] Riftspire placed at %s" % _riftspire_hex_key)

	# 2. Place NPC towns.
	if _faction_names.is_empty():
		print("[WorldGenerator] No factions loaded; skipping town placement")
		return
	var total_hexes: int = _tile_map.size()
	var target_town_count: int = clampi(int(round(float(total_hexes) / 25.0)), 4, 10)
	# Build the list of town templates. We want: 1 large_hub per
	# faction (capped at one per faction), rest medium_settlements,
	# some small_outposts.
	var template_assignments: Array = []
	# One large_hub per faction
	var faction_count: int = _faction_names.size()
	var large_hub_count: int = mini(faction_count, target_town_count)
	for i in large_hub_count:
		template_assignments.append("large_hub")
	# Fill the rest with medium_settlements, then a few small_outposts
	for _i in target_town_count - large_hub_count:
		template_assignments.append("medium_settlement")
	# Add 1-2 small_outposts for flavor if there's room
	if target_town_count >= 6 and template_assignments.size() < target_town_count + 2:
		template_assignments.append("small_outpost")
	if target_town_count >= 8 and template_assignments.size() < target_town_count + 2:
		template_assignments.append("small_outpost")
	# Cap at target_town_count
	template_assignments = template_assignments.slice(0, target_town_count)

	# 3. Sort candidates by axial distance from Riftspire (descending
	# so we fill far cells first), and pick valid candidates.
	var valid: Array = []
	for c in candidates:
		var key: String = str(c.get("key", ""))
		if key == _riftspire_hex_key:
			continue
		var parts: PackedStringArray = key.split(",")
		if parts.size() != 2:
			continue
		var dist: int = hex_distance(
			int(parts[0]), int(parts[1]),
			int(_riftspire_hex_key.split(",")[0]),
			int(_riftspire_hex_key.split(",")[1]),
		)
		if dist >= 2:
			valid.append({"key": key, "tile": c.get("tile", {}), "dist": dist})
	# Shuffle within distance tiers (so we don't always pick the
	# most-distant cells), then sort by distance descending.
	valid.shuffle()
	# Group by distance tier, then flatten with distance order
	var tiered: Dictionary = {}
	for v in valid:
		var d: int = int(v.get("dist", 0))
		if not tiered.has(d):
			tiered[d] = []
		tiered[d].append(v)
	var sorted_keys: Array = tiered.keys()
	sorted_keys.sort()
	sorted_keys.reverse()
	var ordered: Array = []
	for d in sorted_keys:
		for v in tiered[d]:
			ordered.append(v)

	# 4. Walk the template_assignments and place each one at the next
	# valid candidate, ensuring no two adjacent.
	var placed_hexes: Array = [_riftspire_hex_key]
	for i in template_assignments.size():
		var tpl_id: String = template_assignments[i]
		var tpl_data: Dictionary = _town_templates.get(tpl_id, {})
		# Pick the first non-adjacent candidate
		var picked: Dictionary = {}
		for v in ordered:
			var key: String = str(v.get("key", ""))
			if key in placed_hexes:
				continue
			# Check distance >= 2 from all placed towns
			var too_close: bool = false
			for ph in placed_hexes:
				var p_parts: PackedStringArray = ph.split(",")
				var v_parts: PackedStringArray = key.split(",")
				if p_parts.size() == 2 and v_parts.size() == 2:
					var d: int = hex_distance(
						int(v_parts[0]), int(v_parts[1]),
						int(p_parts[0]), int(p_parts[1]),
					)
					if d < 2:
						too_close = true
						break
			if too_close:
				continue
			picked = v
			break
		if picked.is_empty():
			continue  # no valid candidate for this slot
		# Even percentage of factions: assign faction in round-robin.
		var faction: String = _faction_names[i % _faction_names.size()]
		# v0.7.0: pull biome from the picked tile so the settlement can
		# spawn biome-appropriate procedural NPCs later.
		var picked_tile: Dictionary = picked.get("tile", {})
		var biome: String = str(picked_tile.get("name", "Ash Wastes"))
		var town: Dictionary = {
			"hex": picked.get("key", ""),
			"faction": faction,
			"template": tpl_id,
			"template_name": str(tpl_data.get("name", tpl_id)),
			"size": str(tpl_data.get("size", "medium")),
			"pop_cap": int(tpl_data.get("pop_cap", 12)),
			"buildings": tpl_data.get("buildings", []),
			"npc_ids": [],  # Phase 5 will populate
			"biome": biome,  # v0.7.0
		}
		_towns_seeded.append(town)
		placed_hexes.append(picked.get("key", ""))
		# Tag the tile with a town feature
		var tkey: String = str(picked.get("key", ""))
		if _tile_map.has(tkey):
			var tile: Dictionary = _tile_map[tkey]
			var tfeats: Array = tile.get("features", [])
			tfeats.append("town")
			tile["features"] = tfeats
			tile["is_town"] = true
			tile["town_faction"] = faction
			tile["town_template"] = tpl_id
			_tile_map[tkey] = tile
	print("[WorldGenerator] Placed %d towns across %d factions" % [
		_towns_seeded.size(), _faction_names.size()
	])


## Public read accessors for town / Riftspire state.
func get_towns_seeded() -> Array:
	return _towns_seeded.duplicate()


func get_riftspire_hex_key() -> String:
	return _riftspire_hex_key


## get_visual_tile / get_tile_visual removed in v0.3.0 — tile rendering is now
## handled by TerrainSystem + LocalMapView (Godot TileMapLayer). WorldGenerator
## only owns sphere-gen + biome classification, not visuals.
