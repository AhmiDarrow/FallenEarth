shader_type spatial;

uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 flash_color : source_color = vec4(1.0, 0.0, 0.0, 0.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float noise_scale : hint_range(0.0, 10.0) = 2.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV * noise_scale;
	float n = noise(uv);
	vec3 col = mix(base_color.rgb, tint_color.rgb, tint_color.a);
	col = mix(col, flash_color.rgb, flash_amount);
	col += (n - 0.5) * 0.05;
	ALBEDO = col;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}
