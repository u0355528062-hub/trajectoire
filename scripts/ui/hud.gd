class_name Hud
extends Control
## Interface en jeu : horloge, objectif, patient en cours, outil équipé,
## invites (E / clic gauche), anneau de progression d'examen, sous-titres,
## notifications, cartes de résultat, carnet de notes, appel téléphonique.

var _clock: Label
var _day: Label
var _status: Label
var _next: Label
var _waiting: Label
var _objective: Label
var _objective_panel: PanelContainer
var _rep_bar: ProgressBar
var _rep_value: Label
var _money: Label
var _toasts: VBoxContainer
var _crosshair: Control
var _prompt_box: VBoxContainer
var _prompt_e: Control
var _prompt_e_label: Label
var _prompt_x: Control
var _prompt_x_label: Label
var _prompt_x_key: Label
var _progress := 0.0
var _focused := false
var _tool_panel: PanelContainer
var _tool_icon: Label
var _tool_name: Label
var _patient_panel: PanelContainer
var _patient_name: Label
var _patient_info: Label
var _patient_pos: Label
var _subtitle_panel: PanelContainer
var _subtitle_name: Label
var _subtitle_text: Label
var _subtitle_t := 0.0
var _cards: VBoxContainer
var _center_msg: Label
var _notes: Control
var _phone: PanelContainer
var _play_ui: Array[Control] = []
var _playing := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Game.stats_changed.connect(_update_stats)
	_update_stats()
	set_clock(Game.clock_text())


func _build() -> void:
	# Horloge
	var tl := Glass.panel(18, 22, 14)
	tl.position = Vector2(30, 26)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tl)
	var v := UITheme.vbox(2)
	tl.add_child(v)
	_day = UITheme.label("", "AccentCaption")
	v.add_child(_day)
	var row := UITheme.hbox(16)
	v.add_child(row)
	_clock = UITheme.label("08:20", "H1")
	_clock.add_theme_font_size_override("font_size", 42)
	row.add_child(_clock)
	var col := UITheme.vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	_status = UITheme.label("", "Caption")
	_status.add_theme_color_override("font_color", UITheme.WARNING)
	_status.visible = false
	col.add_child(_status)
	_next = UITheme.label("", "Muted")
	_next.add_theme_font_size_override("font_size", 14)
	col.add_child(_next)
	_waiting = UITheme.label("", "Muted")
	_waiting.add_theme_font_size_override("font_size", 14)
	col.add_child(_waiting)

	# Objectif
	_objective_panel = Glass.panel(14, 18, 12)
	_objective_panel.position = Vector2(30, 146)
	_objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_objective_panel)
	var oh := UITheme.hbox(12)
	_objective_panel.add_child(oh)
	var target := _icon("map-pin", 20, UITheme.ACCENT)
	target.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	oh.add_child(target)
	var ov := UITheme.vbox(2)
	oh.add_child(ov)
	ov.add_child(UITheme.label("OBJECTIF", "AccentCaption"))
	_objective = UITheme.label("", "Body")
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size = Vector2(390, 0)
	_objective.add_theme_font_size_override("font_size", 16)
	ov.add_child(_objective)

	# Statistiques (haut droite)
	var tr := Glass.panel(18, 22, 14)
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.offset_right = -30
	tr.offset_left = -30
	tr.offset_top = 26
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	var sv := UITheme.hbox(26)
	tr.add_child(sv)
	var rep_box := UITheme.vbox(6)
	sv.add_child(rep_box)
	var rh := UITheme.hbox(8)
	rep_box.add_child(rh)
	rh.add_child(_icon("star", 14, UITheme.WARNING))
	rh.add_child(UITheme.label("RÉPUTATION", "Caption"))
	rh.add_child(UITheme.spacer(false))
	_rep_value = UITheme.label("50", "Caption")
	_rep_value.add_theme_color_override("font_color", UITheme.TEXT)
	rh.add_child(_rep_value)
	_rep_bar = ProgressBar.new()
	_rep_bar.custom_minimum_size = Vector2(180, 7)
	_rep_bar.show_percentage = false
	_rep_bar.max_value = 100
	rep_box.add_child(_rep_bar)
	var mb := UITheme.vbox(2)
	sv.add_child(mb)
	var mh := UITheme.hbox(6)
	mb.add_child(mh)
	mh.add_child(_icon("euro", 14, UITheme.SUCCESS))
	mh.add_child(UITheme.label("HONORAIRES", "Caption"))
	_money = UITheme.label("0 €", "H3")
	mb.add_child(_money)

	# Notifications
	_toasts = UITheme.vbox(10)
	_toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toasts.offset_right = -30
	_toasts.offset_left = -470
	_toasts.offset_top = 126
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)

	# Cartes de résultat (à droite)
	_cards = UITheme.vbox(10)
	_cards.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_cards.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_cards.offset_right = -30
	_cards.offset_left = -450
	_cards.offset_top = 60
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cards)

	# Réticule
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(_draw_crosshair)
	add_child(_crosshair)

	# Invites d'action
	_prompt_box = UITheme.vbox(8)
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt_box)
	_prompt_e = _make_prompt("E")
	_prompt_e_label = _prompt_e.get_meta("label")
	_prompt_box.add_child(_prompt_e)
	_prompt_x = _make_prompt(Icons.glyph("mouse-pointer-click"), true)
	_prompt_x_label = _prompt_x.get_meta("label")
	_prompt_x_key = _prompt_x.get_meta("key")
	_prompt_box.add_child(_prompt_x)
	_prompt_e.visible = false
	_prompt_x.visible = false

	# Outil équipé (bas centre)
	_tool_panel = Glass.panel(16, 18, 10)
	_tool_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tool_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tool_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tool_panel.offset_bottom = -26
	_tool_panel.offset_top = -26
	_tool_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tool_panel)
	var th := UITheme.hbox(12)
	_tool_panel.add_child(th)
	_tool_icon = _icon("hand", 24, UITheme.ACCENT)
	th.add_child(_tool_icon)
	var tv := UITheme.vbox(0)
	th.add_child(tv)
	tv.add_child(UITheme.label("OUTIL", "Caption"))
	_tool_name = UITheme.label("Mains", "H3")
	tv.add_child(_tool_name)
	var keys := UITheme.label("TAB  roue    ·    molette  changer    ·    clic droit  ranger    ·    C  carnet", "Caption")
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(keys)

	# Patient en cours (bas gauche)
	_patient_panel = Glass.panel(16, 20, 14)
	_patient_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_patient_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_patient_panel.offset_left = 30
	_patient_panel.offset_bottom = -26
	_patient_panel.offset_top = -26
	_patient_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_patient_panel.visible = false
	add_child(_patient_panel)
	var pv := UITheme.vbox(3)
	_patient_panel.add_child(pv)
	pv.add_child(UITheme.label("EN CONSULTATION", "AccentCaption"))
	_patient_name = UITheme.label("", "H3")
	pv.add_child(_patient_name)
	_patient_info = UITheme.label("", "Muted")
	_patient_info.add_theme_font_size_override("font_size", 14)
	pv.add_child(_patient_info)
	_patient_pos = UITheme.label("", "Muted")
	_patient_pos.add_theme_font_size_override("font_size", 14)
	_patient_pos.add_theme_color_override("font_color", UITheme.ACCENT_2)
	pv.add_child(_patient_pos)

	# Sous-titres
	_subtitle_panel = PanelContainer.new()
	_subtitle_panel.add_theme_stylebox_override("panel", UITheme.box(Color(0, 0, 0, 0.58), 12, Color(0, 0, 0, 0), 0, 18, 10))
	_subtitle_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subtitle_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_subtitle_panel.offset_bottom = -124
	_subtitle_panel.offset_top = -124
	_subtitle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_panel.visible = false
	add_child(_subtitle_panel)
	var sh := UITheme.hbox(10)
	_subtitle_panel.add_child(sh)
	_subtitle_name = UITheme.label("", "H3")
	_subtitle_name.add_theme_color_override("font_color", UITheme.ACCENT)
	_subtitle_name.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	sh.add_child(_subtitle_name)
	_subtitle_text = UITheme.label("", "Body", true)
	_subtitle_text.add_theme_font_size_override("font_size", 19)
	_subtitle_text.custom_minimum_size.x = 640
	sh.add_child(_subtitle_text)

	# Message central (fondus)
	_center_msg = UITheme.label("", "H1")
	_center_msg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_msg.modulate.a = 0.0
	_center_msg.z_index = 5
	add_child(_center_msg)

	_play_ui = [tl, _objective_panel, tr, _tool_panel]


func _icon(name: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = Icons.glyph(name)
	l.add_theme_font_override("font", Icons.font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _make_prompt(key: String, icon_key: bool = false) -> PanelContainer:
	var p := Glass.panel(999, 14, 7)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UITheme.hbox(10)
	p.add_child(h)
	var kp := PanelContainer.new()
	kp.add_theme_stylebox_override("panel", UITheme.box(Color(1, 1, 1, 0.93), 6, Color(0, 0, 0, 0), 0, 8, 1))
	var kl := Label.new()
	kl.text = key
	if icon_key:
		kl.add_theme_font_override("font", Icons.font())
		kl.add_theme_font_size_override("font_size", 16)
	else:
		kl.add_theme_font_override("font", UITheme.font("bold"))
		kl.add_theme_font_size_override("font_size", 15)
	kl.add_theme_color_override("font_color", Color(0.05, 0.08, 0.12))
	kp.add_child(kl)
	h.add_child(kp)
	var l := UITheme.label("", "H3")
	l.add_theme_font_size_override("font_size", 17)
	h.add_child(l)
	p.set_meta("label", l)
	p.set_meta("key", kl)
	return p


func _process(delta: float) -> void:
	var vs := get_viewport_rect().size
	_crosshair.position = vs * 0.5
	if _prompt_box.visible:
		_prompt_box.reset_size()
		_prompt_box.position = Vector2(vs.x * 0.5 - _prompt_box.size.x * 0.5, vs.y * 0.5 + 46)
	if _subtitle_t > 0.0:
		_subtitle_t -= delta
		if _subtitle_t <= 0.0:
			var tw := create_tween()
			tw.tween_property(_subtitle_panel, "modulate:a", 0.0, 0.3)
			tw.tween_callback(_subtitle_panel.hide)


func _draw_crosshair() -> void:
	if _progress > 0.0:
		_crosshair.draw_arc(Vector2.ZERO, 20, 0, TAU, 64, Color(1, 1, 1, 0.18), 4.0, true)
		_crosshair.draw_arc(Vector2.ZERO, 20, -PI * 0.5, -PI * 0.5 + TAU * _progress, 64, UITheme.ACCENT, 4.0, true)
		_crosshair.draw_circle(Vector2.ZERO, 3.0, UITheme.ACCENT)
	elif _focused:
		_crosshair.draw_arc(Vector2.ZERO, 11, 0, TAU, 48, Color(UITheme.ACCENT, 0.95), 2.0, true)
		_crosshair.draw_circle(Vector2.ZERO, 2.5, UITheme.ACCENT)
	else:
		_crosshair.draw_circle(Vector2.ZERO, 3.2, Color(0, 0, 0, 0.35))
		_crosshair.draw_circle(Vector2.ZERO, 2.2, Color(1, 1, 1, 0.9))


# --- API --------------------------------------------------------------------------------

func set_play_mode(playing: bool) -> void:
	_playing = playing
	for c in _play_ui:
		c.visible = playing
	_crosshair.visible = playing
	_prompt_box.visible = playing
	if not playing:
		_progress = 0.0
		_crosshair.queue_redraw()


## Roue des outils ouverte : masque le réticule et les invites.
func set_dim(on: bool) -> void:
	_crosshair.visible = not on and _playing
	_prompt_box.visible = not on and _playing
	_tool_panel.visible = not on and _playing


func set_prompt(text: String) -> void:
	_prompt_e.visible = text != ""
	_prompt_e_label.text = text
	_refresh_focus()


func set_exam_prompt(verb: String, spot: String, warning: String) -> void:
	if verb == "":
		_prompt_x.visible = false
	else:
		_prompt_x.visible = true
		if warning != "":
			_prompt_x_label.text = "%s — %s" % [spot, warning]
			_prompt_x_label.add_theme_color_override("font_color", UITheme.WARNING)
			_prompt_x_key.text = Icons.glyph("triangle-alert")
		else:
			_prompt_x_label.text = "%s  ·  %s" % [verb, spot]
			_prompt_x_label.remove_theme_color_override("font_color")
			_prompt_x_key.text = Icons.glyph("mouse-pointer-click")
	_refresh_focus()


func _refresh_focus() -> void:
	_focused = _prompt_e.visible or _prompt_x.visible
	_crosshair.queue_redraw()


func set_progress(r: float) -> void:
	_progress = r
	_crosshair.queue_redraw()


func set_tool(id: String) -> void:
	var t := ExamDB.tool_def(id)
	_tool_icon.text = Icons.glyph(t.get("icon", "hand"))
	_tool_name.text = t.get("name", "Mains")


func set_consulting(on: bool) -> void:
	_status.text = "CONSULTATION · HORLOGE EN PAUSE"
	_status.visible = on


func set_patient(r: PatientRecord) -> void:
	_patient_panel.visible = r != null
	if r == null:
		return
	_patient_name.text = r.display_name()
	_patient_info.text = "%d ans  ·  %s" % [r.age(), String(r.data.get("motif", "")).replace("SANS RDV — ", "")]
	var pos := r.position_text()
	_patient_pos.text = pos
	_patient_pos.visible = pos != ""
	_patient_panel.reset_size()


func set_clock(text: String) -> void:
	_clock.text = text


func set_next(text: String) -> void:
	_next.text = text


func set_waiting(n: int) -> void:
	_waiting.text = "Salle d'attente : %d" % n


func set_objective(text: String) -> void:
	if _objective.text != text:
		_objective.text = text
		_objective_panel.reset_size()
		UITheme.fade_in(_objective_panel, 0.4)


func _update_stats() -> void:
	var d := Cases.day_data(Game.day)
	_day.text = "JOUR %d  ·  %s" % [Game.day, String(d["title"]).split(" — ")[0].to_upper()]
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_rep_bar, "value", Game.reputation, 0.8)
	_rep_value.text = "%d" % int(round(Game.reputation))
	var c := UITheme.SUCCESS if Game.reputation >= 65.0 else (UITheme.ACCENT if Game.reputation >= 40.0 else (UITheme.WARNING if Game.reputation >= 25.0 else UITheme.DANGER))
	_rep_bar.add_theme_stylebox_override("fill", UITheme.box(c, 999, Color(0, 0, 0, 0), 0, 0, 0))
	_money.text = "%d €" % int(Game.money)


func toast(text: String, kind: String = "info") -> void:
	var color: Color = {"info": UITheme.ACCENT_2, "success": UITheme.SUCCESS, "warning": UITheme.WARNING, "danger": UITheme.DANGER}.get(kind, UITheme.ACCENT_2)
	var icon_name: String = {"info": "info", "success": "circle-check", "warning": "triangle-alert", "danger": "siren"}.get(kind, "info")
	var p := Glass.panel(14, 16, 12)
	p.custom_minimum_size = Vector2(440, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UITheme.hbox(12)
	p.add_child(h)
	var bar := ColorRect.new()
	bar.color = color
	bar.custom_minimum_size = Vector2(3, 0)
	h.add_child(bar)
	var ic := _icon(icon_name, 20, color)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(ic)
	var l := UITheme.label(text, "Body", true)
	l.add_theme_font_size_override("font_size", 16)
	l.custom_minimum_size = Vector2(360, 0)
	h.add_child(l)
	_toasts.add_child(p)
	_toasts.move_child(p, 0)
	UITheme.fade_in(p, 0.3)
	Sfx.ui("notify" if kind != "danger" else "alert", -2.0)
	while _toasts.get_child_count() > 4:
		var old := _toasts.get_child(_toasts.get_child_count() - 1)
		_toasts.remove_child(old)
		old.queue_free()
	var life := 8.0 if kind == "danger" else 6.0
	var tw := p.create_tween()
	tw.tween_interval(life)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


## Carte de résultat pour les examens sans visualisation dédiée.
func exam_card(title: String, text: String, abnormal: bool, minutes: int) -> void:
	var p := Glass.panel(16, 20, 16)
	p.custom_minimum_size = Vector2(420, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UITheme.vbox(6)
	p.add_child(v)
	var h := UITheme.hbox(10)
	v.add_child(h)
	h.add_child(_icon("clipboard-check", 20, UITheme.WARNING if abnormal else UITheme.SUCCESS))
	var tl := UITheme.label(title, "H3")
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tl)
	h.add_child(UITheme.badge("ANOMALIE" if abnormal else "NORMAL", UITheme.WARNING if abnormal else UITheme.SUCCESS))
	var body := UITheme.label(text, "Body", true)
	body.add_theme_font_size_override("font_size", 16)
	body.custom_minimum_size.x = 380
	v.add_child(body)
	var f := UITheme.label("+%d min  ·  noté dans le carnet (C)" % minutes, "Muted")
	f.add_theme_font_size_override("font_size", 13)
	v.add_child(f)
	_cards.add_child(p)
	UITheme.fade_in(p, 0.25)
	while _cards.get_child_count() > 2:
		var old := _cards.get_child(0)
		_cards.remove_child(old)
		old.queue_free()
	var tw := p.create_tween()
	tw.tween_interval(9.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func subtitle(speaker: String, text: String, duration: float) -> void:
	_subtitle_name.text = speaker + " :"
	_subtitle_text.text = text
	_subtitle_panel.visible = true
	_subtitle_panel.modulate.a = 1.0
	_subtitle_panel.reset_size()
	_subtitle_t = duration


func center_message(text: String, duration: float) -> void:
	_center_msg.text = text
	var tw := create_tween()
	tw.tween_property(_center_msg, "modulate:a", 1.0, 0.4)
	tw.tween_interval(duration)
	tw.tween_property(_center_msg, "modulate:a", 0.0, 0.5)


func phone_call(on: bool) -> void:
	if on:
		if _phone and is_instance_valid(_phone):
			_phone.queue_free()
		_phone = Glass.panel(20, 26, 20)
		_phone.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_phone.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_phone.offset_top = 40
		var h := UITheme.hbox(14)
		_phone.add_child(h)
		h.add_child(_icon("phone", 28, UITheme.DANGER))
		var v := UITheme.vbox(2)
		h.add_child(v)
		v.add_child(UITheme.label("APPEL EN COURS", "AccentCaption"))
		v.add_child(UITheme.label("SAMU — Centre 15", "H2"))
		add_child(_phone)
		UITheme.fade_in(_phone, 0.3)
		Sfx.ui("phone_dial")
	elif _phone and is_instance_valid(_phone):
		var tw := create_tween()
		tw.tween_property(_phone, "modulate:a", 0.0, 0.4)
		tw.tween_callback(_phone.queue_free)


# --- Carnet de notes (C) -----------------------------------------------------------------

func show_notes(r: PatientRecord) -> void:
	hide_notes()
	_notes = Control.new()
	_notes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_notes.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_notes)
	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.02, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_notes.add_child(dim)
	var p := Glass.panel(20, 28, 24)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -440
	p.offset_right = 440
	p.offset_top = -380
	p.offset_bottom = 380
	_notes.add_child(p)
	var v := UITheme.vbox(12)
	p.add_child(v)
	var h := UITheme.hbox(12)
	v.add_child(h)
	h.add_child(_icon("notebook-pen", 26, UITheme.ACCENT))
	var tv := UITheme.vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(UITheme.label("CARNET DE CONSULTATION", "AccentCaption"))
	tv.add_child(UITheme.label(r.display_name() if r else "", "H2"))
	h.add_child(UITheme.label("C / Échap : fermer", "Caption"))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := UITheme.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	if r == null or r.notes.is_empty():
		list.add_child(UITheme.label("Rien de noté pour l'instant.", "Muted"))
		return
	for n in r.notes:
		var item := PanelContainer.new()
		item.add_theme_stylebox_override("panel", UITheme.box(Color(1, 1, 1, 0.04), 10, Color(UITheme.WARNING, 0.6) if n["abnormal"] else Color(1, 1, 1, 0.06), 1, 14, 10))
		var iv := UITheme.vbox(3)
		item.add_child(iv)
		var t := UITheme.label("%s  ·  %s" % [Game.clock_text(n["minute"]), n["title"]], "Caption")
		if n["abnormal"]:
			t.add_theme_color_override("font_color", UITheme.WARNING)
		iv.add_child(t)
		var b := UITheme.label(n["text"], "Body", true)
		b.add_theme_font_size_override("font_size", 16)
		b.custom_minimum_size.x = 780
		iv.add_child(b)
		list.add_child(item)


func hide_notes() -> void:
	if _notes and is_instance_valid(_notes):
		_notes.queue_free()
	_notes = null
