class_name CombatUnit
extends Node2D
## One unit on the combat grid. The visual; reads from UnitResource.
##
## Adapted from ramaureirac/godot-tactical-rpg `TacticsPawn` —
## much simpler in 2D (no CharacterBody3D, no AnimationTree), but
## follows the same pattern: a node that owns a resource, updates
## its position from the resource, and is driven by services.
##
## The CombatUnit does NOT own combat logic — it just renders the
## unit sprite + name plate + HP bar and animates position
## changes. All decisions live in the services.

const CELL_SIZE: int = 40
const SPRITE_FOLDER: String = "res://assets/mobs/"
const CHAR_FOLDER: String = "res://assets/characters/"

## v0.11.0: The UnitResource this unit reads from. Set by
## setup_from_data().
var res: UnitResource

## v0.11.0: Reference to the ArenaResource, used for
## tile occupancy when the unit moves.
var arena_resource: ArenaResource

## v0.11.0: True while the unit is animating along its move
## path. Set by the UnitMovementService.
var is_moving: bool = false

## v0.11.0: Visual children
var _sprite: Sprite2D
var _name_label: Label
var _ct_bar: ColorRect
var _ct_fill: ColorRect
var _name_plate: Panel


## v0.11.0: Sprite scaling — 32px target (fits a 40px cell with
## 4px margin per side). Computed from the texture's native
## size so any sprite (64x64 mob, 128x128 human portrait) auto-fits.
func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = true
	_sprite.z_index = 10
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

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

	# Tiny CT bar (charge time) — center-bottom of the cell.
	_ct_bar = ColorRect.new()
	_ct_bar.name = "CTBar"
	_ct_bar.color = Color(0.08, 0.06, 0.05, 0.85)
	_ct_bar.position = Vector2(-CELL_SIZE * 0.5 + 2, CELL_SIZE * 0.5 - 8)
	_ct_bar.size = Vector2(CELL_SIZE - 4, 4)
	_ct_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ct_bar.z_index = 11
	add_child(_ct_bar)

	_ct_fill = ColorRect.new()
	_ct_fill.name = "CTFill"
	_ct_fill.color = Color(0.95, 0.80, 0.30, 1.0)
	_ct_fill.position = Vector2(-CELL_SIZE * 0.5 + 3, CELL_SIZE * 0.5 - 7)
	_ct_fill.size = Vector2(0, 2)
	_ct_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ct_fill.z_index = 12
	add_child(_ct_fill)

	_name_plate = Panel.new()
	_name_plate.name = "NamePlate"
	_name_plate.position = Vector2(-CELL_SIZE * 0.5, -CELL_SIZE * 0.5 - 22)
	_name_plate.size = Vector2(CELL_SIZE, 14)
	_name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_plate.z_index = 14
	add_child(_name_plate)


## v0.11.0: Configure the unit from a data dictionary. The
## dictionary is the same shape EncounterBuilder uses today, so
## the existing encounter pipeline keeps working.
func setup_from_data(data: Dictionary, arena: ArenaResource) -> void:
	res = UnitResource.new()
	res.unit_id = str(data.get("id", ""))
	res.display_name = str(data.get("name", ""))
	res.team = str(data.get("team", "enemy"))
	res.class_id = str(data.get("class", ""))
	res.race = str(data.get("race", "human"))
	res.gender = str(data.get("gender", "male"))
	res.is_boss = bool(data.get("is_boss", false))
	res.grid_pos = data.get("pos", Vector2i.ZERO)
	res.max_hp = int(data.get("max_hp", 1))
	res.current_hp = int(data.get("hp", res.max_hp))
	res.max_mp = int(data.get("mp_max", 0))
	res.current_mp = int(data.get("mp", res.max_mp))
	res.attack = int(data.get("attack", 0)) + int(data.get("attack_bonus", 0))
	res.defense = int(data.get("defense", 0)) + int(data.get("armor_bonus", 0))
	res.speed = int(data.get("speed", 0))
	res.move = int(data.get("move", 0))
	res.jump = int(data.get("jump", 1))
	res.attack_range = int(data.get("attack_range", 1))
	res.sprite_id = str(data.get("sprite_id", res.unit_id))
	res.facing = int(data.get("facing", 2))
	arena_resource = arena
	# Position the unit at the cell center.
	position = Vector2(res.grid_pos.x * CELL_SIZE + CELL_SIZE * 0.5, res.grid_pos.y * CELL_SIZE + CELL_SIZE * 0.5)
	# Set the tile occupier.
	if arena != null:
		var tile: TileResource = arena.get_tile(res.grid_pos.x, res.grid_pos.y)
		if tile != null:
			tile.occupier = self
	# Load the sprite (32px target on 40px cell).
	_load_sprite()
	_refresh_name()
	_refresh_ct()


## v0.11.0: Load the unit's sprite. Tries player portrait first
## (race_gender/race_gender_S.png), then mob sprite
## (assets/mobs/{sprite_id}.png), then a procedural placeholder.
func _load_sprite() -> void:
	var path: String = ""
	if res.team == "player":
		path = "%s%s_%s/%s_%s_S.png" % [CHAR_FOLDER, res.race, res.gender, res.race, res.gender]
	else:
		path = SPRITE_FOLDER + res.sprite_id + ".png"
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
		# Scale to 32px target.
		var tex_size: Vector2 = _sprite.texture.get_size()
		var native_max: float = maxf(tex_size.x, tex_size.y)
		if native_max > 0:
			_sprite.scale = Vector2(32.0 / native_max, 32.0 / native_max)
		else:
			_sprite.scale = Vector2.ONE
	else:
		_sprite.texture = _make_placeholder()
		_sprite.scale = Vector2.ONE * 1.2


func _make_placeholder() -> Texture2D:
	var img: Image = Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1.0))
	for i in range(20):
		img.set_pixel(i, 0, Color.BLACK)
		img.set_pixel(0, i, Color.BLACK)
		img.set_pixel(19, i, Color.BLACK)
		img.set_pixel(i, 19, Color.BLACK)
	return ImageTexture.create_from_image(img)


func _refresh_name() -> void:
	if res == null:
		return
	_name_label.text = res.display_name if res.display_name != "" else res.unit_id


func _refresh_ct() -> void:
	# v0.11.0: CT bar shows current movement budget remaining
	# (so the player can see how much they can still move). The
	# full FFT CT system is deferred.
	if res == null:
		return
	# No-op for now; the CT bar is decorative in v0.11.0.
	pass


## v0.11.0: Snap the unit to a new grid position (no tween).
## Used by the encounter builder to place units at the start of
## combat.
func set_grid_pos(pos: Vector2i) -> void:
	if res == null:
		return
	res.grid_pos = pos
	position = Vector2(pos.x * CELL_SIZE + CELL_SIZE * 0.5, pos.y * CELL_SIZE + CELL_SIZE * 0.5)
	if arena_resource != null:
		var tile: TileResource = arena_resource.get_tile(pos.x, pos.y)
		if tile != null:
			tile.occupier = self


## v0.11.0: Update HP (called by UnitCombatService after an
## attack). Triggers the death animation if HP hits 0.
func update_hp(new_hp: int) -> void:
	if res == null:
		return
	res.current_hp = new_hp
	if res.current_hp <= 0:
		_play_death()


func _play_death() -> void:
	modulate = Color(0.4, 0.4, 0.4, 0.5)
	scale = Vector2.ONE * 0.6
