// The Veiled Mother's curtain: indigo dabu cloth, wind, something pressing
// through from behind, her light seeping through, and a burning hem.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
#include "res://src/shaders/noise.gdshaderinc"

uniform sampler2D cloth_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D cloth_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 size = vec2(1.6, 2.6);
uniform float tex_scale = 0.9;
uniform float wind = 1.0;
uniform float press = 0.0;
uniform vec2 press_uv = vec2(0.5, 0.3);
uniform float hand = 0.0;
uniform vec2 hand_uv = vec2(0.64, 0.55);
uniform float glow = 0.0;
uniform vec4 glow_color : source_color = vec4(0.62, 0.68, 1.0, 1.0);
uniform float burn = 0.0;
uniform float gap = 0.0;
uniform float breathe = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying vec2 luv;

float bump(vec2 uv, vec2 c, vec2 r) {
	vec2 d = (uv - c) / r;
	return exp(-dot(d, d));
}

void vertex() {
	luv = vec2(VERTEX.x / size.x + 0.5, 0.5 - VERTEX.y / size.y);
	float hang = clamp(luv.y, 0.0, 1.0);
	float t = TIME;
	float w = sin(VERTEX.x * 3.1 + t * 1.3) * 0.045 + sin(VERTEX.x * 7.3 - t * 2.1 + VERTEX.y * 2.0) * 0.016 + sin(t * 0.7 + VERTEX.y * 1.3) * 0.035;
	VERTEX.z += w * wind * hang * (0.4 + hang);
	VERTEX.x += sin(t * 0.9 + VERTEX.y * 2.0) * 0.02 * wind * hang;
	// a face presses through from behind
	vec2 a = vec2(size.x / size.y, 1.0);
	float face = bump(luv * a, press_uv * a, vec2(0.11, 0.15));
	float brow = bump(luv * a, (press_uv + vec2(0.0, -0.035)) * a, vec2(0.09, 0.03));
	float nose = bump(luv * a, (press_uv + vec2(0.0, 0.01)) * a, vec2(0.018, 0.04));
	float eyes = bump(luv * a, (press_uv + vec2(-0.045, -0.015)) * a, vec2(0.025, 0.015)) + bump(luv * a, (press_uv + vec2(0.045, -0.015)) * a, vec2(0.025, 0.015));
	float pr = press * (1.0 + breathe * 0.15 * sin(t * 1.6));
	VERTEX.z += (face * 0.2 + brow * 0.03 + nose * 0.05 - eyes * 0.025) * pr;
	// a handprint pressed from behind
	float palm = bump(luv * a, hand_uv * a, vec2(0.05, 0.05));
	float fingers = 0.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i) - 2.0;
		vec2 fc = hand_uv + vec2(fi * 0.024, -0.075 + abs(fi) * 0.014);
		fingers += bump(luv * a, fc * a, vec2(0.011, 0.04));
	}
	VERTEX.z += (palm * 0.08 + fingers * 0.06) * hand;
}

void fragment() {
	vec2 uv = luv * size / tex_scale;
	vec3 alb = texture(cloth_tex, uv).rgb * tint.rgb;
	float n = fbm(luv * vec2(9.0, 5.0));
	float line = 1.0 - burn * 1.15 + (n - 0.5) * 0.3;
	if (burn > 0.0 && luv.y > line) {
		discard;
	}
	float ember = burn > 0.0 ? smoothstep(line - 0.07, line, luv.y) : 0.0;
	if (gap > 0.0 && abs(luv.x - 0.5) < gap * 0.045 * (0.2 + luv.y * 1.1)) {
		discard;
	}
	ALBEDO = mix(alb, vec3(0.05, 0.02, 0.01), ember);
	NORMAL_MAP = texture(cloth_normal, uv).rgb;
	ROUGHNESS = 0.95;
	float thin = dot(alb, vec3(0.333));
	vec3 light = glow_color.rgb * glow * (0.2 + thin * 1.6) * (0.7 + 0.3 * sin(TIME * 0.8 + luv.y * 4.0));
	EMISSION = light + vec3(1.0, 0.38, 0.07) * ember * 4.0;
	BACKLIGHT = vec3(0.25, 0.3, 0.6);
}
