class_name PlayerStatsPanel
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")

var _name_label: Label
var _class_label: Label
var _hp_bar: ColorRect
var _hp_bg: ColorRect
var _hp_label: Label
var _mp_bar: ColorRect
var _mp_bg: ColorRect
var _mp_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_children()
	visible = false


func _build_children() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", MT.panel(MT.BG_DEEP, MT.BORDER_STRONG, MT.RADIUS_LG, 2))
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	_name_label = Label.new()
	_name_label.name = "PlayerName"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.92))
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 2)
	_name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_name_label)

	_class_label = Label.new()
	_class_label.name = "PlayerClass"
	_class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_class_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_class_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_class_label.add_theme_constant_override("outline_size", 1)
	_class_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_class_label)

	var hp_row := Control.new()
	hp_row.custom_minimum_size = Vector2(0, 14)
	hp_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hp_row)

	_hp_bg = ColorRect.new()
	_hp_bg.name = "HPBg"
	_hp_bg.color = Color(0.15, 0.05, 0.05)
	_hp_bg.position = Vector2(0, 0)
	_hp_bg.size = Vector2(140, 10)
	hp_row.add_child(_hp_bg)

	_hp_bar = ColorRect.new()
	_hp_bar.name = "HPBar"
	_hp_bar.color = Color(0.6, 0.15, 0.15)
	_hp_bar.position = Vector2(0, 0)
	_hp_bar.size = Vector2(140, 10)
	hp_row.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.name = "HPText"
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.add_theme_color_override("font_color", Color.WHITE)
	_hp_label.add_theme_constant_override("outline_size", 1)
	_hp_label.add_theme_font_size_override("font_size", 9)
	_hp_label.position = Vector2(0, 0)
	_hp_label.size = Vector2(140, 10)
	hp_row.add_child(_hp_label)

	var mp_row := Control.new()
	mp_row.custom_minimum_size = Vector2(0, 14)
	mp_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(mp_row)

	_mp_bg = ColorRect.new()
	_mp_bg.name = "MPBg"
	_mp_bg.color = Color(0.05, 0.08, 0.15)
	_mp_bg.position = Vector2(0, 0)
	_mp_bg.size = Vector2(140, 10)
	mp_row.add_child(_mp_bg)

	_mp_bar = ColorRect.new()
	_mp_bar.name = "MPBar"
	_mp_bar.color = Color(0.15, 0.3, 0.6)
	_mp_bar.position = Vector2(0, 0)
	_mp_bar.size = Vector2(140, 10)
	mp_row.add_child(_mp_bar)

	_mp_label = Label.new()
	_mp_label.name = "MPText"
	_mp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mp_label.add_theme_color_override("font_color", Color.WHITE)
	_mp_label.add_theme_constant_override("outline_size", 1)
	_mp_label.add_theme_font_size_override("font_size", 9)
	_mp_label.position = Vector2(0, 0)
	_mp_label.size = Vector2(140, 10)
	mp_row.add_child(_mp_label)


func update_from_character(char_data: Dictionary) -> void:
	var name_text: String = str(char_data.get("name", char_data.get("display_name", "Hero")))
	var class_text: String = str(char_data.get("class", char_data.get("class_id", "")))
	var race_text: String = str(char_data.get("race", ""))
	var level: int = int(char_data.get("level", 1))
	_name_label.text = name_text
	_class_label.text = "Lv.%d %s %s" % [level, race_text.capitalize(), class_text.capitalize()]

	var cur_hp: int = int(char_data.get("hp", char_data.get("current_hp", 100)))
	var max_hp: int = int(char_data.get("max_hp", 100))
	var hp_pct: float = float(cur_hp) / float(max_hp) if max_hp > 0 else 0.0
	_hp_bar.size.x = 140.0 * hp_pct
	_hp_label.text = "%d / %d" % [cur_hp, max_hp]

	var cur_mp: int = int(char_data.get("mp", char_data.get("current_mp", 0)))
	var max_mp: int = int(char_data.get("mp_max", char_data.get("max_mp", 100)))
	var mp_pct: float = float(cur_mp) / float(max_mp) if max_mp > 0 else 0.0
	_mp_bar.size.x = 140.0 * mp_pct
	_mp_label.text = "%d / %d" % [cur_mp, max_mp]

	visible = true
