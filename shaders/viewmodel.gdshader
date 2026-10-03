// Matériau des objets tenus en main (vue à la première personne).
// La profondeur est rapprochée de la caméra pour que l'objet ne traverse
// jamais les murs, tout en gardant un éclairage normal.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, shadows_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, hint_default_white;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.5;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform float clearcoat_amount = 0.0;
uniform float noise_bump = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable, hint_default_white;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// Profondeur inversée (Godot 4.3+) : 1 = plan proche.
	POSITION.z = mix(POSITION.z, POSITION.w, 0.88);
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = albedo.rgb * tex.rgb;
	float n = texture(noise_tex, local_pos.xy * 60.0 + local_pos.z * 37.0).r;
	ROUGHNESS = clamp(roughness + (n - 0.5) * noise_bump, 0.02, 1.0);
	METALLIC = metallic;
	SPECULAR = specular_amount;
	RIM = rim_amount;
	RIM_TINT = 0.5;
	CLEARCOAT = clearcoat_amount;
	CLEARCOAT_ROUGHNESS = 0.15;
	EMISSION = emission * emission_energy;
}
