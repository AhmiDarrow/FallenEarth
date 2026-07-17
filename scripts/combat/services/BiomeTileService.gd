class_name BiomeTileService
extends RefCounted
## Loads and caches per-biome tile textures for the combat grid.
##
## Maps biome name → tileset folder → texture resources.
## Falls back to flat colors if textures are missing.

const TILESET_ROOT: String = "res://assets/tilesets/"
const TERRAIN_FILES: Dictionary = {
	0: "ground.png",
	1: "vegetation.png",
	2: "debris.png",
	3: "blocked.png",
}

## Cache: { biome_slug: { terrain_kind: Texture2D } }
var _cache: Dictionary = {}

## Biome → slug mapping
const BIOME_SLUGS: Dictionary = {
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


func get_biome_slug(biome_name: String) -> String:
	return BIOME_SLUGS.get(biome_name, "ash_wastes")


func get_tile_texture(biome_name: String, terrain_kind: int) -> Texture2D:
	var slug: String = get_biome_slug(biome_name)
	if _cache.has(slug) and _cache[slug].has(terrain_kind):
		return _cache[slug][terrain_kind]

	var textures: Dictionary = _load_biome_textures(slug)
	if not _cache.has(slug):
		_cache[slug] = {}
	for k in textures:
		_cache[slug][k] = textures[k]
	return _cache[slug].get(terrain_kind, null)


func _load_biome_textures(slug: String) -> Dictionary:
	var result: Dictionary = {}
	var folder: String = TILESET_ROOT + slug + "/"
	for terrain_kind in TERRAIN_FILES:
		var file: String = TERRAIN_FILES[terrain_kind]
		var path: String = folder + file
		if ResourceLoader.exists(path):
			result[terrain_kind] = load(path)
	return result


func get_biome_background_path(biome_name: String) -> String:
	var slug: String = get_biome_slug(biome_name)
	return "res://assets/backgrounds/bg_%s.png" % slug


func get_biome_light_color(biome_name: String) -> Color:
	match get_biome_slug(biome_name):
		"ash_wastes": return Color(0.7, 0.55, 0.45)
		"rust_canyons": return Color(0.8, 0.6, 0.4)
		"neon_bogs": return Color(0.5, 0.7, 0.8)
		"scorched_plains": return Color(1.0, 0.85, 0.6)
		"ironwood_thicket": return Color(0.55, 0.65, 0.55)
		"glass_dunes": return Color(0.85, 0.9, 0.95)
		"corpse_fields": return Color(0.75, 0.7, 0.65)
		"stormspire_highlands": return Color(0.6, 0.65, 0.8)
		"toxin_marshes": return Color(0.5, 0.7, 0.55)
		"dead_city_outskirts": return Color(0.5, 0.45, 0.55)
		_: return Color(0.8, 0.8, 0.85)


func get_biome_ambient_color(biome_name: String) -> Color:
	match get_biome_slug(biome_name):
		"ash_wastes": return Color(0.25, 0.2, 0.18)
		"rust_canyons": return Color(0.3, 0.22, 0.15)
		"neon_bogs": return Color(0.15, 0.25, 0.3)
		"scorched_plains": return Color(0.4, 0.35, 0.25)
		"ironwood_thicket": return Color(0.18, 0.22, 0.18)
		"glass_dunes": return Color(0.3, 0.35, 0.4)
		"corpse_fields": return Color(0.25, 0.22, 0.2)
		"stormspire_highlands": return Color(0.2, 0.22, 0.3)
		"toxin_marshes": return Color(0.15, 0.22, 0.18)
		"dead_city_outskirts": return Color(0.15, 0.12, 0.18)
		_: return Color(0.15, 0.15, 0.2)

