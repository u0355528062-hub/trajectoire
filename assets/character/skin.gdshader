shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Peau des personnages : teint cuit (RGB) + brillance du sébum (A), pores à deux échelles,
// translucidité (oreilles, doigts) et léger duvet en lumière rasante. Pas d'aspect plastique :
// rugosité élevée hors zone T, spéculaire de la peau (F0 ~ 0,028).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D pores : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float pore_depth = 0.55;
uniform float sss = 0.3;
uniform float rim = 0.12;

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	vec3 col = a.rgb * tint.rgb;
	ALBEDO = col;
	ROUGHNESS = mix(0.68, 0.38, a.a);
	SPECULAR = 0.36;
	vec2 n1 = texture(pores, UV).xy * 2.0 - 1.0;
	vec2 n2 = texture(pores, UV * 3.7 + vec2(0.31, 0.17)).xy * 2.0 - 1.0;
	NORMAL_MAP = vec3((n1 + n2 * 0.7) * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = pore_depth;
	SSS_STRENGTH = sss;
	BACKLIGHT = col * vec3(0.55, 0.22, 0.14);
	RIM = rim;
	RIM_TINT = 0.55;
}
