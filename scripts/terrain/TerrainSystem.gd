## TerrainSystem — Unified terrain tile pipeline for Fallen Earth.
##
## Replaces the old three-layer mess (LocalMapGenerator → TileSetService → LocalMapView)
## with a single clean pipeline:
##
##   1. Constants: terrain types, biome dirs, PixelLab pair definitions
##   2. Loading: PixelLab Wang metadata+PNG → single atlas TileSet
##   3. Painting: vertex grid → pair projection → atlas lookup → TileMapLayer
##
## Core insight: each PixelLab Wang pair maps exactly TWO terrain types.
## A cell's own terrain type determines which pair to use for its corner transitions.
## No priority-based pair projection. No special water cases. No unused variants.
##
## Fallback for biomes without wang/ data: uses ground_64.png as a single solid tile.
class_name TerrainSystem
extends RefCounted

# ── Terrain type constants ──────────────────────────────────────────────

const TERRAIN_GROUND := 0
const TERRAIN_DEBRIS := 1
const TERRAIN_VEGETATION := 2
const TERRAIN_BLOCKED := 3
const TERRAIN_WATER := 4

const TERRAIN_NAMES := ["ground", "debris", "vegetation", "blocked", "water"]

# ── Map size ─────────────────────────────────────────────────────────────

const MAP_SIZE := 512
const CELL_SIZE := 64

# ── Biome directory slugs ────────────────────────────────────────────────

const BIOME_DIRS := {
	"Ash Wastes": "ash_wastes",
	"Rust Canyons": "rust_canyons",
	"Neon Bogs": "neon_bogs",
	"Scorched Plains": "scorched_plains",
	"Ironwood Thicket": "ironwood_thicket",
	"Glass Dunes": "glass_dunes",
	"Corpse Fields": "corpse_fields",
	"Stormspire Highlands": "stormspire_highlands",
	"Toxin Marshes": "toxin_marshes",
	"Dead City Outskirts": "dead_city_outskirts",
}

# ── PixelLab Wang pair definitions ───────────────────────────────────────
# Each pair stems from create_topdown_tileset(lower_description, upper_description).
# The pair maps two terrain types; tiles handle all 16 corner combinations.

const WANG_PAIRS: Array[Dictionary] = [
	{"stem": "primary",   "lower": TERRAIN_DEBRIS, "upper": TERRAIN_GROUND},
	{"stem": "g_debris",  "lower": TERRAIN_DEBRIS, "upper": TERRAIN_GROUND},
	{"stem": "g_veg",     "lower": TERRAIN_DEBRIS, "upper": TERRAIN_VEGETATION},
	{"stem": "g_water",   "lower": TERRAIN_WATER,  "upper": TERRAIN_GROUND},
	{"stem": "g_blocked", "lower": TERRAIN_BLOCKED,"upper": TERRAIN_GROUND},
]

# ── State ────────────────────────────────────────────────────────────────

static var _last_biome := ""
static var _tile_map: Dictionary = {}         # "nw,ne,sw,se" → Vector2i(atlas_coords)
static var _base_tiles: Dictionary = {}        # terrain_id → Vector2i(atlas_coords)
static var _tileset: TileSet = null
static var _using_wang := false

# ── Public API ───────────────────────────────────────────────────────────

static func biome_dir(biome_name: String) -> String:
	return BIOME_DIRS.get(biome_name, biome_name.to_snake_case())


static func has_wang_data(biome_name: String) -> bool:
	var dir := biome_dir(biome_name)
	if dir.is_empty():
		return false
	var wang_dir := "res://assets/tilesets/%s/wang" % dir
	return FileAccess.file_exists("%s/primary_metadata.json" % wang_dir)


static func tileset_for_biome(biome_name: String) -> TileSet:
	if biome_name == _last_biome and _tileset != null:
		return _tileset
	_clear()
	_last_biome = biome_name

	var dir := biome_dir(biome_name)
	if dir.is_empty():
		push_error("[TerrainSystem] unknown biome: %s" % biome_name)
		return null

	var base := "res://assets/tilesets/%s" % dir

	if _build_from_wang(biome_name, base):
		print("[TerrainSystem] %s → wang tileset (%d tiles, %d base)" % [
			biome_name, _tile_map.size(), _base_tiles.size()])
		_using_wang = true
		return _tileset

	if _build_from_ground64(base):
		print("[TerrainSystem] %s → ground_64 fallback" % biome_name)
		_using_wang = false
		return _tileset

	push_error("[TerrainSystem] %s: no tiles found" % biome_name)
	return null


static func using_wang() -> bool:
	return _using_wang


# ── Terrain painting ─────────────────────────────────────────────────────

## Paint a full terrain map onto a TileMapLayer using corner-Wang matching.
## The vertex grid is one cell larger in each dimension (size+1). Each vertex
## terrain is the majority of the 4 adjacent cells, with no priority weighting.
static func paint_terrain(layer: TileMapLayer, terrain: PackedByteArray, size: int = MAP_SIZE) -> void:
	if _tileset == null:
		push_error("[TerrainSystem] no tileset loaded")
		return

	layer.tile_set = _tileset
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var vs := size + 1
	var verts := PackedByteArray()
	verts.resize(vs * vs)
	for vy in vs:
		for vx in vs:
			verts[vy * vs + vx] = _vertex_terrain(vx, vy, size, terrain)

	for y in size:
		for x in size:
			var idx := y * size + x
			var cell_t := _clamp_terrain(int(terrain[idx]))
			var nw := int(verts[y * vs + x])
			var ne := int(verts[y * vs + x + 1])
			var sw := int(verts[(y + 1) * vs + x])
			var se := int(verts[(y + 1) * vs + x + 1])
			layer.set_cell(Vector2i(x, y), 0, resolve_tile(cell_t, nw, ne, sw, se))


## Resolve the atlas coordinates for one cell.
##
## Strategy (3 tiers):
##   1. Exact match — all 4 corners map directly to a known tile
##   2. Binary pair projection — reduce corners to exactly 2 terrain types
##      using the cell's most relevant PixelLab Wang pair, then exact match
##   3. Solid base tile — all corners same as cell_t
##
## The binary pair for projection is chosen by cell_t:
##   WATER    → water↔ground   (water stays water, rest → ground)
##   DEBRIS   → debris↔ground  (debris stays debris, rest → ground)
##   VEG      → debris↔veg     (veg stays veg, rest → debris)
##   BLOCKED  → blocked↔ground (blocked stays blocked, rest → ground)
##   GROUND   → determined by most common non-ground corner type
##
## This produces valid 2-terrain keys matching PixelLab pair definitions.
## No 3+ terrain keys are ever created.
static func resolve_tile(cell_t: int, nw: int, ne: int, sw: int, se: int) -> Vector2i:
	var key := "%d,%d,%d,%d" % [nw, ne, sw, se]
	if _tile_map.has(key):
		return _tile_map[key] as Vector2i

	# Determine which binary pair to project onto.
	var lo: int
	var hi: int

	match cell_t:
		TERRAIN_WATER:
			lo = TERRAIN_WATER; hi = TERRAIN_GROUND
		TERRAIN_DEBRIS:
			lo = TERRAIN_DEBRIS; hi = TERRAIN_GROUND
		TERRAIN_VEGETATION:
			lo = TERRAIN_DEBRIS; hi = TERRAIN_VEGETATION
		TERRAIN_BLOCKED:
			lo = TERRAIN_BLOCKED; hi = TERRAIN_GROUND
		_:  # TERRAIN_GROUND — pick pair by most common non-ground corner
			var counts := {}
			for c in [nw, ne, sw, se]:
				counts[c] = counts.get(c, 0) + 1
			var dominant := TERRAIN_GROUND
			var dominant_n := 0
			for tid in counts:
				var t := int(tid)
				if t != TERRAIN_GROUND and int(counts[tid]) > dominant_n:
					dominant_n = int(counts[tid])
					dominant = t
			match dominant:
				TERRAIN_WATER:    lo = TERRAIN_WATER;   hi = TERRAIN_GROUND
				TERRAIN_DEBRIS:   lo = TERRAIN_DEBRIS;  hi = TERRAIN_GROUND
				TERRAIN_VEGETATION: lo = TERRAIN_DEBRIS; hi = TERRAIN_VEGETATION
				TERRAIN_BLOCKED:  lo = TERRAIN_BLOCKED; hi = TERRAIN_GROUND
				_:               lo = TERRAIN_GROUND;  hi = TERRAIN_GROUND

	# Project: corners matching lo → lo, everything else → hi
	var pnw := lo if int(nw) == lo else hi
	var pne := lo if int(ne) == lo else hi
	var psw := lo if int(sw) == lo else hi
	var pse := lo if int(se) == lo else hi
	var pkey := "%d,%d,%d,%d" % [pnw, pne, psw, pse]
	if _tile_map.has(pkey):
		return _tile_map[pkey] as Vector2i

	# Final fallback: solid base tile
	if _base_tiles.has(cell_t):
		return _base_tiles[cell_t] as Vector2i
	if _base_tiles.has(TERRAIN_GROUND):
		return _base_tiles[TERRAIN_GROUND] as Vector2i
	return Vector2i.ZERO


## Get the base (all-same-corners) atlas coordinate for a terrain type.
static func base_tile(terrain_id: int) -> Vector2i:
	if _base_tiles.has(terrain_id):
		return _base_tiles[terrain_id] as Vector2i
	if _base_tiles.has(TERRAIN_GROUND):
		return _base_tiles[TERRAIN_GROUND] as Vector2i
	return Vector2i.ZERO


# ── Vertex grid ──────────────────────────────────────────────────────────

## Compute vertex terrain at grid position (vx, vy) from the 4 adjacent cells.
## Simple count-based majority without priority weights.
static func _vertex_terrain(vx: int, vy: int, size: int, terrain: PackedByteArray) -> int:
	var counts := {}
	for dy in range(-1, 1):
		for dx in range(-1, 1):
			var cx := vx + dx
			var cy := vy + dy
			if cx < 0 or cy < 0 or cx >= size or cy >= size:
				continue
			var t := _clamp_terrain(int(terrain[cy * size + cx]))
			counts[t] = counts.get(t, 0) + 1
	if counts.is_empty():
		return TERRAIN_GROUND
	var best := TERRAIN_GROUND
	var best_n := -1
	for tid in counts:
		if int(counts[tid]) > best_n:
			best_n = int(counts[tid])
			best = int(tid)
	return best


# ── Tile loading: PixelLab Wang mode ─────────────────────────────────────

static func _build_from_wang(biome_name: String, base_path: String) -> bool:
	var wang_dir := "%s/wang" % base_path
	var tile_map: Dictionary = {}   # key -> Image

	var any_found := false
	for pair in WANG_PAIRS:
		var stem: String = pair.stem
		var lo: int = pair.lower
		var hi: int = pair.upper
		var meta_path := "%s/%s_metadata.json" % [wang_dir, stem]
		var img_path := "%s/%s_image.png" % [wang_dir, stem]
		if not FileAccess.file_exists(meta_path) or not FileAccess.file_exists(img_path):
			continue
		if _ingest_pair(meta_path, img_path, lo, hi, tile_map):
			any_found = true

	# Cliff water (25-tile): only use transitional tiles — banks, not the solid water fill.
	# The solid water comes from the g_water pair. Cliff tiles add shore variety.
	var cw_meta := "%s/cliff/g_water_cliff_metadata.json" % wang_dir
	var cw_img := "%s/cliff/g_water_cliff_image.png" % wang_dir
	if FileAccess.file_exists(cw_meta) and FileAccess.file_exists(cw_img):
		_ingest_pair(cw_meta, cw_img, TERRAIN_WATER, TERRAIN_GROUND, tile_map)

	# Cliff earth → blocked when g_blocked is missing
	var solid_blocked := "%d,%d,%d,%d" % [TERRAIN_BLOCKED, TERRAIN_BLOCKED, TERRAIN_BLOCKED, TERRAIN_BLOCKED]
	if not tile_map.has(solid_blocked):
		var cl_meta := "%s/cliff/scorched_cliff_metadata.json" % wang_dir
		var cl_img := "%s/cliff/scorched_cliff_image.png" % wang_dir
		if FileAccess.file_exists(cl_meta) and FileAccess.file_exists(cl_img):
			_ingest_pair(cl_meta, cl_img, TERRAIN_BLOCKED, TERRAIN_GROUND, tile_map)

	if not any_found:
		return false

	_pack_atlas(tile_map, biome_name)
	return true


static func _ingest_pair(meta_path: String, img_path: String, lo: int, hi: int, tile_map: Dictionary) -> bool:
	var meta := _load_json(meta_path)
	if meta.is_empty():
		return false
	var sheet := _load_image(img_path)
	if sheet == null:
		return false

	var td: Dictionary = meta.get("tileset_data", {})
	var tiles: Array = td.get("tiles", [])
	if tiles.is_empty():
		return false

	var ok := false
	for t in tiles:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		var corners: Dictionary = t.get("corners", {})
		var bb: Dictionary = t.get("bounding_box", {})
		if corners.is_empty() or bb.is_empty():
			continue

		var nw := _label_to_terrain(corners.get("NW", "lower"), lo, hi)
		var ne := _label_to_terrain(corners.get("NE", "lower"), lo, hi)
		var sw := _label_to_terrain(corners.get("SW", "lower"), lo, hi)
		var se := _label_to_terrain(corners.get("SE", "lower"), lo, hi)

		var key := "%d,%d,%d,%d" % [nw, ne, sw, se]
		if tile_map.has(key):
			continue  # first-pair wins — primary overrides later pairs

		var bx := int(bb.get("x", 0))
		var by := int(bb.get("y", 0))
		var bw := int(bb.get("width", CELL_SIZE))
		var bh := int(bb.get("height", CELL_SIZE))
		if bx + bw > sheet.get_width() or by + bh > sheet.get_height():
			continue

		var cell := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
		cell.blit_rect(sheet, Rect2i(bx, by, bw, bh), Vector2i.ZERO)
		if bw != CELL_SIZE or bh != CELL_SIZE:
			cell.resize(CELL_SIZE, CELL_SIZE, Image.INTERPOLATE_LANCZOS)
		tile_map[key] = cell
		ok = true
	return ok


## Map PixelLab corner label to terrain ID.
## "upper" → hi terrain, everything else (lower/transition) → lo terrain.
static func _label_to_terrain(label, lo: int, hi: int) -> int:
	match str(label).to_lower():
		"upper": return hi
		_: return lo


# ── Tile loading: ground_64 fallback mode ────────────────────────────────

static func _build_from_ground64(base_path: String) -> bool:
	var path := "%s/ground_64.png" % base_path
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		return false

	var img := _load_image(path)
	if img == null:
		return false

	# Use the single ground_64 as the universal tile for every terrain type.
	# This produces solid-color floors — no edge transitions — but lets the
	# biome render until full Wang data arrives.
	var tile_map: Dictionary = {}
	for tid in TERRAIN_NAMES.size():
		var key := "%d,%d,%d,%d" % [tid, tid, tid, tid]
		var cell := Image.create(CELL_SIZE, CELL_SIZE, false, Image.FORMAT_RGBA8)
		cell.blit_rect(img, Rect2i(0, 0, min(CELL_SIZE, img.get_width()), min(CELL_SIZE, img.get_height())), Vector2i.ZERO)
		if img.get_width() < CELL_SIZE or img.get_height() < CELL_SIZE:
			cell.resize(CELL_SIZE, CELL_SIZE, Image.INTERPOLATE_NEAREST)
		tile_map[key] = cell

	_pack_atlas(tile_map, "fallback")
	return true


# ── Atlas packing ────────────────────────────────────────────────────────

static func _pack_atlas(tile_map: Dictionary, biome_name: String) -> void:
	_tile_map.clear()
	_base_tiles.clear()

	var keys: Array = tile_map.keys()
	keys.sort()
	var cols := 8
	var rows := maxi(1, int(ceili(float(keys.size()) / float(cols))))
	var atlas_img := Image.create(cols * CELL_SIZE, rows * CELL_SIZE, false, Image.FORMAT_RGBA8)

	for i in keys.size():
		var key: String = keys[i]
		var img: Image = tile_map[key]
		var cx := i % cols
		var cy := int(i / cols)
		atlas_img.blit_rect(img, Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(cx * CELL_SIZE, cy * CELL_SIZE))
		var ac := Vector2i(cx, cy)
		_tile_map[key] = ac

		var parts := key.split(",")
		if parts.size() == 4:
			var a := int(parts[0])
			var b := int(parts[1])
			var c := int(parts[2])
			var d := int(parts[3])
			if a == b and b == c and c == d:
				if not _base_tiles.has(a):
					_base_tiles[a] = ac

	var tex := ImageTexture.create_from_image(atlas_img)
	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)
	for i in keys.size():
		source.create_tile(Vector2i(i % cols, int(i / cols)))

	_tileset = TileSet.new()
	_tileset.tile_size = Vector2i(CELL_SIZE, CELL_SIZE)
	_tileset.add_source(source, 0)


# ── Helpers ──────────────────────────────────────────────────────────────

static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data


static func _load_image(path: String) -> Image:
	var img := Image.new()
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		if img.load(abs_path) == OK:
			return img
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res.get_image()
	return null


static func _clamp_terrain(t: int) -> int:
	if t < TERRAIN_GROUND or t > TERRAIN_WATER:
		return TERRAIN_GROUND
	return t


static func _clear() -> void:
	_tile_map.clear()
	_base_tiles.clear()
	_tileset = null
	_using_wang = false
