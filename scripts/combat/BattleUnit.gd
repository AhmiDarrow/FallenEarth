## BattleUnit — Per-unit node on the battle grid.
##
## Renders the mob sprite (with horizontal flip for E/W facing), HP
## bar overlay, CT progress bar, name label, and animates walks,
## attacks, hits, and deaths. Owns the visual state for one unit; the
## engine (CombatManager) decides what they do.
class_name BattleUnit extends Node2D

const CELL_SIZE := 24
const SPRITE_FOLDER := "res://assets/mobs/"
const CHAR_FOLDER := "res://assets/characters/"

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


func _ready() -> void:
	_build_children()
	_active_glow.visible = false
	modulate = Color.WHITE if is_alive else Color(0.4, 0.4, 0.4, 0.6)
	scale = Vector2.ONE * (1.4 if is_boss else 1.0)


func _build_children() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = true
	_sprite.position = Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	_sprite.z_index = 10
	add_child(_sprite)

	_active_glow = Sprite2D.new()
	_active_glow.name = "ActiveGlow"
	_active_glow.centered = true
	_active_glow.position = Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	_active_glow.modulate = Color(1.0, 0.95, 0.5, 0.6)
	_active_glow.z_index = 9
	add_child(_active_glow)

	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 2)
	_name_label.add_theme_font_size_override("font_size", 8)
	_name_label.position = Vector2(-CELL_SIZE * 0.5, -CELL_SIZE * 0.5 - 18)
	_name_label.size = Vector2(CELL_SIZE * 2, 12)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.z_index = 12
	add_child(_name_label)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 2)
	_status_label.add_theme_font_size_override("font_size", 7)
	_status_label.position = Vector2(-CELL_SIZE * 0.5, CELL_SIZE * 0.5 + 2)
	_status_label.size = Vector2(CELL_SIZE * 2, 10)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.z_index = 12
	add_child(_status_label)

	# HP bar (with X/X label) is rendered by CombatFeedback so the
	# unit just owns the name + CT mini-bar. Avoids the previous
	# double-bar look where the CombatFeedback bar overlapped the
	# unit's internal bar.
	_hp_bg = null
	_hp_fill = null
	_hp_label = null

	_ct_bg = ColorRect.new()
	_ct_bg.name = "CTBg"
	_ct_bg.color = Color(0.08, 0.06, 0.05, 0.85)
	_ct_bg.position = Vector2(2, -3)
	_ct_bg.size = Vector2(CELL_SIZE - 4, 3)
	_ct_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ct_bg.z_index = 11
	add_child(_ct_bg)

	_ct_fill = ColorRect.new()
	_ct_fill.name = "CTFill"
	_ct_fill.color = CT_BAR_FILL
	_ct_fill.position = Vector2(3, -2)
	_ct_fill.size = Vector2(0, 1)
	_ct_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ct_fill.z_index = 12
	add_child(_ct_fill)


func setup_from_data(unit: Dictionary, cell_size: int) -> void:
	unit_id = str(unit.get("id", ""))
	team = str(unit.get("team", "enemy"))
	max_hp = int(unit.get("max_hp", 1))
	current_hp = int(unit.get("hp", max_hp))
	current_ct = int(unit.get("ct", 0))
	current_facing = int(unit.get("facing", 0))
	is_boss = bool(unit.get("is_boss", false))
	is_alive = current_hp > 0
	_grid_pos = unit.get("pos", Vector2i.ZERO)
	position = Vector2(_grid_pos.x * cell_size, _grid_pos.y * cell_size)
	_load_sprite(unit)
	_apply_team_palette()
	_refresh_hp()
	_refresh_ct()
	_refresh_name()
	_refresh_status()
	if _active_glow != null:
		_active_glow.visible = false
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
		# Scale sprite to fit the cell. Most mob sprites are 64x64
		# natives. Cap so giant bosses don't blow out the cell.
		_sprite.scale = Vector2.ONE * 0.5
	else:
		_sprite.texture = _make_placeholder_texture()
		_sprite.scale = Vector2.ONE * 0.7


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
	_ct_fill.size = Vector2((CELL_SIZE - 6) * ratio, 1)


func _refresh_name() -> void:
	_name_label.text = _unit_display_name()


func _refresh_status() -> void:
	if is_boss:
		_status_label.text = "★ BOSS"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		_status_label.text = ""


func _unit_display_name() -> String:
	if team == "player":
		return "Player"
	return unit_id.replace("_", " ").capitalize()


func move_to(grid_pos: Vector2i, animate: bool = true) -> void:
	_grid_pos = grid_pos
	var target := Vector2(grid_pos.x * CELL_SIZE, grid_pos.y * CELL_SIZE)
	if not animate:
		position = target
		return
	if _walk_tween != null and _walk_tween.is_valid():
		_walk_tween.kill()
	_walk_tween = create_tween()
	_walk_tween.set_trans(Tween.TRANS_QUAD)
	_walk_tween.set_ease(Tween.EASE_OUT)
	_walk_tween.tween_property(self, "position", target, WALK_DURATION)


func play_attack_swing() -> void:
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	var forward := _facing_offset() * 6.0
	var start_pos := Vector2(_grid_pos.x * CELL_SIZE, _grid_pos.y * CELL_SIZE)
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
