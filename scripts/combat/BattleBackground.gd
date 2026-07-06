## BattleBackground — Biome-themed atmosphere for the battle scene.
##
## Layers, back to front:
##  1. Tiled ground texture from the current biome (subtle, dimmed)
##  2. Biome color tint over the tile (darkens + biases the hue)
##  3. Scattered decor props from `assets/battle_decor/{kind}/` (boulders,
##     skulls, cacti, rubble, thorns, stumps, roots). Replaces the
##     earlier debris/vegetation tile scatter, which read as "noise"
##     rather than as scenery. Each decor is 64x64 with several
##     variants, scattered around the grid corners + edges.
##  4. Outer vignette (darkens the screen edges, focuses the eye on the grid)
##  5. Drifting motes for atmosphere
##
## Everything uses the same biome the encounter happens in, so an Ash
## Wastes fight feels different from a Neon Bogs fight without needing
## dedicated per-biome background art.
class_name BattleBackground extends Node2D

const TILE_SIZE := 24
const PADDING := 64
const MOTE_COUNT := 18
# Number of decor props scattered around the grid. Higher than the
# old 18-debris-tile count because the new 64x64 decor reads as a
# proper "props" not as "noise".
const DECOR_COUNT := 22
const DECOR_BASE := "res://assets/battle_decor/"

# Biome → list of decor subfolders to use. Folders not present in
# DECOR_BASE are silently skipped (loaded below).
const BIOME_DECOR := {
	"Ash Wastes": ["boulder", "rubble", "stump", "skull", "roots"],
	"Scorched Plains": ["boulder", "rubble", "stump", "skull", "roots"],
	"Glass Dunes": ["boulder", "rubble", "stump", "skull"],
	"Ironwood Thicket": ["stump", "roots", "thorns", "rubble"],
	"Corpse Fields": ["skull", "roots", "stump", "rubble"],
	"Neon Bogs": ["roots", "thorns", "cactus", "stump", "rubble"],
	"Toxin Marshes": ["roots", "thorns", "cactus", "stump"],
	"Stormspire Highlands": ["boulder", "rubble", "stump", "roots"],
	"Rust Canyons": ["boulder", "rubble", "stump", "skull", "cactus"],
	"Dead City Outskirts": ["boulder", "rubble", "stump", "skull"],
}

var _bg_tile: TextureRect
var _tint: ColorRect
var _tile_layer: Node2D
var _vignette: Control
var _particles: Node2D

var _rng := RandomNumberGenerator.new()
var _biome: String = "Ash Wastes"
var _viewport_size: Vector2 = Vector2(1280, 720)
var _grid_size: int = 7


func _ready() -> void:
	_build_children()


func _build_children() -> void:
	# Layer 1: tiled biome ground. TextureRect is set to STRETCH_TILE so
	# the 24x24 ground.png repeats across the whole viewport.
	_bg_tile = TextureRect.new()
	_bg_tile.name = "BGTile"
	_bg_tile.stretch_mode = TextureRect.STRETCH_TILE
	_bg_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_tile.z_index = -100
	_bg_tile.modulate = Color(0.7, 0.7, 0.7, 0.85)
	add_child(_bg_tile)

	# Layer 2: biome tint. Sits over the tiled ground to bias the hue
	# (e.g. bog → teal, wastes → brown) and dim it overall.
	_tint = ColorRect.new()
	_tint.name = "Tint"
	_tint.color = Color(0.0, 0.0, 0.0, 0.55)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.z_index = -90
	add_child(_tint)

	# Layer 3: scattered decor props (boulders, skulls, plants, …).
	_tile_layer = Node2D.new()
	_tile_layer.name = "TileLayer"
	_tile_layer.z_index = -50
	add_child(_tile_layer)

	# Layer 4: outer vignette.
	_vignette = Control.new()
	_vignette.name = "Vignette"
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.z_index = -10
	add_child(_vignette)

	# Layer 5: drifting motes.
	_particles = Node2D.new()
	_particles.name = "Particles"
	_particles.z_index = -20
	add_child(_particles)


func configure(biome: String, grid_size: int, viewport_size: Vector2) -> void:
	_biome = biome
	_grid_size = grid_size
	_viewport_size = viewport_size
	_rng.seed = hash(biome) ^ grid_size
	_apply_biome_ground()
	_apply_tint()
	_scatter_decor()
	_layout_vignette()
	_spawn_particles()


## Load the biome's ground.png and assign it to the tiled bg rect.
func _apply_biome_ground() -> void:
	var dir_name: String = TileSetService.biome_to_dir(_biome)
	var ground_path := "res://assets/tilesets/%s/ground.png" % dir_name
	if ResourceLoader.exists(ground_path):
		var tex: Texture2D = load(ground_path) as Texture2D
		_bg_tile.texture = tex
	else:
		# Fall back to a flat darker panel if no biome tile is found.
		_bg_tile.texture = null
	# Position the tiled rect so it covers the full viewport.
	_bg_tile.size = _viewport_size
	_bg_tile.position = -_viewport_size * 0.5


func _apply_tint() -> void:
	# A stronger biome color is layered on top of the tiled ground
	# so the player reads the environment's mood immediately.
	_tint.color = _biome_tint_overlay()


## Stronger-biased version of the biome palette used as a tint over
## the tiled ground. Alpha ~0.55 keeps the ground visible underneath.
func _biome_tint_overlay() -> Color:
	match _biome:
		"Ash Wastes", "Scorched Plains", "Glass Dunes":
			return Color(0.42, 0.28, 0.18, 0.55)
		"Ironwood Thicket", "Corpse Fields":
			return Color(0.18, 0.34, 0.18, 0.55)
		"Neon Bogs", "Toxin Marshes":
			return Color(0.10, 0.30, 0.42, 0.55)
		"Stormspire Highlands":
			return Color(0.18, 0.30, 0.46, 0.55)
		"Rust Canyons", "Dead City Outskirts":
			return Color(0.40, 0.22, 0.16, 0.55)
		_:
			return Color(0.22, 0.20, 0.28, 0.55)


func _scatter_decor() -> void:
	_clear_tile_layer()
	# Build a list of available decor textures for this biome.
	var decors: Array[Texture2D] = []
	var decor_sizes: Array[Vector2] = []
	var kinds: Array = BIOME_DECOR.get(_biome, ["boulder", "rubble", "stump"])
	for kind in kinds:
		var folder: String = "%s%s/" % [DECOR_BASE, kind]
		if not ResourceLoader.exists(folder):
			continue
		for i in range(8):
			var path: String = "%s%s_%d.png" % [folder, kind, i]
			if ResourceLoader.exists(path):
				decors.append(load(path) as Texture2D)
				decor_sizes.append(Vector2(64, 64))
	if decors.is_empty():
		# Fallback: load the older debris/vegetation tile pairs so we
		# always have something. This keeps the scene non-empty even
		# if the new decor wasn't generated.
		var dir_name: String = TileSetService.biome_to_dir(_biome)
		for kind in ["debris", "vegetation"]:
			var path := "res://assets/tilesets/%s/%s.png" % [dir_name, kind]
			if ResourceLoader.exists(path):
				decors.append(load(path) as Texture2D)
				decor_sizes.append(Vector2(24, 24))
		if decors.is_empty():
			return

	var grid_pixel_size: int = _grid_size * TILE_SIZE
	var grid_rect := Rect2(
		-grid_pixel_size * 0.5 - 12,
		-grid_pixel_size * 0.5 - 12,
		grid_pixel_size + 24,
		grid_pixel_size + 24,
	)
	# Place decor in two passes: a tight cluster in each of the four
	# grid corners, then edge fillers. This reads more like scenery
	# than the previous random scatter.
	var anchor_pts: Array[Vector2] = [
		Vector2(-grid_pixel_size * 0.5, -grid_pixel_size * 0.5),
		Vector2(grid_pixel_size * 0.5, -grid_pixel_size * 0.5),
		Vector2(-grid_pixel_size * 0.5, grid_pixel_size * 0.5),
		Vector2(grid_pixel_size * 0.5, grid_pixel_size * 0.5),
	]
	var placed: int = 0
	# Corner clusters (3-5 props per corner, mixed scales)
	for corner in anchor_pts:
		for _i in range(3 + int(_rng.randf() * 3.0)):
			var ang: float = _rng.randf() * TAU
			var dist: float = _rng.randf_range(40.0, 100.0)
			var pos: Vector2 = corner + Vector2(cos(ang), sin(ang)) * dist
			if grid_rect.has_point(pos):
				continue
			var idx: int = _rng.randi() % decors.size()
			_spawn_decor_tile(pos, decors[idx], decor_sizes[idx])
			placed += 1
	# Edge fillers (along top/bottom/left/right outside the grid)
	while placed < DECOR_COUNT:
		var side: int = _rng.randi() % 4
		var margin: float = _rng.randf_range(8.0, 28.0)
		var pos2: Vector2
		match side:
			0: # top
				pos2 = Vector2(_rng.randf_range(-grid_pixel_size * 0.5 - 80, grid_pixel_size * 0.5 + 80), -grid_pixel_size * 0.5 - margin)
			1: # bottom
				pos2 = Vector2(_rng.randf_range(-grid_pixel_size * 0.5 - 80, grid_pixel_size * 0.5 + 80), grid_pixel_size * 0.5 + margin)
			2: # left
				pos2 = Vector2(-grid_pixel_size * 0.5 - margin, _rng.randf_range(-grid_pixel_size * 0.5, grid_pixel_size * 0.5))
			3: # right
				pos2 = Vector2(grid_pixel_size * 0.5 + margin, _rng.randf_range(-grid_pixel_size * 0.5, grid_pixel_size * 0.5))
		if grid_rect.has_point(pos2):
			continue
		var idx2: int = _rng.randi() % decors.size()
		_spawn_decor_tile(pos2, decors[idx2], decor_sizes[idx2])
		placed += 1


func _spawn_decor_tile(world_pos: Vector2, tex: Texture2D, native_size: Vector2) -> void:
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	# Random rotation + scale variance. Decor is 64x64 native; we
	# scale by 0.6-1.0 to match the FFT reference's "scattered"
	# feel where props feel like a small chunk, not full-size.
	var base_scale: float = (24.0 / maxf(native_size.x, native_size.y)) * _rng.randf_range(0.85, 1.10)
	sprite.scale = Vector2(base_scale, base_scale)
	sprite.rotation = _rng.randf_range(-0.4, 0.4)
	sprite.position = world_pos
	sprite.modulate = Color(0.92, 0.92, 0.92, 0.95)
	sprite.z_index = -50
	_tile_layer.add_child(sprite)


func _clear_tile_layer() -> void:
	for c in _tile_layer.get_children():
		c.queue_free()


func _layout_vignette() -> void:
	for c in _vignette.get_children():
		c.queue_free()
	var outer := ColorRect.new()
	outer.name = "Outer"
	outer.color = Color(0, 0, 0, 0.50)
	outer.position = -_viewport_size * 0.5
	outer.size = _viewport_size
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.z_index = -10
	_vignette.add_child(outer)


func _spawn_particles() -> void:
	_clear_particles()
	var mote_color: Color = _mote_color()
	for i in range(MOTE_COUNT):
		var mote := ColorRect.new()
		mote.color = mote_color
		mote.size = Vector2(2, 2)
		mote.position = Vector2(
			_rng.randf_range(-_viewport_size.x * 0.5, _viewport_size.x * 0.5),
			_rng.randf_range(-_viewport_size.y * 0.5, _viewport_size.y * 0.5)
		)
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mote.z_index = -20
		_particles.add_child(mote)
		var t := _particles.create_tween().set_loops()
		t.set_parallel(true)
		var start_y: float = mote.position.y
		t.tween_property(mote, "position:y", start_y + _rng.randf_range(-30, 30), _rng.randf_range(3.0, 6.0)).set_trans(Tween.TRANS_SINE)
		t.tween_property(mote, "modulate:a", _rng.randf_range(0.2, 0.6), _rng.randf_range(2.0, 4.0))


func _clear_particles() -> void:
	for c in _particles.get_children():
		c.queue_free()


func _mote_color() -> Color:
	match _biome:
		"Neon Bogs", "Toxin Marshes":
			return Color(0.4, 1.0, 0.7, 0.5)
		"Stormspire Highlands":
			return Color(0.7, 0.8, 1.0, 0.5)
		"Ash Wastes", "Scorched Plains":
			return Color(0.9, 0.7, 0.4, 0.3)
		"Rust Canyons", "Dead City Outskirts":
			return Color(0.9, 0.6, 0.4, 0.3)
		"Ironwood Thicket":
			return Color(0.5, 0.9, 0.5, 0.3)
		"Glass Dunes":
			return Color(0.7, 0.9, 1.0, 0.4)
		"Corpse Fields":
			return Color(0.7, 0.4, 0.4, 0.3)
		_:
			return Color(0.7, 0.7, 0.7, 0.3)
