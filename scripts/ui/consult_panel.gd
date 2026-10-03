class_name ConsultPanel
extends Control
## Interface de consultation : interrogatoire, examen clinique et
## paraclinique, diagnostic, prescription puis compte rendu.

signal question_asked(id: String)
signal exam_requested(id: String)
signal concluded(diagnosis: String, treatments: Array, exams_done: Array)
signal finished

const TABS := ["Interrogatoire", "Examen", "Diagnostic", "Prescription"]

var record: PatientRecord
var _asked: Array[String] = []
var _exams_done: Array = []
var _diagnosis := ""
var _treatments: Array = []
var _concluded := false

var _panel: PanelContainer
var _name: Label
var _meta: Label
var _motif: Label
var _urgent_badge: Control
var _duration: Label
var _speaker: Label
var _speech: RichTextLabel
var _tab_buttons: Array[Button] = []
var _content: VBoxContainer
var _scroll: ScrollContainer
var _summary: Label
var _conclude_btn: Button
var _tab := 0
var _notes: Array = [] # [titre, texte, notable]
var _footer: Control
var _tabs_row: Control
var _speech_box: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.03, 0.05, 0.0))
	grad.set_color(1, Color(0.02, 0.03, 0.05, 0.75))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 256
	gt.height = 4
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.anchor_left = 0.35
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_panel = PanelContainer.new()
	_panel.theme_type_variation = "Card"
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -820
	_panel.offset_right = -28
	_panel.offset_top = 28
	_panel.offset_bottom = -28
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var v := UITheme.vbox(16)
	_panel.add_child(v)

	# En-tête patient
	var head := UITheme.hbox(16)
	v.add_child(head)
	var avatar := PanelContainer.new()
	avatar.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.ACCENT, 0.14), 999, Color(UITheme.ACCENT, 0.4), 1, 0, 0))
	avatar.custom_minimum_size = Vector2(64, 64)
	head.add_child(avatar)
	var av_l := UITheme.label("", "H2")
	av_l.name = "Initials"
	av_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av_l.add_theme_color_override("font_color", UITheme.ACCENT)
	avatar.add_child(av_l)
	var hv := UITheme.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	var name_row := UITheme.hbox(12)
	hv.add_child(name_row)
	_name = UITheme.label("", "H1")
	_name.add_theme_font_size_override("font_size", 30)
	name_row.add_child(_name)
	_urgent_badge = UITheme.badge("URGENCE", UITheme.DANGER)
	_urgent_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_urgent_badge)
	_meta = UITheme.label("", "Muted")
	hv.add_child(_meta)
	var right := UITheme.vbox(2)
	head.add_child(right)
	right.add_child(UITheme.label("DURÉE", "Caption"))
	_duration = UITheme.label("0 min", "H2")
	right.add_child(_duration)

	var motif_box := PanelContainer.new()
	motif_box.theme_type_variation = "SoftCard"
	v.add_child(motif_box)
	var mh := UITheme.hbox(12)
	motif_box.add_child(mh)
	mh.add_child(UITheme.label("MOTIF", "AccentCaption"))
	_motif = UITheme.label("", "Body", true)
	_motif.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mh.add_child(_motif)

	# Bulle de dialogue
	var speech_box := PanelContainer.new()
	_speech_box = speech_box
	var sbs := UITheme.box(Color(1, 1, 1, 0.06), 16, Color(1, 1, 1, 0.08), 1, 20, 16)
	speech_box.add_theme_stylebox_override("panel", sbs)
	speech_box.custom_minimum_size = Vector2(0, 118)
	v.add_child(speech_box)
	var sv := UITheme.vbox(6)
	speech_box.add_child(sv)
	_speaker = UITheme.label("", "AccentCaption")
	sv.add_child(_speaker)
	_speech = RichTextLabel.new()
	_speech.bbcode_enabled = true
	_speech.fit_content = true
	_speech.scroll_active = false
	_speech.add_theme_font_size_override("normal_font_size", 19)
	_speech.add_theme_font_override("normal_font", UITheme.font("medium"))
	sv.add_child(_speech)

	# Onglets
	var tabs := PanelContainer.new()
	_tabs_row = tabs
	tabs.add_theme_stylebox_override("panel", UITheme.box(Color(1, 1, 1, 0.04), 12, Color(0, 0, 0, 0), 0, 5, 5))
	v.add_child(tabs)
	var th := UITheme.hbox(4)
	tabs.add_child(th)
	var group := ButtonGroup.new()
	for i in range(TABS.size()):
		var b := UITheme.button("%d  %s" % [i + 1, TABS[i]], "TabButton")
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_show_tab.bind(i))
		th.add_child(b)
		_tab_buttons.append(b)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	_content = UITheme.vbox(12)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	var foot := UITheme.hbox(14)
	_footer = foot
	v.add_child(foot)
	_summary = UITheme.label("", "Muted", true)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_summary)
	_conclude_btn = UITheme.button("Conclure la consultation", "PrimaryButton", _conclude)
	foot.add_child(_conclude_btn)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or _concluded:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_4:
			_show_tab(k - KEY_1)
			get_viewport().set_input_as_handled()


# --- Ouverture -------------------------------------------------------------------

func open(r: PatientRecord) -> void:
	record = r
	_asked.clear()
	_exams_done.clear()
	_diagnosis = ""
	_treatments.clear()
	_notes.clear()
	_concluded = false
	var p: Dictionary = r.data.get("patient", {})
	_name.text = r.display_name()
	var initials := ""
	for part in r.display_name().split(" "):
		if part.length() > 0:
			initials += part.substr(0, 1)
	(_panel.find_child("Initials", true, false) as Label).text = initials.substr(0, 2)
	_meta.text = "%d ans  ·  %s  ·  %s" % [r.age(), "Femme" if p.get("sex", "M") == "F" else "Homme", p.get("job", "")]
	_motif.text = String(r.data.get("motif", "")).replace("SANS RDV — ", "")
	_urgent_badge.visible = r.is_urgent()
	_say_patient(r.data.get("greeting", "Bonjour docteur."))
	_tabs_row.visible = true
	_footer.visible = true
	_speech_box.visible = true
	_tab_buttons[0].button_pressed = true
	_show_tab(0)
	_update_footer()
	visible = true
	UITheme.fade_in(self, 0.25)


func _process(_delta: float) -> void:
	if visible and record and not _concluded:
		_duration.text = "%d min" % int(Game.minutes - record.consult_started_at)


func _say_patient(text: String) -> void:
	_speaker.text = record.display_name().to_upper() if record else ""
	_speech.text = "« %s »" % text
	_speech.visible_ratio = 0.0
	var tw := _speech.create_tween()
	tw.tween_property(_speech, "visible_ratio", 1.0, clampf(text.length() / 90.0, 0.3, 1.6))


func _say_doctor(text: String) -> void:
	_speaker.text = "VOUS"
	_speech.text = "[color=#8fe3d8]%s[/color]" % text
	_speech.visible_ratio = 1.0


# --- Onglets ---------------------------------------------------------------------

func _show_tab(i: int) -> void:
	if _concluded:
		return
	_tab = i
	for j in range(_tab_buttons.size()):
		_tab_buttons[j].set_pressed_no_signal(j == i)
	for c in _content.get_children():
		c.queue_free()
	match i:
		0: _build_questions()
		1: _build_exams()
		2: _build_diagnosis()
		3: _build_treatments()
	_scroll.scroll_vertical = 0


func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return g


func _chip(text: String, sub: String, done: bool) -> Button:
	var b := Button.new()
	b.theme_type_variation = "Chip"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text = ("✓  " if done else "") + text + ("" if sub == "" else "\n" + sub)
	b.custom_minimum_size = Vector2(0, 56)
	return b


func _section(title: String) -> void:
	var l := UITheme.label(title, "Caption")
	_content.add_child(l)


func _build_questions() -> void:
	_section("QUESTIONS")
	var g := _grid()
	_content.add_child(g)
	var all: Array = []
	for q in Cases.QUESTIONS:
		all.append({"id": q["id"], "text": q["text"]})
	var extra: Array = record.data.get("extra_questions", [])
	for i in range(extra.size()):
		all.append({"id": "extra_%d" % i, "text": extra[i]["text"]})
	for q in all:
		var done: bool = q["id"] in _asked
		var b := _chip(q["text"], "", done)
		b.disabled = done
		b.pressed.connect(_ask.bind(q["id"], q["text"]))
		g.add_child(b)
	_notes_view("NOTES D'INTERROGATOIRE", "q")


func _ask(id: String, text: String) -> void:
	if id in _asked:
		return
	_asked.append(id)
	var answer := ""
	if id.begins_with("extra_"):
		var idx := int(id.substr(6))
		answer = record.data.get("extra_questions", [])[idx]["answer"]
	else:
		answer = Cases.answer(record.data, id)
	_notes.append([text, answer, false, "q"])
	question_asked.emit(id)
	_say_patient(answer)
	_show_tab(0)
	_update_footer()


func _build_exams() -> void:
	for kind in [["clinique", "EXAMEN CLINIQUE"], ["test", "EXAMENS AU CABINET"]]:
		_section(kind[1])
		var g := _grid()
		_content.add_child(g)
		for e in Cases.EXAMS:
			if e["kind"] != kind[0]:
				continue
			var done: bool = e["id"] in _exams_done
			var b := _chip(e["name"], "%s  ·  %d min" % [e["detail"], e["time"]], done)
			b.disabled = done
			b.pressed.connect(_exam.bind(e["id"]))
			g.add_child(b)
	_notes_view("RÉSULTATS", "e")


func _exam(id: String) -> void:
	if id in _exams_done:
		return
	_exams_done.append(id)
	var def := Cases.exam_def(id)
	var res := Cases.exam_result(record.data, id)
	var notable: bool = record.data.get("findings", {}).has(id) or (id == "constantes" and _vitals_abnormal())
	_notes.append([def.get("name", id), res, notable, "e"])
	exam_requested.emit(id)
	if def.get("table", false) and not record.on_table:
		_say_doctor("Pouvez-vous vous installer sur la table d'examen, s'il vous plaît ?")
	else:
		_say_doctor("%s : %s" % [def.get("name", id), res])
	_show_tab(1)
	_update_footer()


func _vitals_abnormal() -> bool:
	var v: Dictionary = record.data.get("vitals", {})
	if float(v.get("temp", 36.8)) >= 38.0 or int(v.get("spo2", 98)) < 95 or int(v.get("fc", 74)) > 100:
		return true
	var ta := String(v.get("ta", "120/80"))
	if "/" in ta:
		var parts := ta.split("/")
		if int(parts[0]) >= 140 or int(parts[1]) >= 90:
			return true
	return false


func _notes_view(title: String, kind: String) -> void:
	var items: Array = []
	for n in _notes:
		if n[3] == kind:
			items.append(n)
	if items.is_empty():
		return
	_content.add_child(HSeparator.new())
	_section(title)
	for i in range(items.size() - 1, -1, -1):
		var n: Array = items[i]
		var p := PanelContainer.new()
		var border := Color(UITheme.WARNING, 0.6) if n[2] else Color(1, 1, 1, 0.06)
		var st := UITheme.box(Color(1, 1, 1, 0.035), 12, border, 1, 16, 12)
		if n[2]:
			st.border_width_left = 4
		p.add_theme_stylebox_override("panel", st)
		var nv := UITheme.vbox(4)
		p.add_child(nv)
		var tl := UITheme.label(n[0], "H3")
		tl.add_theme_font_size_override("font_size", 15)
		tl.add_theme_color_override("font_color", UITheme.WARNING if n[2] else UITheme.MUTED)
		nv.add_child(tl)
		nv.add_child(UITheme.label(n[1], "Body", true))
		_content.add_child(p)


func _build_diagnosis() -> void:
	_section("HYPOTHÈSE DIAGNOSTIQUE PRINCIPALE")
	var opts: Array = [record.data.get("diagnosis", "")]
	opts.append_array(record.data.get("differentials", []))
	# Ordre stable mais mélangé pour ce patient.
	var rng := RandomNumberGenerator.new()
	rng.seed = record.case_id.hash()
	for i in range(opts.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = opts[i]
		opts[i] = opts[j]
		opts[j] = tmp
	var group := ButtonGroup.new()
	for d in opts:
		var b := _chip(Cases.DIAGNOSES.get(d, d), "", false)
		b.text = Cases.DIAGNOSES.get(d, d)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = d == _diagnosis
		b.pressed.connect(_pick_diagnosis.bind(d))
		_content.add_child(b)
	var hint := UITheme.label("Astuce : un bon interrogatoire et les examens ciblés orientent le diagnostic. Chaque action prend du temps.", "Muted", true)
	_content.add_child(hint)


func _pick_diagnosis(d: String) -> void:
	_diagnosis = d
	_update_footer()


func _build_treatments() -> void:
	_section("PRESCRIPTION ET ORIENTATION  (plusieurs choix possibles)")
	for t in record.data.get("options", []):
		var b := _chip(Cases.TREATMENTS.get(t, t), "", false)
		b.text = Cases.TREATMENTS.get(t, t)
		b.toggle_mode = true
		b.button_pressed = t in _treatments
		b.toggled.connect(_toggle_treatment.bind(t))
		if t == "samu":
			b.add_theme_color_override("font_color", UITheme.DANGER.lightened(0.3))
		_content.add_child(b)


func _toggle_treatment(on: bool, t: String) -> void:
	if on and not (t in _treatments):
		_treatments.append(t)
	elif not on:
		_treatments.erase(t)
	_update_footer()


func _update_footer() -> void:
	var d: String = "—" if _diagnosis == "" else Cases.DIAGNOSES.get(_diagnosis, _diagnosis)
	_summary.text = "Diagnostic : %s\n%d prescription%s · %d examen%s" % [d, _treatments.size(), "s" if _treatments.size() > 1 else "", _exams_done.size(), "s" if _exams_done.size() > 1 else ""]
	_conclude_btn.disabled = _diagnosis == "" or _treatments.is_empty()
	_conclude_btn.tooltip_text = "Choisissez un diagnostic et au moins une prescription." if _conclude_btn.disabled else ""


func _conclude() -> void:
	if _concluded or _diagnosis == "" or _treatments.is_empty():
		return
	_concluded = true
	concluded.emit(_diagnosis, _treatments.duplicate(), _exams_done.duplicate())


# --- Compte rendu ----------------------------------------------------------------

func show_result(res: Dictionary) -> void:
	_tabs_row.visible = false
	_footer.visible = false
	_speech_box.visible = false
	for c in _content.get_children():
		c.queue_free()
	_scroll.scroll_vertical = 0

	_section("COMPTE RENDU DE CONSULTATION")
	var top := UITheme.hbox(22)
	_content.add_child(top)
	var grade_col := _grade_color(res["grade"])
	var circle := PanelContainer.new()
	circle.add_theme_stylebox_override("panel", UITheme.box(Color(grade_col, 0.14), 999, grade_col, 3, 0, 0))
	circle.custom_minimum_size = Vector2(120, 120)
	top.add_child(circle)
	var gl := UITheme.label(res["grade"], "Big")
	gl.add_theme_color_override("font_color", grade_col)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	circle.add_child(gl)
	var info := UITheme.vbox(8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	var ok: bool = res["diagnosis_ok"]
	var dl := UITheme.label(("Diagnostic exact" if ok else "Diagnostic erroné"), "H2")
	dl.add_theme_color_override("font_color", UITheme.SUCCESS if ok else UITheme.DANGER)
	info.add_child(dl)
	info.add_child(UITheme.label("Votre diagnostic : %s" % res["diagnosis_given"], "Body", true))
	if not ok:
		info.add_child(UITheme.label("Attendu : %s" % res["diagnosis_expected"], "Muted", true))
	var stats := UITheme.hbox(26)
	info.add_child(stats)
	stats.add_child(_stat("SCORE", "%d / 100" % int(res["score"])))
	stats.add_child(_stat("SATISFACTION", "%d %%" % int(res["satisfaction"])))
	stats.add_child(_stat("DURÉE", "%d min" % int(res["minutes"])))
	var rep: float = res["reputation_delta"]
	stats.add_child(_stat("RÉPUTATION", "%s%.1f" % ["+" if rep >= 0 else "", rep], UITheme.SUCCESS if rep >= 0 else UITheme.DANGER))

	var notes: Array = res["notes"]
	if not notes.is_empty():
		_content.add_child(HSeparator.new())
		_section("POINTS À REVOIR")
		for n in notes:
			var l := UITheme.label("•  " + String(n), "Body", true)
			if String(n).begins_with("ERREUR"):
				l.add_theme_color_override("font_color", UITheme.DANGER)
				l.add_theme_font_override("font", UITheme.font("bold"))
			_content.add_child(l)
	else:
		_content.add_child(UITheme.label("Prise en charge exemplaire. Rien à redire.", "Body", true))

	_content.add_child(HSeparator.new())
	var teach := PanelContainer.new()
	teach.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.ACCENT_2, 0.08), 14, Color(UITheme.ACCENT_2, 0.3), 1, 18, 16))
	_content.add_child(teach)
	var tv := UITheme.vbox(6)
	teach.add_child(tv)
	var tt := UITheme.label("LE POINT MÉDICAL", "Caption")
	tt.add_theme_color_override("font_color", UITheme.ACCENT_2)
	tv.add_child(tt)
	tv.add_child(UITheme.label(res["teaching"], "Body", true))

	var btn_text := "Raccompagner le patient"
	if res.get("samu", false) and record and record.is_urgent():
		btn_text = "Rester auprès du patient jusqu'à l'arrivée du SMUR"
	var b := UITheme.button(btn_text, "PrimaryButton", _finish)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	_content.add_child(b)
	UITheme.fade_in(_content, 0.35)


func _stat(title: String, value: String, color: Color = UITheme.TEXT) -> Control:
	var v := UITheme.vbox(0)
	v.add_child(UITheme.label(title, "Caption"))
	var l := UITheme.label(value, "H3")
	l.add_theme_color_override("font_color", color)
	v.add_child(l)
	return v


func _grade_color(g: String) -> Color:
	match g:
		"A": return UITheme.SUCCESS
		"B": return UITheme.ACCENT
		"C": return UITheme.WARNING
	return UITheme.DANGER


func _finish() -> void:
	visible = false
	record = null
	finished.emit()
