## LocalMapGenerator — Procedural 512×512 local playfield per sphere hex.
## Each hex on the world sphere maps to one explorable local region (RimWorld tile → colony map).
class_name LocalMapGenerator
extends RefCounted

const MAP_SIZE := 512
const TERRAIN_GROUND := 0
const TERRAIN_DEBRIS := 1
const TERRAIN_VEGETATION := 2
const TERRAIN_BLOCKED := 3
const TERRAIN_WATER := 4

## TERRAIN_RIFT_SCAR was removed in v0.4.0 Phase 0. Rifts are now entities
## spawned at coordinates (see RiftRunner) and rendered as markers on the
## local map, not as terrain. Terrain indices are now contiguous 0-4.

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
	Vector2i(256, MAP_SIZE - 4),  # entered from north → spawn near south edge
	Vector2i(256, 3),           # from south → near north
	Vector2i(3, 256),           # from east → near west
	Vector2i(MAP_SIZE - 4, 256),  # from west → near east
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

	# Load per-biome terrain profile from data/biomes.json for noise and thresholds
	var profile: Dictionary = _load_biome_terrain_profile(biome_name)

	# FastNoiseLite for spatial coherence — creates landscape features (lakes, forests, rocky areas)
	# rather than per-cell random speckle. Landscape layer gives large blobs, detail adds edge variation.
	var landscape_noise := FastNoiseLite.new()
	landscape_noise.seed = hash_seed(local_seed + "landscape")
	landscape_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	landscape_noise.frequency = profile.get("noise_freq", 0.008)
	landscape_noise.fractal_octaves = profile.get("noise_octaves", 3)

	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = hash_seed(local_seed + "detail")
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail_noise.frequency = profile.get("detail_freq", 0.03)
	detail_noise.fractal_octaves = profile.get("detail_octaves", 2)

	for y in MAP_SIZE:
		for x in MAP_SIZE:
			var idx := y * MAP_SIZE + x
			var edge_dist := mini(mini(x, MAP_SIZE - 1 - x), mini(y, MAP_SIZE - 1 - y))
			if edge_dist < 2:
				terrain[idx] = TERRAIN_GROUND
				continue
			# Combine landscape + detail noise, remap [-1,1] simplex to [0,1] range
			var ln := landscape_noise.get_noise_2d(x, y) * 0.5 + 0.5
			var dn := detail_noise.get_noise_2d(x, y) * 0.25 + 0.25
			var n := clampf(ln + dn, 0.0, 1.0)
			# Per-biome thresholds from data/biomes.json terrain_profile.
			# rain/elev from WorldGenerator's climate model tweak proportions per hex.
			var blocked_base: float = profile.get("blocked_base", 0.10)
			var blocked_elev: float = profile.get("blocked_elev_factor", 0.06)
			var veget_base: float = profile.get("vegetation_base", 0.25)
			var veget_rain: float = profile.get("vegetation_rain_factor", 0.15)
			var debris_t: float = profile.get("debris_threshold", 0.42)
			var blocked_t := blocked_base + elev * blocked_elev
			var veget_t := veget_base + rain * veget_rain
			if n < blocked_t:
				terrain[idx] = TERRAIN_BLOCKED
			elif n < veget_t:
				terrain[idx] = TERRAIN_VEGETATION
			elif n < debris_t:
				terrain[idx] = TERRAIN_DEBRIS
			else:
				terrain[idx] = TERRAIN_GROUND

	# Phase: carve rivers (water channels) using a separate noise layer.
	# Converts low-elevation cells in river noise troughs to TERRAIN_WATER.
	_carve_rivers(terrain, local_seed, elev)

	# Edge detection: compute a bitmask per cell indicating which cardinal
	# neighbors have different terrain. N=1, S=2, W=4, E=8. Used by TileSetService
	# to place edge-blend tiles for smoother terrain transitions.
	var edge_mask := PackedByteArray()
	edge_mask.resize(MAP_SIZE * MAP_SIZE)
	for y in MAP_SIZE:
		for x in MAP_SIZE:
			var idx := y * MAP_SIZE + x
			var t := int(terrain[idx])
			var mask := 0
			if y > 0 and int(terrain[idx - MAP_SIZE]) != t:
				mask |= 1  # N
			if y < MAP_SIZE - 1 and int(terrain[idx + MAP_SIZE]) != t:
				mask |= 2  # S
			if x > 0 and int(terrain[idx - 1]) != t:
				mask |= 4  # W
			if x < MAP_SIZE - 1 and int(terrain[idx + 1]) != t:
				mask |= 8  # E
			edge_mask[idx] = mask

	# Clear a large homestead pocket at center so the player has room to explore on spawn.
	var cx := int(MAP_SIZE / 2.0)
	var cy := int(MAP_SIZE / 2.0)
	for dy in range(-24, 25):
		for dx in range(-24, 25):
			var px := cx + dx
			var py := cy + dy
			if px < 0 or py < 0 or px >= MAP_SIZE or py >= MAP_SIZE:
				continue
			terrain[py * MAP_SIZE + px] = TERRAIN_GROUND

	# v0.8.0: check if this hex has a town. If so, generate a procedural
	# town layout (clearing + buildings + road) before placing other entities.
	var town_data: Dictionary = _get_town_for_hex(q, r)
	var settlement_data: Dictionary = {"structures": [], "npcs": [], "town_data": town_data, "boundary": null}
	if not town_data.is_empty():
		var structures: Array = _generate_town_layout(rng, town_data, terrain, occupied, Vector2i(cx, cy))
		settlement_data["structures"] = structures
		# Compute bounding box encompassing the clearing + all buildings
		settlement_data["boundary"] = _compute_town_boundary(structures, Vector2i(cx, cy))

	# v0.6.0 follow-up polish: emit one cooking table near the spawn pocket
	# so the player has access to cooking recipes from minute 1. Mark the
	# cell occupied before the resource emitters so they don't drop a tree
	# on top of the table.
	var cooking_tables: Array = _emit_start_cooking_table(Vector2i(cx, cy))
	for ct in cooking_tables:
		var ct_cell: Vector2i = Vector2i(int(ct.get("x", 0)), int(ct.get("y", 0)))
		if ct_cell.x >= 0 and ct_cell.y >= 0 and ct_cell.x < MAP_SIZE and ct_cell.y < MAP_SIZE:
			occupied[ct_cell.y * MAP_SIZE + ct_cell.x] = 1

	# Phase 1: emit resource nodes and floor pickups (after cooking table
	# so the table cell is reserved; town buildings are already in occupied[])
	var resource_nodes: Array = _emit_resource_nodes(rng, biome_name, terrain, occupied, Vector2i(cx, cy))
	var floor_pickups: Array = _emit_floor_pickups(rng, biome_name, terrain, occupied, Vector2i(cx, cy))
	# Phase 2: emit visual decor (rocks, ruins, flora) — no yields, just atmosphere
	var decor: Array = _emit_decor(rng, biome_name, terrain, occupied, Vector2i(cx, cy))
	# Entity collision overlay: trees/rocks/ore/blocking decor block walk.
	var entity_blocked := _build_entity_blocked(resource_nodes, decor)

	return {
		"size": MAP_SIZE,
		"hex_key": hex_key(q, r),
		"q": q,
		"r": r,
		"entity_blocked": entity_blocked,
		"biome": biome_name,
		"local_seed": local_seed,
		"terrain": terrain,
		"edge_mask": edge_mask,
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
	# Categories in placement order; ore/crystals/rocks rarer first.
	var categories := ["crystals", "ore", "rocks", "formations", "trees", "fauna"]
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
				# Harvestables block movement unless explicitly passable.
				if not placed.has("passable"):
					placed["passable"] = false
				out.append(placed)
	return out


## Build a MAP_SIZE² packed mask of cells blocked by solid entities.
static func _build_entity_blocked(resource_nodes: Array, decor: Array) -> PackedByteArray:
	var blocked := PackedByteArray()
	blocked.resize(MAP_SIZE * MAP_SIZE)
	for entry in resource_nodes:
		if entry == null or not (entry is Dictionary):
			continue
		if bool((entry as Dictionary).get("passable", false)):
			continue
		var x: int = int((entry as Dictionary).get("x", -1))
		var y: int = int((entry as Dictionary).get("y", -1))
		if x < 0 or y < 0 or x >= MAP_SIZE or y >= MAP_SIZE:
			continue
		blocked[y * MAP_SIZE + x] = 1
	for entry in decor:
		if entry == null or not (entry is Dictionary):
			continue
		# Decor defaults to blocking when passable is omitted.
		if bool((entry as Dictionary).get("passable", false)):
			continue
		var x2: int = int((entry as Dictionary).get("x", -1))
		var y2: int = int((entry as Dictionary).get("y", -1))
		if x2 < 0 or y2 < 0 or x2 >= MAP_SIZE or y2 >= MAP_SIZE:
			continue
		blocked[y2 * MAP_SIZE + x2] = 1
	return blocked


static func set_entity_blocked(map_data: Dictionary, x: int, y: int, is_blocked: bool) -> void:
	var size: int = int(map_data.get("size", MAP_SIZE))
	if x < 0 or y < 0 or x >= size or y >= size:
		return
	var eb: PackedByteArray = map_data.get("entity_blocked", PackedByteArray())
	if eb.is_empty():
		eb.resize(size * size)
		map_data["entity_blocked"] = eb
	eb[y * size + x] = 1 if is_blocked else 0
	map_data["entity_blocked"] = eb


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


## Emit visual decor (rocks, ruins, flora) using dual placement:
## - Large items (craters, ruins, walls) use noise clustering for natural groups
## - Small items (rocks, flowers, shrubs) use density-based random placement
## Decor is purely visual — no yields, no interaction. passable=false blocks
## movement; passable=true is walkable overlay.
static func _emit_decor(
		rng: RandomNumberGenerator,
		biome_name: String,
		terrain: PackedByteArray,
		occupied: PackedByteArray,
		spawn: Vector2i
) -> Array:
	var decor_data: Dictionary = _load_biome_decor(biome_name)
	if decor_data.is_empty():
		return []
	var profile: Dictionary = _load_biome_decor_profile(biome_name)
	var out: Array = []

	# Noise field for clustering large decor items
	var cluster_noise := FastNoiseLite.new()
	cluster_noise.seed = hash_seed("%s#decor_cluster" % biome_name)
	cluster_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cluster_noise.frequency = profile.get("cluster_noise_freq", 0.02)
	cluster_noise.fractal_octaves = 2

	var cluster_threshold: float = profile.get("cluster_threshold", 0.6)

	# Phase 1: Large decor items — placed via noise clustering
	var large_items: Array = decor_data.get("large", [])
	for entry in large_items:
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
			# Check noise value — only place if above threshold (creates clusters)
			var nval: float = cluster_noise.get_noise_2d(pos.x, pos.y) * 0.5 + 0.5
			if nval < cluster_threshold:
				continue
			var placed: Dictionary = (entry as Dictionary).duplicate(true)
			placed["x"] = pos.x
			placed["y"] = pos.y
			placed["category"] = "decor_large"
			out.append(placed)

	# Phase 2: Small decor items — placed via density (scattered)
	var small_items: Array = decor_data.get("small", [])
	for entry in small_items:
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
			placed["category"] = "decor_small"
			out.append(placed)

	return out


# Find a random walkable cell that is not yet occupied and is not within
# `spawn_buffer` cells of the spawn point. Returns Vector2i(-1, -1) if
# no candidate found after `max_attempts` tries.
static func _pick_walkable_cell(
		rng: RandomNumberGenerator,
		terrain: PackedByteArray,
		occupied: PackedByteArray,
		spawn: Vector2i,
		spawn_buffer: int = 6
	) -> Vector2i:
	# Chebyshev pocket only (NOT axis-OR). Old `abs(x)<buf OR abs(y)<buf`
	# wiped an entire cross the full width/height of the map — left the
	# playfield looking empty while the minimap still showed distant dots.
	var max_attempts := 48
	for _i in max_attempts:
		var x: int = rng.randi_range(0, MAP_SIZE - 1)
		var y: int = rng.randi_range(0, MAP_SIZE - 1)
		if maxi(abs(x - spawn.x), abs(y - spawn.y)) < spawn_buffer:
			continue
		var idx := y * MAP_SIZE + x
		# Resource nodes, decor, and floor pickups only spawn on solid ground.
		# _carve_rivers() leaves TERRAIN_WATER cells scattered across the map,
		# which used to receive resource nodes (16% of Scorched Plains had trees
		# on water). Treat water as blocked for placement.
		var t := int(terrain[idx])
		if t == TERRAIN_BLOCKED or t == TERRAIN_WATER:
			continue
		if int(occupied[idx]) != 0:
			continue
		occupied[idx] = 1
		return Vector2i(x, y)
	return Vector2i(-1, -1)


## v0.6.0 follow-up polish: emit a single cooking table near the spawn
## pocket. Placed at a fixed offset from the spawn (8 tiles east, 8 tiles
## south) so it's always discoverable regardless of biome. Returns
## `[{x, y, station_id}]` for LocalMapView to consume.
##
## The placement is deterministic — same spawn position, same table
## position — so reloads of the same hex don't move the table.
static func _emit_start_cooking_table(spawn: Vector2i) -> Array:
	var table_pos: Vector2i = Vector2i(spawn.x + 8, spawn.y + 8)
	# Clamp to map bounds (in case spawn is near the edge — should never
	# happen since the spawn is at MAP_SIZE/2, but defensive).
	if table_pos.x < 0:
		table_pos.x = 0
	if table_pos.y < 0:
		table_pos.y = 0
	if table_pos.x >= MAP_SIZE:
		table_pos.x = MAP_SIZE - 1
	if table_pos.y >= MAP_SIZE:
		table_pos.y = MAP_SIZE - 1
	return [{
		"x": table_pos.x,
		"y": table_pos.y,
		"station_id": "cooking_table",
	}]


# v0.8.0: Town layout generation ------------------------------------------------

## Cached loader for towns.json (building_types + templates).
static var _towns_cache: Dictionary = {}
static var _towns_cache_mtime: int = -1


static func _load_towns_config() -> Dictionary:
	var path := "res://data/towns.json"
	if not ResourceLoader.exists(path):
		return {}
	var ftime := FileAccess.get_modified_time(path)
	if _towns_cache_mtime != ftime:
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
				_towns_cache = data
				_towns_cache_mtime = ftime
	return _towns_cache


## Look up whether (q, r) contains a town. Returns the town dict from
## world_data.towns_seeded, or {} if not a town hex. Uses a static cache
## so the lookup is O(1) after the first call per session.
static var _town_hex_cache: Dictionary = {}
static var _town_hex_loaded: bool = false


static func _get_town_for_hex(q: int, r: int) -> Dictionary:
	if not _town_hex_loaded:
		_rebuild_town_hex_cache()
	var key := hex_key(q, r)
	return _town_hex_cache.get(key, {})


static func _rebuild_town_hex_cache() -> void:
	_town_hex_cache.clear()
	# GameState is an autoload — read world_data from it at static-call time.
	var gs: Node = Engine.get_singleton("GameState") if Engine.has_singleton("GameState") else null
	if gs == null:
		# Fallback: try /root/GameState (works at runtime, not in @tool)
		gs = Node.new()  # can't access /root from static; cache will be empty
		gs.queue_free()
		_town_hex_loaded = true
		return
	if not gs.has_method("get_world_data"):
		_town_hex_loaded = true
		return
	var wd: Dictionary = gs.call("get_world_data")
	var towns: Array = wd.get("towns_seeded", [])
	for t in towns:
		if t is Dictionary:
			var hk: String = str(t.get("hex", ""))
			if not hk.is_empty():
				_town_hex_cache[hk] = t
	_town_hex_loaded = true


## Generate a procedural town layout: central clearing + ring road +
## buildings placed around the perimeter. Returns an array of structure
## dictionaries for LocalMapView to render.
##
## Algorithm:
## 1. Clear a circular clearing (radius ~15) at center to TERRAIN_GROUND
## 2. Place buildings evenly spaced around the clearing edge
## 3. Each building footprint is marked TERRAIN_BLOCKED + occupied
## 4. A 1-cell-wide debris path connects each building entrance to the clearing
static func _generate_town_layout(
		rng: RandomNumberGenerator,
		town_data: Dictionary,
		terrain: PackedByteArray,
		occupied: PackedByteArray,
		spawn: Vector2i
) -> Array:
	var config: Dictionary = _load_towns_config()
	var building_types: Dictionary = config.get("building_types", {})
	var buildings: Array = town_data.get("buildings", [])
	if buildings.is_empty() or building_types.is_empty():
		return []

	var structures: Array = []
	var cx: int = spawn.x
	var cy: int = spawn.y
	var clearing_radius: int = 15

	# Step 1: Clear a circular clearing at center
	for dy in range(-clearing_radius - 2, clearing_radius + 3):
		for dx in range(-clearing_radius - 2, clearing_radius + 3):
			var px: int = cx + dx
			var py: int = cy + dy
			if px < 0 or py < 0 or px >= MAP_SIZE or py >= MAP_SIZE:
				continue
			if dx * dx + dy * dy <= (clearing_radius + 1) * (clearing_radius + 1):
				terrain[py * MAP_SIZE + px] = TERRAIN_GROUND

	# Step 2: Place buildings evenly around the clearing
	var n_buildings: int = buildings.size()
	var angle_step: float = TAU / float(n_buildings)
	var place_radius: float = float(clearing_radius + 4)

	for i in n_buildings:
		var bld_name: String = str(buildings[i])
		var bld_info: Dictionary = building_types.get(bld_name, {})
		if bld_info.is_empty():
			continue
		var bw: int = int(bld_info.get("w", 2))
		var bh: int = int(bld_info.get("h", 2))
		var role: String = str(bld_info.get("role", "vendor"))
		var sprite: String = str(bld_info.get("sprite", bld_name))
		var label: String = str(bld_info.get("label", bld_name))

		# Position building center on the ring
		var angle: float = angle_step * float(i) - PI / 2.0
		var bx_center: int = cx + int(cos(angle) * place_radius)
		var by_center: int = cy + int(sin(angle) * place_radius)

		# Convert center to top-left corner
		var bx: int = bx_center - int(bw / 2.0)
		var by: int = by_center - int(bh / 2.0)

		# Clamp to map bounds (leave 2-cell border)
		bx = clampi(bx, 2, MAP_SIZE - bw - 2)
		by = clampi(by, 2, MAP_SIZE - bh - 2)

		# Step 3: Mark building footprint as TERRAIN_BLOCKED + occupied
		var entrance_x: int = bx + int(bw / 2.0)
		var entrance_y: int = by + bh  # entrance is at bottom center
		for dy2 in bh:
			for dx2 in bw:
				var px: int = bx + dx2
				var py: int = by + dy2
				if px < 0 or py < 0 or px >= MAP_SIZE or py >= MAP_SIZE:
					continue
				var idx: int = py * MAP_SIZE + px
				terrain[idx] = TERRAIN_BLOCKED
				occupied[idx] = 1

		# Step 4: Path from building entrance to clearing edge (debris trail)
		var path_dx: int = 0
		var path_dy: int = 0
		if entrance_y < cy:
			path_dy = 1  # building is above center, path goes south
		elif entrance_y > cy:
			path_dy = -1  # building is below center, path goes north
		if entrance_x < cx:
			path_dx = 1
		elif entrance_x > cx:
			path_dx = -1

		# Walk from entrance toward clearing, placing debris path
		var px: int = entrance_x
		var py: int = entrance_y
		for _step in clearing_radius + bw:
			if px < 0 or py < 0 or px >= MAP_SIZE or py >= MAP_SIZE:
				break
			var idx: int = py * MAP_SIZE + px
			if terrain[idx] == TERRAIN_BLOCKED:
				# Reached the clearing or another building — stop
				break
			if terrain[idx] != TERRAIN_VEGETATION:
				terrain[idx] = TERRAIN_DEBRIS
			# Move toward clearing center
			var dist_to_center: int = (px - cx) * (px - cx) + (py - cy) * (py - cy)
			if dist_to_center <= clearing_radius * clearing_radius:
				break  # reached the clearing
			# Prefer moving along the dominant axis
			if abs(entrance_x - cx) >= abs(entrance_y - cy):
				px += path_dx
			else:
				py += path_dy

		# Record the structure for rendering
		structures.append({
			"id": bld_name,
			"role": role,
			"sprite": sprite,
			"label": label,
			"x": bx,
			"y": by,
			"w": bw,
			"h": bh,
			"entrance_x": entrance_x,
			"entrance_y": entrance_y,
		})

	return structures


## Compute a Rect2i bounding box encompassing the clearing + all buildings.
## Used by HubWorld._seed_mobs_for_hex() to exclude mobs from the town area.
static func _compute_town_boundary(structures: Array, center: Vector2i) -> Rect2i:
	var clearing_radius: int = 15
	var min_x: int = center.x - clearing_radius
	var min_y: int = center.y - clearing_radius
	var max_x: int = center.x + clearing_radius
	var max_y: int = center.y + clearing_radius

	for s in structures:
		if not (s is Dictionary):
			continue
		var sx: int = int(s.get("x", 0))
		var sy: int = int(s.get("y", 0))
		var sw: int = int(s.get("w", 2))
		var sh: int = int(s.get("h", 2))
		min_x = mini(min_x, sx)
		min_y = mini(min_y, sy)
		max_x = maxi(max_x, sx + sw)
		max_y = maxi(max_y, sy + sh)

	# Clamp to map bounds
	min_x = clampi(min_x, 0, MAP_SIZE - 1)
	min_y = clampi(min_y, 0, MAP_SIZE - 1)
	max_x = clampi(max_x, 0, MAP_SIZE - 1)
	max_y = clampi(max_y, 0, MAP_SIZE - 1)

	return Rect2i(min_x, min_y, max_x - min_x, max_y - min_y)


# End v0.8.0 town layout --------------------------------------------------------


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


# Cached loader for terrain_profile from data/biomes.json.
static var _tp_cache: Dictionary = {}
static var _tp_cache_mtime: int = -1


## Returns the terrain_profile dict for a biome, or empty dict if not found.
## The profile contains noise frequency/octaves and terrain type thresholds.
static func _load_biome_terrain_profile(biome_name: String) -> Dictionary:
	var path := "res://data/biomes.json"
	if not ResourceLoader.exists(path):
		return {}
	var ftime := FileAccess.get_modified_time(path)
	var raw_list = null
	if _tp_cache_mtime != ftime:
		var raw = load(path)
		if raw != null:
			var data: Array = []
			if raw is Array:
				data = raw
			elif "data" in raw:
				var d = raw.data
				if d is Array:
					data = d
			_tp_cache.clear()
			for entry in data:
				if entry is Dictionary:
					var nm: String = str(entry.get("name", ""))
					var prof: Dictionary = entry.get("terrain_profile", {})
					if not nm.is_empty() and not prof.is_empty():
						_tp_cache[nm] = prof
			_tp_cache_mtime = ftime
	return _tp_cache.get(biome_name, {
		"noise_freq": 0.008, "noise_octaves": 3,
		"detail_freq": 0.03, "detail_octaves": 2,
		"blocked_base": 0.10, "blocked_elev_factor": 0.06,
		"vegetation_base": 0.25, "vegetation_rain_factor": 0.15,
		"debris_threshold": 0.42,
	})


# Cached loader for decor data from data/resource_nodes.json.
static var _decor_cache: Dictionary = {}
static var _decor_cache_mtime: int = -1


static func _load_biome_decor(biome_name: String) -> Dictionary:
	var path := "res://data/resource_nodes.json"
	if not ResourceLoader.exists(path):
		return {}
	var ftime := FileAccess.get_modified_time(path)
	if _decor_cache_mtime != ftime:
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
				_decor_cache = data.get("decor", {})
				_decor_cache_mtime = ftime
	return _decor_cache.get(biome_name, {})


# Cached loader for decor_profile from data/biomes.json.
static var _dp_cache: Dictionary = {}
static var _dp_cache_mtime: int = -1


static func _load_biome_decor_profile(biome_name: String) -> Dictionary:
	var path := "res://data/biomes.json"
	if not ResourceLoader.exists(path):
		return {}
	var ftime := FileAccess.get_modified_time(path)
	if _dp_cache_mtime != ftime:
		var raw = load(path)
		if raw != null:
			var data: Array = []
			if raw is Array:
				data = raw
			elif "data" in raw:
				var d = raw.data
				if d is Array:
					data = d
			_dp_cache.clear()
			for entry in data:
				if entry is Dictionary:
					var nm: String = str(entry.get("name", ""))
					var prof: Dictionary = entry.get("decor_profile", {})
					if not nm.is_empty() and not prof.is_empty():
						_dp_cache[nm] = prof
			_dp_cache_mtime = ftime
	return _dp_cache.get(biome_name, {
		"cluster_noise_freq": 0.02,
		"cluster_threshold": 0.65,
		"large_density": 0.003,
		"small_density": 0.014,
	})


static func get_terrain(map_data: Dictionary, x: int, y: int) -> int:
	var size: int = int(map_data.get("size", MAP_SIZE))
	if x < 0 or y < 0 or x >= size or y >= size:
		return TERRAIN_BLOCKED
	var terrain: PackedByteArray = map_data.get("terrain", PackedByteArray())
	if terrain.is_empty():
		return TERRAIN_GROUND
	return int(terrain[y * size + x])


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
		TERRAIN_WATER:
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
		TERRAIN_WATER:
			return "water"
		_:
			return "ground"


## Carve river/water channels into the terrain using a separate noise layer.
## Uses domain-warped simplex noise to create sinuous, connected water paths
## through low-elevation areas. Dilates thin rivers to 2-3 cells wide.
static func _carve_rivers(terrain: PackedByteArray, local_seed: String, elev: float) -> void:
	var river_noise := FastNoiseLite.new()
	river_noise.seed = hash_seed(local_seed + "river")
	river_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	river_noise.frequency = 0.025
	river_noise.fractal_octaves = 3
	river_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	river_noise.fractal_gain = 0.4

	# Domain-warp noise for river sinuosity
	var warp_noise := FastNoiseLite.new()
	warp_noise.seed = hash_seed(local_seed + "river_warp")
	warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	warp_noise.frequency = 0.008

	var water_threshold := 0.25 + (1.0 - elev) * 0.15
	var river_cells: Array[Vector2i] = []

	for y in MAP_SIZE:
		for x in MAP_SIZE:
			var idx := y * MAP_SIZE + x
			if int(terrain[idx]) == TERRAIN_BLOCKED:
				continue
			var warp_x := float(x) + warp_noise.get_noise_2d(x, y) * 30.0
			var warp_y := float(y) + warp_noise.get_noise_2d(x + 500, y + 500) * 30.0
			var rn := river_noise.get_noise_2d(warp_x, warp_y)
			var n := rn * 0.5 + 0.5
			if n < water_threshold:
				terrain[idx] = TERRAIN_WATER
				river_cells.append(Vector2i(x, y))

	# Dilate rivers: expand each water cell into walkable neighbors to create
	# wider channels. One pass is usually enough.
	var to_dilate: Array[Vector2i] = []
	for cell in river_cells:
		for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nx: int = cell.x + d.x
			var ny: int = cell.y + d.y
			if nx < 0 or ny < 0 or nx >= MAP_SIZE or ny >= MAP_SIZE:
				continue
			var nidx: int = ny * MAP_SIZE + nx
			var nt := int(terrain[nidx])
			if nt != TERRAIN_WATER and nt != TERRAIN_BLOCKED:
				to_dilate.append(Vector2i(nx, ny))
	for cell in to_dilate:
		terrain[cell.y * MAP_SIZE + cell.x] = TERRAIN_WATER
