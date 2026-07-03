class_name ProceduralTile extends CanvasTexture

## Procedurally drawn tile for local map / overworld.
## Uses GraphicsManager helpers for consistent style, now with shader-based mixing.

@export_group("Biome")
var biome: String = "Ash Wastes"
var biome_palette: Dictionary = {}

@export_group("Terrain")
var terrain_type: int = 0
var terrain_seed: int = 0
var terrain_height: float = 0.0

@export_group("Details")
var has_rift: bool = false
var rift_type: int = 0
var has_rocks: bool = false
var has_vegetation: bool = false
var has_rune: bool = false

@export_group("Exploration")
var explored_pct: float = 1.0

# Shader parameters
var shader_params: Dictionary = {}

func setup_for(data: Dictionary) -> void:
	biome = data.get("biome", "Ash Wastes")
	terrain_type = data.get("terrain_type", 0)
	terrain_seed = randi()
	terrain_height = data.get("terrain", PackedByteArray()).size() / 10.0
	has_rift = data.get("has_rift", false)
	rift_type = data.get("rift_type", 0)
	has_rocks = data.get("has_rocks", false)
	has_vegetation = data.get("has_vegetation", false)
	has_rune = data.get("has_rune", false)
	explored_pct = data.get("explored_pct", 1.0)

	# Load biome palette
	GraphicsManager.set_current_biome(biome)
	biome_palette = GraphicsManager.get_biome_palette(biome)

	# Build shader parameters
	_build_shader_params()

func _build_shader_params() -> void:
	# Base albedo from palette
	var palette := GraphicsManager.get_palette_for_biome(biome)
	var base_color := palette["ground"]
	if biome == "frost":
		base_color = Color(base_color.r, base_color.b, base_color.g, base_color.a)
	if biome == "void":
		base_color = Color(base_color.r * 0.9, base_color.g * 0.8, base_color.b, base_color.a)

	shader_params["albedo"] = base_color
	shader_params["albedo_amount"] = explored_pct

	# Grit texture
	shader_params["grit"] = GraphicsManager.get_grit_texture(256, biome)
	shader_params["grit_amount"] = 0.4

	# Parallax layer
	var parallax := GraphicsManager.get_parallax_layer(biome)
	shader_params["parallax"] = parallax
	shader_params["parallax_fog_amount"] = 0.55
	shader_params["parallax_ground_amount"] = 0.45

	# Biome overlay
	var overlay := GraphicsManager.get_biome_overlay(biome)
	shader_params["overlay"] = overlay
	shader_params["overlay_amount"] = 0.6

	# Vignette shader
	shader_params["vignette"] = _get_vignette_shader_material()

func _get_vignette_shader_material() -> ShaderMaterial:
	var shader := ShaderMaterial.new()
	shader.shader_code = """
shader_type canvas_texture;

uniform sampler2D uVignette;
uniform float uVignetteAmount;

void fragment() {
  vec4 base = texture(uVignette, uv);
  float alpha = smoothstep(0.0, 0.8, length(uv - vec2(0.5)));
  gl_FragColor = base * vec4(1.0, 1.0, 1.0, alpha);
}
"""
	return shader

func _get_albedo_shader_material() -> ShaderMaterial:
	var shader := ShaderMaterial.new()
	shader.shader_code = """
shader_type canvas_texture;

uniform sampler2D uAlbedo;
uniform vec4 uAlbedoColor;
uniform float uAlbedoAmount;

void fragment() {
  gl_FragColor = texture(uAlbedo, uv) * uAlbedoColor * uAlbedoAmount;
}
"""
	return shader

func _get_parallax_shader_material() -> ShaderMaterial:
	var shader := ShaderMaterial.new()
	shader.shader_code = """
shader_type canvas_texture;

uniform sampler2D uParallax;
uniform float uParallaxFogAmount;
uniform float uParallaxGroundAmount;

void fragment() {
  vec3 albedo = texture(uParallax, uv).rgb;
  vec3 parallax = texture(uParallax, uv).rgb;
  parallax = mix(parallax, vec3(0.0), 0.55 * texture(uParallax, uv).a);
  gl_FragColor = vec4(albedo + parallax, 1.0);
}
"""
	return shader

func _get_grit_shader_material() -> ShaderMaterial:
	var shader := ShaderMaterial.new()
	shader.shader_code = """
shader_type canvas_texture;

uniform sampler2D uNoise;
uniform float uNoiseAmount;

void fragment() {
  gl_FragColor = texture(uNoise, uv) * uNoiseAmount;
}
"""
	return shader

func _get_overlay_shader_material() -> ShaderMaterial:
	var shader := ShaderMaterial.new()
	shader.shader_code = """
shader_type canvas_texture;

uniform sampler2D uOverlay;
uniform vec4 uOverlayColor;
uniform float uOverlayAmount;

void fragment() {
  vec3 overlay = texture(uOverlay, uv).rgb;
  overlay = mix(overlay, vec3(1.0), uOverlayAmount);
  gl_FragColor = vec4(overlay, 1.0);
}
"""
	return shader

var albedo_mat: ShaderMaterial
var parallax_mat: ShaderMaterial
var grit_mat: ShaderMaterial
var overlay_mat: ShaderMaterial
var vignette_mat: ShaderMaterial

func _ready() -> void:
	# Pre-create shader materials
	albedo_mat = _get_albedo_shader_material()
	parallax_mat = _get_parallax_shader_material()
	grit_mat = _get_grit_shader_material()
	overlay_mat = _get_overlay_shader_material()
	vignette_mat = _get_vignette_shader_material()

var detail_chance := 0.3
if biome == "Fungal Gardens": detail_chance = 0.5
if biome == "Ruined City": detail_chance = 0.2
if biome == "Void Shallows": detail_chance = 0.4

func _draw() -> void:
	# Base unified shader — no detail dots here; they're drawn by the detail shader.
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader_code = """
shader_type canvas_texture;

uniform sampler2D uAlbedo;
uniform vec4 uAlbedoColor;
uniform float uAlbedoAmount;

uniform sampler2D uParallax;
uniform float uParallaxFogAmount;
uniform float uParallaxGroundAmount;

uniform sampler2D uNoise;
uniform float uNoiseAmount;

uniform sampler2D uOverlay;
uniform vec4 uOverlayColor;
uniform float uOverlayAmount;

uniform sampler2D uVignette;
uniform float uVignetteAmount;

vec2 uRiftPos;
uniform vec4 uRiftColor;
uniform float uRiftSize;

vec2 uRuneCenter;
uniform vec4 uRuneColor;
uniform float uRuneDotSize;
uniform float uRuneLineLen;

void fragment() {
  vec3 albedo = texture(uAlbedo, uv).rgb;
  albedo = mix(albedo, vec3(0.0), 1.0 - uAlbedoAmount);

  vec3 parallax = texture(uParallax, uv).rgb;
  parallax = mix(parallax, vec3(0.0), uParallaxFogAmount * texture(uParallax, uv).a);
  parallax = mix(parallax, vec3(0.0), uParallaxGroundAmount);

  vec3 noise = texture(uNoise, uv).rgb * uNoiseAmount;

  vec3 overlay = texture(uOverlay, uv).rgb;
  overlay = mix(overlay, albedo, uOverlayAmount);

  vec3 vignette = texture(uVignette, uv).rgb;
  float alpha = smoothstep(0.0, 0.8, length(uv - vec2(0.5)));
  vignette = vignette * alpha;

  vec3 color = albedo + parallax + noise + overlay + vignette;

  // Rift
  if (uRiftPos.x >= 0.0 && uRiftPos.x <= 1.0 && uRiftPos.y >= 0.0 && uRiftPos.y <= 1.0) {
    vec2 p = uv - uRiftPos;
    float d = length(p) * uRiftSize;
    if (d < 0.4) {
      color = mix(color, uRiftColor.rgb, 0.15);
    }
  }

  // Rune marker
  if (uRuneCenter.x >= 0.0 && uRuneCenter.x <= 1.0 && uRuneCenter.y >= 0.0 && uRuneCenter.y <= 1.0) {
    float dist = length(uv - uRuneCenter);
    if (dist < uRuneDotSize) {
      color += uRuneColor.rgb * 0.8;
    }
    vec2 dir = normalize(uv - uRuneCenter);
    float line_len = clamp(uRuneLineLen - dist, 0.0, uRuneLineLen);
    vec2 line_end = uRuneCenter + dir * line_len;
    if (line_end.x >= 0.0 && line_end.x <= 1.0 && line_end.y >= 0.0 && line_end.y <= 1.0) {
      color = mix(color, uRuneColor.rgb, 0.3);
    }
  }

  gl_FragColor = vec4(color, 1.0);
}
"""
	shader_mat.set_shader_param("uAlbedo", albedo_mat)
	shader_mat.set_shader_param("uAlbedoColor", Color(shader_params["albedo"]))
	shader_mat.set_shader_param("uAlbedoAmount", shader_params["albedo_amount"])
	shader_mat.set_shader_param("uParallax", parallax_mat)
	shader_mat.set_shader_param("uParallaxFogAmount", shader_params["parallax_fog_amount"])
	shader_mat.set_shader_param("uParallaxGroundAmount", shader_params["parallax_ground_amount"])
	shader_mat.set_shader_param("uNoise", grit_mat)
	shader_mat.set_shader_param("uNoiseAmount", shader_params["grit_amount"])
	shader_mat.set_shader_param("uOverlay", overlay_mat)
	shader_mat.set_shader_param("uOverlayColor", shader_params["overlay"])
	shader_mat.set_shader_param("uOverlayAmount", shader_params["overlay_amount"])
	shader_mat.set_shader_param("uVignette", vignette_mat)
	shader_mat.set_shader_param("uVignetteAmount", 1.0)
	shader_mat.set_shader_param("uRiftPos", Vector2(0.0, 0.0))
	shader_mat.set_shader_param("uRiftColor", Color(0.5, 0.4, 0.8, 0.15))
	shader_mat.set_shader_param("uRiftSize", 2.0)
	shader_mat.set_shader_param("uRuneCenter", Vector2(0.5, 0.35))
	shader_mat.set_shader_param("uRuneColor", Color(0.9, 0.85, 0.7, 1.0))
	shader_mat.set_shader_param("uRuneDotSize", 0.8)
	shader_mat.set_shader_param("uRuneLineLen", 1.8)
	shader_mat.render()

	# Detail-dots shader — only runs when we have a chance to draw dots.
	if detail_chance > 0:
		var detail_mat := ShaderMaterial.new()
		detail_mat.shader_code = """
shader_type canvas_texture;

uniform sampler2D uOverlay;
uniform int uDetailChance;

void fragment() {
  if (hash(uv.xy) % uDetailChance == 0) {
    float dot_size = rand() * 1.5 + 0.5;
    vec4 dot_color = texture(uOverlay, uv);
    dot_color.rgb = mix(dot_color.rgb, vec3(0.1), rand());
    gl_FragColor = dot_color;
  } else {
    gl_FragColor = vec4(0.0);
  }
}
"""
		detail_mat.set_shader_param("uOverlay", overlay_mat)
		detail_mat.set_shader_param("uDetailChance", 20)
		detail_mat.render()

	# Rocks shader — only when has_rocks is true.
	if has_rocks:
		var rocks_mat := ShaderMaterial.new()
		rocks_mat.shader_code = """
shader_type canvas_texture;

uniform sampler2D uOverlay;
uniform int uDetailChance;

void fragment() {
  if (hash(uv.xy) % uDetailChance == 0) {
    float dot_size = rand() * 0.8 + 0.2;
    vec4 dot_color = texture(uOverlay, uv);
    dot_color.rgb = mix(dot_color.rgb, vec3(0.12, 0.10, 0.08), rand());
    gl_FragColor = dot_color;
  } else {
    gl_FragColor = vec4(0.0);
  }
}
"""
		rocks_mat.set_shader_param("uOverlay", overlay_mat)
		rocks_mat.set_shader_param("uDetailChance", 20)
		rocks_mat.render()

	# Vegetation shader — only when has_vegetation is true.
	if has_vegetation:
		var vegetation_mat := ShaderMaterial.new()
		vegetation_mat.shader_code = """
shader_type canvas_texture;

uniform sampler2D uOverlay;
uniform int uDetailChance;

void fragment() {
  if (hash(uv.xy) % uDetailChance == 0) {
    float dot_size = rand() * 1.2 + 0.2;
    vec4 dot_color = texture(uOverlay, uv);
    vec3 veg_base = vec3(0.15, 0.18, 0.08);
    dot_color.rgb = mix(dot_color.rgb, veg_base, rand());
    gl_FragColor = dot_color;
  } else {
    gl_FragColor = vec4(0.0);
  }
}
"""
		vegetation_mat.set_shader_param("uOverlay", overlay_mat)
		vegetation_mat.set_shader_param("uDetailChance", 20)
		vegetation_mat.render()