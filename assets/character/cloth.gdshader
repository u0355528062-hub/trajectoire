shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Tissus des vêtements : couleur + motif tissé répété (normale, et albedo pour le denim),
// détails propres au vêtement cuits sur l'UV du corps : normales (coutures, poches, côtes, plis)
// et masque (R ombrage, G garnitures/fil, B usure ou bandes, A zone spéciale : zip, œillets, croix).

uniform vec4 color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 trim_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float trim_mix = 0.0;
uniform vec4 wear_color : source_color = vec4(1.0);
uniform float wear_amount = 0.0;
uniform vec4 special_color : source_color = vec4(0.6, 0.6, 0.62, 1.0);
uniform float special_on = 1.0;
uniform float special_metal = 0.0;
uniform sampler2D garment_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D garment_m : filter_linear_mipmap_anisotropic, repeat_disable;
uniform float garment_depth = 1.0;
uniform sampler2D weave_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float weave_scale = 6.0;
uniform float weave_depth = 0.3;
uniform sampler2D weave_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float weave_albedo = 0.0;
uniform float rough = 0.85;
uniform float sheen = 0.0;
uniform float sheen_tint = 0.6;

void fragment() {
	vec4 m = texture(garment_m, UV);
	vec3 base = color.rgb;
	vec3 wa = texture(weave_a, UV * weave_scale).rgb;
	base = mix(base, base * wa * 3.0, weave_albedo);
	base = mix(base, trim_color.rgb, m.g * trim_mix);
	base = mix(base, wear_color.rgb, clamp(m.b * wear_amount, 0.0, 1.0));
	float sp = m.a * special_on;
	base = mix(base, special_color.rgb, sp);
	ALBEDO = base * m.r;
	vec2 g = texture(garment_n, UV).xy * 2.0 - 1.0;
	vec2 w = texture(weave_n, UV * weave_scale).xy * 2.0 - 1.0;
	NORMAL_MAP = vec3((g * garment_depth + w * weave_depth) * 0.5 + 0.5, 1.0);
	ROUGHNESS = mix(rough, 0.35, sp * special_metal);
	METALLIC = sp * special_metal;
	RIM = sheen;
	RIM_TINT = sheen_tint;
}
