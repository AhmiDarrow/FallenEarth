## ProceduralTile — Procedurally drawn ground tiles for the world hex-grid.
## Called from WorldGenerator / LocalMapRenderer when generating terrain.
## Supports: base ground, rock, vegetation, rift cracks, biome tints/patterns.

extends ProceduralRenderer

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

# Runtime
var _drawn: bool = false

# Texture cache (simple PackedByteArray for procedural generation)
var _tex: PackedByteArray = PackedByteArray()

func _setup() -> void:
	_generate_texture()

func _draw() -> void:
	# Base ground — color from biome + terrain
	var bg_color = _get_biome_base_color()
	draw_rect(Vector2(0, 0), size, bg_color)

	# Terrain overlays — rocks, vegetation, rift cracks
	_draw_terrain_overlays()

	# Biome-specific tints and patterns
	_draw_biome_patterns()

	# Exploration reveal — fade in from edges
	if explored_pct > 0.0:
		_draw_exploration_reveal()

	# Rift cracks
	if has_rift:
		_draw_rift_cracks()

	# Runes
	if has_rune:
		_draw_rune()

func _generate_texture() -> void:
	# Generate a simple procedural texture pattern for the biome
	var seed: int = abs(biome.hash())
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var size = size.x
	var data = PackedByteArray()
	for y in range(size):
		for x in range(size):
			# Base noise + biome pattern
			var n = rng.randf_range(-1.0, 1.0)
			var p = _get_biome_pattern_value(x, y)
			var v = clampf(n + p * 0.5, -1.0, 1.0)

			if v < -0.6:
				data.append_byte(50)
			elif v < -0.4:
				data.append_byte(100)
			elif v < -0.2:
				data.append_byte(150)
			elif v <  0.2:
				data.append_byte(200)
			elif v <  0.4:
				data.append_byte(250)
			elif v <  0.6:
				data.append_byte(255)
			else:
				data.append_byte(150)

	_tex = data

func _get_biome_base_color() -> Color:
	match biome:
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

func _draw_terrain_overlays() -> void:
	# Draw rocks, vegetation, rift cracks
	var rng := RandomNumberGenerator.new()
	rng.seed = biome.hash() + terrain_type

	# Rocks
	if has_rocks and rng.randf() < 0.4:
		var rx = rng.randi_range(size.x * 0.1, size.x * 0.85)
		var ry = rng.randi_range(size.y * 0.1, size.y * 0.85)
		var rw = rng.randi_range(4, 12)
		var rh = rng.randi_range(4, 8)
		draw_rect(Vector2(rx, ry), rw, rh, COLORS["stone"])

	# Vegetation
	if has_vegetation and rng.randf() < 0.5:
		var vx = rng.randi_range(size.x * 0.05, size.x * 0.95)
		var vy = rng.randi_range(size.y * 0.05, size.y * 0.95)
		var vw = rng.randi_range(4, 10)
		var vh = rng.randi_range(4, 8)
		draw_rect(Vector2(vx, vy), vw, vh, COLORS["leaf"])

	# Rift cracks
	if has_rift and rng.randf() < 0.35:
		var cx = rng.randi_range(size.x * 0.1, size.x * 0.8)
		var cy = rng.randi_range(size.y * 0.1, size.y * 0.8)
		var cw = rng.randi_range(2, 6)
		var ch = rng.randi_range(2, 8)
		draw_rect(Vector2(cx, cy), cw, ch, COLORS["toxic"])

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
			draw_rect(Vector2(rx, ry), rw, rh, COLORS["toxic"].lerp(COLORS["ground_ash"], 0.7))

	elif biome == "Crystalline Peaks":
		# Crystalline: geometric lines
		for i in range(4):
			var rx = rng.randi_range(size.x * 0.1, size.x * 0.9)
			var ry = rng.randi_range(size.y * 0.1, size.y * 0.9)
			var rw = rng.randi_range(12, 18)
			var rh = rng.randi_range(2, 4)
			draw_rect(Vector2(rx, ry), rw, rh, COLORS["stone"])

	elif biome == "Ruined Sanctum":
		# Ruined: rune fragments
		for i in range(3):
			var rx = rng.randi_range(size.x * 0.05, size.x * 0.95)
			var ry = rng.randi_range(size.y * 0.05, size.y * 0.95)
			var rw = rng.randi_range(8, 12)
			var rh = rng.randi_range(6, 10)
			draw_rect(Vector2(rx, ry), rw, rh, COLORS["rune"].lerp(COLORS["ground_ash"], 0.8))

func _draw_exploration_reveal() -> void:
	# Fade in from edges
	var margin: int = int(size.x * explored_pct)
	for y in range(size.y):
		for x in range(size.x):
			if x < margin or x >= size.x - margin or y < margin or y >= size.y - margin:
				draw_rect(Vector2(x, y), 1, 1, COLORS["shadow"])

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
		draw_rect(Vector2(rx, ry), rw, rh, COLORS["toxic"])

func _draw_rune() -> void:
	# Rune: glowing fragment
	var rx = rng.randi_range(size.x * 0.1, size.x * 0.8)
	var ry = rng.randi_range(size.y * 0.1, size.y * 0.8)
	var rw = rng.randi_range(8, 12)
	var rh = rng.randi_range(6, 10)
	draw_rect(Vector2(rx, ry), rw, rh, COLORS["rune"])

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
