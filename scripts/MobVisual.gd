## MobVisual — Sprite renderer for mobs/enemies.
##
## Renders the 64x64 PixelLab sprite at native size (no scale-down). Mobs sit
## at the cell center of their (local_x, local_y) so the y-sort in the parent
## MobLayer stacks them correctly with the player and each other. Pixel-art
## nearest filter keeps the edges crisp.
##
## IMPORTANT: This mirrors CharacterVisual (the player renderer, which works) by
## drawing the texture directly in _draw() instead of using a Sprite2D child.
## Sprite2D children inside MobLayer were found to not render in this project
## (logs showed texture loaded + visible=true but nothing drawn), whereas
## _draw() via draw_texture renders reliably.
class_name MobVisual
extends Node2D

const SPRITE_DIR := "res://assets/mobs/"

var _texture: Texture2D = null
var _mob_id: String = ""
var _has_sprite: bool = false


func set_mob_sprite(mob_id: String) -> void:
	_mob_id = mob_id.to_lower()
	_replace_sprite()
	queue_redraw()


func get_mob_id() -> String:
	return _mob_id


func _replace_sprite() -> void:
	_texture = null
	_has_sprite = false

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

	_texture = tex
	_has_sprite = true
	print("[MobVisual] Loaded texture: %s (%dx%d) pos=%s z=%d visible=%s" % [
		path, tex.get_width(), tex.get_height(),
		str(position), z_index, str(visible)
	])


func _draw() -> void:
	if _has_sprite and _texture != null:
		# Center the 64x64 sprite on the node origin (matches Sprite2D centered=true)
		var offset := Vector2(-_texture.get_width() * 0.5, -_texture.get_height() * 0.5)
		draw_texture(_texture, offset)
	else:
		# Bright magenta rect — impossible to miss on any biome. Confirms the
		# node position is correct even when the sprite file is missing.
		draw_rect(Rect2(Vector2(-12, -12), Vector2(24, 24)), Color.MAGENTA)
		draw_rect(Rect2(Vector2(-11, -11), Vector2(22, 22)), Color(1.0, 0.0, 1.0, 0.3))
		if not _mob_id.is_empty():
			var label_offset := Vector2(-_mob_id.length() * 2.5, -20)
			draw_string(ThemeDB.fallback_font, label_offset, _mob_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
