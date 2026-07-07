## MobVisual — Sprite renderer for mobs/enemies.
##
## Loads the mob's PNG from res://assets/mobs/ and draws it via _draw().
## _draw() is proven to render on world_grid (the earlier magenta debug rect
## showed reliably). If the sprite file is genuinely missing we fall back to a
## small magenta marker so the position stays visible for debugging.
class_name MobVisual
extends Node2D

const SPRITE_DIR := "res://assets/mobs/"

var _texture: Texture2D = null
var _mob_id: String = ""


func set_mob_sprite(mob_id: String) -> void:
	_mob_id = mob_id.to_lower()
	_load_texture()
	queue_redraw()


func get_mob_id() -> String:
	return _mob_id


func _load_texture() -> void:
	_texture = null
	if _mob_id.is_empty():
		return
	# Convert underscores in mob_id to hyphens for the PNG filename
	var path := "%s%s.png" % [SPRITE_DIR, _mob_id.replace("_", "-")]
	if not ResourceLoader.exists(path):
		push_warning("[MobVisual] No sprite for '%s' (looked in %s)" % [_mob_id, path])
		return
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_warning("[MobVisual] Load returned null for: %s" % path)
		return
	_texture = tex


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _texture != null:
		var offset := Vector2(-_texture.get_width() * 0.5, -_texture.get_height() * 0.5)
		draw_texture(_texture, offset)
	else:
		# Fallback marker only when the sprite is genuinely missing.
		draw_rect(Rect2(Vector2(-16, -16), Vector2(32, 32)), Color.MAGENTA)
		draw_rect(Rect2(Vector2(-15, -15), Vector2(30, 30)), Color(1.0, 0.0, 1.0, 0.4))
	if not _mob_id.is_empty():
		var label_offset := Vector2(-_mob_id.length() * 2.5, -24)
		draw_string(ThemeDB.fallback_font, label_offset, _mob_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
