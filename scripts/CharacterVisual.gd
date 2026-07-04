# CharacterVisual.gd — Sprite rendering with procedural fallback.
# Loads sprite sheets from assets/characters/{race}_{gender}/
# Single base image OR full spritesheet supported.

extends Node2D

const GraphicsManager = preload("res://scripts/GraphicsManager.gd")

const FRAME_WIDTH: int = 64
const FRAME_HEIGHT: int = 64
const FRAMES_PER_ANIM: int = 4
const ANIMATIONS: Array = ["idle", "walk", "attack", "hurt", "ko"]
const DIR_LABELS: Array = ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]

var current_race: String = "human"
var current_gender: String = "male"
var current_anim: String = "idle"
var current_direction: int = 0
var current_frame: int = 0

var _sprite_sheet: Texture2D = null
var _frame_textures: Dictionary = {}
var _use_procedural_graphics: bool = false
var _sprite_node: Sprite2D = null

var _anim_timer: float = 0.0
var _anim_speed: float = 0.18
var _is_moving: bool = false


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	if _use_procedural_graphics:
		return
	_anim_timer += delta
	if _anim_timer >= _anim_speed:
		_anim_timer -= _anim_speed
		current_frame = (current_frame + 1) % FRAMES_PER_ANIM
		if _sprite_sheet != null:
			queue_redraw()
		elif _sprite_node != null:
			_update_sprite_node()


func set_base_sprite(race: String, gender: String) -> void:
	current_race = race.to_lower()
	current_gender = gender.to_lower()
	_frame_textures.clear()
	_sprite_sheet = null
	_use_procedural_graphics = true

	# Remove old sprite node
	if _sprite_node != null:
		_sprite_node.queue_free()
		_sprite_node = null

	# Try full spritesheet first
	var sheet_path: String = "res://assets/characters/%s_%s/%s_%s_spritesheet.png" % [
		current_race, current_gender, current_race, current_gender
	]
	if ResourceLoader.exists(sheet_path):
		_sprite_sheet = load(sheet_path) as Texture2D
		if _sprite_sheet != null:
			_build_frame_atlases()
			_use_procedural_graphics = false
			print("[CharacterVisual] Loaded sprite sheet: ", sheet_path)
			queue_redraw()
			return

	# Fallback: single base sprite via Sprite2D node
	var base_path: String = "res://assets/characters/%s_%s/%s_%s_base.png" % [
		current_race, current_gender, current_race, current_gender
	]
	if ResourceLoader.exists(base_path):
		var base_tex: Texture2D = load(base_path) as Texture2D
		if base_tex != null:
			_sprite_node = Sprite2D.new()
			_sprite_node.texture = base_tex
			_sprite_node.centered = true
			add_child(_sprite_node)
			_use_procedural_graphics = false
			print("[CharacterVisual] Loaded base sprite via Sprite2D: ", base_path)
			return

	print("[CharacterVisual] No sprites found — using procedural fallback for %s_%s" % [current_race, current_gender])
	queue_redraw()


func _update_sprite_node() -> void:
	if _sprite_node == null:
		return
	# Scale 128px sprite to fit 64px cell
	_sprite_node.scale = Vector2(0.5, 0.5)


func _build_frame_atlases() -> void:
	if _sprite_sheet == null:
		return
	for anim_idx in range(ANIMATIONS.size()):
		var anim_name: String = ANIMATIONS[anim_idx]
		for dir_idx in range(DIR_LABELS.size()):
			var dir_label: String = DIR_LABELS[dir_idx]
			for frame in range(FRAMES_PER_ANIM):
				var col: int = dir_idx * FRAMES_PER_ANIM + frame
				var row: int = anim_idx
				var region: Rect2 = Rect2(
					Vector2(col * FRAME_WIDTH, row * FRAME_HEIGHT),
					Vector2(FRAME_WIDTH, FRAME_HEIGHT)
				)
				var atlas: AtlasTexture = AtlasTexture.new()
				atlas.atlas = _sprite_sheet
				atlas.region = region
				_frame_textures["%s_%s_%d" % [anim_name, dir_label, frame]] = atlas


func play_animation(anim_name: String, direction: int = 0, frame: int = 0) -> void:
	current_anim = anim_name
	current_direction = clampi(direction, 0, 7)
	current_frame = clampi(frame, 0, FRAMES_PER_ANIM - 1)
	_is_moving = (anim_name == "walk" or anim_name == "run")
	_anim_timer = 0.0
	if _sprite_sheet != null:
		queue_redraw()


func _draw() -> void:
	if _use_procedural_graphics:
		_draw_procedural()
		return
	if _sprite_sheet == null:
		return

	var dir_label: String = DIR_LABELS[current_direction]
	var key: String = "%s_%s_%d" % [current_anim, dir_label, current_frame]
	if _frame_textures.has(key):
		var offset: Vector2 = Vector2(-FRAME_WIDTH * 0.5, -FRAME_HEIGHT * 0.5)
		draw_texture(_frame_textures[key], offset)
	else:
		var color: Color = _race_color()
		draw_rect(Rect2(Vector2(-32, -32), Vector2(64, 64)), color)


func _draw_procedural() -> void:
	var palette: Dictionary = GraphicsManager.get_palette_for_biome("gloom")
	var pos: Vector2 = position
	var x: float = pos.x
	var y: float = pos.y
	GraphicsManager.draw_character_base(x, y, 0.0, palette)
	GraphicsManager.draw_equipment_layer(x, y, palette)
	var eye_pos: Vector2 = Vector2(x + 6, y - 38)
	draw_circle(eye_pos, 2.5, palette.get("player_eyes", Color.WHITE))
	GraphicsManager.advance_frame()


func update_equipment(equip: Dictionary = {}) -> void:
	pass


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
