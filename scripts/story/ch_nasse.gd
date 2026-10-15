extends ChapterBase
## Chapitre 4 « La nasse » (jeudi, nuit, pluie) : la police encercle le cortège, un tir de LBD blesse Théo,
## Inès soigne ; protéger, filmer, sortir les images et les gens par la rue des Cerisiers ; Karim part à l'émeute.
## Histoire : BIBLE.md § 4.4.

const D := DlgNasse.DLG
const FRIENDS := ["nadia", "karim", "ines", "lou"]


func run() -> void:
	music("tension")
	ambience("pluie_nuit")
	add_stat("mobilisation", 20.0 + stat("opinion") * 0.6, "une semaine de vidéos et de bouche-à-oreille")
	await open_chapter("Chapitre 4 — La nasse", "Jeudi 25 mars — 22 h 15")
	spawn("jo", near("bar_qg", 0.8, -1.2), "player")
	spawn("nadia", near("player", 1.6, -1.0), "player")
	spawn("karim", near("player", -1.4, -1.4), "player")
	spawn("ines", near("player", 2.4, 1.2), "player")
	spawn("lou", near("player", -2.6, 0.8), "player")
	await fade_in(1.2)
	await shot({"from": cam("bar_qg", 16.0, 6.0, 200.0), "to": cam("bar_qg", 7.0, 2.2, 190.0), "look": "jo",
		"dur": 5.0, "fov": 50.0, "ease": "inout"})
	await frame("player", "jo")
	await dialogue(D, "depart")
	await fade_out(0.4)
	cine_end()
	await fade_in(0.5)
	await _marche()
	await _nasse()
	await _tir()
	await _emeute()
	if not flag("ch4_emeute"):
		await _sortie()
	await _zinc()


func _marche() -> void:
	for f in FRIENDS:
		follow(f, "player")
	hint("Reste avec le cortège. Sous la pluie, on voit mal : garde tes amis près de toi.", 6.0)
	var o := objective("carrefour", "Avance avec le cortège jusqu'au carrefour", {"type": "reach",
		"spot": "carrefour_ouest", "radius": 12.0})
	await complete(o)
	clear_objectives()


func _nasse() -> void:
	for f in FRIENDS:
		follow(f, null)
	set_tension(0.55)
	spawn("commissaire", near("carrefour_ouest", 16.0, 3.0), "player")
	cine_begin()
	await shot({"from": cam("carrefour_ouest", 10.0, 16.0, 120.0), "to": cam("carrefour_ouest", 18.0, 12.0, 60.0),
		"look": "carrefour_ouest", "dur": 5.0, "fov": 55.0})
	await frame("player", "lou")
	await dialogue(D, "nasse")
	music("nasse")


func _tir() -> void:
	set_tension(0.7)
	await shot({"from": cam("player", 4.0, 1.7, 160.0), "look": "player", "dur": 0.8, "fov": 45.0, "shake": 0.7,
		"cut": true})
	walk_to("ines", near("player", 2.0, 1.5), true, 5.0)
	gesture("ines", "treat", 40.0)
	await dialogue(D, "tir")
	cine_end()
	var o: Objective
	if flag("ch4_protege_ines"):
		hint("Reste près d'Inès et fais reculer les gens. Ne réponds pas aux tirs.", 6.0)
		o = objective("proteger", "Protège Inès pendant qu'elle soigne Théo", {"type": "hold",
			"waypoint": pos_of("ines"), "radius": 3.5, "sec": 20.0})
	else:
		hint("Cadre le tireur et le blessé, de près. Garde ton calme.", 6.0)
		o = clip_obj("filmer", "Filme le tir et le blessé", "police_lbd", "ines", 9.0)
	await complete(o)
	clear_objectives()
	Campaign.log_action("lbd", "Théo, 17 ans, blessé au visage par un tir de LBD dans la nasse", 0.0)
	if flag("ch4_filme_lbd"):
		Campaign.count("videos")


func _emeute() -> void:
	cine_begin()
	await frame("player", "karim")
	await dialogue(D, "emeute")
	cine_end()
	if flag("ch4_emeute"):
		await _banque()
		return
	if flag("ch4_karim_parti"):
		walk_to("karim", "banque", true, 30.0)
		set_flag("karim_prison", true)
		add_stat("opinion", -2.0, "vitrines brisées sur le boulevard")
		Campaign.log_action("casse", "Vitrines brisées sur le boulevard ; Karim Haddad interpellé", -2.0)
		await wait(4.0)
		despawn("karim")
	else:
		follow("karim", "player")


func _banque() -> void:
	follow("karim", null)
	walk_to("karim", "banque", true, 30.0)
	hint("Tu as suivi l'émeute. Chaque vitrine fera la une demain, pas Théo.", 6.0)
	var o := objective("banque", "Suis Karim jusqu'à la banque", {"type": "reach", "spot": "banque", "radius": 8.0})
	await complete(o)
	clear_objectives()
	add_stat("opinion", -6.0, "émeute sur le boulevard")
	add_stat("repression", 0.1, "émeute sur le boulevard")
	add_stat("notoriete", 0.1, "émeute sur le boulevard")
	add_stat("mobilisation", 8.0, "les plus radicaux")
	Campaign.log_action("casse", "Émeute devant la Banque Hexa : vitrines brisées, alarmes", -6.0)
	cine_begin()
	await shot({"from": cam("banque", 10.0, 2.5, 20.0), "look": "banque", "dur": 1.5, "fov": 45.0, "shake": 0.6})
	await dialogue(D, "banque")
	if flag("karim_prison"):
		despawn("karim")
	else:
		follow("karim", "player")
	await dialogue(D, "lou_seule")
	cine_end()
	var run_o := objective("fuir", "Fuis vers la rue des Cerisiers", {"type": "reach", "spot": "rue_nord", "radius": 8.0})
	await complete(run_o)
	clear_objectives()


func _sortie() -> void:
	set_tension(0.6)
	cine_begin()
	await frame("player", "lou")
	await dialogue(D, "sortie")
	cine_end()
	for f in ["nadia", "lou", "ines"]:
		follow(f, "player")
	var list: Array = [objective("sortie", "Fais sortir les gens par la rue des Cerisiers", {"type": "reach",
		"spot": "rue_nord_fond", "radius": 10.0})]
	list.append(tool_obj("appel", "Guide les gens au mégaphone", {"type": "event", "event": "megaphone", "count": 2,
		"optional": true}, "megaphone_tool", "player", 60.0))
	var ok := await complete(list[0])
	clear_objectives()
	if not ok:
		return
	set_flag("ch4_sortie", true)
	add_stat("opinion", 3.0, "le cortège sort de la nasse dans le calme")
	Campaign.log_action("sortie", "Une centaine de personnes sortent de la nasse par la rue des Cerisiers", 3.0)
	if flag("ch4_lou_garde") and stat("repression") >= 0.3:
		cine_begin()
		await dialogue(D, "lou_seule")
		cine_end()
	else:
		set_flag("images_sorties", true)


func _zinc() -> void:
	set_tension(0.2)
	var o := objective("zinc", "Frappe trois fois à la porte de derrière du Zinc", {"type": "reach", "spot": "bar_qg",
		"radius": 4.0})
	await complete(o)
	clear_objectives()
	set_flag("jo_cache", true)
	rel_add("jo", 10)
	ambience("cafe")
	await fade_out(0.5)
	for f in FRIENDS:
		if actor(f):
			follow(f, null)
	var spots := [Vector2(1.6, -1.0), Vector2(-1.4, -1.4), Vector2(2.4, 0.6), Vector2(-2.4, 0.4)]
	for i in FRIENDS.size():
		if actor(FRIENDS[i]):
			spawn(FRIENDS[i], near("bar_qg", spots[i].x, spots[i].y - 1.5), "jo")
	spawn("jo", near("bar_qg", 0.0, -0.6), "player")
	cine_begin()
	await fade_in(0.8)
	await frame("player", "jo")
	if flag("images_sorties"):
		add_stat("opinion", 6.0 + (3.0 if flag("ch4_filme_lbd") else 0.0), "images de la nasse diffusées")
		Campaign.count("videos")
		Campaign.log_action("video", "Les images du tir de LBD sur Théo, 17 ans, tournent partout", 6.0)
	if flag("ch4_protege_ines"):
		add_stat("opinion", 2.0, "les street medics saluées")
	await dialogue(D, "zinc")
	if flag("images_sorties") and not flag("ch4_emeute") and (flag("ch4_aide_docu") or rel("lou") >= 25):
		set_flag("docu_lou", true)
		Campaign.log_action("docu", "Lou commence un documentaire sur le mouvement", 0.0)
	bank_casse(4 if flag("ch4_emeute") else (2 if flag("ch4_karim_parti") else 0))
	if flag("images_sorties"):
		news("Tir de LBD sur un lycéen : les images font le tour du pays. Le ministère annonce une enquête.")
	elif flag("ch4_emeute"):
		news("« Nuit d'émeutes » : Canal Continu tourne en boucle sur les vitrines du boulevard des Ormes.")
	music("theme")
	await shot({"from": cam("bar_qg", 3.0, 2.0, 180.0), "to": cam("bar_qg", 20.0, 12.0, 195.0), "look": "bar_qg",
		"dur": 6.0, "fov": 45.0, "fov_to": 55.0})
	await fade_out(1.2)
	cine_end()
