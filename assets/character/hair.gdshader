shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Cheveux en coques : mèches (V = sens de la mèche) avec reflet anisotrope le long de la mèche,
// bord découpé mèche à mèche (alpha testé, couverture MSAA) grâce au masque de bord (COLOR.a).

uniform vec4 color : source_color = vec4(0.1, 0.07, 0.05, 1.0);
uniform sampler2D strands : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D strands_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 tiling = vec2(4.0, 2.0);
uniform float aniso = 0.55;
uniform float rough = 0.55;
uniform float spec = 0.2;
uniform float curl = 0.0;

void fragment() {
	vec2 uv = UV * tiling;
	uv.x += curl * 0.04 * sin(uv.y * 40.0);
	vec4 s = texture(strands, uv);
	float edge = COLOR.a;
	ALBEDO = color.rgb * mix(0.55, 1.15, s.r) * mix(0.75, 1.0, edge);
	NORMAL_MAP = texture(strands_n, uv).xyz;
	NORMAL_MAP_DEPTH = 0.8;
	ROUGHNESS = rough;
	SPECULAR = spec;
	ANISOTROPY = aniso;
	ANISOTROPY_FLOW = vec2(0.0, 1.0);
	BACKLIGHT = color.rgb * 0.4;
	ALPHA = clamp(edge * 1.6 + s.a - 0.5, 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.3;
	ALPHA_TEXTURE_COORDINATE = uv * vec2(textureSize(strands, 0));
}
