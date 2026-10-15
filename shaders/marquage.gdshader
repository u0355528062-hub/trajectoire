shader_type spatial;

// Peinture routière usée (passages piétons, lignes d'arrêt) : la peinture s'écaille selon un bruit en
// coordonnées monde, plus usée là où passent les roues.

uniform vec3 paint : source_color = vec3(0.93, 0.93, 0.89);
uniform float wear = 0.32;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;  // peinture mouillée : un peu plus sombre et brillante

varying vec3 wpos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
			mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float n = vnoise(p * 1.3) * 0.45 + vnoise(p * 6.0) * 0.3 + vnoise(p * 29.0) * 0.25;
	// traces de roues : deux bandes par voie (voies du boulevard centrées en z = -9.15 et -5.65)
	float lane = min(abs(p.y + 9.15), abs(p.y + 5.65));
	float track = smoothstep(0.35, 0.0, abs(lane - 0.8)) * 0.18;
	float a = smoothstep(wear + track, wear + track + 0.06, n);
	ALBEDO = paint * (0.82 + 0.18 * vnoise(p * 11.0)) * (1.0 - 0.12 * wetness);
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = mix(0.5, 0.18, wetness);
	SPECULAR = 0.45;
}
