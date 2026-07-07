## MaterialLibrary — Procedural materials for entities.
##
## Produces StandardMaterial3D instances (cached) from a material descriptor
## such as {"type": "organic", "roughness": 0.8, "glow": 0.2, "color": [r,g,b]},
## plus noise-based grime/glow variation textures and shader-material variants
## for hover-outline, faction tint and damage flash. Designed to feed
## ProceduralEntityGenerator.
##
## Materials are cached by key so that many entities sharing a descriptor reuse
## a single RID-backed material (cheap, and keeps draw calls batched).
class_name MaterialLibrary
extends RefCounted

enum ShaderVariant { NONE, OUTLINE, FACTION_TINT, DAMAGE_FLASH }

static var _material_cache: Dictionary = {}
static var _noise_cache: Dictionary = {}
static var _shader_cache: Dictionary = {}




## Resolve a color from a descriptor. Accepts either:
##   color: [r, g, b]            (0..1 floats)
##   color_hex: "#rrggbb"
##   palette: "faction_waste"    (named palette entry)
## Falls back to a neutral gray.
static func resolve_color(data: Dictionary, default_hue: float = -1.0) -> Color:
	if data.has("color"):
		var c = data["color"]
		if c is Array and c.size() >= 3:
			return Color(float(c[0]), float(c[1]), float(c[2]))
	if data.has("color_hex"):
		return Color.from_string(str(data["color_hex"]), Color.GRAY)
	if data.has("palette"):
		return palette_color(str(data["palette"]), default_hue)
	if default_hue >= 0.0:
		return Color.from_hsv(default_hue, 0.5, 0.8)
	return Color.GRAY


## Named color palettes keyed by archetype / faction role.
static func palette_color(name: String, hue_override: float = -1.0) -> Color:
	match name:
		"faction_waste": return Color(0.55, 0.7, 0.35)
		"faction_rift": return Color(0.6, 0.3, 0.8)
		"faction_tech": return Color(0.4, 0.7, 0.9)
		"faction_wild": return Color(0.7, 0.55, 0.3)
		"organic": return Color(0.7, 0.6, 0.5)
		"metallic": return Color(0.55, 0.57, 0.62)
		"glow": return Color(0.4, 0.8, 1.0)
		"chitin": return Color(0.35, 0.45, 0.3)
		"flesh": return Color(0.8, 0.6, 0.55)
		"bone": return Color(0.85, 0.82, 0.7)
		_:
			if hue_override >= 0.0:
				return Color.from_hsv(hue_override, 0.5, 0.8)
			return Color.GRAY


## Build (or fetch cached) a StandardMaterial3D from a descriptor dictionary.
## Descriptor keys: type, roughness, metallic, glow, color/color_hex/palette,
## emissive, ao, transparent.
static func make_material(data: Dictionary = {}, cache_key: String = "") -> StandardMaterial3D:
	var key := cache_key if not cache_key.is_empty() else _material_key(data)
	if _material_cache.has(key):
		return _material_cache[key]

	var mat := StandardMaterial3D.new()
	var mtype: String = str(data.get("type", "organic")).to_lower()

	match mtype:
		"metallic":
			mat.metallic = float(data.get("metallic", 0.9))
			mat.roughness = float(data.get("roughness", 0.35))
			mat.metallic_specular = 0.9
		"glow":
			mat.emission_enabled = true
			mat.emission = resolve_color(data)
			mat.emission_energy_multiplier = float(data.get("glow", 0.6)) * 2.0
			mat.roughness = float(data.get("roughness", 0.3))
			mat.metallic = float(data.get("metallic", 0.0))
		"chitin":
			mat.roughness = float(data.get("roughness", 0.55))
			mat.metallic = float(data.get("metallic", 0.3))
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.4
		"fabric", "stone", "organic", _:
			mat.roughness = float(data.get("roughness", 0.8))
			mat.metallic = float(data.get("metallic", 0.0))

	var base_color := resolve_color(data)
	mat.albedo_color = base_color

	if data.get("emissive", false):
		mat.emission_enabled = true
		mat.emission = resolve_color(data.get("emissive_color", data)) if data.has("emissive_color") else base_color
		mat.emission_energy_multiplier = float(data.get("emissive_energy", 1.0))

	if data.get("ao", false):
		mat.ao_enabled = true

	if data.get("transparent", false):
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.alpha_scissor_threshold = 0.5

	# Apply noise texture (grime / glow variation) if requested.
	if data.has("noise"):
		var noise_type: String = str(data.get("noise", "dirt"))
		var noise_size: int = int(data.get("noise_size", 64))
		# Clamp noise size to a reasonable range (4–128px)
		noise_size = max(4, min(noise_size, 128))
		var noise: NoiseTexture2D = make_noise_texture(noise_type, noise_size)
		mat.albedo_texture = noise
		# Mix the texture with the base color so it's not fully opaque; this
		# keeps the material readable while adding variation.
		mat.albedo_texture_albedo_color = base_color

	# Apply noise texture (grime / glow variation) if requested.
	# Noise is applied as an albedo texture with the base color mixed in,
	# creating a subtle, non-destructive variation effect.
	if data.has("noise"):
		var noise_type: String = str(data.get("noise", "dirt"))
		var noise_size: int = int(data.get("noise_size", 64))
		# Clamp noise size to a reasonable range (4–128px)
		noise_size = max(4, min(noise_size, 128))
		var noise: NoiseTexture2D = make_noise_texture(noise_type, noise_size)
		mat.albedo_texture = noise
		# Mix the texture with the base color so it's not fully opaque; this
		# keeps the material readable while adding variation.
		mat.albedo_texture_albedo_color = base_color

	_material_cache[key] = mat
	return mat


## Generate a small procedural noise texture (cached) for dirt / grime / glow
## variation. mode: "dirt", "glow", "metal". size: 4–128px. Returns a
## NoiseTexture2D.
static func make_noise_texture(mode: String = "dirt", size: int = 64) -> NoiseTexture2D:
	var key := "%s_%d" % [mode, size]
	if _noise_cache.has(key):
		return _noise_cache[key]

	var noise := FastNoiseLite.new()
	match mode:
		"glow":
			noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			noise.frequency = 0.08
		"metal":
			noise.noise_type = FastNoiseLite.TYPE_CELLULAR
			noise.frequency = 0.12
		"dirt", _:
			noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
			noise.frequency = 0.15
			noise.fractal_octaves = 4

	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = size
	tex.height = size
	tex.seamless = true
	_noise_cache[key] = tex
	return tex


## Build a ShaderMaterial variant for hover-outline / faction-tint / damage-flash.
## These wrap the base albedo color and are cheap (single uniform).
static func make_shader_variant(base_mat: StandardMaterial3D, variant: int, params: Dictionary = {}) -> ShaderMaterial:
	var key := "%d_%s" % [variant, params.hash()]
	if _shader_cache.has(key):
		return _shader_cache[key]

	var shader := _get_entity_shader()
	var sm := ShaderMaterial.new()
	sm.shader = shader

	var base_color := base_mat.albedo_color if base_mat else Color.WHITE
	match variant:
		ShaderVariant.OUTLINE:
			sm.set_shader_parameter("mode", 1)
			sm.set_shader_parameter("tint_color", params.get("outline_color", Color.CYAN))
			sm.set_shader_parameter("tint_strength", 0.0)
			sm.set_shader_parameter("flash_color", Color.WHITE)
			sm.set_shader_parameter("flash_strength", 0.0)
		ShaderVariant.FACTION_TINT:
			sm.set_shader_parameter("mode", 2)
			sm.set_shader_parameter("tint_color", params.get("faction_color", Color(1.0, 0.3, 0.3)))
			sm.set_shader_parameter("tint_strength", float(params.get("tint_strength", 0.35)))
			sm.set_shader_parameter("flash_color", Color.WHITE)
			sm.set_shader_parameter("flash_strength", 0.0)
		ShaderVariant.DAMAGE_FLASH:
			sm.set_shader_parameter("mode", 3)
			sm.set_shader_parameter("flash_color", params.get("flash_color", Color(1.0, 0.2, 0.2)))
			sm.set_shader_parameter("flash_strength", 0.0)
			sm.set_shader_parameter("tint_color", base_color)
			sm.set_shader_parameter("tint_strength", 0.0)
		_:
			sm.set_shader_parameter("mode", 0)
			sm.set_shader_parameter("tint_color", base_color)
			sm.set_shader_parameter("tint_strength", 0.0)
			sm.set_shader_parameter("flash_color", Color.WHITE)
			sm.set_shader_parameter("flash_strength", 0.0)

	sm.set_shader_parameter("base_color", base_color)
	_shader_cache[key] = sm
	return sm


## The shared entity shader: unlit-ish base color with optional tint / flash.
## Kept simple (no lighting model swap) so it works as an overlay material.
static func _get_entity_shader() -> Shader:
	if _entity_shader != null:
		return _entity_shader
	var s := Shader.new()
	s.code = """
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 base_color = vec4(1.0);
uniform vec4 tint_color = vec4(1.0);
uniform float tint_strength = 0.0;
uniform vec4 flash_color = vec4(1.0);
uniform float flash_strength = 0.0;
uniform int mode = 0;

void fragment() {
	vec4 col = base_color;
	if (mode == 2) {
		col.rgb = mix(base_color.rgb, tint_color.rgb, tint_strength);
	}
	if (mode == 3) {
		col.rgb = mix(base_color.rgb, flash_color.rgb, flash_strength);
	}
	col.rgb = mix(col.rgb, flash_color.rgb, flash_strength * float(mode != 2 ? 1 : 0));
	ALBEDO = col.rgb;
	ALPHA = base_color.a;
}
"""
	_entity_shader = s
	return s

static var _entity_shader: Shader = null


static func _material_key(data: Dictionary) -> String:
	var parts: PackedStringArray = []
	parts.append(str(data.get("type", "organic")))
	parts.append("r%.2f" % float(data.get("roughness", 0.8)))
	parts.append("m%.2f" % float(data.get("metallic", 0.0)))
	parts.append("g%.2f" % float(data.get("glow", 0.0)))
	if data.has("color"):
		var c = data["color"]
		if c is Array and c.size() >= 3:
			parts.append("c%.2f_%.2f_%.2f" % [float(c[0]), float(c[1]), float(c[2])])
	if data.has("color_hex"):
		parts.append(str(data["color_hex"]))
	if data.has("palette"):
		parts.append(str(data["palette"]))
	return "mat_" + "_".join(parts)


## Clear all cached materials / textures / shaders. Call on theme or world reset.
static func clear_cache() -> void:
	_material_cache.clear()
	_noise_cache.clear()
	_shader_cache.clear()
