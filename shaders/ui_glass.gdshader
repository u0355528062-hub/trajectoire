// Verre dépoli pour l'interface : flou de l'arrière-plan + teinte.
// Le StyleBoxFlat du panneau code les zones par couleur :
// blanc = verre, vert = liseré, bleu = ombre portée.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.035, 0.05, 0.085, 0.74);
uniform vec4 edge : source_color = vec4(1.0, 1.0, 1.0, 0.1);
uniform float blur = 3.2;
uniform float shadow_strength = 0.45;
uniform float sheen = 0.05;

void fragment() {
	vec4 c = COLOR;
	if (c.b > 0.5 && c.r < 0.5 && c.g < 0.5) {
		COLOR = vec4(0.0, 0.0, 0.0, c.a * shadow_strength);
	} else if (c.g > 0.5 && c.r < 0.5) {
		COLOR = vec4(edge.rgb, edge.a * c.a);
	} else {
		vec2 px = SCREEN_PIXEL_SIZE * 5.0;
		vec3 bg = textureLod(screen_tex, SCREEN_UV, blur).rgb * 0.36;
		bg += textureLod(screen_tex, SCREEN_UV + vec2(px.x, px.y), blur).rgb * 0.16;
		bg += textureLod(screen_tex, SCREEN_UV + vec2(-px.x, px.y), blur).rgb * 0.16;
		bg += textureLod(screen_tex, SCREEN_UV + vec2(px.x, -px.y), blur).rgb * 0.16;
		bg += textureLod(screen_tex, SCREEN_UV + vec2(-px.x, -px.y), blur).rgb * 0.16;
		vec3 col = mix(bg, tint.rgb, tint.a);
		col += vec3(sheen) * (1.0 - UV.y);
		COLOR = vec4(col, c.a);
	}
}
