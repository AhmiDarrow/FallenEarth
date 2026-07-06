## BattleBackground — Atmospheric backdrop for the battle scene.
##
## Wraps the grid with biome-themed darkening + vignette. Uses the
## existing biome's tiles scattered around the grid border to suggest
## rubble. Tints the whole thing toward the biome's dominant hue so
## the player immediately recognizes the environment.
class_name BattleBackground extends Node2D

const TILE_SIZE := 24
const PADDING := 96
const MOTE_COUNT := 18

var _bg: ColorRect
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
	_bg = ColorRect.new()
	_bg.name = "BG"
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.z_index = -100
	add_child(_bg)

	_tile_layer = Node2D.new()
	_tile_layer.name = "TileLayer"
	_tile_layer.z_index = -50
	add_child(_tile_layer)

	_vignette = Control.new()
	_vignette.name = "Vignette"
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.z_index = -10
	add_child(_vignette)

	_particles = Node2D.new()
	_particles.name = "Particles"
	_particles.z_index = -20
	add_child(_particles)


func configure(biome: String, grid_size: int, viewport_size: Vector2) -> void:
	_biome = biome
	_grid_size = grid_size
	_viewport_size = viewport_size
	_rng.seed = hash(biome) ^ grid_size
	_apply_tint()
	_scatter_tiles()
	_layout_vignette()
	_spawn_particles()


func _apply_tint() -> void:
	_bg.color = _biome_tint()
	_bg.size = _viewport_size
	_bg.position = Vector2(-_viewport_size.x * 0.5, -_viewport_size.y * 0.5)


func _biome_tint() -> Color:
	match _biome:
		"Ash Wastes", "Scorched Plains", "Glass Dunes":
			return Color(0.12, 0.09, 0.07, 1.0)
		"Ironwood Thicket", "Corpse Fields":
			return Color(0.06, 0.10, 0.06, 1.0)
		"Neon Bogs", "Toxin Marshes":
			return Color(0.06, 0.09, 0.13, 1.0)
		"Stormspire Highlands":
			return Color(0.07, 0.09, 0.14, 1.0)
		"Rust Canyons", "Dead City Outskirts":
			return Color(0.11, 0.07, 0.06, 1.0)
		_:
			return Color(0.08, 0.07, 0.10, 1.0)


func _scatter_tiles() -> void:
	_clear_tile_layer()
	var tileset_service = preload("res://scripts/TileSetService.gd")
	var tile_set: TileSet = tileset_service.create_for_biome(_biome)
	if tile_set == null:
		return
	var atlas_tex: Texture2D = null
	for i in range(tile_set.get_source_count()):
		var src: TileSetSource = tile_set.get_source(i)
		if src is TileSetAtlasSource:
			atlas_tex = (src as TileSetAtlasSource).texture
			break
	if atlas_tex == null:
		return
	var atlas_size_y: int = int(atlas_tex.get_size().y)
	var row_count: int = mini(4, atlas_size_y / TILE_SIZE)
	# Grid center in local space (BattleGridView centers the grid)
	var grid_pixel_size: int = _grid_size * TILE_SIZE
	var grid_rect := Rect2(
		-grid_pixel_size * 0.5 - 12,
		-grid_pixel_size * 0.5 - 12,
		grid_pixel_size + 24,
		grid_pixel_size + 24,
	)
	var placed: int = 0
	var attempts: int = 0
	while placed < 64 and attempts < 400:
		attempts += 1
		var row: int = _rng.randi_range(0, row_count - 1)
		var px: float = _rng.randf_range(-_viewport_size.x * 0.5 - PADDING, _viewport_size.x * 0.5 + PADDING)
		var py: float = _rng.randf_range(-_viewport_size.y * 0.5 - PADDING, _viewport_size.y * 0.5 + PADDING)
		if grid_rect.has_point(Vector2(px, py)):
			continue
		var sprite := Sprite2D.new()
		sprite.texture = atlas_tex
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, row * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		sprite.position = Vector2(px, py)
		sprite.modulate = Color(0.45, 0.45, 0.45, 0.55)
		sprite.z_index = -50
		_tile_layer.add_child(sprite)
		placed += 1


func _clear_tile_layer() -> void:
	for c in _tile_layer.get_children():
		c.queue_free()


func _layout_vignette() -> void:
	for c in _vignette.get_children():
		c.queue_free()
	# Outer dim
	var outer := ColorRect.new()
	outer.name = "Outer"
	outer.color = Color(0, 0, 0, 0.45)
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
