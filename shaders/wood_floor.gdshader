// Parquet à lames procédural (coordonnées monde XZ).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 color_a : source_color = vec3(0.58, 0.40, 0.25);
uniform vec3 color_b : source_color = vec3(0.40, 0.25, 0.14);
uniform float plank_width = 0.19;
uniform float plank_length = 1.4;
uniform float gloss = 0.55;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float row = floor(p.y / plank_width);
	float offs = hash(vec2(row, 3.17)) * plank_length;
	float col = floor((p.x + offs) / plank_length);
	vec2 id = vec2(col, row);
	vec2 local = vec2(fract((p.x + offs) / plank_length), fract(p.y / plank_width));
	float h = hash(id);
	float n = texture(noise_tex, vec2(p.x * 0.11 + h * 7.0, p.y * 1.7 + h * 3.0)).r;
	float fine = texture(noise_tex, vec2(p.x * 0.9 + h * 2.0, p.y * 9.0)).r;
	float grain = sin(local.y * plank_width * 140.0 + n * 9.0 + h * 12.0) * 0.5 + 0.5;
	vec3 base = mix(color_a, color_b, clamp(h * 0.55 + grain * 0.18 + n * 0.35, 0.0, 1.0));
	base *= 0.9 + fine * 0.2;
	float ex = 0.0035 / plank_length;
	float ey = 0.0035 / plank_width;
	float gap = smoothstep(0.0, ex, local.x) * smoothstep(0.0, ex, 1.0 - local.x)
		* smoothstep(0.0, ey, local.y) * smoothstep(0.0, ey, 1.0 - local.y);
	ALBEDO = base * mix(0.3, 1.0, gap);
	ROUGHNESS = clamp(mix(0.85, 1.0 - gloss, gap) + (fine - 0.5) * 0.12 + grain * 0.06, 0.05, 1.0);
	SPECULAR = 0.5;
}
