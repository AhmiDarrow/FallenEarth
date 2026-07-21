## TileSetService — Builds native Godot TileSet resources for local map rendering.
##
## One TileSet per biome. Each TileSet has a TileSetAtlasSource whose atlas is a
## grid of 5 terrain types × 5 tiles each (center + N/S/W/E edge variants) = 25 tiles,
## each 32×32 px. Edge variants have an 8-pixel visual band on the edge side to make
## terrain transitions look intentional rather than sharp seams. The blocked center
## tile carries a full-cell collision polygon so the player can't walk through it.
## Water tiles are loaded from a shared PixelLab-generated base texture and
## color-shifted per biome, with 8-frame animated flowing water.
##
## As of v0.4.0 Phase 0, rift_scar is no longer a terrain type — rifts are entities
## spawned by RiftRunner and rendered as markers on the local map.
class_name TileSetService
extends RefCounted

const CELL_SIZE := 32
const TERRAIN_GROUND := 0
const TERRAIN_DEBRIS := 1
const TERRAIN_VEGETATION := 2
const TERRAIN_BLOCKED := 3
const TERRAIN_WATER := 4

const TERRAIN_NAMES := ["ground", "debris", "vegetation", "blocked", "water"]

## Each terrain type has 5 atlas rows: 0=center (original), 1=N edge, 2=S edge, 3=W edge, 4=E edge.
## Edge bands visually mark terrain transitions when placed beside a different terrain type.
const TILES_PER_TERRAIN := 5
const EDGE_N := 1
const EDGE_S := 2
const EDGE_W := 3
const EDGE_E := 4

## Edge direction bitmask constants (matches LocalMapGenerator edge_mask bits).
const BIT_N := 1
const BIT_S := 2
const BIT_W := 4
const BIT_E := 8

## Water animation config — base texture from PixelLab, color-shifted per biome.
const WATER_ANIM_FRAMES := 8
const WATER_ANIM_FPS := 1.0
const WATER_BASE_PATH := "res://assets/tilesets/_water_base.png"

const BIOME_DIR := {
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

## Fully opaque per-biome water colors. No ground bleed-through — water tiles
## are solid with a subtle wave highlight baked in.
const BIOME_WATER_COLORS := {
	"Ash Wastes": Color(0.50, 0.55, 0.60, 1.0),
	"Rust Canyons": Color(0.75, 0.40, 0.20, 1.0),
	"Neon Bogs": Color(0.15, 0.80, 0.70, 1.0),
	"Scorched Plains": Color(0.55, 0.50, 0.30, 1.0),
	"Ironwood Thicket": Color(0.20, 0.60, 0.40, 1.0),
	"Glass Dunes": Color(0.55, 0.70, 0.90, 1.0),
	"Corpse Fields": Color(0.60, 0.25, 0.25, 1.0),
	"Stormspire Highlands": Color(0.20, 0.30, 0.75, 1.0),
	"Toxin Marshes": Color(0.45, 0.75, 0.20, 1.0),
	"Dead City Outskirts": Color(0.40, 0.45, 0.55, 1.0),
}


static func biome_to_dir(biome_name: String) -> String:
	return BIOME_DIR.get(biome_name, biome_name.to_snake_case())


## Returns a fresh TileSet for the given biome, or null if the biome folder
## or any required tile is missing. Atlas: 8×32=256 px wide, 25×32=800 px tall:
## 4 terrain types (ground/debris/vegetation/blocked) × 5 edge variants each = 20 rows
## using column 0, plus water (5 edge variants × 8 animation frames = 40 tiles in columns 0-7).
## Edge tiles are generated procedurally from the center tile.
## Water tiles are loaded from a shared PixelLab base texture and color-shifted per biome.
static func create_for_biome(biome_name: String) -> TileSet:
	var dir_name := biome_to_dir(biome_name)
	if dir_name.is_empty():
		push_error("[TileSetService] Unknown biome: %s" % biome_name)
		return null

	var base_path := "res://assets/tilesets/%s" % dir_name
	var has_water_frames := false
	var water_frames: Array[Image] = _load_water_frames(biome_name)
	if water_frames.is_empty():
		# Fallback: generate a single procedural water tile
		water_frames = [_make_water_tile(biome_name)]
	else:
		has_water_frames = true

	# Load terrain images (ground, debris, vegetation, blocked).
	var loaded: Array[Image] = []
	for terrain_name in ["ground", "debris", "vegetation", "blocked"]:
		var path := "%s/%s.png" % [base_path, terrain_name]
		if not ResourceLoader.exists(path):
			push_error("[TileSetService] Missing tile for %s: %s" % [biome_name, path])
			return null
		var tex := load(path) as Texture2D
		if tex == null:
			push_error("[TileSetService] Failed to load texture: %s" % path)
			return null
		var img := tex.get_image()
		if img == null:
			push_error("[TileSetService] Texture has no Image: %s" % path)
			return null
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		img.resize(CELL_SIZE, CELL_SIZE, Image.INTERPOLATE_NEAREST)
		loaded.append(img)

	# Build atlas: cols = WATER_ANIM_FRAMES for water, 1 for other terrains.
	# Row order per terrain: [center, N_edge, S_edge, W_edge, E_edge].
	var atlas_cols := WATER_ANIM_FRAMES if has_water_frames else 1
	var total_rows := loaded.size() * TILES_PER_TERRAIN + TILES_PER_TERRAIN  # 4 terrains + water
	var atlas_img := Image.create(CELL_SIZE * atlas_cols, CELL_SIZE * total_rows, false, Image.FORMAT_RGBA8)
	var terrain_idx := 0
	for ti in loaded.size():
		var center: Image = loaded[ti]
		var base_row := ti * TILES_PER_TERRAIN
		atlas_img.blit_rect(center, Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, base_row * CELL_SIZE))
		atlas_img.blit_rect(_make_edge_tile(center, 0, -1), Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, (base_row + EDGE_N) * CELL_SIZE))
		atlas_img.blit_rect(_make_edge_tile(center, 0, 1),  Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, (base_row + EDGE_S) * CELL_SIZE))
		atlas_img.blit_rect(_make_edge_tile(center, -1, 0), Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, (base_row + EDGE_W) * CELL_SIZE))
		atlas_img.blit_rect(_make_edge_tile(center, 1, 0),  Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, (base_row + EDGE_E) * CELL_SIZE))

	# Place water: 5 edge variants × N frames.
	var wrow := TERRAIN_WATER * TILES_PER_TERRAIN
	if has_water_frames:
		for variant in TILES_PER_TERRAIN:
			var row := wrow + variant
			for frame in WATER_ANIM_FRAMES:
				var fimg: Image = water_frames[frame]
				var edge_img: Image
				if variant == 0:
					edge_img = fimg
				elif variant == EDGE_N:
					edge_img = _make_edge_tile(fimg, 0, -1)
				elif variant == EDGE_S:
					edge_img = _make_edge_tile(fimg, 0, 1)
				elif variant == EDGE_W:
					edge_img = _make_edge_tile(fimg, -1, 0)
				elif variant == EDGE_E:
					edge_img = _make_edge_tile(fimg, 1, 0)
				atlas_img.blit_rect(edge_img, Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(frame * CELL_SIZE, row * CELL_SIZE))
	else:
		# Fallback: single-frame water
		var fimg: Image = water_frames[0]
		for variant in TILES_PER_TERRAIN:
			var row := wrow + variant
			var edge_img: Image
			if variant == 0:
				edge_img = fimg
			elif variant == EDGE_N:
				edge_img = _make_edge_tile(fimg, 0, -1)
			elif variant == EDGE_S:
				edge_img = _make_edge_tile(fimg, 0, 1)
			elif variant == EDGE_W:
				edge_img = _make_edge_tile(fimg, -1, 0)
			elif variant == EDGE_E:
				edge_img = _make_edge_tile(fimg, 1, 0)
			atlas_img.blit_rect(edge_img, Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, row * CELL_SIZE))

	var atlas_tex := ImageTexture.create_from_image(atlas_img)
	var source := TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)
	# Create tiles for ground, debris, vegetation, blocked
	for ti in 4:
		var base_row := ti * TILES_PER_TERRAIN
		for slot in TILES_PER_TERRAIN:
			source.create_tile(Vector2i(0, base_row + slot))
	# Create water tiles (animated or static)
	for variant in TILES_PER_TERRAIN:
		var at_pos := Vector2i(0, wrow + variant)
		source.create_tile(at_pos, Vector2i(1, 1))
		if has_water_frames:
			source.set_tile_animation_frames_count(at_pos, WATER_ANIM_FRAMES)
			source.set_tile_animation_columns(at_pos, WATER_ANIM_FRAMES)
			source.set_tile_animation_separation(at_pos, Vector2i(CELL_SIZE, 0))
			source.set_tile_animation_speed(at_pos, WATER_ANIM_FPS)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(CELL_SIZE, CELL_SIZE)
	ts.add_physics_layer()
	ts.add_source(source)

	# Collision on blocked and water center tiles.
	var coll_rows := [TERRAIN_BLOCKED, TERRAIN_WATER]
	for tr in coll_rows:
		var row: int = tr * TILES_PER_TERRAIN
		var td: TileData = source.get_tile_data(Vector2i(0, row), 0)
		if td != null:
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(0, 0),
				Vector2(CELL_SIZE, 0),
				Vector2(CELL_SIZE, CELL_SIZE),
				Vector2(0, CELL_SIZE),
			]))

	return ts


## Load the shared PixelLab water base texture, colorize it for the given biome,
## and return WATER_ANIM_FRAMES animation frames as a flat array.
## Falls back to procedural flat color if the base texture is missing.
static func _load_water_frames(biome_name: String) -> Array[Image]:
	var frames: Array[Image] = []
	if not ResourceLoader.exists(WATER_BASE_PATH):
		push_warning("[TileSetService] No _water_base.png found — using procedural fallback for %s" % biome_name)
		return frames
	var tex := load(WATER_BASE_PATH) as Texture2D
	if tex == null:
		return frames
	var src := tex.get_image()
	if src == null:
		return frames
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)

	var wc: Color = BIOME_WATER_COLORS.get(biome_name, Color(0.2, 0.45, 0.75, 1.0))
	var tw := src.get_width()
	var fw := tw / WATER_ANIM_FRAMES
	var fh := src.get_height()
	for f in WATER_ANIM_FRAMES:
		var frame := Image.create(fw, fh, false, Image.FORMAT_RGBA8)
		frame.blit_rect(src, Rect2i(f * fw, 0, fw, fh), Vector2i.ZERO)
		frame.resize(CELL_SIZE, CELL_SIZE, Image.INTERPOLATE_NEAREST)
		frames.append(_colorize_image(frame, wc))
	return frames


## Colorize an image by converting to luminance and applying the target color.
## Preserves the source's brightness pattern while shifting hue to target_color.
## Transparent background pixels are filled with a dark variant for solid coverage.
static func _colorize_image(src: Image, target_color: Color) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var dst := Image.create(w, h, false, Image.FORMAT_RGBA8)
	dst.blit_rect(src, Rect2i(0, 0, w, h), Vector2i.ZERO)
	for y in h:
		for x in w:
			var c := dst.get_pixel(x, y)
			var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			if c.a < 0.5:
				# Transparent background — fill with a darker solid variant
				lum = 0.35
			dst.set_pixel(x, y, Color(
				target_color.r * lum,
				target_color.g * lum,
				target_color.b * lum,
				1.0
			))
	return dst


## Procedurally generate a solid water tile with the biome's water color +
## subtle wave highlights. Fallback when no PixelLab base texture exists.
static func _make_water_tile(biome_name: String = "Ash Wastes") -> Image:
	var wc: Color = BIOME_WATER_COLORS.get(biome_name, Color(0.2, 0.45, 0.75, 1.0))
	var img := Image.create(CELL_SIZE, CELL_SIZE, false, Image.FORMAT_RGBA8)
	for py in CELL_SIZE:
		for px in CELL_SIZE:
			var wave := sin(float(px) * 0.8 + float(py) * 0.4) * 0.06
			var r := clampf(wc.r + wave, 0.0, 1.0)
			var g := clampf(wc.g + wave * 0.6, 0.0, 1.0)
			var b := clampf(wc.b + wave * 0.3, 0.0, 1.0)
			img.set_pixel(px, py, Color(r, g, b, 1.0))
	return img


## Generate an edge-variant tile by darkening an 8px band along one side.
## dx/dy indicates the edge direction: (0,-1)=N, (0,1)=S, (-1,0)=W, (1,0)=E.
static func _make_edge_tile(src: Image, dx: int, dy: int) -> Image:
	var out := Image.create(CELL_SIZE, CELL_SIZE, false, Image.FORMAT_RGBA8)
	out.blit_rect(src, Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, 0))
	var band := 8
	for py in CELL_SIZE:
		for px in CELL_SIZE:
			var edge_dist := 999
			if dx != 0:
				edge_dist = abs(px - (CELL_SIZE / 2 - dx * CELL_SIZE / 2))
			elif dy != 0:
				edge_dist = abs(py - (CELL_SIZE / 2 - dy * CELL_SIZE / 2))
			if edge_dist >= band:
				continue
			var c := out.get_pixel(px, py)
			var t := float(edge_dist) / float(band)
			c.r *= 0.55 + 0.45 * t
			c.g *= 0.55 + 0.45 * t
			c.b *= 0.55 + 0.45 * t
			out.set_pixel(px, py, c)
	return out


## Returns the cell coords inside a biome's atlas for a given terrain type.
## terrain: TERRAIN_GROUND (0) through TERRAIN_BLOCKED (3).
## edge_mask: bitmask from LocalMapGenerator edge_mask (0 = center, non-zero picks edge variant).
static func atlas_coords(terrain: int, edge_mask: int = 0) -> Vector2i:
	var row := terrain * TILES_PER_TERRAIN
	# Map edge_mask bitmask to edge variant row offset
	if edge_mask & BIT_N:
		row += EDGE_N
	elif edge_mask & BIT_S:
		row += EDGE_S
	elif edge_mask & BIT_W:
		row += EDGE_W
	elif edge_mask & BIT_E:
		row += EDGE_E
	else:
		row += 0  # center
	return Vector2i(0, row)


## Legacy single-param version for callers that don't have edge_mask.
static func atlas_coords_legacy(terrain: int) -> Vector2i:
	return Vector2i(0, terrain * TILES_PER_TERRAIN)
