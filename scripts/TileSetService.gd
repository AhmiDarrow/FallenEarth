## TileSetService — Builds native Godot 4.3 TileSet resources for local map rendering.
##
## One TileSet per biome. Each TileSet has a single TileSetAtlasSource whose atlas is
## a vertical strip of 4 terrain tiles (ground / debris / vegetation / blocked),
## each 24x24 px. The blocked tile carries a full-cell collision polygon so the player
## can't walk through it. No procedural drawing — all visuals come from
## res://assets/tilesets/{biome_dir}/{terrain}.png.
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
## or any required tile is missing. Atlas: 24x96 px (1 column, 4 rows).
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
		# Convert to RGBA8 explicitly so every tile matches the atlas format.
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		img.resize(CELL_SIZE, CELL_SIZE, Image.INTERPOLATE_NEAREST)
		loaded.append(img)

	var atlas_img := Image.create(CELL_SIZE, CELL_SIZE * loaded.size(), false, Image.FORMAT_RGBA8)
	for i in loaded.size():
		atlas_img.blit_rect(
			loaded[i],
			Rect2i(0, 0, CELL_SIZE, CELL_SIZE),
			Vector2i(0, i * CELL_SIZE),
		)

	var atlas_tex := ImageTexture.create_from_image(atlas_img)
	var source := TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)
	source.create_tile(Vector2i(0, 0))  # ground
	source.create_tile(Vector2i(0, 1))  # debris
	source.create_tile(Vector2i(0, 2))  # vegetation
	source.create_tile(Vector2i(0, 3))  # blocked — collision below

	var ts := TileSet.new()
	ts.tile_size = Vector2i(CELL_SIZE, CELL_SIZE)
	# Physics layer must exist on the TileSet BEFORE the source is added, so
	# that the BLOCKED tile's TileData inherits the layer count and accepts
	# the collision polygon below.
	ts.add_physics_layer()
	ts.add_source(source)

	# Source is now part of the tileset — physics layer count is reflected
	# onto the BLOCKED tile's TileData.
	var blocked_data: TileData = source.get_tile_data(Vector2i(0, TERRAIN_BLOCKED), 0)
	if blocked_data != null:
		blocked_data.add_collision_polygon(0)
		blocked_data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(0, 0),
			Vector2(CELL_SIZE, 0),
			Vector2(CELL_SIZE, CELL_SIZE),
			Vector2(0, CELL_SIZE),
		]))

	return ts


## Returns the cell coords inside a biome's atlas for a given terrain type.
static func atlas_coords(terrain: int) -> Vector2i:
	return Vector2i(0, terrain)
