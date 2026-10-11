shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

// Feuillage en cartes (bouquets de feuilles, atlas 2 x 2) instanciées par MultiMesh :
// normales « sphériques » autour du centre du houppier (volume), occlusion vers l'intérieur,
// lumière qui traverse les feuilles à contre-jour, balancement au vent.
// INSTANCE_CUSTOM.a : case de l'atlas (partie entière de a*4) + aléa (partie fractionnaire).
// COLOR : teinte de la carte.

uniform sampler2D leaves : source_color, filter_linear_mipmap_anisotropic;
uniform float wind = 1.0;
uniform vec3 backlight_tint : source_color = vec3(0.55, 0.62, 0.22);
instance uniform vec3 crown_center = vec3(0.0, 8.0, 0.0);
instance uniform vec3 crown_radius = vec3(4.0, 3.5, 4.0);
instance uniform vec3 tree_tint = vec3(1.0);

varying vec3 v_tint;
varying float v_ao;

void vertex() {
	float a4 = INSTANCE_CUSTOM.a * 4.0;
	float cell = floor(a4);
	float rnd = fract(a4);
	UV = UV * 0.5 + vec2(mod(cell, 2.0), floor(cell * 0.5)) * 0.5;
	vec3 rel = (VERTEX - crown_center) / crown_radius;
	float r = length(rel);
	vec3 od = normalize(rel + vec3(0.0, 0.25, 0.0));
	NORMAL = normalize(mix(NORMAL, od, 0.82));
	v_ao = clamp(0.35 + r * 0.75, 0.35, 1.0);
	// bas du houppier plus sombre (ombre propre)
	v_ao *= clamp(0.75 + rel.y * 0.35, 0.45, 1.0);
	v_tint = COLOR.rgb * tree_tint;
	// vent : grand balancement du houppier + frémissement des bouquets
	float h = clamp(rel.y * 0.5 + 0.6, 0.0, 1.2);
	float ph = TIME * 0.9 + crown_center.x * 0.37 + crown_center.z * 0.21;
	vec3 sway = vec3(sin(ph) + 0.4 * sin(ph * 2.7), 0.0, 0.6 * sin(ph * 0.8 + 1.3)) * 0.07 * h;
	float fl = TIME * 4.2 + rnd * 40.0 + VERTEX.x * 0.8 + VERTEX.y * 0.6;
	vec3 flutter = vec3(sin(fl), sin(fl * 1.31 + 2.0) * 0.6, cos(fl * 0.87)) * 0.035;
	VERTEX += (sway + flutter * r) * wind;
}

void fragment() {
	vec4 t = texture(leaves, UV);
	ALBEDO = t.rgb * v_tint;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.42;
	ROUGHNESS = 0.62;
	SPECULAR = 0.32;
	AO = v_ao;
	AO_LIGHT_AFFECT = 0.55;
	BACKLIGHT = backlight_tint * t.rgb * 1.6;
}
