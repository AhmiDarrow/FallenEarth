## TileSetFactory — Builds native Godot TileSet resources for local map rendering.
## Creates TileSet with Wang tile atlas (auto-tiling) and biome-specific terrain tiles.
class_name TileSetFactory
extends RefCounted

const CELL_SIZE := 24
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")
const BiomeTilesetMgr = preload("res://scripts/BiomeTilesetManager.gd")

# Terrain atlas layout: row 0=GROUND, 1=DEBRIS, 2=VEGETATION, 3=BLOCKED, 4=RIFT_SCAR
const TERRAIN_ATLAS_ROWS := 5

class TileSetData:
	var tileset: TileSet
	var wang_source_id: int = -1
	var terrain_source_id: int = -1


static func create_for_biome(biome_name: String) -> TileSetData:
	var data := TileSetData.new()
	var ts := TileSet.new()
	ts.tile_size = Vector2i(CELL_SIZE, CELL_SIZE)

	var wang_source := _create_wang_atlas_source(biome_name)
	if wang_source:
		data.wang_source_id = ts.add_source(wang_source)
		print("[TileSetFactory] Wang source created for %s" % biome_name)
	else:
		print("[TileSetFactory] Wang source FAILED for %s" % biome_name)

	var terrain_source := _create_terrain_atlas_source(biome_name)
	data.terrain_source_id = ts.add_source(terrain_source)
	print("[TileSetFactory] Terrain source created for %s (ID: %d)" % [biome_name, data.terrain_source_id])

	data.tileset = ts
	print("[TileSetFactory] TileSet created: tile_size=%s, sources=%d" % [ts.tile_size, ts.get_source_count()])
	return data


static func _create_wang_atlas_source(biome_name: String) -> TileSetAtlasSource:
	var biome_dir: String = BiomeTilesetMgr.BIOME_DIR_MAP.get(biome_name, "")
	if biome_dir.is_empty():
		return null

	var base_path := "res://assets/tilesets/%s" % biome_dir

	for i in 16:
		var path := "%s/wang_%d.png" % [base_path, i]
		if not ResourceLoader.exists(path):
			return null

	var atlas_size := CELL_SIZE * 4
	var atlas_img := Image.create(atlas_size, atlas_size, false, Image.FORMAT_RGBA8)

	for i in 16:
		var path := "%s/wang_%d.png" % [base_path, i]
		var tex := load(path) as Texture2D
		var img: Image = tex.get_image()
		img.resize(CELL_SIZE, CELL_SIZE, Image.INTERPOLATE_NEAREST)

		var col := i % 4
		var row := i / 4
		atlas_img.blit_rect(img, Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(col * CELL_SIZE, row * CELL_SIZE))

	var atlas_tex := ImageTexture.create_from_image(atlas_img)

	var source := TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)

	for row in 4:
		for col in 4:
			source.create_tile(Vector2i(col, row))

	return source


static func _create_terrain_atlas_source(biome_name: String) -> TileSetAtlasSource:
	var biome_dir: String = BiomeTilesetMgr.BIOME_DIR_MAP.get(biome_name, "")
	if biome_dir.is_empty():
		print("[TileSetFactory] No biome dir for: %s, using fallback" % biome_name)
		return _create_fallback_terrain_atlas()

	var base_path := "res://assets/tilesets/%s" % biome_dir

	var ground_path := "%s/ground.png" % base_path
	var debris_path := "%s/debris.png" % base_path
	var vegetation_path := "%s/vegetation.png" % base_path
	var blocked_path := "%s/blocked.png" % base_path
	var rift_path := "%s/rift.png" % base_path

	if not ResourceLoader.exists(ground_path):
		print("[TileSetFactory] Ground tile missing for %s, using fallback" % biome_name)
		return _create_fallback_terrain_atlas()

	var atlas_width := CELL_SIZE
	var atlas_height := CELL_SIZE * TERRAIN_ATLAS_ROWS
	var atlas_img := Image.create(atlas_width, atlas_height, false, Image.FORMAT_RGBA8)

	var loaded := _load_and_place_tile(atlas_img, ground_path, 0)
	loaded = _load_and_place_tile(atlas_img, debris_path, 1) and loaded
	loaded = _load_and_place_tile(atlas_img, vegetation_path, 2) and loaded
	loaded = _load_and_place_tile(atlas_img, blocked_path, 3) and loaded
	loaded = _load_and_place_tile(atlas_img, rift_path, 4) and loaded

	if not loaded:
		print("[TileSetFactory] Failed to load some tiles for %s" % biome_name)

	var atlas_tex := ImageTexture.create_from_image(atlas_img)
	print("[TileSetFactory] Terrain atlas created: %dx%d" % [atlas_width, atlas_height])

	var source := TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)

	for row in TERRAIN_ATLAS_ROWS:
		source.create_tile(Vector2i(0, row))

	var blocked_coords := Vector2i(0, 3)
	var tile_data := source.get_tile_data(blocked_coords, 0)
	if tile_data:
		tile_data.add_collision_polygon(0)
		var points := PackedVector2Array([
			Vector2(0, 0),
			Vector2(CELL_SIZE, 0),
			Vector2(CELL_SIZE, CELL_SIZE),
			Vector2(0, CELL_SIZE),
		])
		tile_data.set_collision_polygon_points(0, 0, points)

	return source


static func _load_and_place_tile(atlas_img: Image, path: String, row: int) -> void:
	var tex := load(path) as Texture2D
	if tex:
		var img: Image = tex.get_image()
		img.resize(CELL_SIZE, CELL_SIZE, Image.INTERPOLATE_NEAREST)
		atlas_img.blit_rect(img, Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, row * CELL_SIZE))


static func _create_fallback_terrain_atlas() -> TileSetAtlasSource:
	var atlas_width := CELL_SIZE
	var atlas_height := CELL_SIZE * TERRAIN_ATLAS_ROWS
	var atlas_img := Image.create(atlas_width, atlas_height, false, Image.FORMAT_RGBA8)

	_draw_seamless_tile(atlas_img, 0, Color(0.38, 0.34, 0.30))
	_draw_seamless_tile(atlas_img, 1, Color(0.52, 0.38, 0.28))
	_draw_seamless_tile(atlas_img, 2, Color(0.20, 0.55, 0.22))
	_draw_seamless_tile(atlas_img, 3, Color(0.10, 0.09, 0.12))
	_draw_seamless_tile(atlas_img, 4, Color(0.62, 0.20, 0.78))

	var atlas_tex := ImageTexture.create_from_image(atlas_img)

	var source := TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)

	for row in TERRAIN_ATLAS_ROWS:
		source.create_tile(Vector2i(0, row))

	var blocked_coords := Vector2i(0, 3)
	var tile_data := source.get_tile_data(blocked_coords, 0)
	if tile_data:
		tile_data.add_collision_polygon(0)
		var points := PackedVector2Array([
			Vector2(0, 0),
			Vector2(CELL_SIZE, 0),
			Vector2(CELL_SIZE, CELL_SIZE),
			Vector2(0, CELL_SIZE),
		])
		tile_data.set_collision_polygon_points(0, 0, points)

	return source


static func _draw_seamless_tile(img: Image, row: int, color: Color) -> void:
	var oy := row * CELL_SIZE
	for y in CELL_SIZE:
		for x in CELL_SIZE:
			img.set_pixel(x, oy + y, color)
