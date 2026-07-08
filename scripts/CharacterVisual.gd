# CharacterVisual.gd — Sprite rendering for characters.
# Loads sprite sheets from assets/characters/{race}_{gender}/
# Single base image OR full spritesheet supported.

extends Node2D

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
var _sprite_node: Sprite2D = null
var _equip_overlays: Dictionary = {}  # slot -> Sprite2D

var _anim_timer: float = 0.0
var _anim_speed: float = 0.18
var _is_moving: bool = false


func _ready() -> void:
	pass


func _process(delta: float) -> void:
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

	# Remove old sprite node
	if _sprite_node != null:
		_sprite_node.queue_free()
		_sprite_node = null

	# Try full spritesheet first (check both naming conventions)
	var sheet_paths: Array[String] = [
		"res://assets/characters/%s_%s/%s_%s_spritesheet.png",
		"res://assets/characters/%s_%s/%s_%s_sheet.png",
	]
	for fmt in sheet_paths:
		var sheet_path: String = fmt % [current_race, current_gender, current_race, current_gender]
		if ResourceLoader.exists(sheet_path):
			_sprite_sheet = load(sheet_path) as Texture2D
			if _sprite_sheet != null:
				_build_frame_atlases()
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
			print("[CharacterVisual] Loaded base sprite via Sprite2D: ", base_path)
			return

	print("[CharacterVisual] WARNING: No sprites found for %s_%s" % [current_race, current_gender])


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


func update_equipment(equip: Dictionary = {}) -> void:
	# Clear previous overlays
	for slot in _equip_overlays:
		var overlay: Sprite2D = _equip_overlays[slot]
		if is_instance_valid(overlay):
			overlay.queue_free()
	_equip_overlays.clear()

	if equip.is_empty():
		return

	var equip_sprite_path: String = "res://assets/sprites/equipment/"
	# Layer order: boots (back) -> legs -> chest -> head -> offhand -> mainhand (front)
	var layer_order: Array = ["boots", "legs", "chest", "head", "offhand", "mainhand"]
	var z_offsets: Dictionary = {
		"boots": -3, "legs": -2, "chest": -1,
		"head": 1, "offhand": 1, "mainhand": 2,
	}
	# Position offsets in game units (character cell ~0.64 units)
	# Positive x = right, positive y = down (top-down)
	var slot_offsets: Dictionary = {
		"head": Vector2(0, -0.28),
		"chest": Vector2(0, 0),
		"legs": Vector2(0, 0.16),
		"boots": Vector2(0, 0.28),
		"mainhand": Vector2(0.28, 0.08),
		"offhand": Vector2(-0.28, 0.08),
	}

	for slot in layer_order:
		var item_id: String = str(equip.get(slot, ""))
		if item_id.is_empty():
			continue
		var sprite_name: String = _resolve_equip_sprite(item_id)
		if sprite_name.is_empty():
			continue
		var tex_path: String = equip_sprite_path + sprite_name + ".png"
		if not ResourceLoader.exists(tex_path):
			continue
		var tex: Texture2D = load(tex_path) as Texture2D
		if tex == null:
			continue
		var overlay := Sprite2D.new()
		overlay.texture = tex
		overlay.centered = true
		overlay.pixel_size = 0.01
		overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		overlay.scale = Vector2(2.0, 2.0)
		overlay.z_index = int(z_offsets.get(slot, 0))
		overlay.position = slot_offsets.get(slot, Vector2.ZERO)
		add_child(overlay)
		_equip_overlays[slot] = overlay


## Resolve equipment sprite filename from an item_id.
## weapon_scavenger_t1 -> weapon_scavenger  (tier 0 = base)
## weapon_scavenger_t2 -> weapon_scavenger_ii (tier 1)
## armor_scavenger_head_t1 -> armor_scavenger_head
func _resolve_equip_sprite(item_id: String) -> String:
	if item_id.begins_with("weapon_"):
		# Format: weapon_<class>_t<num>
		var rest: String = item_id.substr("weapon_".length())
		var parts: PackedStringArray = rest.split("_t")
		if parts.size() == 2:
			var base: String = "weapon_" + parts[0]
			var tier: int = int(parts[1]) - 1
			if tier <= 0:
				return base
			# Tier 1+ uses roman numeral suffix
			var suffixes: Array = ["", "_ii", "_iii", "_iv", "_v", "_vi", "_vii", "_viii", "_ix", "_x",
				"_xi", "_xii", "_xiii", "_xiv", "_xv", "_xvi", "_xvii", "_xviii", "_xix", "_xx",
				"_xxi", "_xxii", "_xxiii", "_xxiv", "_xxv", "_xxvi"]
			if tier < suffixes.size():
				return base + suffixes[tier]
			return base
	elif item_id.begins_with("armor_"):
		# Format: armor_<class>_<slot>_t<num>
		var rest: String = item_id.substr("armor_".length())
		var parts: PackedStringArray = rest.split("_t")
		if parts.size() == 2:
			var base: String = "armor_" + parts[0]
			var tier: int = int(parts[1]) - 1
			if tier <= 0:
				return base
			var suffixes: Array = ["", "_ii", "_iii", "_iv", "_v", "_vi", "_vii", "_viii", "_ix", "_x",
				"_xi", "_xii", "_xiii"]
			if tier < suffixes.size():
				return base + suffixes[tier]
			return base
	return ""


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
