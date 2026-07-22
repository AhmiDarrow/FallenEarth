extends SceneTree

const TerrainSys = preload("res://scripts/terrain/TerrainSystem.gd")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")

func _init() -> void:
	TerrainSys.tileset_for_biome("Scorched Plains")
	var ts: TileSet = TerrainSys.tileset_for_biome("Scorched Plains")
	var src := ts.get_source(0) as TileSetAtlasSource
	var img: Image = src.texture.get_image()

	var biome_tile := {"name": "Scorched Plains", "elevation": 0.5, "rainfall": 0.5, "rift_chance": 0.25}
	var md: Dictionary = LocalMapGen.generate("test", 428, 0, biome_tile)
	var t: PackedByteArray = md.terrain
	var sz: int = int(md.size)

	# Rebuild verts like paint_terrain
	var vs := sz + 1
	var verts := PackedByteArray()
	verts.resize(vs * vs)
	for vy in vs:
		for vx in vs:
			verts[vy * vs + vx] = _vertex(vx, vy, sz, t)

	var bad := 0
	var good := 0
	var samples: Array = []
	for y in range(200, 280):
		for x in range(200, 280):
			if int(t[y * sz + x]) != 4:
				continue
			var nw := int(verts[y * vs + x])
			var ne := int(verts[y * vs + x + 1])
			var sw := int(verts[(y + 1) * vs + x])
			var se := int(verts[(y + 1) * vs + x + 1])
			var ac: Vector2i = TerrainSys.resolve_tile(4, nw, ne, sw, se)
			var m := _mean(img, ac)
			var cool := m.z - (m.x + m.y) * 0.5
			if cool < 0.05:
				bad += 1
				if samples.size() < 12:
					samples.append("(%d,%d) corners=%d,%d,%d,%d ac=%s rgb=%.2f,%.2f,%.2f cool=%.2f" % [
						x, y, nw, ne, sw, se, str(ac), m.x, m.y, m.z, cool])
			else:
				good += 1
	print("water cool-good=", good, " warm-bad=", bad)
	for s in samples:
		print("  BAD ", s)

	# Full map water quality
	bad = 0
	good = 0
	var ac_hist: Dictionary = {}
	for y in sz:
		for x in sz:
			if int(t[y * sz + x]) != 4:
				continue
			var nw2 := int(verts[y * vs + x])
			var ne2 := int(verts[y * vs + x + 1])
			var sw2 := int(verts[(y + 1) * vs + x])
			var se2 := int(verts[(y + 1) * vs + x + 1])
			var ac2: Vector2i = TerrainSys.resolve_tile(4, nw2, ne2, sw2, se2)
			var m2 := _mean(img, ac2)
			var cool2 := m2.z - (m2.x + m2.y) * 0.5
			if cool2 < 0.05:
				bad += 1
			else:
				good += 1
			var ak := "%d,%d" % [ac2.x, ac2.y]
			ac_hist[ak] = int(ac_hist.get(ak, 0)) + 1
	print("FULLMAP water cool-good=", good, " warm-bad=", bad, " pct_bad=", float(bad) / float(maxi(1, good + bad)))
	var items: Array = ac_hist.keys()
	items.sort_custom(func(a, b): return int(ac_hist[a]) > int(ac_hist[b]))
	for i in mini(10, items.size()):
		var k: String = items[i]
		var ac3 := Vector2i(int(k.split(",")[0]), int(k.split(",")[1]))
		print("  ac=", k, " n=", ac_hist[k], " rgb=", _mean(img, ac3))

	# Ground should now be sand-colored (high L)
	var g_sum := Vector3.ZERO
	var g_n := 0
	for y in range(200, 280):
		for x in range(200, 280):
			if int(t[y * sz + x]) != 0:
				continue
			var acg: Vector2i = TerrainSys.resolve_tile(0,
				int(verts[y * vs + x]), int(verts[y * vs + x + 1]),
				int(verts[(y + 1) * vs + x]), int(verts[(y + 1) * vs + x + 1]))
			g_sum += _mean(img, acg)
			g_n += 1
	if g_n > 0:
		g_sum /= float(g_n)
	print("ground mean rgb=", g_sum, " lightness=", (g_sum.x + g_sum.y + g_sum.z) / 3.0)

	quit(0)


func _vertex(vx: int, vy: int, size: int, terrain: PackedByteArray) -> int:
	var counts := {}
	for dy in range(-1, 1):
		for dx in range(-1, 1):
			var cx := vx + dx
			var cy := vy + dy
			if cx < 0 or cy < 0 or cx >= size or cy >= size:
				continue
			var tt := int(terrain[cy * size + cx])
			counts[tt] = counts.get(tt, 0) + 1
	if counts.is_empty():
		return 0
	var best := 0
	var best_n := -1
	for tid in counts:
		if int(counts[tid]) > best_n:
			best_n = int(counts[tid])
			best = int(tid)
	return best


func _mean(img: Image, ac: Vector2i) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	var ox := ac.x * 64
	var oy := ac.y * 64
	for y in range(oy, oy + 64, 2):
		for x in range(ox, ox + 64, 2):
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			sum += Vector3(c.r, c.g, c.b)
			n += 1
	if n > 0:
		sum /= float(n)
	return sum
