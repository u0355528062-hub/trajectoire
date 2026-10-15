shader_type sky;

// Ciel de crépuscule : dégradé chaud -> bleu nuit, halo solaire, nuages procéduraux éclairés par le soleil couchant
// (liseré doré côté soleil, ventres mauves ailleurs), étoiles entre les nuages, tramage contre les bandes de couleur.
// Réglé par Lighting selon le moment et la météo (couvert, nuages bas, halo de la ville la nuit) ; les valeurs par
// défaut sont celles du crépuscule par temps sec.
// Pas de TIME : le ciel reste statique, le reflet (radiance) n'est pas recalculé à chaque image.
uniform vec3 zenith_color : source_color = vec3(0.012, 0.025, 0.11);
uniform vec3 mid_color : source_color = vec3(0.12, 0.17, 0.42);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.52, 0.28);
uniform vec3 ground_color : source_color = vec3(0.16, 0.14, 0.17);
uniform float star_amount : hint_range(0.0, 1.0) = 0.8;
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.52;
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.62, 0.36);
uniform vec3 cloud_shade : source_color = vec3(0.2, 0.17, 0.3);
uniform float cloud_scale = 1.0;                                          // < 1 : nuages plus bas (plus gros)
uniform float overcast : hint_range(0.0, 1.0) = 0.0;                      // couche nuageuse continue (pluie, brume)
uniform vec3 halo_color : source_color = vec3(1.0, 0.45, 0.2);
uniform float halo_k = 0.35;
uniform vec3 glare_color : source_color = vec3(1.0, 0.7, 0.4);
uniform float glare_k = 0.8;
uniform vec3 disc_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float disc_k = 3.0;
uniform vec3 city_glow : source_color = vec3(0.0);                        // halo orangé de la ville (nuit)

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return s;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 col;
	if (h >= 0.0) {
		float t = pow(clamp(h, 0.0, 1.0), 0.45);
		col = mix(horizon_color, mid_color, smoothstep(0.0, 0.45, t));
		col = mix(col, zenith_color, smoothstep(0.35, 1.0, t));
	} else {
		col = mix(horizon_color * 0.45, ground_color, smoothstep(0.0, 0.25, -h));
	}

	vec3 sun_dir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(0.5, 0.05, -0.8));
	float s = max(dot(dir, sun_dir), 0.0);
	// large halo chaud + disque
	col += halo_color * pow(s, 8.0) * halo_k;
	col += glare_color * pow(s, 64.0) * glare_k;
	col += disc_color * smoothstep(0.9993, 0.9998, s) * disc_k;
	// éclairage de la ville renvoyé par l'atmosphère, fort sur l'horizon
	col += city_glow * exp(-max(h, 0.0) * 5.0) * 0.6;

	float cloud_a = 0.0;
	if (h > 0.0) {
		// couche de nuages projetée sur un plan (perspective naturelle vers l'horizon)
		vec2 uv = dir.xz / (h + 0.08) * 0.9 * cloud_scale;
		float n = fbm(uv * 1.3 + vec2(3.7, 1.2));
		float detail = fbm(uv * 4.6 + vec2(n * 1.5, 0.0));
		float dens = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.32, n * 0.75 + detail * 0.35);
		dens = max(dens, overcast * (0.72 + 0.28 * n));            // couvert : voile continu, plus ou moins épais
		dens *= smoothstep(0.0, 0.07 + 0.1 * overcast, h);         // s'effacent dans la brume de l'horizon
		// éclairage : côté soleil doré, épaisseur plus sombre, bords translucides
		float toward = pow(max(dot(normalize(vec3(dir.x, 0.0, dir.z)), normalize(vec3(sun_dir.x, 0.0, sun_dir.z))), 0.0), 2.0);
		float thick = smoothstep(0.3, 1.0, dens);
		vec3 lit = mix(cloud_shade, cloud_lit, clamp(toward * (1.0 - thick * 0.55) + (1.0 - h) * 0.25, 0.0, 1.0));
		lit += cloud_lit * pow(s, 6.0) * (1.0 - thick) * 1.2;      // liseré lumineux près du soleil
		lit = mix(lit, col * 0.9, smoothstep(0.55, 1.0, h) * 0.5 * (1.0 - overcast));  // plus haut : plus bleutés
		lit = mix(lit, cloud_shade, thick * overcast * 0.45);      // ventres sombres sous le couvert
		lit += city_glow * (0.35 + 0.65 * (1.0 - h)) * (0.6 + 0.6 * thick);  // ventres éclairés par la ville
		cloud_a = dens * 0.92;
		col = mix(col, lit, cloud_a);
	}

	// étoiles (cachées par les nuages)
	if (h > 0.02) {
		vec3 p = dir * 260.0;
		vec3 id = floor(p);
		float r = hash13(id);
		vec3 c = fract(p) - 0.5;
		float star = smoothstep(0.12, 0.0, length(c)) * step(0.9965, r);
		float fade = smoothstep(0.1, 0.5, h);
		col += vec3(0.8, 0.85, 1.0) * star * fade * star_amount * (0.6 + 0.9 * hash13(id + 7.0)) * (1.0 - cloud_a);
	}
	// tramage : casse les bandes de couleur du dégradé
	col += (hash12(SCREEN_UV * 1024.0 + dir.xz * 37.0) - 0.5) / 255.0;
	COLOR = col;
}
