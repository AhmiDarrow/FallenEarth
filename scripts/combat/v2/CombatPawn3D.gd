class_name CombatPawn3D
extends CharacterBody3D
## 3D combat pawn — CharacterBody3D with billboard sprite.
##
## Adapted from ramaureirac/godot-tactical-rpg `TacticsPawn`.
## Displays a billboard sprite facing the camera, with name label
## and health info. Movement is handled by UnitMovementService3D.

const CombatTile3DScript = preload("res://scripts/combat/v2/CombatTile3D.gd")
const PAWN_HEIGHT: float = 0.6
const CELL_SIZE: float = 1.0
const SPRITE_FOLDER: String = "res://assets/mobs/"
const CHAR_FOLDER: String = "res://assets/characters/"

## The UnitResource this pawn reads from
var res: UnitResource

## Reference to arena node (for tile lookups that return CombatTile3D)
var arena_node: Node3D = null

## True while animating movement
var is_moving: bool = false

## Child references
var _sprite: Sprite3D
var _name_label: Label3D
var _hp_label: Label3D
var _tile_raycast: RayCast3D
var _collision: CollisionShape3D
var _anim_player: AnimationPlayer


func _ready() -> void:
	_build_collision()
	_build_tile_raycast()
	_build_sprite()
	_build_labels()
	_build_animations()


func _build_collision() -> void:
	_collision = CollisionShape3D.new()
	_collision.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.5
	capsule.radius = 0.3
	_collision.shape = capsule
	_collision.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.75, 0))
	collision_layer = 2
	collision_mask = 0
	add_child(_collision)


func _build_tile_raycast() -> void:
	_tile_raycast = RayCast3D.new()
	_tile_raycast.name = "TileRaycast"
	# Start above pawn and reach down through the tile — must pass through tile collision
	_tile_raycast.position = Vector3(0, 0.5, 0)
	_tile_raycast.target_position = Vector3(0, -2.0, 0)
	_tile_raycast.enabled = true
	add_child(_tile_raycast)


func _build_sprite() -> void:
	_sprite = Sprite3D.new()
	_sprite.name = "Sprite3D"
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.pixel_size = 0.01
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector3(0, PAWN_HEIGHT, 0)
	_sprite.modulate = Color.WHITE
	_sprite.render_priority = 0
	add_child(_sprite)


func _build_labels() -> void:
	# HP label (below name)
	_hp_label = Label3D.new()
	_hp_label.name = "HPLabel"
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.font_size = 28
	_hp_label.outline_size = 8
	_hp_label.outline_modulate = Color.BLACK
	_hp_label.position = Vector3(0, PAWN_HEIGHT + 1.0, 0)
	_hp_label.pixel_size = 0.01
	_hp_label.render_priority = 1
	add_child(_hp_label)

	# Name label (above HP)
	_name_label = Label3D.new()
	_name_label.name = "NameLabel"
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.font_size = 32
	_name_label.outline_size = 8
	_name_label.outline_modulate = Color.BLACK
	_name_label.position = Vector3(0, PAWN_HEIGHT + 1.4, 0)
	_name_label.pixel_size = 0.01
	_name_label.render_priority = 2
	add_child(_name_label)


func _build_animations() -> void:
	_anim_player = AnimationPlayer.new()
	_anim_player.name = "AnimationPlayer"
	add_child(_anim_player)


func setup_from_data(data: Dictionary, arena: ArenaResource, arena_node_ref: Node3D = null) -> void:
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
	arena_node = arena_node_ref
	# Position on grid — use local position since we're a child of the Arena
	position = Vector3(
		res.grid_pos.x * CELL_SIZE,
		0.0,
		res.grid_pos.y * CELL_SIZE
	)
	_load_sprite()
	_refresh_labels()


func _load_sprite() -> void:
	var path: String = ""
	if res.team == "player":
		path = "%s%s_%s/%s_%s_S.png" % [CHAR_FOLDER, res.race, res.gender, res.race, res.gender]
	else:
		path = SPRITE_FOLDER + res.sprite_id + ".png"
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
		_sprite.scale = Vector3(1.5, 1.5, 1.5)
	else:
		_sprite.texture = _make_placeholder()
		_sprite.scale = Vector3(1.2, 1.2, 1.2)


func _make_placeholder() -> Texture2D:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1.0))
	for i in range(32):
		img.set_pixel(i, 0, Color.BLACK)
		img.set_pixel(0, i, Color.BLACK)
		img.set_pixel(31, i, Color.BLACK)
		img.set_pixel(i, 31, Color.BLACK)
	# Simple face
	img.set_pixel(10, 12, Color.BLACK)
	img.set_pixel(20, 12, Color.BLACK)
	img.set_pixel(12, 18, Color.RED)
	img.set_pixel(14, 18, Color.RED)
	img.set_pixel(16, 18, Color.RED)
	img.set_pixel(18, 18, Color.RED)
	return ImageTexture.create_from_image(img)


func _refresh_labels() -> void:
	if res == null:
		return
	_name_label.text = res.display_name if res.display_name != "" else res.unit_id
	_hp_label.text = "%d/%d" % [res.current_hp, res.max_hp]


func is_alive() -> bool:
	return res != null and res.current_hp > 0


func can_pawn_move() -> bool:
	return res != null and res.can_move and is_alive()


func can_pawn_attack() -> bool:
	return res != null and res.can_act and is_alive()


func can_act() -> bool:
	return res != null and (res.can_move or res.can_act) and is_alive()


func get_tile() -> CombatTile3D:
	if _tile_raycast and _tile_raycast.is_colliding():
		var collider: Node3D = _tile_raycast.get_collider()
		if collider is CombatTile3D:
			return collider as CombatTile3D
	# Fallback: look up tile by grid_pos from arena
	if arena_node != null and res != null:
		var tile = arena_node.get_tile(res.grid_pos.x, res.grid_pos.y)
		if tile != null and tile is CombatTile3D:
			return tile as CombatTile3D
	return null


func reset_turn() -> void:
	if res != null:
		res.reset_turn()


func end_pawn_turn() -> void:
	if res != null:
		res.end_move()
		res.end_action()


func update_hp(new_hp: int) -> void:
	if res == null:
		return
	res.current_hp = new_hp
	_refresh_labels()
	if res.current_hp <= 0:
		_play_death()


func _play_death() -> void:
	_sprite.modulate = Color(0.4, 0.4, 0.4, 0.5)
	scale = Vector3(0.6, 0.6, 0.6)
	_anim_player.stop()


func show_stats(v: bool) -> void:
	_name_label.visible = v
	_hp_label.visible = v


func move_to_world_pos(world_pos: Vector3) -> void:
	position = Vector3(world_pos.x, 0.0, world_pos.z)
	if res:
		res.grid_pos = Vector2i(int(world_pos.x / CELL_SIZE), int(world_pos.z / CELL_SIZE))
