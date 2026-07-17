class_name DestructibleDecor
extends StaticBody3D

signal decor_destroyed(decor: DestructibleDecor, grid_pos: Vector2i)

const SPRITE_SIZE: float = 1.0
const COLLISION_RADIUS: float = 0.3
const COLLISION_HEIGHT: float = 0.6

var decor_type: String = ""
var variant_index: int = 0
var hp: int = 30
var hp_max: int = 30
var grid_pos: Vector2i
var alive: bool = true

var _sprite: Sprite3D
var _collision_shape: CollisionShape3D


func _ready() -> void:
	_build_sprite()
	_build_collision()


func _build_sprite() -> void:
	_sprite = Sprite3D.new()
	_sprite.name = "DecorSprite"
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.pixel_size = 0.01
	_sprite.centered = true
	add_child(_sprite)

	var path: String = "res://assets/battle_decor/%s/%s_%d.png" % [decor_type, decor_type, variant_index]
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
		var tex: Texture2D = _sprite.texture
		var tex_size: Vector2 = tex.get_size()
		var aspect: float = tex_size.y / tex_size.x if tex_size.x > 0 else 1.0
		_sprite.scale = Vector3(SPRITE_SIZE, SPRITE_SIZE * aspect, 1.0)
	else:
		_sprite.scale = Vector3(SPRITE_SIZE, SPRITE_SIZE, 1.0)
	_snap_feet_to_tile()


func _build_collision() -> void:
	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "DecorCollision"
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = COLLISION_RADIUS
	shape.height = COLLISION_HEIGHT
	_collision_shape.shape = shape
	_collision_shape.position.y = COLLISION_HEIGHT * 0.5
	add_child(_collision_shape)


func _snap_feet_to_tile() -> void:
	if _sprite.texture == null:
		return
	var tex_h: float = float(_sprite.texture.get_height())
	# Bottom of centered sprite = sprite_y - (tex_h * 0.5 * pixel_size).
	# Place bottom at TILE_HEIGHT so feet sit on top of the tile.
	_sprite.position.y = CombatTile3D.TILE_HEIGHT + tex_h * 0.5 * _sprite.pixel_size


func take_damage(amount: int) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0:
		alive = false
		_destroy()


func _destroy() -> void:
	decor_destroyed.emit(self, grid_pos)
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(queue_free)


func setup(type_name: String, variant: int, initial_hp: int = 30, pos: Vector2i = Vector2i.ZERO) -> void:
	decor_type = type_name
	variant_index = variant
	hp = initial_hp
	hp_max = initial_hp
	grid_pos = pos
