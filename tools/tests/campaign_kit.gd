extends SceneTree
## Kit du joueur : barre d'outils d'après les outils autorisés (touches 1..9, molette), puis chaque outil du kit
## (téléphone, tracts, affiches, mégaphone, bombe de peinture) et l'interaction « Parler » ; vérifie les événements
## émis sur le bus de la foule (§ 5.9 du cahier des charges) et leurs données.

class Rec extends Node:
	var log: Array = []

	func on_event(type: String, d: Dictionary) -> void:
		log.append([type, d])


var main: Node
var p: Player
var crowd: Crowd
var civ: Civilians
var rec: Rec
var fails: Array = []
var limit := 0


func _initialize() -> void:
	WorldSetup.sandbox = {"tools": WorldSetup.TOOLS_ORIGINAL + WorldSetup.TOOLS_CAMPAIGN}
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	_run()


func _process(_d: float) -> bool:
	limit += 1
	if limit > 30 * 240:
		print("ÉCHEC : délai du test dépassé")
		quit(1)
		return true
	return false


func check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)
		print("ÉCHEC : ", what)
	else:
		print("  ok  ", what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func secs(s: float) -> void:
	await frames(int(s * 30.0))


func key(k: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	var u := InputEventKey.new()
	u.physical_keycode = k
	u.pressed = false
	Input.parse_input_event(u)
	await frames(2)


func events(type: String) -> Array:
	return rec.log.filter(func(e): return e[0] == type).map(func(e): return e[1])


func has_keys(d: Dictionary, keys: Array) -> bool:
	for k in keys:
		if not d.has(k):
			return false
	return true


## Joueur à `pos`, regard horizontal vers `look`
func stand(pos: Vector3, look: Vector3) -> void:
	p.place_at(pos + Vector3(0, 0.05, 0))
	var d := look - pos
	p._yaw = atan2(-d.x, -d.z)
	p._pitch = 0.0
	p.human.rotation.y = p._yaw
	await frames(6)


func _run() -> void:
	await frames(3)
	p = main.player
	for c in main.get_children():
		if c is Crowd:
			crowd = c
		if c is Civilians:
			civ = c
	rec = Rec.new()
	rec.add_to_group("crowd")
	main.add_child(rec)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await frames(20)

	# --- barre d'outils et touches
	check(p.tool_items == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], "11 outils autorisés : %s" % str(p.tool_items))
	var hud: Node = null
	for c in main.get_children():
		if c.get("_slots") != null:
			hud = c
	check(hud != null and (hud.get("_slots") as Array).size() == 9, "barre d'outils : 9 cases (touches 1..9)")
	await key(KEY_7)
	check(p.current_item == 7, "touche 7 -> téléphone")
	await key(KEY_7)
	check(p.current_item == 0, "touche 7 de nouveau -> mains libres")
	p.set_tools(["phone", "tracts", "posters"])
	await frames(2)
	check(p.tool_items == [7, 8, 9], "outils de chapitre : téléphone, tracts, affiches")
	check(hud != null and (hud.get("_slots") as Array).size() == 3, "barre reconstruite : 3 cases")
	await key(KEY_2)
	check(p.current_item == 8, "touche 2 -> 2e outil autorisé (tracts)")
	await key(KEY_5)
	check(p.current_item == 8, "touche 5 sans outil : rien ne change")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	Input.parse_input_event(wheel)
	await frames(3)
	check(p.current_item == 9, "molette -> outil autorisé suivant (affiches)")
	p.set_tools(WorldSetup.TOOLS_ORIGINAL)
	await frames(3)
	check(p.current_item == 0 and p.tool_items == [1, 2, 3, 4, 5, 6], "retour au bac à sable : 1..6, outil retiré rangé")
	await key(KEY_1)
	check(p.current_item == 1, "bac à sable : touche 1 -> mortier")
	p.set_tools(WorldSetup.TOOLS_ORIGINAL + WorldSetup.TOOLS_CAMPAIGN)
	await frames(2)

	# --- téléphone : la foule dans le champ
	p.select_item(7)
	await frames(30)
	var cc := Vector3.ZERO
	var nn := 0
	for n in crowd.npcs:
		cc += n.global_position
		nn += 1
	cc /= maxf(nn, 1)
	await stand(cc + Vector3(-14.0, 0.0, 0.3), cc)
	p.phone.start_film()
	await secs(3.5)
	p.phone.stop_film()
	await frames(2)
	check(events("film_start").size() == 1, "film_start")
	var fs := events("film_stop")
	check(fs.size() == 1 and float(fs[0].get("sec", 0.0)) > 3.0, "film_stop {sec}")
	var clips := events("film_clip")
	check(clips.size() == 1 and has_keys(clips[0], ["sec", "subjects", "score", "published"]), "film_clip {sec, subjects, score, published}")
	if clips.size() > 0:
		check("crowd" in clips[0]["subjects"] and not clips[0]["published"] and float(clips[0]["score"]) > 0.0, "la foule cadrée est dans la vidéo : %s" % str(clips[0]))
	# dos tourné : la foule n'est pas dans le champ
	await stand(cc + Vector3(-14.0, 0.0, 0.3), cc + Vector3(-40.0, 0.0, 0.3))
	p.phone.start_film()
	await secs(3.5)
	p.phone.stop_film()
	await frames(2)
	clips = events("film_clip")
	check(clips.size() == 2 and not ("crowd" in clips[1]["subjects"]), "hors champ : pas de foule dans la vidéo")
	# publier = choix
	check(p.phone.publish_last(true), "publier la dernière vidéo")
	clips = events("film_clip")
	check(clips.size() == 3 and clips[2]["published"] == true, "film_clip publiée")
	# étiquettes de prix (supérette)
	var sup := Quartier.spot("supermarche")
	await stand(sup + Vector3(0, 0, 4.0), sup + Vector3(0, 1.5, 0))
	p.phone.take_photo()
	await frames(2)
	var ph := events("photo")
	check(ph.size() == 1 and has_keys(ph[0], ["subjects"]) and "prix" in ph[0]["subjects"], "photo des prix : %s" % str(ph))
	# témoignage face caméra
	var a := StoryActor.new()
	a.setup_look("mme_ferreira")
	a.crowd = crowd
	main.add_child(a)
	crowd.actors.append(a)
	var tp := Quartier.spot("square") + Vector3(4, 0, 0)
	a.global_position = tp
	await stand(tp + Vector3(0, 0, 1.8), tp + Vector3(0, 1.5, 0))
	a.rotation.y = atan2(0.0, -1.8)
	a.yaw = a.rotation.y
	p.phone.start_film()
	await secs(3.6)
	p.phone.stop_film()
	await frames(2)
	var te := events("testimony")
	check(te.size() == 1 and te[0].get("who", "") == "mme_ferreira", "testimony {who} : %s" % str(te))
	# batterie
	p.phone.battery = 0.05
	p.phone.start_film()
	await secs(1.5)
	check(not p.phone.recording and events("film_stop").size() == 4, "batterie à plat : la vidéo s'arrête")
	p.phone.battery = 80.0

	# --- parler à un personnage d'histoire (E)
	p.select_item(0)
	await frames(20)
	Input.action_press("interact")
	await frames(3)
	Input.action_release("interact")
	await frames(3)
	var tk := events("talk")
	check(tk.size() == 1 and tk[0].get("who", "") == "mme_ferreira" and tk[0].get("node") == a, "talk {who, node} avec un personnage d'histoire")
	crowd.actors.erase(a)
	a.queue_free()

	# --- tracts aux passants
	p.select_item(8)
	await frames(30)
	var spot := Quartier.spot("boulangerie") + Vector3(0, 0, -2.0)
	var tries := 0
	for w in civ.walkers.duplicate():
		if events("tract_given").size() > 0 and events("tract_refused").size() > 0:
			break
		if not is_instance_valid(w) or w.done or w.leaving or w.lead != null:
			continue
		tries += 1
		w.curious = 1.0 if tries % 2 == 1 else 0.0
		w.hurry = tries % 2 == 0
		await stand(spot, spot + Vector3(0, 0, 1.0))
		w.global_position = spot + Vector3(0, 0, 1.2)
		w.stop_move()
		await frames(4)
		p.tracts.offer(w)
		await secs(1.4)
		if tries > 24:
			break
	var tg := events("tract_given")
	var tr := events("tract_refused")
	check(tg.size() > 0 and tg[0].get("by", "") == "player" and tg[0].get("pos") is Vector3, "tract_given {pos, by} (%d essais)" % tries)
	check(tr.size() > 0 and tr[0].get("by", "") == "player" and tr[0].get("pos") is Vector3, "tract_refused {pos, by}")
	check(p.tracts.count == TractTool.MAX - tg.size(), "pile de tracts : %d" % p.tracts.count)
	await stand(Quartier.spot("bar_qg") + Vector3(0, 0, -1.0), Quartier.spot("bar_qg"))
	await secs(0.8)
	check(p.tracts.count == TractTool.MAX, "pile reprise au QG")

	# --- parler à un passant (E, mains libres)
	p.select_item(0)
	await frames(20)
	var talked := false
	for w in civ.walkers.duplicate():
		if not is_instance_valid(w) or w.done or w.leaving or w.state != "walk":
			continue
		await stand(spot, spot + Vector3(0, 0, 1.0))
		w.global_position = spot + Vector3(0, 0, 1.1)
		w.stop_move()
		await frames(6)
		if p.near_talk == w:
			Input.action_press("interact")
			await frames(3)
			Input.action_release("interact")
			await frames(3)
			talked = true
			break
	tk = events("talk")
	check(talked and tk.size() >= 2 and tk[-1].get("who", "") == "passant", "talk {who: passant} avec E")

	# --- affiches : colonne Morris (légal), mur (illégal), panneau d'affichage libre (légal)
	p.select_item(9)
	await frames(30)
	var mo := Quartier.MORRIS
	await stand(mo + Vector3(0, 0, -1.3), mo + Vector3(0, 1.6, 0))
	p.posters.use()
	await secs(2.8)
	var ps := events("poster_stuck")
	check(ps.size() == 1 and ps[0].get("surface", "") == "morris" and ps[0].get("legal") == true and ps[0].get("pos") is Vector3, "poster_stuck colonne Morris légal : %s" % str(ps))
	var wx := 6.0
	var lim := Quartier.z_limits(wx)
	var wall_p := Vector3(wx, 0, lim.y - 0.9)
	await stand(wall_p, wall_p + Vector3(0, 1.6, 3.0))
	p.posters.use()
	await secs(2.8)
	ps = events("poster_stuck")
	check(ps.size() == 2 and ps[1].get("surface", "") == "mur" and ps[1].get("legal") == false, "poster_stuck mur illégal : %s" % str(ps.slice(1)))
	var board := StaticBody3D.new()
	board.add_to_group("affichage_libre")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.2, 1.8, 0.1)
	cs.shape = bs
	board.add_child(cs)
	main.add_child(board)
	var bp := Quartier.spot("square") + Vector3(-3, 1.4, 0)
	board.global_position = bp
	await frames(3)
	await stand(bp - Vector3(0, 1.4, 1.2), bp)
	p.posters.use()
	await secs(2.8)
	ps = events("poster_stuck")
	check(ps.size() == 3 and ps[2].get("surface", "") == "panneau" and ps[2].get("legal") == true, "poster_stuck panneau d'affichage libre légal")
	check(p.posters.count == PosterTool.MAX - 3, "affiches restantes")

	# --- bombe de peinture
	p.select_item(11)
	await frames(30)
	await stand(wall_p + Vector3(2.0, 0, 0), wall_p + Vector3(2.0, 1.4, 3.0))
	p.spray.paint_now()
	await secs(3.8)
	var st := events("spray_tag")
	check(st.size() == 1 and has_keys(st[0], ["pos", "text", "surface"]) and st[0]["surface"] == "mur" and str(st[0]["text"]) != "", "spray_tag {pos, text, surface} : %s" % str(st))

	# --- mégaphone : au milieu de la foule, puis seul au bout d'une rue
	p.select_item(10)
	await frames(30)
	crowd.excitement = 1.0
	for n in crowd.npcs:
		n.fear = 0.0
		n.anger = 0.6
	await stand(cc + Vector3(-1.0, 0, 0), cc + Vector3(4.0, 1.5, 0))
	p.megaphone.use()
	await secs(4.0)
	var mg := events("megaphone")
	check(mg.size() == 1 and has_keys(mg[0], ["slogan", "joined"]) and int(mg[0]["joined"]) >= MegaphoneTool.CHANT_MIN, "megaphone {slogan, joined} : la foule reprend : %s" % str(mg))
	await stand(Quartier.spot("rue_nord_fond"), Quartier.spot("rue_nord_fond") + Vector3(0, 1.5, -5))
	await secs(MegaphoneTool.COOLDOWN)
	p.megaphone.use()
	await secs(4.0)
	mg = events("megaphone")
	check(mg.size() == 2 and int(mg[1]["joined"]) == 0, "mégaphone seul : personne ne reprend")

	# --- triche R désactivée en campagne
	Campaign.active = true
	var before := p.tracts.count
	p.tracts.count = 3
	await key(KEY_R)
	check(p.tracts.count == 3, "R sans effet en campagne")
	Campaign.active = false
	p.tracts.count = before

	# --- bilan des événements du kit
	var kit_types := ["talk", "tract_given", "tract_refused", "poster_stuck", "spray_tag", "megaphone", "film_start", "film_stop", "film_clip", "photo", "testimony"]
	print("événements du kit : ", rec.log.filter(func(e): return e[0] in kit_types).map(func(e): return e[0]))
	print("RÉSULTAT : OK" if fails.is_empty() else "RÉSULTAT : ÉCHEC (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
