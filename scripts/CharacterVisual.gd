# CharacterVisual.gd — Pure _draw() rendering via GraphicsManager helpers.
# No Sprite2D / AnimatedSprite2D — everything drawn procedurally.
# Equipment layered as offset shapes; direction animated via sine/cosine.

extends Node2D

const GraphicsManager = preload("res://scripts/GraphicsManager.gd")

# GraphicsManager stub or autoload — call its helpers directly.
var current_race: String = "Human"
var current_gender: String = "male"
var current_anim: String = "idle"
var current_frame: int = 0

# Procedural fallback flag (GameState.sets this)
var _use_procedural_graphics: bool = true


# -----------------------------------------------------------------------------
# Draw loop — called on each frame (or via queue_redraw)
# -----------------------------------------------------------------------------
func _draw() -> void:
	if not _use_procedural_graphics:
		return

	# 1. Base character (body + head)
	#    GraphicsManager.draw_character_base(x, y, direction, palette)
	var palette: Dictionary = GraphicsManager.get_palette_for_biome("gloom")
	var pos: Vector2 = position  # local position in _draw
	var x: float = pos.x
	var y: float = pos.y
	var direction: float = 0.0  # radians; will be updated by animation

	GraphicsManager.draw_character_base(x, y, direction, palette)

	# 2. Equipment layer (weapons, armor) — simple offset shapes
	GraphicsManager.draw_equipment_layer(x, y, palette)

	# 3. Face details (eyes, mouth) — draw_circle + draw_multiline
	var eye_pos: Vector2 = Vector2(x + 6, y - 38)
	var eye_color: Color = palette.get("player_eyes", Color.WHITE)
	draw_circle(eye_pos, 2.5, eye_color)

	var mouth_color: Color = palette.get("ink_faint", Color(0.5,0.5,0.5))
	GraphicsManager.draw_multiline_path(
		[eye_pos.x, eye_pos.y - 6, eye_pos.x + 4, eye_pos.y - 4],
		mouth_color,
		2,
		true,
		false,
	)

	# 4. Direction animation — slight bob + rotate
	#    Use GraphicsManager.advance_frame() to drive a seeded cycle.
	GraphicsManager.advance_frame()
	var frame_progress: float = GraphicsManager.get_frame_progress()
	var bob: float = sin(frame_progress * 0.15) * 1.2
	var swing: float = cos(frame_progress * 0.2) * 0.1

	#    Apply bob to y, keep x stable.
	#    (Direction is still 0 here; when facing left/right you'd set direction accordingly)

# Usage:
# - In character scene: instance this, with child nodes for overlays under $Equipment.
# - Call set_base_sprite(race, gender) from spawn (RaceManager + AppearanceManager).
# - Call update_equipment(dict) from EquipmentManager when gear changes.
# - Call play_animation("walk", frame) or similar to drive layers.


# In HubWorld or a CharacterDisplay node, use:
# var visual = CharacterVisual.new()
# add_child(visual)
# visual.set_base_sprite(race, gender)
# visual.update_equipment(equip_dict)
