## WorldGenerator -- Procedural hexagonal sphere world (RimWorld-inspired).
## Uses axial hex coordinates (q,r) for sphere-like topology.
## Biomes assigned via simulated latitude (temp), elevation noise, rainfall.
## Player can choose starting tile like RimWorld landing site selection.
class_name WorldGenerator
extends Node

signal world_generated(seed_string: String)

const VERSION := "0.2.0"
const DATA_PATH := "res://data/biomes.json"
const FACTIONS_PATH := "res://data/factions.json"
const TOWNS_PATH := "res://data/towns.json"
var _hex_radius: int = 12  # Size of hex "sphere" patch (axial); set via generate() size param

var _seed: String = ""
var _tile_map: Dictionary = {}  # key "q,r" -> tile dict
var _biome_definitions: Array[Dictionary] = []
var _active_rift_nodes: Array[Dictionary] = []


## Town and Riftspire data populated by _place_towns (called from generate()).
## Stored on world_data so the same world can be reloaded.
var _towns_seeded: Array = []  # [{hex, faction, template, npc_ids}]
var _riftspire_hex_key: String = ""
var _faction_names: Array = []  # cached from data/factions.json
var _town_templates: Dictionary = {}  # cached from data/towns.json


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


## Generate hex sphere world (axial coords q,r). RimWorld-like: lat/temp + elev + noise for biome.
## size: desired hex radius (small=6, medium=12, large=18)
func generate(world_seed: String, difficulty_modifier: float = 1.0, size: int = 12) -> Dictionary:
	_seed = world_seed
	_hex_radius = size
	randseed_from_string(world_seed)

	var tile_map: Dictionary = {}
	var biomes = _biome_definitions

	# Generate hex tiles in a large "sphere" patch using axial coords
	# Track assigned biomes for neighbor clustering bonus
	var assigned_biomes: Dictionary = {}  # key -> biome name
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

			# Count adjacent hexes by biome for clustering bonus
			var neighbor_bonus: Dictionary = {}
			var dirs = [[+1, 0], [+1, -1], [0, -1], [-1, 0], [-1, +1], [0, +1]]
			for d in dirs:
				var nk: String = "%d,%d" % [q + d[0], r + d[1]]
				if assigned_biomes.has(nk):
					var nb: String = assigned_biomes[nk]
					neighbor_bonus[nb] = neighbor_bonus.get(nb, 0.0) + 1.0

			# Pick biome based on temp/rain/elev + neighbor clustering
			var chosen_biome = _pick_biome_by_climate(temp, rain, elevation, biomes, neighbor_bonus)
			var chosen_name: String = chosen_biome.get("name", "")
			assigned_biomes["%d,%d" % [q, r]] = chosen_name

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
	# Phase 3: place NPC towns and the Riftspire capital on the freshly
	# generated hex map. Modifies _tile_map in place (adds a "town" or
	# "riftspire" feature to the relevant tiles) and populates
	# `_towns_seeded` / `_riftspire_hex_key`.
	_place_towns()
	world_generated.emit(world_seed)
	return tile_map


func _pick_biome_by_climate(temp: float, rain: float, elev: float, biomes: Array, neighbor_bonus: Dictionary = {}) -> Dictionary:
	# Climate profile scoring: each biome has ideal ranges, score = proximity to ideal.
	# Profiles: [temp_min, temp_max, rain_min, rain_max, elev_min, elev_max]
	var profiles: Dictionary = {
		"Ash Wastes": [0.5, 0.7, 0.3, 0.5, 0.3, 0.6],
		"Rust Canyons": [0.3, 0.5, 0.2, 0.5, 0.6, 0.9],
		"Neon Bogs": [0.5, 0.7, 0.6, 0.9, 0.0, 0.3],
		"Scorched Plains": [0.7, 1.0, 0.1, 0.4, 0.3, 0.6],
		"Ironwood Thicket": [0.4, 0.6, 0.5, 0.8, 0.3, 0.7],
		"Glass Dunes": [0.6, 0.9, 0.0, 0.3, 0.4, 0.7],
		"Corpse Fields": [0.3, 0.6, 0.3, 0.6, 0.2, 0.5],
		"Stormspire Highlands": [0.1, 0.4, 0.4, 0.7, 0.7, 1.0],
		"Toxin Marshes": [0.4, 0.7, 0.7, 1.0, 0.0, 0.3],
		"Dead City Outskirts": [0.3, 0.6, 0.3, 0.6, 0.4, 0.7],
	}

	var best_score = -999.0
	var best = biomes[0] if biomes.size() > 0 else {"name": "Ash Wastes"}
	for b in biomes:
		var name = b.get("name", "")
		var p: Array = profiles.get(name, [0.0, 1.0, 0.0, 1.0, 0.0, 1.0])

		# How well does this hex's climate fit the biome's ideal range?
		var temp_fit = _range_fit(temp, p[0], p[1])
		var rain_fit = _range_fit(rain, p[2], p[3])
		var elev_fit = _range_fit(elev, p[4], p[5])
		var score = (temp_fit + rain_fit + elev_fit) / 3.0 * 3.0

		# Neighbor clustering bonus: +1.0 per adjacent hex with same biome
		score += neighbor_bonus.get(name, 0.0)

		# Small random jitter to break ties
		score += randf_range(-0.2, 0.2)

		if score > best_score:
			best_score = score
			best = b
	return best.duplicate(true)


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


func get_tile_at(q: int, r: int) -> Dictionary:
	var key = "%d,%d" % [q, r]
	if _tile_map.has(key):
		return _tile_map[key].duplicate(true)
	return {}


static func hex_distance(q1: int, r1: int, q2: int, r2: int) -> int:
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
	var rift_idx: int = randi() % candidates.size()
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


# TODO Methods -- not yet implemented

func add_rift_node(x: int, y: int, is_active: bool = true) -> void:
	_active_rift_nodes.append({"x": x, "y": y, "active": is_active})


## get_visual_tile / get_tile_visual removed in v0.3.0 — tile rendering is now
## handled by TileSetService + LocalMapView (Godot 4.3 TileMapLayer). WorldGenerator
## only owns sphere-gen + biome classification, not visuals.
