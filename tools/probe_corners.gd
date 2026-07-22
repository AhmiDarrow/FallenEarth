extends SceneTree

func _init():
	var TerrainSys = load("res://scripts/terrain/TerrainSystem.gd")
	TerrainSys.tileset_for_biome("Scorched Plains")
	var w = 4
	var g = 0
	print("base water=", TerrainSys.base_tile(w))
	print("base ground=", TerrainSys.base_tile(g))
	print("corner WWWW=", TerrainSys.resolve_tile(w, w,w,w,w))
	print("corner GGGG=", TerrainSys.resolve_tile(g, g,g,g,g))
	print("corner WGGG=", TerrainSys.resolve_tile(w, w,g,g,g))
	print("corner WWGG=", TerrainSys.resolve_tile(w, w,w,g,g))
	print("corner WGWG=", TerrainSys.resolve_tile(w, w,g,w,g))
	print("corner BBBB blocked=", TerrainSys.resolve_tile(3, 3,3,3,3))
	print("corner BGGG=", TerrainSys.resolve_tile(g, 3,g,g,g))
	quit()
