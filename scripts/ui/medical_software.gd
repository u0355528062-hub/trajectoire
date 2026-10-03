class_name MedicalSoftware
extends Control
## Logiciel médical de l'ordinateur du bureau : agenda, dossier du patient,
## diagnostic, ordonnance, clôture et compte rendu.

signal closed

const INK := Color(0.1, 0.14, 0.2)
const SUB := Color(0.4, 0.46, 0.55)
const LINE := Color(0.86, 0.89, 0.92)
const BG := Color(0.955, 0.965, 0.975)
const CARD := Color(1, 1, 1)
const TEAL := Color(0.05, 0.6, 0.56)
const AMBER := Color(0.85, 0.5, 0.05)
const RED := Color(0.85, 0.2, 0.25)
const GREEN := Color(0.12, 0.62, 0.32)

var session: GameSession
var page := "agenda"
var _content: VBoxContainer
var _scroll: ScrollContainer
var _nav: Dictionary = {}
var _title: Label
var _clock: Label
var _result_shown := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.02, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var win := PanelContainer.new()
	var ws := StyleBoxFlat.new()
	ws.bg_color = BG
	ws.set_corner_radius_all(16)
	ws.shadow_color = Color(0, 0, 0, 0.55)
	ws.shadow_size = 40
	ws.shadow_offset = Vector2(0, 14)
	ws.anti_aliasing = true
	win.add_theme_stylebox_override("panel", ws)
	win.anchor_left = 0.5
	win.anchor_right = 0.5
	win.anchor_top = 0.5
	win.anchor_bottom = 0.5
	win.offset_left = -780
	win.offset_right = 780
	win.offset_top = -450
	win.offset_bottom = 450
	add_child(win)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	win.add_child(root)

	# Barre de titre
	var bar := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.07, 0.12, 0.18)
	bs.corner_radius_top_left = 16
	bs.corner_radius_top_right = 16
	bs.content_margin_left = 22
	bs.content_margin_right = 14
	bs.content_margin_top = 12
	bs.content_margin_bottom = 12
	bar.add_theme_stylebox_override("panel", bs)
	root.add_child(bar)
	var bh := UITheme.hbox(12)
	bar.add_child(bh)
	bh.add_child(_icon("stethoscope", 22, Color(0.4, 0.9, 0.85)))
	_title = _lbl("Médilogiciel", 17, Color(1, 1, 1), "bold")
	bh.add_child(_title)
	var sub := _lbl("Cabinet médical de Saint-Aubin-sur-Loire", 14, Color(0.65, 0.72, 0.8), "medium")
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(sub)
	_clock = _lbl("", 15, Color(0.85, 0.9, 0.95), "semibold")
	bh.add_child(_clock)
	var x := _flat_button(Icons.glyph("x"), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.12), request_close)
	x.add_theme_font_override("font", Icons.font())
	x.add_theme_font_size_override("font_size", 20)
	x.tooltip_text = "Fermer (Échap)"
	bh.add_child(x)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# Barre latérale
	var side := PanelContainer.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.92, 0.94, 0.955)
	ss.corner_radius_bottom_left = 16
	ss.content_margin_left = 14
	ss.content_margin_right = 14
	ss.content_margin_top = 18
	ss.border_color = LINE
	ss.border_width_right = 1
	side.add_theme_stylebox_override("panel", ss)
	side.custom_minimum_size = Vector2(250, 0)
	body.add_child(side)
	var sv := UITheme.vbox(6)
	side.add_child(sv)
	for item in [["agenda", "calendar", "Agenda du jour"], ["dossier", "file-heart", "Dossier patient"], ["diagnostic", "brain", "Diagnostic"], ["ordonnance", "notepad-text", "Ordonnance"], ["cloture", "clipboard-check", "Clôturer"]]:
		var b := _nav_button(item[1], item[2])
		b.pressed.connect(show_page.bind(item[0]))
		sv.add_child(b)
		_nav[item[0]] = b

	var main := MarginContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for m in ["margin_left", "margin_right"]:
		main.add_theme_constant_override(m, 30)
	main.add_theme_constant_override("margin_top", 24)
	main.add_theme_constant_override("margin_bottom", 22)
	body.add_child(main)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(_scroll)
	_content = UITheme.vbox(14)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)


# --- Ouverture / fermeture ----------------------------------------------------------

func open() -> void:
	_result_shown = false
	_title.text = "Médilogiciel  ·  Dr %s" % Game.settings.get("doctor_name", "Martin")
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
	Sfx.ui("computer")
	var r := session.current if session else null
	if r and r.status == PatientRecord.Status.IN_OFFICE:
		show_page("dossier")
	else:
		show_page("agenda")


func request_close() -> void:
	if _result_shown:
		_result_shown = false
		session.finish_consultation()
		return
	force_close()


func force_close() -> void:
	if not visible:
		return
	visible = false
	Sfx.ui("close")
	closed.emit()


func refresh() -> void:
	if visible and not _result_shown:
		show_page(page)


func show_page(p: String) -> void:
	page = p
	var r := session.current if session else null
	var consult := r != null and r.status == PatientRecord.Status.IN_OFFICE
	for k in _nav.keys():
		var b: Button = _nav[k]
		b.disabled = k != "agenda" and not consult
		b.button_pressed = k == p
	if p != "agenda" and not consult:
		page = "agenda"
	_clock.text = "%s  ·  %s" % [Cases.day_data(Game.day)["title"].split(" — ")[0], Game.clock_text()]
	for c in _content.get_children():
		c.queue_free()
	match page:
		"agenda":
			_page_agenda()
		"dossier":
			_page_dossier(r)
		"diagnostic":
			_page_diagnostic(r)
		"ordonnance":
			_page_ordonnance(r)
		"cloture":
			_page_cloture(r)
	_scroll.scroll_vertical = 0


# --- Pages ----------------------------------------------------------------------------

func _page_agenda() -> void:
	_heading("Agenda du jour", "Patients du %s" % Cases.day_data(Game.day)["title"].split(" — ")[0].to_lower())
	var table := _card()
	_content.add_child(table)
	var tv := UITheme.vbox(0)
	table.add_child(tv)
	tv.add_child(_row_header(["HEURE", "PATIENT", "MOTIF", "STATUT", ""], [90, 260, 0, 170, 140]))
	var shown := 0
	for r in session.records:
		if r.walk_in and r.status == PatientRecord.Status.EXPECTED:
			continue
		shown += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.custom_minimum_size.y = 58
		var t := _lbl("S. RDV" if r.walk_in else Game.clock_text(r.appointment), 16, AMBER if r.walk_in else INK, "bold")
		t.custom_minimum_size.x = 90
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(t)
		var nv := UITheme.vbox(0)
		nv.custom_minimum_size.x = 260
		nv.alignment = BoxContainer.ALIGNMENT_CENTER
		nv.add_child(_lbl(r.display_name(), 16, INK, "semibold"))
		nv.add_child(_lbl("%d ans" % r.age(), 13, SUB, "regular"))
		row.add_child(nv)
		var m := _lbl(String(r.data.get("motif", "")).replace("SANS RDV — ", ""), 15, SUB, "regular")
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(m)
		var st := Control.new()
		st.custom_minimum_size = Vector2(170, 0)
		row.add_child(st)
		var col := SUB
		match r.status:
			PatientRecord.Status.WAITING:
				col = RED if r.is_urgent() else TEAL
			PatientRecord.Status.CALLED, PatientRecord.Status.IN_OFFICE:
				col = Color(0.15, 0.45, 0.85)
			PatientRecord.Status.DONE, PatientRecord.Status.LEAVING:
				col = GREEN
		var chip := _chip(("URGENCE" if r.is_urgent() and r.status == PatientRecord.Status.WAITING else r.status_text().to_upper()), col)
		chip.position = Vector2(0, 16)
		st.add_child(chip)
		var act := Control.new()
		act.custom_minimum_size = Vector2(140, 0)
		row.add_child(act)
		if r.status == PatientRecord.Status.WAITING:
			var b := _primary("Appeler", RED if r.is_urgent() else TEAL, _call.bind(r))
			b.disabled = session.office_busy()
			b.tooltip_text = "Un patient est déjà dans votre cabinet." if session.office_busy() else ""
			b.position = Vector2(0, 9)
			b.custom_minimum_size = Vector2(130, 40)
			act.add_child(b)
		elif r.status == PatientRecord.Status.DONE and not r.result.is_empty():
			var g := _lbl("Note %s" % r.result.get("grade", "-"), 16, INK, "bold")
			g.position = Vector2(20, 18)
			act.add_child(g)
		tv.add_child(row)
		tv.add_child(_sep())
	if shown == 0:
		tv.add_child(_lbl("Aucun patient pour le moment.", 15, SUB, "regular"))
	var foot := UITheme.hbox(14)
	_content.add_child(foot)
	var info := _lbl("Les patients sans rendez-vous apparaissent dès leur arrivée. Vous pouvez aussi demander à Camille de faire entrer le patient suivant.", 14, SUB, "regular")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(info)
	if session.waiting_count() == 0 and not session.office_busy() and session.next_arrival_minute() != INF:
		var ff := _primary("Avancer jusqu'à la prochaine arrivée  (%s)" % Game.clock_text(session.next_arrival_minute()), Color(0.2, 0.3, 0.45), _skip)
		foot.add_child(ff)


func _call(r: PatientRecord) -> void:
	if session.call_patient(r):
		Sfx.ui("click")
		force_close()


func _skip() -> void:
	if session.skip_to_next_arrival():
		force_close()


func _patient_header(r: PatientRecord) -> void:
	var c := _card()
	_content.add_child(c)
	var h := UITheme.hbox(18)
	c.add_child(h)
	var av := PanelContainer.new()
	var avs := StyleBoxFlat.new()
	avs.bg_color = Color(TEAL, 0.12)
	avs.set_corner_radius_all(999)
	av.add_theme_stylebox_override("panel", avs)
	av.custom_minimum_size = Vector2(64, 64)
	var ini := ""
	for part in r.display_name().split(" "):
		ini += part.substr(0, 1)
	var il := _lbl(ini.substr(0, 2), 22, TEAL, "bold")
	il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	il.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av.add_child(il)
	h.add_child(av)
	var v := UITheme.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var nh := UITheme.hbox(10)
	v.add_child(nh)
	nh.add_child(_lbl(r.display_name(), 24, INK, "display"))
	if r.is_urgent():
		nh.add_child(_chip("URGENCE", RED))
	v.add_child(_lbl("%d ans  ·  %s  ·  %s" % [r.age(), "Femme" if r.is_female() else "Homme", r.data.get("patient", {}).get("job", "")], 15, SUB, "medium"))
	var anc := _lbl("Antécédents : " + String(r.data.get("history", "")), 14, SUB, "regular")
	anc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(anc)
	var right := UITheme.vbox(2)
	h.add_child(right)
	right.add_child(_lbl("DURÉE", 12, SUB, "bold"))
	right.add_child(_lbl("%d min" % int(Game.minutes - r.consult_started_at), 20, INK, "bold"))


func _page_dossier(r: PatientRecord) -> void:
	_heading("Dossier patient", "Motif : " + String(r.data.get("motif", "")).replace("SANS RDV — ", ""))
	_patient_header(r)
	var cols := UITheme.hbox(16)
	_content.add_child(cols)
	for kind in ["question", "exam"]:
		var c := _card()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(c)
		var v := UITheme.vbox(10)
		c.add_child(v)
		v.add_child(_lbl("INTERROGATOIRE" if kind == "question" else "EXAMEN CLINIQUE ET TESTS", 13, TEAL, "bold"))
		var count := 0
		for n in r.notes:
			if n["kind"] != kind:
				continue
			count += 1
			var item := UITheme.vbox(2)
			var t := _lbl(String(n["title"]), 13, AMBER if n["abnormal"] else SUB, "semibold")
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			item.add_child(t)
			var body := _lbl(String(n["text"]), 15, INK, "regular")
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			item.add_child(body)
			v.add_child(item)
			v.add_child(_sep())
		if count == 0:
			var e := _lbl("Aucune question posée pour l'instant." if kind == "question" else "Aucun examen réalisé. Équipez un outil (TAB) et examinez le patient.", 14, SUB, "regular")
			e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(e)


func _page_diagnostic(r: PatientRecord) -> void:
	_heading("Diagnostic", "Choisissez l'hypothèse principale")
	var opts: Array = [r.data.get("diagnosis", "")]
	opts.append_array(r.data.get("differentials", []))
	var rng := RandomNumberGenerator.new()
	rng.seed = r.case_id.hash()
	for i in range(opts.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = opts[i]
		opts[i] = opts[j]
		opts[j] = tmp
	var group := ButtonGroup.new()
	for d in opts:
		var b := _choice_card(Cases.DIAGNOSES.get(d, d), "", r.diagnosis == d)
		b.button_group = group
		b.pressed.connect(_pick_diag.bind(r, String(d)))
		_content.add_child(b)
	var tip := _lbl("Les examens ciblés et l'interrogatoire orientent le diagnostic. Les éléments anormaux apparaissent en orange dans le dossier.", 14, SUB, "regular")
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(tip)
	_content.add_child(_primary("Continuer vers l'ordonnance", TEAL, show_page.bind("ordonnance")))


func _pick_diag(r: PatientRecord, d: String) -> void:
	r.diagnosis = d
	Sfx.ui("click")
	show_page.call_deferred("diagnostic")


func _page_ordonnance(r: PatientRecord) -> void:
	_heading("Ordonnance et orientation", "Plusieurs choix possibles")
	var cols := UITheme.hbox(18)
	_content.add_child(cols)
	var left := UITheme.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var groups := {"rx": "Médicaments et soins", "bio": "Examens complémentaires", "orientation": "Orientation", "conseil": "Conseils et arrêt"}
	for g in groups.keys():
		var items: Array = []
		for t in r.data.get("options", []):
			if Cases.treatment_kind(t) == g:
				items.append(t)
		if items.is_empty():
			continue
		left.add_child(_lbl(String(groups[g]).to_upper(), 13, TEAL, "bold"))
		for t in items:
			var b := _choice_card(Cases.treatment_label(t), Cases.treatment_line(t), t in r.treatments)
			if t == "samu":
				b.add_theme_color_override("font_color", RED)
			b.toggled.connect(_toggle_rx.bind(r, String(t)))
			left.add_child(b)
	cols.add_child(_paper(r))


func _toggle_rx(on: bool, r: PatientRecord, t: String) -> void:
	if on and not (t in r.treatments):
		r.treatments.append(t)
	elif not on:
		r.treatments.erase(t)
	Sfx.ui("click")
	show_page.call_deferred("ordonnance")


func _paper(r: PatientRecord) -> Control:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 0.995)
	s.shadow_color = Color(0, 0, 0, 0.18)
	s.shadow_size = 14
	s.shadow_offset = Vector2(0, 6)
	s.content_margin_left = 30
	s.content_margin_right = 30
	s.content_margin_top = 28
	s.content_margin_bottom = 30
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(470, 600)
	var v := UITheme.vbox(6)
	p.add_child(v)
	v.add_child(_lbl("Dr %s" % Game.settings.get("doctor_name", "Martin"), 20, INK, "display"))
	v.add_child(_lbl("Médecine générale — Conventionné secteur 1", 12, SUB, "medium"))
	v.add_child(_lbl("2 place de l'Église, 37000 Saint-Aubin-sur-Loire", 12, SUB, "regular"))
	v.add_child(_sep())
	var d := UITheme.hbox(10)
	v.add_child(d)
	var who := _lbl("%s  (%d ans)" % [r.display_name(), r.age()], 15, INK, "semibold")
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.add_child(who)
	d.add_child(_lbl("le %s" % ["lundi", "mardi", "mercredi"][clampi(Game.day - 1, 0, 2)], 14, SUB, "medium"))
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	v.add_child(gap)
	if r.treatments.is_empty():
		v.add_child(_lbl("Aucune ligne de prescription.", 14, SUB, "regular"))
	var n := 0
	for t in r.treatments:
		n += 1
		var l := _lbl("%d.  %s" % [n, Cases.treatment_line(t)], 15, INK, "regular")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 400
		v.add_child(l)
	v.add_child(UITheme.spacer(true))
	var sig := _lbl("Signature", 13, SUB, "regular")
	sig.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(sig)
	var sn := _lbl("Dr %s" % Game.settings.get("doctor_name", "Martin"), 22, Color(0.15, 0.25, 0.6), "light")
	sn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(sn)
	return p


func _page_cloture(r: PatientRecord) -> void:
	_heading("Clôturer la consultation", "Vérifiez votre décision avant de valider")
	var c := _card()
	_content.add_child(c)
	var v := UITheme.vbox(10)
	c.add_child(v)
	v.add_child(_lbl("DIAGNOSTIC", 13, TEAL, "bold"))
	v.add_child(_lbl(Cases.DIAGNOSES.get(r.diagnosis, "Non renseigné"), 18, INK if r.diagnosis != "" else RED, "semibold"))
	v.add_child(_sep())
	v.add_child(_lbl("PRESCRIPTIONS (%d)" % r.treatments.size(), 13, TEAL, "bold"))
	if r.treatments.is_empty():
		v.add_child(_lbl("Aucune prescription.", 15, RED, "medium"))
	for t in r.treatments:
		v.add_child(_lbl("•  " + Cases.treatment_label(t), 15, INK, "regular"))
	v.add_child(_sep())
	v.add_child(_lbl("%d question%s posée%s  ·  %d examen%s réalisé%s" % [r.questions.size(), "s" if r.questions.size() > 1 else "", "s" if r.questions.size() > 1 else "", r.exams.size(), "s" if r.exams.size() > 1 else "", "s" if r.exams.size() > 1 else ""], 14, SUB, "medium"))
	var ok := r.diagnosis != "" and not r.treatments.is_empty()
	var b := _primary("Valider la consultation", TEAL, _conclude.bind(r))
	b.disabled = not ok
	b.custom_minimum_size = Vector2(300, 50)
	_content.add_child(b)
	if not ok:
		_content.add_child(_lbl("Choisissez un diagnostic et au moins une prescription.", 14, AMBER, "medium"))


func _conclude(r: PatientRecord) -> void:
	var res := session.conclude_consultation(r.diagnosis, r.treatments)
	if res.is_empty():
		return
	_result_shown = true
	Sfx.ui("success" if res.get("grade", "F") in ["A", "B"] else "error")
	for k in _nav.keys():
		(_nav[k] as Button).disabled = true
	for ch in _content.get_children():
		ch.queue_free()
	_report(r, res)


func _report(r: PatientRecord, res: Dictionary) -> void:
	_heading("Compte rendu de consultation", r.display_name())
	var top := _card()
	_content.add_child(top)
	var h := UITheme.hbox(26)
	top.add_child(h)
	var gcol: Color = {"A": GREEN, "B": TEAL, "C": AMBER}.get(res["grade"], RED)
	var circle := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(gcol, 0.1)
	cs.border_color = gcol
	cs.set_border_width_all(4)
	cs.set_corner_radius_all(999)
	cs.anti_aliasing = true
	circle.add_theme_stylebox_override("panel", cs)
	circle.custom_minimum_size = Vector2(124, 124)
	var gl := _lbl(res["grade"], 64, gcol, "display")
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	circle.add_child(gl)
	h.add_child(circle)
	var info := UITheme.vbox(6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var ok: bool = res["diagnosis_ok"]
	info.add_child(_lbl("Diagnostic exact" if ok else "Diagnostic erroné", 24, GREEN if ok else RED, "display"))
	info.add_child(_lbl("Votre diagnostic : %s" % res["diagnosis_given"], 16, INK, "medium"))
	if not ok:
		info.add_child(_lbl("Attendu : %s" % res["diagnosis_expected"], 15, SUB, "medium"))
	var stats := UITheme.hbox(30)
	info.add_child(stats)
	var rep: float = res["reputation_delta"]
	for st in [["SCORE", "%d / 100" % int(res["score"]), INK], ["SATISFACTION", "%d %%" % int(res["satisfaction"]), INK], ["DURÉE", "%d min" % int(res["minutes"]), INK], ["RÉPUTATION", "%s%.1f" % ["+" if rep >= 0 else "", rep], GREEN if rep >= 0 else RED], ["HONORAIRES", "+30 €", INK]]:
		var sv := UITheme.vbox(0)
		sv.add_child(_lbl(st[0], 12, SUB, "bold"))
		sv.add_child(_lbl(st[1], 19, st[2], "bold"))
		stats.add_child(sv)
	var cols := UITheme.hbox(16)
	_content.add_child(cols)
	var good := _card()
	good.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(good)
	var gv := UITheme.vbox(8)
	good.add_child(gv)
	gv.add_child(_lbl("POINTS À REVOIR", 13, AMBER, "bold"))
	var notes: Array = res["notes"]
	if notes.is_empty():
		gv.add_child(_lbl("Rien à redire : prise en charge exemplaire.", 15, GREEN, "medium"))
	for n in notes:
		var l := _lbl("•  " + String(n), 15, RED if String(n).begins_with("ERREUR") else INK, "semibold" if String(n).begins_with("ERREUR") else "regular")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gv.add_child(l)
	for pr in res.get("praise", []):
		gv.add_child(_lbl("✓  " + String(pr), 15, GREEN, "medium"))
	var teach := _card(Color(0.93, 0.97, 0.99), Color(0.6, 0.8, 0.9))
	teach.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(teach)
	var tv := UITheme.vbox(8)
	teach.add_child(tv)
	tv.add_child(_lbl("LE POINT MÉDICAL", 13, Color(0.1, 0.45, 0.65), "bold"))
	var tl := _lbl(res["teaching"], 15, INK, "regular")
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(tl)
	var txt := "Raccompagner le patient"
	if res.get("samu", false) and r.is_urgent():
		txt = "Appeler le 15 maintenant"
	var b := _primary(txt, RED if txt.begins_with("Appeler") else TEAL, request_close)
	b.custom_minimum_size = Vector2(320, 52)
	_content.add_child(b)


# --- Briques graphiques --------------------------------------------------------------

func _heading(title: String, sub: String) -> void:
	var v := UITheme.vbox(2)
	v.add_child(_lbl(title, 28, INK, "display"))
	if sub != "":
		v.add_child(_lbl(sub, 15, SUB, "medium"))
	_content.add_child(v)


func _lbl(text: String, size: int, col: Color, weight: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UITheme.font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _icon(name: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = Icons.glyph(name)
	l.add_theme_font_override("font", Icons.font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _card(bg: Color = CARD, border: Color = LINE) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(12)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	s.anti_aliasing = true
	p.add_theme_stylebox_override("panel", s)
	return p


func _sep() -> Control:
	var c := ColorRect.new()
	c.color = LINE
	c.custom_minimum_size = Vector2(0, 1)
	return c


func _chip(text: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(col, 0.12)
	s.set_corner_radius_all(999)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", s)
	var l := _lbl(text, 12, col.darkened(0.1), "bold")
	p.add_child(l)
	return p


func _row_header(names: Array, widths: Array) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.custom_minimum_size.y = 32
	for i in names.size():
		var l := _lbl(names[i], 12, SUB, "bold")
		if widths[i] == 0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			l.custom_minimum_size.x = widths[i]
		h.add_child(l)
	return h


func _nav_button(icon: String, text: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.text = "  " + text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_override("font", UITheme.font("semibold"))
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", TEAL)
	b.add_theme_color_override("font_hover_pressed_color", TEAL)
	b.add_theme_color_override("font_disabled_color", Color(SUB, 0.45))
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0, 0, 0, 0)
	n.set_corner_radius_all(10)
	n.content_margin_left = 14
	var hv := n.duplicate() as StyleBoxFlat
	hv.bg_color = Color(0, 0, 0, 0.05)
	var pr := n.duplicate() as StyleBoxFlat
	pr.bg_color = Color(TEAL, 0.12)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("hover_pressed", pr)
	b.add_theme_stylebox_override("disabled", n)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.icon = null
	var ic := _icon(icon, 18, TEAL)
	ic.position = Vector2(14, 12)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	b.text = "       " + text
	return b


func _primary(text: String, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", UITheme.font("bold"))
	b.add_theme_font_size_override("font_size", 16)
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(st, Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.7))
	var n := StyleBoxFlat.new()
	n.bg_color = col
	n.set_corner_radius_all(10)
	n.content_margin_left = 20
	n.content_margin_right = 20
	n.content_margin_top = 11
	n.content_margin_bottom = 11
	var hv := n.duplicate() as StyleBoxFlat
	hv.bg_color = col.lightened(0.12)
	var pr := n.duplicate() as StyleBoxFlat
	pr.bg_color = col.darkened(0.12)
	var ds := n.duplicate() as StyleBoxFlat
	ds.bg_color = Color(col, 0.35)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("disabled", ds)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(cb)
	return b


func _flat_button(text: String, col: Color, hover_bg: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0, 0, 0, 0)
	n.set_corner_radius_all(8)
	n.content_margin_left = 10
	n.content_margin_right = 10
	n.content_margin_top = 4
	n.content_margin_bottom = 4
	var hv := n.duplicate() as StyleBoxFlat
	hv.bg_color = hover_bg
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	return b


func _choice_card(title: String, sub: String, pressed: bool) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = pressed
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text = ("✓   " if pressed else "○   ") + title + ("" if sub == "" else "\n       " + sub)
	b.custom_minimum_size = Vector2(0, 52 if sub == "" else 66)
	b.add_theme_font_override("font", UITheme.font("semibold"))
	b.add_theme_font_size_override("font_size", 15)
	for st in ["font_color", "font_hover_color"]:
		b.add_theme_color_override(st, INK)
	b.add_theme_color_override("font_pressed_color", TEAL.darkened(0.25))
	b.add_theme_color_override("font_hover_pressed_color", TEAL.darkened(0.25))
	var n := StyleBoxFlat.new()
	n.bg_color = CARD
	n.border_color = LINE
	n.set_border_width_all(1)
	n.set_corner_radius_all(10)
	n.content_margin_left = 18
	n.content_margin_right = 18
	n.content_margin_top = 10
	n.content_margin_bottom = 10
	var hv := n.duplicate() as StyleBoxFlat
	hv.border_color = Color(TEAL, 0.6)
	var pr := n.duplicate() as StyleBoxFlat
	pr.bg_color = Color(TEAL, 0.08)
	pr.border_color = TEAL
	pr.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("hover_pressed", pr)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b
