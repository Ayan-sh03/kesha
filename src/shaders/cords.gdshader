// Gaara's counting cords, hanging like roots, swaying by touch.
shader_type spatial;
uniform sampler2D rope_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float cord_len = 8.0;
uniform float sway = 1.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float hang = clamp((cord_len * 0.5 - VERTEX.y) / cord_len, 0.0, 1.0);
	float ph = o.x * 1.7 + o.z * 2.3;
	VERTEX.x += sin(TIME * 0.7 + ph) * 0.12 * sway * hang * hang;
	VERTEX.z += cos(TIME * 0.5 + ph * 1.3) * 0.08 * sway * hang * hang;
}

void fragment() {
	ALBEDO = texture(rope_tex, UV * vec2(1.0, cord_len * 2.0)).rgb * tint.rgb;
	ROUGHNESS = 0.95;
}
