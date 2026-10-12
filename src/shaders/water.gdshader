// Still dark water in the drowned streets: every sound ripples it.
shader_type spatial;
render_mode cull_disabled;
#include "res://src/shaders/noise.gdshaderinc"

uniform vec4 deep : source_color = vec4(0.01, 0.025, 0.03, 1.0);
uniform vec4 tint : source_color = vec4(0.05, 0.1, 0.11, 1.0);
uniform float ripple = 1.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float t = TIME;
	float h1 = fbm(p * 1.6 + vec2(t * 0.11, t * 0.07));
	float h2 = fbm(p * 3.2 - vec2(t * 0.09, -t * 0.13));
	float e = 0.03;
	float hx = fbm((p + vec2(e, 0.0)) * 1.6 + vec2(t * 0.11, t * 0.07)) - h1;
	float hz = fbm((p + vec2(0.0, e)) * 1.6 + vec2(t * 0.11, t * 0.07)) - h1;
	NORMAL_MAP = normalize(vec3(-hx * 8.0 * ripple, -hz * 8.0 * ripple, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	ALBEDO = mix(deep.rgb, tint.rgb, h2 * 0.4);
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.9;
}
