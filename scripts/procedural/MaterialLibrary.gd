## MaterialLibrary — Procedural material factory for 3D entities.
## Creates and caches StandardMaterial3D and ShaderMaterial variants
## driven by color palettes, noise textures, and faction/state tints.
class_name MaterialLibrary
extends RefCounted

static var _material_cache: Dictionary = {}

static func create_palette_material(color: Color, params: Dictionary = {}) -> Material:
	var key := "palette_%s_%s" % [color.to_html(), var_to_str(params).md5_text()]
	if _material_cache.has(key):
		return _material_cache[key]

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = params.get("metallic", 0.0)
	mat.roughness = params.get("roughness", 0.8)
	mat.emission_enabled = params.get("glow", false)
	if mat.emission_enabled:
		mat.emission = color
		mat.emission_energy_multiplier = params.get("glow_intensity", 1.0)
	mat.transparency = params.get("transparent", false)

	_material_cache[key] = mat
	return mat

static func create_organic_material(color: Color, roughness: float = 0.8) -> Material:
	return create_palette_material(color, {"roughness": roughness, "metallic": 0.0})

static func create_metallic_material(color: Color, roughness: float = 0.3) -> Material:
	return create_palette_material(color, {"roughness": roughness, "metallic": 0.7})

static func create_glow_material(color: Color, intensity: float = 1.0) -> Material:
	return create_palette_material(color, {"glow": true, "glow_intensity": intensity, "roughness": 0.4})

static func create_outline_material(base_color: Color, outline_color: Color = Color.BLACK) -> ShaderMaterial:
	var key := "outline_%s_%s" % [base_color.to_html(), outline_color.to_html()]
	if _material_cache.has(key):
		return _material_cache[key]

	var shader := preload("res://assets/shaders/entity_outline.gdshader") as Shader
	if not shader:
		return create_palette_material(base_color) as ShaderMaterial

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("base_color", base_color)
	mat.set_shader_parameter("outline_color", outline_color)
	_material_cache[key] = mat
	return mat

static func create_faction_tint_material(base_color: Color, faction_color: Color) -> ShaderMaterial:
	var key := "faction_%s_%s" % [base_color.to_html(), faction_color.to_html()]
	if _material_cache.has(key):
		return _material_cache[key]

	var shader := preload("res://assets/shaders/entity_noise.gdshader") as Shader
	if not shader:
		return create_palette_material(base_color) as ShaderMaterial

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("base_color", base_color)
	mat.set_shader_parameter("tint_color", faction_color)
	_material_cache[key] = mat
	return mat

static func create_damage_flash_material(base_color: Color) -> ShaderMaterial:
	var key := "damage_flash_%s" % base_color.to_html()
	if _material_cache.has(key):
		return _material_cache[key]

	var shader := preload("res://assets/shaders/entity_noise.gdshader") as Shader
	if not shader:
		return create_palette_material(base_color) as ShaderMaterial

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("base_color", base_color)
	mat.set_shader_parameter("flash_color", Color.RED)
	mat.set_shader_parameter("flash_amount", 0.0)
	_material_cache[key] = mat
	return mat

static func material_from_visual_data(visual: Dictionary) -> Material:
	var mat_type: String = visual.get("material", {}).get("type", "organic")
	var color_arr: Array = visual.get("torso", {}).get("color", [0.5, 0.5, 0.5])
	var color := Color(color_arr[0], color_arr[1], color_arr[2])
	var params: Dictionary = visual.get("material", {})

	match mat_type:
		"organic":
			return create_organic_material(color, params.get("roughness", 0.8))
		"metallic":
			return create_metallic_material(color, params.get("roughness", 0.3))
		"glow":
			return create_glow_material(color, params.get("glow", 1.0))
		_:
			return create_palette_material(color, params)

static func clear_cache() -> void:
	_material_cache.clear()

static func create_portal_material(base_color: Color, distortion_speed: float = 1.0) -> ShaderMaterial:
	var key := "portal_%s_%.1f" % [base_color.to_html(), distortion_speed]
	if _material_cache.has(key):
		return _material_cache[key]

	var shader := preload("res://assets/shaders/portal_distortion.gdshader") as Shader
	if not shader:
		return create_glow_material(base_color, 2.0) as ShaderMaterial

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("base_color", base_color)
	mat.set_shader_parameter("distortion_speed", distortion_speed)
	mat.set_shader_parameter("time", 0.0)
	_material_cache[key] = mat
	return mat

static func create_interaction_highlight(color: Color = Color(0.4, 0.8, 1.0)) -> Material:
	return create_outline_material(color, color.lightened(0.3))
