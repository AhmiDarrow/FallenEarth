extends Node2D

const CHAR_FOLDER: String = "res://assets/characters/"

var current_race: String = "human"
var current_gender: String = "male"
var current_direction: int = 0
var current_armor_state: String = ""
var npc_id: String = "player"

var _anim_sprite: AnimatedSprite2D = null
var _sprite_node: Sprite2D = null
var _mount_sprite
var _mount_anim: AnimatedSprite2D = null
var _equip_overlays: Dictionary = {}
var _equip_sprite_path: String = "res://assets/sprites/equipment/"
var _bob_time: float = 0.0
var _bob_base_positions: Dictionary = {}

## Visual tier suffixes for the 3-tier weapon system
const _VIS_TIER_SUFFIXES: Array = ["", "_t2", "_t3"]


func _ready() -> void:
	# Subscribe to armor equip events so we can tint the sprite per tier.
	var em := get_node_or_null("/root/EquipmentManager")
	if em != null and em.has_signal("equipment_changed"):
		em.connect("equipment_changed", _on_equipment_changed)

func set_base_sprite(race: String, gender: String, armor_state: String = "") -> void:
	current_race = race.to_lower()
	current_gender = gender.to_lower()
	current_armor_state = armor_state

	_clear_sprite()

	var base: String = "%s%s_%s/" % [CHAR_FOLDER, current_race, current_gender]
	if not armor_state.is_empty():
		base += armor_state + "/"
	base += "%s_%s" % [current_race, current_gender]
	if not armor_state.is_empty():
		base += "_" + armor_state
	var tres_path: String = base + ".tres"
	var png_path: String = base + "_S.png"

	if ResourceLoader.exists(tres_path):
		_anim_sprite = AnimatedSprite2D.new()
		_anim_sprite.name = "AnimatedSprite2D"
		_anim_sprite.sprite_frames = load(tres_path)
		_anim_sprite.centered = true
		_anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_anim_sprite.scale = Vector2(0.5, 0.5)
		add_child(_anim_sprite)
		_anim_sprite.play("idle")
		return

	if ResourceLoader.exists(png_path):
		_sprite_node = Sprite2D.new()
		_sprite_node.name = "Sprite2D"
		_sprite_node.texture = load(png_path)
		_sprite_node.centered = true
		_sprite_node.scale = Vector2(0.5, 0.5)
		add_child(_sprite_node)
		return

	# Fall back to unarmored base sprite if armor state path missing
	if not armor_state.is_empty():
		var base_base: String = "%s%s_%s/%s_%s" % [CHAR_FOLDER, current_race, current_gender, current_race, current_gender]
		var base_tres: String = base_base + ".tres"
		if ResourceLoader.exists(base_tres):
			_anim_sprite = AnimatedSprite2D.new()
			_anim_sprite.name = "AnimatedSprite2D"
			_anim_sprite.sprite_frames = load(base_tres)
			_anim_sprite.centered = true
			_anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_anim_sprite.scale = Vector2(0.5, 0.5)
			add_child(_anim_sprite)
			_anim_sprite.play("idle")
			current_armor_state = ""
			return
		var base_png: String = base_base + "_S.png"
		if ResourceLoader.exists(base_png):
			_sprite_node = Sprite2D.new()
			_sprite_node.name = "Sprite2D"
			_sprite_node.texture = load(base_png)
			_sprite_node.centered = true
			_sprite_node.scale = Vector2(0.5, 0.5)
			add_child(_sprite_node)
			current_armor_state = ""

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
	_bob_base_positions.clear()

func _process(delta: float) -> void:
	if _equip_overlays.is_empty():
		return
	var is_walking: bool = _anim_sprite != null and _anim_sprite.is_playing() and _anim_sprite.animation == "walk"
	if is_walking:
		_bob_time += delta * 8.0
	else:
		_bob_time = 0.0
	for slot in _equip_overlays:
		var overlay: Sprite2D = _equip_overlays[slot]
		if not is_instance_valid(overlay):
			continue
		var base_pos: Vector2 = _bob_base_positions.get(slot, Vector2.ZERO)
		if is_walking:
			overlay.position.y = base_pos.y + sin(_bob_time) * 1.5
		else:
			overlay.position.y = base_pos.y

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
	elif anim_name == "ride":
		mapped = "walk"

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
	# Directions with dx < 0 (NW=5, W=6, SW=7) face left → mirror horizontally.
	# flip_v is intentionally NOT applied: every direction shares the same
	# south-facing frame pool (assets/characters/<race>_<gender>/<race>_<gender>.tres
	# has only one rotation; the natural pixel-art orientation is already upright,
	# so a vertical flip renders the head pointing DOWN — i.e. upside-down when
	# the player walks north). Verified by in-game screenshot (Scorched Plains,
	# 2026-07-20).
	var flip_h: bool = current_direction >= 5
	if _anim_sprite != null:
		_anim_sprite.flip_h = flip_h
		_anim_sprite.flip_v = false
	if _sprite_node != null:
		_sprite_node.flip_h = flip_h
		_sprite_node.flip_v = false
	if _mount_sprite != null:
		_mount_sprite.flip_h = flip_h
		_mount_sprite.flip_v = false

func update_equipment(equip: Dictionary = {}) -> void:
	for slot in _equip_overlays:
		var overlay: Sprite2D = _equip_overlays[slot]
		if is_instance_valid(overlay):
			overlay.queue_free()
	_equip_overlays.clear()

	if equip.is_empty():
		return

	_apply_armor_sprite()

	var layer_order: Array = ["offhand", "mainhand"]



	var z_offsets: Dictionary = {
		"offhand": 1, "mainhand": 2,
	}
	var slot_offsets: Dictionary = {
		"mainhand": Vector2(0.22, 0.06),
		"offhand": Vector2(-0.22, 0.06),
	}
	var slot_scales: Dictionary = {
		"mainhand": Vector2(0.45, 0.45),
		"offhand": Vector2(0.45, 0.45),
	}

	for slot in layer_order:
		var item_id: String = str(equip.get(slot, ""))
		if item_id.is_empty():
			continue
		var sprite_name: String = _resolve_equip_sprite(item_id)
		if sprite_name.is_empty():
			continue
		var tex_path: String = _equip_sprite_path + sprite_name + ".png"
		var tex: Texture2D = null
		# Try Godot resource loader first, then direct filesystem
		if ResourceLoader.exists(tex_path):
			tex = load(tex_path) as Texture2D
		if tex == null:
			var global_path := ProjectSettings.globalize_path(tex_path)
			if FileAccess.file_exists(global_path):
				var img := Image.new()
				if img.load(global_path) == OK:
					tex = ImageTexture.create_from_image(img)
		if tex == null:
			continue
		var overlay := Sprite2D.new()
		overlay.texture = tex
		overlay.centered = true
		overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		overlay.scale = slot_scales.get(slot, Vector2(0.45, 0.45))
		overlay.z_index = int(z_offsets.get(slot, 0))
		overlay.position = slot_offsets.get(slot, Vector2.ZERO)
		add_child(overlay)
		_equip_overlays[slot] = overlay
		_bob_base_positions[slot] = overlay.position

func _resolve_equip_sprite(item_id: String) -> String:
	if item_id.begins_with("weapon_"):
		var rest: String = item_id.substr("weapon_".length())
		var parts: PackedStringArray = rest.split("_t")
		if parts.size() == 2:
			var base: String = "weapon_" + parts[0]
			var tier: int = int(parts[1])
			# Map 26 data tiers → 3 visual sprites:
			# T1 (tiers 1-9) = base sprite, T2 (10-18) = _t2, T3 (19-26) = _t3
			var vis_idx: int = 0
			if tier >= 19:
				vis_idx = 2
			elif tier >= 10:
				vis_idx = 1
			return base + _VIS_TIER_SUFFIXES[vis_idx]
	elif item_id.begins_with("armor_"):
		var rest: String = item_id.substr("armor_".length())
		var parts: PackedStringArray = rest.split("_t")
		if parts.size() == 2:
			var base: String = "armor_" + parts[0]
			var tier: int = int(parts[1]) - 1
			if tier <= 0:
				return base
			var suffixes: Array = ["", "_ii", "_iii", "_iv", "_v"]
			if tier < suffixes.size():
				return base + suffixes[tier]
			return base
	return ""


# ---------------------------------------------------------------------------
# Armor-state switching (switch sprite sheet when armor type changes)
# ---------------------------------------------------------------------------

## Extract the armor type from an equipped armor item_id.
## e.g. "armor_rugged_t3" → "rugged"
func _resolve_armor_type(item_id: String) -> String:
	if not item_id.begins_with("armor_"):
		return ""
	var rest: String = item_id.substr("armor_".length())
	var parts: PackedStringArray = rest.split("_t")
	if parts.is_empty():
		return ""
	return parts[0].to_lower().strip_edges()


## Switch the character sprite to the armor state matching the equipped
## armor type, or reload the base unarmored sprite if no armor is equipped.
## Armor types map directly to visual states: rugged/heavy/massive.
func _apply_armor_sprite() -> void:
	var em := get_node_or_null("/root/EquipmentManager")
	if em == null or not em.has_method("get_equipment"):
		return
	var eq: Dictionary = em.call("get_equipment", npc_id)
	var item_id: String = str(eq.get("armor", ""))
	if item_id.is_empty():
		if not current_armor_state.is_empty():
			set_base_sprite(current_race, current_gender, "")
		return

	var armor_type: String = _resolve_armor_type(item_id)
	var state: String = "armor_%s" % armor_type
	if armor_type.is_empty() or state == current_armor_state:
		return

	set_base_sprite(current_race, current_gender, state)

	# If armor state sprite wasn't available (fallback to unarmored), apply tint
	if current_armor_state.is_empty():
		current_armor_state = state
		var color: Color = em.call("get_armor_color", npc_id)
		if _anim_sprite != null:
			_anim_sprite.modulate = color
		elif _sprite_node != null:
			_sprite_node.modulate = color


func _on_equipment_changed(changed_npc_id: String, slot: String) -> void:
	if slot != "armor":
		return
	if changed_npc_id != npc_id:
		return
	_apply_armor_sprite()
