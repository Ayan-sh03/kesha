// Fired clay: crumbles to dust (enemies dying) or reveals in steps.
shader_type spatial;
#include "res://src/shaders/noise.gdshaderinc"
uniform vec4 albedo : source_color = vec4(0.7, 0.35, 0.2, 1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float amount = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.15, 1.0);
uniform float flash = 0.0;
varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float n = fbm(lp.xy * 3.0 + lp.z * 2.0);
	if (n < amount) {
		discard;
	}
	vec3 tri = texture(albedo_tex, lp.xy * 0.8).rgb;
	ALBEDO = albedo.rgb * tri * 1.6;
	ROUGHNESS = 0.8;
	EMISSION = edge_color.rgb * smoothstep(amount + 0.06, amount, n) * 3.0 * step(0.001, amount) + vec3(flash);
}
