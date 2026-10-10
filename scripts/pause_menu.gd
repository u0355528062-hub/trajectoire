class_name PauseMenu
extends CanvasLayer
## Menu Échap : pause du jeu, réglages (son, image, jeu, accessibilité), liste des commandes,
## recommencer / quitter. Verre sombre flouté, accent ambre, animations douces.

signal resumed

var player: Player
var tension: Tension
var police: Police
var crowd: Crowd

var _open := false
var _page := "main"
var _root: Control
var _dim: ColorRect
var _card: PanelContainer
var _holder: Control
var _pages := {}
var _tab_btns: Array = []
var _tab_pages: Array = []
var _play_t := 0.0
var _stats: Label
var _save_timer: Timer
var _confirm: Control
var _confirm_cb := Callable()
var _syncing := false
var _controls := {}                  # clé de réglage -> contrôle (pour la remise à zéro)


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
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


func is_open() -> bool:
	return _open


# =================================================================== construction
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	# fond : flou + assombrissement
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = textureLod(screen_tex, uv, 3.2 * amount).rgb;
	vec2 d = uv - 0.5;
	float v = smoothstep(0.25, 0.95, length(d * vec2(1.0, 0.8)));
	col = mix(col, col * vec3(0.32, 0.36, 0.5), 0.62 * amount);
	col *= 1.0 - v * 0.5 * amount;
	COLOR = vec4(col, 1.0);
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	_dim.material = sm
	_root.add_child(_dim)
	# carte centrale
	_holder = CenterContainer.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_holder)
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(560, 0)
	_card.add_theme_stylebox_override("panel", UiKit.style(UiKit.GLASS, 26, Color(1, 1, 1, 0.1), 1, 30.0, 40))
	_holder.add_child(_card)
	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(stack)
	_pages["main"] = _build_main()
	_pages["settings"] = _build_settings()
	_pages["controls"] = _build_controls()
	for k in _pages:
		(_pages[k] as Control).visible = false
	var vb := VBoxContainer.new()
	vb.name = "Pages"
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(vb)
	for k in _pages:
		vb.add_child(_pages[k])
	stack.queue_free()
	_confirm = _build_confirm()
	_root.add_child(_confirm)
	_confirm.visible = false


func _title_block(sub: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := Label.new()
	t.text = "BLOCUS"
	t.add_theme_font_override("font", UiKit.title_font())
	t.add_theme_font_size_override("font_size", 68)
	t.add_theme_color_override("font_color", Color(1.0, 0.93, 0.8))
	t.add_theme_color_override("font_outline_color", Color(0.85, 0.35, 0.1, 0.65))
	t.add_theme_constant_override("outline_size", 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var s := UiKit.label(sub, 14, UiKit.AMBER)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	return v


func _sep() -> Control:
	var c := ColorRect.new()
	c.color = UiKit.LINE
	c.custom_minimum_size = Vector2(0, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _click() -> void:
	AudioLib.play_at(self, "sfx:click", Vector3.ZERO, -14.0, 50.0, 1.3)


func _build_main() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_title_block("PAUSE"))
	v.add_child(_gap(10))
	var b_resume := UiKit.Btn.new("Reprendre", true)
	b_resume.pressed.connect(func(): _click(); close())
	v.add_child(b_resume)
	var b_set := UiKit.Btn.new("Réglages")
	b_set.pressed.connect(func(): _click(); show_page("settings"))
	v.add_child(b_set)
	var b_ctl := UiKit.Btn.new("Commandes")
	b_ctl.pressed.connect(func(): _click(); show_page("controls"))
	v.add_child(b_ctl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var b_re := UiKit.Btn.new("Recommencer")
	b_re.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_re.pressed.connect(func(): _click(); _ask("Recommencer la partie ?", "Tout repart de zéro : tension, foule et police.", "Recommencer", _restart))
	row.add_child(b_re)
	var b_q := UiKit.Btn.new("Quitter")
	b_q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_q.pressed.connect(func(): _click(); _ask("Quitter le jeu ?", "La partie en cours sera perdue.", "Quitter", func(): get_tree().quit()))
	row.add_child(b_q)
	v.add_child(row)
	v.add_child(_gap(4))
	v.add_child(_sep())
	_stats = UiKit.label("", 13, UiKit.MUTED)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_stats)
	var hint := UiKit.label("ÉCHAP pour reprendre", 12, Color(1, 1, 1, 0.35))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	return v


# ------------------------------------------------------------------ réglages
func _build_settings() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(640, 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := HBoxContainer.new()
	var back := UiKit.Btn.new("‹  Retour")
	back.custom_minimum_size = Vector2(120, 40)
	back.pressed.connect(func(): _click(); show_page("main"))
	head.add_child(back)
	var title := UiKit.label("RÉGLAGES", 22, UiKit.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var reset := UiKit.Btn.new("Par défaut")
	reset.custom_minimum_size = Vector2(120, 40)
	reset.pressed.connect(func():
		_click()
		Settings.reset()
		Settings.apply(get_tree())
		Settings.save_all()
		_sync_controls())
	head.add_child(reset)
	v.add_child(head)
	# onglets
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(tabs)
	var names := ["Son", "Image", "Jeu", "Accessibilité"]
	var pages: Array[Control] = [_tab_sound(), _tab_image(), _tab_game(), _tab_access()]
	var host := Control.new()
	host.custom_minimum_size = Vector2(0, 430)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in names.size():
		var b := UiKit.Btn.new(names[i])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(130, 38)
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
		(_tab_pages[k] as Control).visible = k == i


func _col() -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 8)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	return c


func _sl(key: String, title: String, hint: String, lo: float, hi: float, step: float, fmt: String, scale := 1.0) -> Control:
	var s := UiKit.slider(lo, hi, step, float(Settings.d[key]))
	var vl := UiKit.label("", 14, UiKit.AMBER)
	var upd := func(v: float): vl.text = fmt % (v * scale)
	upd.call(s.value)
	s.value_changed.connect(func(v: float):
		upd.call(v)
		if _syncing:
			return
		Settings.d[key] = v
		_changed())
	_controls[key] = {"ctl": s, "upd": upd}
	return UiKit.row(title, hint, s, vl)


func _sw(key: String, title: String, hint: String) -> Control:
	var sw := UiKit.Switch.new(bool(Settings.d[key]))
	sw.toggled.connect(func(on: bool):
		if _syncing:
			return
		Settings.d[key] = on
		_click()
		_changed())
	_controls[key] = {"ctl": sw}
	return UiKit.row(title, hint, sw)


func _seg(key: String, title: String, hint: String, options: Array) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var btns: Array[Button] = []
	for i in options.size():
		var b := UiKit.Btn.new(options[i])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 36)
		b.add_theme_font_size_override("font_size", 14)
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
	return UiKit.row(title, hint, box)


func _tab_sound() -> Control:
	var c := _col()
	c.add_child(_sl("master", "Volume général", "", 0.0, 1.0, 0.01, "%d %%", 100.0))
	c.add_child(_sl("effects", "Effets", "Pas, explosions, feu, vitres, véhicules.", 0.0, 1.0, 0.01, "%d %%", 100.0))
	c.add_child(_sl("voices", "Voix", "Manifestants, policiers, mégaphones.", 0.0, 1.0, 0.01, "%d %%", 100.0))
	c.add_child(_sl("ambience", "Ambiance de foule", "Chants, murmure, applaudissements.", 0.0, 1.0, 0.01, "%d %%", 100.0))
	return c


func _tab_image() -> Control:
	var c := _col()
	c.add_child(_seg("quality", "Qualité", "Préréglage ; les options ci-dessous peuvent être ajustées une à une.", Settings.QUALITY_NAMES))
	c.add_child(_sl("render_scale", "Échelle de rendu", "Baisse pour gagner en fluidité (reconstruction FSR).", 0.5, 1.0, 0.05, "%d %%", 100.0))
	c.add_child(_seg("msaa", "Anti-crénelage", "", ["Aucun", "2x", "4x"]))
	c.add_child(_seg("smoke_q", "Fumées (gaz, feux, fumigènes)", "Le plus gros coût quand il y a beaucoup de fumée. S'applique aux nouvelles fumées.", ["Basse", "Moyenne", "Haute"]))
	c.add_child(_sw("shadows", "Ombres", "Le soleil couchant projette de longues ombres."))
	c.add_child(_sw("ssao", "Occlusion ambiante", "Ombrage doux dans les recoins."))
	c.add_child(_sw("ssil", "Éclairage indirect", "Lumière rebondie (plus coûteux)."))
	c.add_child(_sw("ssr", "Réflexions", "Sol mouillé, vitres, carrosseries."))
	c.add_child(_sw("volfog", "Brouillard volumétrique", "Faisceaux et brume dans la lumière."))
	c.add_child(_sw("glow", "Halo lumineux", "Flammes, gyrophares, fumigènes."))
	c.add_child(_sl("brightness", "Luminosité", "", 0.6, 1.5, 0.01, "%d %%", 100.0))
	c.add_child(_sw("fullscreen", "Plein écran", ""))
	c.add_child(_sw("vsync", "Synchronisation verticale", ""))
	c.add_child(_seg("fps_cap", "Limite d'images/s", "", ["Aucune", "30", "60", "120"]))
	return c


func _tab_game() -> Control:
	var c := _col()
	c.add_child(_sl("sensitivity", "Sensibilité de la souris", "", 0.2, 3.0, 0.05, "×%.2f"))
	c.add_child(_sw("invert_y", "Inverser l'axe vertical", ""))
	c.add_child(_sl("fov", "Champ de vision", "", 60.0, 100.0, 1.0, "%d°"))
	c.add_child(_sl("tension_gain", "Montée de la tension", "Plus haut : la police arrive plus vite.", 0.3, 2.0, 0.05, "×%.2f"))
	c.add_child(_sw("show_help", "Aide des commandes au départ", "Panneau en haut à gauche pendant 14 s."))
	return c


func _tab_access() -> Control:
	var c := _col()
	c.add_child(_sw("head_bob", "Balancement de la caméra", "Désactive le ballant en 1re personne."))
	c.add_child(_sl("screen_shake", "Secousses d'écran", "Tirs, explosions, coups.", 0.0, 1.0, 0.05, "%d %%", 100.0))
	c.add_child(_sl("gas_fx", "Effets de lacrymo et de coups", "Flou, double vision, flashs rouges. 0 % pour les supprimer.", 0.0, 1.0, 0.05, "%d %%", 100.0))
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
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(640, 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := HBoxContainer.new()
	var back := UiKit.Btn.new("‹  Retour")
	back.custom_minimum_size = Vector2(120, 40)
	back.pressed.connect(func(): _click(); show_page("main"))
	head.add_child(back)
	var title := UiKit.label("COMMANDES", 22, UiKit.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(120, 0)
	head.add_child(spacer)
	v.add_child(head)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 470)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(col)
	v.add_child(sc)
	var groups := [
		["DÉPLACEMENT", [[["Z", "Q", "S", "D"], "Marcher"], [["MAJ"], "Courir"], [["ESPACE"], "Sauter · se débattre quand on t'arrête"], [["C"], "S'accroupir"], [["V"], "Vue 1re / 3e personne"]]],
		["OUTILS", [[["1"], "Mortier d'artifice"], [["2"], "Pierres"], [["3"], "Briquet + déchets"], [["4"], "Fumigène"], [["5"], "Petit pétard"], [["6"], "Gros pétard"], [["MOLETTE"], "Changer d'outil"]]],
		["ACTIONS", [[["CLIC DROIT"], "Viser · brandir · allumer le briquet"], [["CLIC GAUCHE"], "Tirer · lancer · déposer"], [["F"], "Coup de pied (vitres, poubelles, barrières, grenades)"], [["E"], "Ouvrir une poubelle · ramasser · redresser"], [["G"], "Appeler la foule à casser l'abribus"]]],
		["GESTES", [[["B"], "Poing levé"], [["N"], "Applaudir"], [["X"], "Mains en l'air"]]],
		["DIVERS", [[["R"], "Recharger (test)"], [["H"], "Masquer l'aide"], [["ÉCHAP"], "Menu pause"]]],
	]
	for g in groups:
		var gl := UiKit.label(g[0], 12, UiKit.AMBER)
		col.add_child(_gap(4))
		col.add_child(gl)
		for it in (g[1] as Array):
			var r := HBoxContainer.new()
			r.add_theme_constant_override("separation", 6)
			var keys := HBoxContainer.new()
			keys.custom_minimum_size = Vector2(250, 0)
			keys.add_theme_constant_override("separation", 5)
			for kk in (it[0] as Array):
				keys.add_child(UiKit.keycap(kk))
			r.add_child(keys)
			r.add_child(UiKit.label(it[1], 14, UiKit.TEXT))
			col.add_child(r)
	return v


func _build_confirm() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.5)
	c.add_child(shade)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.style(Color(0.06, 0.065, 0.1, 0.97), 20, Color(1, 0.72, 0.28, 0.4), 1, 26.0, 30))
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.name = "Box"
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(420, 0)
	p.add_child(v)
	var t := UiKit.label("", 22, UiKit.TEXT)
	t.name = "T"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UiKit.label("", 14, UiKit.MUTED)
	s.name = "S"
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var no := UiKit.Btn.new("Annuler")
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


func _ask(title: String, sub: String, ok: String, cb: Callable) -> void:
	(_confirm.find_child("T", true, false) as Label).text = title
	(_confirm.find_child("S", true, false) as Label).text = sub
	(_confirm.find_child("Yes", true, false) as Button).text = ok
	_confirm_cb = cb
	_confirm.visible = true
	(_confirm.find_child("Yes", true, false) as Button).grab_focus()


func _restart() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()


# =================================================================== ouverture / fermeture
func show_page(p: String) -> void:
	_page = p
	for k in _pages:
		(_pages[k] as Control).visible = k == p
	_confirm.visible = false
	_card.custom_minimum_size = Vector2(700 if p != "main" else 560, 0)
	_card.reset_size()
	if p == "main":
		_refresh_stats()
		var first := (_pages["main"] as Control).find_children("*", "Button", true, false)
		if not first.is_empty():
			(first[0] as Button).grab_focus()


func _refresh_stats() -> void:
	var secs := int(_play_t)
	var peak := tension.max_value() if tension else 0.0
	var arr := police.arrested_count if police else 0
	var panes := 0
	if crowd and crowd.bus:
		panes = crowd.bus.broken_count()
	_stats.text = "Durée %d:%02d   ·   Tension maximale %d %%   ·   Interpellations %d   ·   Vitres brisées %d" % [secs / 60, secs % 60, int(peak * 100.0), arr, panes]


func open() -> void:
	if _open:
		return
	_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root.visible = true
	show_page("main")
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.96, 0.96)
	_card.pivot_offset = _card.size * 0.5
	(_dim.material as ShaderMaterial).set_shader_parameter("amount", 0.0)
	var tw := create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_card, "modulate:a", 1.0, 0.22)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): (_dim.material as ShaderMaterial).set_shader_parameter("amount", v), 0.0, 1.0, 0.3)


func close() -> void:
	if not _open:
		return
	_open = false
	Settings.save_all()
	var tw := create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_card, "modulate:a", 0.0, 0.14)
	tw.tween_method(func(v: float): (_dim.material as ShaderMaterial).set_shader_parameter("amount", v), 1.0, 0.0, 0.14)
	tw.chain().tween_callback(func():
		_root.visible = false
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		resumed.emit())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if player != null and player.arrest_phase == "cuffed":
			return
		get_viewport().set_input_as_handled()
		if _confirm.visible:
			_confirm.visible = false
		elif not _open:
			open()
		elif _page != "main":
			show_page("main")
		else:
			close()


func _process(delta: float) -> void:
	if not _open:
		_play_t += delta
	elif _page == "main":
		_refresh_stats()
