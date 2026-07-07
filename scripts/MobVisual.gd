## MobVisual — Sprite renderer for mobs/enemies.
##
## Uses a Sprite2D child (the same mechanism CharacterVisual/player uses and
## which is proven to render on world_grid). If the sprite file is missing,
## falls back to a magenta _draw() rectangle so the position is always visible.
class_name MobVisual
extends Node2D

const SPRITE_DIR := "res://assets/mobs/"

var _sprite: Sprite2D = null
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
		return

	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_warning("[MobVisual] Load returned null for: %s" % path)
		return

	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.centered = true
	_sprite.visible = true
	_sprite.modulate = Color.WHITE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# CRITICAL: add the Sprite2D child only AFTER this node is in the tree,
	# so the texture RID registers and the sprite actually renders.
	if is_inside_tree():
		add_child(_sprite)
	else:
		# Defer until entered tree
		tree_entered.connect(func() -> void:
			if is_instance_valid(self) and _sprite != null and _sprite.get_parent() == null:
				add_child(_sprite)
		, CONNECT_ONE_SHOT)
	_has_sprite = true
	print("[MobVisual] Loaded sprite: %s (%dx%d) pos=%s z=%d visible=%s in_tree=%s" % [
		path, tex.get_width(), tex.get_height(),
		str(position), z_index, str(visible), str(is_inside_tree())
	])


func _process(_delta: float) -> void:
	_dbg_process += 1
	if _dbg_process <= 120 and _dbg_process % 60 == 0:
		print("[MobVisual] %s _process=%d _draw=%d parent=%s in_tree=%s visible=%s sprite=%s" % [
			_mob_id, _dbg_process, _dbg_draw,
			get_parent().name if get_parent() else "null",
			str(is_inside_tree()), str(visible),
			str(is_instance_valid(_sprite))
		])
	queue_redraw()


func _draw() -> void:
	_dbg_draw += 1
	# Magenta fallback rectangle — only visible when no real sprite is present.
	if not _has_sprite:
		draw_rect(Rect2(Vector2(-14, -14), Vector2(28, 28)), Color.MAGENTA)
		draw_rect(Rect2(Vector2(-13, -13), Vector2(26, 26)), Color(1.0, 0.0, 1.0, 0.4))
		if not _mob_id.is_empty():
			var label_offset := Vector2(-_mob_id.length() * 2.5, -22)
			draw_string(ThemeDB.fallback_font, label_offset, _mob_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
