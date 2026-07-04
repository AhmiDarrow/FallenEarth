shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.3, 0.25, 0.45, 1.0);
uniform float distortion_speed : hint_range(0.1, 5.0) = 1.0;
uniform float distortion_strength : hint_range(0.0, 1.0) = 0.15;
uniform float pulse_speed : hint_range(0.5, 5.0) = 2.0;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.3;
uniform float rim_power : hint_range(0.5, 5.0) = 2.0;
uniform float time = 0.0;

void vertex() {
	float t = TIME * distortion_speed;
	float wave = sin(VERTEX.x * 4.0 + t) * cos(VERTEX.z * 3.0 + t * 0.7) * distortion_strength;
	VERTEX += NORMAL * wave;
}

void fragment() {
	float t = TIME * distortion_speed;
	float pulse = 1.0 + sin(t * pulse_speed) * pulse_strength;

	vec3 rim_dir = normalize(VIEW);
	float rim = 1.0 - max(dot(NORMAL, rim_dir), 0.0);
	rim = pow(rim, rim_power);

	vec3 col = base_color.rgb * pulse;
	col += rim * base_color.rgb * 0.5;

	float alpha = base_color.a * (0.7 + rim * 0.3);
	ALBEDO = col;
	ALPHA = alpha;
	EMISSION = col * 1.5;
}
