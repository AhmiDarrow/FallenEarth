## FloatingDamage — Animated damage numbers that float up and fade.
##
## Red for physical damage, blue for magic, green for heal.
extends Node2D

const DURATION := 0.8
const FLOAT_HEIGHT := 30.0
const COLOR_PHYSICAL := Color(1.0, 0.3, 0.3)
const COLOR_MAGIC := Color(0.4, 0.6, 1.0)
const COLOR_HEAL := Color(0.3, 1.0, 0.4)

var _label: Label = null
var _timer: float = 0.0
var _start_pos: Vector2 = Vector2.ZERO
var _damage_type: String = "physical"


func setup(amount: int, damage_type: String = "physical", pos: Vector2 = Vector2.ZERO) -> void:
	_start_pos = pos
	position = pos
	_damage_type = damage_type

	_label = Label.new()
	_label.name = "DamageLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size = Vector2(60, 20)
	_label.position = Vector2(-30, -10)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var color: Color
	match damage_type:
		"magic":
			color = COLOR_MAGIC
		"heal":
			color = COLOR_HEAL
			_label.text = "+%d" % amount
		_:
			color = COLOR_PHYSICAL
			_label.text = "-%d" % amount

	_label.add_theme_color_override("font_color", color)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 2)
	add_child(_label)

	_timer = 0.0
	visible = true


func _process(delta: float) -> void:
	_timer += delta
	var t: float = _timer / DURATION
	if t >= 1.0:
		queue_free()
		return

	# Float up
	position.y = _start_pos.y - (FLOAT_HEIGHT * t)

	# Fade out
	var alpha: float = 1.0 - t
	if _label != null and is_instance_valid(_label):
		var color: Color = _label.get_theme_color("font_color")
		color.a = alpha
		_label.add_theme_color_override("font_color", color)

	# Scale down slightly
	var scale_val: float = 1.0 - (t * 0.3)
	_label.scale = Vector2(scale_val, scale_val)
