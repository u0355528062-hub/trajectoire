shader_type spatial;
// Façades lointaines : fenêtres procédurales, certaines allumées (émission chaude).
uniform vec3 wall_color : source_color = vec3(0.07, 0.075, 0.1);
uniform float seed = 1.0;
varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423) + seed);
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = wall_color;
	float em = 0.0;
	if (abs(wnrm.y) < 0.5) {
		float u = abs(wnrm.x) > abs(wnrm.z) ? wpos.z : wpos.x;
		vec2 cell = vec2(u / 3.4, wpos.y / 3.8);
		vec2 id = floor(cell);
		vec2 f = fract(cell);
		float inside = step(0.18, f.x) * step(f.x, 0.82) * step(0.22, f.y) * step(f.y, 0.78);
		float lit = step(0.72, hash(id));
		em = inside * lit * (0.7 + 0.6 * hash(id + 7.0));
		col = mix(col, vec3(0.03, 0.04, 0.06), inside);
	}
	ALBEDO = col;
	ROUGHNESS = 0.8;
	EMISSION = vec3(1.0, 0.72, 0.4) * em * 1.6;
}
