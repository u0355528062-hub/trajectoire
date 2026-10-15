shader_type spatial;

// Sol du quartier (plan unique, plat) : trottoirs en enrobé gris clair à granulats, zones pavées, chaussées pavées
// des rues adjacentes, allées en stabilisé du square ; taches, flaques, salissures au pied des façades.
// Les zones sont des rectangles (x0, z0, x1, z1) en coordonnées monde, fournis par Streetscape.

uniform sampler2D trottoir_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trottoir_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paves_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paves_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D route_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D route_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stab_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stab_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 roads[4];          // chaussées pavées des rues adjacentes
uniform int road_count = 0;
uniform vec4 paved[6];          // zones de pavés (métro, abords...)
uniform int paved_count = 0;
uniform vec4 stab[4];           // stabilisé (square)
uniform int stab_count = 0;
uniform vec4 hole = vec4(0.0);  // trémie de l'escalier du métro (le sol n'est pas dessiné)
uniform vec2 facades = vec2(-26.0, 19.0);
uniform vec3 tint = vec3(1.0);
uniform float wetness : hint_range(0.0, 1.0) = 0.0;  // sol mouillé (météo) : plus sombre, plus lisse, flaques étendues
uniform float rain : hint_range(0.0, 1.0) = 0.0;     // averse en cours : ronds de gouttes dans les flaques

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

bool inside(vec2 p, vec4 r) {
	return p.x >= r.x && p.x <= r.z && p.y >= r.y && p.y <= r.w;
}

float edge_dist(vec2 p, vec4 r) {
	return min(min(p.x - r.x, r.z - p.x), min(p.y - r.y, r.w - p.y));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	if (inside(p, hole)) {
		discard;
	}
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float far_k = smoothstep(18.0, 70.0, dist);
	float macro = vnoise(p * 0.05) * 0.55 + vnoise(p * 0.21) * 0.3 + vnoise(p * 0.9) * 0.15;

	vec3 alb;
	vec3 nm;
	float rough;
	float wet_ok = 1.0;
	int kind = 0;
	vec4 rr = vec4(0.0);
	for (int i = 0; i < road_count; i++) {
		if (inside(p, roads[i])) { kind = 2; rr = roads[i]; }
	}
	if (kind == 0) {
		for (int i = 0; i < paved_count; i++) {
			if (inside(p, paved[i])) { kind = 1; rr = paved[i]; }
		}
		for (int i = 0; i < stab_count; i++) {
			if (inside(p, stab[i])) { kind = 3; rr = stab[i]; }
		}
	}

	if (kind == 2) {
		// pavés de chaussée : rangées en travers de la rue, joints sombres ; caniveaux plus sombres et humides
		vec2 uv = p * 0.5;
		if (rr.z - rr.x > rr.w - rr.y) { uv = p.yx * 0.5; }
		alb = texture(route_a, uv).rgb;
		nm = texture(route_n, uv).rgb;
		alb *= 0.9 + 0.2 * macro;
		rough = 0.78 - 0.25 * dot(alb, vec3(0.33));
		float ed = edge_dist(p, rr);
		float gut = 1.0 - smoothstep(0.3, 0.55, ed);
		alb *= 1.0 - gut * 0.25;
		rough -= gut * 0.3;
		// traces de roues : bandes plus lisses et un peu plus claires
		float w = abs(fract((rr.z - rr.x > rr.w - rr.y ? p.y - rr.y : p.x - rr.x) / 3.0) - 0.5);
		float track = smoothstep(0.32, 0.22, w) * 0.5;
		rough -= track * 0.12;
		alb *= 1.0 + track * 0.06;
	} else if (kind == 1) {
		// pavés de trottoir (granit mosaïque)
		vec2 uv = p * 0.5 + vec2(0.37, 0.11);
		alb = texture(paves_a, uv).rgb;
		nm = texture(paves_n, uv).rgb;
		alb *= 0.92 + 0.16 * macro;
		rough = 0.74 - 0.2 * dot(alb, vec3(0.33));
	} else if (kind == 3) {
		vec2 uv = p * 0.45;
		alb = texture(stab_a, uv).rgb;
		nm = texture(stab_n, uv).rgb;
		alb *= 0.9 + 0.2 * macro;
		rough = 0.92;
		wet_ok = 0.3;
	} else {
		// enrobé : deux échantillonnages (échelle et rotation différentes) mélangés par un bruit, contre la répétition
		vec2 uv1 = p * 0.25;
		vec2 uv2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 0.19 + vec2(0.31, 0.77);
		float m = smoothstep(0.35, 0.65, vnoise(p * 0.11 + 7.0));
		alb = mix(texture(trottoir_a, uv1).rgb, texture(trottoir_a, uv2).rgb, m);
		nm = mix(texture(trottoir_n, uv1).rgb, texture(trottoir_n, uv2).rgb, m);
		alb *= 0.9 + 0.2 * macro;
		rough = 0.86 - 0.1 * macro;
	}

	// salissures au pied des façades et le long des bordures
	float fz = min(abs(p.y - facades.x), abs(p.y - facades.y));
	alb *= 1.0 - 0.18 * (1.0 - smoothstep(0.0, 0.9, fz)) * (0.6 + 0.4 * macro);

	// flaques (rares par temps sec, étendues sous la pluie) : sombres, lisses, reflets du ciel (SSR)
	float wn = vnoise(p * 0.16 + 31.0);
	float pt = mix(0.74, 0.6, wetness);
	float pud = smoothstep(pt, pt + 0.06, wn) * smoothstep(mix(0.45, 0.3, wetness), mix(0.6, 0.48, wetness), vnoise(p * 0.7 + 3.0)) * wet_ok;
	float damp = smoothstep(mix(0.55, 0.3, wetness), mix(0.75, 0.55, wetness), wn) * wet_ok;
	if (wetness > 0.0) {
		// tout le sol est imbibé : matériaux poreux assombris, film d'eau qui lisse la surface
		float wk = wetness * mix(1.0, 0.55, float(kind == 3));
		alb *= 1.0 - 0.38 * wk;
		rough = mix(rough, rough * 0.5 + 0.12, wk);
		nm = mix(nm, vec3(0.5, 0.5, 1.0), wk * 0.35);
		if (rain > 0.0) {
			// ronds de gouttes (deux couches décalées), seulement près de la caméra
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
			nm.xy += rip * 0.22 * rain * (pud + 0.25 * damp) * (1.0 - far_k);
		}
	}
	alb *= 1.0 - damp * 0.18 - pud * 0.3;
	rough = mix(rough, 0.35, damp * 0.6);
	rough = mix(rough, 0.04, pud);
	nm = mix(nm, vec3(0.5, 0.5, 1.0), pud * 0.9);

	ALBEDO = alb * tint;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = mix(1.0, 0.25, far_k);
	ROUGHNESS = clamp(rough, 0.03, 1.0);
	SPECULAR = 0.5;
	METALLIC = 0.0;
}
