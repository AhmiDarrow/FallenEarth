class_name EnemyInfoPanel
extends Control
## Screen-space enemy info panel — name + HP bar.
## Created at runtime on HUDLayer by CombatLevel3D.

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")

var _name_label: Label
var _hp_bar: ColorRect
var _hp_label: Label
var _target_pawn = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_children()
	visible = false


func _build_children() -> void:
	size_flags_horizontal = SIZE_SHRINK_BEGIN
	size_flags_vertical = SIZE_SHRINK_BEGIN

	_name_label = UH.make_label("", 14, MT.TEXT_PRIMARY)
	_name_label.name = "EnemyName"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 2)
	_name_label.position = Vector2(8, 6)
	add_child(_name_label)

	_hp_bar = ColorRect.new()
	_hp_bar.name = "HPBar"
	_hp_bar.color = MT.HP_FILL
	_hp_bar.position = Vector2(8, 28)
	_hp_bar.size = Vector2(140, 10)
	add_child(_hp_bar)

	var hp_bg := ColorRect.new()
	hp_bg.name = "HPBg"
	hp_bg.color = MT.HP_BG
	hp_bg.position = Vector2(8, 28)
	hp_bg.size = Vector2(140, 10)
	hp_bg.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(hp_bg)
	move_child(hp_bg, 0)

	_hp_label = UH.make_label("", 9, Color.WHITE)
	_hp_label.name = "HPText"
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.add_theme_constant_override("outline_size", 1)
	_hp_label.position = Vector2(8, 28)
	_hp_label.size = Vector2(140, 10)
	add_child(_hp_label)


func set_target(pawn) -> void:
	_target_pawn = pawn
	if pawn == null or pawn.res == null:
		visible = false
		return

	_name_label.text = pawn.res.display_name
	var cur: int = pawn.res.current_hp
	var max_hp: int = pawn.res.max_hp
	var pct: float = float(cur) / float(max_hp) if max_hp > 0 else 0.0
	_hp_bar.size.x = 140.0 * pct
	_hp_bar.color = Color(0.6 - pct * 0.3, 0.3 + pct * 0.3, 0.2)
	_hp_label.text = "%d / %d" % [cur, max_hp]

	var vp: Viewport = get_viewport()
	var vp_size: Vector2 = vp.get_visible_rect().size if vp else Vector2(1280, 720)
	position = Vector2(vp_size.x - 180, 72)
	visible = true
