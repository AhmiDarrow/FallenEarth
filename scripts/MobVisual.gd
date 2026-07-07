## MobVisual — Sprite renderer for mobs/enemies.
##
## Renders the 64x64 PixelLab sprite at native size (no scale-down). Mobs sit
## at the cell center of their (local_x, local_y) so the y-sort in the parent
## MobLayer stacks them correctly with the player and each other. Pixel-art
## nearest filter keeps the edges crisp. If a sprite is missing, draws a
## bright debug rectangle so the mob position is always confirmed visible.
class_name MobVisual
extends Node2D

const SPRITE_DIR := "res://assets/mobs/"

var _sprite: Sprite2D = null
var _mob_id: String = ""
var _has_sprite: bool = false


func set_mob_sprite(mob_id: String) -> void:
	_mob_id = mob_id.to_lower()
	_replace_sprite()


func get_mob_id() -> String:
	return _mob_id


func _replace_sprite() -> void:
	if _sprite != null:
		_sprite.queue_free()
		_sprite = null
	_has_sprite = false

	if _mob_id.is_empty():
		return

	var path := "%s%s.png" % [SPRITE_DIR, _mob_id]
	if not ResourceLoader.exists(path):
		push_warning("[MobVisual] No sprite for '%s' (looked in %s)" % [_mob_id, path])
		queue_redraw()
		return

	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_warning("[MobVisual] Load returned null for: %s" % path)
		queue_redraw()
		return

	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.centered = true
	_sprite.visible = true
	_sprite.modulate = Color.WHITE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_has_sprite = true
	print("[MobVisual] Loaded sprite: %s (%dx%d) pos=%s z=%d visible=%s modulate=%s" % [
		path, tex.get_width(), tex.get_height(),
	 str(position), z_index, str(visible), str(modulate)
	])
	# Force a redraw so the _draw() fallback knows the sprite loaded.
	queue_redraw()


func _draw() -> void:
	# Always draw a debug rectangle so the mob position is confirmed visible.
	# When a real sprite exists the Sprite2D child renders on top and hides it.
	if _has_sprite:
		return
	# Bright magenta rect — impossible to miss on any biome.
	draw_rect(Rect2(Vector2(-12, -12), Vector2(24, 24)), Color.MAGENTA)
	draw_rect(Rect2(Vector2(-11, -11), Vector2(22, 22)), Color(1.0, 0.0, 1.0, 0.3))
	# Draw mob_id text so the caller can confirm which sprite was requested.
	if not _mob_id.is_empty():
		var label_offset := Vector2(-_mob_id.length() * 2.5, -20)
		draw_string(ThemeDB.fallback_font, label_offset, _mob_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
