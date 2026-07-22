extends SceneTree

const TerrainSys = preload("res://scripts/terrain/TerrainSystem.gd")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")

func _init() -> void:
	var ts: TileSet = TerrainSys.tileset_for_biome("Scorched Plains")
	var src := ts.get_source(0) as TileSetAtlasSource
	var img: Image = src.texture.get_image()
	img.save_png("user://diag_atlas.png")

	print("=== BASE TILES ===")
	for tid in range(5):
		var ac: Vector2i = TerrainSys.base_tile(tid)
		var mean := _mean_at(img, ac)
		print("base tid=", tid, " name=", TerrainSys.TERRAIN_NAMES[tid], " ac=", ac, " rgb=", mean)

	print("=== KEY SPOT CHECKS ===")
	for key in ["0,0,0,0", "1,1,1,1", "2,2,2,2", "3,3,3,3", "4,4,4,4", "4,4,4,0", "4,0,0,0", "0,0,0,4"]:
		var ac2: Vector2i = TerrainSys.resolve_tile(_cell_from_key(key), _p(key,0), _p(key,1), _p(key,2), _p(key,3))
		print("key=", key, " → ", ac2, " rgb=", _mean_at(img, ac2))

	# Paint a synthetic lake and dump RGB of interior vs shore
	var size := 32
	var terrain := PackedByteArray()
	terrain.resize(size * size)
	for y in size:
		for x in size:
			var dx := x - 16
			var dy := y - 16
			var d2 := dx * dx + dy * dy
			terrain[y * size + x] = TerrainSys.TERRAIN_WATER if d2 < 100 else TerrainSys.TERRAIN_GROUND

	var layer := TileMapLayer.new()
	TerrainSys.paint_terrain(layer, terrain, size)

	var interior_ac: Vector2i = layer.get_cell_atlas_coords(Vector2i(16, 16))
	var shore_ac: Vector2i = layer.get_cell_atlas_coords(Vector2i(16, 6))
	var ground_ac: Vector2i = layer.get_cell_atlas_coords(Vector2i(2, 2))
	print("=== SYNTHETIC LAKE ===")
	print("interior(16,16) ac=", interior_ac, " rgb=", _mean_at(img, interior_ac), " cool=", _cool(_mean_at(img, interior_ac)))
	print("shore(16,6) ac=", shore_ac, " rgb=", _mean_at(img, shore_ac), " cool=", _cool(_mean_at(img, shore_ac)))
	print("ground(2,2) ac=", ground_ac, " rgb=", _mean_at(img, ground_ac), " cool=", _cool(_mean_at(img, ground_ac)))

	# Real map near player coords from screenshot
	var biome_tile := {"name": "Scorched Plains", "elevation": 0.5, "rainfall": 0.5, "rift_chance": 0.25}
	var md: Dictionary = LocalMapGen.generate("test", 428, 0, biome_tile)
	var t: PackedByteArray = md.terrain
	var sz: int = int(md.size)
	var layer2 := TileMapLayer.new()
	TerrainSys.paint_terrain(layer2, t, sz)

	# Sample water cells near (228,236)
	var w_sum := Vector3.ZERO
	var w_n := 0
	var g_sum := Vector3.ZERO
	var g_n := 0
	var d_sum := Vector3.ZERO
	var d_n := 0
	for y in range(200, 280):
		for x in range(200, 280):
			var tid := int(t[y * sz + x])
			var ac: Vector2i = layer2.get_cell_atlas_coords(Vector2i(x, y))
			var m := _mean_at(img, ac)
			if tid == 4:
				w_sum += m
				w_n += 1
			elif tid == 0:
				g_sum += m
				g_n += 1
			elif tid == 1:
				d_sum += m
				d_n += 1
	if w_n > 0:
		w_sum /= float(w_n)
	if g_n > 0:
		g_sum /= float(g_n)
	if d_n > 0:
		d_sum /= float(d_n)
	print("=== REAL MAP 200-280 ===")
	print("water n=", w_n, " mean_rgb=", w_sum, " cool=", _cool(w_sum))
	print("ground n=", g_n, " mean_rgb=", g_sum, " cool=", _cool(g_sum))
	print("debris n=", d_n, " mean_rgb=", d_sum, " cool=", _cool(d_sum))

	# Flag if water is warmer than ground (lava symptom)
	var water_is_hot := w_n > 0 and w_sum.x > w_sum.z + 0.05
	var ground_is_hot := g_n > 0 and g_sum.x > g_sum.z + 0.05
	print("WATER_LOOKS_LIKE_LAVA=", water_is_hot)
	print("GROUND_LOOKS_LIKE_LAVA=", ground_is_hot)

	# Dump a few water cell atlas coords
	var shown := 0
	for y in range(200, 280):
		for x in range(200, 280):
			if int(t[y * sz + x]) != 4:
				continue
			var ac3: Vector2i = layer2.get_cell_atlas_coords(Vector2i(x, y))
			print("water_cell ", x, ",", y, " ac=", ac3, " rgb=", _mean_at(img, ac3))
			shown += 1
			if shown >= 8:
				break
		if shown >= 8:
			break

	quit(0)


func _mean_at(img: Image, ac: Vector2i) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	var ox := ac.x * TerrainSys.CELL_SIZE
	var oy := ac.y * TerrainSys.CELL_SIZE
	for y in range(oy, oy + TerrainSys.CELL_SIZE, 2):
		for x in range(ox, ox + TerrainSys.CELL_SIZE, 2):
			if x >= img.get_width() or y >= img.get_height():
				continue
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			sum += Vector3(c.r, c.g, c.b)
			n += 1
	if n > 0:
		sum /= float(n)
	return sum


func _cool(v: Vector3) -> float:
	return v.z - (v.x + v.y) * 0.5


func _p(key: String, i: int) -> int:
	return int(key.split(",")[i])


func _cell_from_key(key: String) -> int:
	var parts := key.split(",")
	# prefer water if present else first
	for p in parts:
		if int(p) == 4:
			return 4
	return int(parts[0])
