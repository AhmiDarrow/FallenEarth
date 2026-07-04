shader_type canvas_item;

uniform vec2 pixel_size = vec2(0.001, 0.001);
uniform float stylize_strength : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec2 uv = UV;
	vec2 snapped = floor(uv / pixel_size) * pixel_size + pixel_size * 0.5;
	vec4 col = texture(TEXTURE, snapped);

	float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	vec3 stylized = mix(col.rgb, vec3(gray), stylize_strength);
	stylized = floor(stylized * 8.0) / 8.0;

	COLOR = vec4(stylized, col.a);
}
