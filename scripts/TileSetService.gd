## TileSetService — Builds native Godot TileSet resources for local map rendering.
##
## One TileSet per biome. Ground uses Wang-based autotiling from a PixelLab
## Wang spritesheet (ground_wang_32.png) with two terrain subtypes (A/B) for
## natural-looking ground variety. Debris / vegetation / blocked use single-tile
## edge variants (center + N/S/W/E) generated via procedural edge bands.
## Water tiles are loaded from a shared PixelLab base texture and color-shifted per biome.
##
## The atlas is a single image combining all terrain types. Ground Wang tiles
## occupy the top-left grid (grid_cols × grid_rows), non-ground terrain tiles
## sit below in column 0, and animated water tiles occupy rows below that across
## all animation columns.
class_name TileSetService
extends RefCounted

const CELL_SIZE := 32
const TERRAIN_GROUND := 0
const TERRAIN_DEBRIS := 1
const TERRAIN_VEGETATION := 2
const TERRAIN_BLOCKED := 3
const TERRAIN_WATER := 4

const TERRAIN_NAMES := ["ground", "debris", "vegetation", "blocked", "water"]

## Wang ground subtype IDs — each cell's ground can be subtype A or B.
## The Wang spritesheet provides tiles for every corner combination of these two subtypes.
const WANG_A := 0
const WANG_B := 1

## Non-ground terrain types each have 5 atlas rows: 0=center, 1=N, 2=S, 3=W, 4=E.
const TILES_PER_TERRAIN := 5
const EDGE_CENTER := 0
const EDGE_N := 1
const EDGE_S := 2
const EDGE_W := 3
const EDGE_E := 4

## Edge direction bitmask (matches LocalMapGenerator edge_mask).
const BIT_N := 1
const BIT_S := 2
const BIT_W := 4
const BIT_E := 8

## Water animation config.
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

## Atlas layout calculated in create_for_biome — available after first TileSet is built.
static var _grid_cols := 4
static var _grid_rows := 4
static var _non_ground_row_start := 4   # row where debris/vegetation/blocked begin
static var _water_row_start := 19       # row where water tiles begin


static func biome_to_dir(biome_name: String) -> String:
	return BIOME_DIR.get(biome_name, biome_name.to_snake_case())


## Creates a TileSet for the given biome. Ground uses Wang autotiling from
## the PixelLab Wang spritesheet. Debris/vegetation/blocked use single-tile
## edge variants. Water is animated and color-shifted.
static func create_for_biome(biome_name: String) -> TileSet:
	var dir_name := biome_to_dir(biome_name)
	if dir_name.is_empty():
		push_error("[TileSetService] Unknown biome: %s" % biome_name)
		return null

	var base_path := "res://assets/tilesets/%s" % dir_name

	# Load the Wang ground spritesheet (32px per tile, resized from 64px source)
	var wang_path := "%s/ground_wang_32.png" % base_path
	var wang_img := _load_image_or_fallback(wang_path, "%s/ground.png" % base_path)
	if wang_img == null:
		push_error("[TileSetService] Missing ground texture for %s" % biome_name)
		return null

	# Calculate Wang grid dimensions (always column-major 4 cols)
	var wang_w := wang_img.get_width()
	var wang_h := wang_img.get_height()
	var grid_cols := wang_w / CELL_SIZE
	var grid_rows := wang_h / CELL_SIZE
	_grid_cols = grid_cols
	_grid_rows = grid_rows
	# Rows for non-ground terrain types start after the Wang grid
	_non_ground_row_start = grid_rows

	# Load terrain images for debris, vegetation, blocked
	var terrain_imgs: Array[Image] = []
	for tn in ["debris", "vegetation", "blocked"]:
		var path := "%s/%s.png" % [base_path, tn]
		var img := _load_image(path)
		if img == null:
			push_error("[TileSetService] Missing %s for %s" % [tn, biome_name])
			return null
		terrain_imgs.append(img)

	# Load water frames
	var has_water_frames := false
	var water_frames: Array[Image] = _load_water_frames(biome_name)
	if water_frames.is_empty():
		water_frames = [_make_water_tile(biome_name)]
	else:
		has_water_frames = true

	# --- Build combined atlas ---
	var atlas_cols := maxi(grid_cols, WATER_ANIM_FRAMES)
	var non_ground_terrains := 3  # debris, vegetation, blocked
	_water_row_start = _non_ground_row_start + non_ground_terrains * TILES_PER_TERRAIN
	var total_rows := _water_row_start + TILES_PER_TERRAIN  # 5 water edge variants

	var atlas_img := Image.create(CELL_SIZE * atlas_cols, CELL_SIZE * total_rows, false, Image.FORMAT_RGBA8)

	# Copy Wang ground spritesheet into top-left
	atlas_img.blit_rect(wang_img, Rect2i(0, 0, wang_w, wang_h), Vector2i.ZERO)

	# Place non-ground terrain tiles in column 0, rows below Wang grid
	for ti in non_ground_terrains:
		var center: Image = terrain_imgs[ti]
		var base_row := _non_ground_row_start + ti * TILES_PER_TERRAIN
		atlas_img.blit_rect(center, Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, base_row * CELL_SIZE))
		atlas_img.blit_rect(_make_edge_tile(center, 0, -1), Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, (base_row + EDGE_N) * CELL_SIZE))
		atlas_img.blit_rect(_make_edge_tile(center, 0, 1),  Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, (base_row + EDGE_S) * CELL_SIZE))
		atlas_img.blit_rect(_make_edge_tile(center, -1, 0), Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, (base_row + EDGE_W) * CELL_SIZE))
		atlas_img.blit_rect(_make_edge_tile(center, 1, 0),  Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(0, (base_row + EDGE_E) * CELL_SIZE))

	# Place water: 5 edge variants × N animation frames, starting at _water_row_start
	var wrow := _water_row_start
	if has_water_frames:
		for variant in TILES_PER_TERRAIN:
			var row := wrow + variant
			for frame in WATER_ANIM_FRAMES:
				var fimg: Image = water_frames[frame]
				var edge_img: Image
				if variant == EDGE_CENTER:
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
		var fimg: Image = water_frames[0]
		for variant in TILES_PER_TERRAIN:
			var row := wrow + variant
			var edge_img: Image
			if variant == EDGE_CENTER:
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

	# Create Wang ground tiles (all positions in the Wang grid)
	for row in grid_rows:
		for col in grid_cols:
			source.create_tile(Vector2i(col, row))

	# Create non-ground terrain tiles (column 0)
	for ti in non_ground_terrains:
		var base_row := _non_ground_row_start + ti * TILES_PER_TERRAIN
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
	for tr in [TERRAIN_BLOCKED, TERRAIN_WATER]:
		var td := _get_terrain_tile_data(source, tr, EDGE_CENTER)
		if td != null:
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(0, 0),
				Vector2(CELL_SIZE, 0),
				Vector2(CELL_SIZE, CELL_SIZE),
				Vector2(0, CELL_SIZE),
			]))

	return ts


## Returns the TileData for a given terrain type's edge variant.
static func _get_terrain_tile_data(source: TileSetAtlasSource, terrain: int, edge_variant: int) -> TileData:
	var row: int
	if terrain == TERRAIN_GROUND:
		# Ground center = Wang tile (0,0)
		return source.get_tile_data(Vector2i(0, 0), 0)
	elif terrain == TERRAIN_WATER:
		row = _water_row_start + edge_variant
	else:
		var ti := terrain - 1  # debris=0, vegetation=1, blocked=2
		row = _non_ground_row_start + ti * TILES_PER_TERRAIN + edge_variant
	return source.get_tile_data(Vector2i(0, row), 0)


## Returns the atlas coordinates for a given terrain type + edge mask.
## For GROUND cells: if edge_mask is 0 (all neighbors same), use the Wang
## ground tile based on ground_variant corner pattern. Otherwise use edge variant.
## For non-ground cells: always use edge variant tiles.
## ground_var_pattern: 4-bit value [TL=8, TR=4, BR=2, BL=1] where each bit
##   is 1 if that corner differs from the center cell's ground subtype.
static func atlas_coords(terrain: int, edge_mask: int = 0, ground_var_pattern: int = 0) -> Vector2i:
	if terrain == TERRAIN_GROUND:
		if edge_mask != 0:
			return _edge_coords_for(TERRAIN_GROUND, edge_mask)
		else:
			return _wang_ground_coords(ground_var_pattern)
	elif terrain == TERRAIN_WATER:
		return _edge_coords_for(TERRAIN_WATER, edge_mask)
	else:
		return _edge_coords_for(terrain, edge_mask)


## Returns the atlas coords for a non-ground terrain type's edge variant.
static func _edge_coords_for(terrain: int, edge_mask: int) -> Vector2i:
	var variant_row := EDGE_CENTER
	if edge_mask & BIT_N:
		variant_row = EDGE_N
	elif edge_mask & BIT_S:
		variant_row = EDGE_S
	elif edge_mask & BIT_W:
		variant_row = EDGE_W
	elif edge_mask & BIT_E:
		variant_row = EDGE_E

	var row: int
	if terrain == TERRAIN_WATER:
		row = _water_row_start + variant_row
	elif terrain == TERRAIN_GROUND:
		row = _non_ground_row_start + 0  # falls back to same as debris center? no... let me think
		# Actually for GROUND edge variants, we don't have dedicated edge tiles.
		# The Wang system handles same-terrain edges, and edge_mask=0 means no edge.
		# When edge_mask != 0 but terrain == GROUND, we should still use the Wang
		# center tile since there are no dedicated ground edge variant rows.
		# But we return the Wang center tile since the edge band isn't needed
		# for ground (the Wang tiles handle transitions internally).
		return Vector2i(0, 0)
	else:
		var ti := terrain - 1  # debris=0, vegetation=1, blocked=2
		row = _non_ground_row_start + ti * TILES_PER_TERRAIN + variant_row
	return Vector2i(0, row)


## Converts a 4-bit corner pattern to Wang atlas coords.
## ground_var_pattern bits: [TL=8, TR=4, BR=2, BL=1]
## Each bit is 0=same-as-center, 1=different-from-center.
## Maps to Wang grid: col=(BL<<1)|BR, row=(TL<<1)|TR
static func _wang_ground_coords(pattern: int) -> Vector2i:
	var tl := 1 if (pattern & 8) else 0
	var tr := 1 if (pattern & 4) else 0
	var bl := 1 if (pattern & 1) else 0
	var br := 1 if (pattern & 2) else 0
	var col := (bl << 1) | br
	var row := (tl << 1) | tr
	return Vector2i(col, row)


## Compute the ground variant corner pattern for a cell based on its
## own variant and its neighbors' variants.
##   self_variant: the center cell's ground subtype (WANG_A=0, WANG_B=1)
##   nv: N neighbor variant (-1 if N is not ground)
##   sv, wv, ev: S, W, E neighbor variants
## Returns a 4-bit pattern [TL=8, TR=4, BR=2, BL=1] for wang_ground_coords.
static func compute_wang_pattern(self_variant: int, nv: int, sv: int, wv: int, ev: int) -> int:
	var pattern := 0
	# Top-left corner: different if N or W differs
	if (nv >= 0 and nv != self_variant) or (wv >= 0 and wv != self_variant):
		pattern |= 8
	# Top-right corner: different if N or E differs
	if (nv >= 0 and nv != self_variant) or (ev >= 0 and ev != self_variant):
		pattern |= 4
	# Bottom-right corner: different if S or E differs
	if (sv >= 0 and sv != self_variant) or (ev >= 0 and ev != self_variant):
		pattern |= 2
	# Bottom-left corner: different if S or W differs
	if (sv >= 0 and sv != self_variant) or (wv >= 0 and wv != self_variant):
		pattern |= 1
	return pattern


# --- Image loading utilities ---

static func _load_image(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	img.resize(CELL_SIZE, CELL_SIZE, Image.INTERPOLATE_NEAREST)
	return img


static func _load_image_or_fallback(path: String, fallback_path: String) -> Image:
	var img := _load_image(path)
	if img != null:
		return img
	if ResourceLoader.exists(fallback_path):
		return _load_image(fallback_path)
	return null


static func _load_water_frames(biome_name: String) -> Array[Image]:
	var frames: Array[Image] = []
	if not ResourceLoader.exists(WATER_BASE_PATH):
		push_warning("[TileSetService] No _water_base.png — using procedural fallback for %s" % biome_name)
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
				lum = 0.35
			dst.set_pixel(x, y, Color(
				target_color.r * lum,
				target_color.g * lum,
				target_color.b * lum,
				1.0
			))
	return dst


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


## Legacy shortcut for callers that don't have edge_mask.
static func atlas_coords_legacy(terrain: int) -> Vector2i:
	return atlas_coords(terrain, 0, 0)
