## CombatHPBar — HP bar displayed above tactical combat units.
##
## Shows current HP as a colored bar. Green for player, red for enemy, blue for ally.
extends Node2D

# v0.10.4 polish: bigger bars (48x8) so they read as actual bars
# at 1280x720, not as a thin line under the HP text label.
const BAR_WIDTH := 48.0
const BAR_HEIGHT := 8.0
const LABEL_OFFSET_Y := -10  # label sits above the bar
const BAR_OFFSET_Y := -1  # bar is just above the unit's sprite
const COLOR_PLAYER := Color(0.25, 0.85, 0.35)
const COLOR_ENEMY := Color(0.90, 0.25, 0.25)
const COLOR_ALLY := Color(0.35, 0.60, 0.95)
const COLOR_BG := Color(0.08, 0.06, 0.04, 0.95)
const COLOR_BORDER := Color(0.15, 0.10, 0.05, 1.0)
const COLOR_LABEL := Color(1, 1, 1)

var _bg: ColorRect = null
var _fill: ColorRect = null
var _hp_label: Label = null
var _unit_id: String = ""
var _team: String = ""


func setup(unit_id: String, team: String, current_hp: int, max_hp: int) -> void:
	_unit_id = unit_id
	_team = team

	# Background
	_bg = ColorRect.new()
	_bg.name = "BG"
	_bg.color = COLOR_BG
	_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bg.position = Vector2(-BAR_WIDTH * 0.5, BAR_OFFSET_Y)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# Fill
	_fill = ColorRect.new()
	_fill.name = "Fill"
	_fill.color = _get_color()
	_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_fill.position = Vector2(-BAR_WIDTH * 0.5, BAR_OFFSET_Y)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill)

	# Border ring (drawn after fill so it overlays the bar edges)
	var border := ColorRect.new()
	border.name = "Border"
	border.color = COLOR_BORDER
	border.size = Vector2(BAR_WIDTH + 2, BAR_HEIGHT + 2)
	border.position = Vector2(-BAR_WIDTH * 0.5 - 1, BAR_OFFSET_Y - 1)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)

	# HP label (above the bar)
	_hp_label = Label.new()
	_hp_label.name = "HPLabel"
	_hp_label.text = "%d/%d" % [current_hp, max_hp]
	_hp_label.add_theme_font_size_override("font_size", 10)
	_hp_label.add_theme_color_override("font_color", COLOR_LABEL)
	_hp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hp_label.add_theme_constant_override("outline_size", 3)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.position = Vector2(-BAR_WIDTH * 0.5, LABEL_OFFSET_Y)
	_hp_label.size = Vector2(BAR_WIDTH, 10)
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_label)


func update_hp(current_hp: int, max_hp: int) -> void:
	if _fill == null or not is_instance_valid(_fill):
		return
	var ratio: float = float(current_hp) / float(max(1, max_hp))
	_fill.size.x = BAR_WIDTH * ratio
	if _hp_label != null and is_instance_valid(_hp_label):
		_hp_label.text = "%d/%d" % [current_hp, max_hp]


func _get_color() -> Color:
	match _team:
		"player":
			return COLOR_PLAYER
		"enemy":
			return COLOR_ENEMY
		"ally":
			return COLOR_ALLY
		_:
			return COLOR_ENEMY
