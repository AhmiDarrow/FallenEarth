## LocalMapGenerator — Procedural 512x512 local playfield per sphere hex.
##
## Each hex on the world sphere maps to one explorable local region.
## Generates a terrain byte array (0=ground, 1=debris, 2=vegetation, 3=blocked, 4=water)
## plus resource nodes, floor pickups, decor, and town layouts.
##
## v0.13.0: Simplified — removed ground_variant, edge_mask, excessive smoothing passes.
## Terrain rendering is delegated to TerrainSystem.
class_name LocalMapGenerator
extends RefCounted

const MAP_SIZE := 512
const TERRAIN_VERSION := 2
const TERRAIN_GROUND := 0
const TERRAIN_DEBRIS := 1
const TERRAIN_VEGETATION := 2
const TERRAIN_BLOCKED := 3
const TERRAIN_WATER := 4

const EDGE_NORTH := 0
const EDGE_SOUTH := 1
const EDGE_EAST := 2
const EDGE_WEST := 3

const EDGE_TO_HEX_DIR: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(0, 1),
	Vector2i(1, 0),
	Vector2i(-1, 0),
]

const EDGE_ENTRY_POS: Array[Vector2i] = [
	Vector2i(256, MAP_SIZE - 4),
	Vector2i(256, 3),
	Vector2i(3, 256),
	Vector2i(MAP_SIZE - 4, 256),
]


static func hex_key(q: int, r: int) -> String:
	return "%d,%d" % [q, r]


static func local_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


static func make_local_seed(world_seed: String, q: int, r: int) -> String:
	return "%s|%d,%d" % [world_seed, q, r]


static func hash_seed(seed_str: String) -> int:
	return abs(seed_str.hash())


static func _rng(seed_str: String, salt: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash_seed("%s#%d" % [seed_str, salt])
	return rng


## Main entry: generate one 512x512 local map for a hex tile.
static func generate(world_seed: String, q: int, r: int, biome_tile: Dictionary) -> Dictionary:
	var local_seed := make_local_seed(world_seed, q, r)
	var rng := _rng(local_seed)
	var biome_name: String = str(biome_tile.get("name", "Ash Wastes"))

	var terrain := PackedByteArray()
	terrain.resize(MAP_SIZE * MAP_SIZE)

	var occupied := PackedByteArray()
	occupied.resize(MAP_SIZE * MAP_SIZE)

	var elev: float = float(biome_tile.get("elevation", 0.5))
	var rain: float = float(biome_tile.get("rainfall", 0.5))

	var profile: Dictionary = _load_biome_terrain_profile(biome_name)

	# ── Step 1: Height bands (4 levels: valley, lowland, hill, peak) ─────
	var height_band := PackedByteArray()
	height_band.resize(MAP_SIZE * MAP_SIZE)

	var height_noise := FastNoiseLite.new()
	height_noise.seed = hash_seed(local_seed + "height")
	height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	height_noise.frequency = float(profile.get("height_noise_freq", 0.0035))
	height_noise.fractal_octaves = 4
	height_noise.fractal_gain = 0.5

	var elev_bias := elev * 0.12
	var t0 := float(profile.get("height_t0", 0.28))
	var t1 := float(profile.get("height_t1", 0.48))
	var t2 := float(profile.get("height_t2", 0.68))
	for y in MAP_SIZE:
		for x in MAP_SIZE:
			var idx := y * MAP_SIZE + x
			var hn := height_noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			hn = clampf(hn + elev_bias, 0.0, 1.0)
			if hn < t0:
				height_band[idx] = 0
			elif hn < t1:
				height_band[idx] = 1
			elif hn < t2:
				height_band[idx] = 2
			else:
				height_band[idx] = 3

	# ── Step 2: Base fill ─────────────────────────────────────────────────
	var path_noise := FastNoiseLite.new()
	path_noise.seed = hash_seed(local_seed + "paths")
	path_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	path_noise.frequency = float(profile.get("path_noise_freq", 0.009))
	path_noise.fractal_octaves = 2

	var path_threshold: float = float(profile.get("path_threshold", 0.72))
	for y in MAP_SIZE:
		for x in MAP_SIZE:
			var idx := y * MAP_SIZE + x
			terrain[idx] = TERRAIN_GROUND
			var hb := int(height_band[idx])
			if hb == 0:
				var pn0 := absf(path_noise.get_noise_2d(float(x), float(y)))
				if pn0 > path_threshold * 0.85:
					terrain[idx] = TERRAIN_DEBRIS

	# ── Step 3: Rivers ────────────────────────────────────────────────────
	_carve_rivers(terrain, local_seed, elev, height_band)

	# ── Step 4: Lakes ─────────────────────────────────────────────────────
	_carve_lakes(terrain, height_band, local_seed)

	# ── Step 5: Paths (multi-scale gravel ridges) ─────────────────────────
	var path_half: float = float(profile.get("path_half_width", 0.08))
	var wash_threshold: float = float(profile.get("wash_threshold", 0.48))
	for y in MAP_SIZE:
		for x in MAP_SIZE:
			var idx := y * MAP_SIZE + x
			var t := int(terrain[idx])
			if t == TERRAIN_WATER or t == TERRAIN_BLOCKED:
				continue
			var fx := float(x)
			var fy := float(y)
			var pn1 := path_noise.get_noise_2d(fx * 0.45, fy * 0.45)
			var pn2 := path_noise.get_noise_2d(fx * 0.9 + 80.0, fy * 0.9)
			var pn3 := path_noise.get_noise_2d(fx * 0.18 + 20.0, fy * 0.18)
			var on_ridge := absf(pn1) < path_half or absf(pn2) < path_half * 0.7
			var wash := absf(pn3) > wash_threshold and int(height_band[idx]) <= 1
			if on_ridge or wash:
				if t == TERRAIN_GROUND:
					terrain[idx] = TERRAIN_DEBRIS

	# ── Step 6: Rock (peaks + steep south-facing rims) ────────────────────
	var rock_noise := FastNoiseLite.new()
	rock_noise.seed = hash_seed(local_seed + "rock")
	rock_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	rock_noise.frequency = float(profile.get("noise_freq", 0.008))
	rock_noise.fractal_octaves = 2

	var rock_threshold: float = float(profile.get("blocked_base", 0.08)) + elev * float(profile.get("blocked_elev_factor", 0.04))
	for y in MAP_SIZE:
		for x in MAP_SIZE:
			var idx := y * MAP_SIZE + x
			if int(terrain[idx]) == TERRAIN_WATER:
				continue
			var hb := int(height_band[idx])
			var rn := rock_noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			if hb >= 3 and rn > (1.0 - rock_threshold * 2.5):
				terrain[idx] = TERRAIN_BLOCKED
			elif hb >= 2 and y < MAP_SIZE - 1:
				var south_h := int(height_band[idx + MAP_SIZE])
				if hb - south_h >= 2 and rn > 0.45:
					terrain[idx] = TERRAIN_BLOCKED

	# ── Step 7: Smoothing ─────────────────────────────────────────────────
	# Light cleanup: shore edges only (2 passes) — preserves organic shapes.
	_smooth_water_shores(terrain)
	_smooth_water_shores(terrain)

	# Water stays at height band 0 so bank overlays don't appear on lakes.
	for i in MAP_SIZE * MAP_SIZE:
		if int(terrain[i]) == TERRAIN_WATER:
			height_band[i] = 0

	# ── Step 8: Vegetation / forest canopy (Wang veg tiles + tree masks) ───
	_paint_vegetation(terrain, height_band, local_seed, profile, rain)

	# ── Step 9: Center clearing ───────────────────────────────────────────
	var cx := int(MAP_SIZE / 2.0)
	var cy := int(MAP_SIZE / 2.0)
	for dy in range(-24, 25):
		for dx in range(-24, 25):
			var px := cx + dx
			var py := cy + dy
			if px < 0 or py < 0 or px >= MAP_SIZE or py >= MAP_SIZE:
				continue
			terrain[py * MAP_SIZE + px] = TERRAIN_GROUND

	# ── Step 10: Town layout ──────────────────────────────────────────────
	var town_data: Dictionary = _get_town_for_hex(q, r)
	var settlement_data: Dictionary = {"structures": [], "npcs": [], "town_data": town_data, "boundary": null}
	if not town_data.is_empty():
		var structures: Array = _generate_town_layout(rng, town_data, terrain, occupied, Vector2i(cx, cy))
		settlement_data["structures"] = structures
		settlement_data["boundary"] = _compute_town_boundary(structures, Vector2i(cx, cy))

	# ── Step 11: Cooking table ────────────────────────────────────────────
	var cooking_tables: Array = _emit_start_cooking_table(Vector2i(cx, cy))
	for ct in cooking_tables:
		var ct_cell := Vector2i(int(ct.get("x", 0)), int(ct.get("y", 0)))
		if ct_cell.x >= 0 and ct_cell.y >= 0 and ct_cell.x < MAP_SIZE and ct_cell.y < MAP_SIZE:
			occupied[ct_cell.y * MAP_SIZE + ct_cell.x] = 1

	# ── Step 12: Entities (patch/vein/field placement) ─────────────────────
	var biome_tier: int = _load_biome_tier(biome_name)
	var resource_nodes: Array = _emit_resource_nodes(rng, biome_name, biome_tier, terrain, occupied, Vector2i(cx, cy), height_band)
	var floor_pickups: Array = _emit_floor_pickups(rng, biome_name, terrain, occupied, Vector2i(cx, cy))
	var decor: Array = _emit_decor(rng, biome_name, biome_tier, terrain, occupied, Vector2i(cx, cy), height_band)
	var entity_blocked := _build_entity_blocked(resource_nodes, decor)

	return {
		"size": MAP_SIZE,
		"terrain_version": TERRAIN_VERSION,
		"hex_key": hex_key(q, r),
		"q": q,
		"r": r,
		"entity_blocked": entity_blocked,
		"biome": biome_name,
		"local_seed": local_seed,
		"terrain": terrain,
		"height_band": height_band,
		"spawn": Vector2i(cx, cy),
		"visited": false,
		"explored_pct": 0.0,
		"mobs": [],
		"active_rifts": [],
		"settlement": settlement_data,
		"resource_nodes": resource_nodes,
		"floor_pickups": floor_pickups,
		"cooking_tables": cooking_tables,
		"decor": decor,
	}


# ── Terrain query helpers ────────────────────────────────────────────────

static func get_terrain(map_data: Dictionary, x: int, y: int) -> int:
	var size: int = int(map_data.get("size", MAP_SIZE))
	if x < 0 or y < 0 or x >= size or y >= size:
		return TERRAIN_BLOCKED
	var tdata: PackedByteArray = map_data.get("terrain", PackedByteArray())
	if tdata.is_empty():
		return TERRAIN_GROUND
	return int(tdata[y * size + x])


static func is_walkable(map_data: Dictionary, x: int, y: int) -> bool:
	if get_movement_cost(map_data, x, y) < 0:
		return false
	var size: int = int(map_data.get("size", MAP_SIZE))
	if x < 0 or y < 0 or x >= size or y >= size:
		return false
	var eb: PackedByteArray = map_data.get("entity_blocked", PackedByteArray())
	if not eb.is_empty():
		var idx := y * size + x
		if idx < eb.size() and int(eb[idx]) != 0:
			return false
	return true


static func get_movement_cost(map_data: Dictionary, x: int, y: int) -> int:
	return get_terrain_movement_cost(get_terrain(map_data, x, y))


static func get_terrain_movement_cost(terrain_type: int) -> int:
	match terrain_type:
		TERRAIN_GROUND, TERRAIN_VEGETATION:
			return 1
		TERRAIN_DEBRIS:
			return 2
		TERRAIN_BLOCKED, TERRAIN_WATER:
			return -1
		_:
			return 1


static func set_entity_blocked(map_data: Dictionary, x: int, y: int, is_blocked: bool) -> void:
	var size: int = int(map_data.get("size", MAP_SIZE))
	if x < 0 or y < 0 or x >= size or y >= size:
		return
	var eb: PackedByteArray = map_data.get("entity_blocked", PackedByteArray())
	if eb.is_empty():
		eb.resize(size * size)
		map_data["entity_blocked"] = eb
	eb[y * size + x] = 1 if is_blocked else 0


static func get_neighbor_hex(q: int, r: int, edge: int) -> Vector2i:
	if edge < 0 or edge >= EDGE_TO_HEX_DIR.size():
		return Vector2i(q, r)
	var d: Vector2i = EDGE_TO_HEX_DIR[edge]
	return Vector2i(q + d.x, r + d.y)


static func get_entry_position(from_edge: int) -> Vector2i:
	if from_edge < 0 or from_edge >= EDGE_ENTRY_POS.size():
		return Vector2i(int(MAP_SIZE / 2.0), int(MAP_SIZE / 2.0))
	return EDGE_ENTRY_POS[from_edge]


static func edge_from_delta(dx: int, dy: int) -> int:
	if dy < 0:
		return EDGE_NORTH
	if dy > 0:
		return EDGE_SOUTH
	if dx > 0:
		return EDGE_EAST
	if dx < 0:
		return EDGE_WEST
	return -1


static func terrain_label(terrain_type: int) -> String:
	match terrain_type:
		TERRAIN_DEBRIS: return "debris"
		TERRAIN_VEGETATION: return "vegetation"
		TERRAIN_BLOCKED: return "blocked"
		TERRAIN_WATER: return "water"
		_: return "ground"


# ── River generation ─────────────────────────────────────────────────────

static func _carve_rivers(terrain: PackedByteArray, local_seed: String, elev: float, height_band: PackedByteArray = PackedByteArray()) -> void:
	var river_noise := FastNoiseLite.new()
	river_noise.seed = hash_seed(local_seed + "river")
	river_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	river_noise.frequency = 0.018
	river_noise.fractal_octaves = 3
	river_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	river_noise.fractal_gain = 0.45

	var warp_noise := FastNoiseLite.new()
	warp_noise.seed = hash_seed(local_seed + "river_warp")
	warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	warp_noise.frequency = 0.007

	var water_threshold := 0.22 + (1.0 - elev) * 0.12
	var river_cells: Array[Vector2i] = []

	for y in MAP_SIZE:
		for x in MAP_SIZE:
			var idx := y * MAP_SIZE + x
			if int(terrain[idx]) == TERRAIN_BLOCKED:
				continue
			if height_band.size() > idx and int(height_band[idx]) >= 3:
				continue
			var warp_x := float(x) + warp_noise.get_noise_2d(x, y) * 40.0
			var warp_y := float(y) + warp_noise.get_noise_2d(x + 500, y + 500) * 40.0
			var n := river_noise.get_noise_2d(warp_x, warp_y) * 0.5 + 0.5
			var thr := water_threshold
			if height_band.size() > idx:
				var hb := int(height_band[idx])
				if hb == 0:
					thr += 0.08
				elif hb >= 2:
					thr -= 0.06
			if n < thr:
				terrain[idx] = TERRAIN_WATER
				river_cells.append(Vector2i(x, y))

	# Dilate twice for wider channels
	for _pass in 2:
		var to_dilate: Array[Vector2i] = []
		for cell in river_cells:
			for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var nx: int = cell.x + d.x
				var ny: int = cell.y + d.y
				if nx < 0 or ny < 0 or nx >= MAP_SIZE or ny >= MAP_SIZE:
					continue
				var nidx: int = ny * MAP_SIZE + nx
				if int(terrain[nidx]) == TERRAIN_WATER or int(terrain[nidx]) == TERRAIN_BLOCKED:
					continue
				if height_band.size() > nidx and int(height_band[nidx]) >= 3:
					continue
				to_dilate.append(Vector2i(nx, ny))
		for cell in to_dilate:
			terrain[cell.y * MAP_SIZE + cell.x] = TERRAIN_WATER
			river_cells.append(cell)


# ── Lake generation ──────────────────────────────────────────────────────

static func _carve_lakes(terrain: PackedByteArray, height_band: PackedByteArray, local_seed: String) -> void:
	var lake_noise := FastNoiseLite.new()
	lake_noise.seed = hash_seed(local_seed + "lakes")
	lake_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	lake_noise.frequency = 0.012
	lake_noise.fractal_octaves = 2
	for y in MAP_SIZE:
		for x in MAP_SIZE:
			var idx := y * MAP_SIZE + x
			if height_band.size() <= idx or int(height_band[idx]) > 0:
				continue
			if int(terrain[idx]) == TERRAIN_BLOCKED:
				continue
			var ln := lake_noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			if ln < 0.22:
				terrain[idx] = TERRAIN_WATER


# ── Smoothing ────────────────────────────────────────────────────────────

## Soften isolated water cells — keep connected bodies, dissolve stray pixels.
static func _smooth_water_shores(terrain: PackedByteArray) -> void:
	var next := terrain.duplicate()
	for y in range(1, MAP_SIZE - 1):
		for x in range(1, MAP_SIZE - 1):
			var idx := y * MAP_SIZE + x
			var wn := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					if int(terrain[(y + dy) * MAP_SIZE + (x + dx)]) == TERRAIN_WATER:
						wn += 1
			var self_w := int(terrain[idx]) == TERRAIN_WATER
			if self_w and wn <= 2:
				next[idx] = TERRAIN_GROUND
			elif not self_w and wn >= 5:
				next[idx] = TERRAIN_WATER
	for i in terrain.size():
		terrain[i] = next[i]


# ── Resource / entity placement ──────────────────────────────────────────
# Modes: forest_patch | vein | field | pocket | scatter
# Tier gate: entry.min_biome_tier vs biomes.json difficulty_tier

static func _paint_vegetation(terrain: PackedByteArray, height_band: PackedByteArray, local_seed: String, profile: Dictionary, rain: float) -> void:
	var forest_noise := FastNoiseLite.new()
	forest_noise.seed = hash_seed(local_seed + "forest_canopy")
	forest_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	forest_noise.frequency = float(profile.get("forest_noise_freq", 0.006))
	forest_noise.fractal_octaves = 3
	forest_noise.fractal_lacunarity = 2.0
	forest_noise.fractal_gain = 0.5

	var edge_noise := FastNoiseLite.new()
	edge_noise.seed = hash_seed(local_seed + "forest_edge")
	edge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	edge_noise.frequency = float(profile.get("forest_noise_freq", 0.006)) * 2.4
	edge_noise.fractal_octaves = 2

	var veg_base: float = float(profile.get("vegetation_base", 0.22))
	var rain_factor: float = float(profile.get("vegetation_rain_factor", 0.12))
	var forest_threshold: float = float(profile.get("forest_threshold", 0.58))
	var thresh: float = clampf(forest_threshold - rain * rain_factor * 0.35 - veg_base * 0.15, 0.22, 0.78)

	for y in MAP_SIZE:
		for x in MAP_SIZE:
			var idx := y * MAP_SIZE + x
			if int(terrain[idx]) != TERRAIN_GROUND:
				continue
			var hb := int(height_band[idx])
			if hb < 1 or hb > 2:
				continue
			var n: float = forest_noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var e: float = edge_noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			if n * 0.72 + e * 0.28 >= thresh:
				terrain[idx] = TERRAIN_VEGETATION


static func _terrain_ok_for_category(category: String, terrain_type: int) -> bool:
	if terrain_type == TERRAIN_WATER:
		return false
	if terrain_type == TERRAIN_BLOCKED:
		return category == "rocks" or category == "ore" or category == "crystals"
	if category == "trees":
		return terrain_type == TERRAIN_VEGETATION or terrain_type == TERRAIN_GROUND
	if category == "rocks":
		return terrain_type == TERRAIN_GROUND or terrain_type == TERRAIN_DEBRIS or terrain_type == TERRAIN_BLOCKED
	if category == "ore" or category == "crystals":
		return terrain_type == TERRAIN_GROUND or terrain_type == TERRAIN_BLOCKED or terrain_type == TERRAIN_DEBRIS
	if category == "formations":
		return terrain_type == TERRAIN_GROUND or terrain_type == TERRAIN_DEBRIS
	return terrain_type != TERRAIN_WATER


static func _band_ok_for_category(category: String, cell: Vector2i, height_band: PackedByteArray) -> bool:
	if height_band.size() <= 0:
		return true
	var idx := cell.y * MAP_SIZE + cell.x
	if idx < 0 or idx >= height_band.size():
		return true
	var band := int(height_band[idx])
	if category == "trees" or category == "forest":
		return band >= 1 and band <= 2
	if category == "rocks":
		return band >= 2
	if category == "ore" or category == "crystals":
		return band >= 2
	if category == "formations":
		return band >= 1
	if category == "fauna":
		return band <= 2
	return true


static func _decor_band_ok(entry: Dictionary, cell: Vector2i, height_band: PackedByteArray) -> bool:
	if height_band.size() <= 0:
		return true
	var idx := cell.y * MAP_SIZE + cell.x
	if idx < 0 or idx >= height_band.size():
		return true
	var band := int(height_band[idx])
	var sprite: String = str(entry.get("sprite", ""))
	if sprite.find("flower") >= 0 or sprite.find("grass") >= 0 or sprite.find("mushroom") >= 0:
		return band <= 1
	if sprite.find("shrub") >= 0 or sprite.find("bone") >= 0:
		return band <= 2
	if sprite.find("rock") >= 0 or sprite.find("boulder") >= 0:
		return band >= 1
	if sprite.find("crater") >= 0 or sprite.find("wall") >= 0 or sprite.find("ruin") >= 0 or sprite.find("tower") >= 0:
		return band >= 1
	if entry.get("passable", false):
		return true
	return band <= 2


static func _append_node(out: Array, entry: Dictionary, category: String, pos: Vector2i, occupied: PackedByteArray) -> void:
	occupied[pos.y * MAP_SIZE + pos.x] = 1
	var placed: Dictionary = entry.duplicate(true)
	placed["x"] = pos.x
	placed["y"] = pos.y
	placed["category"] = category
	if not placed.has("passable"):
		placed["passable"] = false
	out.append(placed)


static func _spacing_clear(occupied: PackedByteArray, pos: Vector2i, spacing: int) -> bool:
	if spacing <= 0:
		return true
	for dy in range(-spacing, spacing + 1):
		for dx in range(-spacing, spacing + 1):
			if dx == 0 and dy == 0:
				continue
			var px := pos.x + dx
			var py := pos.y + dy
			if px < 0 or py < 0 or px >= MAP_SIZE or py >= MAP_SIZE:
				continue
			if int(occupied[py * MAP_SIZE + px]) != 0:
				return false
	return true


static func _noise_pass(noise_gen: FastNoiseLite, threshold: float, x: int, y: int) -> bool:
	if noise_gen == null:
		return true
	return noise_gen.get_noise_2d(float(x), float(y)) * 0.5 + 0.5 >= threshold


static func _emit_resource_nodes(rng: RandomNumberGenerator, biome_name: String, biome_tier: int, terrain: PackedByteArray, occupied: PackedByteArray, spawn: Vector2i, height_band: PackedByteArray = PackedByteArray()) -> Array:
	var biome_data: Dictionary = _load_biome_resource_nodes(biome_name)
	if biome_data.is_empty():
		return []

	var placement_noise: Dictionary = biome_data.get("placement_noise", {})
	var category_defaults: Dictionary = biome_data.get("category_defaults", {})
	var noise_cache: Dictionary = {}
	var out: Array = []

	var categories := ["crystals", "ore", "rocks", "formations", "trees", "fauna"]
	for category in categories:
		var entries: Array = biome_data.get(category, [])
		var cat_def: Dictionary = category_defaults.get(category, {})
		for entry in entries:
			if entry == null or not (entry is Dictionary):
				continue
			var min_tier: int = int(entry.get("min_biome_tier", cat_def.get("min_biome_tier", 0)))
			if biome_tier < min_tier:
				continue
			var density: float = float(entry.get("density", 0.0))
			if density <= 0.0:
				continue
			var mode: String = str(entry.get("placement_mode", cat_def.get("placement_mode", "scatter")))
			var noise_channel: String = str(entry.get("noise_channel", cat_def.get("noise_channel", "")))
			var min_spacing: int = int(entry.get("min_spacing", cat_def.get("min_spacing", 0)))

			var noise_gen: FastNoiseLite = null
			var noise_threshold: float = 0.0
			if not noise_channel.is_empty() and placement_noise.has(noise_channel):
				if not noise_cache.has(noise_channel):
					var nc: Dictionary = placement_noise[noise_channel]
					var n := FastNoiseLite.new()
					n.seed = hash_seed("%s#%s" % [biome_name, noise_channel])
					n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
					n.frequency = float(nc.get("frequency", 0.01))
					n.fractal_octaves = 3
					noise_cache[noise_channel] = n
				noise_gen = noise_cache[noise_channel] as FastNoiseLite
				noise_threshold = float(placement_noise[noise_channel].get("threshold", 0.5))

			match mode:
				"forest_patch":
					_place_forest_patch(out, entry as Dictionary, category, density, rng, terrain, occupied, spawn, height_band, noise_gen, noise_threshold, min_spacing, cat_def)
				"vein":
					_place_vein(out, entry as Dictionary, category, density, rng, terrain, occupied, spawn, height_band, noise_gen, noise_threshold, min_spacing, cat_def)
				"field":
					_place_field(out, entry as Dictionary, category, density, rng, terrain, occupied, spawn, height_band, noise_gen, noise_threshold, min_spacing, cat_def)
				"pocket":
					_place_pocket(out, entry as Dictionary, category, density, rng, terrain, occupied, spawn, height_band, noise_gen, noise_threshold, min_spacing, cat_def)
				_:
					_place_scatter(out, entry as Dictionary, category, density, rng, terrain, occupied, spawn, height_band, noise_gen, noise_threshold, min_spacing, cat_def)
	return out


static func _place_forest_patch(out: Array, entry: Dictionary, category: String, density: float, rng: RandomNumberGenerator, terrain: PackedByteArray, occupied: PackedByteArray, spawn: Vector2i, height_band: PackedByteArray, noise_gen: FastNoiseLite, noise_threshold: float, min_spacing: int, cat_def: Dictionary) -> void:
	var target: int = int(round(MAP_SIZE * MAP_SIZE * density))
	if target <= 0:
		return
	var patch_count: int = int(entry.get("patch_count", cat_def.get("patch_count", 0)))
	if patch_count <= 0:
		patch_count = clampi(int(round(float(target) / 140.0)), 2, 14)
	var radius_min: int = int(entry.get("patch_radius_min", cat_def.get("patch_radius_min", 14)))
	var radius_max: int = int(entry.get("patch_radius_max", cat_def.get("patch_radius_max", 36)))
	var core_fill: float = float(entry.get("core_fill", cat_def.get("core_fill", 0.38)))
	var edge_fill: float = float(entry.get("edge_fill", cat_def.get("edge_fill", 0.12)))
	var outlier_density: float = float(entry.get("outlier_density", cat_def.get("outlier_density", density * 0.04)))
	var spacing: int = maxi(min_spacing, int(entry.get("min_spacing", cat_def.get("min_spacing", 1))))

	var placed := 0
	var seed_attempts := 0
	var patches_done := 0
	while patches_done < patch_count and placed < target and seed_attempts < patch_count * 100:
		seed_attempts += 1
		var center: Vector2i = _peek_category_cell(rng, terrain, occupied, spawn, category, height_band)
		if center.x < 0:
			break
		if not _noise_pass(noise_gen, noise_threshold, center.x, center.y):
			continue
		# Prefer canopy seeds.
		var ct := int(terrain[center.y * MAP_SIZE + center.x])
		if ct != TERRAIN_VEGETATION and rng.randf() > 0.35:
			continue
		var radius: int = rng.randi_range(radius_min, radius_max)
		var r2: float = float(radius * radius)
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if placed >= target:
					break
				var dist2: float = float(dx * dx + dy * dy)
				if dist2 > r2:
					continue
				var pos := Vector2i(center.x + dx, center.y + dy)
				if pos.x < 0 or pos.y < 0 or pos.x >= MAP_SIZE or pos.y >= MAP_SIZE:
					continue
				if maxi(abs(pos.x - spawn.x), abs(pos.y - spawn.y)) < 8:
					continue
				var idx := pos.y * MAP_SIZE + pos.x
				if int(occupied[idx]) != 0:
					continue
				var tt := int(terrain[idx])
				if not _terrain_ok_for_category(category, tt):
					continue
				if height_band.size() > 0 and not _band_ok_for_category(category, pos, height_band):
					continue
				if tt == TERRAIN_DEBRIS:
					continue
				var tnorm: float = sqrt(dist2) / float(maxi(radius, 1))
				var fill_p: float = lerpf(core_fill, edge_fill, clampf(tnorm, 0.0, 1.0))
				if tt == TERRAIN_VEGETATION:
					fill_p = minf(fill_p * 1.35, 0.92)
				else:
					fill_p *= 0.5
				if rng.randf() > fill_p:
					continue
				if not _spacing_clear(occupied, pos, spacing):
					continue
				_append_node(out, entry, category, pos, occupied)
				placed += 1
		patches_done += 1

	var outliers: int = int(round(MAP_SIZE * MAP_SIZE * outlier_density))
	var o_attempts := 0
	while outliers > 0 and placed < target and o_attempts < outliers * 16:
		o_attempts += 1
		var pos2: Vector2i = _peek_category_cell(rng, terrain, occupied, spawn, category, height_band)
		if pos2.x < 0:
			break
		if not _spacing_clear(occupied, pos2, spacing):
			continue
		_append_node(out, entry, category, pos2, occupied)
		placed += 1
		outliers -= 1


static func _place_vein(out: Array, entry: Dictionary, category: String, density: float, rng: RandomNumberGenerator, terrain: PackedByteArray, occupied: PackedByteArray, spawn: Vector2i, height_band: PackedByteArray, noise_gen: FastNoiseLite, noise_threshold: float, min_spacing: int, cat_def: Dictionary) -> void:
	var target: int = int(round(MAP_SIZE * MAP_SIZE * density))
	if target <= 0:
		return
	var per_vein: int = clampi(int(entry.get("vein_length", cat_def.get("vein_length", 8))), 3, 20)
	var vein_count: int = int(entry.get("vein_count", cat_def.get("vein_count", 0)))
	if vein_count <= 0:
		vein_count = clampi(int(ceili(float(target) / float(per_vein))), 1, 48)
	var spacing: int = maxi(min_spacing, int(entry.get("min_spacing", cat_def.get("min_spacing", 2))))

	var placed := 0
	var attempts := 0
	while placed < target and attempts < vein_count * 50:
		attempts += 1
		var center: Vector2i = _peek_category_cell(rng, terrain, occupied, spawn, category, height_band)
		if center.x < 0:
			break
		if not _noise_pass(noise_gen, noise_threshold, center.x, center.y):
			continue
		var angle: float = rng.randf() * TAU
		var dx: float = cos(angle)
		var dy: float = sin(angle)
		var pxf: float = float(center.x)
		var pyf: float = float(center.y)
		var vein_len: int = rng.randi_range(maxi(3, per_vein - 3), per_vein + 4)
		for _step in vein_len:
			if placed >= target:
				break
			var pos := Vector2i(int(round(pxf)) + rng.randi_range(-1, 1), int(round(pyf)) + rng.randi_range(-1, 1))
			if pos.x >= 0 and pos.y >= 0 and pos.x < MAP_SIZE and pos.y < MAP_SIZE:
				if maxi(abs(pos.x - spawn.x), abs(pos.y - spawn.y)) >= 8:
					var idx := pos.y * MAP_SIZE + pos.x
					if int(occupied[idx]) == 0 and _terrain_ok_for_category(category, int(terrain[idx])):
						if height_band.size() <= 0 or _band_ok_for_category(category, pos, height_band):
							if _spacing_clear(occupied, pos, spacing):
								_append_node(out, entry, category, pos, occupied)
								placed += 1
			pxf += dx + rng.randf_range(-0.25, 0.25)
			pyf += dy + rng.randf_range(-0.25, 0.25)


static func _place_field(out: Array, entry: Dictionary, category: String, density: float, rng: RandomNumberGenerator, terrain: PackedByteArray, occupied: PackedByteArray, spawn: Vector2i, height_band: PackedByteArray, noise_gen: FastNoiseLite, noise_threshold: float, min_spacing: int, cat_def: Dictionary) -> void:
	var target: int = int(round(MAP_SIZE * MAP_SIZE * density))
	if target <= 0:
		return
	var cluster_radius: int = int(entry.get("cluster_radius", cat_def.get("cluster_radius", 6)))
	var cluster_count: int = maxi(1, int(entry.get("cluster_count", cat_def.get("cluster_count", 8))))
	var field_count: int = clampi(int(ceili(float(target) / float(cluster_count))), 2, 60)
	var spacing: int = maxi(min_spacing, int(entry.get("min_spacing", cat_def.get("min_spacing", 1))))

	var placed := 0
	var attempts := 0
	while placed < target and attempts < field_count * 50:
		attempts += 1
		var center: Vector2i = _peek_category_cell(rng, terrain, occupied, spawn, category, height_band)
		if center.x < 0:
			break
		if not _noise_pass(noise_gen, noise_threshold, center.x, center.y):
			continue
		for _c in cluster_count:
			if placed >= target:
				break
			var pos := Vector2i(center.x + rng.randi_range(-cluster_radius, cluster_radius), center.y + rng.randi_range(-cluster_radius, cluster_radius))
			if pos.x < 0 or pos.y < 0 or pos.x >= MAP_SIZE or pos.y >= MAP_SIZE:
				continue
			if maxi(abs(pos.x - spawn.x), abs(pos.y - spawn.y)) < 8:
				continue
			var idx := pos.y * MAP_SIZE + pos.x
			if int(occupied[idx]) != 0:
				continue
			if not _terrain_ok_for_category(category, int(terrain[idx])):
				continue
			if height_band.size() > 0 and not _band_ok_for_category(category, pos, height_band):
				continue
			if not _spacing_clear(occupied, pos, spacing):
				continue
			_append_node(out, entry, category, pos, occupied)
			placed += 1


static func _place_pocket(out: Array, entry: Dictionary, category: String, density: float, rng: RandomNumberGenerator, terrain: PackedByteArray, occupied: PackedByteArray, spawn: Vector2i, height_band: PackedByteArray, noise_gen: FastNoiseLite, noise_threshold: float, min_spacing: int, cat_def: Dictionary) -> void:
	var target: int = int(round(MAP_SIZE * MAP_SIZE * density))
	if target <= 0:
		return
	var pocket_size: int = clampi(int(entry.get("pocket_size", cat_def.get("pocket_size", 4))), 2, 10)
	var pocket_count: int = clampi(int(ceili(float(target) / float(pocket_size))), 1, 24)
	var spacing: int = maxi(min_spacing, int(entry.get("min_spacing", cat_def.get("min_spacing", 1))))

	var placed := 0
	var attempts := 0
	while placed < target and attempts < pocket_count * 60:
		attempts += 1
		var center: Vector2i = _peek_category_cell(rng, terrain, occupied, spawn, category, height_band)
		if center.x < 0:
			break
		if not _noise_pass(noise_gen, noise_threshold, center.x, center.y):
			continue
		var rad: int = rng.randi_range(2, 4)
		for _c in pocket_size:
			if placed >= target:
				break
			var pos := Vector2i(center.x + rng.randi_range(-rad, rad), center.y + rng.randi_range(-rad, rad))
			if pos.x < 0 or pos.y < 0 or pos.x >= MAP_SIZE or pos.y >= MAP_SIZE:
				continue
			if maxi(abs(pos.x - spawn.x), abs(pos.y - spawn.y)) < 8:
				continue
			var idx := pos.y * MAP_SIZE + pos.x
			if int(occupied[idx]) != 0:
				continue
			if not _terrain_ok_for_category(category, int(terrain[idx])):
				continue
			if height_band.size() > 0 and not _band_ok_for_category(category, pos, height_band):
				continue
			if not _spacing_clear(occupied, pos, spacing):
				continue
			_append_node(out, entry, category, pos, occupied)
			placed += 1


static func _place_scatter(out: Array, entry: Dictionary, category: String, density: float, rng: RandomNumberGenerator, terrain: PackedByteArray, occupied: PackedByteArray, spawn: Vector2i, height_band: PackedByteArray, noise_gen: FastNoiseLite, noise_threshold: float, min_spacing: int, cat_def: Dictionary) -> void:
	var count: int = int(round(MAP_SIZE * MAP_SIZE * density))
	if count <= 0:
		return
	var cluster_radius: int = int(entry.get("cluster_radius", cat_def.get("cluster_radius", 0)))
	var cluster_count: int = maxi(1, int(entry.get("cluster_count", cat_def.get("cluster_count", 1))))
	var spacing: int = min_spacing
	var placed_total := 0
	var attempts := 0
	var max_attempts: int = count * 12
	while placed_total < count and attempts < max_attempts:
		attempts += 1
		var center: Vector2i = _peek_category_cell(rng, terrain, occupied, spawn, category, height_band)
		if center.x < 0:
			break
		if not _noise_pass(noise_gen, noise_threshold, center.x, center.y):
			continue
		if not _spacing_clear(occupied, center, spacing):
			continue
		_append_node(out, entry, category, center, occupied)
		placed_total += 1
		if cluster_radius > 0 and cluster_count > 1:
			for _c in range(cluster_count - 1):
				if placed_total >= count:
					break
				var pos := Vector2i(center.x + rng.randi_range(-cluster_radius, cluster_radius), center.y + rng.randi_range(-cluster_radius, cluster_radius))
				if pos.x < 0 or pos.y < 0 or pos.x >= MAP_SIZE or pos.y >= MAP_SIZE:
					continue
				if maxi(abs(pos.x - spawn.x), abs(pos.y - spawn.y)) < 8:
					continue
				var idx := pos.y * MAP_SIZE + pos.x
				if int(occupied[idx]) != 0:
					continue
				if not _terrain_ok_for_category(category, int(terrain[idx])):
					continue
				if height_band.size() > 0 and not _band_ok_for_category(category, pos, height_band):
					continue
				if not _spacing_clear(occupied, pos, spacing):
					continue
				_append_node(out, entry, category, pos, occupied)
				placed_total += 1


static func _build_entity_blocked(resource_nodes: Array, decor: Array) -> PackedByteArray:
	var blocked := PackedByteArray()
	blocked.resize(MAP_SIZE * MAP_SIZE)
	for entry in resource_nodes:
		if entry == null or not (entry is Dictionary): continue
		if bool((entry as Dictionary).get("passable", false)): continue
		var x: int = int((entry as Dictionary).get("x", -1))
		var y: int = int((entry as Dictionary).get("y", -1))
		if x < 0 or y < 0 or x >= MAP_SIZE or y >= MAP_SIZE: continue
		blocked[y * MAP_SIZE + x] = 1
	for entry in decor:
		if entry == null or not (entry is Dictionary): continue
		if bool((entry as Dictionary).get("passable", false)): continue
		var x: int = int((entry as Dictionary).get("x", -1))
		var y: int = int((entry as Dictionary).get("y", -1))
		if x < 0 or y < 0 or x >= MAP_SIZE or y >= MAP_SIZE: continue
		blocked[y * MAP_SIZE + x] = 1
	return blocked


static func _emit_floor_pickups(rng: RandomNumberGenerator, biome_name: String, terrain: PackedByteArray, occupied: PackedByteArray, spawn: Vector2i) -> Array:
	var densities: Dictionary = _load_floor_pickup_densities()
	if densities.is_empty():
		return []
	var out: Array = []
	for pickup_id in ["stick", "stone"]:
		var density: float = float(densities.get(pickup_id, 0.0))
		if density <= 0.0: continue
		var count: int = int(round(MAP_SIZE * MAP_SIZE * density))
		for _i in count:
			var pos: Vector2i = _pick_walkable_cell(rng, terrain, occupied, spawn, 8)
			if pos.x < 0: break
			occupied[pos.y * MAP_SIZE + pos.x] = 1
			out.append({"id": pickup_id, "x": pos.x, "y": pos.y, "qty": 1})
	return out


static func _emit_decor(rng: RandomNumberGenerator, biome_name: String, biome_tier: int, terrain: PackedByteArray, occupied: PackedByteArray, spawn: Vector2i, height_band: PackedByteArray = PackedByteArray()) -> Array:
	var decor_data: Dictionary = _load_biome_decor(biome_name)
	if decor_data.is_empty():
		return []
	var profile: Dictionary = _load_biome_decor_profile(biome_name)
	var out: Array = []

	var large_mult: float = float(profile.get("large_density_mult", 1.0))
	var small_mult: float = float(profile.get("small_density_mult", 1.0))

	var meadow_noise := FastNoiseLite.new()
	meadow_noise.seed = hash_seed("%s#decor_meadow" % biome_name)
	meadow_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	meadow_noise.frequency = float(profile.get("small_cluster_noise_freq", 0.018))
	meadow_noise.fractal_octaves = 3
	var meadow_threshold: float = float(profile.get("meadow_threshold", profile.get("small_cluster_threshold", 0.42)))

	var ruin_noise := FastNoiseLite.new()
	ruin_noise.seed = hash_seed("%s#decor_ruin" % biome_name)
	ruin_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruin_noise.frequency = float(profile.get("cluster_noise_freq", 0.014))
	ruin_noise.fractal_octaves = 2
	var ruin_threshold: float = float(profile.get("cluster_threshold", 0.62))

	var understory_noise := FastNoiseLite.new()
	understory_noise.seed = hash_seed("%s#decor_under" % biome_name)
	understory_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	understory_noise.frequency = 0.04
	understory_noise.fractal_octaves = 2

	for size_key in ["large", "small"]:
		var dens_mult: float = large_mult if size_key == "large" else small_mult
		var cat_name: String = "decor_large" if size_key == "large" else "decor_small"
		for entry in decor_data.get(size_key, []):
			if entry == null or not (entry is Dictionary):
				continue
			if biome_tier < int(entry.get("min_biome_tier", 0)):
				continue
			var density: float = float(entry.get("density", 0.0)) * dens_mult
			if density <= 0.0:
				continue
			var sprite: String = str(entry.get("sprite", ""))
			var passable: bool = bool(entry.get("passable", false))
			var mode: String = str(entry.get("placement_mode", ""))
			if mode.is_empty():
				if size_key == "large":
					mode = "ruin"
				elif passable and (sprite.find("flower") >= 0 or sprite.find("mushroom") >= 0 or sprite.find("grass") >= 0 or sprite.find("bone") >= 0):
					mode = "meadow"
				elif sprite.find("shrub") >= 0:
					mode = "understory"
				else:
					mode = "scatter"
			var count: int = int(round(MAP_SIZE * MAP_SIZE * density))
			var placed_total := 0
			var attempts := 0
			while placed_total < count and attempts < count * 12:
				attempts += 1
				var pos: Vector2i = _peek_walkable_cell(rng, terrain, occupied, spawn)
				if pos.x < 0:
					break
				var tt := int(terrain[pos.y * MAP_SIZE + pos.x])
				match mode:
					"meadow":
						if tt == TERRAIN_VEGETATION:
							continue
						if tt != TERRAIN_GROUND and tt != TERRAIN_DEBRIS:
							continue
						if meadow_noise.get_noise_2d(float(pos.x), float(pos.y)) * 0.5 + 0.5 < meadow_threshold:
							continue
					"understory":
						if tt != TERRAIN_VEGETATION:
							continue
						if understory_noise.get_noise_2d(float(pos.x), float(pos.y)) * 0.5 + 0.5 < 0.4:
							continue
					"ruin":
						if ruin_noise.get_noise_2d(float(pos.x), float(pos.y)) * 0.5 + 0.5 < ruin_threshold:
							continue
					_:
						if meadow_noise.get_noise_2d(float(pos.x) * 1.3, float(pos.y) * 1.3) * 0.5 + 0.5 < meadow_threshold * 0.85:
							continue
				if height_band.size() > 0 and not _decor_band_ok(entry, pos, height_band):
					continue
				occupied[pos.y * MAP_SIZE + pos.x] = 1
				var placed: Dictionary = (entry as Dictionary).duplicate(true)
				placed["x"] = pos.x
				placed["y"] = pos.y
				placed["category"] = cat_name
				out.append(placed)
				placed_total += 1
	return out


static func _pick_walkable_cell(rng: RandomNumberGenerator, terrain: PackedByteArray, occupied: PackedByteArray, spawn: Vector2i, spawn_buffer: int = 6) -> Vector2i:
	for _i in 48:
		var x: int = rng.randi_range(0, MAP_SIZE - 1)
		var y: int = rng.randi_range(0, MAP_SIZE - 1)
		if maxi(abs(x - spawn.x), abs(y - spawn.y)) < spawn_buffer: continue
		var idx := y * MAP_SIZE + x
		var t := int(terrain[idx])
		if t == TERRAIN_BLOCKED or t == TERRAIN_WATER: continue
		if int(occupied[idx]) != 0: continue
		occupied[idx] = 1
		return Vector2i(x, y)
	return Vector2i(-1, -1)


static func _peek_walkable_cell(rng: RandomNumberGenerator, terrain: PackedByteArray, occupied: PackedByteArray, spawn: Vector2i, spawn_buffer: int = 6) -> Vector2i:
	for _i in 64:
		var x: int = rng.randi_range(0, MAP_SIZE - 1)
		var y: int = rng.randi_range(0, MAP_SIZE - 1)
		if maxi(abs(x - spawn.x), abs(y - spawn.y)) < spawn_buffer: continue
		var idx := y * MAP_SIZE + x
		var t := int(terrain[idx])
		if t == TERRAIN_BLOCKED or t == TERRAIN_WATER: continue
		if int(occupied[idx]) != 0: continue
		return Vector2i(x, y)
	return Vector2i(-1, -1)


static func _peek_category_cell(rng: RandomNumberGenerator, terrain: PackedByteArray, occupied: PackedByteArray, spawn: Vector2i, category: String, height_band: PackedByteArray = PackedByteArray(), spawn_buffer: int = 8) -> Vector2i:
	for _i in 96:
		var x: int = rng.randi_range(0, MAP_SIZE - 1)
		var y: int = rng.randi_range(0, MAP_SIZE - 1)
		if maxi(abs(x - spawn.x), abs(y - spawn.y)) < spawn_buffer: continue
		var idx := y * MAP_SIZE + x
		var t := int(terrain[idx])
		if not _terrain_ok_for_category(category, t): continue
		if int(occupied[idx]) != 0: continue
		if height_band.size() > 0 and not _band_ok_for_category(category, Vector2i(x, y), height_band): continue
		return Vector2i(x, y)
	return _peek_walkable_cell(rng, terrain, occupied, spawn, spawn_buffer)


static func _emit_start_cooking_table(spawn: Vector2i) -> Array:
	var table_pos := Vector2i(spawn.x + 8, spawn.y + 8)
	if table_pos.x < 0: table_pos.x = 0
	if table_pos.y < 0: table_pos.y = 0
	if table_pos.x >= MAP_SIZE: table_pos.x = MAP_SIZE - 1
	if table_pos.y >= MAP_SIZE: table_pos.y = MAP_SIZE - 1
	return [{"x": table_pos.x, "y": table_pos.y, "station_id": "cooking_table"}]


# ── Town layout generation ───────────────────────────────────────────────

static var _towns_cache: Dictionary = {}
static var _towns_cache_mtime: int = -1
static var _town_hex_cache: Dictionary = {}
static var _town_hex_loaded: bool = false


static func _load_towns_config() -> Dictionary:
	var path := "res://data/towns.json"
	if not ResourceLoader.exists(path): return {}
	var ftime := FileAccess.get_modified_time(path)
	if _towns_cache_mtime != ftime:
		var raw = load(path)
		if raw != null:
			var data: Dictionary = {}
			if raw is Dictionary: data = raw
			elif "data" in raw:
				var d = raw.data
				if d is Dictionary: data = d
			if not data.is_empty():
				_towns_cache = data; _towns_cache_mtime = ftime
	return _towns_cache


static func _get_town_for_hex(q: int, r: int) -> Dictionary:
	if not _town_hex_loaded:
		_rebuild_town_hex_cache()
	return _town_hex_cache.get(hex_key(q, r), {})


static func _rebuild_town_hex_cache() -> void:
	_town_hex_cache.clear()
	var gs: Node = Engine.get_singleton("GameState") if Engine.has_singleton("GameState") else null
	if gs == null:
		gs = Node.new(); gs.queue_free(); _town_hex_loaded = true; return
	if not gs.has_method("get_world_data"):
		_town_hex_loaded = true; return
	for t in gs.call("get_world_data").get("towns_seeded", []):
		if t is Dictionary:
			var hk: String = str(t.get("hex", ""))
			if not hk.is_empty(): _town_hex_cache[hk] = t
	_town_hex_loaded = true


static func _generate_town_layout(rng: RandomNumberGenerator, town_data: Dictionary, terrain: PackedByteArray, occupied: PackedByteArray, spawn: Vector2i) -> Array:
	var config: Dictionary = _load_towns_config()
	var building_types: Dictionary = config.get("building_types", {})
	var buildings: Array = town_data.get("buildings", [])
	if buildings.is_empty() or building_types.is_empty(): return []

	var structures: Array = []
	var cx: int = spawn.x; var cy: int = spawn.y
	var clearing_radius: int = 15

	for dy in range(-clearing_radius - 2, clearing_radius + 3):
		for dx in range(-clearing_radius - 2, clearing_radius + 3):
			var px: int = cx + dx; var py: int = cy + dy
			if px < 0 or py < 0 or px >= MAP_SIZE or py >= MAP_SIZE: continue
			if dx * dx + dy * dy <= (clearing_radius + 1) * (clearing_radius + 1):
				terrain[py * MAP_SIZE + px] = TERRAIN_GROUND

	var n_buildings: int = buildings.size()
	var angle_step: float = TAU / float(n_buildings)
	var place_radius: float = float(clearing_radius + 4)

	for i in n_buildings:
		var bld_name: String = str(buildings[i])
		var bld_info: Dictionary = building_types.get(bld_name, {})
		if bld_info.is_empty(): continue
		var bw: int = int(bld_info.get("w", 2))
		var bh: int = int(bld_info.get("h", 2))
		var role: String = str(bld_info.get("role", "vendor"))
		var sprite: String = str(bld_info.get("sprite", bld_name))
		var label: String = str(bld_info.get("label", bld_name))

		var angle: float = angle_step * float(i) - PI / 2.0
		var bx_center: int = cx + int(cos(angle) * place_radius)
		var by_center: int = cy + int(sin(angle) * place_radius)
		var bx: int = bx_center - int(bw / 2.0)
		var by: int = by_center - int(bh / 2.0)
		bx = clampi(bx, 2, MAP_SIZE - bw - 2)
		by = clampi(by, 2, MAP_SIZE - bh - 2)

		var entrance_x: int = bx + int(bw / 2.0)
		var entrance_y: int = by + bh

		for dy2 in bh:
			for dx2 in bw:
				var px: int = bx + dx2; var py: int = by + dy2
				if px < 0 or py < 0 or px >= MAP_SIZE or py >= MAP_SIZE: continue
				terrain[py * MAP_SIZE + px] = TERRAIN_BLOCKED
				occupied[py * MAP_SIZE + px] = 1

		var path_dx: int = 0; var path_dy: int = 0
		if entrance_y < cy: path_dy = 1
		elif entrance_y > cy: path_dy = -1
		if entrance_x < cx: path_dx = 1
		elif entrance_x > cx: path_dx = -1
		var px: int = entrance_x; var py: int = entrance_y
		for _step in clearing_radius + bw:
			if px < 0 or py < 0 or px >= MAP_SIZE or py >= MAP_SIZE: break
			var idx: int = py * MAP_SIZE + px
			if terrain[idx] == TERRAIN_BLOCKED: break
			if terrain[idx] != TERRAIN_VEGETATION: terrain[idx] = TERRAIN_DEBRIS
			var dist_to_center: int = (px - cx) * (px - cx) + (py - cy) * (py - cy)
			if dist_to_center <= clearing_radius * clearing_radius: break
			if abs(entrance_x - cx) >= abs(entrance_y - cy): px += path_dx
			else: py += path_dy

		structures.append({
			"id": bld_name, "role": role, "sprite": sprite, "label": label,
			"x": bx, "y": by, "w": bw, "h": bh,
			"entrance_x": entrance_x, "entrance_y": entrance_y,
		})

	return structures


static func _compute_town_boundary(structures: Array, center: Vector2i) -> Rect2i:
	var clearing_radius: int = 15
	var min_x: int = center.x - clearing_radius
	var min_y: int = center.y - clearing_radius
	var max_x: int = center.x + clearing_radius
	var max_y: int = center.y + clearing_radius
	for s in structures:
		if not (s is Dictionary): continue
		var sx: int = int(s.get("x", 0)); var sy: int = int(s.get("y", 0))
		min_x = mini(min_x, sx); min_y = mini(min_y, sy)
		max_x = maxi(max_x, sx + int(s.get("w", 2)))
		max_y = maxi(max_y, sy + int(s.get("h", 2)))
	return Rect2i(clampi(min_x, 0, MAP_SIZE - 1), clampi(min_y, 0, MAP_SIZE - 1),
		clampi(max_x, 0, MAP_SIZE - 1) - min_x, clampi(max_y, 0, MAP_SIZE - 1) - min_y)


# ── Cached JSON loaders ─────────────────────────────────────────────────

static var _rn_cache: Dictionary = {}; static var _rn_cache_mtime: int = -1
static var _fp_cache: Dictionary = {}; static var _fp_cache_mtime: int = -1
static var _tp_cache: Dictionary = {}; static var _tp_cache_mtime: int = -1
static var _decor_cache: Dictionary = {}; static var _decor_cache_mtime: int = -1
static var _dp_cache: Dictionary = {}; static var _dp_cache_mtime: int = -1
static var _tier_cache: Dictionary = {}; static var _tier_cache_mtime: int = -1


static func _load_biome_tier(biome_name: String) -> int:
	var path := "res://data/biomes.json"
	if not ResourceLoader.exists(path):
		return 1
	var ftime := FileAccess.get_modified_time(path)
	if _tier_cache_mtime != ftime:
		var raw = load(path)
		if raw != null:
			var data: Array = []
			if raw is Array:
				data = raw
			elif "data" in raw:
				var d = raw.data
				if d is Array:
					data = d
			_tier_cache.clear()
			for entry in data:
				if entry is Dictionary:
					var nm: String = str(entry.get("name", ""))
					if not nm.is_empty():
						_tier_cache[nm] = int(entry.get("difficulty_tier", 1))
			_tier_cache_mtime = ftime
	return int(_tier_cache.get(biome_name, 1))


static func _load_biome_resource_nodes(biome_name: String) -> Dictionary:
	var path := "res://data/resource_nodes.json"
	if not ResourceLoader.exists(path): return {}
	var ftime := FileAccess.get_modified_time(path)
	if _rn_cache_mtime != ftime:
		var raw = load(path)
		if raw != null:
			var data: Dictionary = {}
			if raw is Dictionary: data = raw
			elif "data" in raw:
				var d = raw.data
				if d is Dictionary: data = d
			if not data.is_empty():
				_rn_cache = data.get("biomes", {}); _rn_cache_mtime = ftime
	return _rn_cache.get(biome_name, {})


static func _load_floor_pickup_densities() -> Dictionary:
	var path := "res://data/resource_nodes.json"
	if not ResourceLoader.exists(path): return {}
	var ftime := FileAccess.get_modified_time(path)
	if _fp_cache_mtime != ftime:
		var raw = load(path)
		if raw != null:
			var data: Dictionary = {}
			if raw is Dictionary: data = raw
			elif "data" in raw:
				var d = raw.data
				if d is Dictionary: data = d
			if not data.is_empty():
				_fp_cache = data.get("floor_pickup_density", {}); _fp_cache_mtime = ftime
	return _fp_cache


static func _load_biome_terrain_profile(biome_name: String) -> Dictionary:
	var path := "res://data/biomes.json"
	if not ResourceLoader.exists(path): return {}
	var ftime := FileAccess.get_modified_time(path)
	if _tp_cache_mtime != ftime:
		var raw = load(path)
		if raw != null:
			var data: Array = []
			if raw is Array: data = raw
			elif "data" in raw:
				var d = raw.data
				if d is Array: data = d
			_tp_cache.clear()
			for entry in data:
				if entry is Dictionary:
					var nm: String = str(entry.get("name", ""))
					var prof: Dictionary = entry.get("terrain_profile", {})
					if not nm.is_empty() and not prof.is_empty():
						_tp_cache[nm] = prof
			_tp_cache_mtime = ftime
	return _tp_cache.get(biome_name, {
		"height_noise_freq": 0.0035, "height_t0": 0.28, "height_t1": 0.48, "height_t2": 0.68,
		"path_noise_freq": 0.009, "path_threshold": 0.72, "path_half_width": 0.08,
		"wash_threshold": 0.48, "noise_freq": 0.008, "blocked_base": 0.10, "blocked_elev_factor": 0.06,
		"vegetation_base": 0.22, "vegetation_rain_factor": 0.12, "debris_threshold": 0.42,
		"forest_noise_freq": 0.006, "forest_threshold": 0.58,
	})


static func _load_biome_decor(biome_name: String) -> Dictionary:
	var path := "res://data/resource_nodes.json"
	if not ResourceLoader.exists(path): return {}
	var ftime := FileAccess.get_modified_time(path)
	if _decor_cache_mtime != ftime:
		var raw = load(path)
		if raw != null:
			var data: Dictionary = {}
			if raw is Dictionary: data = raw
			elif "data" in raw:
				var d = raw.data
				if d is Dictionary: data = d
			if not data.is_empty():
				_decor_cache = data.get("decor", {}); _decor_cache_mtime = ftime
	return _decor_cache.get(biome_name, {})


static func _load_biome_decor_profile(biome_name: String) -> Dictionary:
	var path := "res://data/biomes.json"
	if not ResourceLoader.exists(path): return {}
	var ftime := FileAccess.get_modified_time(path)
	if _dp_cache_mtime != ftime:
		var raw = load(path)
		if raw != null:
			var data: Array = []
			if raw is Array: data = raw
			elif "data" in raw:
				var d = raw.data
				if d is Array: data = d
			_dp_cache.clear()
			for entry in data:
				if entry is Dictionary:
					var nm: String = str(entry.get("name", ""))
					var prof: Dictionary = entry.get("decor_profile", {})
					if not nm.is_empty() and not prof.is_empty():
						_dp_cache[nm] = prof
			_dp_cache_mtime = ftime
	return _dp_cache.get(biome_name, {
		"cluster_noise_freq": 0.014, "cluster_threshold": 0.62,
		"small_cluster_noise_freq": 0.018, "small_cluster_threshold": 0.42,
		"meadow_threshold": 0.42, "large_density_mult": 1.0, "small_density_mult": 1.0,
	})
