## TargetingReticle — 4-corner bracket sprite that follows the cursor
## when the player is in TARGET_ATTACK or TARGET_SKILL subphase.
class_name TargetingReticle extends Control

const COLOR_ATTACK := Color(0.95, 0.30, 0.30, 0.95)
const COLOR_SKILL := Color(0.65, 0.20, 0.90, 0.95)
const COLOR_MOVE := Color(0.20, 0.55, 0.85, 0.95)
const SIZE := 56
const CORNER_LEN := 14

var _color: Color = COLOR_ATTACK
var _tl: Line2D
var _tr: Line2D
var _bl: Line2D
var _br: Line2D
var _pulse_tween: Tween = null


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_corners()
	_start_pulse()


func _build_corners() -> void:
	_tl = _make_corner([Vector2(0, CORNER_LEN), Vector2(0, 0), Vector2(CORNER_LEN, 0)])
	_tr = _make_corner([Vector2(SIZE - CORNER_LEN, 0), Vector2(SIZE, 0), Vector2(SIZE, CORNER_LEN)])
	_bl = _make_corner([Vector2(0, SIZE - CORNER_LEN), Vector2(0, SIZE), Vector2(CORNER_LEN, SIZE)])
	_br = _make_corner([Vector2(SIZE - CORNER_LEN, SIZE), Vector2(SIZE, SIZE), Vector2(SIZE, SIZE - CORNER_LEN)])


func _make_corner(points: Array) -> Line2D:
	var line := Line2D.new()
	line.width = 2.5
	line.default_color = _color
	for p in points:
		line.add_point(p as Vector2)
	add_child(line)
	return line


func set_kind(kind: String) -> void:
	match kind:
		"attack":
			_color = COLOR_ATTACK
		"skill":
			_color = COLOR_SKILL
		"move":
			_color = COLOR_MOVE
		_:
			_color = COLOR_ATTACK
	if _tl != null:
		_tl.default_color = _color
		_tr.default_color = _color
		_bl.default_color = _color
		_br.default_color = _color


func _start_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.4).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_SINE)


func follow(world_pos: Vector2) -> void:
	if _tl == null:
		return
	position = world_pos - Vector2(SIZE, SIZE) * 0.5
