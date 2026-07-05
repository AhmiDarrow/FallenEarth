## StatsScreen — Placeholder for the Stats tab in CharacterMenu.
##
## Phase 4 will own this (HP, MP, Attack, Defense, Speed, +stat bonuses
## from gear). Phase 3 just shows a "lands in Phase 4" message.
class_name StatsScreen
extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var ph := Label.new()
	ph.text = "(Stats screen lands in Phase 4.\n\nHP, MP, Attack, Defense, Speed, +stat bonuses from equipped gear.)"
	ph.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	ph.add_theme_font_size_override("font_size", 14)
	ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ph.anchor_right = 1.0
	ph.anchor_bottom = 1.0
	ph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(ph)
