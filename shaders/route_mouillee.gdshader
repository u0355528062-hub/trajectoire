shader_type spatial;

// Enrobé du boulevard sous la pluie (remplace le matériau sec de la chaussée quand la météo est humide) :
// bitume assombri et lustré, eau accumulée dans les ornières des voies et en flaques, ronds de gouttes.
// Les reflets viennent du SSR et de la sonde du boulevard.
uniform sampler2D asphalt_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint = vec3(0.82, 0.84, 0.9);
uniform float uv_scale = 1.6;
uniform float wetness : hint_range(0.0, 1.0) = 1.0;
uniform float rain : hint_range(0.0, 1.0) = 1.0;

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
	vec2 uv = p * uv_scale;
	vec3 alb = texture(asphalt_a, uv).rgb * tint;
	vec3 nm = mix(vec3(0.5, 0.5, 1.0), texture(asphalt_n, uv).rgb, 0.3);
	float far_k = smoothstep(18.0, 70.0, length(wpos - CAMERA_POSITION_WORLD));
	// ornières : deux bandes par voie (voies centrées en z = -9.15 et -5.65), l'eau y stagne
	float lane = min(abs(p.y + 9.15), abs(p.y + 5.65));
	float rut = smoothstep(0.38, 0.05, abs(lane - 0.8));
	float n = vnoise(p * 0.22 + 11.0) * 0.6 + vnoise(p * 0.9) * 0.4;
	float pud = smoothstep(0.62, 0.7, n + rut * 0.22 * wetness) * smoothstep(0.3, 0.6, wetness);
	float wk = wetness * (0.85 + 0.15 * n);
	alb *= 1.0 - 0.38 * wk - 0.2 * pud;
	float rough = mix(0.72, 0.16 + 0.12 * (1.0 - n), wk);
	rough = mix(rough, 0.03, pud);
	nm = mix(nm, vec3(0.5, 0.5, 1.0), wk * 0.5 + pud * 0.5);
	if (rain > 0.0) {
		vec2 rip = vec2(0.0);
		for (int l = 0; l < 2; l++) {
			vec2 g = p * 2.3 + float(l) * vec2(0.37, 0.61);
			vec2 id = floor(g);
			vec2 f = fract(g) - 0.5 - (vec2(hash(id), hash(id + 5.3)) - 0.5) * 0.5;
			float ph = fract(TIME * (0.9 + 0.5 * hash(id + 2.1)) + hash(id + 9.7));
			float r = length(f);
			float dd = r - ph * 0.42;
			float wave = sin(dd * 46.0) * smoothstep(0.07, 0.0, abs(dd)) * (1.0 - ph);
			rip += f / max(r, 0.001) * wave;
		}
		nm.xy += rip * 0.22 * rain * (pud + 0.3) * (1.0 - far_k);
	}
	ALBEDO = alb;
	NORMAL_MAP = nm;
	ROUGHNESS = clamp(rough, 0.03, 1.0);
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
