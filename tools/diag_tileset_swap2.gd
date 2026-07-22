extends SceneTree

const TerrainSys = preload("res://scripts/terrain/TerrainSystem.gd")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")

func _init() -> void:
	var ts: TileSet = TerrainSys.tileset_for_biome("Scorched Plains")
	var src := ts.get_source(0) as TileSetAtlasSource
	var img: Image = src.texture.get_image()

	# Reverse-map atlas coords → keys via resolve of all solid combos is hard;
	# instead inspect painted cells in the "lava band" north of player.
	var biome_tile := {"name": "Scorched Plains", "elevation": 0.5, "rainfall": 0.5, "rift_chance": 0.25}
	var md: Dictionary = LocalMapGen.generate("test", 428, 0, biome_tile)
	var t: PackedByteArray = md.terrain
	var sz: int = int(md.size)
	var layer := TileMapLayer.new()
	TerrainSys.paint_terrain(layer, t, sz)

	# Screenshot: big cracked field is above the grey path / cliffs.
	# Sample a horizontal band y=80..140 (north) and y=200..260 (player).
	for band in [{"name": "north_lava", "y0": 60, "y1": 140}, {"name": "player", "y0": 200, "y1": 260}]:
		var counts := {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
		var rgb := {0: Vector3.ZERO, 1: Vector3.ZERO, 2: Vector3.ZERO, 3: Vector3.ZERO, 4: Vector3.ZERO}
		var ac_hist: Dictionary = {}
		for y in range(band.y0, band.y1):
			for x in range(180, 300):
				var tid := int(t[y * sz + x])
				counts[tid] = int(counts[tid]) + 1
				var ac: Vector2i = layer.get_cell_atlas_coords(Vector2i(x, y))
				var m := _mean(img, ac)
				rgb[tid] = rgb[tid] + m
				var ak := "%d,%d" % [ac.x, ac.y]
				if not ac_hist.has(ak):
					ac_hist[ak] = {"n": 0, "tid_counts": {}, "rgb": m}
				ac_hist[ak]["n"] = int(ac_hist[ak]["n"]) + 1
				var tc: Dictionary = ac_hist[ak]["tid_counts"]
				tc[tid] = int(tc.get(tid, 0)) + 1
		print("=== BAND ", band.name, " ===")
		for tid in range(5):
			var n: int = int(counts[tid])
			if n == 0:
				continue
			var avg: Vector3 = rgb[tid] / float(n)
			print(" tid=", tid, " n=", n, " rgb=", avg, " cool=", avg.z - (avg.x + avg.y) * 0.5)
		# top atlas coords by frequency
		var items: Array = ac_hist.keys()
		items.sort_custom(func(a, b): return int(ac_hist[a]["n"]) > int(ac_hist[b]["n"]))
		for i in mini(8, items.size()):
			var k: String = items[i]
			var info: Dictionary = ac_hist[k]
			print("  ac=", k, " n=", info.n, " tids=", info.tid_counts, " rgb=", info.rgb)

	# What is atlas (1,1)? Sample neighbors of a water cell that used it
	print("=== ATLAS SWATCHES ===")
	for ac in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(5, 2), Vector2i(5, 3), Vector2i(4, 7), Vector2i(3, 7), Vector2i(5, 6), Vector2i(3, 0)]:
		_save_swatch(img, ac)

	# Check g_water pair: are lower/upper swapped in art vs labels?
	# Extract solid lower and solid upper from source sheet via metadata
	var meta := _load_json("res://assets/tilesets/scorched_plains/wang/g_water_metadata.json")
	var sheet := Image.new()
	sheet.load(ProjectSettings.globalize_path("res://assets/tilesets/scorched_plains/wang/g_water_image.png"))
	print("=== G_WATER SOURCE SOLIDS ===")
	for tile in meta.get("tileset_data", {}).get("tiles", []):
		var c: Dictionary = tile.get("corners", {})
		var vals := [str(c.get("NW")), str(c.get("NE")), str(c.get("SW")), str(c.get("SE"))]
		var all_same: bool = vals[0] == vals[1] and vals[1] == vals[2] and vals[2] == vals[3]
		if not all_same:
			continue
		var bb: Dictionary = tile.get("bounding_box", {})
		var cell := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		cell.blit_rect(sheet, Rect2i(int(bb.x), int(bb.y), int(bb.width), int(bb.height)), Vector2i.ZERO)
		var s := _mean_img(cell)
		print(" corners=", vals[0], " bb=", bb.x, ",", bb.y, " rgb=", s, " cool=", s.z - (s.x + s.y) * 0.5)

	var pmeta := _load_json("res://assets/tilesets/scorched_plains/wang/primary_metadata.json")
	var psheet := Image.new()
	psheet.load(ProjectSettings.globalize_path("res://assets/tilesets/scorched_plains/wang/primary_image.png"))
	print("=== PRIMARY SOURCE SOLIDS ===")
	for tile in pmeta.get("tileset_data", {}).get("tiles", []):
		var c2: Dictionary = tile.get("corners", {})
		var vals2 := [str(c2.get("NW")), str(c2.get("NE")), str(c2.get("SW")), str(c2.get("SE"))]
		var all_same2: bool = vals2[0] == vals2[1] and vals2[1] == vals2[2] and vals2[2] == vals2[3]
		if not all_same2:
			continue
		var bb2: Dictionary = tile.get("bounding_box", {})
		var cell2 := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		cell2.blit_rect(psheet, Rect2i(int(bb2.x), int(bb2.y), int(bb2.width), int(bb2.height)), Vector2i.ZERO)
		var s2 := _mean_img(cell2)
		print(" corners=", vals2[0], " bb=", bb2.x, ",", bb2.y, " rgb=", s2, " cool=", s2.z - (s2.x + s2.y) * 0.5)

	# Cliff water solids
	var cmeta_path := "res://assets/tilesets/scorched_plains/wang/cliff/g_water_cliff_metadata.json"
	if FileAccess.file_exists(cmeta_path):
		var cmeta := _load_json(cmeta_path)
		var csheet := Image.new()
		csheet.load(ProjectSettings.globalize_path("res://assets/tilesets/scorched_plains/wang/cliff/g_water_cliff_image.png"))
		print("=== CLIFF WATER SOURCE SOLIDS ===")
		for tile3 in cmeta.get("tileset_data", {}).get("tiles", []):
			var c3: Dictionary = tile3.get("corners", {})
			var vals3 := [str(c3.get("NW")), str(c3.get("NE")), str(c3.get("SW")), str(c3.get("SE"))]
			var all_same3: bool = vals3[0] == vals3[1] and vals3[1] == vals3[2] and vals3[2] == vals3[3]
			if not all_same3:
				continue
			var bb3: Dictionary = tile3.get("bounding_box", {})
			var cell3 := Image.create(64, 64, false, Image.FORMAT_RGBA8)
			if int(bb3.width) != 64 or int(bb3.height) != 64:
				var tmp := Image.create(int(bb3.width), int(bb3.height), false, Image.FORMAT_RGBA8)
				tmp.blit_rect(csheet, Rect2i(int(bb3.x), int(bb3.y), int(bb3.width), int(bb3.height)), Vector2i.ZERO)
				tmp.resize(64, 64)
				cell3 = tmp
			else:
				cell3.blit_rect(csheet, Rect2i(int(bb3.x), int(bb3.y), 64, 64), Vector2i.ZERO)
			var s3 := _mean_img(cell3)
			print(" corners=", vals3[0], " bb=", bb3.x, ",", bb3.y, " rgb=", s3, " cool=", s3.z - (s3.x + s3.y) * 0.5)

	quit(0)


func _save_swatch(img: Image, ac: Vector2i) -> void:
	var cell := img.get_region(Rect2i(ac.x * 64, ac.y * 64, 64, 64))
	cell.save_png("user://swatch_%d_%d.png" % [ac.x, ac.y])
	var m := _mean_img(cell)
	print("swatch ", ac, " rgb=", m, " cool=", m.z - (m.x + m.y) * 0.5)


func _mean(img: Image, ac: Vector2i) -> Vector3:
	return _mean_img(img.get_region(Rect2i(ac.x * 64, ac.y * 64, 64, 64)))


func _mean_img(cell: Image) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for y in cell.get_height():
		for x in cell.get_width():
			var c := cell.get_pixel(x, y)
			if c.a < 0.5:
				continue
			sum += Vector3(c.r, c.g, c.b)
			n += 1
	if n > 0:
		sum /= float(n)
	return sum


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if typeof(d) == TYPE_DICTIONARY else {}
