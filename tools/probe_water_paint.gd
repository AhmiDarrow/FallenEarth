extends SceneTree

func _init():
	var TerrainSys = load("res://scripts/terrain/TerrainSystem.gd")
	var ts = TerrainSys.tileset_for_biome("Scorched Plains")
	var ac = TerrainSys.base_tile(TerrainSys.TERRAIN_WATER)
	print("base_water=", ac, " base_ground=", TerrainSys.base_tile(TerrainSys.TERRAIN_GROUND))
	var size := 8
	var terrain := PackedByteArray()
	terrain.resize(size * size)
	for i in size * size:
		terrain[i] = 0
	for y in range(2, 6):
		for x in range(2, 6):
			terrain[y * size + x] = 4
	var vs := size + 1
	var verts := PackedByteArray()
	verts.resize(vs * vs)
	for vy in vs:
		for vx in vs:
			verts[vy * vs + vx] = _vertex(vx, vy, size, terrain)
	var bw: Vector2i = TerrainSys.base_tile(4)
	var bg: Vector2i = TerrainSys.base_tile(0)
	var grass_on_water := 0; var water_on_water := 0
	for y in size:
		for x in size:
			var cell_t := int(terrain[y * size + x])
			if cell_t != 4: continue
			var nw := int(verts[y * vs + x])
			var ne := int(verts[y * vs + x + 1])
			var sw := int(verts[(y + 1) * vs + x])
			var se := int(verts[(y + 1) * vs + x + 1])
			var ac2: Vector2i = TerrainSys.resolve_tile(cell_t, nw, ne, sw, se)
			print("W cell(%d,%d) ac=%s" % [x, y, ac2])
			if ac2 == bg: grass_on_water += 1
			else: water_on_water += 1
	print("grass_on_water=", grass_on_water, " water_on_water=", water_on_water)
	quit()

func _vertex(vx: int, vy: int, size: int, terrain: PackedByteArray) -> int:
	var counts := {}
	for dy in range(-1, 1):
		for dx in range(-1, 1):
			var cx: int = vx + dx; var cy: int = vy + dy
			if cx < 0 or cy < 0 or cx >= size or cy >= size: continue
			var t := int(terrain[cy * size + cx])
			counts[t] = int(counts.get(t, 0)) + 1
	if counts.is_empty(): return 0
	var best := 0; var best_n := -1
	for t in counts.keys():
		if int(counts[t]) > best_n:
			best_n = int(counts[t]); best = int(t)
	return best
