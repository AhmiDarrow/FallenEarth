extends Node2D

const CHAR_FOLDER: String = "res://assets/characters/"

var current_race: String = "human"
var current_gender: String = "male"
var current_direction: int = 0

var _anim_sprite: AnimatedSprite2D = null
var _sprite_node: Sprite2D = null
var _mount_sprite  # Sprite2D or AnimatedSprite2D
var _mount_anim: AnimatedSprite2D = null
var _equip_overlays: Dictionary = {}
var _equip_sprite_path: String = "res://assets/sprites/equipment/"

func _ready() -> void:
	pass

func set_base_sprite(race: String, gender: String) -> void:
	current_race = race.to_lower()
	current_gender = gender.to_lower()

	_clear_sprite()

	var base: String = "%s%s_%s/%s_%s" % [CHAR_FOLDER, current_race, current_gender, current_race, current_gender]
	var tres_path: String = base + ".tres"
	var png_path: String = base + "_base.png"

	if ResourceLoader.exists(tres_path):
		_anim_sprite = AnimatedSprite2D.new()
		_anim_sprite.name = "AnimatedSprite2D"
		_anim_sprite.sprite_frames = load(tres_path)
		_anim_sprite.centered = true
		_anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_anim_sprite.scale = Vector2(0.5, 0.5)
		add_child(_anim_sprite)
		_anim_sprite.play("idle")
		print("[CharacterVisual] Loaded animated sprite: ", tres_path)
		return

	if ResourceLoader.exists(png_path):
		_sprite_node = Sprite2D.new()
		_sprite_node.name = "Sprite2D"
		_sprite_node.texture = load(png_path)
		_sprite_node.centered = true
		_sprite_node.scale = Vector2(0.5, 0.5)
		add_child(_sprite_node)
		print("[CharacterVisual] Loaded base sprite: ", png_path)
		return

	print("[CharacterVisual] WARNING: No sprites found for %s_%s" % [current_race, current_gender])

func _clear_sprite() -> void:
	if _anim_sprite != null:
		_anim_sprite.queue_free()
		_anim_sprite = null
	if _sprite_node != null:
		_sprite_node.queue_free()
		_sprite_node = null
	if _mount_sprite != null:
		_mount_sprite.queue_free()
		_mount_sprite = null
	_mount_anim = null
	for slot in _equip_overlays:
		var overlay: Sprite2D = _equip_overlays[slot]
		if is_instance_valid(overlay):
			overlay.queue_free()
	_equip_overlays.clear()

func play_animation(anim_name: String, direction: int = 0, _frame: int = 0) -> void:
	current_direction = clampi(direction, 0, 7)
	_apply_direction()

	var mapped: String = anim_name
	if anim_name == "run":
		mapped = "walk"
	elif anim_name == "ko":
		mapped = "death"
	elif anim_name == "hurt":
		mapped = "death"

	if _anim_sprite != null and _anim_sprite.sprite_frames != null:
		if _anim_sprite.sprite_frames.has_animation(mapped):
			_anim_sprite.play(mapped)
		else:
			_anim_sprite.play("idle")

	# Sync mount animation to player movement
	if _mount_anim != null and _mount_anim.sprite_frames != null:
		if _mount_anim.sprite_frames.has_animation(mapped):
			_mount_anim.play(mapped)
		else:
			_mount_anim.play("idle")

func set_mount_sprite(mob_uuid: String) -> void:
	clear_mount_sprite()
	# Prefer animated SpriteFrames (.tres) for walk/idle animations
	var tres_path: String = "res://assets/mobs/%s/%s.tres" % [mob_uuid, mob_uuid]
	if ResourceLoader.exists(tres_path):
		_mount_anim = AnimatedSprite2D.new()
		_mount_anim.name = "MountAnimatedSprite2D"
		_mount_anim.sprite_frames = load(tres_path)
		_mount_anim.centered = true
		_mount_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_mount_anim.scale = Vector2(0.5, 0.5)
		_mount_anim.z_index = -5
		add_child(_mount_anim, false, Node.INTERNAL_MODE_FRONT)
		_mount_anim.play("idle")
		_mount_sprite = _mount_anim
		return
	# Fall back to static PNG
	var png_path: String = "res://assets/mobs/%s.png" % mob_uuid
	if not ResourceLoader.exists(png_path):
		return
	var static_sprite := Sprite2D.new()
	static_sprite.name = "MountSprite2D"
	static_sprite.texture = load(png_path)
	static_sprite.centered = true
	static_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	static_sprite.scale = Vector2(0.5, 0.5)
	static_sprite.z_index = -5
	add_child(static_sprite, false, Node.INTERNAL_MODE_FRONT)
	_mount_sprite = static_sprite

func clear_mount_sprite() -> void:
	if _mount_sprite != null:
		_mount_sprite.queue_free()
		_mount_sprite = null
	_mount_anim = null

func _apply_direction() -> void:
	rotation_degrees = 0.0
	# Directions with dx < 0 (NW=5, W=6, SW=7) face left → flip horizontally.
	var flip_h: bool = current_direction >= 5
	# Directions with dy < 0 (NE=3, N=4, NW=5) face away → flip vertically.
	var flip_v: bool = current_direction >= 3 and current_direction <= 5
	if _anim_sprite != null:
		_anim_sprite.flip_h = flip_h
		_anim_sprite.flip_v = flip_v
	if _sprite_node != null:
		_sprite_node.flip_h = flip_h
		_sprite_node.flip_v = flip_v
	if _mount_sprite != null:
		_mount_sprite.flip_h = flip_h
		_mount_sprite.flip_v = flip_v

func update_equipment(equip: Dictionary = {}) -> void:
	for slot in _equip_overlays:
		var overlay: Sprite2D = _equip_overlays[slot]
		if is_instance_valid(overlay):
			overlay.queue_free()
	_equip_overlays.clear()

	if equip.is_empty():
		return

	var layer_order: Array = ["boots", "legs", "chest", "head", "offhand", "mainhand"]
	var z_offsets: Dictionary = {
		"boots": -3, "legs": -2, "chest": -1,
		"head": 1, "offhand": 1, "mainhand": 2,
	}
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
		var tex_path: String = _equip_sprite_path + sprite_name + ".png"
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

func _resolve_equip_sprite(item_id: String) -> String:
	if item_id.begins_with("weapon_"):
		var rest: String = item_id.substr("weapon_".length())
		var parts: PackedStringArray = rest.split("_t")
		if parts.size() == 2:
			var base: String = "weapon_" + parts[0]
			var tier: int = int(parts[1]) - 1
			if tier <= 0:
				return base
			var suffixes: Array = ["", "_ii", "_iii", "_iv", "_v", "_vi", "_vii", "_viii", "_ix", "_x",
				"_xi", "_xii", "_xiii", "_xiv", "_xv", "_xvi", "_xvii", "_xviii", "_xix", "_xx",
				"_xxi", "_xxii", "_xxiii", "_xxiv", "_xxv", "_xxvi"]
			if tier < suffixes.size():
				return base + suffixes[tier]
			return base
	elif item_id.begins_with("armor_"):
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
