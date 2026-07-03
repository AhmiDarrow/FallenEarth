## GraphicsManager — minimal stub for clean parse after bug fix round.
## Full procedural drawing code had unresolved dependencies (noise assets, types).
extends Node

var _underearth_seed: float

func _init() -> void:
	_underearth_seed = randf()

static func get_palette_for_biome(biome_name: String = "gloom") -> Dictionary:
	return {
		"ink_outline": Color(0.2,0.2,0.2),
		"player_skin_base": Color(0.8,0.7,0.6),
		"player_skin_high": Color(0.9,0.8,0.7),
		"player_eyes": Color(0.2,0.1,0.05),
		"ink_faint": Color(0.4,0.35,0.3),
		"ground": Color(0.3,0.25,0.2)
	}

func generate_procedural_texture(size: int = 256, biome_name: String = "gloom") -> Dictionary:
	return {"noise": null, "palette": get_palette_for_biome(biome_name)}

func get_grit_texture(size: int = 256, biome_name: String = "gloom") -> Resource:
	return null

func get_parallax_layer(biome_name: String = "gloom") -> Dictionary:
	return {"fog": null, "ground": null}

func get_biome_overlay(biome_name: String = "gloom") -> Resource:
	return null

static func draw_character_base(x: float, y: float, direction: float, palette: Dictionary) -> void:
	pass

static func draw_equipment_layer(x: float, y: float, palette: Dictionary) -> void:
	pass

static func draw_multiline_path_begin() -> Path2D:
	return Path2D.new()

static func _add_lines_to_path(path: Path2D, points: Array, outline_color: Color, outline_width: float, fill: bool, is_closed: bool) -> void:
	pass

static func draw_multiline_path(points: Array, outline_color: Color, outline_width: float, fill: bool, is_closed: bool) -> Path2D:
	var p := draw_multiline_path_begin()
	return p

static func draw_rect(a = null, b = null, c = null, d = null) -> void: pass
static func draw_circle(a = null, b = null, c = null, d = null, e = null) -> void: pass
static func draw_line(a = null, b = null, c = null, d = null, e = null) -> void: pass
static func draw_polygon(a = null, b = null, c = null, d = null) -> void: pass
static func draw_texture(a = null, b = null, c = null, d = null) -> void: pass

static func advance_frame() -> void: pass
static func get_frame_progress() -> float: return 0.0
