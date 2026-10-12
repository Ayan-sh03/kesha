// Full-screen post: the doors you've given change what reaches you.
shader_type canvas_item;
#include "res://src/shaders/noise.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float eye_lost = 0.0;
uniform float band = 0.0;
uniform float hurt = 0.0;
uniform float burn = 0.0;
uniform float indigo = 0.0;
uniform float grain = 0.045;
uniform float vignette = 0.45;
uniform float letterbox = 0.0;
uniform float heat = 0.0;
uniform float desat = 0.0;
uniform float fade = 0.0;
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float knock = 0.0;
uniform float moths = 0.0;
uniform float chroma = 0.0;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float smoke = 0.0;
uniform float time_s = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	if (heat > 0.0) {
		vec2 hn = vec2(vnoise(uv * vec2(14.0, 7.0) + vec2(0.0, time_s * 2.3)), vnoise(uv * vec2(11.0, 9.0) - vec2(time_s, time_s * 1.7)));
		uv += (hn - 0.5) * 0.008 * heat;
	}
	uv.x += sin(uv.y * 28.0 + time_s * 22.0) * 0.004 * knock;
	vec2 dir = uv - 0.5;
	float ca = chroma * 0.008 + hurt * 0.005 + knock * 0.004;
	vec3 col;
	col.r = texture(screen_tex, uv + dir * ca).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - dir * ca).b;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l), desat);
	// the Mother's hold: indigo creeps into the shadows
	float sh = 1.0 - smoothstep(0.0, 0.5, l);
	col = mix(col, col * vec3(0.78, 0.85, 1.25) + vec3(0.004, 0.006, 0.03) * sh, indigo);
	// kiln smoke
	if (smoke > 0.0) {
		float s = fbm(uv * vec2(4.0, 3.0) + vec2(time_s * 0.15, -time_s * 0.1));
		col = mix(col, vec3(0.16, 0.14, 0.13), smoke * (0.4 + 0.6 * s));
	}
	float v = smoothstep(0.9, 0.25, length(dir * vec2(1.0, 0.8)));
	col *= mix(1.0, v, vignette);
	col = mix(col, vec3(0.45, 0.02, 0.02), hurt * (1.0 - v) * 0.9);
	// moths settle on the doors of your face
	if (moths > 0.0) {
		float m = fbm(uv * vec2(18.0, 10.0) + vec2(time_s * 0.6, sin(time_s) * 0.3));
		float edge = smoothstep(0.25, 0.75, length(dir * vec2(1.0, 0.75)) * 1.4);
		col = mix(col, vec3(0.03, 0.04, 0.12), moths * edge * smoothstep(0.35, 0.65, m));
	}
	// one eye given: the left third of the world goes dark
	float e = 0.333 + (vnoise(vec2(uv.y * 5.0, time_s * 0.15)) - 0.5) * 0.035;
	float blind = smoothstep(e + 0.035, e - 0.05, uv.x);
	col *= 1.0 - blind * eye_lost * 0.97;
	// eyes shut in the shut prayer: warm dark of the lids
	col = mix(col, vec3(0.07, 0.012, 0.01) + col * 0.04, band);
	col = mix(col, vec3(1.0, 0.95, 0.86), burn);
	col += (hash12(uv * vec2(1920.0, 1080.0) + fract(time_s) * 100.0) - 0.5) * grain;
	col = mix(col, flash_color.rgb, flash * flash_color.a);
	col = mix(col, fade_color.rgb, fade);
	float lb = letterbox * 0.11;
	if (SCREEN_UV.y < lb || SCREEN_UV.y > 1.0 - lb) {
		col = vec3(0.0);
	}
	COLOR = vec4(col, 1.0);
}
