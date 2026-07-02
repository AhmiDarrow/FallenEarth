# TileSetBuilder.gd
# Provides paths and can build a basic TileSet for Ash Wastes hand-drawn tiles.
# For full hex support, configure TileMap in editor or extend.

@tool
extends Node

const BASE_PATH = "res://assets/tilesets/"
const CURATED_PATH = "res://assets/tilesets/ash_wastes/selected/"  # 40 curated proper tiles for Ash

var tile_paths = {
	"ground": [],
	"debris": [],
	"vegetation": [],
	"rift": [],
	"transition": []
}

# Biome specific curated/ground lists (expand as generated)
var biome_tile_paths: Dictionary = {}

func _ready():
	_load_paths()
	_load_all_biomes()

func _load_paths():
	for type in tile_paths:
		var dir = CURATED_PATH
		var da = DirAccess.open(dir)
		if da:
			da.list_dir_begin()
			var f = da.get_next()
			while f != "":
				if f.begins_with("ash_wastes_" + type) and f.ends_with(".png"):
					tile_paths[type].append(dir + f)
				f = da.get_next()
			da.list_dir_end()
		tile_paths[type].sort()

func _load_all_biomes():
	# Scan all biome folders for any pngs (ground/* + selected/* + root tiles)
	biome_tile_paths.clear()
	var da = DirAccess.open(BASE_PATH)
	if not da:
		return
	da.list_dir_begin()
	var bname = da.get_next()
	while bname != "":
		if da.current_is_dir() and bname != ".." and bname != ".":
			var bpath = BASE_PATH + bname + "/"
			var files = []
			# selected if present
			var sel_da = DirAccess.open(bpath + "selected")
			if sel_da:
				sel_da.list_dir_begin()
				var sf = sel_da.get_next()
				while sf != "":
					if sf.ends_with(".png"): files.append(bpath + "selected/" + sf)
					sf = sel_da.get_next()
				sel_da.list_dir_end()
			# subdirs ground etc
			for sub in ["ground", "debris", "vegetation", "rift", "transition"]:
				var sub_da = DirAccess.open(bpath + sub)
				if sub_da:
					sub_da.list_dir_begin()
					var f = sub_da.get_next()
					while f != "":
						if f.ends_with(".png"): files.append(bpath + sub + "/" + f)
						f = sub_da.get_next()
					sub_da.list_dir_end()
			# loose tiles in biome root
			var root_da = DirAccess.open(bpath)
			if root_da:
				root_da.list_dir_begin()
				var rf = root_da.get_next()
				while rf != "":
					if rf.ends_with(".png"): files.append(bpath + rf)
					rf = root_da.get_next()
				root_da.list_dir_end()
			if files.size() > 0:
				biome_tile_paths[bname.replace("_", " ").capitalize()] = files
		bname = da.get_next()
	da.list_dir_end()
	print("[TileSetBuilder] Loaded visuals for %d biomes." % biome_tile_paths.size())

func get_tile_set() -> TileSet:
	var ts = TileSet.new()
	ts.tile_size = Vector2i(512, 512)  # current generated assets are 512x512 illustrative
	# Add sources - in practice user builds atlas in editor for performance
	# Example: add first ground as demo
	if tile_paths["ground"].size() > 0:
		var src = TileSetAtlasSource.new()
		src.texture = load(tile_paths["ground"][0])
		ts.add_source(src)
	return ts

func get_random_for_biome(biome: String) -> String:
	# Normalize name e.g. "ash_wastes" or "Ash Wastes" -> "Ash Wastes"
	var key = biome.replace("_", " ").capitalize()
	if biome_tile_paths.has(key) and biome_tile_paths[key].size() > 0:
		var lst = biome_tile_paths[key]
		return lst[randi() % lst.size()]
	# Fallbacks for common aliases
	var aliases = {
		"ash_wastes": "Ash Wastes",
		"rust_canyons": "Rust Canyons",
		"neon_bogs": "Neon Bogs",
	}
	for a in aliases:
		if biome.to_lower().contains(a) and biome_tile_paths.has(aliases[a]) and biome_tile_paths[aliases[a]].size() > 0:
			var lst = biome_tile_paths[aliases[a]]
			return lst[randi() % lst.size()]
	# Any available
	for b in biome_tile_paths:
		if biome_tile_paths[b].size() > 0:
			return biome_tile_paths[b][randi() % biome_tile_paths[b].size()]
	return ""

func get_paths_for_biome(biome: String) -> Array:
	var key = biome.replace("_", " ").capitalize()
	if biome_tile_paths.has(key):
		return biome_tile_paths[key]
	return []

func axial_to_map_pos(q: int, r: int) -> Vector2i:
	# Adjust for your TileMap hex layout (e.g. odd-r offset)
	return Vector2i(q + (r + (r % 2)) / 2, r)
