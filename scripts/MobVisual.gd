## MobVisual — Sprite rendering for mobs/enemies.
## Loads sprite from assets/mobs/{mob_id}.png

extends Node2D

var _sprite_node: Sprite2D = null
var _mob_id: String = ""


func _ready() -> void:
	pass


func set_mob_sprite(mob_id: String) -> void:
	_mob_id = mob_id.to_lower()
	
	# Remove old sprite
	if _sprite_node != null:
		_sprite_node.queue_free()
		_sprite_node = null
	
	# Try to load sprite
	var sprite_path: String = "res://assets/mobs/%s.png" % _mob_id
	if ResourceLoader.exists(sprite_path):
		var tex: Texture2D = load(sprite_path) as Texture2D
		if tex != null:
			_sprite_node = Sprite2D.new()
			_sprite_node.texture = tex
			_sprite_node.centered = true
			_sprite_node.scale = Vector2(0.5, 0.5)  # Scale 64px to 32px
			add_child(_sprite_node)
			print("[MobVisual] Loaded sprite: %s" % sprite_path)
			return
	
	print("[MobVisual] WARNING: No sprite found for %s" % _mob_id)


func _process(delta: float) -> void:
	pass
