## BattleUnit — Per-unit node on the battle grid.
##
## v0.10.10: SQUARE grid (was isometric diamond in v0.10.5+). Unit
## positions are now simple (x * CELL_SIZE + CELL_SIZE/2,
## y * CELL_SIZE + CELL_SIZE/2) — the cell's center. The unit's
## sprite is centered at (0, 0) in local space and the whole node
## is positioned at the cell center.
## v0.10.11: CELL_SIZE 56 -> 40. Sprite target_px 46 -> 32 so the
## sprite fits cleanly inside the smaller 40px cell.
class_name BattleUnit extends Node2D

const CELL_SIZE := 40
const SPRITE_FOLDER := "res://assets/mobs/"
const CHAR_FOLDER := "res://assets/characters/"

const UnitNamePlateScript = preload("res://scripts/combat/UnitNamePlate.gd")
const UnitSelectionArrowScript = preload("res://scripts/combat/UnitSelectionArrow.gd")

const SWING_DURATION := 0.18
const WALK_DURATION := 0.22
const DEATH_FADE := 0.6
const FLASH_DURATION := 0.12

const COLOR_PLAYER := Color(0.30, 0.75, 0.45)
const COLOR_ALLY := Color(0.30, 0.55, 0.90)
const COLOR_ENEMY := Color(0.92, 0.25, 0.25)
const COLOR_BOSS := Color(0.70, 0.20, 0.85)
const CT_BAR_FILL := Color(0.95, 0.80, 0.30)

var unit_id: String = ""
var team: String = "enemy"
var max_hp: int = 1
var current_hp: int = 1
var current_ct: int = 0
var current_facing: int = 0
var is_boss: bool = false
var is_alive: bool = true
var display_name: String = ""
var _team_hp_color: Color = COLOR_ENEMY
var _grid_pos: Vector2i = Vector2i.ZERO
var _walk_tween: Tween = null
var _flash_tween: Tween = null
var _death_tween: Tween = null
var _swing_tween: Tween = null

var _sprite: Sprite2D
var _hp_bg: ColorRect = null
var _hp_fill: ColorRect = null
var _hp_label: Label = null
var _ct_bg: ColorRect
var _ct_fill: ColorRect
var _name_label: Label
var _status_label: Label
var _active_glow: Sprite2D
var _name_plate: Control
var _selection_arrow: Node2D


func _ready() -> void:
	_build_children()
	_active_glow.visible = false
	_name_plate.visible = true
	_selection_arrow.visible = false
	modulate = Color.WHITE if is_alive else Color(0.4, 0.4, 0.4, 0.6)
	scale = Vector2.ONE * (1.4 if is_boss else 1.0)


func _build_children() -> void:
	# v0.10.10: SQUARE grid. BattleUnit is positioned at the cell
	# center, so the sprite is centered at (0, 0). All overlays
	# are positioned relative to the cell center.
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = true
	_sprite.position = Vector2.ZERO
	_sprite.z_index = 10
	add_child(_sprite)

	_active_glow = Sprite2D.new()
	_active_glow.name = "ActiveGlow"
	_active_glow.centered = true
	_active_glow.position = Vector2.ZERO
	_active_glow.modulate = Color(1.0, 0.95, 0.5, 0.6)
	_active_glow.z_index = 9
	add_child(_active_glow)

	# Name label sits above the unit, centered on the cell.
	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 2)
	_name_label.add_theme_font_size_override("font_size", 8)
	_name_label.position = Vector2(-CELL_SIZE * 0.5, -CELL_SIZE * 0.5 - 12)
	_name_label.size = Vector2(CELL_SIZE, 12)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.z_index = 12
	add_child(_name_label)

	# Status label (e.g. "★ BOSS") below the unit.
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 2)
	_status_label.add_theme_font_size_override("font_size", 7)
	_status_label.position = Vector2(-CELL_SIZE * 0.5, CELL_SIZE * 0.5 + 2)
	_status_label.size = Vector2(CELL_SIZE, 10)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.z_index = 12
	add_child(_status_label)

	_hp_bg = null
	_hp_fill = null
	_hp_label = null

	# CT mini-bar centered below the sprite (within the cell).
	_ct_bg = ColorRect.new()
	_ct_bg.name = "CTBg"
	_ct_bg.color = Color(0.08, 0.06, 0.05, 0.85)
	_ct_bg.position = Vector2(-CELL_SIZE * 0.5 + 2, CELL_SIZE * 0.5 - 8)
	_ct_bg.size = Vector2(CELL_SIZE - 4, 4)
	_ct_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ct_bg.z_index = 11
	add_child(_ct_bg)

	_ct_fill = ColorRect.new()
	_ct_fill.name = "CTFill"
	_ct_fill.color = CT_BAR_FILL
	_ct_fill.position = Vector2(-CELL_SIZE * 0.5 + 3, CELL_SIZE * 0.5 - 7)
	_ct_fill.size = Vector2(0, 2)
	_ct_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ct_fill.z_index = 12
	add_child(_ct_fill)

	# Name plate (white-bg label) sits above the unit sprite,
	# below the selection arrow.
	_name_plate = UnitNamePlateScript.new()
	_name_plate.name = "NamePlate"
	_name_plate.position = Vector2(-48, -CELL_SIZE * 0.5 - 24)
	_name_plate.z_index = 14
	_name_plate.visible = true
	add_child(_name_plate)

	# Selection arrow (cyan down-triangle) sits above the name plate.
	_selection_arrow = UnitSelectionArrowScript.new()
	_selection_arrow.name = "SelectionArrow"
	_selection_arrow.position = Vector2(0, -CELL_SIZE * 0.5 - 48)
	_selection_arrow.z_index = 15
	_selection_arrow.visible = false
	add_child(_selection_arrow)


func setup_from_data(unit: Dictionary, cell_size: int) -> void:
	unit_id = str(unit.get("id", ""))
	team = str(unit.get("team", "enemy"))
	max_hp = int(unit.get("max_hp", 1))
	current_hp = int(unit.get("hp", max_hp))
	current_ct = int(unit.get("ct", 0))
	current_facing = int(unit.get("facing", 0))
	is_boss = bool(unit.get("is_boss", false))
	is_alive = current_hp > 0
	display_name = str(unit.get("name", _unit_display_name()))
	_grid_pos = unit.get("pos", Vector2i.ZERO)
	# v0.10.10: SQUARE grid — unit sits at the cell center.
	position = Vector2(
		_grid_pos.x * cell_size + cell_size * 0.5,
		_grid_pos.y * cell_size + cell_size * 0.5,
	)
	_load_sprite(unit)
	_apply_team_palette()
	_refresh_hp()
	_refresh_ct()
	_refresh_name()
	_refresh_status()
	if _active_glow != null:
		_active_glow.visible = false
	_refresh_name_plate()
	_refresh_selection_arrow()
	modulate = Color.WHITE if is_alive else Color(0.4, 0.4, 0.4, 0.6)
	scale = Vector2.ONE * (1.4 if is_boss else 1.0)
	update_facing(current_facing)


func _load_sprite(unit: Dictionary) -> void:
	var path: String = ""
	if team == "player":
		var race: String = str(unit.get("race", "human")).to_lower()
		var gender: String = str(unit.get("gender", "male")).to_lower()
		# Folder structure is {race}_{gender}/{race}_{gender}_S.png
		path = "%s%s_%s/%s_%s_S.png" % [CHAR_FOLDER, race, gender, race, gender]
	else:
		var sprite_id: String = str(unit.get("sprite_id", unit.get("id", "")))
		path = SPRITE_FOLDER + sprite_id + ".png"
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
		# v0.10.11 polish: scale the sprite to ~32px (was 46px) so
		# it fits cleanly inside the smaller 40px cell with margin.
		# Native sprite sizes vary (mobs are 64x64, character
		# portraits are 128x128), so compute scale from the
		# texture's native size.
		# - 128x128 human portrait: 32/128 = 0.25x = 32px ✓
		# - 64x64 mob sprite: 32/64 = 0.5x = 32px ✓
		var tex_size: Vector2 = _sprite.texture.get_size()
		var target_px: float = 32.0
		var native_max: float = maxf(tex_size.x, tex_size.y)
		if native_max <= 0.0:
			native_max = 64.0
		var scl: float = target_px / native_max
		_sprite.scale = Vector2(scl, scl)
	else:
		_sprite.texture = _make_placeholder_texture()
		_sprite.scale = Vector2.ONE * 1.2


func _character_race_dir(race: String) -> String:
	match race:
		"human", "upworlder":
			return "human"
		"mutant":
			return "mutant"
		"ai", "sentientai":
			return "sentientai"
		"cyborg":
			return "cyborg"
		"chthon":
			return "chthon"
		"vesper", "vesperid":
			return "vesperid"
		"nullborn":
			return "nullborn"
		"revenant":
			return "revenant"
		_:
			return "human"


func _make_placeholder_texture() -> Texture2D:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1.0))
	for i in range(20):
		img.set_pixel(i, 0, Color.BLACK)
		img.set_pixel(0, i, Color.BLACK)
		img.set_pixel(19, i, Color.BLACK)
		img.set_pixel(i, 19, Color.BLACK)
	return ImageTexture.create_from_image(img)


func _apply_team_palette() -> void:
	var hp_color: Color = COLOR_ENEMY
	if is_boss:
		hp_color = COLOR_BOSS
	elif team == "player":
		hp_color = COLOR_PLAYER
	elif team == "ally":
		hp_color = COLOR_ALLY
	# HP bar is owned by CombatFeedback now; just remember the color
	# for any future visual update.
	_team_hp_color = hp_color


func _refresh_hp() -> void:
	# HP bar/label live in CombatFeedback. Nothing to draw here.
	pass


func _refresh_ct() -> void:
	var ratio: float = clampf(float(current_ct) / 100.0, 0.0, 1.0)
	_ct_fill.size = Vector2((CELL_SIZE - 6) * ratio, 2)


func _refresh_name() -> void:
	_name_label.text = _unit_display_name()


func _refresh_name_plate() -> void:
	if _name_plate == null:
		return
	_name_plate.set_unit_info(display_name if not display_name.is_empty() else _unit_display_name(), team, is_boss)
	_name_plate.position = Vector2(-48, -CELL_SIZE * 0.5 - 24)


func _refresh_selection_arrow() -> void:
	if _selection_arrow == null:
		return
	_selection_arrow.position = Vector2(0, -CELL_SIZE * 0.5 - 48)


func _refresh_status() -> void:
	if is_boss:
		_status_label.text = "★ BOSS"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		_status_label.text = ""


func _unit_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if team == "player":
		return "Player"
	return unit_id.replace("_", " ").capitalize()


func move_to(grid_pos: Vector2i, animate: bool = true) -> void:
	_grid_pos = grid_pos
	# v0.10.10: square cell center.
	var target := Vector2(
		grid_pos.x * CELL_SIZE + CELL_SIZE * 0.5,
		grid_pos.y * CELL_SIZE + CELL_SIZE * 0.5,
	)
	if not animate:
		position = target
		return
	if _walk_tween != null and _walk_tween.is_valid():
		_walk_tween.kill()
	_walk_tween = create_tween()
	_walk_tween.set_trans(Tween.TRANS_QUAD)
	_walk_tween.set_ease(Tween.EASE_OUT)
	_walk_tween.tween_property(self, "position", target, WALK_DURATION)


func set_grid_pos(grid_pos: Vector2i) -> void:
	_grid_pos = grid_pos
	position = Vector2(
		grid_pos.x * CELL_SIZE + CELL_SIZE * 0.5,
		grid_pos.y * CELL_SIZE + CELL_SIZE * 0.5,
	)
	if _name_plate != null:
		_name_plate.position = Vector2(-48, -CELL_SIZE * 0.5 - 24)
	if _selection_arrow != null:
		_selection_arrow.position = Vector2(0, -CELL_SIZE * 0.5 - 48)


func play_attack_swing() -> void:
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	var forward := _facing_offset() * 6.0
	var start_pos := Vector2(
		_grid_pos.x * CELL_SIZE + CELL_SIZE * 0.5,
		_grid_pos.y * CELL_SIZE + CELL_SIZE * 0.5,
	)
	_swing_tween = create_tween()
	_swing_tween.tween_property(self, "position", start_pos + forward, SWING_DURATION * 0.5).set_trans(Tween.TRANS_SINE)
	_swing_tween.tween_property(self, "position", start_pos, SWING_DURATION * 0.5).set_trans(Tween.TRANS_SINE)


func flash_damage() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", Color(2.0, 0.5, 0.5), FLASH_DURATION)
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, FLASH_DURATION)


func play_death() -> void:
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	_death_tween = create_tween()
	_death_tween.set_parallel(true)
	_death_tween.tween_property(self, "modulate:a", 0.0, DEATH_FADE)
	_death_tween.tween_property(self, "scale", Vector2.ONE * 0.3, DEATH_FADE)
	_death_tween.set_parallel(false)
	_death_tween.tween_callback(func(): is_alive = false)


func set_active(active: bool) -> void:
	if _active_glow != null:
		_active_glow.visible = active
	if _selection_arrow != null:
		_selection_arrow.set_active(active)
		_selection_arrow.visible = active


func update_hp(new_hp: int) -> void:
	current_hp = new_hp
	if current_hp <= 0 and is_alive:
		is_alive = false
		play_death()
	_refresh_hp()


func update_ct(new_ct: int) -> void:
	current_ct = new_ct
	_refresh_ct()


func update_facing(facing: int) -> void:
	current_facing = facing
	# E/W flip the sprite to fake direction. N/S keep the south-facing
	# sprite (most mob sprites are authored south-facing).
	_sprite.flip_h = (facing == 1 or facing == 3)


func _facing_offset() -> Vector2:
	match current_facing:
		0:
			return Vector2(0, -1)
		1:
			return Vector2(1, 0)
		2:
			return Vector2(0, 1)
		3:
			return Vector2(-1, 0)
		_:
			return Vector2.ZERO


func refresh_from_unit(unit: Dictionary) -> void:
	var new_hp: int = int(unit.get("hp", current_hp))
	var new_ct: int = int(unit.get("ct", current_ct))
	var new_facing: int = int(unit.get("facing", current_facing))
	var was_alive: bool = is_alive
	if new_hp != current_hp:
		update_hp(new_hp)
	if new_ct != current_ct:
		update_ct(new_ct)
	if new_facing != current_facing:
		update_facing(new_facing)
	if was_alive and not is_alive:
		play_death()
