extends SceneTree

const TerrainSys = preload("res://scripts/terrain/TerrainSystem.gd")

func _init() -> void:
	TerrainSys.tileset_for_biome("Scorched Plains")
	var ac: Vector2i = TerrainSys.base_tile(TerrainSys.TERRAIN_WATER)
	print("water_base=", ac)
	var ts := TerrainSys.tileset_for_biome("Scorched Plains")
	if ts == null:
		print("FAIL: tileset null")
		quit(1)
	var src := ts.get_source(0) as TileSetAtlasSource
	var tex := src.texture
	var img: Image = tex.get_image()
	print("runtime_atlas=", img.get_width(), "x", img.get_height(), " rows=", img.get_height()/TerrainSys.CELL_SIZE)
	var cell := img.get_region(Rect2i(ac.x * TerrainSys.CELL_SIZE, ac.y * TerrainSys.CELL_SIZE, TerrainSys.CELL_SIZE, TerrainSys.CELL_SIZE))
	cell.save_png("user://debug_water_runtime.png")
	img.save_png("user://debug_atlas_runtime.png")
	var sum_r := 0; var sum_g := 0; var sum_b := 0; var n := 0
	for y in TerrainSys.CELL_SIZE:
		for x in TerrainSys.CELL_SIZE:
			var p := cell.get_pixel(x, y)
			sum_r += int(p.r * 255); sum_g += int(p.g * 255); sum_b += int(p.b * 255); n += 1
	print("water_mean=", sum_r/n, ",", sum_g/n, ",", sum_b/n)
	var ac2: Vector2i = TerrainSys.resolve_tile(4, 4,4,4,4)
	print("corner_4444=", ac2, " same=", ac2==ac)
	quit(0)
