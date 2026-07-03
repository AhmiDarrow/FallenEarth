## ProceduralTile — Procedurally drawn terrain tiles for overworld generation.
## Extends ProceduralRenderer. Supports tile types: grass, stone, water, sand, snow, dirt.
## Each type has distinct draw logic. Called from WorldGenerator when generating terrain.

extends ProceduralRenderer

# Tile type enum
enum TileType { GRASS, STONE, WATER, SAND, SNOW, DIRT }

# Size (in world units, e.g., 64)
var size: Vector2 = Vector2(64, 64)

# Tile type
var tile_type: TileType = TileType.GRASS

# Color variant (0-3)
var color_variant: int = 0

# Special flags
var is_decorative: bool = false  # True for grass/stone variants, False for terrain base
var is_water: bool = false
var is_decorative_grass: bool = false
var is_decorative_stone: bool = false

func _setup() -> void:
	# Initialize with defaults
	tile_type = TileType.GRASS
	color_variant = 0
	is_decorative = false
	is_water = false
	is_decorative_grass = false
	is_decorative_stone = false

func _draw() -> void:
	match tile_type:
		TileType.GRASS:
			_draw_grass()
		TileType.STONE:
			_draw_stone()
		TileType.WATER:
			_draw_water()
		TileType.SAND:
			_draw_sand()
		TileType.SNOW:
			_draw_snow()
		TileType.DIRT:
			_draw_dirt()
		_:
			# Unknown: fallback to simple color
			draw_rect(Vector2(0, 0), size, Color.WHITE)

func _draw_grass() -> void:
	if is_decorative_grass:
		# Decorative grass tuft — irregular shape
		_draw_decorative_grass()
	else:
		# Base grass — flat green with subtle variation
		var base_green: Color = COLOR_PALETTE["grass"][color_variant % 4]
		draw_rect(Vector2(0, 0), size, base_green)

func _draw_stone() -> void:
	if is_decorative_stone:
		# Decorative stone — irregular jagged shape
		_draw_decorative_stone()
	else:
		# Base stone — flat gray
		var base_gray: Color = COLOR_PALETTE["stone"][color_variant % 3]
		draw_rect(Vector2(0, 0), size, base_gray)

func _draw_water() -> void:
	# Base water — flat blue with subtle variation
	var base_blue: Color = COLOR_PALETTE["water"][color_variant % 3]
	draw_rect(Vector2(0, 0), size, base_blue)

func _draw_sand() -> void:
	# Base sand — flat beige
	var base_beige: Color = COLOR_PALETTE["sand"][color_variant % 3]
	draw_rect(Vector2(0, 0), size, base_beige)

func _draw_snow() -> void:
	# Base snow — flat white
	draw_rect(Vector2(0, 0), size, Color.WHITE)

func _draw_dirt() -> void:
	# Base dirt — flat brown
	var base_brown: Color = COLOR_PALETTE["dirt"][color_variant % 3]
	draw_rect(Vector2(0, 0), size, base_brown)

# Decorative variants — irregular shapes for grass/stone
func _draw_decorative_grass() -> void:
	# Irregular grass tuft
	var blob = PackedVector2Array(
		Vector2(0, 0),
		Vector2(size.x * 0.4, 0),
		Vector2(size.x * 0.45, size.y * 0.35),
		Vector2(size.x * 0.35, size.y * 0.45),
		Vector2(size.x * 0.25, size.y * 0.3),
		Vector2(size.x * 0.15, size.y * 0.4),
		Vector2(size.x * 0.1, size.y * 0.25),
		Vector2(size.x * 0.15, size.y * 0.15),
		Vector2(size.x * 0.3, size.y * 0.1),
		Vector2(size.x * 0.45, size.y * 0.12),
		Vector2(size.x * 0.55, size.y * 0.18),
	)
	var color: Color = COLOR_PALETTE["grass_decor"][color_variant % 4]
	draw_polygon(blob, color)

func _draw_decorative_stone() -> void:
	# Irregular stone
	var blob = PackedVector2Array(
		Vector2(0, 0),
		Vector2(size.x * 0.45, 0),
		Vector2(size.x * 0.55, size.y * 0.25),
		Vector2(size.x * 0.45, size.y * 0.4),
		Vector2(size.x * 0.3, size.y * 0.45),
		Vector2(size.x * 0.2, size.y * 0.35),
		Vector2(size.x * 0.15, size.y * 0.25),
		Vector2(size.x * 0.2, size.y * 0.15),
		Vector2(size.x * 0.35, size.y * 0.1),
		Vector2(size.x * 0.5, size.y * 0.12),
	)
	var color: Color = COLOR_PALETTE["stone_decor"][color_variant % 3]
	draw_polygon(blob, color)

# Helper to get base color palette entry
func _get_base_color(palette_key: String, variant: int) -> Color:
	return COLOR_PALETTE.get(palette_key, Color.WHITE)
