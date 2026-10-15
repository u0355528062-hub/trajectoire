class_name DialogueUI
extends CanvasLayer
## Dialogues de l'histoire : interprète les arbres de dialogue (format : docs/CAMPAGNE.md § « Format des dialogues »),
## affiche les répliques sous-titrées (nom du personnage à sa couleur CastLooks, texte qui apparaît mot à mot),
## joue la voix si elle existe (res://assets/voice/<_id>/<id de réplique>.ogg — la réplique dure alors le temps
## de la voix), fait parler le personnage (bouche, tête, mains ; les autres le regardent) et présente les choix
## (souris, touches 1-4 ou flèches + Entrée, minuteur visible). Clic, Espace ou E : passer à la suite.
## Les « barks » (répliques courtes, non bloquantes) s'affichent au-dessus de la tête du personnage.
## Pilote automatique (Campaign.autoplay) : répliques quasi instantanées, choix par Campaign.auto_pick.

signal line_done
signal choice_made(index: int)
signal frame                      # émis à chaque image (attentes des répliques et des choix)

const VO_BUS := "VoixRecit"       # bus des voix enregistrées (analyseur de niveau pour la synchro labiale)
const SUB_W := 0.62               # largeur des sous-titres (fraction de l'écran)

var director: ChapterDirector
var _root: Control
var _band: TextureRect            # dégradé sombre en bas d'écran, sous les sous-titres
var _sub: VBoxContainer
var _name: Label
var _text: Label
var _prog: ColorRect
var _barks_box: VBoxContainer
var _choice_root: VBoxContainer
var _prompt: Label
var _rows: Array[DialogueChoice] = []
var _timer_bar: ColorRect
var _vo: AudioStreamPlayer
var _choice := -1
var _choosing := false
var _hot := -1
var _skip := false
var _line_on := false
var _sub_hold := false            # la dernière réplique reste affichée pendant le choix qui suit
var _hold_t := 0.0
var _sub_y := 0.87                # bas des sous-titres (plus haut en jeu, au-dessus de la barre d'outils)
var _line_serial := 0
var _band_a := 0.0
var _sub_a := 0.0
var _sam_env: Array = []          # synchro labiale de Sam (le joueur)
var _sam_t := -1.0
var _barks: Array = []            # [{node, t, life}]
var _analyzer: AudioEffectSpectrumAnalyzerInstance


func bind(d: ChapterDirector) -> void:
	director = d


func _ready() -> void:
	layer = 36
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	# voile bas d'écran
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(UiStyle.INK, 0.72))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	_band = TextureRect.new()
	_band.texture = gt
	_band.stretch_mode = TextureRect.STRETCH_SCALE
	_band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_band.anchor_left = 0.0
	_band.anchor_right = 1.0
	_band.anchor_top = 0.6
	_band.anchor_bottom = 1.0
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.modulate.a = 0.0
	_root.add_child(_band)
	# sous-titre : nom (couleur du personnage), texte, fil de progression
	_sub = VBoxContainer.new()
	_sub.anchor_left = 0.5 - SUB_W * 0.5
	_sub.anchor_right = 0.5 + SUB_W * 0.5
	_sub.anchor_top = 0.87
	_sub.anchor_bottom = 0.87
	_sub.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sub.alignment = BoxContainer.ALIGNMENT_END
	_sub.add_theme_constant_override("separation", 4)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.modulate.a = 0.0
	_root.add_child(_sub)
	_name = UiStyle.ink_outline(UiStyle.label("", 15, UiStyle.PAPER, "caps"), 5, 0.8)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_child(_name)
	_text = UiStyle.ink_outline(UiStyle.label("", 26, UiStyle.PAPER, "semibold"), 8, 0.85)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_sub.add_child(_text)
	var pw := Control.new()
	pw.custom_minimum_size = Vector2(0, 8)
	pw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.add_child(pw)
	_prog = ColorRect.new()
	_prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prog.anchor_left = 0.5
	_prog.anchor_right = 0.5
	_prog.offset_top = 5
	_prog.offset_bottom = 7
	pw.add_child(_prog)
	# barks sans personnage visible : petites lignes au-dessus des sous-titres
	_barks_box = VBoxContainer.new()
	_barks_box.anchor_left = 0.5 - SUB_W * 0.5
	_barks_box.anchor_right = 0.5 + SUB_W * 0.5
	_barks_box.anchor_top = 0.66
	_barks_box.anchor_bottom = 0.66
	_barks_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_barks_box.alignment = BoxContainer.ALIGNMENT_END
	_barks_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_barks_box)
	# choix
	_choice_root = VBoxContainer.new()
	_choice_root.anchor_left = 0.5
	_choice_root.anchor_right = 0.5
	_choice_root.anchor_top = 0.84
	_choice_root.anchor_bottom = 0.84
	_choice_root.offset_left = -300
	_choice_root.offset_right = 300
	_choice_root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choice_root.alignment = BoxContainer.ALIGNMENT_END
	_choice_root.add_theme_constant_override("separation", 8)
	_choice_root.visible = false
	_root.add_child(_choice_root)
	_vo = AudioStreamPlayer.new()
	_vo.bus = _vo_bus()
	add_child(_vo)


## Bus des voix enregistrées : envoyé vers « Voix » (réglage du volume), avec un analyseur de niveau
func _vo_bus() -> StringName:
	var i := AudioServer.get_bus_index(VO_BUS)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, VO_BUS)
		AudioServer.set_bus_send(i, &"Voix" if AudioServer.get_bus_index("Voix") >= 0 else &"Master")
		var an := AudioEffectSpectrumAnalyzer.new()
		an.buffer_length = 0.1
		AudioServer.add_bus_effect(i, an)
	if AudioServer.get_bus_effect_count(i) > 0:
		_analyzer = AudioServer.get_bus_effect_instance(i, 0) as AudioEffectSpectrumAnalyzerInstance
	return StringName(VO_BUS)


# ------------------------------------------------------------------ identités
## Nom affiché d'un personnage
static func display_name(who: String) -> String:
	return str(CastLooks.look(who).get("name", who.capitalize()))


## Couleur du nom dans les sous-titres
static func name_color(who: String) -> Color:
	var c: Variant = CastLooks.look(who).get("color", UiStyle.PAPER)
	return c if c is Color else UiStyle.PAPER


## Identifiant de réplique (sert au nom du fichier de voix) : "<nœud>_<index>" ; choix : "<nœud>_<index>_c<k>"
static func line_id(node: String, idx: int, choice := -1) -> String:
	return "%s_%d" % [node, idx] if choice < 0 else "%s_%d_c%d" % [node, idx, choice]


static func voice_path(dlg_id: String, lid: String) -> String:
	return "res://assets/voice/%s/%s.ogg" % [dlg_id, lid]


## Durée de lecture d'une réplique sans voix enregistrée (s)
static func read_time(text: String) -> float:
	return clampf(0.9 + text.length() * 0.052, 1.6, 9.0)


# ------------------------------------------------------------------ répliques
## Une réplique : sous-titre, voix éventuelle (opts.vo = chemin), le personnage parle ; attend la fin.
## opts : "anim" (geste), "look" (cible du regard : id de personnage, "sam", id de lieu), "wait" (pause après),
## "keep" (le sous-titre reste affiché, atténué, jusqu'au choix suivant).
func play_line(who: String, text: String, opts := {}) -> void:
	if text.strip_edges() == "":
		return
	_line_serial += 1
	var my := _line_serial
	var auto := Campaign.autoplay
	var stream: AudioStream = null
	var vo := str(opts.get("vo", ""))
	if vo != "" and not auto and ResourceLoader.exists(vo):
		stream = load(vo) as AudioStream
	var speak := read_time(text)
	var total := speak
	if stream:
		speak = maxf(stream.get_length(), 0.3) + 0.12
		total = maxf(speak, 0.6 + text.length() * 0.04)
	if auto:
		speak = 0.02
		total = 0.02
	var reveal := speak * 0.85 if stream else minf(speak * 0.7, text.length() / 28.0)
	# mise en scène : le personnage parle, regarde, les autres le regardent
	var a := _actor(who)
	var node := _node_of(who)
	if a:
		a.talk(speak, text)
		if opts.has("anim") and str(opts["anim"]) != "":
			a.gesture(str(opts["anim"]), maxf(speak, 1.6))
	elif who == "sam" and node:
		_sam_env = DialogueLip.envelope(text, speak)
		_sam_t = 0.0
	_stage_looks(who, node, opts.get("look", null), total + 2.5)
	# sous-titre
	_sub_hold = false
	_show_line(who, text)
	if stream:
		_vo.stop()
		_vo.stream = stream
		_vo.play()
	_skip = false
	_line_on = true
	var t := 0.0
	while _line_serial == my:
		await frame
		t += get_process_delta_time()
		if _skip:
			_skip = false
			if _text.visible_characters >= 0 and not auto:
				reveal = 0.0
				_text.visible_characters = -1
			else:
				break
		if reveal > 0.0 and _text.visible_characters >= 0:
			var vc := DialogueLip.visible_chars(text, t / reveal)
			_text.visible_characters = -1 if vc >= text.length() else vc
		_prog.anchor_left = 0.5 - 0.5 * clampf(t / total, 0.0, 1.0)
		_prog.anchor_right = 0.5 + 0.5 * clampf(t / total, 0.0, 1.0)
		if stream and a:
			a.live_amp = _voice_level()
		if t >= total:
			break
	if _line_serial != my:
		return
	_line_on = false
	if stream and _vo.playing:
		_vo.stop()
	if a and is_instance_valid(a):
		a.stop_talk()
	_sam_t = -1.0
	_sub_hold = bool(opts.get("keep", false)) and not auto
	_hide_line()
	var w := float(opts.get("wait", 0.0))
	if w > 0.0:
		await director.sleep(w * (0.1 if auto else 1.0))
	line_done.emit()


func _show_line(who: String, text: String) -> void:
	var narr := who == "narrateur"
	var nm := "" if narr else display_name(who)
	_name.text = nm.to_upper()
	_name.visible = nm != ""
	_name.add_theme_color_override("font_color", name_color(who))
	_text.text = text
	_text.visible_characters = 0
	_text.add_theme_color_override("font_color", UiStyle.PAPER_DIM if narr else UiStyle.PAPER)
	_text.add_theme_font_override("font", UiStyle.font("regular" if narr else "semibold"))
	_prog.color = Color(name_color(who), 0.75)
	_prog.anchor_left = 0.5
	_prog.anchor_right = 0.5


func _hide_line() -> void:
	_text.visible_characters = -1


## Le personnage qui parle regarde son interlocuteur (« look », sinon Sam s'il est près) ; ceux qui sont autour
## le regardent
func _stage_looks(who: String, node: Node3D, look: Variant, sec: float) -> void:
	if director == null or director.cast == null or node == null:
		return
	var a := _actor(who)
	var tgt: Node3D = null
	if look != null and str(look) != "":
		tgt = _node_of(str(look))
		if tgt == null and a and Quartier.SPOTS.has(str(look)):
			a.face_target(Quartier.spot(str(look)))
	elif a and director.player and is_instance_valid(director.player) and a.global_position.distance_to(director.player.global_position) < 8.0:
		tgt = director.player
	if a and tgt and tgt != a:
		var to := tgt.global_position - a.global_position
		var turn := Vector2(to.x, to.z).length() > 0.3 and a.forward().dot(Vector3(to.x, 0, to.z).normalized()) < 0.2 and not a.has_goal
		a.look_at_node(tgt, sec, turn)
	for id in director.cast.actors:
		var o := director.cast.get_actor(id)
		if o and o != a and o.global_position.distance_to(node.global_position) < 9.0 and not o.talking():
			o.look_at_node(node, sec)


func _actor(who: String) -> StoryActor:
	return director.cast.get_actor(who) if director and director.cast else null


## Nœud d'un locuteur ou d'une cible : personnage d'histoire, ou le joueur pour "sam" / "player"
func _node_of(who: String) -> Node3D:
	if who == "sam" or who == "player":
		var p: Player = director.player if director else null
		return p if p and is_instance_valid(p) else null
	return _actor(who)


## Niveau de la voix enregistrée en cours (0..1), pour la bouche
func _voice_level() -> float:
	if _analyzer == null or not _vo.playing:
		return -1.0
	var m := _analyzer.get_magnitude_for_frequency_range(150.0, 3500.0).length()
	if m <= 0.0:
		return -1.0
	return clampf((linear_to_db(m) + 52.0) / 34.0, 0.0, 1.0)


## Réplique courte non bloquante : au-dessus de la tête du personnage s'il est là et assez près de la caméra,
## sinon en petite ligne discrète au-dessus des sous-titres
func bark(who: String, text: String) -> void:
	if text.strip_edges() == "":
		return
	var life := clampf(1.8 + text.length() * 0.05, 2.2, 5.5) * (0.05 if Campaign.autoplay else 1.0)
	var node := _node_of(who)
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if node and cam and cam.global_position.distance_to(node.global_position) < 28.0:
		var l := Label3D.new()
		l.text = text
		l.font = UiStyle.font("semibold")
		l.font_size = 40
		l.outline_size = 10
		l.outline_modulate = Color(UiStyle.INK, 0.85)
		l.modulate = Color(UiStyle.PAPER, 0.0)
		l.pixel_size = 0.0032
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = false
		l.width = 420.0
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.render_priority = 5
		l.outline_render_priority = 4
		l.position = Vector3(0, 2.2, 0)
		node.add_child(l)
		_barks.append({"node": l, "t": 0.0, "life": life})
		var a := _actor(who)
		if a and not a.talking():
			a.talk(minf(life * 0.6, 3.0), text)
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.modulate.a = 0.0
	var nm := display_name(who) if who != "narrateur" else ""
	if nm != "":
		row.add_child(UiStyle.ink_outline(UiStyle.label(nm.to_upper(), 12, name_color(who), "caps"), 4, 0.8))
	var tl := UiStyle.ink_outline(UiStyle.label(text, 17, UiStyle.PAPER_DIM, "regular"), 5, 0.8)
	row.add_child(tl)
	_barks_box.add_child(row)
	while _barks_box.get_child_count() > 3:
		_barks_box.get_child(0).free()
	_barks.append({"node": row, "t": 0.0, "life": life})


# ------------------------------------------------------------------ choix
## Choix : renvoie l'index de l'option retenue (minuteur > 0 : option 0 à l'expiration)
func choose(prompt: String, options: Array, timer := 0.0) -> int:
	if Campaign.autoplay:
		await director.sleep(0.02)
		var k := Campaign.auto_pick(options.size())
		choice_made.emit(k)
		return k
	if options.is_empty():
		return -1
	for c in _choice_root.get_children():
		c.free()
	_rows.clear()
	if prompt != "":
		_prompt = UiStyle.ink_outline(UiStyle.label(prompt.to_upper(), 14, UiStyle.PAPER_DIM, "caps"), 5, 0.8)
		_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_choice_root.add_child(_prompt)
	for i in options.size():
		var r := DialogueChoice.new()
		r.setup(i, str(options[i]))
		r.picked.connect(func(k: int) -> void: _pick(k))
		r.mouse_entered.connect(func() -> void: _set_hot(i))
		_choice_root.add_child(r)
		_rows.append(r)
	var tw := Control.new()
	tw.custom_minimum_size = Vector2(0, 6)
	tw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_root.add_child(tw)
	_timer_bar = ColorRect.new()
	_timer_bar.color = UiStyle.RED
	_timer_bar.anchor_right = 1.0
	_timer_bar.offset_top = 2
	_timer_bar.offset_bottom = 5
	_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_bar.visible = timer > 0.0
	tw.add_child(_timer_bar)
	var top := _sub_y - (0.16 if (_sub_hold or _line_on) else 0.02)
	_choice_root.anchor_top = top
	_choice_root.anchor_bottom = top
	_choice_root.visible = true
	_choice_root.modulate.a = 0.0
	_choice = -1
	_hot = -1
	_choosing = true
	var prev := Input.mouse_mode
	var t := 0.0
	while _choice < 0:
		await frame
		var dt := get_process_delta_time()
		t += dt
		_choice_root.modulate.a = minf(_choice_root.modulate.a + dt * 5.0, 1.0)
		if not get_tree().paused and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if timer > 0.0:
			var left := clampf(1.0 - t / timer, 0.0, 1.0)
			_timer_bar.anchor_left = 0.5 - 0.5 * left
			_timer_bar.anchor_right = 0.5 + 0.5 * left
			_timer_bar.color = UiStyle.RED.lerp(UiStyle.YELLOW, 0.5 + 0.5 * sin(t * 9.0)) if left < 0.25 else UiStyle.RED
			if t >= timer:
				_choice = 0
	_choosing = false
	_sub_hold = false
	var picked := _choice
	if picked < _rows.size():
		_rows[picked].flash()
	await director.sleep(0.22)
	_choice_root.visible = false
	for c in _choice_root.get_children():
		c.queue_free()
	_rows.clear()
	if not get_tree().paused:
		Input.mouse_mode = prev if prev != Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_CAPTURED
	choice_made.emit(picked)
	return picked


## Passe à la suite : affiche toute la réplique, ou la termine si elle est déjà entière (clic, Espace, E)
func advance() -> void:
	if _line_on:
		_skip = true


## Une réplique ou un choix est-il à l'écran ?
func busy() -> bool:
	return _line_on or _choosing


func _pick(k: int) -> void:
	if _choosing and _choice < 0 and k >= 0 and k < _rows.size():
		_choice = k


func _set_hot(i: int) -> void:
	_hot = i
	for r in _rows:
		r.set_hot(r.index == i)


func _unhandled_input(e: InputEvent) -> void:
	if _choosing:
		if e is InputEventKey and e.pressed and not e.echo:
			var k := (e as InputEventKey).physical_keycode
			var n := _rows.size()
			if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < n:
				_pick(k - KEY_1)
			elif k >= KEY_KP_1 and k <= KEY_KP_9 and k - KEY_KP_1 < n:
				_pick(k - KEY_KP_1)
			elif k == KEY_UP or k == KEY_W or k == KEY_Z:
				_set_hot(posmod(_hot - 1, n) if _hot >= 0 else n - 1)
			elif k == KEY_DOWN or k == KEY_S:
				_set_hot(posmod(_hot + 1, n) if _hot >= 0 else 0)
			elif (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE or k == KEY_E) and _hot >= 0:
				_pick(_hot)
			else:
				return
			get_viewport().set_input_as_handled()
		elif e is InputEventMouseButton:
			get_viewport().set_input_as_handled()   # pas de tir ni de capture de souris pendant un choix
		return
	if not _line_on:
		return
	var adv := false
	var consume := false
	if e is InputEventKey and e.pressed and not e.echo:
		var k2 := (e as InputEventKey).physical_keycode
		if k2 == KEY_SPACE or k2 == KEY_ENTER:
			adv = true
			consume = _cine_on()
		elif k2 == KEY_E:
			adv = true
			consume = true
	elif e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		adv = true
		consume = _cine_on()
	if adv:
		_skip = true
		if consume:
			get_viewport().set_input_as_handled()


func _cine_on() -> bool:
	return director != null and director.cine != null and director.cine.active


# ------------------------------------------------------------------ boucle
func _process(delta: float) -> void:
	# apparition / disparition douce du sous-titre et du voile
	if _sub_hold and not _choosing:
		_hold_t += delta
		if _hold_t > 1.0:
			_sub_hold = false        # aucun choix n'a suivi : on n'oublie pas le sous-titre à l'écran
	else:
		_hold_t = 0.0
	var y := 0.87 if _cine_on() else 0.8
	if not is_equal_approx(_sub_y, y):
		_sub_y = move_toward(_sub_y, y, delta * 0.4)
		_sub.anchor_top = _sub_y
		_sub.anchor_bottom = _sub_y
		_barks_box.anchor_top = _sub_y - 0.21
		_barks_box.anchor_bottom = _sub_y - 0.21
	var want := 1.0 if _line_on else (0.8 if _sub_hold else 0.0)
	_sub_a = move_toward(_sub_a, want, delta * (8.0 if _line_on else 5.0))
	_sub.modulate.a = _sub_a
	_band_a = move_toward(_band_a, 1.0 if (_line_on or _choosing or _sub_hold) else 0.0, delta * 3.0)
	_band.modulate.a = _band_a
	if not _line_on and not _sub_hold and _sub_a <= 0.0 and _text.text != "":
		_text.text = ""
	# bouche de Sam
	if _sam_t >= 0.0:
		_sam_t += delta
		var p: Player = director.player if director else null
		if p and is_instance_valid(p) and p.human:
			p.human.jaw = lerpf(p.human.jaw, AudioLib.env_at(_sam_env, _sam_t) * 0.6, minf(1.0, delta * 18.0))
	elif director and director.player and is_instance_valid(director.player) and director.player.human and director.player.human.jaw > 0.0:
		var h := director.player.human
		h.jaw = maxf(h.jaw - delta * 3.0, 0.0)
	# barks
	var i := _barks.size() - 1
	while i >= 0:
		var b: Dictionary = _barks[i]
		var n: Variant = b["node"]
		b["t"] = float(b["t"]) + delta
		var t: float = b["t"]
		var life: float = b["life"]
		if not is_instance_valid(n) or t >= life:
			if is_instance_valid(n):
				(n as Node).queue_free()
			_barks.remove_at(i)
		else:
			var a := minf(t / 0.2, 1.0) * minf((life - t) / 0.4, 1.0)
			if n is Label3D:
				(n as Label3D).modulate.a = a
				(n as Label3D).outline_modulate.a = a * 0.85
				(n as Label3D).position.y = 2.2 + 0.06 * minf(t / 0.3, 1.0)
			else:
				(n as Control).modulate.a = a
		i -= 1
	frame.emit()


# ------------------------------------------------------------------ interprète
## Joue l'arbre `dlg` depuis le nœud `node` ; renvoie l'"id" du dernier choix fait
func run(dlg: Dictionary, node := "start") -> String:
	var dlg_id := str(dlg.get("_id", "dlg"))
	var last := ""
	var cur := node
	var guard := 0
	while cur != "" and guard < 200:
		guard += 1
		if not dlg.has(cur) or not (dlg[cur] is Array):
			push_error("Dialogue %s : nœud inconnu « %s »" % [dlg_id, cur])
			return last
		var steps: Array = dlg[cur]
		var next := ""
		var i := 0
		while i < steps.size():
			var s: Dictionary = steps[i]
			if s.has("if") and not s.has("goto") and not cond(s["if"]):
				i += 1
				continue
			if s.has("text"):
				var who := str(s.get("who", "narrateur"))
				var o: Dictionary = s.duplicate()
				var vp := voice_path(dlg_id, line_id(cur, i))
				if ResourceLoader.exists(vp):
					o["vo"] = vp
				if i + 1 < steps.size() and steps[i + 1] is Dictionary and (steps[i + 1] as Dictionary).has("choice"):
					o["keep"] = true
				_apply(s)
				await play_line(who, str(s["text"]), o)
			elif s.has("choice"):
				var opts: Array = (s["choice"] as Array).filter(func(c): return not c.has("if") or cond(c["if"]))
				if opts.is_empty():
					i += 1
					continue
				var labels := opts.map(func(c): return str(c.get("text", "…")))
				var k := await choose(str(s.get("prompt", "")), labels, float(s.get("timer", 0.0)))
				var c: Dictionary = opts[clampi(k, 0, opts.size() - 1)]
				last = str(c.get("id", c.get("text", "")))
				_apply(c)
				if c.has("say"):
					var full_k: int = (s["choice"] as Array).find(c)
					var o2 := {"vo": voice_path(dlg_id, line_id(cur, i, full_k))}
					if not ResourceLoader.exists(o2["vo"]):
						o2.erase("vo")
					if c.has("anim"):
						o2["anim"] = c["anim"]
					await play_line("sam", str(c["say"]), o2)
				if c.has("goto"):
					next = str(c["goto"])
					break
			elif s.has("goto"):
				if not s.has("if") or cond(s["if"]):
					next = str(s["goto"])
					break
				elif s.has("else"):
					next = str(s["else"])
					break
			elif s.has("end"):
				_release_looks()
				return last
			elif s.has("call"):
				var m := str(s["call"])
				if director.script_obj and director.script_obj.has_method(m):
					await director.script_obj.call(m)
				else:
					push_error("Dialogue %s : méthode « %s » absente du chapitre" % [dlg_id, m])
			elif s.has("wait") and s.size() == 1:
				await director.sleep(float(s["wait"]) * (0.1 if Campaign.autoplay else 1.0))
			else:
				_apply(s)
				if s.has("wait"):
					await director.sleep(float(s["wait"]) * (0.1 if Campaign.autoplay else 1.0))
			i += 1
		cur = next
	_release_looks()
	return last


## Fin de dialogue : les regards se relâchent doucement (sauf consignes en cours du script)
func _release_looks() -> void:
	if director == null or director.cast == null:
		return
	for id in director.cast.actors:
		var a := director.cast.get_actor(id)
		if a and a._look_node != null and a._look_until > 0.0:
			a._look_until = minf(a._look_until, 1.2)


## Effets d'une étape ou d'une option : set (drapeaux), stats (jauges), rel (relations), news
func _apply(s: Dictionary) -> void:
	for k in (s.get("set", {}) as Dictionary):
		Campaign.set_flag(k, s["set"][k])
	for k in (s.get("stats", {}) as Dictionary):
		Campaign.add_stat(k, float(s["stats"][k]), "dialogue")
	for k in (s.get("rel", {}) as Dictionary):
		Campaign.rel_add(k, int(s["rel"][k]))
	if s.has("news") and director and director.news:
		director.news.push(str(s["news"]))


# ------------------------------------------------------------------ conditions
const _OPS := [">=", "<=", "==", "!=", ">", "<"]


## Analyse une condition simple : {"kind": "flag"|"stat"|"rel"|"flagcmp", "neg", "key", "op", "rhs"} ;
## {"error": message} si elle est illisible
static func parse_cond(c: String) -> Dictionary:
	var s := c.strip_edges()
	var neg := false
	while s.begins_with("!"):
		neg = not neg
		s = s.substr(1).strip_edges()
	if s == "":
		return {"error": "condition vide"}
	for pre in ["stat:", "rel:", "flag:"]:
		if s.begins_with(pre):
			var body := s.substr(pre.length())
			for op in _OPS:
				var p := body.find(op)
				if p > 0:
					var key := body.substr(0, p).strip_edges()
					var rhs := body.substr(p + op.length()).strip_edges()
					if key == "" or rhs == "":
						return {"error": "clé ou valeur manquante dans « %s »" % c}
					if pre == "flag:":
						if op != "==" and op != "!=":
							return {"error": "flag: n'accepte que == ou != (« %s »)" % c}
						return {"kind": "flagcmp", "neg": neg, "key": key, "op": op, "rhs": rhs}
					if not rhs.is_valid_float():
						return {"error": "valeur non numérique dans « %s »" % c}
					return {"kind": pre.trim_suffix(":"), "neg": neg, "key": key, "op": op, "rhs": rhs}
			return {"error": "opérateur manquant dans « %s »" % c}
	for op in _OPS:
		if s.contains(op):
			return {"error": "comparaison sans préfixe stat:/rel:/flag: (« %s »)" % c}
	if s.contains(" ") or s.contains(":"):
		return {"error": "nom de drapeau invalide « %s »" % c}
	return {"kind": "flag", "neg": neg, "key": s}


## Condition : "drapeau", "!drapeau", "stat:opinion>=40", "rel:karim<0", "flag:choix==valeur",
## ou un Array de conditions (toutes vraies)
static func cond(c: Variant) -> bool:
	if c is Array:
		for x in c:
			if not cond(x):
				return false
		return true
	if c is bool:
		return c
	var p := parse_cond(str(c))
	if p.has("error"):
		push_error("Dialogue : condition illisible « %s » (%s)" % [str(c), p["error"]])
		return false
	var r := false
	match str(p["kind"]):
		"flag":
			r = bool(Campaign.flag(p["key"], false))
		"flagcmp":
			var v := str(Campaign.flag(p["key"], ""))
			r = v == str(p["rhs"]) if p["op"] == "==" else v != str(p["rhs"])
		_:
			var lhs := Campaign.stat(p["key"]) if p["kind"] == "stat" else float(Campaign.rel_get(p["key"]))
			var rv := float(p["rhs"])
			match str(p["op"]):
				">=": r = lhs >= rv
				"<=": r = lhs <= rv
				"==": r = is_equal_approx(lhs, rv)
				"!=": r = not is_equal_approx(lhs, rv)
				">": r = lhs > rv
				"<": r = lhs < rv
	return not r if p["neg"] else r
