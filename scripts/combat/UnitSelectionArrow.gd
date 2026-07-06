## UnitSelectionArrow — Bright cyan-blue down-pointing arrow that
## hovers above the active unit. Built procedurally (3 nested
## triangles for a layered, glowing look) so it doesn't need an
## asset to look good. Bobs up-and-down and pulses.
class_name UnitSelectionArrow extends Node2D

const COLOR_OUTER := Color(0.05, 0.10, 0.30, 0.95)
const COLOR_MID := Color(0.20, 0.55, 0.95, 1.0)
const COLOR_INNER := Color(0.85, 0.95, 1.0, 1.0)
const BOB_HEIGHT := 4.0
const BOB_PERIOD := 0.7
const WIDTH := 18
const HEIGHT := 16

var _outer: Polygon2D
var _mid: Polygon2D
var _inner: Polygon2D
var _tween: Tween = null
var _t: float = 0.0


func _ready() -> void:
	z_index = 50
	visible = false  # Hidden until set_active(true) flips it on
	_build_polygons()
	_start_bob()


func _build_polygons() -> void:
	# Three layered triangles: dark outer, blue mid, light inner.
	# Centered on (0, 0); the pointy end points down.
	# Triangles: top-left -> top-right -> bottom-tip
	var cx: float = 0.0
	var top_y: float = -HEIGHT * 0.5
	var tip_y: float = HEIGHT * 0.5
	var outer_pts: PackedVector2Array = PackedVector2Array([
		Vector2(cx - WIDTH * 0.6, top_y),
		Vector2(cx + WIDTH * 0.6, top_y),
		Vector2(cx, tip_y),
	])
	var mid_pts: PackedVector2Array = PackedVector2Array([
		Vector2(cx - WIDTH * 0.45, top_y + 1.0),
		Vector2(cx + WIDTH * 0.45, top_y + 1.0),
		Vector2(cx, tip_y - 1.0),
	])
	var inner_pts: PackedVector2Array = PackedVector2Array([
		Vector2(cx - WIDTH * 0.20, top_y + 3.0),
		Vector2(cx + WIDTH * 0.20, top_y + 3.0),
		Vector2(cx, tip_y - 4.0),
	])
	_outer = Polygon2D.new()
	_outer.polygon = outer_pts
	_outer.color = COLOR_OUTER
	add_child(_outer)
	_mid = Polygon2D.new()
	_mid.polygon = mid_pts
	_mid.color = COLOR_MID
	add_child(_mid)
	_inner = Polygon2D.new()
	_inner.polygon = inner_pts
	_inner.color = COLOR_INNER
	add_child(_inner)


func _start_bob() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	# We use a property tween to drive the y-offset (visual bob).
	# The arrow bobs by BOB_HEIGHT px over BOB_PERIOD seconds,
	# and the inner triangle's alpha pulses for a "glow" effect.
	_tween = create_tween().set_loops()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:y", position.y - BOB_HEIGHT, BOB_PERIOD * 0.5).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "position:y", position.y, BOB_PERIOD * 0.5).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_inner, "modulate:a", 0.55, BOB_PERIOD * 0.5)
	_tween.tween_property(_inner, "modulate:a", 1.0, BOB_PERIOD * 0.5)


func set_active(is_active: bool) -> void:
	visible = is_active


## Snap the arrow to a unit's grid cell. The arrow hovers just
## above the cell (CELL_SIZE pixels up from the cell center).
func snap_to_cell(cell_x: int, cell_y: int, cell_size: int) -> void:
	position = Vector2(cell_x * cell_size + cell_size * 0.5, cell_y * cell_size - 6)
