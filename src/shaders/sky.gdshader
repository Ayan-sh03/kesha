// Night over a dead river: dust, stars, a big moon; fire on the horizon when the village burns.
shader_type sky;
#include "res://src/shaders/noise.gdshaderinc"

uniform vec4 top_color : source_color = vec4(0.02, 0.025, 0.07, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.16, 0.12, 0.2, 1.0);
uniform vec4 ground_color : source_color = vec4(0.03, 0.02, 0.02, 1.0);
uniform vec3 moon_dir = vec3(-0.35, 0.32, -1.0);
uniform float moon_size = 0.045;
uniform vec4 moon_color : source_color = vec4(1.0, 0.92, 0.78, 1.0);
uniform float moon_energy = 3.0;
uniform float stars = 1.0;
uniform vec4 fire_color : source_color = vec4(1.0, 0.35, 0.08, 1.0);
uniform float fire = 0.0;
uniform float dust = 0.35;
uniform float clouds = 0.0;
uniform float exposure = 1.0;

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon_color.rgb, top_color.rgb, smoothstep(-0.02, 0.55, h));
	col = mix(col, ground_color.rgb, smoothstep(0.0, -0.15, h));
	if (h > 0.0) {
		vec3 sd = d * 420.0;
		float s = hash13(floor(sd));
		float tw = 0.6 + 0.4 * sin(TIME * (1.0 + s * 4.0) + s * 50.0);
		col += vec3(0.9, 0.9, 1.0) * step(0.9975, s) * tw * stars * smoothstep(0.02, 0.3, h) * (1.0 - clouds);
		vec2 p = d.xz / max(h + 0.08, 0.05);
		float band = fbm(p * 0.6 + vec2(TIME * 0.006, 0.0));
		col = mix(col, horizon_color.rgb * 1.3, dust * band * smoothstep(0.6, 0.0, h));
		float c = smoothstep(0.45, 0.8, fbm(p * 0.35 + vec2(TIME * 0.01, 0.0)));
		col = mix(col, vec3(0.05, 0.05, 0.07), clouds * c);
	}
	vec3 md = normalize(moon_dir);
	float m = distance(d, md);
	float disc = smoothstep(moon_size, moon_size * 0.93, m);
	float crater = 0.85 + 0.15 * fbm(d.xy * 90.0);
	col = mix(col, moon_color.rgb * moon_energy * crater, disc * (1.0 - clouds * 0.7));
	col += moon_color.rgb * (exp(-m * 14.0) * 0.35 + exp(-m * 4.0) * 0.08) * (1.0 - clouds * 0.6);
	col += fire_color.rgb * fire * exp(-max(h, 0.0) * 7.0) * (0.6 + 0.4 * fbm(vec2(atan(d.x, d.z) * 6.0, TIME * 0.3)));
	COLOR = col * exposure;
}
