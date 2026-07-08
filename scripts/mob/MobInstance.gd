## MobInstance — Standard Godot node for a single mob on the overworld.
## Uses Sprite2D (not _draw()) so it works with any parent, no y_sort issues.
## Poolable: reset() reuses the node for a different mob type.
class_name MobInstance
extends Node2D

var mob_data: MobData = null
var _sprite: Sprite2D = null


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	add_child(_sprite)


## Configure from MobData. Loads the PNG and centres it.
func setup(data: MobData) -> void:
	mob_data = data
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		add_child(_sprite)
	var path := data.sprite_path()
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		if tex != null:
			_sprite.texture = tex
			_sprite.centered = true
			return
	_sprite.texture = null
	# Fallback: draw nothing — caller sees _sprite.texture == null


## Called by pool to return to neutral state for reuse.
func reset() -> void:
	mob_data = null
	if _sprite != null:
		_sprite.texture = null
