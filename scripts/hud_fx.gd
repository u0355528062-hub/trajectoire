class_name HudFx
extends CanvasLayer
## Interface de la police (charte UiStyle) : jauge de tension à cinq stades avec étiquette tamponnée,
## transitions marquantes (rebond, flash des bords, bandeau d'annonce), pastille « recherché »,
## alerte lacrymo, roue des gestes à pictogrammes, effets d'écran (lacrymo, gazeuse, coups,
## paupières), jauge de lutte pendant une arrestation et écran « ARRÊTÉ ».

# Anciens noms conservés (palette de la charte)
const AMBER := UiStyle.YELLOW
const GLASS := UiStyle.INK_PANEL
const TEXT := UiStyle.PAPER
const MUTED := UiStyle.PAPER_DIM
const STAGE_COL := UiStyle.STAGE_COL

var player: Player
var tension: Tension
var _fx: ColorRect
var _edge: TextureRect
var _edge_flash := 0.0
var _edge_col := Color.WHITE
var _bar: TensionBar
var _banner_box: CenterContainer
var _banner: Label
var _banner_panel: PanelContainer
var _banner_kicker: Label
var _banner_tween: Tween
var _struggle: PanelContainer
var _struggle_bar: ProgressBar
var _struggle_label: Label
var _struggle_key: Control
var _gas_chip: PanelContainer
var _gas_label: Label
var _over: Control
var _over_on := false
var _over_t := 0.0
var _stamp: Control
var _t0 := 0.0
var _alert_q: Array = []
var _alert_t := 0.0


# ----------------------------------------------------------------- jauge de tension
## Panneau d'encre : intitulé, étiquette du stade (papier de couleur, légèrement de travers, qui
## rebondit à chaque changement), gyrophare quand la police est engagée, jauge en cinq segments
## biseautés qui pulse quand la tension monte.
class TensionBar extends Control:
	var value := 0.0
	var shown := 0.0
	var stage := 0
	var police := false
	var pulse := 0.0
	var t := 0.0
	var pop := 0.0          # rebond de l'étiquette (changement de stade)
	var flash := 0.0        # éclair blanc sur la jauge
	var _shown_stage := 0

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var danger := clampf(float(stage - 2) / 2.0, 0.0, 1.0)
		var beat := 0.5 + 0.5 * sin(t * (5.0 + 3.0 * float(stage)))
		# fond
		var bg := UiStyle.soft_shadow(UiStyle.box(UiStyle.INK_PANEL, 8, Color(UiStyle.PAPER, 0.08).lerp(Color(UiStyle.STAGE_COL[stage], 0.55 + 0.35 * beat), danger), 1), 0.35, 12, Vector2(0, 4))
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
		var fcap := UiStyle.font("caps")
		draw_string(fcap, Vector2(18, 28), "TENSION", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiStyle.PAPER_DIM)
		var pct := "%d %%" % int(round(shown * 100.0))
		draw_string(UiStyle.font("bold"), Vector2(98, 28), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiStyle.PAPER_MUTE)
		# étiquette du stade
		var col: Color = UiStyle.STAGE_COL[stage]
		var sname: String = Tension.STAGE_NAMES[stage]
		var fm := UiStyle.font("marker")
		var fs := 21
		var tw := fm.get_string_size(sname, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var sw := tw + 24.0
		var sh := 32.0
		var k := 1.0 + 0.45 * pop * pop
		var sc := Vector2(w - 14.0 - sw * 0.5, 22.0)
		draw_set_transform(sc, deg_to_rad(-3.0 + 5.0 * pop * sin(pop * 9.0)), Vector2(k, k))
		var sr := Rect2(-sw * 0.5, -sh * 0.5, sw, sh)
		draw_rect(Rect2(sr.position + Vector2(3, 3), sr.size), Color(UiStyle.INK, 0.9), true)
		draw_rect(sr, col, true)
		var txt_col := UiStyle.INK if stage < 3 else UiStyle.PAPER
		draw_string(fm, Vector2(-tw * 0.5, 8.0), sname, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, txt_col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# gyrophare
		if police:
			var on := fmod(t, 0.7) < 0.35
			var sir := UiIcons.tex("siren", 44)
			var sp := Vector2(w - 14.0 - sw - 36.0, 9.0)
			var sc2 := UiStyle.BLUE if on else UiStyle.RED
			draw_texture_rect(UiStyle.spot_tex(), Rect2(sp - Vector2(10, 10), Vector2(44, 44)), false, Color(sc2, 0.35))
			draw_texture_rect(sir, Rect2(sp, Vector2(24, 24)), false, sc2.lightened(0.25))
		# jauge biseautée
		var x0 := 18.0
		var x1 := w - 18.0
		var y := 44.0
		var bh := 12.0
		var skew := 5.0
		var bounds: Array = Tension.STAGES.duplicate()
		bounds.append(1.0)
		for i in 5:
			var a: float = bounds[i]
			var b: float = bounds[i + 1]
			var sx := lerpf(x0, x1, a) + (2.0 if i > 0 else 0.0)
			var ex := lerpf(x0, x1, b) - (2.0 if i < 4 else 0.0)
			var sc_i: Color = UiStyle.STAGE_COL[i]
			_para(sx, ex, y, bh, skew, Color(UiStyle.PAPER, 0.09))
			_para(sx, ex, y + bh - 2.0, 2.0, 0.0, Color(sc_i, 0.4))
			var fill := clampf((shown - a) / (b - a), 0.0, 1.0)
			if fill > 0.0:
				var fx := lerpf(sx, ex, fill)
				_para(sx, fx, y, bh, skew, sc_i)
				_para(sx, fx, y, 3.0, skew * 0.25, Color(1, 1, 1, 0.3))
				if flash > 0.0:
					_para(sx, fx, y, bh, skew, Color(1, 1, 1, flash * 0.8))
				if pulse > 0.0 and i == stage:
					var gr := Rect2(sx - 3.0, y - 3.0, fx - sx + skew + 6.0, bh + 6.0)
					draw_rect(gr, Color(sc_i, 0.35 * pulse), false, 2.0)
		# curseur : triangle crème sous la jauge
		var cx := lerpf(x0, x1, shown) + skew * 0.5
		var tri := PackedVector2Array([Vector2(cx, y + bh + 2.0), Vector2(cx - 5.0, y + bh + 9.0), Vector2(cx + 5.0, y + bh + 9.0)])
		draw_colored_polygon(tri, UiStyle.PAPER)
		draw_line(Vector2(cx, y - 3.0), Vector2(cx, y + bh + 1.0), UiStyle.PAPER, 2.0)

	## Parallélogramme (segment biseauté)
	func _para(sx: float, ex: float, y: float, h: float, skew: float, c: Color) -> void:
		if ex - sx <= 0.1:
			return
		var pts := PackedVector2Array([Vector2(sx + skew, y), Vector2(ex + skew, y), Vector2(ex, y + h), Vector2(sx, y + h)])
		draw_colored_polygon(pts, c)


# ----------------------------------------------------------------- attention de la police sur le joueur
## Pastille « repéré / recherché » : œil, libellé, cinq crans. Jaune quand on est repéré, rouge
## pulsant quand on est recherché.
class WantedChip extends Control:
	var wanted := 0.0
	var t := 0.0

	func _draw() -> void:
		if wanted < 0.15:
			return
		var hot := wanted >= 0.55
		var a := clampf((wanted - 0.15) / 0.1, 0.0, 1.0)
		var beat := 0.5 + 0.5 * sin(t * 7.0)
		var w := size.x
		var h := size.y
		var bg := UiStyle.RED.lerp(UiStyle.RED_DEEP, 0.35 * beat) if hot else UiStyle.INK_PANEL
		var st := UiStyle.box(Color(bg, bg.a * a), 5, Color(UiStyle.YELLOW, 0.5 * a) if not hot else Color(UiStyle.PAPER, 0.0), 0 if hot else 1)
		if hot:
			UiStyle.print_shadow(st, Color(UiStyle.INK, 0.85 * a), Vector2(3, 3))
		draw_style_box(st, Rect2(Vector2.ZERO, size))
		var fg := UiStyle.PAPER if hot else UiStyle.YELLOW
		var eye := UiIcons.tex("eye", 40)
		draw_texture_rect(eye, Rect2(12, h * 0.5 - 10, 26, 20), false, Color(fg, a))
		var txt := "RECHERCHÉ PAR LA POLICE" if hot else "REPÉRÉ PAR LES CRS"
		draw_string(UiStyle.font("caps"), Vector2(48, h * 0.5 + 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(fg, a))
		# crans
		var n := 5
		var lit := int(ceil(clampf(wanted, 0.0, 1.0) * n - 0.001))
		for i in n:
			var px := w - 14.0 - float(n - i) * 13.0
			var r := Rect2(px, h * 0.5 - 6, 9, 12)
			var on := i < lit
			draw_rect(r, Color(fg, a * (1.0 if on else 0.22)), true)


# ----------------------------------------------------------------- roue des gestes (Tab)
## Huit secteurs autour du centre, pictogrammes dessinés ; le secteur visé s'avance et passe au rouge,
## son nom s'affiche au centre. Ouverture et fermeture en fondu avec léger zoom.
class GestureWheel extends Control:
	var player: Player
	var open_k := 0.0
	var _hov: Array[float] = []
	var _pick := -1

	const R_IN := 96.0
	const R_OUT := 232.0

	func step(delta: float) -> void:
		if player == null:
			return
		var n := Player.WHEEL.size()
		if _hov.size() != n:
			_hov.resize(n)
			_hov.fill(0.0)
		var want := 1.0 if player.wheel_open else 0.0
		var before := open_k
		open_k = UiStyle.damp(open_k, want, 16.0 if want > 0.5 else 22.0, delta)
		if open_k < 0.005 and want == 0.0:
			open_k = 0.0
		_pick = player.wheel_pick() if player.wheel_open else _pick
		for i in n:
			_hov[i] = UiStyle.damp(_hov[i], 1.0 if i == _pick else 0.0, 18.0, delta)
		if open_k > 0.0 or before > 0.0:
			queue_redraw()

	func _draw() -> void:
		if player == null or open_k <= 0.0:
			return
		var c := size * 0.5
		var e := UiStyle.smooth(open_k)
		var sc := lerpf(0.86, 1.0, e)
		var n := Player.WHEEL.size()
		# halo d'encre derrière la roue
		var halo := (R_OUT + 140.0) * sc
		draw_texture_rect(UiStyle.spot_tex(), Rect2(c - Vector2(halo, halo), Vector2(halo, halo) * 2.0), false, Color(UiStyle.INK, 0.6 * e))
		var seg := TAU / float(n)
		for i in n:
			var hv: float = _hov[i] if i < _hov.size() else 0.0
			var mid := -PI * 0.5 + seg * float(i)
			var push := Vector2.from_angle(mid) * 12.0 * hv
			var ri := R_IN * sc
			var ro := (R_OUT + 10.0 * hv) * sc
			var a0 := mid - seg * 0.5 + 0.035
			var a1 := mid + seg * 0.5 - 0.035
			var pts := PackedVector2Array()
			var steps := 14
			for s in steps + 1:
				pts.append(c + push + Vector2.from_angle(lerpf(a0, a1, float(s) / steps)) * ro)
			for s in steps + 1:
				pts.append(c + push + Vector2.from_angle(lerpf(a1, a0, float(s) / steps)) * ri)
			var fill := Color(UiStyle.INK_PANEL, 0.88 * e).lerp(Color(UiStyle.RED, e), hv)
			draw_colored_polygon(pts, fill)
			var outline := pts.duplicate()
			outline.append(pts[0])
			draw_polyline(outline, Color(UiStyle.PAPER, (0.1 + 0.5 * hv) * e), 1.5, true)
			# pictogramme
			var ic := UiIcons.tex(UiIcons.gesture_icon(Player.WHEEL[i][0]), 128)
			var isz := (52.0 + 10.0 * hv) * sc
			var ip := c + push + Vector2.from_angle(mid) * ((R_IN + R_OUT) * 0.5 * sc)
			draw_texture_rect(ic, Rect2(ip - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false, Color(UiStyle.PAPER, (0.62 + 0.38 * hv) * e))
		# centre : nom du geste choisi
		var cr := (R_IN - 10.0) * sc
		draw_circle(c, cr, Color(UiStyle.INK, 0.92 * e), true, -1.0, true)
		draw_arc(c, cr, 0.0, TAU, 64, Color(UiStyle.PAPER, 0.16 * e), 1.5, true)
		var fcap := UiStyle.font("caps")
		if _pick >= 0:
			var nm: String = str(Player.WHEEL[_pick][1]).to_upper()
			var fm := UiStyle.font("bold")
			var fs := 17
			draw_multiline_string(fm, c + Vector2(-cr * 0.85, -4.0), nm, HORIZONTAL_ALIGNMENT_CENTER, cr * 1.7, fs, 2, Color(UiStyle.PAPER, e))
			draw_string(fcap, c + Vector2(-cr, -26.0), "GESTE", HORIZONTAL_ALIGNMENT_CENTER, cr * 2.0, 11, Color(UiStyle.RED.lightened(0.2), e))
		else:
			draw_string(fcap, c + Vector2(-cr, 5.0), "VISE UN GESTE", HORIZONTAL_ALIGNMENT_CENTER, cr * 2.0, 12, Color(UiStyle.PAPER_DIM, e))
		# curseur de la souris
		var cur := c + player.wheel_vec * 0.9 * sc
		if player.wheel_vec.length() > 4.0:
			draw_line(c, cur, Color(UiStyle.YELLOW, 0.5 * e), 2.0, true)
		draw_circle(cur, 6.0, Color(UiStyle.INK, e), true, -1.0, true)
		draw_circle(cur, 4.0, Color(UiStyle.YELLOW, e), true, -1.0, true)
		# consigne
		var hint := "Relâche  TAB  pour faire le geste"
		var fr := UiStyle.font("semibold")
		var hw := fr.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var hp := c + Vector2(-hw * 0.5, (R_OUT + 48.0) * sc)
		draw_style_box(UiStyle.box(Color(UiStyle.INK, 0.8 * e), 4), Rect2(hp + Vector2(-14, -22), Vector2(hw + 28, 32)))
		draw_string(fr, hp, hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UiStyle.PAPER_DIM, e))


var _wheel: GestureWheel
var _wanted: WantedChip
var _hint_wanted := false


func _ready() -> void:
	layer = 12
	UiStyle.apply_theme(get_tree())
	_t0 = Time.get_ticks_msec() / 1000.0
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# effets d'écran : flou, double vision, voile, paupières, coup
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 6
	add_child(fx_layer)
	_fx = ColorRect.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float gas : hint_range(0.0, 1.0) = 0.0;
uniform float pepper : hint_range(0.0, 1.0) = 0.0;
uniform float hit : hint_range(0.0, 1.0) = 0.0;
uniform float blink : hint_range(0.0, 1.0) = 0.0;
uniform float time_s = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return v;
}
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - vec2(0.5);
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(d * vec2(aspect, 1.0));
	float amt = max(gas, pepper);
	vec2 wob = vec2(sin(uv.y * 13.0 + time_s * 2.1), cos(uv.x * 10.0 + time_s * 1.7)) * 0.006 * amt;
	wob += vec2(sin(uv.y * 38.0 + time_s * 4.6) * 0.0022, 0.0) * amt * amt;
	wob += d * hit * 0.03 * sin(time_s * 40.0);
	vec2 uv2 = uv + wob;
	float lod = amt * (1.2 + 4.2 * smoothstep(0.0, 0.7, r + amt * 0.3)) + hit * 1.5;
	vec2 ca = d * (0.016 * amt + 0.01 * hit);
	vec3 col;
	col.r = textureLod(screen_tex, uv2 + ca, lod).r;
	col.g = textureLod(screen_tex, uv2, lod).g;
	col.b = textureLod(screen_tex, uv2 - ca, lod).b;
	// image fantôme (double vision)
	vec2 off = vec2(0.012 * sin(time_s * 1.3), -0.008 * cos(time_s * 1.1)) * amt;
	vec3 ghost = textureLod(screen_tex, uv2 + off, lod + 1.0).rgb;
	col = mix(col, (col + ghost) * 0.5, 0.4 * amt);
	// voiles : gaz = blanc jaunâtre, poivre = rouge
	col = mix(col, vec3(0.88, 0.92, 0.8), gas * (0.14 + 0.42 * smoothstep(0.15, 0.95, r)));
	col = mix(col, vec3(0.62, 0.08, 0.05), pepper * (0.3 + 0.45 * smoothstep(0.05, 0.9, r)));
	// volutes de lacrymo qui dérivent devant les yeux
	if (gas > 0.01) {
		vec2 q = uv * vec2(1.0 / aspect, 1.0);
		float n1 = fbm(q * 2.6 + vec2(time_s * 0.07, -time_s * 0.035));
		float n2 = fbm(q * 5.2 - vec2(time_s * 0.11, time_s * 0.06));
		float puff = smoothstep(0.38, 0.82, n1 * 0.65 + n2 * 0.45);
		col = mix(col, vec3(0.9, 0.92, 0.86), gas * puff * (0.45 + 0.35 * smoothstep(0.1, 0.8, r)));
		// les yeux brûlent : la vision se rétrécit
		col *= 1.0 - gas * 0.5 * smoothstep(0.22, 0.78, r);
	}
	// coup reçu : flash rouge sur les bords
	col = mix(col, vec3(0.8, 0.03, 0.03), hit * (0.2 + 0.6 * smoothstep(0.2, 0.95, r)));
	col *= 1.0 - amt * 0.18 * (0.5 + 0.5 * sin(time_s * 2.0));
	// paupières qui se ferment
	float edge = 0.5 - 0.52 * blink;
	float lid = smoothstep(edge, edge + 0.06, abs(d.y) + 0.0);
	col = mix(col, vec3(0.01), lid * step(0.001, blink));
	float vis = max(max(gas, pepper), max(hit, blink));
	COLOR = vec4(col, step(0.001, vis));
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	_fx.material = sm
	_fx.visible = false
	fx_layer.add_child(_fx)

	# bords de l'écran teintés : flash de changement de stade, pouls de l'émeute
	_edge = TextureRect.new()
	_edge.texture = UiStyle.edge_tex()
	_edge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_edge.stretch_mode = TextureRect.STRETCH_SCALE
	_edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.modulate = Color(1, 1, 1, 0)
	_edge.visible = false
	root.add_child(_edge)

	_wheel = GestureWheel.new()
	_wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_wheel)

	# haut de l'écran : jauge, puis pastilles d'état
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 18
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_bar = TensionBar.new()
	_bar.custom_minimum_size = Vector2(560, 70)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_bar)
	_wanted = WantedChip.new()
	_wanted.custom_minimum_size = Vector2(330, 34)
	_wanted.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_wanted.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wanted.visible = false
	top.add_child(_wanted)
	_gas_chip = PanelContainer.new()
	var gs := UiStyle.box(UiStyle.YELLOW, 5)
	UiStyle.print_shadow(gs, Color(UiStyle.INK, 0.85), Vector2(3, 3))
	gs.content_margin_left = 10
	gs.content_margin_right = 14
	gs.content_margin_top = 5
	gs.content_margin_bottom = 5
	_gas_chip.add_theme_stylebox_override("panel", gs)
	_gas_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_gas_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gas_chip.visible = false
	_gas_chip.modulate.a = 0.0
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 8)
	gh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gas_chip.add_child(gh)
	var gi := TextureRect.new()
	gi.texture = UiIcons.tex("gas", 48)
	gi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gi.custom_minimum_size = Vector2(22, 22)
	gi.modulate = UiStyle.INK
	gi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gh.add_child(gi)
	_gas_label = UiStyle.label("LACRYMO", 13, UiStyle.INK, "caps")
	_gas_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gh.add_child(_gas_label)
	top.add_child(_gas_chip)

	# annonce centrale : bandeau d'encre posé de travers
	_banner_box = CenterContainer.new()
	_banner_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner_box.offset_top = 210
	_banner_box.offset_bottom = 330
	_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_banner_box)
	_banner_panel = PanelContainer.new()
	_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_panel.modulate.a = 0.0
	_banner_box.add_child(_banner_panel)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", -4)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_panel.add_child(bv)
	_banner_kicker = UiStyle.label("", 12, UiStyle.PAPER_DIM, "caps")
	_banner_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_banner_kicker)
	_banner = UiStyle.label("", 44, UiStyle.PAPER, "marker")
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_banner)
	_banner_panel.resized.connect(func(): _banner_panel.pivot_offset = _banner_panel.size * 0.5)

	_build_struggle(root)
	_build_over(root)


func _build_struggle(root: Control) -> void:
	_struggle = PanelContainer.new()
	var ss := UiStyle.soft_shadow(UiStyle.box(UiStyle.INK_PANEL, 6, UiStyle.RED, 2, 0.0), 0.5, 18, Vector2(0, 6))
	ss.border_width_left = 6
	ss.content_margin_left = 22
	ss.content_margin_right = 22
	ss.content_margin_top = 14
	ss.content_margin_bottom = 16
	_struggle.add_theme_stylebox_override("panel", ss)
	_struggle.set_anchors_preset(Control.PRESET_CENTER)
	_struggle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_struggle.grow_vertical = Control.GROW_DIRECTION_BOTH
	_struggle.offset_top = 170
	_struggle.offset_bottom = 170
	_struggle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_struggle.add_child(sv)
	var kick := UiStyle.label("INTERPELLATION", 13, UiStyle.RED.lightened(0.15), "caps")
	sv.add_child(kick)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sv.add_child(row)
	_struggle_label = UiStyle.label("Débats-toi !", 34, UiStyle.PAPER, "marker")
	_struggle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_struggle_label)
	var kc := UiStyle.keycap("ESPACE", 18, UiStyle.YELLOW)
	kc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kc.resized.connect(func(): kc.pivot_offset = kc.size * 0.5)
	_struggle_key = kc
	row.add_child(kc)
	_struggle_bar = ProgressBar.new()
	_struggle_bar.custom_minimum_size = Vector2(400, 14)
	_struggle_bar.show_percentage = false
	_struggle_bar.max_value = 1.0
	_struggle_bar.add_theme_stylebox_override("background", UiStyle.box(Color(UiStyle.PAPER, 0.12), 2))
	_struggle_bar.add_theme_stylebox_override("fill", UiStyle.box(UiStyle.YELLOW, 2))
	_struggle_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sv.add_child(_struggle_bar)
	_struggle.visible = false
	root.add_child(_struggle)


## Écran « ARRÊTÉ » : gyrophares, tampon rouge, bilan, touche pour recommencer
func _build_over(root: Control) -> void:
	_over = Control.new()
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_STOP
	_over.visible = false
	var ov := ColorRect.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.color = Color(UiStyle.INK, 0.86)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.add_child(ov)
	var lights := ColorRect.new()
	lights.name = "Lights"
	lights.set_anchors_preset(Control.PRESET_FULL_RECT)
	lights.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lsh := Shader.new()
	lsh.code = """shader_type canvas_item;
uniform float t = 0.0;
void fragment() {
	vec2 uv = UV;
	float k = step(0.5, fract(t * 1.4));
	float l = smoothstep(0.55, 0.0, uv.x) * (0.5 + 0.5 * k);
	float r = smoothstep(0.45, 1.0, uv.x) * (0.5 + 0.5 * (1.0 - k));
	float v = smoothstep(0.0, 0.7, 1.0 - abs(uv.y - 0.5) * 1.6);
	COLOR = vec4(0.95 * r + 0.1 * l, 0.1 * r + 0.25 * l, 0.1 * r + 1.0 * l, (l * 0.26 + r * 0.26) * v);
}"""
	var lm := ShaderMaterial.new()
	lm.shader = lsh
	lights.material = lm
	_over.add_child(lights)
	var ht := TextureRect.new()
	ht.texture = UiStyle.halftone_tex()
	ht.stretch_mode = TextureRect.STRETCH_TILE
	ht.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ht.set_anchors_preset(Control.PRESET_FULL_RECT)
	ht.modulate = Color(UiStyle.PAPER, 0.05)
	ht.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.add_child(ht)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.add_child(cc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(box)
	# tampon
	var stamp := PanelContainer.new()
	var sst := UiStyle.box(Color(UiStyle.RED, 0.06), 10, UiStyle.RED, 8, 0.0)
	sst.content_margin_left = 40
	sst.content_margin_right = 40
	sst.content_margin_top = 0
	sst.content_margin_bottom = 8
	stamp.add_theme_stylebox_override("panel", sst)
	stamp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.rotation = deg_to_rad(-6.0)
	stamp.resized.connect(func(): stamp.pivot_offset = stamp.size * 0.5)
	_stamp = stamp
	box.add_child(stamp)
	var title := UiStyle.label("ARRÊTÉ", 132, UiStyle.RED, "marker")
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap)
	var sub := UiStyle.label("Les forces de l'ordre t'ont interpellé.", 28, UiStyle.PAPER, "semibold")
	sub.name = "Sub"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var stats := UiStyle.label("", 15, UiStyle.PAPER_DIM, "caps")
	stats.name = "Stats"
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats)
	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 18
	gap2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap2)
	var hint := HBoxContainer.new()
	hint.name = "Hint"
	hint.alignment = BoxContainer.ALIGNMENT_CENTER
	hint.add_theme_constant_override("separation", 12)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(UiStyle.keycap("ENTRÉE", 18))
	var hl := UiStyle.label("Recommencer depuis le début", 20, UiStyle.PAPER, "semibold")
	hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_child(hl)
	box.add_child(hint)
	root.add_child(_over)


func bind(p: Player, t: Tension) -> void:
	player = p
	tension = t
	if t:
		t.stage_up.connect(_on_stage_up)
		t.stage_down.connect(_on_stage_down)
	p.arrested.connect(_on_arrested)
	p.message.connect(func(txt: String): pass)


## Remet le chronomètre de la partie à zéro (sortie de l'écran titre)
func reset_clock() -> void:
	_t0 = Time.get_ticks_msec() / 1000.0


## Annonce centrale (file d'attente) : texte, couleur, durée
func announce(text: String, col := Color(1, 0.93, 0.8), secs := 2.6) -> void:
	_alert_q.append([text, col, secs])


func _on_stage_up(s: int) -> void:
	var msgs := ["", "La tension monte…", "Ça chauffe : la police se rapproche", "Affrontements : les CRS avancent", "ÉMEUTE !"]
	announce(msgs[s], STAGE_COL[s], 2.8)
	_stage_hit(s)


func _on_stage_down(s: int) -> void:
	if s == 0:
		announce("Retour au calme", STAGE_COL[0], 2.4)


## Transition de stade : l'étiquette rebondit, la jauge s'éclaire, les bords de l'écran flashent
func _stage_hit(s: int) -> void:
	_bar.pop = 1.0
	_bar.flash = 1.0
	_edge_flash = 0.55 if s >= 3 else 0.32
	_edge_col = STAGE_COL[s]


func _on_arrested() -> void:
	_over_on = true
	_over_t = 0.0
	_over.visible = true
	_over.modulate.a = 0.0
	_stamp.scale = Vector2(2.4, 2.4)
	_stamp.modulate.a = 0.0
	var secs := Time.get_ticks_msec() / 1000.0 - _t0
	var stats := _over.find_child("Stats", true, false) as Label
	var peak := tension.max_value() if tension else 0.0
	stats.text = "Durée  %d min %02d s     ·     Tension maximale  %d %%" % [int(secs / 60.0), int(secs) % 60, int(peak * 100.0)]
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_property(_stamp, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(_stamp, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_stamp, "scale", Vector2(1.06, 1.06), 0.06)
	tw.tween_property(_stamp, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if _over_on and _over_t > 1.2 and event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE):
		get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if tension:
		var before := _bar.shown
		_bar.value = tension.value
		_bar.shown = UiStyle.damp(_bar.shown, tension.value, 4.0, delta)
		_bar.stage = tension.stage
		_bar.police = tension.police_active
		_bar.t = t
		_bar.pulse = move_toward(_bar.pulse, 0.0, delta * 1.5)
		_bar.pop = move_toward(_bar.pop, 0.0, delta * 2.2)
		_bar.flash = move_toward(_bar.flash, 0.0, delta * 2.5)
		if tension.value > before + 0.0004:
			_bar.pulse = 1.0
		_bar.queue_redraw()
		# bords de l'écran : flash de stade, puis pouls léger à l'émeute
		_edge_flash = move_toward(_edge_flash, 0.0, delta * 0.45)
		var base := 0.0
		if tension.stage >= 4:
			base = 0.09 + 0.05 * sin(t * 3.2)
			if _edge_flash <= 0.0:
				_edge_col = STAGE_COL[4]
		var ea := maxf(_edge_flash, base) * float(Settings.d.get("screen_shake", 1.0) * 0.5 + 0.5)
		_edge.visible = ea > 0.005
		if _edge.visible:
			_edge.modulate = Color(_edge_col, ea)
	if player and _wheel:
		if _wheel.player == null:
			_wheel.player = player
		_wheel.step(delta)
	if player and _wanted:
		_wanted.wanted = UiStyle.damp(_wanted.wanted, player.wanted, 3.0, delta)
		_wanted.t = t
		_wanted.visible = _wanted.wanted >= 0.15
		if _wanted.visible:
			_wanted.queue_redraw()
		if player.wanted >= 0.55 and not _hint_wanted and player.arrest_phase == "":
			_hint_wanted = true
			player.message.emit("Recherché : lève les mains (X) pour calmer les CRS, ou fonds-toi dans la foule")
	if player:
		var fxk := float(Settings.d["gas_fx"])
		var gas := player.gas_level * fxk
		var pep := player.pepper_level * fxk
		var hit := player.hit_flash * fxk
		var blink := player.eye_close * fxk
		var on := gas > 0.003 or pep > 0.003 or hit > 0.01 or blink > 0.01
		_fx.visible = on
		if on:
			var m := _fx.material as ShaderMaterial
			m.set_shader_parameter("gas", gas)
			m.set_shader_parameter("pepper", pep)
			m.set_shader_parameter("hit", hit)
			m.set_shader_parameter("blink", blink)
			m.set_shader_parameter("time_s", t)
		# alerte gaz (indépendante du réglage d'effets : l'information reste)
		var g_on := player.gas_level > 0.12 or player.pepper_level > 0.12
		if g_on:
			_gas_label.text = "GAZEUSE  ·  LES YEUX BRÛLENT" if player.pepper_level > player.gas_level else "GAZ LACRYMOGÈNE  ·  SORS DU NUAGE"
			_gas_chip.visible = true
		_gas_chip.modulate.a = UiStyle.damp(_gas_chip.modulate.a, (0.85 + 0.15 * sin(t * 6.0)) if g_on else 0.0, 8.0, delta)
		if not g_on and _gas_chip.modulate.a < 0.02:
			_gas_chip.visible = false
		_struggle.visible = player.arrest_phase == "grabbed"
		if _struggle.visible:
			_struggle_bar.value = player.struggle
			var kp := 1.0 + 0.08 * maxf(sin(t * 14.0), 0.0)
			_struggle_key.scale = Vector2(kp, kp)
	# file d'annonces
	_alert_t -= delta
	if _alert_t <= 0.0 and not _alert_q.is_empty():
		var a: Array = _alert_q.pop_front()
		_show_banner(str(a[0]), a[1], float(a[2]))
		_alert_t = float(a[2]) + 0.9
	if _over_on:
		_over_t += delta
		_over.modulate.a = clampf(_over_t / 0.8, 0.0, 1.0)
		var lights := _over.find_child("Lights", true, false) as ColorRect
		(lights.material as ShaderMaterial).set_shader_parameter("t", t)
		var hint := _over.find_child("Hint", true, false) as Control
		if hint:
			hint.modulate.a = 0.0 if _over_t < 1.2 else 0.65 + 0.35 * sin(t * 4.0)


## Bandeau d'annonce : encre, filets de couleur, texte au marqueur ; arrive en grand et se pose de travers
func _show_banner(text: String, col: Color, secs: float) -> void:
	var big := text.begins_with("ÉMEUTE")
	var police := col.is_equal_approx(Color(1, 0.93, 0.8))
	var accent := UiStyle.RED if police else col
	var st := UiStyle.box(UiStyle.INK if big else UiStyle.INK_PANEL, 3, accent, 0, 0.0)
	st.border_width_top = 4
	st.border_width_bottom = 4
	st.content_margin_left = 36
	st.content_margin_right = 36
	st.content_margin_top = 8
	st.content_margin_bottom = 12
	UiStyle.print_shadow(st, Color(accent, 0.9) if big else Color(UiStyle.INK, 0.6), Vector2(6, 6))
	_banner_panel.add_theme_stylebox_override("panel", st)
	_banner.text = text
	_banner.add_theme_font_size_override("font_size", 68 if big else 44)
	_banner.add_theme_color_override("font_color", UiStyle.PAPER if police else col.lerp(UiStyle.PAPER, 0.15))
	_banner_kicker.text = "POLICE" if police else "TENSION"
	_banner_kicker.add_theme_color_override("font_color", Color(accent.lightened(0.2), 0.9))
	_banner_panel.reset_size()
	if _banner_tween:
		_banner_tween.kill()
	_banner_panel.modulate.a = 0.0
	_banner_panel.scale = Vector2(1.35, 1.35)
	_banner_panel.rotation = deg_to_rad(-6.0)
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner_panel, "modulate:a", 1.0, 0.15)
	_banner_tween.tween_property(_banner_panel, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(_banner_panel, "rotation", deg_to_rad(-2.0), 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_interval(secs)
	_banner_tween.chain().tween_property(_banner_panel, "modulate:a", 0.0, 0.6)
