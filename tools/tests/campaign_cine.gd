extends SceneTree
## Test du module Cinématiques & jeu d'acteur (sans affichage) : prise de main (joueur figé, interface masquée,
## bandes noires), travellings avec courbe, zoom (fov_to), profondeur de champ (fixe, automatique), caméra à
## l'épaule, glissé (cut: false), fondus, carton de titre, rendu de la main (caméra du joueur), plans en pilote
## automatique ; gestes expressifs (nod, shake_head, shrug, explain, sigh, laugh, hug, sit) et retour au repos ;
## marche (arrivée), suivi, se relever avant de marcher.
##   tools/dev/gd --headless --path . --fixed-fps 30 -s tools/tests/campaign_cine.gd
## Captures (rendu) : tools/dev/gd --render --path . --resolution 1280x720 -s tools/tests/campaign_cine.gd -- <dossier>
##   -> <dossier>/pres_1.png (plan de dialogue : bandes noires, sous-titre, choix minuté), pres_2.png (carton),
##      pres_3.png (gestes), pres_4.png (bark en jeu)

const CH_PATH := "user://test_cine_ch.gd"
const CH_SRC := """extends ChapterScript


func run() -> void:
	await director.sleep(100000.0)
"""

var fails: Array = []
var main: Node
var director: ChapterDirector
var out_dir := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out_dir = a[0] if a.size() > 0 else ""
	var f := FileAccess.open(CH_PATH, FileAccess.WRITE)
	f.store_string(CH_SRC)
	f.close()
	Campaign.autoplay = true
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


## Attente en temps de jeu (le rendu logiciel est lent : on compte le temps, pas les images)
func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await process_frame
		t += _dt()


func _dt() -> float:
	return director.get_process_delta_time() if director else 1.0 / 30.0


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
	while director.script_obj == null and w < 400:
		await process_frame
		w += 1
	if out_dir != "":
		await _capture()
		return
	Campaign.autoplay = false
	var cine := director.cine
	var player: Player = director.player
	var p0 := player.global_position
	var nadia := director.cast.spawn("nadia", p0 + Vector3(3.0, 0, 2.0))
	var karim := director.cast.spawn("karim", p0 + Vector3(-2.0, 0, 3.0))
	await _frames(5)
	# --- prise de main
	var hud: CanvasLayer = null
	for c in main.get_children():
		if c is CanvasLayer and not (c is PauseMenu) and c.visible:
			hud = c
			break
	cine.begin()
	await _frames(25)
	_check(cine.active and cine.cam.current, "caméra de cinéma active")
	_check(not player.is_physics_processing() and not player.is_processing_unhandled_input(), "joueur figé")
	_check(hud == null or not hud.visible, "interface de jeu masquée")
	_check(not director.objectives.visible, "objectifs masqués")
	_check(cine._bar_top.visible and absf(cine._bar_top.anchor_bottom - Cinematics.BAR_H) < 0.01, "bandes noires (%.3f)" % cine._bar_top.anchor_bottom)
	# --- travelling avec courbe et zoom
	var A := p0 + Vector3(6, 3, 6)
	var B := p0 + Vector3(-6, 3, 6)
	var done := [false]
	var go := func() -> void:
		await cine.shot({"from": A, "to": B, "look": "nadia", "dur": 1.0, "fov": 50, "fov_to": 30, "ease": "inout"})
		done[0] = true
	go.call()
	await _frames(15)
	var mid := cine.cam.global_position
	_check(absf(mid.x - (A.x + B.x) * 0.5) < 0.8, "travelling à mi-course (%.2f)" % (mid.x - (A.x + B.x) * 0.5))
	await _frames(1)
	var q := cine.cam.global_position
	await _frames(2)
	_check(q.distance_to(cine.cam.global_position) > 0.05, "travelling en mouvement")
	await _frames(25)
	_check(done[0], "plan terminé")
	_check(cine.cam.global_position.distance_to(B) < 0.02, "travelling arrivé")
	_check(absf(cine.cam.fov - 30.0) < 0.1, "fov_to (%.1f)" % cine.cam.fov)
	var to_n := (nadia.head_pos() - cine.cam.global_position).normalized()
	_check(-cine.cam.global_basis.z.dot(to_n) > 0.995, "cadré sur Nadia")
	# --- profondeur de champ
	await cine.shot({"from": A, "look": "karim", "dur": 0.2, "dof": 4.0})
	var at: CameraAttributesPractical = cine.cam.attributes
	_check(at != null and at.dof_blur_far_enabled and absf(at.dof_blur_far_distance - 5.6) < 0.01, "dof fixe")
	await cine.shot({"from": A, "look": "karim", "dur": 0.2, "dof": -1})
	var dk := A.distance_to(karim.head_pos())
	_check(at.dof_blur_far_enabled and absf(at.dof_blur_far_distance - (dk * 1.25 + 0.6)) < 0.05, "dof automatique")
	await cine.shot({"from": A, "look": "karim", "dur": 0.1})
	_check(not at.dof_blur_far_enabled and not at.dof_blur_near_enabled, "sans dof")
	# --- caméra à l'épaule
	cine.shot({"from": B, "look": Vector3(p0.x, 1.5, p0.z), "dur": 0.6, "shake": 1.0})
	await _frames(3)
	var x1 := cine.cam.global_transform
	await _frames(4)
	var x2 := cine.cam.global_transform
	_check(x1.origin.distance_to(x2.origin) > 0.0005 or not x1.basis.is_equal_approx(x2.basis), "caméra à l'épaule")
	await _frames(20)
	# --- glissé (cut: false) : on part de la place actuelle
	var before := cine.cam.global_position
	var far := p0 + Vector3(0, 8, -12)
	cine.shot({"from": far, "look": "player", "dur": 0.5, "cut": false, "blend": 0.6})
	await _frames(1)
	_check(cine.cam.global_position.distance_to(before) < 1.0, "glissé depuis la place actuelle")
	await _frames(40)
	_check(cine.cam.global_position.distance_to(far) < 0.05, "glissé arrivé")
	# --- fondus et carton
	await cine.fade_out(0.3)
	_check(cine._fade.color.a > 0.99, "fondu au noir")
	await cine.title_card("TITRE", "Jeudi 9 mars — 18 h 40\nLe square", 0.6)
	_check(cine._card == null or not is_instance_valid(cine._card) or cine._card.is_queued_for_deletion(), "carton retiré")
	await cine.fade_in(0.3)
	_check(cine._fade.color.a < 0.01, "retour de l'image")
	# --- on rend la main
	cine.end()
	await _frames(2)
	_check(player.is_physics_processing() and player.is_processing_unhandled_input(), "joueur libéré")
	_check(hud == null or hud.visible, "interface rétablie")
	_check(director.objectives.visible, "objectifs rétablis")
	await _frames(30)
	_check(player.camera.current, "caméra du joueur rendue")
	_check(not cine._bar_top.visible, "bandes noires retirées")
	# --- pilote automatique : plans quasi instantanés
	Campaign.autoplay = true
	var f0 := Engine.get_process_frames()
	await cine.shot({"from": A, "to": B, "look": "nadia", "dur": 6.0})
	await cine.fade_out(1.0)
	await cine.fade_in(1.0)
	await cine.title_card("X", "Y", 4.0)
	cine.end()
	_check(Engine.get_process_frames() - f0 < 30, "pilote automatique rapide (%d images)" % (Engine.get_process_frames() - f0))
	_check(player.camera.current, "caméra du joueur après pilote automatique")
	Campaign.autoplay = false
	# --- gestes
	var probes := {
		"nod": func() -> bool: return nadia.human.nod > 0.3,
		"shake_head": func() -> bool: return nadia.human.shake > 0.3,
		"shrug": func() -> bool: return nadia._hands()[0] != null and nadia.human.side_lean > 0.05,
		"explain": func() -> bool: return nadia._hands()[0] != null and nadia._hands()[1] != null,
		"sigh": func() -> bool: return absf(nadia.human.hunch) > 0.05,
		"laugh": func() -> bool: return nadia.jaw_extra > 0.1 and nadia._hands()[0] != null,
		"hug": func() -> bool: return nadia._hands()[0] != null and nadia._hands()[1] != null and nadia.sep_k < 0.5,
		"sit": func() -> bool: return nadia.human.sit > 0.4,
	}
	for g in probes:
		nadia.gesture(g, 1.2)
		await _frames(8)          # la physique avance de 2 pas de 1/30 s par image (--fixed-fps 30)
		_check((probes[g] as Callable).call(), "geste « %s »" % g)
		await _frames(70)
		_check(nadia.act == "idle" and not nadia._expr_on, "retour au repos après « %s »" % g)
		_check(nadia.human.nod == 0.0 and nadia.human.shake == 0.0 and nadia.human.sit == 0.0 and nadia.human.hunch == 0.0 and nadia.jaw_extra == 0.0, "tête / buste / assise au repos après « %s »" % g)
	# --- parole : bouche, tête, mains
	nadia.talk(2.0, "Bon, on y va ? Faut qu'on parle aux gens du quartier.")
	var jaw := 0.0
	for i in 30:
		await process_frame
		jaw = maxf(jaw, nadia.human.jaw)
	_check(jaw > 0.05 and nadia.act == "explain", "parole animée (bouche %.2f, mains %s)" % [jaw, nadia.act])
	await _frames(40)
	_check(nadia.act == "idle" and not nadia.talking(), "fin de parole")
	# --- marche
	var dest := "morris" if Quartier.spot("morris").distance_to(nadia.global_position) > 6.0 else "abribus"
	var ok: bool = await director.cast.walk_to(nadia, Quartier.spot(dest), false, 60.0)
	_check(ok and nadia.arrived(), "marche jusqu'à « %s »" % dest)
	await _frames(10)
	_check(not nadia.has_goal and nadia.vel.length() < 0.3, "arrêt à l'arrivée (%.2f m/s)" % nadia.vel.length())
	# --- suivi
	var pp := nadia.global_position + Vector3(9.0, 0, 0)
	player.global_position = Vector3(pp.x, player.global_position.y, pp.z)
	nadia.follow_target(player)
	await _frames(300)
	var dfol := Vector2(nadia.global_position.x - pp.x, nadia.global_position.z - pp.z).length()
	_check(dfol > 0.9 and dfol < 2.9, "suit le joueur (%.2f m)" % dfol)
	nadia.follow_target(null)
	# --- assis, puis repartir
	nadia.gesture("sit", 30.0)
	await _frames(30)
	_check(nadia.seated(), "assise")
	var from := nadia.global_position
	nadia.walk(Quartier.spot(dest))     # lieu déjà atteint plus haut : accessible
	await _frames(3)
	_check(from.distance_to(nadia.global_position) < 0.05, "ne glisse pas en se relevant")
	await _frames(120)
	_check(not nadia.seated() and from.distance_to(nadia.global_position) > 1.0, "se relève puis marche")
	_finish()


# ------------------------------------------------------------------ captures
func _shot(name: String) -> void:
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name))
	print("CAPTURE ", out_dir.path_join(name))


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	Campaign.autoplay = false
	var cine := director.cine
	var ui := director.dialogue
	var player: Player = director.player
	var p0 := player.global_position
	var cf := -player.camera.global_basis.z
	var fwd := Vector3(cf.x, 0, cf.z).normalized()
	var side := fwd.cross(Vector3.UP).normalized()
	var nadia := director.cast.spawn("nadia", p0 + fwd * 3.0)
	var karim := director.cast.spawn("karim", p0 + fwd * 3.0 + side * 1.6)
	nadia.face_target(p0)
	karim.face_target(nadia.global_position)
	await _wait(1.0)
	# 1. plan de dialogue : contrechamp sur Nadia par-dessus l'épaule de Sam, bandes noires, réplique, choix
	cine.begin()
	var eye := p0 + Vector3.UP * 1.68 - fwd * 0.55 - side * 0.45
	cine.shot({"from": eye, "to": eye + Vector3(0.1, 0, 0.25), "look": "nadia", "dur": 30.0, "fov": 38, "dof": -1, "shake": 0.3})
	await _wait(1.0)
	ui.play_line("nadia", "On était douze, l'an dernier. Aujourd'hui, regarde autour de toi : ils sont tous là.", {"keep": true, "look": "sam"})
	await _wait(1.2)
	ui.advance()
	await _wait(0.2)
	ui.advance()
	await _wait(0.3)
	ui.choose("Que réponds-tu ?", ["Je suis là. Dis-moi quoi faire.", "Je passe juste, Nadia.", "Et si on bloquait le boulevard ?"], 12.0)
	await _wait(1.2)
	await _shot("pres_1.png")
	ui._pick(0)
	await _wait(0.5)
	# 2. carton de titre sur un plan large
	cine.shot({"from": p0 - fwd * 6.0 - side * 8.0 + Vector3.UP * 4.5, "to": p0 - fwd * 6.0 - side * 6.0 + Vector3.UP * 4.0, "look": p0 + fwd * 4.0 + Vector3.UP * 1.2, "dur": 30.0, "fov": 45})
	cine.title_card("On était douze", "Jeudi 9 mars — 18 h 40\nLe square", 3.0)
	await _wait(1.4)
	await _shot("pres_2.png")
	await _wait(1.8)
	# 3. gestes : rangée face caméra
	var ines := director.cast.spawn("ines", p0 + fwd * 3.0 - side * 1.6)
	var lou := director.cast.spawn("lou", p0 + fwd * 3.0 + side * 3.4)
	var jo := director.cast.spawn("jo", p0 + fwd * 3.6 + side * 3.4)
	var ferreira := director.cast.spawn("mme_ferreira", p0 + fwd * 3.0 - side * 3.4)
	for a in [nadia, karim, ines, ferreira]:
		a.face_target(p0 + fwd * -5.0)
	lou.face_target(jo.global_position)
	jo.face_target(lou.global_position)
	jo.global_position = lou.global_position + (jo.global_position - lou.global_position).normalized() * 0.5
	await _wait(0.6)
	ferreira.gesture("sit", 20.0)
	ines.gesture("laugh", 20.0)
	nadia.gesture("explain", 20.0)
	karim.gesture("shrug", 20.0)
	lou.gesture("hug", 20.0)
	jo.gesture("hug", 20.0)
	cine.shot({"from": p0 + fwd * -3.5 + Vector3(0, 1.5, 0), "look": p0 + fwd * 3.0 + Vector3(0, 1.0, 0), "dur": 30.0, "fov": 55, "cut": true})
	await _wait(1.0)
	await _shot("pres_3.png")
	# 4. en jeu : bark au-dessus d'un personnage
	cine.end()
	for a in [nadia, karim, ines, lou, jo, ferreira]:
		a.gesture("idle", 0.1)
	await _wait(1.2)
	ui.bark("karim", "Regarde-moi ces prix, sérieux…")
	ui.bark("passant", "Encore une manif ?")
	await _wait(0.6)
	await _shot("pres_4.png")
	print("RÉSULTAT : OK")
	quit(0)


func _finish() -> void:
	Campaign.active = false
	if fails.is_empty():
		print("RÉSULTAT : OK")
	else:
		print("ÉCHEC : %d vérification(s) : %s" % [fails.size(), ", ".join(fails)])
	quit(0 if fails.is_empty() else 1)
