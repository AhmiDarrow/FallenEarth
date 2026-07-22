extends SceneTree
const TerrainSys = preload("res://scripts/terrain/TerrainSystem.gd")
func _init() -> void:
	var biomes := ["Ash Wastes","Rust Canyons","Neon Bogs","Scorched Plains","Ironwood Thicket","Glass Dunes","Corpse Fields","Stormspire Highlands","Toxin Marshes","Dead City Outskirts"]
	for b in biomes:
		TerrainSys.tileset_for_biome(b) # force rebuild via name change
		var ts = TerrainSys.tileset_for_biome(b)
		var wang = TerrainSys.using_wang()
		var g = TerrainSys.base_tile(0)
		var w = TerrainSys.base_tile(4)
		print("BIOME ", b, " wang=", wang, " ground=", g, " water=", w, " ts=", ts != null)
	quit(0)
