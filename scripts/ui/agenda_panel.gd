class_name AgendaPanel
extends Control
## Logiciel de cabinet : agenda du jour et appel des patients.

signal call_requested(record: PatientRecord)
signal closed

var _list: VBoxContainer
var _subtitle: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.04, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.custom_minimum_size = Vector2(980, 0)
	center.add_child(card)
	var v := UITheme.vbox(18)
	card.add_child(v)

	var head := UITheme.hbox(16)
	v.add_child(head)
	var icon := PanelContainer.new()
	icon.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.ACCENT, 0.15), 14, Color(0, 0, 0, 0), 0, 14, 8))
	var il := UITheme.label("✚", "H2")
	il.add_theme_color_override("font_color", UITheme.ACCENT)
	icon.add_child(il)
	head.add_child(icon)
	var tv := UITheme.vbox(2)
	head.add_child(tv)
	tv.add_child(UITheme.label("LOGICIEL MÉDICAL", "AccentCaption"))
	tv.add_child(UITheme.label("Agenda du jour", "H1"))
	head.add_child(UITheme.spacer(false))
	_subtitle = UITheme.label("", "Muted")
	head.add_child(_subtitle)

	v.add_child(HSeparator.new())
	var cols := UITheme.hbox(16)
	v.add_child(cols)
	for c in [["HEURE", 90], ["PATIENT", 0], ["STATUT", 190], ["", 150]]:
		var l := UITheme.label(c[0], "Caption")
		l.custom_minimum_size.x = c[1]
		if c[1] == 0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(l)

	_list = UITheme.vbox(8)
	v.add_child(_list)

	var foot := UITheme.hbox(12)
	v.add_child(foot)
	foot.add_child(UITheme.label("Les patients sans rendez-vous apparaissent dès leur arrivée.", "Muted"))
	foot.add_child(UITheme.spacer(false))
	foot.add_child(UITheme.button("Fermer   TAB", "", func(): closed.emit()))


func open(records: Array[PatientRecord], office_busy: bool) -> void:
	_subtitle.text = "%s  ·  %s" % [Cases.day_data(Game.day)["title"].split(" — ")[0], Game.clock_text()]
	for c in _list.get_children():
		c.queue_free()
	var shown := 0
	for r in records:
		if r.walk_in and r.status == PatientRecord.Status.EXPECTED:
			continue
		_list.add_child(_row(r, office_busy))
		shown += 1
	if shown == 0:
		_list.add_child(UITheme.label("Aucun patient.", "Muted"))
	visible = true
	UITheme.fade_in(self, 0.18)


func _row(r: PatientRecord, office_busy: bool) -> Control:
	var p := PanelContainer.new()
	var urgent := r.is_urgent() and r.status == PatientRecord.Status.WAITING
	var bg := Color(UITheme.DANGER, 0.12) if urgent else Color(1, 1, 1, 0.035)
	p.add_theme_stylebox_override("panel", UITheme.box(bg, 12, Color(UITheme.DANGER, 0.5) if urgent else Color(1, 1, 1, 0.05), 1, 16, 12))
	var h := UITheme.hbox(16)
	p.add_child(h)
	var t := UITheme.label("S. RDV" if r.walk_in else Game.clock_text(r.appointment), "H3")
	t.custom_minimum_size.x = 90
	if r.walk_in:
		t.add_theme_color_override("font_color", UITheme.WARNING)
	h.add_child(t)
	var info := UITheme.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	info.add_child(UITheme.label("%s  ·  %d ans" % [r.display_name(), r.age()], "H3"))
	var motif := UITheme.label(String(r.data.get("motif", "")).replace("SANS RDV — ", ""), "Muted")
	motif.add_theme_font_size_override("font_size", 15)
	info.add_child(motif)
	var status_box := Control.new()
	status_box.custom_minimum_size = Vector2(190, 0)
	h.add_child(status_box)
	var col := UITheme.MUTED
	match r.status:
		PatientRecord.Status.WAITING: col = UITheme.DANGER if urgent else UITheme.ACCENT
		PatientRecord.Status.CALLED, PatientRecord.Status.IN_OFFICE, PatientRecord.Status.CONSULTING: col = UITheme.ACCENT_2
		PatientRecord.Status.LEAVING, PatientRecord.Status.DONE: col = UITheme.SUCCESS
		PatientRecord.Status.ARRIVING: col = UITheme.WARNING
	var badge := UITheme.badge(("URGENCE" if urgent else r.status_text().to_upper()), col)
	badge.position = Vector2(0, 8)
	status_box.add_child(badge)
	var action := Control.new()
	action.custom_minimum_size = Vector2(150, 44)
	h.add_child(action)
	if r.status == PatientRecord.Status.WAITING:
		var b := UITheme.button("Appeler", "DangerButton" if urgent else "PrimaryButton", func(): call_requested.emit(r))
		b.disabled = office_busy
		b.tooltip_text = "Un patient est déjà dans votre cabinet." if office_busy else ""
		b.custom_minimum_size = Vector2(150, 44)
		action.add_child(b)
	elif r.status == PatientRecord.Status.DONE and not r.result.is_empty():
		var g := UITheme.label("Note  %s" % r.result.get("grade", "-"), "H3")
		g.position = Vector2(30, 10)
		action.add_child(g)
	return p
