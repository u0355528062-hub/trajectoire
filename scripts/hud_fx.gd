class_name HudFx
extends CanvasLayer
## Interface de la mise à jour police : barre de tension, effets d'écran (lacrymo, gazeuse, coups, paupières),
## jauge de lutte pendant une arrestation, annonces et écran « ARRÊTÉ ».

const AMBER := Color(1.0, 0.72, 0.28)
const GLASS := Color(0.045, 0.05, 0.075, 0.82)
const TEXT := Color(0.93, 0.94, 0.97)
const MUTED := Color(0.93, 0.94, 0.97, 0.55)
const STAGE_COL := [Color(0.62, 0.86, 0.6), Color(0.98, 0.82, 0.36), Color(1.0, 0.58, 0.2), Color(0.98, 0.3, 0.2), Color(0.86, 0.12, 0.3)]

var player: Player
var tension: Tension
var _fx: ColorRect
var _bar: TensionBar
var _banner: Label
var _banner_tween: Tween
var _struggle: PanelContainer
var _struggle_bar: ProgressBar
var _struggle_label: Label
var _over: Control
var _over_on := false
var _over_t := 0.0
var _t0 := 0.0
var _alert_q: Array = []
var _alert_t := 0.0


# ----------------------------------------------------------------- barre de tension
class TensionBar extends Control:
	var value := 0.0
	var shown := 0.0
	var stage := 0
	var police := false
	var pulse := 0.0
	var t := 0.0

	func _draw() -> void:
		var w := size.x
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(14, 17), "TENSION", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.93, 0.94, 0.97, 0.6))
		var col: Color = HudFx.STAGE_COL[stage]
		draw_string(font, Vector2(w - 14 - font.get_string_size(Tension.STAGE_NAMES[stage], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x - (22 if police else 0), 17), Tension.STAGE_NAMES[stage], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		if police:
			var on := fmod(t, 0.8) < 0.4
			draw_circle(Vector2(w - 22, 12), 5.0, Color(0.15, 0.35, 1.0) if on else Color(1.0, 0.18, 0.15))
			draw_circle(Vector2(w - 22, 12), 9.0, Color(0.2, 0.4, 1.0, 0.18) if on else Color(1.0, 0.2, 0.2, 0.18))
		var x0 := 14.0
		var x1 := w - 14.0
		var y := 27.0
		var h := 8.0
		var bounds: Array = Tension.STAGES.duplicate()
		bounds.append(1.0)
		for i in 5:
			var a: float = bounds[i]
			var b: float = bounds[i + 1]
			var sx := lerpf(x0, x1, a) + (2.0 if i > 0 else 0.0)
			var ex := lerpf(x0, x1, b) - (2.0 if i < 4 else 0.0)
			var rect := Rect2(sx, y, ex - sx, h)
			draw_rect(rect, Color(1, 1, 1, 0.08), true)
			var fill := clampf((shown - a) / (b - a), 0.0, 1.0)
			if fill > 0.0:
				var c: Color = HudFx.STAGE_COL[i]
				draw_rect(Rect2(sx, y, (ex - sx) * fill, h), c, true)
				draw_rect(Rect2(sx, y, (ex - sx) * fill, 3.0), Color(1, 1, 1, 0.28), true)
				if pulse > 0.0:
					draw_rect(Rect2(sx - 2, y - 2, (ex - sx) * fill + 4, h + 4), Color(c.r, c.g, c.b, 0.25 * pulse), false, 2.0)
		# curseur
		var cx := lerpf(x0, x1, shown)
		draw_rect(Rect2(cx - 1.5, y - 4, 3.0, h + 8), Color(1, 1, 1, 0.85), true)


func _ready() -> void:
	layer = 12
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

	# barre de tension
	_bar = TensionBar.new()
	_bar.custom_minimum_size = Vector2(380, 44)
	_bar.size = Vector2(380, 44)
	_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_bar.offset_left = -190
	_bar.offset_right = 190
	_bar.offset_top = 14
	_bar.offset_bottom = 58
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bp := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = GLASS
	st.set_corner_radius_all(14)
	st.border_color = Color(1, 1, 1, 0.09)
	st.set_border_width_all(1)
	st.shadow_color = Color(0, 0, 0, 0.35)
	st.shadow_size = 12
	bp.add_theme_stylebox_override("panel", st)
	bp.set_anchors_preset(Control.PRESET_FULL_RECT)
	bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(bp)
	_bar.move_child(bp, 0)
	root.add_child(_bar)

	# annonce centrale
	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 30)
	_banner.add_theme_color_override("font_color", Color(1, 0.93, 0.8))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_banner.add_theme_constant_override("outline_size", 7)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 86
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_banner)

	# jauge de lutte (arrestation)
	_struggle = PanelContainer.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.05, 0.05, 0.08, 0.82)
	ss.set_corner_radius_all(16)
	ss.border_color = Color(1.0, 0.35, 0.3, 0.7)
	ss.set_border_width_all(2)
	ss.set_content_margin_all(14)
	_struggle.add_theme_stylebox_override("panel", ss)
	_struggle.set_anchors_preset(Control.PRESET_CENTER)
	_struggle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_struggle.grow_vertical = Control.GROW_DIRECTION_BOTH
	_struggle.offset_top = 150
	_struggle.offset_bottom = 150
	_struggle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	_struggle.add_child(sv)
	_struggle_label = Label.new()
	_struggle_label.text = "Débats-toi !  Appuie sur ESPACE"
	_struggle_label.add_theme_font_size_override("font_size", 20)
	_struggle_label.add_theme_color_override("font_color", Color(1, 0.9, 0.85))
	_struggle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(_struggle_label)
	_struggle_bar = ProgressBar.new()
	_struggle_bar.custom_minimum_size = Vector2(320, 12)
	_struggle_bar.show_percentage = false
	_struggle_bar.max_value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bg.set_corner_radius_all(6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(1.0, 0.45, 0.25)
	fg.set_corner_radius_all(6)
	_struggle_bar.add_theme_stylebox_override("background", bg)
	_struggle_bar.add_theme_stylebox_override("fill", fg)
	sv.add_child(_struggle_bar)
	_struggle.visible = false
	root.add_child(_struggle)

	# écran « ARRÊTÉ »
	_over = Control.new()
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_STOP
	_over.visible = false
	var ov := ColorRect.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.color = Color(0.01, 0.015, 0.03, 0.82)
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
	COLOR = vec4(0.1 * r + 1.0 * 0.0, 0.18 * l + 0.0, 0.9 * l, 0.0) + vec4(0.95 * r, 0.1 * r, 0.1 * r, 0.0);
	COLOR.a = (l * 0.28 + r * 0.28) * v;
}"""
	var lm := ShaderMaterial.new()
	lm.shader = lsh
	lights.material = lm
	_over.add_child(lights)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.add_child(box)
	var title := Label.new()
	title.name = "Title"
	title.text = "ARRÊTÉ"
	title.add_theme_font_size_override("font_size", 92)
	title.add_theme_color_override("font_color", Color(0.96, 0.96, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.8, 0.55))
	title.add_theme_constant_override("outline_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.name = "Sub"
	sub.text = "Les forces de l'ordre t'ont interpellé."
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var stats := Label.new()
	stats.name = "Stats"
	stats.add_theme_font_size_override("font_size", 16)
	stats.add_theme_color_override("font_color", MUTED)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats)
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "Appuie sur ENTRÉE pour recommencer depuis le début"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", AMBER)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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


func announce(text: String, col := Color(1, 0.93, 0.8), secs := 2.6) -> void:
	_alert_q.append([text, col, secs])


func _on_stage_up(s: int) -> void:
	var msgs := ["", "La tension monte…", "Ça chauffe : la police se rapproche", "Affrontements : les CRS avancent", "ÉMEUTE !"]
	announce(msgs[s], STAGE_COL[s], 2.8)


func _on_stage_down(s: int) -> void:
	if s == 0:
		announce("Retour au calme", STAGE_COL[0], 2.4)


func _on_arrested() -> void:
	_over_on = true
	_over_t = 0.0
	_over.visible = true
	_over.modulate.a = 0.0
	var secs := Time.get_ticks_msec() / 1000.0 - _t0
	var stats := _over.find_child("Stats", true, false) as Label
	var peak := tension.max_value() if tension else 0.0
	stats.text = "Durée : %d min %02d s   ·   Tension maximale : %d %%" % [int(secs / 60.0), int(secs) % 60, int(peak * 100.0)]


func _unhandled_input(event: InputEvent) -> void:
	if _over_on and _over_t > 1.2 and event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE):
		get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if tension:
		var before := _bar.shown
		_bar.value = tension.value
		_bar.shown = lerpf(_bar.shown, tension.value, minf(1.0, delta * 4.0))
		_bar.stage = tension.stage
		_bar.police = tension.police_active
		_bar.t = t
		_bar.pulse = move_toward(_bar.pulse, 0.0, delta * 1.5)
		if tension.value > before + 0.0004:
			_bar.pulse = 1.0
		_bar.queue_redraw()
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
		_struggle.visible = player.arrest_phase == "grabbed"
		if _struggle.visible:
			_struggle_bar.value = player.struggle
			_struggle_label.text = "Débats-toi !  ESPACE ESPACE ESPACE"
	# file d'annonces
	_alert_t -= delta
	if _alert_t <= 0.0 and not _alert_q.is_empty():
		var a: Array = _alert_q.pop_front()
		_banner.text = a[0]
		_banner.add_theme_color_override("font_color", a[1])
		if _banner_tween:
			_banner_tween.kill()
		_banner.modulate.a = 0.0
		_banner_tween = create_tween()
		_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.25)
		_banner_tween.tween_interval(float(a[2]))
		_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.7)
		_alert_t = float(a[2]) + 0.9
	if _over_on:
		_over_t += delta
		_over.modulate.a = clampf(_over_t / 1.0, 0.0, 1.0)
		var lights := _over.find_child("Lights", true, false) as ColorRect
		(lights.material as ShaderMaterial).set_shader_parameter("t", t)
