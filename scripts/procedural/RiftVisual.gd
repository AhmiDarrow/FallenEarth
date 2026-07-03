## RiftVisual — Pulsing irregular polygon with inner glow, drawn via _draw().
extends ColorRect

const PALETTE = preload("res://scripts/procedural/RiftPalette.gd")
const DISPLAY = preload("res://scripts/DisplayManager.gd")

@export var rift_type: int = 0  # 0=void, 1=life, 2=energy
@export var intensity: float = 1.0
@export var age: float = 0.0  # seconds since spawn

var _time: float = 0.0

func setup(data: Dictionary) -> void:
	rift_type = data.get("rift_type", 0)
	intensity = data.get("intensity", 1.0)
	_time = Time.get_ticks_msec()

func _draw() -> void:
	if age <= 0 or intensity <= 0:
		queue_free()
		return

	var palette: PALETTE = PALETTE.new()
	palette.set_current_type(rift_type)

	var base := Color(0.12, 0.10, 0.14)
	var glow := Color(0.30, 0.25, 0.45)
	if rift_type == 1:
		base = Color(0.08, 0.18, 0.10)
		glow = Color(0.20, 0.55, 0.35)
	if rift_type == 2:
		base = Color(0.10, 0.12, 0.30)
		glow = Color(0.45, 0.35, 0.90)

	var pulse := sin(_time / 500.0) * 0.15
	var scale := 1.0 + pulse * intensity
	var rect := Rect2(get_rect().center, Vector2(size.x * scale, size.y * scale))

	# Background (irregular polygon)
	var vertices := get_irregular_polygon(rect.size)
	var bg_color := base.lerp(Color(0, 0, 0, 0.25), 0.6)
	draw_polygon(vertices, bg_color, 0.0, 1.2)

	# Inner glow
	var inner := vertices * 0.75
	var inner_color := glow.lerp(base, 0.4)
	draw_polygon(inner, inner_color, 0.0, 1.8)

	# Edge shimmer
	var rim := get_rim_rectangle(rect.size, 3.0)
	draw_polygon(rim, Color(0.0, 0.0, 0.0, 0.3), 0.0, 1.2)

	# Age fade
	modulate = modulate * clampf(1.0 - age / 120.0, 0.0, 1.0)

func get_irregular_polygon(size: Vector2) -> PackedVector2Array:
	var v := PackedVector2Array()
	var cx := size.x * 0.5
	var cy := size.y * 0.5
	for i in range(7):
		var a := 2 * PI / 7.0 * float(i)
		var r := size.x * 0.45 + sin(a * 3.0) * 6.0
		v.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return v

func get_rim_rectangle(size: Vector2, thickness: float) -> PackedVector2Array:
	var margin := thickness
	return [
		Vector2(margin, margin),
		Vector2(size.x - margin, margin),
		Vector2(size.x - margin, size.y - margin),
		Vector2(margin, size.y - margin),
	]
