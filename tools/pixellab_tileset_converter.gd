extends SceneTree
## Offline builder: PixelLab Wang metadata+PNG pairs → Godot corner TileSet.
##
## Usage:
##   godot --headless -s tools/pixellab_tileset_converter.gd -- --biome scorched_plains
##   godot --headless -s tools/pixellab_tileset_converter.gd -- path/a_metadata.json path/a_image.png ...
##
## Output: assets/tilesets/<biome>/terrain.tres + terrain_atlas.png
## Terrain IDs are forced to 0..4 via tools/wang_biome_map.json (not free-form prompts).

## Native PixelLab tile size — match TerrainSystem.CELL_SIZE (no downscale).
const CELL := 64
const MAP_PATH := "res://tools/wang_biome_map.json"
const TERRAIN_COUNT := 5

var _biome_slug := ""
var _pair_files: Array[Dictionary] = []  # {json, png}
var _exit_code := 0


func _init() -> void:
	print("[wang-build] PixelLab → Godot terrain TileSet converter")
	if not _parse_args():
		_exit_code = 1
		quit(_exit_code)
		return
	if not _run():
		_exit_code = 1
	quit(_exit_code)


func _parse_args() -> bool:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()

	var i := 0
	while i < args.size():
		var a := str(args[i])
		if a == "--biome" and i + 1 < args.size():
			_biome_slug = str(args[i + 1]).strip_edges()
			i += 2
			continue
		if a.ends_with("_metadata.json"):
			var json_path := a
			var png_path := json_path.replace("_metadata.json", "_image.png")
			if i + 1 < args.size() and str(args[i + 1]).ends_with(".png"):
				png_path = str(args[i + 1])
				i += 1
			_pair_files.append({"json": json_path, "png": png_path})
		i += 1

	if _biome_slug.is_empty() and _pair_files.is_empty():
		print("Usage: godot --headless -s tools/pixellab_tileset_converter.gd -- --biome <slug>")
		print("   or: godot --headless -s tools/pixellab_tileset_converter.gd -- meta.json image.png ...")
		return false

	if _pair_files.is_empty() and not _biome_slug.is_empty():
		_pair_files = _discover_biome_pairs(_biome_slug)
		if _pair_files.is_empty():
			print("[wang-build] No wang pairs under assets/tilesets/%s/wang/" % _biome_slug)
			return false

	if _biome_slug.is_empty():
		# Infer biome from first path: assets/tilesets/<slug>/wang/...
		var p := str(_pair_files[0].json).replace("\\", "/")
		var marker := "/tilesets/"
		var idx := p.find(marker)
		if idx >= 0:
			var rest := p.substr(idx + marker.length())
			_biome_slug = rest.get_slice("/", 0)

	print("[wang-build] biome=%s pairs=%d" % [_biome_slug, _pair_files.size()])
	return true


func _discover_biome_pairs(slug: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var map := _load_json_dict(MAP_PATH)
	if map.is_empty():
		return out
	var wang_dir := "res://assets/tilesets/%s/wang" % slug
	for pair in map.get("pairs", []):
		var stem := str(pair.get("stem", ""))
		var json_path := "%s/%s_metadata.json" % [wang_dir, stem]
		var png_path := "%s/%s_image.png" % [wang_dir, stem]
		if FileAccess.file_exists(json_path) and FileAccess.file_exists(png_path):
			out.append({"json": json_path, "png": png_path, "stem": stem,
				"lower": str(pair.get("lower", "ground")),
				"upper": str(pair.get("upper", "debris"))})
		else:
			print("[wang-build] skip missing pair %s" % stem)
	return out


func _run() -> bool:
	var map := _load_json_dict(MAP_PATH)
	if map.is_empty():
		print("[wang-build] missing %s" % MAP_PATH)
		return false

	var id_of: Dictionary = map.get("terrain_ids", {})
	var terrain_names: Array = map.get("terrain_names", ["ground", "debris", "vegetation", "blocked", "water"])

	# tile_key "nw,ne,sw,se" (terrain ids) → Image
	var tile_images: Dictionary = {}
	var tile_size := CELL

	for pair in _pair_files:
		var json_path := str(pair.json)
		var png_path := str(pair.png)
		print("[wang-build] load %s" % json_path)
		var meta := _load_json_dict(json_path)
		if meta.is_empty():
			print("[wang-build] FAIL bad metadata %s" % json_path)
			return false
		var sheet := Image.new()
		if sheet.load(ProjectSettings.globalize_path(png_path) if png_path.begins_with("res://") else png_path) != OK:
			# try res path via FileAccess
			if not _load_image_res(png_path, sheet):
				print("[wang-build] FAIL load png %s" % png_path)
				return false

		var lower_name := str(pair.get("lower", ""))
		var upper_name := str(pair.get("upper", ""))
		if lower_name.is_empty() or upper_name.is_empty():
			lower_name = _infer_role(meta, true, id_of)
			upper_name = _infer_role(meta, false, id_of)
		# Prefer explicit stem map from wang_biome_map pairs
		var stem := str(pair.get("stem", json_path.get_file().replace("_metadata.json", "")))
		for pdef in map.get("pairs", []):
			if str(pdef.get("stem", "")) == stem:
				lower_name = str(pdef.get("lower", lower_name))
				upper_name = str(pdef.get("upper", upper_name))
				break

		if not id_of.has(lower_name) or not id_of.has(upper_name):
			print("[wang-build] FAIL unknown terrain names lower=%s upper=%s" % [lower_name, upper_name])
			return false
		var lower_id: int = int(id_of[lower_name])
		var upper_id: int = int(id_of[upper_name])

		var tsd: Dictionary = meta.get("tileset_data", meta)
		var tiles: Array = tsd.get("tiles", [])
		if tiles.size() != 16:
			print("[wang-build] FAIL %s expected 16 tiles, got %d (cliff/25 not supported)" % [stem, tiles.size()])
			return false

		var ts_size: Dictionary = tsd.get("tile_size", {})
		if ts_size.has("width"):
			tile_size = int(ts_size.width)
		if tile_size != CELL:
			print("[wang-build] WARN tile_size=%d (game CELL=%d) — will resize" % [tile_size, CELL])

		var seen := 0
		for tile in tiles:
			var corners: Dictionary = tile.get("corners", {})
			var nw := upper_id if str(corners.get("NW", "lower")) == "upper" else lower_id
			var ne := upper_id if str(corners.get("NE", "lower")) == "upper" else lower_id
			var sw := upper_id if str(corners.get("SW", "lower")) == "upper" else lower_id
			var se := upper_id if str(corners.get("SE", "lower")) == "upper" else lower_id
			var key := "%d,%d,%d,%d" % [nw, ne, sw, se]
			var bbox: Dictionary = tile.get("bounding_box", {})
			var img := _blit_bbox(sheet, bbox, tile_size)
			if img == null:
				print("[wang-build] FAIL bbox for %s" % key)
				return false
			if tile_size != CELL:
				img.resize(CELL, CELL, Image.INTERPOLATE_NEAREST)
			# First pair wins (primary) — do not let later pairs overwrite bases.
			if not tile_images.has(key):
				tile_images[key] = img
				seen += 1
		print("[wang-build]   pair %s→%s new_tiles=%d" % [lower_name, upper_name, seen])

	# Ensure pure base tiles exist for all 5 terrains (solid procedural if missing)
	var colors := _default_colors()
	for tid in TERRAIN_COUNT:
		var key := "%d,%d,%d,%d" % [tid, tid, tid, tid]
		if not tile_images.has(key):
			tile_images[key] = _solid_tile(colors[tid])
			print("[wang-build]   synthetic base terrain %d" % tid)

	if tile_images.is_empty():
		print("[wang-build] FAIL no tiles")
		return false

	var keys: Array = tile_images.keys()
	keys.sort()
	var cols := 8
	var rows := int(ceili(float(keys.size()) / float(cols)))
	var atlas := Image.create(cols * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	var placements: Array[Dictionary] = []
	for i in keys.size():
		var key: String = str(keys[i])
		var img: Image = tile_images[key]
		var cx := i % cols
		var cy := i / cols
		atlas.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(cx * CELL, cy * CELL))
		var parts := key.split(",")
		placements.append({
			"atlas": Vector2i(cx, cy),
			"nw": int(parts[0]), "ne": int(parts[1]),
			"sw": int(parts[2]), "se": int(parts[3]),
		})

	if _biome_slug.is_empty():
		_biome_slug = "combined"
	var out_dir := "res://assets/tilesets/%s" % _biome_slug
	var atlas_path := "%s/terrain_atlas.png" % out_dir
	var tres_path := "%s/terrain.tres" % out_dir

	var abs_atlas := ProjectSettings.globalize_path(atlas_path)
	DirAccess.make_dir_recursive_absolute(abs_atlas.get_base_dir())
	var err := atlas.save_png(abs_atlas)
	if err != OK:
		print("[wang-build] FAIL save atlas %s err=%s" % [atlas_path, err])
		return false
	print("[wang-build] wrote %s" % atlas_path)

	# Build TileSet resource
	var tex := ImageTexture.create_from_image(atlas)
	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(CELL, CELL)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(CELL, CELL)
	ts.add_physics_layer()
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	for tid in TERRAIN_COUNT:
		ts.add_terrain(0)
		var tname := str(terrain_names[tid]) if tid < terrain_names.size() else "t%d" % tid
		ts.set_terrain_name(0, tid, tname)
		ts.set_terrain_color(0, tid, colors[tid])

	for p in placements:
		var ac: Vector2i = p.atlas
		source.create_tile(ac)
		var td := source.get_tile_data(ac, 0)
		td.terrain_set = 0
		# Majority terrain as tile terrain id
		var counts := {}
		for c in [p.nw, p.ne, p.sw, p.se]:
			counts[c] = int(counts.get(c, 0)) + 1
		var maj := int(p.nw)
		var maj_n := 0
		for k in counts.keys():
			if int(counts[k]) > maj_n:
				maj_n = int(counts[k])
				maj = int(k)
		td.terrain = maj
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, int(p.nw))
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, int(p.ne))
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, int(p.sw))
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, int(p.se))

	ts.add_source(source, 0)

	# Collision on blocked + water base tiles (physics layer already added above)
	for p in placements:
		if int(p.nw) == int(p.ne) and int(p.ne) == int(p.sw) and int(p.sw) == int(p.se):
			var tid := int(p.nw)
			if tid == 3 or tid == 4:
				var td2 := source.get_tile_data(p.atlas, 0)
				td2.add_collision_polygon(0)
				td2.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(0, 0), Vector2(CELL, 0), Vector2(CELL, CELL), Vector2(0, CELL)
				]))

	# Prefer external atlas reference: re-save texture to disk path for .tres
	# ResourceSaver embeds ImageTexture; also write a companion load helper path.
	err = ResourceSaver.save(ts, tres_path)
	if err != OK:
		print("[wang-build] FAIL save %s err=%s" % [tres_path, err])
		return false
	print("[wang-build] wrote %s (%d tiles, %d terrains)" % [tres_path, placements.size(), TERRAIN_COUNT])
	print("[wang-build] OK")
	return true


func _infer_role(meta: Dictionary, want_lower: bool, _id_of: Dictionary) -> String:
	var md: Dictionary = meta.get("metadata", {})
	var prompts: Dictionary = md.get("terrain_prompts", {})
	var text := str(prompts.get("lower" if want_lower else "upper", "")).to_lower()
	# Fallback only — stem map is preferred
	if "water" in text or "mud" in text or "oil" in text:
		return "water"
	if "rock" in text or "stone" in text or "cliff" in text:
		return "blocked"
	if "veg" in text or "grass" in text or "moss" in text or "scrub" in text:
		return "vegetation"
	if "debris" in text or "gravel" in text or "rubble" in text or "ash" in text:
		return "debris"
	return "ground" if want_lower else "debris"


func _blit_bbox(sheet: Image, bbox: Dictionary, tile_size: int) -> Image:
	var x := int(bbox.get("x", 0))
	var y := int(bbox.get("y", 0))
	var w := int(bbox.get("width", tile_size))
	var h := int(bbox.get("height", tile_size))
	if w <= 0 or h <= 0:
		return null
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.blit_rect(sheet, Rect2i(x, y, w, h), Vector2i.ZERO)
	return img


func _load_image_res(path: String, out: Image) -> bool:
	var abs_path := path
	if path.begins_with("res://"):
		abs_path = ProjectSettings.globalize_path(path)
	return out.load(abs_path) == OK


func _solid_tile(c: Color) -> Image:
	var img := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	img.fill(c)
	# tiny noise so tiles aren't pure flat
	for y in CELL:
		for x in CELL:
			if ((x * 17 + y * 31) % 23) == 0:
				var p := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(p.r * 0.92, p.g * 0.92, p.b * 0.92, 1.0))
	return img


func _default_colors() -> Array[Color]:
	return [
		Color(0.55, 0.42, 0.28),  # ground
		Color(0.45, 0.38, 0.32),  # debris
		Color(0.35, 0.48, 0.28),  # vegetation
		Color(0.35, 0.32, 0.30),  # blocked
		Color(0.30, 0.40, 0.55),  # water
	]


func _load_json_dict(path: String) -> Dictionary:
	var abs_path := path
	if path.begins_with("res://"):
		abs_path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(abs_path):
		return {}
	var f := FileAccess.open(path if FileAccess.file_exists(path) else abs_path, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(txt) != OK:
		return {}
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data
