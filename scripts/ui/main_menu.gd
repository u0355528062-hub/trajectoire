class_name MainMenu
extends Node3D
## Menu principal : le cabinet en arrière-plan avec ses personnages,
## caméra cinématique, interface en verre dépoli.

signal new_game
signal continue_game
signal quit_game

const SHOTS := [
	[Vector3(1.0, 1.62, 5.2), Vector3(3.4, 1.15, 1.6)],
	[Vector3(-0.9, 1.6, 5.0), Vector3(-5.0, 1.0, 1.4)],
	[Vector3(5.3, 1.6, 1.3), Vector3(2.6, 1.2, 3.0)],
]

var _cam: Camera3D
var _t := 0.0
var _ui: Control
var _main_col: VBoxContainer
var _settings_col: VBoxContainer
var _modal: Control


func _ready() -> void:
	var clinic := Clinic.new()
	add_child(clinic)
	clinic.build()
	clinic.set_screen("Agenda", "Bienvenue, docteur.")
	_cam = Camera3D.new()
	_cam.fov = 60
	add_child(_cam)
	_cam.current = true
	_populate()
	_build_ui()
	Sfx.music("menu_theme", 2.5)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _populate() -> void:
	var doc := Character.new()
	add_child(doc)
	doc.setup("docteur", "m")
	doc.place_standing(Vector3(3.6, 0, 3.4), Vector3(-0.6, 0, -1))
	doc.play_loop("docs")
	var cam := Character.new()
	add_child(cam)
	cam.setup("camille_secretaire", "f")
	cam.place_seated(Vector3(-6.42, 0, 3.5), Vector3.RIGHT, 0.0, "type")
	var pat := Character.new()
	add_child(pat)
	pat.setup("monique_lefevre", "f")
	pat.place_seated(Clinic.PATIENT_SEAT, Vector3.FORWARD)
	pat.look_target = doc.head_bone_node()
	var w := Character.new()
	add_child(w)
	w.setup("patrick_morel", "m")
	w.place_seated(Vector3(-4.8, 0, 0.5), Vector3.BACK)
	var w2 := Character.new()
	add_child(w2)
	w2.setup("ines_garcia", "f")
	w2.place_seated(Vector3(-3.2, 0, 0.5), Vector3.BACK)


func _process(delta: float) -> void:
	_t += delta
	var shot_len := 12.0
	var idx := int(_t / shot_len) % SHOTS.size()
	var k := fmod(_t, shot_len) / shot_len
	var s: Array = SHOTS[idx]
	var from: Vector3 = s[0]
	var to: Vector3 = s[1]
	var side := (to - from).cross(Vector3.UP).normalized()
	var pos := from + side * lerpf(-0.45, 0.45, k) + Vector3(0, sin(k * PI) * 0.05, 0)
	_cam.global_position = pos
	_cam.look_at(to + side * lerpf(-0.15, 0.15, k), Vector3.UP)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.theme = UITheme.get_theme()
	layer.add_child(_ui)

	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.03, 0.05, 0.92))
	grad.set_color(1, Color(0.02, 0.03, 0.05, 0.0))
	grad.add_point(0.5, Color(0.02, 0.03, 0.05, 0.62))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_to = Vector2(1, 0)
	gt.width = 256
	gt.height = 4
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.anchor_right = 0.72
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 110)
	margin.add_theme_constant_override("margin_top", 86)
	margin.add_theme_constant_override("margin_bottom", 64)
	margin.add_theme_constant_override("margin_right", 80)
	_ui.add_child(margin)
	var root := UITheme.hbox(40)
	margin.add_child(root)

	var left := UITheme.vbox(0)
	left.custom_minimum_size = Vector2(580, 0)
	root.add_child(left)
	var brand := UITheme.hbox(12)
	left.add_child(brand)
	var cross := PanelContainer.new()
	cross.add_theme_stylebox_override("panel", UITheme.box(UITheme.ACCENT, 10, Color(0, 0, 0, 0), 0, 8, 4))
	var cl := Label.new()
	cl.text = Icons.glyph("stethoscope")
	cl.add_theme_font_override("font", Icons.font())
	cl.add_theme_font_size_override("font_size", 20)
	cl.add_theme_color_override("font_color", Color(0.02, 0.1, 0.1))
	cross.add_child(cl)
	brand.add_child(cross)
	var bl := UITheme.label("SIMULATION MÉDICALE", "AccentCaption")
	bl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(bl)
	var gap := Control.new()
	gap.custom_minimum_size.y = 16
	left.add_child(gap)
	var title := UITheme.label("TRAJECTOIRE", "Title")
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_font_override("font", UITheme.spaced("display", 4))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	title.add_theme_constant_override("shadow_offset_y", 4)
	left.add_child(title)
	var sub := UITheme.label("Une vie de médecin, une décision à la fois.", "Body")
	sub.add_theme_font_override("font", UITheme.font("light"))
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(UITheme.TEXT, 0.82))
	left.add_child(sub)
	left.add_child(UITheme.spacer(true))

	_main_col = UITheme.vbox(6)
	left.add_child(_main_col)
	if Game.has_save():
		_menu_button(_main_col, "play", "Continuer", "Reprendre l'histoire — jour %d" % _saved_day(), func(): continue_game.emit())
	_menu_button(_main_col, "stethoscope", "Nouvelle partie", "Mode Histoire · Médecin généraliste", _ask_name)
	_menu_button(_main_col, "settings", "Paramètres", "Graphismes, audio, contrôles", _show_settings)
	_menu_button(_main_col, "book-open", "Crédits", "Modèles, voix, polices", _show_credits)
	_menu_button(_main_col, "log-out", "Quitter", "", func(): quit_game.emit())

	_settings_col = UITheme.vbox(14)
	_settings_col.visible = false
	left.add_child(_settings_col)
	var sp := Glass.panel(22, 28, 24)
	sp.custom_minimum_size = Vector2(540, 0)
	_settings_col.add_child(sp)
	var spv := UITheme.vbox(16)
	sp.add_child(spv)
	spv.add_child(UITheme.label("Paramètres", "H2"))
	spv.add_child(Overlays.settings_panel())
	spv.add_child(Overlays.icon_button("arrow-left", "Retour", "", _hide_settings))

	left.add_child(UITheme.spacer(true))
	var ver := UITheme.label("Prototype 0.2  ·  Godot 4.6  ·  Contenus médicaux simplifiés à visée pédagogique", "Muted")
	ver.add_theme_font_size_override("font_size", 13)
	left.add_child(ver)

	root.add_child(UITheme.spacer(false))

	var right := UITheme.vbox(12)
	right.custom_minimum_size = Vector2(390, 0)
	right.size_flags_vertical = Control.SIZE_SHRINK_END
	root.add_child(right)
	right.add_child(UITheme.label("MODES DE JEU", "Caption"))
	_mode_card(right, "stethoscope", "Médecin généraliste", "Histoire · Cabinet de Saint-Aubin", true, UITheme.ACCENT)
	_mode_card(right, "hospital", "Urgentiste", "Service d'accueil des urgences", false, UITheme.WARNING)
	_mode_card(right, "ambulance", "SAMU · SMUR", "Interventions pré-hospitalières", false, UITheme.DANGER)
	_mode_card(right, "syringe", "Chirurgie", "Bloc opératoire", false, UITheme.ACCENT_2)
	_mode_card(right, "sparkles", "Sandbox", "Cabinet libre, cas aléatoires", false, Color(0.7, 0.5, 0.95))
	UITheme.fade_in(_ui, 0.9)
	(_main_col.get_child(0) as Button).grab_focus.call_deferred()


func _saved_day() -> int:
	var f := FileAccess.open(Game.SAVE_PATH, FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			return clampi(int(d.get("day", 1)), 1, Cases.day_count())
	return 1


func _menu_button(parent: Control, icon: String, text: String, sub: String, cb: Callable) -> void:
	var b := Button.new()
	b.theme_type_variation = "MenuButtonBig"
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(460, 66 if sub != "" else 52)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(func():
		Sfx.ui("click")
		cb.call())
	b.mouse_entered.connect(func(): Sfx.ui("hover", -8.0))
	parent.add_child(b)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 20)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(m)
	var h := UITheme.hbox(16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)
	var ic := Label.new()
	ic.text = Icons.glyph(icon)
	ic.add_theme_font_override("font", Icons.font())
	ic.add_theme_font_size_override("font_size", 24)
	ic.add_theme_color_override("font_color", UITheme.ACCENT)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var v := UITheme.vbox(1)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var t := UITheme.label(text, "H2")
	t.add_theme_font_size_override("font_size", 22)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	if sub != "":
		var s := UITheme.label(sub, "Muted")
		s.add_theme_font_size_override("font_size", 14)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(s)


func _mode_card(parent: Control, icon: String, title: String, sub: String, available: bool, color: Color) -> void:
	var p := Glass.panel(16, 18, 14)
	parent.add_child(p)
	if not available:
		p.modulate = Color(1, 1, 1, 0.72)
	var h := UITheme.hbox(14)
	p.add_child(h)
	var ic := Label.new()
	ic.text = Icons.glyph(icon)
	ic.add_theme_font_override("font", Icons.font())
	ic.add_theme_font_size_override("font_size", 24)
	ic.add_theme_color_override("font_color", color)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v := UITheme.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var t := UITheme.label(title, "H3")
	v.add_child(t)
	var s := UITheme.label(sub, "Muted")
	s.add_theme_font_size_override("font_size", 14)
	v.add_child(s)
	var badge := UITheme.badge("DISPONIBLE" if available else "BIENTÔT", color if available else UITheme.MUTED)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(badge)


func _show_settings() -> void:
	_main_col.visible = false
	_settings_col.visible = true


func _hide_settings() -> void:
	_settings_col.visible = false
	_main_col.visible = true
	(_main_col.get_child(0) as Button).grab_focus.call_deferred()


func _close_modal() -> void:
	if _modal and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null


func _ask_name() -> void:
	_close_modal()
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.02, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(c)
	var p := Glass.panel(24, 34, 30)
	p.custom_minimum_size = Vector2(560, 0)
	c.add_child(p)
	var v := UITheme.vbox(16)
	p.add_child(v)
	v.add_child(UITheme.label("NOUVELLE PARTIE", "AccentCaption"))
	v.add_child(UITheme.label("Comment vous appelez-vous, docteur ?", "H2"))
	var h := UITheme.hbox(10)
	v.add_child(h)
	h.add_child(UITheme.label("Dr", "H2"))
	var le := LineEdit.new()
	le.text = String(Game.settings.get("doctor_name", "Martin"))
	le.max_length = 24
	le.custom_minimum_size = Vector2(380, 48)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.select_all_on_focus = true
	h.add_child(le)
	var hint := UITheme.label("Votre nom apparaîtra sur la plaque du cabinet et sur vos ordonnances.", "Muted", true)
	v.add_child(hint)
	var row := UITheme.hbox(12)
	v.add_child(row)
	row.add_child(Overlays.icon_button("arrow-left", "Annuler", "GhostButton", _close_modal))
	row.add_child(UITheme.spacer(false))
	var go := func():
		var n := le.text.strip_edges()
		if n == "":
			n = "Martin"
		Game.set_setting("doctor_name", n.substr(0, 24))
		_close_modal()
		new_game.emit()
	row.add_child(Overlays.icon_button("play", "Commencer", "PrimaryButton", go))
	le.text_submitted.connect(func(_t: String): go.call())
	le.grab_focus.call_deferred()
	UITheme.fade_in(_modal, 0.25)


func _show_credits() -> void:
	_close_modal()
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.02, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(c)
	var p := Glass.panel(24, 34, 30)
	p.custom_minimum_size = Vector2(720, 0)
	c.add_child(p)
	var v := UITheme.vbox(12)
	p.add_child(v)
	v.add_child(UITheme.label("CRÉDITS", "AccentCaption"))
	v.add_child(UITheme.label("Trajectoire — prototype", "H2"))
	for line in [
		"Moteur : Godot Engine 4.6 (MIT).",
		"Personnages et animations : Microsoft Rocketbox Avatar Library (licence MIT).",
		"Voix de synthèse : Piper — voix « siwis » (CC BY 4.0, université d'Édimbourg), « gilles » (CC0), « mls_1840 » (CC BY 4.0, Multilingual LibriSpeech).",
		"Police : Inter de Rasmus Andersson (SIL Open Font License). Icônes : Lucide (licence ISC).",
		"Décors, sons, musiques, textures et outils médicaux : créés de manière procédurale pour ce projet.",
		"Contenus médicaux simplifiés à visée ludique et pédagogique : ils ne remplacent pas un avis médical.",
	]:
		var l := UITheme.label("•  " + line, "Body", true)
		l.add_theme_font_size_override("font_size", 16)
		v.add_child(l)
	var b := Overlays.icon_button("x", "Fermer", "", _close_modal)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(b)
	UITheme.fade_in(_modal, 0.25)
