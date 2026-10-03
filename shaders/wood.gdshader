// Bois verni pour le mobilier (utilise les UV métriques du maillage).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 color_a : source_color = vec3(0.62, 0.44, 0.28);
uniform vec3 color_b : source_color = vec3(0.44, 0.29, 0.17);
uniform float ring_scale = 26.0;
uniform float varnish = 0.6;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 uv = UV;
	float n = texture(noise_tex, uv * vec2(0.4, 3.0)).r;
	float fine = texture(noise_tex, uv * vec2(3.0, 30.0)).r;
	float rings = sin((uv.y + n * 0.25) * ring_scale + n * 6.0) * 0.5 + 0.5;
	vec3 c = mix(color_a, color_b, clamp(rings * 0.55 + n * 0.45, 0.0, 1.0));
	c *= 0.92 + fine * 0.16;
	ALBEDO = c;
	ROUGHNESS = clamp(1.0 - varnish + fine * 0.1, 0.05, 1.0);
	SPECULAR = 0.5;
	CLEARCOAT = varnish * 0.6;
	CLEARCOAT_ROUGHNESS = 0.2;
}
