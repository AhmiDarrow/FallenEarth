## GraphicsManager — Core procedural drawing system (autoload)
## Provides palettes, texture generators, shared draw helpers, and seed-driven consistency.

extends Node


# -----------------------------------------------------------------------------
# Seed-driven randomness
# -----------------------------------------------------------------------------
var _underearth_seed: float

func _init() -> void:
	_underearth_seed = randf()

var _seed_hash := hash(str(_underearth_seed))


# -----------------------------------------------------------------------------
# Biome state helpers — set current biome and get its palette
# -----------------------------------------------------------------------------

func set_current_biome(biome_name: String) -> void:
	# Store the currently active biome for palette lookups
	current_biome = biome_name

func get_biome_palette(biome_name: String) -> Dictionary:
	# Return the palette for the given biome; default to GLOOM if unknown
	return get_palette_for_biome(biome_name)

var current_biome: String = "gloom"

var _rng := RandomNumberGenerator.new()
var _rng_seed := _seed_hash

func _ready() -> void:
	_rng.seed = _rng_seed
	print("[GraphicsManager] seeded with hash %d" % _rng_seed)


func seeded_random() -> float:
	return _rng.randf()


# -----------------------------------------------------------------------------
# Color palettes — one dict per biome, keyed by biome name.
# -----------------------------------------------------------------------------
const PALETTE_GLOOM := {
	"background": Color(0.10, 0.12, 0.14, 1.0),
	"ground": Color(0.16, 0.14, 0.11, 1.0),
	"ground_high": Color(0.18, 0.16, 0.12, 1.0),
	"ground_mid": Color(0.15, 0.13, 0.10, 1.0),
	"ground_dark": Color(0.12, 0.10, 0.08, 1.0),
	"ink_outline": Color(0.28, 0.26, 0.24, 1.0),
	"ink_accent": Color(0.45, 0.42, 0.38, 1.0),
	"ink_faint": Color(0.18, 0.16, 0.14, 0.75),
	"player_skin_base": Color(0.52, 0.40, 0.30, 1.0),
	"player_skin_high": Color(0.62, 0.48, 0.36, 1.0),
	"player_skin_low": Color(0.42, 0.32, 0.24, 1.0),
	"player_hair_base": Color(0.24, 0.18, 0.14, 1.0),
	"player_hair_high": Color(0.32, 0.26, 0.20, 1.0),
	"player_hair_low": Color(0.18, 0.14, 0.10, 1.0),
	"player_eyes": Color(0.58, 0.52, 0.48, 1.0),
	"shadow_base": Color(0.10, 0.10, 0.10, 0.6),
}

const PALETTE_FROST := {
	"background": Color(0.12, 0.14, 0.18, 1.0),
	"ground": Color(0.18, 0.20, 0.22, 1.0),
	"ground_high": Color(0.22, 0.24, 0.26, 1.0),
	"ground_mid": Color(0.16, 0.18, 0.20, 1.0),
	"ground_dark": Color(0.12, 0.14, 0.16, 1.0),
	"ink_outline": Color(0.30, 0.32, 0.36, 1.0),
	"ink_accent": Color(0.48, 0.50, 0.54, 1.0),
	"ink_faint": Color(0.20, 0.22, 0.24, 0.75),
	"player_skin_base": Color(0.54, 0.46, 0.38, 1.0),
	"player_skin_high": Color(0.64, 0.54, 0.44, 1.0),
	"player_skin_low": Color(0.44, 0.36, 0.28, 1.0),
	"player_hair_base": Color(0.22, 0.18, 0.24, 1.0),
	"player_hair_high": Color(0.30, 0.24, 0.30, 1.0),
	"player_hair_low": Color(0.18, 0.14, 0.20, 1.0),
	"player_eyes": Color(0.56, 0.48, 0.60, 1.0),
	"shadow_base": Color(0.10, 0.10, 0.12, 0.6),
}

const PALETTE_VOID := {
	"background": Color(0.06, 0.05, 0.08, 1.0),
	"ground": Color(0.10, 0.08, 0.10, 1.0),
	"ground_high": Color(0.12, 0.10, 0.12, 1.0),
	"ground_mid": Color(0.08, 0.06, 0.08, 1.0),
	"ground_dark": Color(0.05, 0.04, 0.06, 1.0),
	"ink_outline": Color(0.36, 0.34, 0.40, 1.0),
	"ink_accent": Color(0.54, 0.52, 0.60, 1.0),
	"ink_faint": Color(0.20, 0.18, 0.24, 0.75),
	"player_skin_base": Color(0.48, 0.40, 0.36, 1.0),
	"player_skin_high": Color(0.58, 0.48, 0.44, 1.0),
	"player_skin_low": Color(0.38, 0.30, 0.28, 1.0),
	"player_hair_base": Color(0.20, 0.16, 0.22, 1.0),
	"player_hair_high": Color(0.28, 0.22, 0.28, 1.0),
	"player_hair_low": Color(0.16, 0.12, 0.18, 1.0),
	"player_eyes": Color(0.46, 0.38, 0.50, 1.0),
	"shadow_base": Color(0.06, 0.06, 0.08, 0.6),
}

func get_palette_for_biome(biome_name: String) -> Dictionary:
	if biome_name == "gloom":
		return PALETTE_GLOOM
	if biome_name == "frost":
		return PALETTE_FROST
	if biome_name == "void":
		return PALETTE_VOID
	return PALETTE_GLOOM


# -----------------------------------------------------------------------------
# Procedural texture generators — noise, hatching, grit, parallax, overlay
# -----------------------------------------------------------------------------

## Returns a generated texture dict with noise texture and optional hatching.
func generate_procedural_texture(size: int = 256, biome_name: String = "gloom") -> Dictionary:
	var palette := get_palette_for_biome(biome_name)
	var noise: NoiseTexture2D = preload("res://noise/noise_simple.tres")
	if noise == null:
		push_warning("[GraphicsManager] NoiseTexture2D not found, generating fallback")
		noise = NoiseTexture2D.new()
		noise.size = Vector2(size, size)
		noise.frequency = 1.5
		noise.amount = 0.05
		noise.vertical = false
		noise.seed = _rng_seed
		var color := palette["ground"]
		if biome_name == "frost":
			color = Color(color.r, color.b, color.g, color.a)
		if biome_name == "void":
			color = Color(color.r * 0.9, color.g * 0.8, color.b, color.a)
		noise.color = color
		noise.anisotropy = 16

	var result := {"noise": noise}
	if size >= 512:
		result["hatching"] = _generate_hatching(size, palette, biome_name)
	return result


## Generates a subtle hatching texture (cross-hatch, ink lines).
func _generate_hatching(size: int, palette: Dictionary, biome_name: String) -> NoiseTexture:
	var noise := NoiseTexture.new()
	noise.size = Vector2(size, size)
	noise.noise_type = Noise.TYPE_SIMPLE
	noise.seed = _rng_seed
	noise.frequency = 0.75
	noise.amount = 0.03
	noise.vertical = false

	var ink := palette["ink_faint"]
	if biome_name == "frost":
		ink = Color(ink.r * 0.9, ink.g * 0.85, ink.b * 0.9, ink.a)
	if biome_name == "void":
		ink = Color(ink.r * 0.85, ink.g * 0.8, ink.b * 0.9, ink.a)

	noise.color = ink
	noise.anisotropy = 16
	return noise


## Generates a grit (sdf-based) texture for consistent grain.
func get_grit_texture(size: int = 256, biome_name: String = "gloom") -> NoiseTexture:
	var noise := NoiseTexture.new()
	noise.size = Vector2(size, size)
	noise.noise_type = Noise.TYPE_SIMPLE
	noise.seed = _rng_seed
	noise.frequency = 3.0
	noise.amount = 0.025
	noise.vertical = false
	var palette := get_palette_for_biome(biome_name)
	var color := palette["ink_faint"]
	noise.color = color
	noise.anisotropy = 16
	return noise


## Generates parallax layer textures (fog + ground).
func get_parallax_layer(biome_name: String = "gloom") -> Dictionary:
	var result := {"fog": NoiseTexture.new(), "ground": NoiseTexture.new()}
	var palette := get_palette_for_biome(biome_name)
	var fog := NoiseTexture.new()
	fog.size = Vector2(256, 256)
	fog.noise_type = Noise.TYPE_SIMPLE
	fog.seed = _rng_seed
	fog.frequency = 0.8
	fog.amount = 0.08
	fog.vertical = false
	fog.color = palette["ground"]
	fog.anisotropy = 16
	var ground := NoiseTexture.new()
	ground.size = Vector2(256, 256)
	ground.noise_type = Noise.TYPE_SIMPLE
	ground.seed = _rng_seed
	ground.frequency = 1.2
	ground.amount = 0.06
	ground.vertical = false
	ground.color = palette["ground"]
	ground.anisotropy = 16
	result["fog"] = fog
	result["ground"] = ground
	return result


## Generates a biome overlay texture (frost tint, void fog).
func get_biome_overlay(biome_name: String = "gloom") -> NoiseTexture:
	if biome_name == "frost":
		var noise := NoiseTexture.new()
		noise.size = Vector2(256, 256)
		noise.noise_type = Noise.TYPE_SIMPLE
		noise.seed = _rng_seed
		noise.frequency = 2.0
		noise.amount = 0.03
		noise.vertical = false
		noise.color = Color(0.75, 0.85, 1.0)
		noise.anisotropy = 16
		return noise
	if biome_name == "void":
		var noise := NoiseTexture.new()
		noise.size = Vector2(256, 256)
		noise.noise_type = Noise.TYPE_SIMPLE
		noise.seed = _rng_seed
		noise.frequency = 1.5
		noise.amount = 0.04
		noise.vertical = false
		noise.color = Color(0.6, 0.5, 0.8)
		noise.anisotropy = 16
		return noise
	return null


# -----------------------------------------------------------------------------
# Shared draw helpers — used by CharacterVisual, LocalMapRenderer, TacticalCombat
# -----------------------------------------------------------------------------

## Draws a base character (body outline + face) at (x,y) facing direction.
func draw_character_base(x: float, y: float, direction: float, palette: Dictionary) -> void:
	# Body outline (procedural torso + limbs)
	var body_color := palette["player_skin_base"]
	var head_color := palette["player_skin_high"]
	var outline_color := palette["ink_outline"]

	draw_multiline(
		draw_multiline_begin(),
		[x, y - 20, x + 10, y - 30, x + 20, y - 20],
		outline_color,
		4,
		true,
		false,
	)
	draw_multiline(
		draw_multiline_begin(),
		[x - 20, y - 20, x - 10, y - 30, x, y - 20],
		outline_color,
		4,
		true,
		false,
	)

	# Head
	draw_circle(x, y - 35, 8, head_color, outline_color)

	# Body fill with subtle noise tint
	var fill_color := body_color
	if direction > 1.57: # facing right
		fill_color = Color(body_color.r * 1.05, body_color.g * 1.05, body_color.b * 1.05, body_color.a)
	if direction < -1.57: # facing left
		fill_color = Color(body_color.r * 0.95, body_color.g * 0.95, body_color.b * 0.95, body_color.a)

	draw_rect(Rect2(x - 6, y - 25, 12, 15), fill_color, 0.2)


## Draws equipment layer (weapon, armor) offset from body.
func draw_equipment_layer(x: float, y: float, palette: Dictionary) -> void:
	var outline := palette["ink_accent"]
	var armor := palette["ink_faint"]

	# Weapon (simple outline)
	draw_line(x + 12, y - 22, x + 24, y - 28, outline, 3)
	draw_line(x + 10, y - 20, x + 26, y - 30, outline, 3)


## Draws a hex tile with procedural biome pattern (ground + detail dots).
func draw_hex_tile(x: float, y: float, size: float, biome_name: String, palette: Dictionary) -> void:
	var ground := palette["ground"]
	var detail := palette["ink_faint"]

	# Base ground
	draw_rect(Rect2(x - size, y - size, size * 2, size * 2), ground, 0.35)

	# Subtle cross-hatch noise
	var noise := generate_procedural_texture(int(size), biome_name)
	var noise_tex := noise["noise"] as NoiseTexture
	if noise_tex:
		draw_texture(noise_tex, x - size + 2, y - size + 2)

	# Detail dots (rocks, flora)
	var seed := _rng_seed
	for i in range(3):
		seed += 100
		var offset := Vector2(
			(size - 4) * seeded_random(),
			(size - 4) * seeded_random(),
		)
		var dot_radius := 1.5 + seeded_random() * 0.5
		draw_circle(x + offset.x, y + offset.y, dot_radius, detail, 1.2)


# -----------------------------------------------------------------------------
# Animation frame counter — global time-based, seeded
# -----------------------------------------------------------------------------
const _FPS := 60
var _frame_counter := 0

func advance_frame() -> void:
	_frame_counter += 1


func get_frame_progress() -> float:
	return _frame_counter % _FPS


func is_idle_frame() -> bool:
	return get_frame_progress() < 2


# -----------------------------------------------------------------------------
# Shared draw helpers — implement multiline, rect, circle, line, polygon, texture
# -----------------------------------------------------------------------------

## Creates a new Path2D for multiline drawing. Caller must call draw_multiline_begin() again to close.
func draw_multiline_begin() -> Path2D:
	var path := Path2D.new()
	return path

## Adds a line segment to the given Path2D.
func draw_multiline(path: Path2D, points: Array, outline_color: Color, outline_width: float, fill: bool, is_closed: bool) -> void:
	for i in range(points.size() - 1):
		path.add_line(points[i], points[i + 1])
	if is_closed:
		path.close()
	path.outline_color = outline_color
	path.outline_width = outline_width
	path.fill = fill

## Draws a multiline shape.
func draw_multiline(points: Array, outline_color: Color, outline_width: float, fill: bool, is_closed: bool) -> Path2D:
	var path := draw_multiline_begin()
	draw_multiline(path, points, outline_color, outline_width, fill, is_closed)
	return path

## Draws a filled rectangle.
func draw_rect(rect: Rect2, color: Color, alpha: float = 1.0) -> void:
	color.a = color.a * alpha
	# Rectangle is drawn via CanvasTexture's built-in methods; this is a no-op here.

## Draws a filled circle.
func draw_circle(center: Vector2, radius: float, color: Color, outline_color: Color = null) -> void:
	# Circle is drawn via CanvasTexture's built-in methods; this is a no-op here.

## Draws a line.
func draw_line(from: Vector2, to: Vector2, color: Color, width: float = 2.0) -> void:
	# Line is drawn via CanvasTexture's built-in methods; this is a no-op here.

## Draws a polygon outline (no fill).
func draw_polygon(points: Array, color: Color, width: float = 2.0) -> void:
	# Polygon is drawn via CanvasTexture's built-in methods; this is a no-op here.

## Draws a texture at a given position.
func draw_texture(texture: Texture2D, position: Vector2, color: Color = Color.WHITE) -> void:
	# Texture is drawn via CanvasTexture's built-in methods; this is a no-op here.
