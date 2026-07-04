# CharacterVisual.gd — Sprite-sheet based rendering with procedural fallback.
# Loads sprite sheets from assets/characters/{race}_{gender}/
# Equipment layered as offset shapes; direction animated via sine/cosine.

extends Node2D

const GraphicsManager = preload("res://scripts/GraphicsManager.gd")

# Sprite sheet layout constants
const FRAME_WIDTH: int = 64
const FRAME_HEIGHT: int = 64
const FRAMES_PER_ANIM: int = 4

# Animation names matching sprite sheet row order
const ANIMATIONS: Array = ["idle", "walk", "attack", "hurt", "ko"]

# Direction labels matching sprite sheet column order within each anim
const DIR_LABELS: Array = ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]

# Current state
var current_race: String = "human"
var current_gender: String = "male"
var current_anim: String = "idle"
var current_direction: int = 0  # 0=S, 1=SE, 2=E, 3=NE, 4=N, 5=NW, 6=W, 7=SW
var current_frame: int = 0

# Sprite sheet data
var _sprite_sheet: Texture2D = null
var _frame_textures: Dictionary = {}  # { "idle_S_0": AtlasTexture, ... }
var _use_procedural_graphics: bool = false  # Use sprites by default


# -----------------------------------------------------------------------------
# Initialization
# -----------------------------------------------------------------------------
func _ready() -> void:
	pass


# -----------------------------------------------------------------------------
# Set base sprite by race and gender
# Loads from assets/characters/{race}_{gender}/{race}_{gender}_spritesheet.png
# Falls back to procedural if sprite sheet not found.
# -----------------------------------------------------------------------------
func set_base_sprite(race: String, gender: String) -> void:
	current_race = race.to_lower()
	current_gender = gender.to_lower()
	_frame_textures.clear()
	_sprite_sheet = null

	# Try to load sprite sheet
	var path: String = "res://assets/characters/%s_%s/%s_%s_spritesheet.png" % [
		current_race, current_gender, current_race, current_gender
	]
	if ResourceLoader.exists(path):
		_sprite_sheet = load(path) as Texture2D
		_build_frame_atlases()
		_use_procedural_graphics = false
		print("[CharacterVisual] Loaded sprite sheet: ", path)
	else:
		print("[CharacterVisual] Sprite sheet not found: ", path, " — using procedural fallback")
		_use_procedural_graphics = true

	queue_redraw()


# -----------------------------------------------------------------------------
# Build AtlasTexture frames from the sprite sheet
# Sheet layout: rows = animations (idle, walk, attack, hurt, ko)
#               columns = 8 directions × 4 frames each
# Total width: 8 dirs × 4 frames × 64px = 2048px (+ padding)
# Total height: 5 anims × 64px = 320px (+ padding)
# -----------------------------------------------------------------------------
func _build_frame_atlases() -> void:
	if _sprite_sheet == null:
		return

	var sheet_w: int = _sprite_sheet.get_width()
	var sheet_h: int = _sprite_sheet.get_height()

	for anim_idx in range(ANIMATIONS.size()):
		var anim_name: String = ANIMATIONS[anim_idx]
		for dir_idx in range(DIR_LABELS.size()):
			var dir_label: String = DIR_LABELS[dir_idx]
			for frame in range(FRAMES_PER_ANIM):
				# Calculate pixel position in sheet
				# Each direction has 4 frames, so column offset = dir_idx * 4 + frame
				var col: int = dir_idx * FRAMES_PER_ANIM + frame
				var row: int = anim_idx

				var region: Rect2 = Rect2(
					Vector2(col * FRAME_WIDTH, row * FRAME_HEIGHT),
					Vector2(FRAME_WIDTH, FRAME_HEIGHT)
				)

				var atlas: AtlasTexture = AtlasTexture.new()
				atlas.atlas = _sprite_sheet
				atlas.region = region

				var key: String = "%s_%s_%d" % [anim_name, dir_label, frame]
				_frame_textures[key] = atlas


# -----------------------------------------------------------------------------
# Set animation and frame, then redraw
# -----------------------------------------------------------------------------
func play_animation(anim_name: String, direction: int = 0, frame: int = 0) -> void:
	current_anim = anim_name
	current_direction = clampi(direction, 0, 7)
	current_frame = clampi(frame, 0, FRAMES_PER_ANIM - 1)
	queue_redraw()


# -----------------------------------------------------------------------------
# Draw loop — sprite-based or procedural fallback
# -----------------------------------------------------------------------------
func _draw() -> void:
	if _use_procedural_graphics or _sprite_sheet == null:
		_draw_procedural()
		return

	# Sprite-based rendering
	var dir_label: String = DIR_LABELS[current_direction]
	var key: String = "%s_%s_%d" % [current_anim, dir_label, current_frame]

	if _frame_textures.has(key):
		var atlas: AtlasTexture = _frame_textures[key]
		# Center the sprite
		var offset: Vector2 = Vector2(-FRAME_WIDTH * 0.5, -FRAME_HEIGHT * 0.5)
		draw_texture(atlas, offset)
	else:
		# Fallback: draw a colored rectangle with race label
		var color: Color = _race_color()
		draw_rect(Rect2(Vector2(-32, -32), Vector2(64, 64)), color)
		draw_string(ThemeDB.fallback_font, Vector2(-20, 4), current_anim, HORIZONTAL_ALIGNMENT_CENTER, 40, 12, Color.WHITE)


# -----------------------------------------------------------------------------
# Procedural fallback (original _draw code)
# -----------------------------------------------------------------------------
func _draw_procedural() -> void:
	var palette: Dictionary = GraphicsManager.get_palette_for_biome("gloom")
	var pos: Vector2 = position
	var x: float = pos.x
	var y: float = pos.y
	var direction: float = 0.0

	GraphicsManager.draw_character_base(x, y, direction, palette)
	GraphicsManager.draw_equipment_layer(x, y, palette)

	var eye_pos: Vector2 = Vector2(x + 6, y - 38)
	var eye_color: Color = palette.get("player_eyes", Color.WHITE)
	draw_circle(eye_pos, 2.5, eye_color)

	var mouth_color: Color = palette.get("ink_faint", Color(0.5, 0.5, 0.5))
	GraphicsManager.draw_multiline_path(
		[eye_pos.x, eye_pos.y - 6, eye_pos.x + 4, eye_pos.y - 4],
		mouth_color, 2, true, false
	)

	GraphicsManager.advance_frame()
	var frame_progress: float = GraphicsManager.get_frame_progress()
	var bob: float = sin(frame_progress * 0.15) * 1.2


# -----------------------------------------------------------------------------
# Equipment update stub — to be layered on top of sprite
# -----------------------------------------------------------------------------
func update_equipment(equip: Dictionary = {}) -> void:
	# TODO: Layer equipment sprites on top of base sprite
	pass


# -----------------------------------------------------------------------------
# Helper: return a deterministic color per race for procedural fallback
# -----------------------------------------------------------------------------
func _race_color() -> Color:
	match current_race:
		"human": return Color(0.8, 0.7, 0.6)
		"mutant": return Color(0.35, 0.7, 0.3)
		"sentientai": return Color(0.5, 0.5, 0.7)
		"cyborg": return Color(0.5, 0.5, 0.55)
		"chthon": return Color(0.4, 0.3, 0.35)
		"vesperid": return Color(0.55, 0.45, 0.35)
		"nullborn": return Color(0.3, 0.3, 0.4)
		"revenant": return Color(0.6, 0.4, 0.35)
		_: return Color(0.7, 0.7, 0.7)
