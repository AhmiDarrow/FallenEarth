## ProceduralTile — Procedurally drawn ground tiles for the world hex-grid.
## Called from WorldGenerator / LocalMapRenderer when generating terrain.
## Supports: base ground, rock, vegetation, rift cracks, biome tints/patterns.

class_name ProceduralTile
extends Node2D

const COLORS = preload("res://scripts/procedural/Palette.gd").COLORS
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")

# Tile metadata (data-driven)
var biome: String = "Ash Wastes"
var terrain_type: int = 0
var terrain: PackedByteArray = PackedByteArray()
var explored_pct: float = 0.0
var has_rift: bool = false
var rift_type: int = 0
var has_rocks: bool = false
var has_vegetation: bool = false
var has_rune: bool = false
var size: Vector2 = Vector2(64, 64)
var _tex: PackedByteArray = PackedByteArray()

# Shader uniforms
var shader: ShaderMaterial = null

func _init() -> void:
	shader = ShaderMaterial.new()
	# Broken shader_code initialization removed (caused Invalid assignment of 'shader_code' on ShaderMaterial)

func _draw() -> void:
	var bg_color = _get_terrain_color()
	draw_rect(Rect2(Vector2(0, 0), size), bg_color)

	_draw_noise(bg_color)
	_draw_terrain_features()
	_draw_decorations()
	_draw_biome_patterns()

	if explored_pct > 0.0:
		_draw_exploration_reveal()

	if has_rift:
		_draw_rift_cracks()

	if has_rune:
		_draw_rune()

func _generate_texture() -> void:
	var biome_seed: int = abs(biome.hash())
	var rng := RandomNumberGenerator.new()
	rng.seed = biome_seed

	var sz: int = int(size.x)
	var data := PackedByteArray()
	data.resize(sz * sz)
	var i: int = 0
	for y in sz:
		for x in sz:
			var n: float = rng.randf_range(-1.0, 1.0)
			var p: float = _get_biome_pattern_value(x, y)
			var v: float = clampf(n + p * 0.5, -1.0, 1.0)

			var val: int
			if v < -0.6:
				val = 50
			elif v < -0.4:
				val = 100
			elif v < -0.2:
				val = 150
			elif v <  0.2:
				val = 200
			elif v <  0.4:
				val = 250
			elif v <  0.6:
				val = 255
			else:
				val = 150

			data[i] = val
			i += 1

	_tex = data

func _get_biome_base_color() -> Color:
	match biome:
		"Ash Wastes":
			return COLORS["ground_ash"]
		"Neon Bogs":
			return COLORS["neon"].lerp(Color("#1A3A3A"), 0.6)
		"Rust Canyons":
			return COLORS["ground_rust"]
		"Scorched Plains":
			return COLORS["sand"].lerp(Color("#8A7A5A"), 0.4)
		"Ironwood Thicket":
			return COLORS["iron"].lerp(Color("#2A2A1A"), 0.3)
		"Glass Dunes":
			return COLORS["sand"].lerp(Color("#C8E8E8"), 0.3)
		"Corpse Fields":
			return COLORS["bone"].lerp(COLORS["ground_ash"], 0.4)
		"Stormspire Highlands":
			return COLORS["storm"].lerp(Color("#2A3A4A"), 0.5)
		"Toxin Marshes":
			return COLORS["marsh"].lerp(COLORS["toxic"], 0.15)
		"Dead City Outskirts":
			return COLORS["city_ash"].lerp(Color("#1A1820"), 0.3)
		"Swamp of Whispers":
			return COLORS["ground_ash"].lerp(COLORS["toxic"], 0.25)
		"Crystalline Peaks":
			return COLORS["ground_rust"].lerp(COLORS["stone"], 0.3)
		"Ruined Sanctum":
			return COLORS["ground_ash"].lerp(COLORS["rune"], 0.2)
		"toxic":
			return COLORS["toxic"].lerp(COLORS["ground_ash"], 0.35)
		"corrupted":
			return COLORS["toxic"].lerp(COLORS["ground_rust"], 0.3)
		_:
			return COLORS["ground_ash"]


func _get_terrain_color() -> Color:
	var base: Color = _get_biome_base_color()
	match terrain_type:
		LocalMapGen.TERRAIN_BLOCKED:
			return base.darkened(0.4).lerp(COLORS["shadow"], 0.5)
		LocalMapGen.TERRAIN_DEBRIS:
			return base.lerp(COLORS["stone"], 0.3)
		LocalMapGen.TERRAIN_VEGETATION:
			return base.lerp(COLORS["leaf"], 0.35)
		LocalMapGen.TERRAIN_RIFT_SCAR:
			return base.lerp(COLORS["rune"], 0.25)
		_:
			return base

func _get_biome_pattern_value(x: int, y: int) -> float:
	# Procedural pattern based on biome
	var rng := RandomNumberGenerator.new()
	rng.seed = biome.hash() + x + y

	match biome:
		"Swamp of Whispers":
			return rng.randf_range(-0.3, 0.2)
		"Crystalline Peaks":
			return rng.randf_range(0.1, 0.5)
		"Ruined Sanctum":
			return rng.randf_range(-0.4, 0.1)
		_:
			return rng.randf_range(-0.2, 0.2)

func _draw_noise(base_color: Color) -> void:
	if _tex.is_empty():
		return
	var sz := int(size.x)
	var block := 3
	var darker := Color(base_color.r * 0.85, base_color.g * 0.85, base_color.b * 0.85, 0.5)
	var lighter := Color(
		minf(base_color.r * 1.15, 1.0), minf(base_color.g * 1.15, 1.0),
		minf(base_color.b * 1.15, 1.0), 0.4
	)
	for y in range(0, sz, block):
		for x in range(0, sz, block):
			var idx := y * sz + x
			if idx >= _tex.size():
				continue
			var v := _tex[idx]
			if v < 100:
				draw_rect(Rect2(Vector2(x, y), Vector2(block, block)), darker)
			elif v > 200:
				draw_rect(Rect2(Vector2(x, y), Vector2(block, block)), lighter)

func _draw_decorations() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = biome.hash() + terrain_type + int(size.x * 17.0)
	var count := rng.randi_range(0, 4)
	for i in range(count):
		var rx := rng.randf_range(2.0, size.x - 4.0)
		var ry := rng.randf_range(2.0, size.y - 4.0)
		var kind := rng.randi() % 3
		match kind:
			0:
				var w := rng.randf_range(1.5, 3.0)
				var h := rng.randf_range(3.0, 5.0)
				draw_rect(Rect2(Vector2(rx, ry), Vector2(w, h)), COLORS["stone"].lerp(COLORS["ground_ash"], 0.5))
			1:
				var w := rng.randf_range(2.0, 4.0)
				draw_rect(Rect2(Vector2(rx, ry), Vector2(w, w * 0.5)), COLORS["leaf"].lerp(COLORS["ground_ash"], 0.6))
			2:
				var w := rng.randf_range(1.0, 3.0)
				draw_rect(Rect2(Vector2(rx, ry), Vector2(w, w)), COLORS["shadow"].lerp(COLORS["ground_ash"], 0.3))

func _draw_terrain_features() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = biome.hash() + terrain_type + int(size.x * 7.0)
	var base_color := _get_terrain_color()

	match terrain_type:
		LocalMapGen.TERRAIN_BLOCKED:
			# Dense rock/wall — draw large blocking shapes
			var count := rng.randi_range(2, 5)
			for i in range(count):
				var rx := rng.randf_range(0.0, size.x * 0.8)
				var ry := rng.randf_range(0.0, size.y * 0.8)
				var rw := rng.randf_range(8.0, size.x * 0.6)
				var rh := rng.randf_range(8.0, size.y * 0.6)
				draw_rect(Rect2(Vector2(rx, ry), Vector2(rw, rh)), COLORS["shadow"].lerp(COLORS["stone"], 0.3))
			# Cross-hatch pattern for impassable
			for i in range(4):
				var lx := rng.randf_range(2.0, size.x - 2.0)
				draw_line(Vector2(lx, 0), Vector2(lx, size.y), COLORS["shadow"].lerp(COLORS["stone"], 0.2), 1.0)

		LocalMapGen.TERRAIN_DEBRIS:
			# Scattered rubble
			var count := rng.randi_range(3, 7)
			for i in range(count):
				var rx := rng.randf_range(2.0, size.x - 4.0)
				var ry := rng.randf_range(2.0, size.y - 4.0)
				var rw := rng.randf_range(2.0, 5.0)
				var rh := rng.randf_range(2.0, 4.0)
				draw_rect(Rect2(Vector2(rx, ry), Vector2(rw, rh)), COLORS["stone"].lerp(base_color, 0.4))

		LocalMapGen.TERRAIN_VEGETATION:
			# Green clumps / foliage
			var count := rng.randi_range(2, 6)
			for i in range(count):
				var vx := rng.randf_range(3.0, size.x - 5.0)
				var vy := rng.randf_range(3.0, size.y - 5.0)
				var vr := rng.randf_range(3.0, 6.0)
				draw_circle(Vector2(vx, vy), vr, COLORS["leaf"].lerp(base_color, 0.3))
			# Small stem lines
			for i in range(2):
				var sx := rng.randf_range(4.0, size.x - 4.0)
				var sy := rng.randf_range(4.0, size.y - 4.0)
				draw_line(Vector2(sx, sy), Vector2(sx, sy - 4.0), COLORS["leaf"].darkened(0.2), 1.0)

		LocalMapGen.TERRAIN_RIFT_SCAR:
			# Purple/violet cracks
			var count := rng.randi_range(2, 4)
			for i in range(count):
				var cx := rng.randf_range(size.x * 0.1, size.x * 0.8)
				var cy := rng.randf_range(size.y * 0.1, size.y * 0.8)
				var cw := rng.randf_range(4.0, 10.0)
				var ch := rng.randf_range(2.0, 6.0)
				draw_rect(Rect2(Vector2(cx, cy), Vector2(cw, ch)), COLORS["rune"].lerp(COLORS["toxic"], 0.3))

		_:
			# Ground — no extra features
			pass

func _draw_biome_patterns() -> void:
	# Biome-specific patterns — lines, dots, etc.
	var rng := RandomNumberGenerator.new()
	rng.seed = biome.hash()

	if biome == "Swamp of Whispers":
		# Swamp: subtle ripples
		for i in range(6):
			var rx = rng.randi_range(size.x * 0.1, size.x * 0.9)
			var ry = rng.randi_range(size.y * 0.1, size.y * 0.9)
			var rw = rng.randi_range(8, 14)
			var rh = rng.randi_range(2, 4)
			draw_rect(Rect2(Vector2(rx, ry), Vector2(rw, rh)), COLORS["toxic"].lerp(COLORS["ground_ash"], 0.7))

	elif biome == "Crystalline Peaks":
		# Crystalline: geometric lines
		for i in range(4):
			var rx = rng.randi_range(size.x * 0.1, size.x * 0.9)
			var ry = rng.randi_range(size.y * 0.1, size.y * 0.9)
			var rw = rng.randi_range(12, 18)
			var rh = rng.randi_range(2, 4)
			draw_rect(Rect2(Vector2(rx, ry), Vector2(rw, rh)), COLORS["stone"])

	elif biome == "Ruined Sanctum":
		# Ruined: rune fragments
		for i in range(3):
			var rx = rng.randi_range(size.x * 0.05, size.x * 0.95)
			var ry = rng.randi_range(size.y * 0.05, size.y * 0.95)
			var rw = rng.randi_range(8, 12)
			var rh = rng.randi_range(6, 10)
			draw_rect(Rect2(Vector2(rx, ry), Vector2(rw, rh)), COLORS["rune"].lerp(COLORS["ground_ash"], 0.8))

func _draw_exploration_reveal() -> void:
	# Fade in from edges
	var margin: int = int(size.x * explored_pct)
	for y in range(size.y):
		for x in range(size.x):
			if x < margin or x >= size.x - margin or y < margin or y >= size.y - margin:
				draw_rect(Rect2(Vector2(x, y), Vector2(1, 1)), COLORS["shadow"])

func _draw_rift_cracks() -> void:
	# Rift: pulsating toxic veins
	var rng := RandomNumberGenerator.new()
	rng.seed = biome.hash() + terrain_type

	var count = rng.randi_range(2, 4)
	for i in range(count):
		var rx = rng.randi_range(size.x * 0.1, size.x * 0.8)
		var ry = rng.randi_range(size.y * 0.1, size.y * 0.8)
		var rw = rng.randi_range(6, 10)
		var rh = rng.randi_range(3, 6)
		draw_rect(Rect2(Vector2(rx, ry), Vector2(rw, rh)), COLORS["toxic"])

func _draw_rune() -> void:
	# Rune: glowing fragment
	var rng := RandomNumberGenerator.new()
	rng.seed = biome.hash() + terrain_type
	var rx = rng.randi_range(size.x * 0.1, size.x * 0.8)
	var ry = rng.randi_range(size.y * 0.1, size.y * 0.8)
	var rw = rng.randi_range(8, 12)
	var rh = rng.randi_range(6, 10)
	draw_rect(Rect2(Vector2(rx, ry), Vector2(rw, rh)), COLORS["rune"])

# -------------------------------------------------------------------------
# Data-driven setup (called before draw)
# -------------------------------------------------------------------------

func setup_for(data: Dictionary) -> void:
	biome = str(data.get("biome", "Ash Wastes"))
	terrain_type = int(data.get("terrain_type", 0))
	terrain = data.get("terrain", PackedByteArray())
	explored_pct = float(data.get("explored_pct", 0.0))
	has_rift = bool(data.get("has_rift", false))
	rift_type = int(data.get("rift_type", 0))
	has_rocks = bool(data.get("has_rocks", false))
	has_vegetation = bool(data.get("has_vegetation", false))
	has_rune = bool(data.get("has_rune", false))
	_generate_texture()

# -------------------------------------------------------------------------
# Exposed getters
# -------------------------------------------------------------------------

func get_biome() -> String:
	return biome

func get_terrain_type() -> int:
	return terrain_type

func get_exploration_pct() -> float:
	return explored_pct

func get_has_rift() -> bool:
	return has_rift

func get_rift_type() -> int:
	return rift_type

func get_has_rocks() -> bool:
	return has_rocks

func get_has_vegetation() -> bool:
	return has_vegetation

func get_has_rune() -> bool:
	return has_rune

func get_shader_params() -> Dictionary:
	return {
		"biome": biome,
		"terrain_type": terrain_type,
		"terrain": terrain,
		"explored_pct": explored_pct,
		"has_rift": has_rift,
		"rift_type": rift_type,
		"has_rocks": has_rocks,
		"has_vegetation": has_vegetation,
		"has_rune": has_rune,
	}
