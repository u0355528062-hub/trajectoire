shader_type sky;

// Ciel de crépuscule : dégradé chaud -> bleu nuit, halo solaire, étoiles.
uniform vec3 zenith_color : source_color = vec3(0.012, 0.025, 0.11);
uniform vec3 mid_color : source_color = vec3(0.12, 0.17, 0.42);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.52, 0.28);
uniform vec3 ground_color : source_color = vec3(0.16, 0.14, 0.17);
uniform float star_amount : hint_range(0.0, 1.0) = 0.8;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
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
	col += vec3(1.0, 0.45, 0.2) * pow(s, 8.0) * 0.35;
	col += vec3(1.0, 0.7, 0.4) * pow(s, 64.0) * 0.8;
	col += vec3(1.0, 0.9, 0.7) * smoothstep(0.9993, 0.9998, s) * 3.0;

	// étoiles
	if (h > 0.02) {
		vec3 p = dir * 260.0;
		vec3 id = floor(p);
		float r = hash13(id);
		vec3 c = fract(p) - 0.5;
		float star = smoothstep(0.12, 0.0, length(c)) * step(0.9965, r);
		float fade = smoothstep(0.1, 0.5, h);
		col += vec3(0.8, 0.85, 1.0) * star * fade * star_amount * (0.6 + 0.9 * hash13(id + 7.0));
	}
	COLOR = col;
}
