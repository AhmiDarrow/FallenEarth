extends SceneTree

func _init() -> void:
	var TerrainSys = load("res://scripts/terrain/TerrainSystem.gd")
	var LocalMapGen = load("res://scripts/LocalMapGenerator.gd")
	var biome_tile := {"name": "Scorched Plains", "elevation": 0.5, "rainfall": 0.5, "rift_chance": 0.25}
	var md: Dictionary = LocalMapGen.generate("test", 428, 0, biome_tile)
	var terrain: PackedByteArray = md.terrain
	var size: int = int(md.size)
	var ts: TileSet = TerrainSys.tileset_for_biome("Scorched Plains")
	var layer := TileMapLayer.new()
	layer.tile_set = ts
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	TerrainSys.paint_terrain(layer, terrain, size)

	var cx := 231; var cy := 234
	var water_cells: Array[Vector2i] = []
	for y in size:
		for x in size:
			if int(terrain[y * size + x]) == 4:
				water_cells.append(Vector2i(x, y))

	var w_ok := 0; var w_bad := 0; var sample_acs := {}
	for c in water_cells:
		if absi(c.x - cx) > 15 or absi(c.y - cy) > 15: continue
		var ac: Vector2i = layer.get_cell_atlas_coords(c)
		var k := str(ac)
		sample_acs[k] = int(sample_acs.get(k, 0)) + 1
		if ac == TerrainSys.base_tile(0): w_bad += 1
		else: w_ok += 1
	print("near water cluster painted ok=", w_ok, " ground_atlas=", w_bad)
	print("atlas hist ", sample_acs)

	var src: TileSetAtlasSource = ts.get_source(0) as TileSetAtlasSource
	var atlas_img: Image = src.texture.get_image()
	var cs := 64
	var out_w := 20 * cs; var out_h := 20 * cs
	var out := Image.create(out_w, out_h, false, Image.FORMAT_RGBA8)
	var ox0 := cx - 10; var oy0 := cy - 10
	for y in 20:
		for x in 20:
			var mx := ox0 + x; var my := oy0 + y
			var ac2: Vector2i = layer.get_cell_atlas_coords(Vector2i(mx, my))
			out.blit_rect(atlas_img, Rect2i(ac2.x * cs, ac2.y * cs, cs, cs), Vector2i(x * cs, y * cs))
	out.save_png("user://debug_water_region.png")
	print("saved ", ProjectSettings.globalize_path("user://debug_water_region.png"))
	quit()
