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
var _dbg_process: int = 0
var _dbg_draw: int = 0


func set_mob_sprite(mob_id: String) -> void:
	_mob_id = mob_id.to_lower()
	_replace_sprite()
	queue_redraw()


func get_mob_id() -> String:
	return _mob_id


func _process(_delta: float) -> void:
	_dbg_process += 1
	if _dbg_process <= 120 and _dbg_process % 60 == 0:
		print("[MobVisual] %s _process ran %d times, _draw ran %d times, parent=%s in_tree=%s visible=%s" % [
			_mob_id, _dbg_process, _dbg_draw,
			get_parent().name if get_parent() else "null",
			str(is_inside_tree()), str(visible)
		])
	# Continuous redraw — same pattern as CharacterVisual (player).
	queue_redraw()


func _draw() -> void:
	_dbg_draw += 1
	# UNCONDITIONAL debug square — proves _draw() runs on this node.
	draw_rect(Rect2(Vector2(-14, -14), Vector2(28, 28)), Color.MAGENTA)
	draw_rect(Rect2(Vector2(-13, -13), Vector2(26, 26)), Color(1.0, 0.0, 1.0, 0.4))
	if _has_sprite and _texture != null:
		var offset := Vector2(-_texture.get_width() * 0.5, -_texture.get_height() * 0.5)
		draw_texture(_texture, offset)
	if not _mob_id.is_empty():
		var label_offset := Vector2(-_mob_id.length() * 2.5, -22)
		draw_string(ThemeDB.fallback_font, label_offset, _mob_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)


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
