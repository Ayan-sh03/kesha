// Far painted backdrops: no engine fog (the painting has its own atmosphere).
// grounding at the bottom edge. Unshaded (the painting carries its own light)
// but fog and volumetric fog still pass in front of it.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha, shadows_disabled, fog_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 grade : source_color = vec4(0.42, 0.45, 0.62, 1.0);
uniform float brightness = 1.0;
uniform float keep_lights = 1.0;
uniform float desat = 0.15;
uniform float bottom_fade = 0.0;
uniform float alpha_mul = 1.0;
uniform float mirror = 0.0;
uniform vec4 add_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float flicker = 0.0;

void fragment() {
	vec2 uv = UV;
	if (mirror > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	vec4 c = texture(tex, uv);
	float a = c.a * alpha_mul;
	if (bottom_fade > 0.0) {
		a *= smoothstep(1.0, 1.0 - bottom_fade, UV.y);
	}
	if (a < 0.02) {
		discard;
	}
	vec3 col = c.rgb;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(col, vec3(l), desat) * grade.rgb * brightness;
	// warm bright paint = flames and lit windows: they stay lit at night
	float warm = smoothstep(0.55, 0.85, max(col.r, col.g)) * smoothstep(0.05, 0.3, col.r - col.b);
	float fl = 1.0 + flicker * 0.15 * sin(TIME * 9.0 + UV.x * 40.0);
	ALBEDO = mix(g, col * 1.5 * fl, warm * keep_lights) + add_color.rgb;
	ALPHA = a;
}
