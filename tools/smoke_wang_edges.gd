extends SceneTree

const TerrainSys = preload("res://scripts/terrain/TerrainSystem.gd")

func _init() -> void:
	TerrainSys.tileset_for_biome("Scorched Plains")
	var size := 8
	var terrain := PackedByteArray()
	terrain.resize(size * size)
	for i in size * size:
		terrain[i] = TerrainSys.TERRAIN_GROUND
	for i in size:
		terrain[i * size + i] = TerrainSys.TERRAIN_DEBRIS
		if i + 1 < size:
			terrain[i * size + i + 1] = TerrainSys.TERRAIN_DEBRIS
	for y in range(5, 8):
		for x in range(5, 8):
			terrain[y * size + x] = TerrainSys.TERRAIN_WATER
	var solid := 0
	var edge := 0
	var edge_ok := 0
	var edge_fallback := 0
	var vs := size + 1
	var verts := PackedByteArray()
	verts.resize(vs * vs)
	for vy in vs:
		for vx in vs:
			var counts := {}
			for dy in range(-1, 1):
				for dx in range(-1, 1):
					var cx: int = vx + dx
					var cy: int = vy + dy
					if cx < 0 or cy < 0 or cx >= size or cy >= size:
						continue
					var t := int(terrain[cy * size + cx])
					counts[t] = int(counts.get(t, 0)) + 1
			var best: int = TerrainSys.TERRAIN_GROUND; var best_n := -1
			for t in counts.keys():
				if int(counts[t]) > best_n:
					best_n = int(counts[t]); best = int(t)
			verts[vy * vs + vx] = best
	for y in size:
		for x in size:
			var nw := int(verts[y * vs + x])
			var ne := int(verts[y * vs + x + 1])
			var sw := int(verts[(y + 1) * vs + x])
			var se := int(verts[(y + 1) * vs + x + 1])
			var cell_t := int(terrain[y * size + x])
			if nw == ne and ne == sw and sw == se:
				solid += 1
			else:
				edge += 1
				var ac: Vector2i = TerrainSys.resolve_tile(cell_t, nw, ne, sw, se)
				var base_g: Vector2i = TerrainSys.base_tile(TerrainSys.TERRAIN_GROUND)
				var base_w: Vector2i = TerrainSys.base_tile(TerrainSys.TERRAIN_WATER)
				var base_d: Vector2i = TerrainSys.base_tile(TerrainSys.TERRAIN_DEBRIS)
				if ac == base_g or ac == base_w or ac == base_d:
					edge_fallback += 1
					print("FALLBACK ", x, ",", y, " c=", nw, ",", ne, ",", sw, ",", se, " ac=", ac)
				else:
					edge_ok += 1
	print("synthetic solid=", solid, " edge=", edge, " ok=", edge_ok, " fallback=", edge_fallback)
	quit(0)
