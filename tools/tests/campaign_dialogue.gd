extends SceneTree
## Test du module Dialogues (sans affichage) : conditions, ids de réplique et de voix, enveloppe de parole,
## interprète des arbres (if/else, goto, set/stats/rel, call, choix filtrés, end) en pilote automatique, puis
## répliques réelles (apparition mot à mot, bouche du personnage et de Sam, avance par advance()), choix au
## minuteur, au clavier et à la souris, barks (au-dessus de la tête, ou discrets).
##   tools/dev/gd --headless --path . --fixed-fps 30 -s tools/tests/campaign_dialogue.gd

const CH_PATH := "user://test_dialogue_ch.gd"
const CH_SRC := """extends ChapterScript
var marks := 0


func run() -> void:
	await director.sleep(100000.0)


func mise_en_scene() -> void:
	marks += 1
	await director.sleep(0.05)
"""

const DLG := {
	"_id": "test",
	"start": [
		{"who": "nadia", "text": "Salut, toi.", "anim": "nod", "look": "sam"},
		{"who": "karim", "text": "Réplique ignorée.", "if": "jamais_pose"},
		{"set": {"t_flag": true}, "stats": {"opinion": 2}, "rel": {"karim": 5}},
		{"goto": "suite", "if": "t_flag", "else": "mauvais"},
		{"set": {"t_mauvais": true}},
	],
	"mauvais": [{"set": {"t_mauvais": true}}],
	"suite": [
		{"call": "mise_en_scene"},
		{"who": "karim", "text": "Alors, tu viens ?"},
		{"prompt": "Alors ?", "timer": 5.0, "choice": [
			{"id": "cache", "text": "Option cachée", "if": "!t_flag", "goto": "mauvais"},
			{"id": "a", "text": "A", "say": "Je prends A.", "set": {"t_choix": "a"}, "goto": "fin"},
			{"id": "b", "text": "B", "goto": "mauvais"},
		]},
	],
	"fin": [
		{"goto": "mauvais", "if": "flag:t_choix==b", "else": "fin2"},
	],
	"fin2": [
		{"who": "narrateur", "text": "Fin.", "if": ["t_flag", "stat:opinion>=19", "rel:karim>0"]},
		{"set": {"t_fin2": true}},
		{"end": true},
		{"set": {"t_apres_fin": true}},
	],
}

var fails: Array = []
var main: Node
var director: ChapterDirector


func _initialize() -> void:
	var f := FileAccess.open(CH_PATH, FileAccess.WRITE)
	f.store_string(CH_SRC)
	f.close()
	Campaign.autoplay = true
	Campaign.autoplay_policy = "first"
	Campaign.new_game()
	Campaign.active = true
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)
		print("  ✗ ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var w := 0
	while main.get("director") == null and w < 100:
		await process_frame
		w += 1
	director = main.get("director")
	if director == null:
		_check(false, "directeur de chapitre créé")
		_finish()
		return
	director.def = director.def.duplicate()
	director.def["script"] = CH_PATH
	# --- fonctions statiques
	_check(DialogueUI.line_id("start", 3) == "start_3", "line_id")
	_check(DialogueUI.line_id("n", 2, 1) == "n_2_c1", "line_id choix")
	_check(DialogueUI.voice_path("ch1", "start_0") == "res://assets/voice/ch1/start_0.ogg", "voice_path")
	_check(DialogueUI.display_name("nadia") == "Nadia", "display_name")
	Campaign.set_flag("t_x", true)
	Campaign.set_flag("t_v", "floutee")
	_check(DialogueUI.cond("t_x") and not DialogueUI.cond("!t_x") and DialogueUI.cond("!t_absent"), "cond drapeaux")
	_check(DialogueUI.cond("stat:opinion>=18") and not DialogueUI.cond("stat:opinion>40"), "cond jauges")
	_check(DialogueUI.cond("rel:karim<=0") and not DialogueUI.cond("rel:karim<0"), "cond relations")
	_check(DialogueUI.cond("flag:t_v==floutee") and DialogueUI.cond("flag:t_v!=nette"), "cond flag:")
	_check(DialogueUI.cond(["t_x", "stat:opinion<50"]) and not DialogueUI.cond(["t_x", "t_absent"]), "cond liste")
	for bad in ["stat:opinion>>", "opinion>=3", "stat:opinion>=abc", "flag:x>3", "deux mots", ""]:
		_check(DialogueUI.parse_cond(bad).has("error"), "condition illisible détectée : « %s »" % bad)
	var env := DialogueLip.envelope("Bonjour, ça va ? Oui.", 2.0)
	_check(env.size() == 40 and env.max() > 0.5 and env.min() == 0.0, "enveloppe de parole")
	_check(DialogueLip.visible_chars("un deux trois", 0.3) == 7, "apparition mot à mot (%d)" % DialogueLip.visible_chars("un deux trois", 0.3))
	_check(DialogueLip.visible_chars("un deux", 1.0) == 7 and DialogueLip.visible_chars("un deux", 0.0) == 0, "apparition bornes")
	# --- attendre le script de test
	var t := 0
	while director.script_obj == null and t < 300:
		await process_frame
		t += 1
	_check(director.script_obj != null, "script de chapitre de test chargé")
	if director.script_obj == null:
		_finish()
		return
	var ui := director.dialogue
	var player: Player = director.player
	var nadia := director.cast.spawn("nadia", player.global_position + Vector3(2.0, 0, 1.0))
	director.cast.spawn("karim", player.global_position + Vector3(-1.5, 0, 2.0))
	# --- interprète en pilote automatique
	var last: String = await ui.run(DLG, "start")
	_check(last == "a", "dernier choix « a » (obtenu « %s »)" % last)
	_check(Campaign.flag("t_flag", false) == true and str(Campaign.flag("t_choix", "")) == "a", "drapeaux posés")
	_check(not Campaign.flag("t_mauvais", false), "aucun mauvais embranchement")
	_check(Campaign.flag("t_fin2", false) and not Campaign.flag("t_apres_fin", false), "end arrête le dialogue")
	_check(is_equal_approx(Campaign.stat("opinion"), 20.0) and Campaign.rel_get("karim") == 5, "stats et rel")
	_check(int(director.script_obj.get("marks")) == 1, "call vers le script du chapitre")
	# --- répliques réelles
	Campaign.autoplay = false
	var text := "Bonjour, ceci est une réplique de test assez longue pour apparaître mot à mot."
	var t0 := Engine.get_process_frames()
	var done := [false]
	ui.line_done.connect(func() -> void: done[0] = true, CONNECT_ONE_SHOT)
	ui.play_line("nadia", text, {"anim": "explain"})
	var jaw := 0.0
	var partial := false
	for i in 30:
		await process_frame
		jaw = maxf(jaw, nadia.human.jaw)
		var vc: int = ui._text.visible_characters
		if vc > 0 and vc < text.length():
			partial = true
			_check(vc == text.length() or text[vc] == " ", "coupure entre deux mots")
	_check(partial, "texte qui apparaît progressivement")
	_check(jaw > 0.05, "la bouche de Nadia bouge (%.2f)" % jaw)
	_check(ui.busy() and ui._name.text == "NADIA", "sous-titre affiché avec le nom")
	ui.advance()
	await _frames(2)
	_check(ui._text.visible_characters == -1, "advance() : toute la réplique")
	ui.advance()
	await _frames(3)
	_check(done[0], "advance() : réplique terminée")
	_check(Engine.get_process_frames() - t0 < int(DialogueUI.read_time(text) * 30.0), "réplique passée avant sa fin")
	# Sam parle : la bouche du joueur bouge
	ui.play_line("sam", "Je parle, moi aussi, et assez longtemps.", {})
	var pj := 0.0
	for i in 25:
		await process_frame
		pj = maxf(pj, player.human.jaw)
	_check(pj > 0.05, "la bouche de Sam bouge (%.2f)" % pj)
	ui.advance()
	ui.advance()
	await _frames(3)
	# --- choix : minuteur
	var t1 := Engine.get_process_frames()
	var k: int = await ui.choose("Vite !", ["Un", "Deux", "Trois"], 0.5)
	_check(k == 0, "minuteur : option 0 (%d)" % k)
	_check(Engine.get_process_frames() - t1 >= 14, "minuteur respecté (%d images)" % (Engine.get_process_frames() - t1))
	# clavier
	var got := [-1]
	ui.choice_made.connect(func(i: int) -> void: got[0] = i, CONNECT_ONE_SHOT)
	ui.choose("", ["Un", "Deux", "Trois"], 0.0)
	await _frames(3)
	_check(ui._rows.size() == 3 and ui._timer_bar != null and not ui._timer_bar.visible, "options affichées, pas de minuteur")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_2
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(12)
	_check(got[0] == 1, "touche 2 : option 1 (%d)" % got[0])
	# souris
	got[0] = -1
	ui.choice_made.connect(func(i: int) -> void: got[0] = i, CONNECT_ONE_SHOT)
	ui.choose("", ["Un", "Deux", "Trois"], 0.0)
	await _frames(3)
	ui._rows[2].picked.emit(2)
	await _frames(12)
	_check(got[0] == 2, "clic : option 2 (%d)" % got[0])
	# --- barks
	ui.bark("nadia", "Hé, par ici !")
	await _frames(2)
	var lbl: Label3D = null
	for c in nadia.get_children():
		if c is Label3D:
			lbl = c
	_check(lbl != null, "bark au-dessus de Nadia")
	ui.bark("passant", "Ils exagèrent quand même…")
	await _frames(2)
	_check(ui._barks_box.get_child_count() == 1, "bark discret sans personnage")
	await _frames(200)
	_check(lbl == null or not is_instance_valid(lbl), "bark effacé")
	_check(ui._barks.is_empty(), "plus de bark en cours")
	# --- retour au calme
	await _frames(40)
	_check(not ui.busy() and ui._sub.modulate.a < 0.05, "sous-titres effacés")
	_finish()


func _finish() -> void:
	Campaign.active = false
	if fails.is_empty():
		print("RÉSULTAT : OK")
	else:
		print("ÉCHEC : %d vérification(s) : %s" % [fails.size(), ", ".join(fails)])
	quit(0 if fails.is_empty() else 1)
