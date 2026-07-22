extends SceneTree

func _init():
	var ts = load("res://scripts/terrain/TerrainSystem.gd")
	ts.tileset_for_biome("Scorched Plains")
	print("water_base=", ts.base_tile(4), " blocked=", ts.base_tile(3))
	var terrain = PackedByteArray()
	terrain.resize(512 * 512)
	terrain.fill(0)
	var mid = 256
	var idx = mid * 512 + mid
	terrain[idx] = 4
	var wb = ts.base_tile(4)
	var bb = ts.base_tile(3)
	var gb = ts.base_tile(0)
	print("water_atlas=", wb, " blocked=", bb, " ground=", gb)
	print("w cell water corners=", ts.resolve_tile(4, 4,4,4,4))
	print("w cell water+ground=", ts.resolve_tile(4, 0,4,4,4))
	quit()
