class_name MainMenu
extends Node3D
## Menu principal avec le cabinet en arrière-plan (caméra cinématique).

signal new_game
signal continue_game
signal quit_game

var _cam: Camera3D
var _t := 0.0
var _ui: Control
var _main_col: VBoxContainer
var _settings_col: VBoxContainer

const SHOTS := [
	[Vector3(1.0, 1.62, 5.2), Vector3(3.6, 1.05, 1.2)],
	[Vector3(-0.9, 1.6, 5.0), Vector3(-5.0, 0.9, 0.9)],
	[Vector3(5.3, 1.6, 1.4), Vector3(1.6, 1.0, 4.4)],
]


func _ready() -> void:
	var clinic := Clinic.new()
	add_child(clinic)
	clinic.build()
	clinic.set_screen("Agenda", "Bienvenue, docteur.")
	_cam = Camera3D.new()
	_cam.fov = 62
	add_child(_cam)
	_cam.current = true
	_build_ui()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	_t += delta
	var shot_len := 11.0
	var idx := int(_t / shot_len) % SHOTS.size()
	var k := fmod(_t, shot_len) / shot_len
	var s: Array = SHOTS[idx]
	var from: Vector3 = s[0]
	var to: Vector3 = s[1]
	var side := (to - from).cross(Vector3.UP).normalized()
	var pos := from + side * lerpf(-0.5, 0.5, k) + Vector3(0, sin(k * PI) * 0.06, 0)
	_cam.global_position = pos
	_cam.look_at(to + side * lerpf(-0.2, 0.2, k), Vector3.UP)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.theme = UITheme.get_theme()
	layer.add_child(_ui)

	# Dégradé de lisibilité à gauche
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.035, 0.06, 0.94))
	grad.set_color(1, Color(0.02, 0.035, 0.06, 0.0))
	grad.add_point(0.55, Color(0.02, 0.035, 0.06, 0.7))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_to = Vector2(1, 0)
	gt.width = 256
	gt.height = 4
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.anchor_right = 0.75
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 110)
	margin.add_theme_constant_override("margin_top", 90)
	margin.add_theme_constant_override("margin_bottom", 70)
	margin.add_theme_constant_override("margin_right", 90)
	_ui.add_child(margin)
	var root := UITheme.hbox(40)
	margin.add_child(root)

	var left := UITheme.vbox(0)
	left.custom_minimum_size = Vector2(560, 0)
	root.add_child(left)
	var brand := UITheme.hbox(12)
	left.add_child(brand)
	var cross := PanelContainer.new()
	cross.add_theme_stylebox_override("panel", UITheme.box(UITheme.ACCENT, 10, Color(0, 0, 0, 0), 0, 9, 1))
	var cl := UITheme.label("✚", "H3")
	cl.add_theme_color_override("font_color", Color(0.02, 0.1, 0.1))
	cross.add_child(cl)
	brand.add_child(cross)
	var bl := UITheme.label("SIMULATION MÉDICALE", "AccentCaption")
	bl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(bl)
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	left.add_child(gap)
	var title := UITheme.label("TRAJECTOIRE", "Title")
	title.add_theme_font_size_override("font_size", 92)
	title.add_theme_font_override("font", UITheme.spaced("display", 4))
	left.add_child(title)
	var sub := UITheme.label("Une vie de médecin, une décision à la fois.", "Body")
	sub.add_theme_font_override("font", UITheme.font("light"))
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(UITheme.TEXT, 0.8))
	left.add_child(sub)
	left.add_child(UITheme.spacer(true))

	_main_col = UITheme.vbox(4)
	left.add_child(_main_col)
	if Game.has_save():
		_menu_button(_main_col, "Continuer", "Reprendre l'histoire — jour %d" % _saved_day(), func(): continue_game.emit())
	_menu_button(_main_col, "Nouvelle partie", "Mode Histoire · Médecin généraliste", func(): new_game.emit())
	_menu_button(_main_col, "Paramètres", "Graphismes, contrôles", _show_settings)
	_menu_button(_main_col, "Quitter", "", func(): quit_game.emit())

	_settings_col = UITheme.vbox(14)
	_settings_col.visible = false
	left.add_child(_settings_col)
	var sp := PanelContainer.new()
	sp.theme_type_variation = "Card"
	sp.custom_minimum_size = Vector2(480, 0)
	_settings_col.add_child(sp)
	var spv := UITheme.vbox(16)
	sp.add_child(spv)
	spv.add_child(UITheme.label("Paramètres", "H2"))
	spv.add_child(Overlays.settings_panel())
	spv.add_child(UITheme.button("Retour", "", _hide_settings))

	left.add_child(UITheme.spacer(true))
	var ver := UITheme.label("Prototype 0.1  ·  Godot 4.4  ·  Contenus médicaux simplifiés à visée pédagogique", "Muted")
	ver.add_theme_font_size_override("font_size", 13)
	left.add_child(ver)

	root.add_child(UITheme.spacer(false))

	# Modes de jeu
	var right := UITheme.vbox(12)
	right.custom_minimum_size = Vector2(380, 0)
	right.size_flags_vertical = Control.SIZE_SHRINK_END
	root.add_child(right)
	right.add_child(UITheme.label("MODES DE JEU", "Caption"))
	_mode_card(right, "Médecin généraliste", "Histoire · Cabinet de Saint-Aubin", true, UITheme.ACCENT)
	_mode_card(right, "Urgentiste", "Service d'accueil des urgences", false, UITheme.WARNING)
	_mode_card(right, "SAMU · SMUR", "Interventions pré-hospitalières", false, UITheme.DANGER)
	_mode_card(right, "Chirurgie", "Bloc opératoire", false, UITheme.ACCENT_2)
	_mode_card(right, "Sandbox", "Cabinet libre, cas aléatoires", false, Color(0.7, 0.5, 0.95))
	UITheme.fade_in(_ui, 0.8)
	# Navigation au clavier / manette : flèches + Entrée.
	(_main_col.get_child(0) as Button).grab_focus.call_deferred()


func _saved_day() -> int:
	var f := FileAccess.open(Game.SAVE_PATH, FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			return clampi(int(d.get("day", 1)), 1, Cases.day_count())
	return 1


func _menu_button(parent: Control, text: String, sub: String, cb: Callable) -> void:
	var b := Button.new()
	b.theme_type_variation = "MenuButtonBig"
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(440, 64 if sub != "" else 50)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(cb)
	parent.add_child(b)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 22)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(m)
	var v := UITheme.vbox(1)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var t := UITheme.label(text, "H2")
	t.add_theme_font_size_override("font_size", 22)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	if sub != "":
		var s := UITheme.label(sub, "Muted")
		s.add_theme_font_size_override("font_size", 14)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(s)
	var bar := ColorRect.new()
	bar.color = UITheme.ACCENT
	bar.size = Vector2(3, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.visible = false
	b.add_child(bar)
	b.mouse_entered.connect(func():
		bar.visible = true
		bar.position = Vector2(0, 12)
		bar.size = Vector2(3, b.size.y - 24))
	b.mouse_exited.connect(func(): bar.visible = false)


func _mode_card(parent: Control, title: String, sub: String, available: bool, color: Color) -> void:
	var p := PanelContainer.new()
	var st := UITheme.box(Color(0.04, 0.06, 0.1, 0.78 if available else 0.55), 14, Color(color, 0.7) if available else Color(1, 1, 1, 0.06), 1, 18, 14)
	st.border_width_left = 4
	st.border_color = Color(color, 0.9 if available else 0.35)
	p.add_theme_stylebox_override("panel", st)
	parent.add_child(p)
	var h := UITheme.hbox(12)
	p.add_child(h)
	var v := UITheme.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var t := UITheme.label(title, "H3")
	if not available:
		t.add_theme_color_override("font_color", Color(UITheme.TEXT, 0.55))
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
	var back := _settings_col.find_children("*", "Button", true, false)
	if not back.is_empty():
		(back[back.size() - 1] as Button).grab_focus.call_deferred()


func _hide_settings() -> void:
	_settings_col.visible = false
	_main_col.visible = true
	(_main_col.get_child(0) as Button).grab_focus.call_deferred()
