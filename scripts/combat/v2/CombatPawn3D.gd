class_name CombatPawn3D
extends CharacterBody3D

const CombatTile3DScript = preload("res://scripts/combat/v2/CombatTile3D.gd")
const PAWN_HEIGHT: float = 0.6
const SPRITE_FOLDER: String = "res://assets/mobs/"
const CHAR_FOLDER: String = "res://assets/characters/"

var res: UnitResource

var arena_node: Node3D = null

var is_moving: bool = false

var _sprite: Sprite3D
var _name_label: Label3D
var _hp_label: Label3D
var _tile_raycast: RayCast3D
var _collision: CollisionShape3D
var _anim_player: AnimationPlayer
var _team_ring: MeshInstance3D

## Sprite animation state (manual frame cycling for Sprite3D)
var _anim_library: Dictionary = {}  # anim_name → Array[Texture2D]
var _anim_speeds: Dictionary = {}   # anim_name → speed
var _anim_loops: Dictionary = {}    # anim_name → bool
var _anim_frames: Array[Texture2D] = []
var _anim_speed: float = 5.0
var _anim_loop: bool = true
var _anim_timer: float = 0.0
var _anim_index: int = 0
var _anim_name: String = "idle"


func _ready() -> void:
	_build_collision()
	_build_tile_raycast()
	_build_sprite()
	_build_labels()
	_build_team_ring()
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
	_tile_raycast.position = Vector3(0, 0.5, 0)
	_tile_raycast.target_position = Vector3(0, -2.0, 0)
	_tile_raycast.enabled = true
	add_child(_tile_raycast)


func _build_sprite() -> void:
	_sprite = Sprite3D.new()
	_sprite.name = "Sprite3D"
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.pixel_size = 0.01
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector3(0, PAWN_HEIGHT, 0)
	_sprite.modulate = Color.WHITE
	_sprite.render_priority = 0
	add_child(_sprite)


func _build_labels() -> void:
	_hp_label = Label3D.new()
	_hp_label.name = "HPLabel"
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.font_size = 16
	_hp_label.outline_size = 4
	_hp_label.outline_modulate = Color.BLACK
	_hp_label.no_depth_test = true
	_hp_label.position = Vector3(0, PAWN_HEIGHT + 1.0, 0)
	_hp_label.pixel_size = 0.012
	_hp_label.render_priority = 1
	add_child(_hp_label)

	_name_label = Label3D.new()
	_name_label.name = "NameLabel"
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.font_size = 18
	_name_label.outline_size = 4
	_name_label.outline_modulate = Color.BLACK
	_name_label.no_depth_test = true
	_name_label.position = Vector3(0, PAWN_HEIGHT + 1.3, 0)
	_name_label.pixel_size = 0.012
	_name_label.render_priority = 2
	add_child(_name_label)


func _build_team_ring() -> void:
	_team_ring = MeshInstance3D.new()
	_team_ring.name = "TeamRing"
	# Use a flat cylinder as a team-colored ring under the pawn
	var ring := CylinderMesh.new()
	ring.top_radius = 0.5
	ring.bottom_radius = 0.5
	ring.height = 0.02
	ring.radial_segments = 24
	_team_ring.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	# Color set in setup_from_data based on team
	_team_ring.material_override = mat
	_team_ring.position = Vector3(0, 0.01, 0)
	_team_ring.visible = false
	add_child(_team_ring)


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
	res.level = int(data.get("level", 1))
	res.max_hp = int(data.get("max_hp", 1))
	res.current_hp = int(data.get("hp", res.max_hp))
	res.max_mp = int(data.get("mp_max", 0))
	res.current_mp = int(data.get("mp", res.max_mp))
	res.attack = int(data.get("attack", 0)) + int(data.get("attack_bonus", 0))
	res.defense = int(data.get("defense", 0)) + int(data.get("armor_bonus", 0))
	res.speed = int(data.get("speed", 0))
	res.move = maxi(1, int(data.get("move", 3)) - 1 + int(sqrt(float(res.level) / 10.0)))
	res.jump = int(data.get("jump", 1))
	res.attack_range = int(data.get("attack_range", 1))
	res.sprite_id = str(data.get("sprite_id", res.unit_id))
	res.facing = int(data.get("facing", 2))
	arena_node = arena_node_ref
	position = Vector3(
		res.grid_pos.x * CombatTile3D.CELL_SIZE,
		0.0,
		res.grid_pos.y * CombatTile3D.CELL_SIZE
	)
	_load_sprite()
	_refresh_labels()
	_setup_team_ring()


func _load_sprite() -> void:
	_anim_library.clear()
	_anim_speeds.clear()
	_anim_loops.clear()

	var tres_path: String = ""
	var fallback_png: String = ""
	if res.team == "player":
		var base: String = "%s%s_%s/%s_%s" % [CHAR_FOLDER, res.race, res.gender, res.race, res.gender]
		tres_path = base + ".tres"
		fallback_png = base + "_S.png"
	else:
		var base: String = SPRITE_FOLDER + res.sprite_id
		tres_path = base + "/" + res.sprite_id + ".tres"
		fallback_png = base + ".png"

	var scale_vec := Vector3(1.0, 1.0, 1.0)

	if ResourceLoader.exists(tres_path):
		var sf: SpriteFrames = load(tres_path)
		var anim_names: PackedStringArray = sf.get_animation_names()
		for aname in anim_names:
			var fc: int = sf.get_frame_count(aname)
			var frames: Array[Texture2D] = []
			for i in range(fc):
				frames.append(sf.get_frame_texture(aname, i))
			_anim_library[aname] = frames
			_anim_speeds[aname] = sf.get_animation_speed(aname)
			_anim_loops[aname] = sf.get_animation_loop(aname)
	elif ResourceLoader.exists(fallback_png):
		_anim_library["idle"] = [load(fallback_png)]
		_anim_speeds["idle"] = 5.0
		_anim_loops["idle"] = true
	else:
		_anim_library["idle"] = [_make_placeholder()]
		_anim_speeds["idle"] = 5.0
		_anim_loops["idle"] = true
		scale_vec = Vector3(0.8, 0.8, 0.8)

	_switch_anim("idle")
	_sprite.scale = scale_vec


func _switch_anim(anim_name: String) -> void:
	if not _anim_library.has(anim_name):
		anim_name = "idle" if _anim_library.has("idle") else ""
		if anim_name.is_empty():
			return
	_anim_frames = _anim_library[anim_name]
	_anim_speed = _anim_speeds.get(anim_name, 5.0)
	_anim_loop = _anim_loops.get(anim_name, true)
	_anim_index = 0
	_anim_timer = 0.0
	_anim_name = anim_name
	if not _anim_frames.is_empty():
		_sprite.texture = _anim_frames[0]
		_snap_feet_to_tile()


func _snap_feet_to_tile() -> void:
	if _sprite.texture == null:
		return
	var tex_h: float = float(_sprite.texture.get_height())
	# Bottom of centered sprite = sprite_y - (tex_h * 0.5 * pixel_size).
	# Place bottom at TILE_HEIGHT so feet sit on top of the tile.
	_sprite.position.y = CombatTile3D.TILE_HEIGHT + tex_h * 0.5 * _sprite.pixel_size
	# Keep labels above the sprite top.
	var top_y: float = _sprite.position.y + tex_h * 0.5 * _sprite.pixel_size
	_hp_label.position.y = top_y + 0.3
	_name_label.position.y = top_y + 0.6


func _make_placeholder() -> Texture2D:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1.0))
	for i in range(32):
		img.set_pixel(i, 0, Color.BLACK)
		img.set_pixel(0, i, Color.BLACK)
		img.set_pixel(31, i, Color.BLACK)
		img.set_pixel(i, 31, Color.BLACK)
	img.set_pixel(10, 12, Color.BLACK)
	img.set_pixel(20, 12, Color.BLACK)
	img.set_pixel(12, 18, Color.RED)
	img.set_pixel(14, 18, Color.RED)
	img.set_pixel(16, 18, Color.RED)
	img.set_pixel(18, 18, Color.RED)
	return ImageTexture.create_from_image(img)


func _setup_team_ring() -> void:
	if _team_ring == null:
		return
	var mat: StandardMaterial3D = _team_ring.material_override as StandardMaterial3D
	if mat == null:
		return
	if res == null:
		return
	match res.team:
		"player":
			mat.albedo_color = Color(0.2, 0.6, 1.0, 0.5)
			_team_ring.visible = true
		"enemy":
			mat.albedo_color = Color(1.0, 0.2, 0.2, 0.5)
			_team_ring.visible = true
		"ally":
			mat.albedo_color = Color(0.2, 1.0, 0.4, 0.5)
			_team_ring.visible = true
		_:
			_team_ring.visible = false


func _process(delta: float) -> void:
	if _anim_frames.is_empty():
		return
	_anim_timer += delta
	var frame_duration: float = 1.0 / maxf(_anim_speed, 0.001)
	if _anim_timer >= frame_duration:
		_anim_timer -= frame_duration
		_anim_index += 1
		if _anim_index >= _anim_frames.size():
			if _anim_loop:
				_anim_index = 0
			else:
				_anim_index = _anim_frames.size() - 1
		_sprite.texture = _anim_frames[_anim_index]


func play_anim(anim_name: String) -> void:
	if _anim_name == anim_name:
		return
	_switch_anim(anim_name)


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


func show_damage_text(amount: int) -> void:
	var lbl := Label3D.new()
	lbl.pixel_size = 0.01
	lbl.font_size = 32
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	if amount <= 0:
		lbl.text = "MISS"
		lbl.modulate = Color(1.0, 1.0, 1.0)
	else:
		lbl.text = str(amount)
		lbl.modulate = Color(1.0, 0.3, 0.3)
	lbl.position = Vector3(0, 1.2, 0)
	add_child(lbl)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", 1.8, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.set_parallel(false)
	tween.tween_callback(lbl.queue_free)


func _show_loot_text(item_name: String) -> void:
	var lbl := Label3D.new()
	lbl.pixel_size = 0.01
	lbl.font_size = 20
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.text = "+%s" % item_name
	lbl.modulate = Color(0.3, 1.0, 0.3)
	lbl.position = Vector3(0, 1.4, 0)
	add_child(lbl)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", 2.0, 1.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "modulate:a", 0.0, 1.0).set_delay(0.3)
	tween.set_parallel(false)
	tween.tween_callback(lbl.queue_free)


func _play_death() -> void:
	if _anim_library.has("death"):
		_switch_anim("death")
		# Calculate death anim duration from speed + frame count
		var fc: int = _anim_frames.size()
		var dur: float = float(fc) / maxf(_anim_speed, 0.001)
		var tween: Tween = create_tween().set_delay(dur)
		tween.tween_callback(func():
			if is_inside_tree():
				_sprite.modulate = Color(0.4, 0.4, 0.4, 0.5)
				scale = Vector3(0.6, 0.6, 0.6)
		)
	else:
		_sprite.modulate = Color(0.4, 0.4, 0.4, 0.5)
		scale = Vector3(0.6, 0.6, 0.6)
	_anim_player.stop()


func show_stats(v: bool) -> void:
	_name_label.visible = v
	_hp_label.visible = v


func move_to_world_pos(world_pos: Vector3) -> void:
	position = Vector3(world_pos.x, 0.0, world_pos.z)
	if res:
		res.grid_pos = Vector2i(int(world_pos.x / CombatTile3D.CELL_SIZE), int(world_pos.z / CombatTile3D.CELL_SIZE))
