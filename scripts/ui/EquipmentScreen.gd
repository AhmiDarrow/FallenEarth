## EquipmentScreen — Placeholder for the Equipment tab in CharacterMenu.
##
## Phase 4 will own this. Phase 3 just shows a "lands in Phase 4"
## message so the tab works end-to-end. The CharacterMenu
## lazy-loader falls back to a placeholder when the script file is
## missing.
class_name EquipmentScreen
extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var ph := Label.new()
	ph.text = "(Equipment screen lands in Phase 4.\n\nDrag-to-equip from inventory; 9 slots: head, chest, legs, boots, mainhand, offhand, tool, acc1, acc2.)"
	ph.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	ph.add_theme_font_size_override("font_size", 14)
	ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ph.anchor_right = 1.0
	ph.anchor_bottom = 1.0
	ph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(ph)
