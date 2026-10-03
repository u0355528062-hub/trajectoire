class_name Overlays
extends RefCounted
## Écrans superposés : introduction de journée, bilan, pause, réglages.


static func _backdrop(alpha: float = 0.7) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.04, alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	return root


static func _centered_card(root: Control, width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.custom_minimum_size = Vector2(width, 0)
	center.add_child(card)
	var v := UITheme.vbox(18)
	card.add_child(v)
	UITheme.fade_in(root, 0.35)
	return v


# --- Introduction de la journée --------------------------------------------------------

static func day_intro(day: int, title: String, text: String, records: Array[PatientRecord], on_start: Callable) -> Control:
	var root := _backdrop(0.62)
	var v := _centered_card(root, 860)
	v.add_child(UITheme.label("MODE HISTOIRE  ·  JOUR %d SUR %d" % [day, Cases.day_count()], "AccentCaption"))
	v.add_child(UITheme.label(title, "H1"))
	var body := UITheme.label(text, "Body", true)
	body.add_theme_font_size_override("font_size", 19)
	body.add_theme_color_override("font_color", Color(UITheme.TEXT, 0.88))
	v.add_child(body)
	v.add_child(HSeparator.new())
	v.add_child(UITheme.label("RENDEZ-VOUS PRÉVUS", "Caption"))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 8)
	v.add_child(g)
	for r in records:
		if r.walk_in:
			continue
		var h := UITheme.hbox(12)
		var t := UITheme.label(Game.clock_text(r.appointment), "H3")
		t.add_theme_color_override("font_color", UITheme.ACCENT)
		h.add_child(t)
		h.add_child(UITheme.label("%s — %s" % [r.short_name(), String(r.data.get("motif", ""))], "Body"))
		g.add_child(h)
	var tip := UITheme.label("Des patients peuvent se présenter sans rendez-vous. Le temps passe pendant vos déplacements et chaque examen prend quelques minutes.", "Muted", true)
	v.add_child(tip)
	var row := UITheme.hbox(12)
	v.add_child(row)
	row.add_child(UITheme.spacer(false))
	var b := UITheme.button("Commencer la journée", "PrimaryButton", on_start)
	b.custom_minimum_size = Vector2(260, 52)
	row.add_child(b)
	b.grab_focus.call_deferred()
	return root


# --- Bilan de fin de journée --------------------------------------------------------------

static func day_report(day: int, results: Array[Dictionary], last: bool, on_continue: Callable, on_menu: Callable) -> Control:
	var root := _backdrop(0.75)
	var v := _centered_card(root, 920)
	v.add_child(UITheme.label("FIN DE LA MATINÉE  ·  JOUR %d" % day, "AccentCaption"))
	v.add_child(UITheme.label("Bilan de la journée", "H1"))
	var total_score := 0.0
	var correct := 0
	for r in results:
		total_score += float(r.get("score", 0))
		if r.get("diagnosis_ok", false):
			correct += 1
	var avg := total_score / maxf(1.0, results.size())
	var stats := UITheme.hbox(14)
	v.add_child(stats)
	stats.add_child(_kpi("PATIENTS VUS", str(results.size())))
	stats.add_child(_kpi("DIAGNOSTICS EXACTS", "%d / %d" % [correct, results.size()]))
	stats.add_child(_kpi("SCORE MOYEN", "%d" % int(avg)))
	stats.add_child(_kpi("RÉPUTATION", "%d" % int(round(Game.reputation))))
	stats.add_child(_kpi("HONORAIRES", "%d €" % int(Game.money)))
	v.add_child(HSeparator.new())
	for r in results:
		var row := UITheme.hbox(16)
		var grade: String = r.get("grade", "-")
		var col := UITheme.SUCCESS if grade == "A" else (UITheme.ACCENT if grade == "B" else (UITheme.WARNING if grade == "C" else UITheme.DANGER))
		var gb := UITheme.badge(" %s " % grade, col)
		gb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(gb)
		var n := UITheme.label(r.get("name", "?"), "H3")
		n.custom_minimum_size.x = 220
		row.add_child(n)
		var d := UITheme.label(r.get("diagnosis_expected", ""), "Muted")
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(d)
		row.add_child(UITheme.label("%d pts" % int(r.get("score", 0)), "Body"))
		v.add_child(row)
	if last:
		v.add_child(HSeparator.new())
		var end := UITheme.label("Fin du prototype — merci d'avoir joué !\nLe Dr Marchand est fière de vous. Prochainement : modes Urgentiste, SAMU, Chirurgie et Sandbox.", "Body", true)
		end.add_theme_color_override("font_color", UITheme.ACCENT)
		v.add_child(end)
	var row2 := UITheme.hbox(12)
	v.add_child(row2)
	if not last:
		row2.add_child(UITheme.button("Menu principal", "GhostButton", on_menu))
	row2.add_child(UITheme.spacer(false))
	var b := UITheme.button("Retour au menu" if last else "Journée suivante  →", "PrimaryButton", on_continue)
	b.custom_minimum_size = Vector2(240, 52)
	row2.add_child(b)
	b.grab_focus.call_deferred()
	return root


static func _kpi(title: String, value: String) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = "SoftCard"
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UITheme.vbox(4)
	p.add_child(v)
	v.add_child(UITheme.label(title, "Caption"))
	var l := UITheme.label(value, "H2")
	v.add_child(l)
	return p


# --- Pause ----------------------------------------------------------------------------

static func pause_menu(on_resume: Callable, on_quit: Callable) -> Control:
	var root := _backdrop(0.6)
	var v := _centered_card(root, 460)
	v.add_child(UITheme.label("PAUSE", "AccentCaption"))
	v.add_child(UITheme.label("Cabinet de Saint-Aubin", "H2"))
	var settings_holder := UITheme.vbox(12)
	settings_holder.visible = false
	var buttons := UITheme.vbox(10)
	v.add_child(buttons)
	v.add_child(settings_holder)
	var resume := UITheme.button("Reprendre", "PrimaryButton", on_resume)
	resume.custom_minimum_size.y = 50
	buttons.add_child(resume)
	resume.grab_focus.call_deferred()
	buttons.add_child(UITheme.button("Paramètres", "", func():
		buttons.visible = false
		settings_holder.visible = true))
	buttons.add_child(UITheme.button("Quitter vers le menu principal", "", on_quit))
	settings_holder.add_child(settings_panel())
	settings_holder.add_child(UITheme.button("Retour", "", func():
		settings_holder.visible = false
		buttons.visible = true))
	return root


# --- Réglages -------------------------------------------------------------------------

static func settings_panel() -> Control:
	var v := UITheme.vbox(16)
	v.custom_minimum_size = Vector2(400, 0)
	v.add_child(_slider_row("Sensibilité de la souris", 0.05, 0.8, 0.01, float(Game.settings["sensitivity"]), "sensitivity", "%.2f"))
	v.add_child(_slider_row("Champ de vision", 60.0, 100.0, 1.0, float(Game.settings["fov"]), "fov", "%d°"))
	v.add_child(UITheme.label("QUALITÉ GRAPHIQUE", "Caption"))
	var q := UITheme.hbox(6)
	var group := ButtonGroup.new()
	var names := ["Performance", "Équilibrée", "Ultra"]
	for i in range(3):
		var b := UITheme.button(names[i], "TabButton")
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = int(Game.settings["quality"]) == i
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(Game.set_setting.bind("quality", i))
		q.add_child(b)
	var qp := PanelContainer.new()
	qp.add_theme_stylebox_override("panel", UITheme.box(Color(1, 1, 1, 0.04), 12, Color(0, 0, 0, 0), 0, 5, 5))
	qp.add_child(q)
	v.add_child(qp)
	var qhint := UITheme.label("Ultra : illumination globale SDFGI, brouillard volumétrique, réflexions.", "Muted", true)
	qhint.add_theme_font_size_override("font_size", 14)
	v.add_child(qhint)
	v.add_child(_toggle_row("Balancement de la caméra", "head_bob"))
	v.add_child(_toggle_row("Plein écran", "fullscreen"))
	return v


static func _slider_row(title: String, min_v: float, max_v: float, step: float, value: float, key: String, fmt: String) -> Control:
	var v := UITheme.vbox(6)
	var h := UITheme.hbox(8)
	v.add_child(h)
	h.add_child(UITheme.label(title.to_upper(), "Caption"))
	h.add_child(UITheme.spacer(false))
	var val := UITheme.label(fmt % value, "Caption")
	val.add_theme_color_override("font_color", UITheme.TEXT)
	h.add_child(val)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size = Vector2(0, 24)
	s.value_changed.connect(func(x: float):
		val.text = fmt % x
		Game.set_setting(key, x))
	v.add_child(s)
	return v


static func _toggle_row(title: String, key: String) -> Control:
	var c := CheckButton.new()
	c.text = title
	c.button_pressed = bool(Game.settings[key])
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on: bool): Game.set_setting(key, on))
	return c
