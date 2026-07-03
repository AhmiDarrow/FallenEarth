## ParticleEmitters — Custom _process + _draw emitters (ash, sparks, void tendrils).
extends CanvasLayer

const DISPLAY = preload("res://scripts/DisplayManager.gd")

@export var ash_enabled: bool = true
@export var spark_enabled: bool = true
@export var void_enabled: bool = true
@export var energy_enabled: bool = true

var _ash: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _void: Array[Dictionary] = []
var _energy: Array[Dictionary] = []

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	_update_ash(delta)
	_update_sparks(delta)
	_update_void(delta)
	_update_energy(delta)

func _update_ash(delta: float) -> void:
	if not ash_enabled:
		return
	for p in range(_ash.size()):
		var par: Dictionary = _ash[p]
		par["pos"] += par["velocity"] * delta
		par["age"] += delta
		par["scale"] = lerp(par["scale"], 0.0, delta * 2.5)
		if par["age"] > 2.0:
			_ash.remove_at(p)
			p -= 1

func _update_sparks(delta: float) -> void:
	if not spark_enabled:
		return
	for p in range(_sparks.size()):
		var par: Dictionary = _sparks[p]
		par["pos"] += par["velocity"] * delta
		par["age"] += delta
		par["scale"] = lerp(par["scale"], 0.0, delta * 3.0)
		if par["age"] > 0.8:
			_sparks.remove_at(p)
			p -= 1

func _update_void(delta: float) -> void:
	if not void_enabled:
		return
	for p in range(_void.size()):
		var par: Dictionary = _void[p]
		par["pos"] += par["velocity"] * delta
		par["age"] += delta
		par["scale"] = lerp(par["scale"], 0.0, delta * 2.0)
		if par["age"] > 3.0:
			_void.remove_at(p)
			p -= 1

func _update_energy(delta: float) -> void:
	if not energy_enabled:
		return
	for p in range(_energy.size()):
		var par: Dictionary = _energy[p]
		par["pos"] += par["velocity"] * delta
		par["age"] += delta
		par["scale"] = lerp(par["scale"], 0.0, delta * 1.5)
		if par["age"] > 1.2:
			_energy.remove_at(p)
			p -= 1

func spawn_ash(pos: Vector2, count: int = 5) -> void:
	for _ in range(count):
		_ash.append({
			"pos": pos + Vector2(randf_range(-0.8, 0.8), randf_range(-0.6, 0.6)),
			"velocity": Vector2(randf_range(-30, 30), randf_range(-20, 40)),
			"scale": randf_range(0.8, 1.4),
			"age": 0.0,
			"color": Color(0.25, 0.22, 0.20),
		})

func spawn_spark(pos: Vector2, count: int = 3) -> void:
	for _ in range(count):
		_sparks.append({
			"pos": pos + Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6)),
			"velocity": Vector2(randf_range(-80, 80), randf_range(-50, 150)),
			"scale": randf_range(0.6, 1.2),
			"age": 0.0,
			"color": Color(1.0, 0.95, 0.85),
		})

func spawn_void_tendril(pos: Vector2, count: int = 2) -> void:
	for _ in range(count):
		_void.append({
			"pos": pos + Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4)),
			"velocity": Vector2(randf_range(-15, 15), randf_range(-15, 15)),
			"scale": randf_range(1.0, 1.6),
			"age": 0.0,
			"color": Color(0.35, 0.30, 0.55),
		})

func spawn_energy_trail(pos: Vector2, count: int = 2) -> void:
	for _ in range(count):
		_energy.append({
			"pos": pos + Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)),
			"velocity": Vector2(randf_range(-60, 60), randf_range(-60, 60)),
			"scale": randf_range(0.8, 1.4),
			"age": 0.0,
			"color": Color(0.60, 0.50, 0.95),
		})

func _draw() -> void:
	if _ash.is_empty() and _sparks.is_empty() and _void.is_empty() and _energy.is_empty():
		return

	# Ash
	for par in _ash:
		var rect := Rect2(par["pos"], Vector2(par["scale"] * 12, par["scale"] * 8))
		var alpha := 0.25 * clampf(1.0 - par["age"] / 2.0, 0.0, 1.0)
		DISPLAY.draw_rect(rect, par["color"].with_alpha(alpha), 0.0)

	# Sparks
	for par in _sparks:
		var dot := Rect2(par["pos"], Vector2(par["scale"] * 6, par["scale"] * 6))
		DISPLAY.draw_circle(dot, par["scale"] * 3.5, par["color"].with_alpha(0.7 * clampf(1.0 - par["age"] / 0.8, 0.0, 1.0)))

	# Void tendrils
	for par in _void:
		var size := par["scale"] * 22
		var v := PackedVector2Array(
			par["pos"] - Vector2(0, size),
			par["pos"] + Vector2(size, 0),
			par["pos"] + Vector2(0, size),
			par["pos"] - Vector2(size, 0),
		)
		var alpha := 0.15 * clampf(1.0 - par["age"] / 3.0, 0.0, 1.0)
		DISPLAY.draw_polygon(v, par["color"].with_alpha(alpha), 0.0, 1.5)

	# Energy trails
	for par in _energy:
		var size := par["scale"] * 18
		var v := PackedVector2Array(
			par["pos"] - Vector2(0, size),
			par["pos"] + Vector2(size, 0),
			par["pos"] + Vector2(0, size),
			par["pos"] - Vector2(size, 0),
		)
		var alpha := 0.25 * clampf(1.0 - par["age"] / 1.2, 0.0, 1.0)
		DISPLAY.draw_polygon(v, par["color"].with_alpha(alpha), 0.0, 1.8)
