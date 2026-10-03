// Carrelage grand format procédural (coordonnées monde XZ).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 tile_color : source_color = vec3(0.82, 0.8, 0.76);
uniform vec3 tile_color_2 : source_color = vec3(0.74, 0.72, 0.69);
uniform vec3 grout_color : source_color = vec3(0.55, 0.54, 0.52);
uniform float tile_size = 0.6;
uniform float grout = 0.004;
uniform float polish = 0.7;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz / tile_size;
	vec2 id = floor(p);
	vec2 local = fract(p);
	float h = hash(id);
	float n = texture(noise_tex, world_pos.xz * 0.35 + h * 5.0).r;
	float veins = texture(noise_tex, world_pos.xz * vec2(0.8, 0.25) + h * 9.0).r;
	vec3 base = mix(tile_color, tile_color_2, clamp(h * 0.6 + n * 0.5, 0.0, 1.0));
	base = mix(base, base * 0.86, smoothstep(0.55, 0.75, veins) * 0.6);
	float g = grout / tile_size;
	float edge = smoothstep(0.0, g, local.x) * smoothstep(0.0, g, 1.0 - local.x)
		* smoothstep(0.0, g, local.y) * smoothstep(0.0, g, 1.0 - local.y);
	ALBEDO = mix(grout_color, base, edge);
	ROUGHNESS = mix(0.9, 1.0 - polish + n * 0.15, edge);
	SPECULAR = 0.55;
}
