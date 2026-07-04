shader_type spatial;
render_mode unshaded;

uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 0.1) = 0.02;

void vertex() {
	vec3 normal_world = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	VERTEX += normal_world * outline_width;
}

void fragment() {
	ALBEDO = base_color.rgb;
	ALPHA = base_color.a;
}
