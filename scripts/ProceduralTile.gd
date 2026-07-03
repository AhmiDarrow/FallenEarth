class_name ProceduralTile
extends CanvasTexture

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
	var shader := Shader.new()
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
	shader.set("parameters/uVignette/texture", null)
	shader.set("parameters/uVignetteAmount/value", 1.0)
	return shader


func _get_albedo_shader_material() -> ShaderMaterial:
	var shader := Shader.new()
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
	var shader := Shader.new()
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
	var shader := Shader.new()
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
	var shader := Shader.new()
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


func draw() -> void:
	# Unified shader that mixes all layers
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

  gl_FragColor = vec4(albedo + parallax + noise + overlay + vignette, 1.0);
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
	shader_mat.render()

	# Cross-hatch texture
	if biome_palette.has("cross_hatch"):
		var p := biome_palette["cross_hatch"]
		var repeat := 3.0 / max(1.0, p.size())
		var p2 := p * repeat
		for y in range(4):
			draw_line(Vector2(0, y * p2), Vector2(size.x, y * p2), p)
		for x in range(4):
			draw_line(Vector2(x * p2, 0), Vector2(x * p2, size.y), p)

	# Detail dots (rocks, flora)
	var detail_chance := 0.3
	if biome == "Fungal Gardens": detail_chance = 0.5
	if biome == "Ruined City": detail_chance = 0.2
	if biome == "Void Shallows": detail_chance = 0.4

	for _ in range(20):
		if randf() > detail_chance: continue
		var pos := Vector2(randf() * size.x, randf() * size.y)
		var dot_size := randf_range(0.5, 1.5)
		var dot_color := biome_palette.get("detail", Color(0.1, 0.1, 0.1))
		if biome == "Fungal Gardens": dot_color = Color(0.2, 0.3, 0.15)
		if biome == "Ruined City": dot_color = Color(0.3, 0.25, 0.25)
		if biome == "Void Shallows": dot_color = Color(0.15, 0.1, 0.25)
		draw_circle(pos, dot_size, dot_color)

	# Rift visual
	if has_rift:
		var rift_color := Color(0.5, 0.4, 0.8, 0.15)
		if rift_type == 1: rift_color = Color(0.8, 0.2, 0.8, 0.15)  # Void
		if rift_type == 2: rift_color = Color(0.2, 0.8, 0.6, 0.15)  # Life
		draw_polygon([
			pos - Vector2(3, 3),
			pos + Vector2(3, -3),
			pos + Vector2(3, 3),
			pos - Vector2(-3, -3)
		], rift_color, 2.0, rift_color)

	# Rune marker
	if has_rune:
		var rune_center := Vector2(size.x * 0.5, size.y * 0.35)
		var rune_color := biome_palette.get("rune", Color(0.9, 0.85, 0.7))
		draw_circle(rune_center, 0.8, rune_color)
		draw_line(rune_center - Vector2(1.8, 0), rune_center + Vector2(1.8, 0), rune_color)
		draw_line(rune_center - Vector2(0, 1.8), rune_center + Vector2(0, 1.8), rune_color)
