extends SceneTree
## Cross-biome visual coverage probe.
## Generates a map for each of the 10 biomes and verifies:
##   1. EVERY spawned entity (resource node, decor) maps to a sprite ID with
##      at least one PNG variant on disk.
##   2. NO resource node / decor is placed on a TERRAIN_WATER cell.
## Exits 0 when all biomes clean, 1 otherwise.

const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")

var biome_names := [
	"Ash Wastes",
	"Rust Canyons",
	"Neon Bogs",
	"Scorched Plains",
	"Ironwood Thicket",
	"Glass Dunes",
	"Corpse Fields",
	"Stormspire Highlands",
	"Toxin Marshes",
	"Dead City Outskirts",
]

var failures: Array[String] = []


func _has_variant(sprite_id: String) -> bool:
	if sprite_id.is_empty():
		return true
	var folders: Array[String] = [
		"res://assets/sprites/resource_nodes/",
		"res://assets/sprites/decor/",
	]
	for folder in folders:
		for i in range(16):
			var path: String = folder + "%s_%02d.png" % [sprite_id, i]
			if ResourceLoader.exists(path):
				return true
	return false


func _check_sprites(entries: Array, label: String) -> void:
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var sprite: String = str(entry.get("sprite", ""))
		if not _has_variant(sprite):
			failures.append("[%s] sprite '%s' has NO png variants" % [label, sprite])


func _check_water_placement(entries: Array, terrain: PackedByteArray, size: int, label: String) -> int:
	var on_water := 0
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var x: int = int(entry.get("x", -1))
		var y: int = int(entry.get("y", -1))
		if x < 0 or y < 0:
			continue
		var idx: int = y * size + x
		if idx < 0 or idx >= terrain.size():
			continue
		if int(terrain[idx]) == LocalMapGen.TERRAIN_WATER:
			on_water += 1
	if on_water > 0:
		failures.append("[%s] %d entities on TERRAIN_WATER cells" % [label, on_water])
	return on_water


func _initialize() -> void:
	print("[probe-biomes] cross-biome sprite + water-tile coverage")
	for biome in biome_names:
		var biome_tile := {
			"name": biome,
			"elevation": 0.5,
			"rainfall": 0.5,
			"rift_chance": 0.25,
		}
		var map_data: Dictionary = LocalMapGen.generate("probe_seed_%s" % biome.replace(" ", ""), 0, 0, biome_tile)
		var rn: Array = map_data.get("resource_nodes", [])
		var fp: Array = map_data.get("floor_pickups", [])
		var decor: Array = map_data.get("decor", [])
		var terrain: PackedByteArray = map_data.get("terrain", PackedByteArray())
		var size: int = int(map_data.get("size", LocalMapGen.MAP_SIZE))
		var total_water: int = 0
		for i in range(terrain.size()):
			if int(terrain[i]) == LocalMapGen.TERRAIN_WATER:
				total_water += 1
		_check_sprites(rn, "%s.resource_nodes" % biome)
		_check_sprites(decor, "%s.decor" % biome)
		for pick in fp:
			var iid: String = str(pick.get("id", ""))
			if not ResourceLoader.exists("res://assets/sprites/items/%s.png" % iid):
				failures.append("[%s.floor_pickup] item '%s' has no png" % [biome, iid])
		var rn_water: int = _check_water_placement(rn, terrain, size, "%s.resource_nodes" % biome)
		var dec_water: int = _check_water_placement(decor, terrain, size, "%s.decor" % biome)
		print("  %s : %d nodes (%d on water), %d pickups, %d decor (%d on water); %d/%d water tiles" %
			[biome, rn.size(), rn_water, fp.size(), decor.size(), dec_water, total_water, terrain.size()])
	if failures.is_empty():
		print("[probe-biomes] ALL biomes clean. %d biomes checked." % biome_names.size())
		quit(0)
	else:
		for f in failures:
			print("[probe-biomes] FAIL: " + f)
		print("[probe-biomes] %d failure(s)." % failures.size())
		quit(1)
