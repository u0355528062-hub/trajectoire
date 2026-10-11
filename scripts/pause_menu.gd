class_name PauseMenu
extends CanvasLayer
## Menu Échap (charte UiStyle) : pause du jeu façon affiche (titre au marqueur, colonne de boutons,
## bilan de la partie), réglages en onglets (son, image, jeu, accessibilité), liste des commandes,
## recommencer / quitter avec confirmation. Ouvre aussi les réglages depuis l'écran titre.

signal resumed

var player: Player
var tension: Tension
var police: Police
var crowd: Crowd
var title: TitleScreen               # écran titre affiché au lancement (s'il y en a un)

var _open := false
var _page := "main"
var _from_title := false
var _root: Control
var _dim: ColorRect
var _shade: ColorRect
var _main: Control
var _main_col: VBoxContainer
var _holder: CenterContainer
var _card: PanelContainer
var _pages := {}
var _tab_btns: Array = []
var _tab_pages: Array = []
var _play_t := 0.0
var _stats: Label
var _save_timer: Timer
var _confirm: Control
var _confirm_card: Control
var _confirm_cb := Callable()
var _syncing := false
var _controls := {}                  # clé de réglage -> contrôle (pour la remise à zéro)


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiStyle.apply_theme(get_tree())
	Settings.load_all()
	Settings.apply(get_tree())
	get_tree().node_added.connect(Settings.route_player)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.5
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer.timeout.connect(Settings.save_all)
	add_child(_save_timer)
	_build()
	_root.visible = false


func bind(p: Player, t: Tension, pol: Police, c: Crowd) -> void:
	player = p
	tension = t
	police = pol
	crowd = c
	if TitleScreen.should_show(get_tree()):
		title = TitleScreen.new()
		title.menu = self
		add_child(title)


func is_open() -> bool:
	return _open


# =================================================================== construction
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	# fond : scène floutée, teintée d'encre, trame de points
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = textureLod(screen_tex, uv, 3.4 * amount).rgb;
	float g = dot(col, vec3(0.3, 0.55, 0.15));
	col = mix(col, vec3(g) * vec3(0.95, 0.9, 0.86), 0.55 * amount);
	col *= 1.0 - 0.6 * amount;
	float left = smoothstep(0.75, 0.0, uv.x);
	col *= 1.0 - left * 0.45 * amount;
	COLOR = vec4(col, 1.0);
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	_dim.material = sm
	_root.add_child(_dim)
	var ht := TextureRect.new()
	ht.texture = UiStyle.halftone_tex()
	ht.stretch_mode = TextureRect.STRETCH_TILE
	ht.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ht.set_anchors_preset(Control.PRESET_FULL_RECT)
	ht.modulate = Color(UiStyle.PAPER, 0.035)
	ht.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.add_child(ht)
	# voile supplémentaire derrière les cartes (réglages, commandes)
	_shade = ColorRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(UiStyle.INK, 0.45)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.visible = false
	_root.add_child(_shade)

	_main = _build_main()
	_root.add_child(_main)
	# carte centrale des sous-pages
	_holder = CenterContainer.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_holder)
	_card = PanelContainer.new()
	var cs := UiStyle.soft_shadow(UiStyle.box(Color(UiStyle.INK, 0.94), 8, Color(UiStyle.PAPER, 0.1), 1, 0.0), 0.55, 40, Vector2(0, 14))
	cs.border_width_top = 5
	cs.border_color = UiStyle.RED
	cs.content_margin_left = 36
	cs.content_margin_right = 36
	cs.content_margin_top = 26
	cs.content_margin_bottom = 30
	_card.add_theme_stylebox_override("panel", cs)
	_card.custom_minimum_size = Vector2(940, 0)
	_holder.add_child(_card)
	var vb := VBoxContainer.new()
	vb.name = "Pages"
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(vb)
	_pages["settings"] = _build_settings()
	_pages["controls"] = _build_controls()
	for k in _pages:
		(_pages[k] as Control).visible = false
		vb.add_child(_pages[k])
	_pages["main"] = _main
	_confirm = _build_confirm()
	_root.add_child(_confirm)
	_confirm.visible = false


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _click() -> void:
	AudioLib.play_at(self, "sfx:click", Vector3.ZERO, -14.0, 50.0, 1.3)


## Ruban adhésif rouge portant un mot (« PAUSE », « RÉGLAGES »…)
static func tape(text: String, bg := UiStyle.RED, fg := UiStyle.PAPER) -> Control:
	var p := PanelContainer.new()
	var st := UiStyle.box(bg, 2)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 3
	st.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.rotation = deg_to_rad(-2.0)
	p.add_child(UiStyle.label(text, 14, fg, "caps"))
	return p


## Page principale : colonne à gauche, titre au marqueur, boutons, bilan
func _build_main() -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	m.offset_right = 640
	m.add_theme_constant_override("margin_left", 120)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(m)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	_main_col = v
	v.add_child(tape("PARTIE EN PAUSE"))
	var t := UiStyle.misprint(UiStyle.label("BLOCUS", 128, UiStyle.PAPER, "marker"), UiStyle.RED, Vector2(7, 6))
	t.add_theme_constant_override("line_spacing", -30)
	v.add_child(t)
	_stats = UiStyle.label("", 14, UiStyle.PAPER_DIM, "caps")
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.custom_minimum_size.x = 460
	v.add_child(_stats)
	v.add_child(_gap(18))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size.x = 400
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(col)
	var b_resume := _menu_btn("Reprendre", true)
	b_resume.pressed.connect(func(): _click(); close())
	col.add_child(b_resume)
	var b_set := _menu_btn("Réglages")
	b_set.pressed.connect(func(): _click(); show_page("settings"))
	col.add_child(b_set)
	var b_ctl := _menu_btn("Commandes")
	b_ctl.pressed.connect(func(): _click(); show_page("controls"))
	col.add_child(b_ctl)
	col.add_child(_gap(6))
	var b_re := _menu_btn("Recommencer")
	b_re.pressed.connect(func(): _click(); _ask("Recommencer la partie ?", "Tout repart de zéro : tension, foule et police.", "Recommencer", _restart))
	col.add_child(b_re)
	var b_q := _menu_btn("Quitter le jeu")
	b_q.pressed.connect(func(): _click(); _ask("Quitter le jeu ?", "La partie en cours sera perdue.", "Quitter", func(): get_tree().quit()))
	col.add_child(b_q)
	v.add_child(_gap(14))
	var hint := HBoxContainer.new()
	hint.add_theme_constant_override("separation", 10)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(UiStyle.keycap("ÉCHAP", 14))
	var hl := UiStyle.label("pour reprendre", 15, UiStyle.PAPER_MUTE, "semibold")
	hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_child(hl)
	v.add_child(hint)
	return page


func _menu_btn(text: String, primary := false) -> UiKit.Btn:
	var b := UiKit.Btn.new(text.to_upper(), primary)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(400, 58 if primary else 52)
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb := b.get_theme_stylebox(k)
		if sb is StyleBoxFlat:
			(sb as StyleBoxFlat).content_margin_left = 24
	return b


## En-tête des sous-pages : « Retour », titre, action à droite
func _page_head(title_text: String, right: Control) -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	var back := UiKit.Btn.new("RETOUR", false, "ghost")
	back.pressed.connect(func(): _click(); _back())
	back.custom_minimum_size = Vector2(130, 40)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(back)
	var t := UiStyle.misprint(UiStyle.label(title_text, 44, UiStyle.PAPER, "marker"), UiStyle.RED, Vector2(4, 3))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	if right == null:
		right = Control.new()
	right.custom_minimum_size.x = 130
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(right)
	return head


# ------------------------------------------------------------------ réglages
func _build_settings() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reset := UiKit.Btn.new("PAR DÉFAUT", false, "ghost")
	reset.icon = null
	reset.tooltip_text = "Remettre tous les réglages par défaut"
	reset.pressed.connect(func():
		_click()
		Settings.reset()
		Settings.apply(get_tree())
		Settings.save_all()
		_sync_controls())
	v.add_child(_page_head("Réglages", reset))
	# onglets
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(tabs)
	var line := ColorRect.new()
	line.color = UiStyle.LINE
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	var names := ["Son", "Image", "Jeu", "Accessibilité"]
	var pages: Array[Control] = [_tab_sound(), _tab_image(), _tab_game(), _tab_access()]
	var host := Control.new()
	host.custom_minimum_size = Vector2(0, 560)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in names.size():
		var b := UiKit.Btn.new(names[i].to_upper(), false, "tab")
		b.pressed.connect(func(): _click(); _select_tab(i))
		tabs.add_child(b)
		_tab_btns.append(b)
		var sc := ScrollContainer.new()
		sc.set_anchors_preset(Control.PRESET_FULL_RECT)
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.mouse_filter = Control.MOUSE_FILTER_PASS
		sc.add_child(pages[i])
		pages[i].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		host.add_child(sc)
		_tab_pages.append(sc)
	v.add_child(host)
	_select_tab(0)
	return v


func _select_tab(i: int) -> void:
	for k in _tab_btns.size():
		(_tab_btns[k] as Button).button_pressed = k == i
		var pg := _tab_pages[k] as Control
		var was := pg.visible
		pg.visible = k == i
		if k == i and not was:
			pg.modulate.a = 0.0
			var tw := pg.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(pg, "modulate:a", 1.0, 0.18)


func _col() -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 0)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	return c


## Intertitre de groupe dans un onglet
func _group(text: String) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 18)
	m.add_theme_constant_override("margin_bottom", 4)
	m.add_theme_constant_override("margin_left", 14)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(UiStyle.label(text, 12, UiStyle.RED.lightened(0.15), "caps"))
	return m


func _sl(key: String, title_text: String, hint: String, lo: float, hi: float, step: float, fmt: String, scale := 1.0) -> Control:
	var s := UiKit.slider(lo, hi, step, float(Settings.d[key]))
	var vl := UiStyle.label("", 17, UiStyle.PAPER, "bold")
	var upd := func(v: float): vl.text = fmt % (v * scale)
	upd.call(s.value)
	s.value_changed.connect(func(v: float):
		upd.call(v)
		if _syncing:
			return
		Settings.d[key] = v
		_changed())
	_controls[key] = {"ctl": s, "upd": upd}
	return UiKit.row(title_text, hint, s, vl)


func _sw(key: String, title_text: String, hint: String) -> Control:
	var sw := UiKit.Switch.new(bool(Settings.d[key]))
	sw.toggled.connect(func(on: bool):
		if _syncing:
			return
		Settings.d[key] = on
		_click()
		_changed())
	_controls[key] = {"ctl": sw}
	return UiKit.row(title_text, hint, sw)


func _seg(key: String, title_text: String, hint: String, options: Array) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var btns: Array[Button] = []
	for i in options.size():
		var b := UiKit.Btn.new(str(options[i]), false, "seg")
		btns.append(b)
		box.add_child(b)
	var refresh := func():
		for k in btns.size():
			btns[k].button_pressed = k == int(Settings.d[key])
	refresh.call()
	for i in btns.size():
		btns[i].pressed.connect(func():
			if _syncing:
				return
			_click()
			Settings.d[key] = i
			if key == "quality":
				Settings.set_quality(i)
				_sync_controls()
			refresh.call()
			_changed())
	_controls[key] = {"ctl": box, "refresh": refresh}
	return UiKit.row(title_text, hint, box)


func _tab_sound() -> Control:
	var c := _col()
	c.add_child(_group("Volumes"))
	c.add_child(_sl("master", "Volume général", "", 0.0, 1.0, 0.01, "%d %%", 100.0))
	c.add_child(_sl("effects", "Effets", "Pas, explosions, feu, vitres, véhicules.", 0.0, 1.0, 0.01, "%d %%", 100.0))
	c.add_child(_sl("voices", "Voix", "Manifestants, policiers, mégaphones.", 0.0, 1.0, 0.01, "%d %%", 100.0))
	c.add_child(_sl("ambience", "Ambiance de foule", "Chants, murmure, applaudissements.", 0.0, 1.0, 0.01, "%d %%", 100.0))
	return c


func _tab_image() -> Control:
	var c := _col()
	c.add_child(_group("Qualité"))
	c.add_child(_seg("quality", "Préréglage", "Les options ci-dessous peuvent être ajustées une à une.", Settings.QUALITY_NAMES))
	c.add_child(_sl("render_scale", "Échelle de rendu", "Baisse pour gagner en fluidité (reconstruction FSR).", 0.5, 1.0, 0.05, "%d %%", 100.0))
	c.add_child(_seg("msaa", "Anti-crénelage", "", ["Aucun", "2x", "4x"]))
	c.add_child(_seg("smoke_q", "Fumées", "Gaz, feux, fumigènes : le plus gros coût. S'applique aux nouvelles fumées.", ["Basse", "Moyenne", "Haute"]))
	c.add_child(_group("Effets"))
	c.add_child(_sw("shadows", "Ombres", "Le soleil couchant projette de longues ombres."))
	c.add_child(_sw("ssao", "Occlusion ambiante", "Ombrage doux dans les recoins."))
	c.add_child(_sw("ssil", "Éclairage indirect", "Lumière rebondie (plus coûteux)."))
	c.add_child(_sw("ssr", "Réflexions", "Sol mouillé, vitres, carrosseries."))
	c.add_child(_sw("volfog", "Brouillard volumétrique", "Faisceaux et brume dans la lumière."))
	c.add_child(_sw("glow", "Halo lumineux", "Flammes, gyrophares, fumigènes."))
	c.add_child(_sl("brightness", "Luminosité", "", 0.6, 1.5, 0.01, "%d %%", 100.0))
	c.add_child(_group("Affichage"))
	c.add_child(_sw("fullscreen", "Plein écran", ""))
	c.add_child(_sw("vsync", "Synchronisation verticale", ""))
	c.add_child(_seg("fps_cap", "Limite d'images/s", "", ["Aucune", "30", "60", "120"]))
	return c


func _tab_game() -> Control:
	var c := _col()
	c.add_child(_group("Contrôles"))
	c.add_child(_sl("sensitivity", "Sensibilité de la souris", "", 0.2, 3.0, 0.05, "×%.2f"))
	c.add_child(_sw("invert_y", "Inverser l'axe vertical", ""))
	c.add_child(_sl("fov", "Champ de vision", "", 60.0, 100.0, 1.0, "%d°"))
	c.add_child(_group("Partie"))
	c.add_child(_sl("tension_gain", "Montée de la tension", "Plus haut : la police arrive plus vite.", 0.3, 2.0, 0.05, "×%.2f"))
	c.add_child(_sw("show_help", "Aide des commandes au départ", "Panneau en haut à gauche, replié au bout de quelques secondes (touche H)."))
	return c


func _tab_access() -> Control:
	var c := _col()
	c.add_child(_group("Confort"))
	c.add_child(_sw("head_bob", "Balancement de la caméra", "Désactive le ballant en 1re personne."))
	c.add_child(_sl("screen_shake", "Secousses d'écran", "Tirs, explosions, coups ; atténue aussi les flashs de bord d'écran.", 0.0, 1.0, 0.05, "%d %%", 100.0))
	c.add_child(_sl("gas_fx", "Effets de lacrymo et de coups", "Flou, double vision, flashs rouges. 0 % pour les supprimer (l'alerte « gaz » reste affichée).", 0.0, 1.0, 0.05, "%d %%", 100.0))
	return c


func _changed() -> void:
	Settings.apply(get_tree())
	_save_timer.start()


func _sync_controls() -> void:
	_syncing = true
	for k in _controls:
		var c: Dictionary = _controls[k]
		var ctl: Control = c["ctl"]
		if ctl is HSlider:
			(ctl as HSlider).value = float(Settings.d[k])
			(c["upd"] as Callable).call((ctl as HSlider).value)
		elif ctl is UiKit.Switch:
			(ctl as UiKit.Switch).on = bool(Settings.d[k])
		elif c.has("refresh"):
			(c["refresh"] as Callable).call()
	_syncing = false


# ------------------------------------------------------------------ commandes
func _build_controls() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_page_head("Commandes", null))
	var line := ColorRect.new()
	line.color = UiStyle.LINE
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 48)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var groups := [
		["DÉPLACEMENT", [[["Z", "Q", "S", "D"], "Marcher"], [["MAJ"], "Courir"], [["ESPACE"], "Sauter · se débattre"], [["C"], "S'accroupir"], [["V"], "Vue 1re / 3e personne"]]],
		["OUTILS", [[["1"], "Mortier d'artifice"], [["2"], "Pierres"], [["3"], "Briquet + déchets"], [["4"], "Fumigène"], [["5", "6"], "Petit / gros pétard"], [["MOLETTE"], "Changer d'outil"]]],
		["ACTIONS", [[["CLIC DROIT"], "Viser · brandir · allumer"], [["CLIC GAUCHE"], "Tirer · lancer · déposer"], [["F"], "Coup de pied"], [["E"], "Ouvrir · ramasser · redresser"], [["G"], "Appeler la foule"]]],
		["GESTES", [[["TAB"], "Roue des gestes"], [["B"], "Poing levé"], [["N"], "Applaudir"], [["X"], "Mains en l'air"], [["T"], "Doigt d'honneur"]]],
		["DIVERS", [[["H"], "Afficher / masquer l'aide"], [["R"], "Recharger (test)"], [["ÉCHAP"], "Menu pause"]]],
	]
	for g in groups:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 7)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gm := MarginContainer.new()
		gm.add_theme_constant_override("margin_top", 10)
		gm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gm.add_child(UiStyle.label(g[0], 12, UiStyle.RED.lightened(0.15), "caps"))
		col.add_child(gm)
		for it in (g[1] as Array):
			var r := HBoxContainer.new()
			r.add_theme_constant_override("separation", 12)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var keys := HBoxContainer.new()
			keys.custom_minimum_size = Vector2(150, 0)
			keys.add_theme_constant_override("separation", 4)
			keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for kk in (it[0] as Array):
				keys.add_child(UiStyle.keycap(kk, 15))
			r.add_child(keys)
			var l := UiStyle.label(it[1], 17, UiStyle.PAPER_DIM, "regular")
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			r.add_child(l)
			col.add_child(r)
		grid.add_child(col)
	return v


func _build_confirm() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(UiStyle.INK, 0.6)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(shade)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(cc)
	var p := PanelContainer.new()
	var st := UiStyle.print_shadow(UiStyle.box(UiStyle.INK, 6, Color(UiStyle.PAPER, 0.12), 1, 0.0), UiStyle.RED, Vector2(8, 8))
	st.content_margin_left = 34
	st.content_margin_right = 34
	st.content_margin_top = 26
	st.content_margin_bottom = 28
	p.add_theme_stylebox_override("panel", st)
	p.resized.connect(func(): p.pivot_offset = p.size * 0.5)
	cc.add_child(p)
	_confirm_card = p
	var v := VBoxContainer.new()
	v.name = "Box"
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(500, 0)
	p.add_child(v)
	var t := UiStyle.label("", 38, UiStyle.PAPER, "marker")
	t.name = "T"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UiStyle.label("", 17, UiStyle.PAPER_DIM)
	s.name = "S"
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(s)
	v.add_child(_gap(6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var no := UiKit.Btn.new("ANNULER")
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(func(): _click(); _confirm.visible = false)
	row.add_child(no)
	var yes := UiKit.Btn.new("OK", true)
	yes.name = "Yes"
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(func():
		_click()
		_confirm.visible = false
		if _confirm_cb.is_valid():
			_confirm_cb.call())
	row.add_child(yes)
	v.add_child(row)
	return c


func _ask(title_text: String, sub: String, ok: String, cb: Callable) -> void:
	(_confirm.find_child("T", true, false) as Label).text = title_text
	(_confirm.find_child("S", true, false) as Label).text = sub
	(_confirm.find_child("Yes", true, false) as Button).text = ok.to_upper()
	_confirm_cb = cb
	_confirm.visible = true
	_confirm.modulate.a = 0.0
	_confirm_card.scale = Vector2(0.94, 0.94)
	var tw := create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_confirm, "modulate:a", 1.0, 0.14)
	tw.tween_property(_confirm_card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	(_confirm.find_child("Yes", true, false) as Button).grab_focus()


func _restart() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()


# =================================================================== ouverture / fermeture
func show_page(p: String) -> void:
	var prev := _page
	_page = p
	_confirm.visible = false
	var on_main := p == "main"
	_main.visible = on_main
	_holder.visible = not on_main
	_shade.visible = not on_main
	for k in _pages:
		if k != "main":
			(_pages[k] as Control).visible = k == p
	if on_main:
		_refresh_stats()
		_main.modulate.a = 0.0
		_main.position.x = -30.0
		var tw := create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(_main, "modulate:a", 1.0, 0.22)
		tw.tween_property(_main, "position:x", 0.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var first := _main.find_children("*", "Button", true, false)
		if not first.is_empty():
			(first[0] as Button).grab_focus()
	else:
		_card.reset_size()
		_card.pivot_offset = _card.size * 0.5
		if prev != p:
			_card.modulate.a = 0.0
			_card.scale = Vector2(0.97, 0.97)
			var tw2 := create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw2.tween_property(_card, "modulate:a", 1.0, 0.18)
			tw2.tween_property(_card, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _back() -> void:
	if _from_title:
		close()
	else:
		show_page("main")


func _refresh_stats() -> void:
	var secs := int(_play_t)
	var peak := tension.max_value() if tension else 0.0
	var arr := police.arrested_count if police else 0
	var panes := 0
	if crowd and crowd.bus:
		panes = crowd.bus.broken_count()
	_stats.text = "Durée %d:%02d   ·   Tension max %d %%   ·   Interpellations %d   ·   Vitres brisées %d" % [secs / 60, secs % 60, int(peak * 100.0), arr, panes]


func open() -> void:
	if _open:
		return
	_open = true
	_from_title = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root.visible = true
	_root.modulate.a = 1.0
	_page = ""
	show_page("main")
	(_dim.material as ShaderMaterial).set_shader_parameter("amount", 0.0)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(func(v: float): (_dim.material as ShaderMaterial).set_shader_parameter("amount", v), 0.0, 1.0, 0.3)


## Ouvre directement une sous-page (réglages, commandes) depuis l'écran titre ; « Retour » y ramène
func open_from_title(p := "settings") -> void:
	_open = true
	_from_title = true
	_root.visible = true
	_root.modulate.a = 1.0
	_page = ""
	(_dim.material as ShaderMaterial).set_shader_parameter("amount", 0.0)
	show_page(p)
	_main.visible = false


func close() -> void:
	if not _open:
		return
	_open = false
	Settings.save_all()
	var from_title := _from_title
	_from_title = false
	var tw := create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_root, "modulate:a", 0.0, 0.16)
	tw.tween_method(func(v: float): (_dim.material as ShaderMaterial).set_shader_parameter("amount", v), (_dim.material as ShaderMaterial).get_shader_parameter("amount"), 0.0, 0.16)
	tw.chain().tween_callback(func():
		_root.visible = false
		_root.modulate.a = 1.0
		if from_title:
			if is_instance_valid(title):
				title.back_from_menu()
			return
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		resumed.emit())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if player != null and player.arrest_phase == "cuffed":
			return
		if is_instance_valid(title) and title.is_showing() and not _open:
			return
		get_viewport().set_input_as_handled()
		if _confirm.visible:
			_confirm.visible = false
		elif not _open:
			open()
		elif _page != "main":
			_back()
		else:
			close()


func _process(delta: float) -> void:
	if not _open:
		if not (is_instance_valid(title) and title.is_showing()):
			_play_t += delta
	elif _page == "main":
		_refresh_stats()
