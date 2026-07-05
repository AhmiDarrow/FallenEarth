## LootPopup — Floating "+3 Iron Ore" text that fades and rises.
##
## Phase 8 polish. Spawned by HubWorld when the player picks up
## something (floor pickup, gather yield, mission reward). The popup
## is a simple Label that animates upward + fades over ~1.5 seconds
## and then queue_frees itself.
class_name LootPopup
extends Label

const LIFETIME := 1.5
const RISE_PX := 28.0
const FONT_SIZE := 16

var _time: float = 0.0
var _start_y: float = 0.0


func _ready() -> void:
	# Style
	add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	add_theme_color_override("font_outline_color", Color(0, 0, 0))
	add_theme_constant_override("outline_size", 3)
	add_theme_font_size_override("font_size", FONT_SIZE)
	# Position
	_start_y = global_position.y
	pivot_offset = Vector2(size.x / 2.0, size.y)
	# Top-level (don't get clipped by other UI)
	z_index = 200


func show_text(txt: String, world_pos: Vector2) -> void:
	text = txt
	global_position = world_pos


## Set the text color (Phase 8: rare items use a colored message).
func set_tier_color(tier_color: Color) -> void:
	add_theme_color_override("font_color", tier_color)


func _process(delta: float) -> void:
	_time += delta
	var t: float = clampf(_time / LIFETIME, 0.0, 1.0)
	# Rise upward
	position.y = _start_y + global_position.y - position.y
	global_position.y = _start_y - RISE_PX * t
	# Fade out
	modulate.a = 1.0 - t
	if _time >= LIFETIME:
		queue_free()
