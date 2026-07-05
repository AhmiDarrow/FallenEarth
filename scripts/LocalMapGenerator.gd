## LocalMapGenerator — Procedural 512×512 local playfield per sphere hex.
## Each hex on the world sphere maps to one explorable local region (RimWorld tile → colony map).
class_name LocalMapGenerator
extends RefCounted

const MAP_SIZE := 512
const TERRAIN_GROUND := 0
const TERRAIN_DEBRIS := 1
const TERRAIN_VEGETATION := 2
const TERRAIN_BLOCKED := 3

## TERRAIN_RIFT_SCAR was removed in v0.4.0 Phase 0. Rifts are now entities
## spawned at coordinates (see RiftRunner) and rendered as markers on the
## local map, not as terrain. Any legacy save with terrain[i] == 4 is
## treated as TERRAIN_GROUND by LocalMapView.configure().

const EDGE_NORTH := 0
const EDGE_SOUTH := 1
const EDGE_EAST := 2
const EDGE_WEST := 3

## Axial neighbor deltas for each cardinal map edge (pointy-top hex, simplified 4-edge model).
const EDGE_TO_HEX_DIR: Array[Vector2i] = [
	Vector2i(0, -1),  # north
	Vector2i(0, 1),   # south
	Vector2i(1, 0),   # east
	Vector2i(-1, 0),  # west
]

## Entry local position when crossing from a given edge into this hex.
const EDGE_ENTRY_POS: Array[Vector2i] = [
	Vector2i(MAP_SIZE / 2, MAP_SIZE - 4),  # entered from north → spawn near south edge
	Vector2i(MAP_SIZE / 2, 3),           # from south → near north
	Vector2i(3, MAP_SIZE / 2),           # from east → near west
	Vector2i(MAP_SIZE - 4, MAP_SIZE / 2),  # from west → near east
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


static func generate(world_seed: String, q: int, r: int, biome_tile: Dictionary) -> Dictionary:
	var local_seed := make_local_seed(world_seed, q, r)
	var rng := _rng(local_seed)
	var biome_name: String = str(biome_tile.get("name", "Ash Wastes"))
	var terrain := PackedByteArray()
	terrain.resize(MAP_SIZE * MAP_SIZE)
	# occupied: PackedByteArray of length MAP_SIZE*MAP_SIZE, 1 = something
	# already placed here (resource node, floor pickup, mob). Prevents
	# double-stacking entities.
	var occupied := PackedByteArray()
	occupied.resize(MAP_SIZE * MAP_SIZE)

	var elev: float = float(biome_tile.get("elevation", 0.5))
	var rain: float = float(biome_tile.get("rainfall", 0.5))
	var rift_chance: float = float(biome_tile.get("rift_chance", 0.3))

	for y in MAP_SIZE:
		for x in MAP_SIZE:
			var idx := y * MAP_SIZE + x
			var n := rng.randf()
			var edge_dist := mini(mini(x, MAP_SIZE - 1 - x), mini(y, MAP_SIZE - 1 - y))
			if edge_dist < 2:
				terrain[idx] = TERRAIN_GROUND
			elif n < 0.06 + elev * 0.04:
				terrain[idx] = TERRAIN_BLOCKED
			elif n < 0.18 + rain * 0.12:
				terrain[idx] = TERRAIN_VEGETATION
			elif n < 0.32:
				terrain[idx] = TERRAIN_DEBRIS
			else:
				terrain[idx] = TERRAIN_GROUND

	# Clear a large homestead pocket at center so the player has room to explore on spawn.
	var cx := MAP_SIZE / 2
	var cy := MAP_SIZE / 2
	for dy in range(-24, 25):
		for dx in range(-24, 25):
			var px := cx + dx
			var py := cy + dy
			if px < 0 or py < 0 or px >= MAP_SIZE or py >= MAP_SIZE:
				continue
			terrain[py * MAP_SIZE + px] = TERRAIN_GROUND

	# Phase 1: emit resource nodes and floor pickups
	var resource_nodes: Array = _emit_resource_nodes(rng, biome_name, terrain, occupied, Vector2i(cx, cy))
	var floor_pickups: Array = _emit_floor_pickups(rng, biome_name, terrain, occupied, Vector2i(cx, cy))

	return {
		"size": MAP_SIZE,
		"hex_key": hex_key(q, r),
		"q": q,
		"r": r,
		"biome": biome_name,
		"local_seed": local_seed,
		"terrain": terrain,
		"spawn": Vector2i(cx, cy),
		"visited": false,
		"explored_pct": 0.0,
		"mobs": [],
		"active_rifts": [],
		"settlement": {"structures": [], "npcs": []},
		"resource_nodes": resource_nodes,
		"floor_pickups": floor_pickups,
	}


# Place per-biome resource nodes (trees, formations, ore, crystals, fauna)
# on walkable cells, avoiding the homestead pocket and edges. Returns a
# list of {x, y, ...node_data} entries. The node_data is the JSON entry
# from data/resource_nodes.json, augmented with the placed cell.
static func _emit_resource_nodes(
		rng: RandomNumberGenerator,
		biome_name: String,
		terrain: PackedByteArray,
		occupied: PackedByteArray,
		spawn: Vector2i
) -> Array:
	var biome_data: Dictionary = _load_biome_resource_nodes(biome_name)
	if biome_data.is_empty():
		return []
	var out: Array = []
	# Categories in placement order; ore/crystals are usually rarer so
	# place them first to reserve walkable cells.
	var categories := ["crystals", "ore", "formations", "trees", "fauna"]
	for category in categories:
		var entries: Array = biome_data.get(category, [])
		for entry in entries:
			if entry == null or not (entry is Dictionary):
				continue
			var density: float = float(entry.get("density", 0.0))
			if density <= 0.0:
				continue
			var count: int = int(round(MAP_SIZE * MAP_SIZE * density))
			for _i in count:
				var pos: Vector2i = _pick_walkable_cell(rng, terrain, occupied, spawn)
				if pos.x < 0:
					break
				var placed: Dictionary = (entry as Dictionary).duplicate(true)
				placed["x"] = pos.x
				placed["y"] = pos.y
				placed["category"] = category
				out.append(placed)
	return out


# Place sticks and stones on walkable cells outside the spawn pocket.
static func _emit_floor_pickups(
		rng: RandomNumberGenerator,
		biome_name: String,
		terrain: PackedByteArray,
		occupied: PackedByteArray,
		spawn: Vector2i
) -> Array:
	var densities: Dictionary = _load_floor_pickup_densities()
	if densities.is_empty():
		return []
	var out: Array = []
	# Floor pickups share density with whatever the JSON provides, with
	# a per-cell chance rolled at generation. We pick a deterministic
	# number of cells to place based on density.
	for pickup_id in ["stick", "stone"]:
		var density: float = float(densities.get(pickup_id, 0.0))
		if density <= 0.0:
			continue
		var count: int = int(round(MAP_SIZE * MAP_SIZE * density))
		for _i in count:
			var pos: Vector2i = _pick_walkable_cell(rng, terrain, occupied, spawn, 8)
			if pos.x < 0:
				break
			occupied[pos.y * MAP_SIZE + pos.x] = 1
			out.append({
				"id": pickup_id,
				"x": pos.x,
				"y": pos.y,
				"qty": 1,
			})
	return out


# Find a random walkable cell that is not yet occupied and is not within
# `spawn_buffer` cells of the spawn point. Returns Vector2i(-1, -1) if
# no candidate found after `max_attempts` tries.
static func _pick_walkable_cell(
		rng: RandomNumberGenerator,
		terrain: PackedByteArray,
		occupied: PackedByteArray,
		spawn: Vector2i,
		spawn_buffer: int = 12
	) -> Vector2i:
	var max_attempts := 32
	for _i in max_attempts:
		var x: int = rng.randi_range(0, MAP_SIZE - 1)
		var y: int = rng.randi_range(0, MAP_SIZE - 1)
		if abs(x - spawn.x) < spawn_buffer or abs(y - spawn.y) < spawn_buffer:
			continue
		var idx := y * MAP_SIZE + x
		if int(terrain[idx]) == TERRAIN_BLOCKED:
			continue
		if int(occupied[idx]) != 0:
			continue
		occupied[idx] = 1
		return Vector2i(x, y)
	return Vector2i(-1, -1)


# Cached loader for the resource_nodes.json (whole-file; this runs at
# every map generate, so cache by file modification time).
static var _rn_cache: Dictionary = {}
static var _rn_cache_mtime: int = -1


static func _load_biome_resource_nodes(biome_name: String) -> Dictionary:
	var path := "res://data/resource_nodes.json"
	if not ResourceLoader.exists(path):
		return {}
	var ftime := FileAccess.get_modified_time(path)
	if _rn_cache_mtime != ftime:
		var raw = load(path)
		if raw != null:
			var data: Dictionary = {}
			if raw is Dictionary:
				data = raw
			elif "data" in raw:
				var d = raw.data
				if d is Dictionary:
					data = d
			if not data.is_empty():
				_rn_cache = data.get("biomes", {})
				_rn_cache_mtime = ftime
	return _rn_cache.get(biome_name, {})


static var _fp_cache: Dictionary = {}
static var _fp_cache_mtime: int = -1


static func _load_floor_pickup_densities() -> Dictionary:
	var path := "res://data/resource_nodes.json"
	if not ResourceLoader.exists(path):
		return {}
	var ftime := FileAccess.get_modified_time(path)
	if _fp_cache_mtime != ftime:
		var raw = load(path)
		if raw != null:
			var data: Dictionary = {}
			if raw is Dictionary:
				data = raw
			elif "data" in raw:
				var d = raw.data
				if d is Dictionary:
					data = d
			if not data.is_empty():
				_fp_cache = data.get("floor_pickup_density", {})
				_fp_cache_mtime = ftime
	return _fp_cache


static func get_terrain(map_data: Dictionary, x: int, y: int) -> int:
	var size: int = int(map_data.get("size", MAP_SIZE))
	if x < 0 or y < 0 or x >= size or y >= size:
		return TERRAIN_BLOCKED
	var terrain: PackedByteArray = map_data.get("terrain", PackedByteArray())
	if terrain.is_empty():
		return TERRAIN_GROUND
	return int(terrain[y * size + x])


static func is_walkable(map_data: Dictionary, x: int, y: int) -> bool:
	return get_movement_cost(map_data, x, y) >= 0


static func get_movement_cost(map_data: Dictionary, x: int, y: int) -> int:
	var terrain: int = get_terrain(map_data, x, y)
	return get_terrain_movement_cost(terrain)


static func get_terrain_movement_cost(terrain_type: int) -> int:
	match terrain_type:
		TERRAIN_GROUND:
			return 1
		TERRAIN_DEBRIS:
			return 2
		TERRAIN_VEGETATION:
			return 2
		TERRAIN_BLOCKED:
			return -1
		_:
			return 1


static func get_neighbor_hex(q: int, r: int, edge: int) -> Vector2i:
	if edge < 0 or edge >= EDGE_TO_HEX_DIR.size():
		return Vector2i(q, r)
	var d: Vector2i = EDGE_TO_HEX_DIR[edge]
	return Vector2i(q + d.x, r + d.y)


static func get_entry_position(from_edge: int) -> Vector2i:
	if from_edge < 0 or from_edge >= EDGE_ENTRY_POS.size():
		return Vector2i(MAP_SIZE / 2, MAP_SIZE / 2)
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


# terrain_color was removed in v0.4.0 Phase 0 — it was dead code from the
# old sprite renderer. The new TileSetService reads tile colors from PNG files.

static func terrain_label(terrain_type: int) -> String:
	match terrain_type:
		TERRAIN_DEBRIS:
			return "debris"
		TERRAIN_VEGETATION:
			return "vegetation"
		TERRAIN_BLOCKED:
			return "blocked"
		_:
			return "ground"
