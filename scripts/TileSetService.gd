## TileSetService — Builds native Godot 4.3 TileSet resources for local map rendering.
##
## One TileSet per biome. Each TileSet has a TileSetAtlasSource whose atlas is a
## grid of 4 terrain types × 5 tiles each (center + N/S/W/E edge variants) = 20 tiles,
## each 24×24 px. Edge variants have a 6-pixel visual band on the edge side to make
## terrain transitions look intentional rather than sharp seams. The blocked center
## tile carries a full-cell collision polygon so the player can't walk through it.
##
## As of v0.4.0 Phase 0, rift_scar is no longer a terrain type — rifts are entities
## spawned by RiftRunner and rendered as markers on the local map.
class_name TileSetService
extends RefCounted

const CELL_SIZE := 24
const TERRAIN_GROUND := 0
const TERRAIN_DEBRIS := 1
const TERRAIN_VEGETATION := 2
const TERRAIN_BLOCKED := 3

## Historical value 4 (TERRAIN_RIFT_SCAR) was removed. Legacy map_data with
## terrain[i] == 4 is normalized to TERRAIN_GROUND by LocalMapView.

const TERRAIN_NAMES := ["ground", "debris", "vegetation", "blocked"]

## Each terrain type has 5 atlas rows: 0=center (original), 1=N edge, 2=S edge, 3=W edge, 4=E edge.
## Edge bands visually mark terrain transitions when placed beside a different terrain type.
const TILES_PER_TERRAIN := 5
const EDGE_N := 1
const EDGE_S := 2
const EDGE_W := 3
const EDGE_E := 4

## Edge direction bitmask constants (matches LocalMapGenerator edge_mask bits).
const BIT_N := 1
const BIT_S := 2
const BIT_W := 4
const BIT_E := 8

const BIOME_DIR := {
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


static func biome_to_dir(biome_name: String) -> String:
	return BIOME_DIR.get(biome_name, biome_name.to_snake_case())


## Returns a fresh TileSet for the given biome, or null if the biome folder
## or any required tile is missing. Atlas: 24x120 px (1 column, 20 rows):
## 4 terrain types × 5 tiles each (center + N/S/W/E edge bands).
## Edge tiles are generated procedurally from the center tile.
static func create_for_biome(biome_name: String) -> TileSet:
	var dir_name := biome_to_dir(biome_name)
	if dir_name.is_empty():
		push_error("[TileSetService] Unknown biome: %s" % biome_name)
		return null

	var base_path := "res://assets/tilesets/%s" % dir_name
	var loaded: Array[Image] = []
	for terrain_name in TERRAIN_NAMES:
		var path := "%s/%s.png" % [base_path, terrain_name]
		if not ResourceLoader.exists(path):
			push_error("[TileSetService] Missing tile for %s: %s" % [biome_name, path])
			return null
		var tex := load(path) as Texture2D
		if tex == null:
			push_error("[TileSetService] Failed to load texture: %s" % path)
			return null
		var img: Image = tex.get_image()
		if img == null:
			push_error("[TileSetService] Texture has no Image: %s" % path)
			return null
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		img.resize(CELL_SIZE, CELL_SIZE, Image.INTERPOLATE_NEAREST)
		loaded.append(img)

	# Build atlas: 4 terrain types × 5 tiles each = 20 rows.
	# Row order per terrain: [center, N_edge, S_edge, W_edge, E_edge].
	var total_rows := loaded.size() * TILES_PER_TERRAIN
	var atlas_img := Image.create(CELL_SIZE, CELL_SIZE * total_rows, false, Image.FORMAT_RGBA8)
	for ti in loaded.size():
		var center: Image = loaded[ti]
		var base_row := ti * TILES_PER_TERRAIN
		# Center tile (original)
		atlas_img.blit_rect(center, Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, base_row * CELL_SIZE))
		# Edge tiles: 6-pixel blended band on the edge side, rest is center tile
		atlas_img.blit_rect(_make_edge_tile(center, 0, -1), Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, (base_row + EDGE_N) * CELL_SIZE))
		atlas_img.blit_rect(_make_edge_tile(center, 0, 1),  Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, (base_row + EDGE_S) * CELL_SIZE))
		atlas_img.blit_rect(_make_edge_tile(center, -1, 0), Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, (base_row + EDGE_W) * CELL_SIZE))
		atlas_img.blit_rect(_make_edge_tile(center, 1, 0),  Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, (base_row + EDGE_E) * CELL_SIZE))

	var atlas_tex := ImageTexture.create_from_image(atlas_img)
	var source := TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)
	for ti in loaded.size():
		var base_row := ti * TILES_PER_TERRAIN
		for slot in TILES_PER_TERRAIN:
			source.create_tile(Vector2i(0, base_row + slot))

	var ts := TileSet.new()
	ts.tile_size = Vector2i(CELL_SIZE, CELL_SIZE)
	ts.add_physics_layer()
	ts.add_source(source)

	# Collision on the blocked center tile (row = TERRAIN_BLOCKED * TILES_PER_TERRAIN)
	var blocked_center_row := TERRAIN_BLOCKED * TILES_PER_TERRAIN
	var blocked_data: TileData = source.get_tile_data(Vector2i(0, blocked_center_row), 0)
	if blocked_data != null:
		blocked_data.add_collision_polygon(0)
		blocked_data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(0, 0),
			Vector2(CELL_SIZE, 0),
			Vector2(CELL_SIZE, CELL_SIZE),
			Vector2(0, CELL_SIZE),
		]))

	return ts


## Generate an edge-variant tile by darkening a 6px band along one side.
## dx/dy indicates the edge direction: (0,-1)=N, (0,1)=S, (-1,0)=W, (1,0)=E.
static func _make_edge_tile(src: Image, dx: int, dy: int) -> Image:
	var out := Image.create(CELL_SIZE, CELL_SIZE, false, Image.FORMAT_RGBA8)
	out.blit_rect(src, Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, 0))
	var band := 6
	for py in CELL_SIZE:
		for px in CELL_SIZE:
			var edge_dist := 999
			if dx != 0:
				edge_dist = abs(px - (CELL_SIZE / 2 - dx * CELL_SIZE / 2))
			elif dy != 0:
				edge_dist = abs(py - (CELL_SIZE / 2 - dy * CELL_SIZE / 2))
			if edge_dist >= band:
				continue
			var c := out.get_pixel(px, py)
			var t := float(edge_dist) / float(band)
			c.r *= 0.55 + 0.45 * t
			c.g *= 0.55 + 0.45 * t
			c.b *= 0.55 + 0.45 * t
			out.set_pixel(px, py, c)
	return out


## Returns the cell coords inside a biome's atlas for a given terrain type.
## terrain: TERRAIN_GROUND (0) through TERRAIN_BLOCKED (3).
## edge_mask: bitmask from LocalMapGenerator edge_mask (0 = center, non-zero picks edge variant).
static func atlas_coords(terrain: int, edge_mask: int = 0) -> Vector2i:
	var row := terrain * TILES_PER_TERRAIN
	# Map edge_mask bitmask to edge variant row offset
	if edge_mask & BIT_N:
		row += EDGE_N
	elif edge_mask & BIT_S:
		row += EDGE_S
	elif edge_mask & BIT_W:
		row += EDGE_W
	elif edge_mask & BIT_E:
		row += EDGE_E
	else:
		row += 0  # center
	return Vector2i(0, row)


## Legacy single-param version for callers that don't have edge_mask.
static func atlas_coords_legacy(terrain: int) -> Vector2i:
	return Vector2i(0, terrain * TILES_PER_TERRAIN)
