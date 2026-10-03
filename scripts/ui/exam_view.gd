class_name ExamView
extends Control
## Résultat visuel d'un examen : vue à l'otoscope, gorge, tracé ECG,
## écrans d'appareils, test rapide, bandelette, peau, auscultation.
## Se ferme avec E, Échap, Espace ou un clic.

signal closed

const VISUAL := ["oto_d", "oto_g", "orl", "ecg", "ta", "temp", "spo2", "glycemie", "dep", "tdr", "bu", "peau_d", "peau_g", "cardio", "pulmo_d", "pulmo_g"]

var exam_id := ""
var case_data: Dictionary = {}
var state = "normal"
var result_text := ""
var abnormal := false
var _t := 0.0
var _viewer: Control
var _cv: Control
var _card: PanelContainer
var _rng := RandomNumberGenerator.new()
var _speckles: Array = []


static func has_visual(id: String) -> bool:
	return id in VISUAL


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open(id: String, c: Dictionary, text: String, is_abnormal: bool, minutes: int) -> void:
	exam_id = id
	case_data = c
	result_text = text
	abnormal = is_abnormal
	state = Cases.visual_state(c, id) if id in ["oto_d", "oto_g", "orl", "ecg", "tdr", "bu", "peau_d", "peau_g"] else Cases.sound_state(c, id)
	_t = 0.0
	_rng.seed = hash(id + str(c.get("patient", {}).get("name", "")))
	_speckles.clear()
	for i in 140:
		_speckles.append(Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf()))
	for ch in get_children():
		ch.queue_free()
	_build(minutes)
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func _build(minutes: int) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.02, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	row.add_theme_constant_override("separation", 34)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)

	_viewer = Control.new()
	_viewer.custom_minimum_size = Vector2(980, 560) if exam_id == "ecg" else Vector2(560, 560)
	_viewer.draw.connect(_draw_viewer.bind(_viewer))
	row.add_child(_viewer)

	_card = Glass.panel(20, 28, 24)
	_card.custom_minimum_size = Vector2(430 if exam_id != "ecg" else 380, 0)
	_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_card)
	var v := UITheme.vbox(12)
	_card.add_child(v)
	var e: Dictionary = ExamDB.EXAMS.get(exam_id, {})
	var tool: Dictionary = ExamDB.tool_def(e.get("tool", "mains"))
	var head := UITheme.hbox(12)
	v.add_child(head)
	var icon := Label.new()
	icon.text = Icons.glyph(tool.get("icon", "circle"))
	icon.add_theme_font_override("font", Icons.font())
	icon.add_theme_font_size_override("font_size", 30)
	icon.add_theme_color_override("font_color", UITheme.ACCENT)
	head.add_child(icon)
	var tv := UITheme.vbox(0)
	head.add_child(tv)
	tv.add_child(UITheme.label("RÉSULTAT D'EXAMEN", "AccentCaption"))
	tv.add_child(UITheme.label(e.get("name", exam_id), "H2"))
	var badge := UITheme.badge("ANOMALIE" if abnormal else "NORMAL", UITheme.WARNING if abnormal else UITheme.SUCCESS)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(badge)
	var body := UITheme.label(result_text, "Body", true)
	body.add_theme_font_size_override("font_size", 19)
	body.custom_minimum_size.x = 370
	v.add_child(body)
	v.add_child(HSeparator.new())
	var foot := UITheme.hbox(10)
	v.add_child(foot)
	var info := UITheme.label("+%d min  ·  Noté dans le dossier" % minutes, "Muted")
	info.add_theme_font_size_override("font_size", 14)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(info)
	foot.add_child(UITheme.button("Continuer   E", "PrimaryButton", close))


func close() -> void:
	if not visible:
		return
	visible = false
	Sfx.ui("close")
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var r := _card.get_global_rect() if _card else Rect2()
		if not r.has_point(event.global_position):
			close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		close()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		if _viewer:
			_viewer.queue_redraw()


# --- Dessin -------------------------------------------------------------------------

func _draw_viewer(v: Control) -> void:
	_cv = v
	var s := v.size
	match exam_id:
		"oto_d", "oto_g":
			_draw_otoscope(s)
		"orl":
			_draw_throat(s)
		"ecg":
			_draw_ecg(s)
		"temp", "ta", "spo2", "glycemie":
			_draw_device(s)
		"dep":
			_draw_peak_flow(s)
		"tdr":
			_draw_trod(s)
		"bu":
			_draw_strip(s)
		"peau_d", "peau_g":
			_draw_skin(s)
		"cardio", "pulmo_d", "pulmo_g":
			_draw_auscultation(s)


func _radial(center: Vector2, r: float, inner: Color, outer: Color, segs: int = 64) -> void:
	_ellipse(center, r, r, 0.0, inner, outer, segs)


func _ellipse(center: Vector2, rx: float, ry: float, rot: float, inner: Color, outer: Color, segs: int = 64) -> void:
	var prev := center + Vector2(rx, 0).rotated(rot)
	for i in range(1, segs + 1):
		var a := TAU * i / segs
		var p := center + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot)
		_cv.draw_primitive(PackedVector2Array([center, prev, p]), PackedColorArray([inner, outer, outer]), PackedVector2Array())
		prev = p


func _draw_otoscope(s: Vector2) -> void:
	var c := s * 0.5
	var R := minf(s.x, s.y) * 0.48
	_cv.draw_circle(c, R + 8, Color(0.02, 0.02, 0.025))
	# Conduit auditif
	_radial(c, R, Color(0.86, 0.6, 0.52), Color(0.34, 0.16, 0.14))
	var right := exam_id == "oto_d"
	var tilt := deg_to_rad(-18.0 if right else 18.0)
	var tc := c + Vector2(0, R * 0.04)
	var rx := R * 0.58
	var ry := R * 0.5
	match String(state):
		"purulente":
			# Tympan bombé, rouge-jaunâtre, sans reflet.
			_ellipse(tc, rx * 1.03, ry * 1.03, tilt, Color(0.95, 0.78, 0.42), Color(0.72, 0.18, 0.14))
			_ellipse(tc + Vector2(-R * 0.06, -R * 0.08), rx * 0.42, ry * 0.36, tilt, Color(1.0, 0.9, 0.62, 0.55), Color(1.0, 0.8, 0.5, 0.0))
			for i in 16:
				var a := TAU * i / 16 + 0.2
				var p1 := tc + Vector2(cos(a) * rx * 0.55, sin(a) * ry * 0.55).rotated(tilt)
				var p2 := tc + Vector2(cos(a + 0.12) * rx * 0.98, sin(a + 0.12) * ry * 0.98).rotated(tilt)
				_cv.draw_line(p1, p2, Color(0.62, 0.06, 0.06, 0.55), 2.0, true)
		"congestive", "rouge_leger":
			_ellipse(tc, rx, ry, tilt, Color(0.88, 0.62, 0.58), Color(0.7, 0.42, 0.4))
			_malleus(tc, R, right, Color(0.85, 0.45, 0.4))
			for i in 6:
				var y := -ry * 0.55 + i * ry * 0.18
				_cv.draw_line(tc + Vector2(-6, y), tc + Vector2(6, y + 10), Color(0.7, 0.12, 0.1, 0.6), 2.0, true)
			_light_reflex(tc, R, right, 0.35)
		_:
			_ellipse(tc, rx, ry, tilt, Color(0.82, 0.82, 0.78), Color(0.6, 0.6, 0.58))
			_ellipse(tc, rx * 0.95, ry * 0.95, tilt, Color(0.85, 0.85, 0.82, 0.0), Color(0.5, 0.5, 0.5, 0.25))
			_malleus(tc, R, right, Color(0.93, 0.9, 0.78))
			_light_reflex(tc, R, right, 0.9)
	# Grain et vignettage du spéculum
	for sp in _speckles:
		var p: Vector2 = c + Vector2(sp.x, sp.y) * R * 0.95
		if p.distance_to(c) < R:
			_cv.draw_circle(p, 0.8 + sp.z, Color(0, 0, 0, 0.05))
	for k in 14:
		_cv.draw_arc(c, R - k * 2.0, 0, TAU, 96, Color(0, 0, 0, 0.09), 3.0, true)
	_cv.draw_arc(c, R + 4, 0, TAU, 128, Color(0.15, 0.15, 0.17), 10.0, true)
	_label(c + Vector2(0, R + 34), "Tympan %s" % ("droit" if right else "gauche"), 18, Color(1, 1, 1, 0.8))


func _malleus(tc: Vector2, R: float, right: bool, col: Color) -> void:
	var top := tc + Vector2(R * (0.06 if right else -0.06), -R * 0.36)
	_cv.draw_line(top, tc, col, 7.0, true)
	_cv.draw_circle(top, 7.0, col)
	_cv.draw_circle(tc, 5.0, col.darkened(0.15))


func _light_reflex(tc: Vector2, R: float, right: bool, strength: float) -> void:
	var dir := Vector2(0.55 if right else -0.55, 0.85).normalized()
	var p0 := tc + dir * 8.0
	var tip := tc + dir * R * 0.42
	var side := Vector2(-dir.y, dir.x) * R * 0.09
	_cv.draw_polygon(PackedVector2Array([p0, tip + side, tip - side]),
		PackedColorArray([Color(1, 1, 1, 0.75 * strength), Color(1, 1, 0.95, 0.25 * strength), Color(1, 1, 0.95, 0.25 * strength)]))


func _draw_throat(s: Vector2) -> void:
	var c := s * 0.5
	var R := minf(s.x, s.y) * 0.47
	_cv.draw_circle(c, R + 8, Color(0.03, 0.02, 0.02))
	_radial(c, R, Color(0.4, 0.08, 0.1), Color(0.12, 0.02, 0.03))
	var red := 0.0
	var exsudat := false
	match String(state):
		"rouge_leger":
			red = 0.4
		"rouge", "erythemateuse":
			red = 0.8
		"exsudat":
			red = 1.0
			exsudat = true
	var wall := Color(0.86, 0.5, 0.48).lerp(Color(0.85, 0.2, 0.18), red)
	# Paroi pharyngée postérieure
	_ellipse(c + Vector2(0, R * 0.05), R * 0.42, R * 0.48, 0.0, wall.lightened(0.08), wall.darkened(0.25))
	for sp in _speckles.slice(0, 40):
		var p: Vector2 = c + Vector2(sp.x * R * 0.3, sp.y * R * 0.35)
		_cv.draw_circle(p, 2.0 + sp.z * 2.0, wall.lightened(0.12))
	# Voile du palais et luette
	_cv.draw_rect(Rect2(c.x - R * 0.9, c.y - R * 0.92, R * 1.8, R * 0.42), Color(0.9, 0.62, 0.6).lerp(Color(0.88, 0.35, 0.3), red * 0.6))
	_ellipse(c + Vector2(0, -R * 0.28), R * 0.075, R * 0.17, 0.0, Color(0.95, 0.6, 0.58).lerp(Color(0.95, 0.3, 0.25), red), Color(0.75, 0.4, 0.38).lerp(Color(0.7, 0.15, 0.12), red))
	# Amygdales
	var tsize := 1.0 + red * 0.45
	for sx in [-1.0, 1.0]:
		var tc := c + Vector2(sx * R * 0.52, R * 0.02)
		var tcol := Color(0.9, 0.55, 0.52).lerp(Color(0.9, 0.18, 0.15), red)
		_ellipse(tc, R * 0.16 * tsize, R * 0.27 * tsize, 0.0, tcol.lightened(0.1), tcol.darkened(0.3))
		for i in 6:
			var cp := tc + Vector2(_speckles[i + (10 if sx > 0 else 0)].x * R * 0.09, _speckles[i + 20].y * R * 0.18)
			_cv.draw_circle(cp, 3.0, tcol.darkened(0.35))
		if exsudat:
			for i in 9:
				var sp: Vector3 = _speckles[i * 3 + (1 if sx > 0 else 0)]
				var ep := tc + Vector2(sp.x * R * 0.1, sp.y * R * 0.2)
				_ellipse(ep, 6.0 + sp.z * 9.0, 4.0 + sp.z * 6.0, sp.x, Color(0.98, 0.96, 0.86), Color(0.92, 0.88, 0.72, 0.6), 18)
	# Langue et abaisse-langue
	_ellipse(c + Vector2(0, R * 0.78), R * 0.95, R * 0.5, 0.0, Color(0.88, 0.5, 0.5), Color(0.6, 0.28, 0.3))
	_cv.draw_rect(Rect2(c.x - R * 0.13, c.y + R * 0.42, R * 0.26, R * 0.7), Color(0.88, 0.76, 0.56))
	_cv.draw_rect(Rect2(c.x - R * 0.13, c.y + R * 0.42, R * 0.26, 4), Color(0.75, 0.62, 0.44))
	# Dents
	for i in 8:
		var x := c.x - R * 0.7 + i * R * 0.2
		_cv.draw_rect(Rect2(x, c.y - R * 0.98, R * 0.17, R * 0.12), Color(0.96, 0.94, 0.88))
	# Éclairage de la lampe
	_radial(c + Vector2(R * 0.05, -R * 0.05), R * 0.95, Color(1, 0.98, 0.9, 0.12), Color(1, 1, 1, 0.0))
	for k in 12:
		_cv.draw_arc(c, R - k * 2.5, 0, TAU, 96, Color(0, 0, 0, 0.1), 3.0, true)
	_label(c + Vector2(0, R + 34), "Gorge — « Faites Aaah »", 18, Color(1, 1, 1, 0.8))


func _ecg_wave(t: float, hr: float, lead: String, st: String) -> float:
	var period := 60.0 / hr
	var x := fmod(t, period) / period
	var amp: float = {"I": 0.7, "II": 1.1, "III": 0.5, "aVR": -0.8, "aVL": 0.3, "aVF": 0.8,
		"V1": -0.6, "V2": 0.4, "V3": 0.9, "V4": 1.3, "V5": 1.2, "V6": 1.0}.get(lead, 1.0)
	var p := 0.12 * exp(-pow((x - 0.12) / 0.03, 2.0))
	var q := -0.12 * exp(-pow((x - 0.235) / 0.008, 2.0))
	var r := 1.0 * exp(-pow((x - 0.25) / 0.012, 2.0))
	var s := -0.25 * exp(-pow((x - 0.27) / 0.01, 2.0))
	var tw := 0.25 * exp(-pow((x - 0.48) / 0.06, 2.0))
	var y := p + q + r + s + tw
	if lead == "aVR":
		y = -y
	elif lead == "V1":
		y = p - 0.15 * exp(-pow((x - 0.25) / 0.012, 2.0)) - 0.7 * exp(-pow((x - 0.27) / 0.014, 2.0)) + 0.1 * exp(-pow((x - 0.48) / 0.06, 2.0))
	else:
		y *= amp
	if st == "st_inferieur":
		var seg := smoothstep(0.27, 0.3, x) * (1.0 - smoothstep(0.52, 0.62, x))
		if lead in ["II", "III", "aVF"]:
			y += 0.32 * seg + 0.18 * exp(-pow((x - 0.45) / 0.08, 2.0))
		elif lead in ["I", "aVL", "V1", "V2", "V3"]:
			y -= 0.16 * seg
	return y


func _draw_ecg(s: Vector2) -> void:
	_cv.draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.97, 0.96))
	var mm := 4.0
	var x := 0.0
	while x < s.x:
		_cv.draw_line(Vector2(x, 0), Vector2(x, s.y), Color(0.95, 0.72, 0.72, 0.45 if int(round(x / mm)) % 5 != 0 else 0.9), 1.0)
		x += mm
	var y := 0.0
	while y < s.y:
		_cv.draw_line(Vector2(0, y), Vector2(s.x, y), Color(0.95, 0.72, 0.72, 0.45 if int(round(y / mm)) % 5 != 0 else 0.9), 1.0)
		y += mm
	var v := Cases.vitals(case_data)
	var hr := float(v["fc"])
	var st := String(state)
	var layout := [["I", "aVR", "V1", "V4"], ["II", "aVL", "V2", "V5"], ["III", "aVF", "V3", "V6"]]
	var col_w := s.x / 4.0
	var row_h := (s.y - 120.0) / 3.0
	var px_per_s := mm * 25.0
	var trace := Color(0.08, 0.08, 0.1)
	for ri in 3:
		for ci in 4:
			var lead: String = layout[ri][ci]
			var base := Vector2(ci * col_w, 40 + ri * row_h + row_h * 0.55)
			var pts := PackedVector2Array()
			var n := int(col_w)
			for i in n:
				var tt := (i / px_per_s) + ci * 2.5
				pts.append(base + Vector2(i, -_ecg_wave(tt, hr, lead, st) * mm * 10.0))
			_cv.draw_polyline(pts, trace, 1.6, true)
			_cv.draw_string(UITheme.font("bold"), base + Vector2(6, -row_h * 0.38), lead, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.15, 0.15, 0.2))
	# Bande de rythme DII
	var base2 := Vector2(0, s.y - 48)
	var pts2 := PackedVector2Array()
	for i in int(s.x):
		pts2.append(base2 + Vector2(i, -_ecg_wave(i / px_per_s, hr, "II", st) * mm * 10.0))
	_cv.draw_polyline(pts2, trace, 1.6, true)
	_cv.draw_string(UITheme.font("bold"), Vector2(8, 24), "ECG 12 dérivations   ·   25 mm/s   ·   10 mm/mV   ·   FC %d/min" % int(hr), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.2, 0.2, 0.25))
	_cv.draw_string(UITheme.font("bold"), base2 + Vector2(6, -34), "II", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.15, 0.15, 0.2))


func _device_frame(r: Rect2, body: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = body
	sb.set_corner_radius_all(36)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 24
	sb.border_color = body.lightened(0.25)
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	_cv.draw_style_box(sb, r)


func _screen_box(r: Rect2, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(14)
	sb.border_color = Color(0, 0, 0, 0.5)
	sb.set_border_width_all(3)
	_cv.draw_style_box(sb, r)


func _draw_device(s: Vector2) -> void:
	var v := Cases.vitals(case_data)
	var c := s * 0.5
	var big := UITheme.font("display")
	var small := UITheme.font("semibold")
	match exam_id:
		"temp":
			var body := Rect2(c - Vector2(150, 230), Vector2(300, 460))
			_device_frame(body, Color(0.93, 0.94, 0.96))
			var scr := Rect2(body.position + Vector2(36, 70), Vector2(228, 150))
			_screen_box(scr, Color(0.62, 0.82, 0.95))
			var temp := float(v["temp"])
			var txt := ("%.1f" % temp).replace(".", ",")
			_label(scr.get_center() + Vector2(0, 12), txt, 72, Color(0.05, 0.12, 0.2), big)
			_label(scr.get_center() + Vector2(84, -38), "°C", 22, Color(0.05, 0.12, 0.2), small)
			if temp >= 38.0:
				_cv.draw_circle(scr.position + Vector2(24, 24), 9, Color(0.9, 0.2, 0.15))
			_label(body.position + Vector2(150, 36), "THERMO IR", 16, Color(0.3, 0.35, 0.45), small)
			_cv.draw_circle(body.position + Vector2(150, 300), 34, Color(0.15, 0.42, 0.8))
		"spo2":
			var body2 := Rect2(c - Vector2(200, 170), Vector2(400, 340))
			_device_frame(body2, Color(0.15, 0.45, 0.78))
			var scr2 := Rect2(body2.position + Vector2(40, 50), Vector2(320, 240))
			_screen_box(scr2, Color(0.01, 0.02, 0.04))
			_label(scr2.position + Vector2(70, 30), "SpO₂ %", 18, Color(0.4, 0.9, 1.0), small)
			_label(scr2.position + Vector2(230, 30), "PR bpm", 18, Color(1.0, 0.85, 0.3), small)
			_label(scr2.position + Vector2(80, 110), str(int(v["spo2"])), 84, Color(0.4, 0.9, 1.0), big)
			_label(scr2.position + Vector2(232, 110), str(int(v["fc"])), 64, Color(1.0, 0.85, 0.3), big)
			var pts := PackedVector2Array()
			var hr := float(v["fc"])
			for i in 280:
				var tt := _t + i / 140.0
				var ph := fmod(tt * hr / 60.0, 1.0)
				var yv := exp(-pow((ph - 0.2) / 0.08, 2.0)) * 1.0 + exp(-pow((ph - 0.45) / 0.1, 2.0)) * 0.35
				pts.append(scr2.position + Vector2(20 + i, 210 - yv * 40))
			_cv.draw_polyline(pts, Color(0.4, 0.9, 1.0), 2.0, true)
		"ta":
			var body3 := Rect2(c - Vector2(190, 220), Vector2(380, 440))
			_device_frame(body3, Color(0.95, 0.95, 0.96))
			var scr3 := Rect2(body3.position + Vector2(40, 50), Vector2(300, 260))
			_screen_box(scr3, Color(0.75, 0.8, 0.74))
			var parts := str(v["ta"]).split("/")
			var sys := parts[0] if parts.size() > 0 else "--"
			var dia := parts[1] if parts.size() > 1 else "--"
			_label(scr3.position + Vector2(40, 40), "SYS", 16, Color(0.1, 0.12, 0.1), small)
			_label(scr3.position + Vector2(40, 120), "DIA", 16, Color(0.1, 0.12, 0.1), small)
			_label(scr3.position + Vector2(40, 200), "PUL", 16, Color(0.1, 0.12, 0.1), small)
			_label(scr3.position + Vector2(190, 52), sys, 72, Color(0.06, 0.08, 0.06), big)
			_label(scr3.position + Vector2(190, 132), dia, 60, Color(0.06, 0.08, 0.06), big)
			_label(scr3.position + Vector2(190, 210), str(int(v["fc"])), 40, Color(0.06, 0.08, 0.06), big)
			_cv.draw_circle(body3.position + Vector2(190, 370), 30, Color(0.15, 0.42, 0.8))
			_label(body3.position + Vector2(190, 372), "START", 13, Color(1, 1, 1), small)
		"glycemie":
			var body4 := Rect2(c - Vector2(140, 210), Vector2(280, 420))
			_device_frame(body4, Color(0.22, 0.24, 0.28))
			var scr4 := Rect2(body4.position + Vector2(30, 50), Vector2(220, 170))
			_screen_box(scr4, Color(0.72, 0.78, 0.72))
			_label(scr4.get_center() + Vector2(0, 0), ("%.2f" % float(v["glyc"])).replace(".", ","), 64, Color(0.06, 0.08, 0.06), big)
			_label(scr4.get_center() + Vector2(0, 52), "g/L", 20, Color(0.06, 0.08, 0.06), small)
			_cv.draw_rect(Rect2(body4.position + Vector2(126, -70), Vector2(28, 90)), Color(0.96, 0.96, 0.92))
			_cv.draw_rect(Rect2(body4.position + Vector2(126, -70), Vector2(28, 16)), Color(0.85, 0.2, 0.2, 0.85))


func _draw_peak_flow(s: Vector2) -> void:
	var c := s * 0.5
	var v := Cases.vitals(case_data)
	var val := float(v.get("dep", 520))
	var tube := Rect2(c - Vector2(90, 240), Vector2(180, 480))
	_device_frame(tube, Color(0.9, 0.93, 0.96))
	for i in 9:
		var y := tube.end.y - 40 - i * 48
		_cv.draw_line(Vector2(tube.position.x + 40, y), Vector2(tube.position.x + 90, y), Color(0.15, 0.15, 0.2), 2.0)
		_label(Vector2(tube.position.x + 128, y + 6), str(100 + i * 75), 16, Color(0.15, 0.15, 0.2), UITheme.font("semibold"))
	var anim := clampf(_t / 1.2, 0.0, 1.0)
	var vy := tube.end.y - 40 - ((val - 100.0) / 75.0) * 48.0 * anim
	_cv.draw_rect(Rect2(tube.position.x + 30, vy - 6, 70, 12), Color(0.85, 0.15, 0.12))
	_label(Vector2(c.x, tube.end.y + 40), "%d L/min" % int(val), 26, Color(1, 1, 1), UITheme.font("display"))


func _draw_trod(s: Vector2) -> void:
	var c := s * 0.5
	var body := Rect2(c - Vector2(110, 250), Vector2(220, 500))
	_device_frame(body, Color(0.97, 0.97, 0.98))
	_label(body.position + Vector2(110, 40), "STREP A", 20, Color(0.2, 0.25, 0.35), UITheme.font("bold"))
	var win := Rect2(body.position + Vector2(70, 90), Vector2(80, 220))
	_screen_box(win, Color(0.98, 0.97, 0.95))
	var reveal := clampf(_t / 1.5, 0.0, 1.0)
	_cv.draw_rect(Rect2(win.position + Vector2(8, 60), Vector2(64, 7)), Color(0.82, 0.12, 0.25, reveal))
	_label(win.position + Vector2(-22, 66), "C", 18, Color(0.3, 0.3, 0.35), UITheme.font("bold"))
	if String(state) == "pos":
		_cv.draw_rect(Rect2(win.position + Vector2(8, 140), Vector2(64, 7)), Color(0.82, 0.12, 0.25, reveal * 0.9))
	_label(win.position + Vector2(-22, 146), "T", 18, Color(0.3, 0.3, 0.35), UITheme.font("bold"))
	_cv.draw_circle(body.position + Vector2(110, 400), 34, Color(0.88, 0.88, 0.9))
	_cv.draw_circle(body.position + Vector2(110, 400), 22, Color(0.75, 0.75, 0.78))


func _draw_strip(s: Vector2) -> void:
	var c := s * 0.5
	var res = state if state is Dictionary else {}
	var rows := [["Leucocytes", "leu", [Color(0.96, 0.93, 0.78), Color(0.88, 0.85, 0.8), Color(0.75, 0.68, 0.8), Color(0.6, 0.45, 0.72)]],
		["Nitrites", "nit", [Color(0.98, 0.95, 0.88), Color(0.95, 0.75, 0.78)]],
		["Sang", "sang", [Color(0.95, 0.85, 0.45), Color(0.7, 0.75, 0.35), Color(0.4, 0.55, 0.3)]],
		["Protéines", "prot", [Color(0.88, 0.92, 0.55), Color(0.7, 0.85, 0.6), Color(0.45, 0.7, 0.6)]],
		["Glucose", "glu", [Color(0.6, 0.85, 0.85), Color(0.6, 0.75, 0.4), Color(0.55, 0.45, 0.25)]]]
	var strip := Rect2(c.x - 230, c.y - 230, 44, 460)
	_cv.draw_rect(strip, Color(0.97, 0.97, 0.97))
	for i in rows.size():
		var key: String = rows[i][1]
		var level := int(res.get(key, 0))
		var cols: Array = rows[i][2]
		var pad_col: Color = cols[clampi(level, 0, cols.size() - 1)]
		var y := c.y - 200 + i * 86
		_cv.draw_rect(Rect2(strip.position.x + 6, y, 32, 32), pad_col)
		_label(Vector2(c.x - 70, y + 22), rows[i][0], 18, Color(1, 1, 1, 0.9), UITheme.font("semibold"))
		for j in cols.size():
			var r := Rect2(c.x + 30 + j * 46, y, 36, 32)
			_cv.draw_rect(r, cols[j])
			if j == clampi(level, 0, cols.size() - 1):
				_cv.draw_rect(r.grow(4), Color(UITheme.ACCENT, 1.0), false, 3.0)


func _draw_skin(s: Vector2) -> void:
	var c := s * 0.5
	var R := minf(s.x, s.y) * 0.47
	var skin := Color(0.88, 0.7, 0.6)
	_radial(c, R, skin.lightened(0.05), skin.darkened(0.12))
	for sp in _speckles:
		var p: Vector2 = c + Vector2(sp.x, sp.y) * R * 0.95
		if p.distance_to(c) < R:
			_cv.draw_circle(p, 1.0 + sp.z * 1.4, Color(0.6, 0.4, 0.35, 0.12))
	if String(state) == "zona":
		var band_dir := Vector2(1.0, 0.25).normalized()
		var n := Vector2(-band_dir.y, band_dir.x)
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in 40:
			var tt := -1.0 + i / 19.5
			var p := c + band_dir * tt * R
			pts.append(p + n * R * 0.18)
			cols.append(Color(0.85, 0.3, 0.25, 0.55))
		for i in range(39, -1, -1):
			var tt2 := -1.0 + i / 19.5
			var p2 := c + band_dir * tt2 * R
			pts.append(p2 - n * R * 0.18)
			cols.append(Color(0.85, 0.3, 0.25, 0.55))
		_cv.draw_polygon(pts, cols)
		for k in 7:
			var sk: Vector3 = _speckles[k]
			var cc: Vector2 = c + band_dir * (-0.7 + k * 0.23) * R + n * sk.x * R * 0.07
			for j in 8:
				var sp2: Vector3 = _speckles[(k * 8 + j) % _speckles.size()]
				var vp: Vector2 = cc + Vector2(sp2.x, sp2.y) * R * 0.07
				var rr := 5.0 + sp2.z * 6.0
				_cv.draw_circle(vp, rr + 3.0, Color(0.8, 0.18, 0.15, 0.6))
				_cv.draw_circle(vp, rr, Color(0.98, 0.92, 0.82))
				_cv.draw_circle(vp - Vector2(rr * 0.3, rr * 0.3), rr * 0.3, Color(1, 1, 1, 0.9))
	for k in 12:
		_cv.draw_arc(c, R - k * 2.0, 0, TAU, 96, Color(0, 0, 0, 0.08), 3.0, true)
	_label(c + Vector2(0, R + 34), "Flanc %s — inspection" % ("droit" if exam_id == "peau_d" else "gauche"), 18, Color(1, 1, 1, 0.8))


func _draw_auscultation(s: Vector2) -> void:
	var c := s * 0.5
	var r := Rect2(Vector2(10, c.y - 170), Vector2(s.x - 20, 340))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.07, 0.95)
	sb.set_corner_radius_all(22)
	sb.border_color = Color(UITheme.ACCENT, 0.4)
	sb.set_border_width_all(2)
	_cv.draw_style_box(sb, r)
	var pts := PackedVector2Array()
	var heart := exam_id == "cardio"
	var v := Cases.vitals(case_data)
	var hr := float(v["fc"])
	var st := String(state)
	for i in int(r.size.x - 40):
		var tt := _t * 0.8 + i / 220.0
		var y := 0.0
		if heart:
			var ph := fmod(tt * hr / 60.0, 1.0)
			y = exp(-pow((ph - 0.1) / 0.02, 2.0)) * sin(tt * 260.0) * 1.0 + exp(-pow((ph - 0.42) / 0.018, 2.0)) * sin(tt * 300.0) * 0.7
		else:
			var br := fmod(tt * 0.28, 1.0)
			var env := sin(clampf(br / 0.45, 0.0, 1.0) * PI) * 0.6 + sin(clampf((br - 0.45) / 0.55, 0.0, 1.0) * PI) * 0.25
			y = env * sin(tt * 900.0 + sin(tt * 77.0) * 3.0) * 0.35
			if st == "sibilants":
				y += env * sin(tt * 160.0) * 0.45
			elif st == "crepitants" and br < 0.45:
				var crack := fmod(tt * 37.0, 1.0)
				y += (1.0 if crack < 0.04 else 0.0) * 0.9 * signf(sin(tt * 999.0))
		pts.append(Vector2(r.position.x + 20 + i, c.y - y * 110.0))
	_cv.draw_polyline(pts, Color(UITheme.ACCENT, 0.95), 2.0, true)
	var title := "Auscultation cardiaque" if heart else "Auscultation pulmonaire"
	_label(Vector2(c.x, r.position.y + 34), title + "  ·  écoute en cours", 18, Color(1, 1, 1, 0.75), UITheme.font("semibold"))


func _label(pos: Vector2, text: String, fs: int, col: Color, f: Font = null) -> void:
	if f == null:
		f = UITheme.font("semibold")
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_cv.draw_string(f, Vector2(pos.x - w * 0.5, pos.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
