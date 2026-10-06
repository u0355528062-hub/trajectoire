shader_type spatial;

// Baseplate grise, plate : micro-variations, grille très discrète, reflets doux.
uniform vec3 base_color : source_color = vec3(0.46, 0.47, 0.48);
uniform float grid_size = 4.0;
uniform float grid_strength = 0.055;

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
	vec2 uv = wpos.xz;
	float dist = length(wpos - CAMERA_POSITION_WORLD);

	vec2 g = uv / grid_size;
	vec2 aa = fwidth(g) * 1.2;
	vec2 gl = abs(fract(g - 0.5) - 0.5) / max(aa, vec2(0.0001));
	float line = 1.0 - clamp(min(gl.x, gl.y), 0.0, 1.0);
	line *= 1.0 - smoothstep(25.0, 90.0, dist);

	float n = vnoise(uv * 2.0) * 0.5 + vnoise(uv * 9.0) * 0.3 + vnoise(uv * 41.0) * 0.2;
	n = mix(n, 0.5, smoothstep(10.0, 60.0, dist)); // lisse au loin (évite le scintillement)

	vec3 col = base_color * (0.93 + 0.14 * n);
	col *= 1.0 - line * grid_strength * 4.0;
	ALBEDO = col;
	ROUGHNESS = 0.62 - 0.18 * n;
	SPECULAR = 0.5;
	METALLIC = 0.0;
}
