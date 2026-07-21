class_name RiftTileSetService
extends RefCounted

const CELL_SIZE := 32
const RIFT_FLOOR := 0
const RIFT_WALL := 1
const RIFT_DECOR := 2

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

const RIFT_TERRAIN_NAMES := ["floor", "wall", "decor"]


static func biome_to_dir(biome_name: String) -> String:
	return BIOME_DIR.get(biome_name, biome_name.to_snake_case())


static func create_for_biome(biome_name: String) -> TileSet:
	var dir_name := biome_to_dir(biome_name)
	if dir_name.is_empty():
		push_error("[RiftTileSetService] Unknown biome: %s" % biome_name)
		return null

	var base_path := "res://assets/tilesets/%s" % dir_name
	var rift_path := "%s/rift.png" % base_path
	if not ResourceLoader.exists(rift_path):
		push_error("[RiftTileSetService] Missing rift tile for %s: %s" % [biome_name, rift_path])
		return null

	var rift_tex := load(rift_path) as Texture2D
	if rift_tex == null:
		return null

	var floor_img: Image = rift_tex.get_image()
	if floor_img == null:
		return null
	if floor_img.get_format() != Image.FORMAT_RGBA8:
		floor_img.convert(Image.FORMAT_RGBA8)
	floor_img.resize(CELL_SIZE, CELL_SIZE, Image.INTERPOLATE_NEAREST)

	var wall_img := Image.create(CELL_SIZE, CELL_SIZE, false, Image.FORMAT_RGBA8)
	wall_img.copy_from(floor_img)
	for x in range(CELL_SIZE):
		for y in range(CELL_SIZE):
			var c := wall_img.get_pixel(x, y)
			c.r *= 0.25
			c.g *= 0.25
			c.b *= 0.25
			wall_img.set_pixel(x, y, c)

	var decor_img := Image.create(CELL_SIZE, CELL_SIZE, false, Image.FORMAT_RGBA8)
	decor_img.copy_from(floor_img)
	for x in range(CELL_SIZE):
		for y in range(CELL_SIZE):
			var c := decor_img.get_pixel(x, y)
			c.r *= 0.85
			c.g *= 0.85
			c.b *= 0.85
			decor_img.set_pixel(x, y, c)

	var atlas_img := Image.create(CELL_SIZE, CELL_SIZE * 3, false, Image.FORMAT_RGBA8)
	atlas_img.blit_rect(floor_img, Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, 0))
	atlas_img.blit_rect(wall_img, Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, CELL_SIZE))
	atlas_img.blit_rect(decor_img, Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, CELL_SIZE * 2))

	var atlas_tex := ImageTexture.create_from_image(atlas_img)
	var source := TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)
	source.create_tile(Vector2i(0, 0))
	source.create_tile(Vector2i(0, 1))
	source.create_tile(Vector2i(0, 2))

	var ts := TileSet.new()
	ts.tile_size = Vector2i(CELL_SIZE, CELL_SIZE)
	ts.add_physics_layer()
	ts.add_source(source)

	var wall_data: TileData = source.get_tile_data(Vector2i(0, RIFT_WALL), 0)
	if wall_data != null:
		wall_data.add_collision_polygon(0)
		wall_data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(0, 0),
			Vector2(CELL_SIZE, 0),
			Vector2(CELL_SIZE, CELL_SIZE),
			Vector2(0, CELL_SIZE),
		]))

	return ts


static func atlas_coords(terrain: int) -> Vector2i:
	return Vector2i(0, terrain)
