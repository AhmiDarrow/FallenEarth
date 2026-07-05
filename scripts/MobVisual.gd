## MobVisual — Sprite renderer for mobs/enemies.
##
## Renders the 64x64 PixelLab sprite at native size (no scale-down). Mobs sit
## at the cell center of their (local_x, local_y) so the y-sort in the parent
## MobLayer stacks them correctly with the player and each other. Pixel-art
## nearest filter keeps the edges crisp. If a sprite is missing, this node
## stays empty and logs once — no procedural draw fallback, callers should
## surface their own marker if they want one.
class_name MobVisual
extends Node2D

const SPRITE_DIR := "res://assets/mobs/"

var _sprite: Sprite2D = null
var _mob_id: String = ""


func set_mob_sprite(mob_id: String) -> void:
	_mob_id = mob_id.to_lower()
	_replace_sprite()


func get_mob_id() -> String:
	return _mob_id


func _replace_sprite() -> void:
	if _sprite != null:
		_sprite.queue_free()
		_sprite = null

	if _mob_id.is_empty():
		return

	var path := "%s%s.png" % [SPRITE_DIR, _mob_id]
	if not ResourceLoader.exists(path):
		push_warning("[MobVisual] No sprite for '%s' (looked in %s)" % [_mob_id, path])
		return

	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_warning("[MobVisual] Load returned null for: %s" % path)
		return

	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	print("[MobVisual] Loaded sprite: %s (%dx%d)" % [path, tex.get_width(), tex.get_height()])
