## BiomeTilesetManager — Loads Pixellab Wang tilesets for each biome.
## Autoload singleton. Provides tile textures to LocalMapRenderer.
class_name BiomeTilesetManager
extends Node

# Preloaded tile textures: { "Ash Wastes": {0: Tex2D, 1: Tex2D, ... 15: Tex2D} }
var _tilesets: Dictionary = {}

# Biome display name → directory name
const BIOME_DIR_MAP := {
	"Ash Wastes": "ash_wastes",
	"Rust Canyons": "rust_canyons",
	"Neon Bogs": "neon_bogs",
	"Scorched Plains": "scorched_plains",
	"Ironwood Thicket": "ironwood_thicket",
	"Glass Dunes": "glass_dunes",
	"Corpse Fields": "corpse_fields",
	"Stormspire Highlands": "stormspire_highlands",
	"Toxin Marshes": "toxin_marshes",
	"Dead City Outskirts": "dead_city_outskirts",
}


func _ready() -> void:
	_load_all_tilesets()


func _load_all_tilesets() -> void:
	for biome_name in BIOME_DIR_MAP:
		var dir_name: String = BIOME_DIR_MAP[biome_name]
		var base_path := "res://assets/tilesets/%s" % dir_name
		var tiles: Dictionary = {}
		for i in 16:
			var path := "%s/wang_%d.png" % [base_path, i]
			if ResourceLoader.exists(path):
				tiles[i] = load(path)
		if tiles.size() == 16:
			_tilesets[biome_name] = tiles
		else:
			push_warning("[BiomeTilesetManager] Incomplete tileset for %s (%d/16)" % [biome_name, tiles.size()])
	print("[BiomeTilesetManager] Loaded %d biome tilesets." % _tilesets.size())


func has_tileset(biome_name: String) -> bool:
	return _tilesets.has(biome_name)


func get_tile(biome_name: String, wang_id: int) -> Texture2D:
	var ts: Dictionary = _tilesets.get(biome_name, {})
	return ts.get(wang_id, null)


static func compute_wang_id(terrain: int, n: int, e: int, s: int, w: int) -> int:
	var nw_id: int = 8 if (n == terrain and w == terrain) else 0
	var ne_id: int = 4 if (n == terrain and e == terrain) else 0
	var sw_id: int = 2 if (s == terrain and w == terrain) else 0
	var se_id: int = 1 if (s == terrain and e == terrain) else 0
	return nw_id | ne_id | sw_id | se_id
