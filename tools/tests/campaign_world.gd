extends SceneTree
## Monde paramétrable (module Fondation B) : chaque chapitre de Story.CHAPTERS et quelques réglages de bac à sable
## construisent le bon monde — taille et composition de la foule, cortège ou groupes, thème des pancartes, police
## (absente, cordon, ligne, palier maximal, tension de départ et figée), passants, habitants, point de départ.
## Puis : sommations réglementaires avant tout usage de la force, et patrouille qui traverse le boulevard.
## Les mondes sont construits via WorldSetup.sandbox (sans directeur de chapitre : on teste le monde, pas le scénario).

const SETTLE := 20                  # images avant les vérifications
var cases: Array = []
var ci := -1
var frame := 0
var main: Node
var crowd: Crowd
var police: Police
var ten: Tension
var errors: Array[String] = []
var orig_size := -1
var phase := "build"
# --- sommations / patrouille
var events: Array = []
var car: PoliceVehicle
var car_x0 := 0.0
var car_min_x := INF
var car_gone := false
# --- menus (écran titre, pause) : étapes [nom, image de déclenchement]
var mstep := 0
var mframe := 0
var main_before: Node


class Spy extends Node:
	var seen: Array
	func _ready() -> void:
		add_to_group("crowd")
	func on_event(type: String, _d: Dictionary) -> void:
		# dispersion par la force (les ripostes ciblées à un jet de projectile ne comptent pas)
		if type in ["police_sommation", "police_gas", "police_charge"]:
			seen.append(type)


func _initialize() -> void:
	Campaign.active = false
	Campaign.reset()
	Campaign.set_stat("mobilisation", 57.0)
	cases.append({"name": "bac à sable d'origine", "over": {}, "kind": "orig"})
	for ch in Story.CHAPTERS:
		cases.append({"name": "chapitre « %s »" % str(ch.get("id", "?")), "over": ch})
	cases.append({"name": "bac à sable : petite foule calme au square, sans police", "over": {
		"crowd": {"size": 12, "cortege": false, "bloc": 0, "medic": false, "press": false, "theme": "prix", "calm": true, "gather": "square"},
		"police": {"enabled": false}, "civilians": {"density": 0.5}, "residents": false, "spawn": "square"}})
	cases.append({"name": "bac à sable : foule « mobilisation », cordon déplacé, palier 2, tension figée", "over": {
		"crowd": {"size": "mobilisation", "bloc": 3, "theme": "prix"},
		"police": {"line_x": 46.0, "max_stage": 2, "start_tension": 0.9, "tension_frozen": true, "patrol": false},
		"civilians": {"density": 1.5}}})
	cases.append({"name": "bac à sable : grande foule, police sans cordon", "over": {
		"crowd": {"size": 150}, "police": {"cordon": false, "start_tension": 0.2}}})
	cases.append({"name": "patrouille de passage", "over": {"crowd": {"size": 12, "cortege": false, "gather": "square", "calm": true},
		"police": {"enabled": false}}, "kind": "patrol"})
	cases.append({"name": "sommations avant la force", "over": {}, "kind": "sommations"})


func _next_case() -> void:
	ci += 1
	frame = 0
	if ci >= cases.size():
		_finish()
		return
	var c: Dictionary = cases[ci]
	WorldSetup.sandbox = (c["over"] as Dictionary).duplicate(true)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	crowd = null
	police = null
	ten = null
	for n in main.get_children():
		if n is Crowd: crowd = n
		if n is Police: police = n
		if n is Tension: ten = n
	events = []
	var spy := Spy.new()
	spy.seen = events
	main.add_child(spy)
	phase = "run"


func _fail(msg: String) -> void:
	errors.append("%s : %s" % [str(cases[ci]["name"]), msg])
	print("ÉCHEC : ", errors[-1])


func _check_world() -> void:
	var c: Dictionary = cases[ci]
	var cfg := WorldSetup.merge(WorldSetup.DEFAULT, c["over"])
	var cc: Dictionary = cfg["crowd"]
	var pc: Dictionary = cfg["police"]
	var roles := {}
	var signs := 0
	var themed := 0
	for n in crowd.npcs:
		roles[n.role] = int(roles.get(n.role, 0)) + 1
		if n.sign_node != null:
			signs += 1
			if n.sign_node.find_child("Slogan", true, false) != null:
				themed += 1
	if c.get("kind", "") == "orig":
		orig_size = crowd.npcs.size()
		if not crowd.is_original():
			_fail("la foule d'origine n'est pas reconnue comme telle")
	# taille
	var sz: Variant = cc["size"]
	var want := orig_size
	if sz is String:
		want = mini(int(Campaign.stat(sz)), Crowd.MAX_SIZE)
	elif int(sz) >= 0:
		want = mini(int(sz), Crowd.MAX_SIZE)
	if crowd.npcs.size() != want:
		_fail("foule de %d au lieu de %d" % [crowd.npcs.size(), want])
	# composition
	if not bool(cc["cortege"]) and int(roles.get("march", 0)) > 0:
		_fail("%d marcheurs sans cortège" % int(roles.get("march", 0)))
	if bool(cc["cortege"]) and want >= 10 and int(roles.get("march", 0)) == 0:
		_fail("cortège demandé mais personne ne défile")
	if int(cc["bloc"]) >= 0 and int(roles.get("bloc", 0)) != mini(int(cc["bloc"]), want):
		_fail("bloc de %d au lieu de %d" % [int(roles.get("bloc", 0)), int(cc["bloc"])])
	if not bool(cc["medic"]) and roles.has("medic"):
		_fail("des médics alors qu'il n'en faut pas")
	if not bool(cc["press"]) and roles.has("press"):
		_fail("des journalistes alors qu'il n'en faut pas")
	if str(cc["theme"]) == "prix" and signs > 0 and themed != signs:
		_fail("pancartes au thème « prix » : %d / %d" % [themed, signs])
	if str(cc["theme"]) != "prix" and themed > 0:
		_fail("pancartes « prix » hors thème")
	if crowd.calm != bool(cc.get("calm", false)):
		_fail("réglage « calm » non appliqué")
	var gather := str(cc.get("gather", ""))
	if gather != "" and not crowd.npcs.is_empty():
		var gc := crowd.gather_center()
		# le cortège suit son parcours : seuls les autres se rassemblent
		var near := 0
		var still := 0
		for n in crowd.npcs:
			if n.role == "march":
				continue
			still += 1
			if n.global_position.distance_to(gc) < 16.0:
				near += 1
		if still > 0 and near < still * 0.75:
			_fail("seulement %d / %d personnes autour du lieu de rassemblement" % [near, still])
	# police
	if not bool(pc["enabled"]):
		if not police.cops.is_empty() or not police.vehicles.is_empty():
			_fail("police désactivée mais %d policiers, %d véhicules" % [police.cops.size(), police.vehicles.size()])
	elif bool(pc["cordon"]):
		if police.cops.size() < 9:
			_fail("cordon incomplet (%d policiers)" % police.cops.size())
		if absf(police.street_x - float(pc["line_x"])) > 0.01:
			_fail("ligne à x=%.1f au lieu de %.1f" % [police.street_x, float(pc["line_x"])])
		if police.cops[0].global_position.distance_to(Vector3(float(pc["line_x"]), 0, Police.ROAD_Z)) > 6.0:
			_fail("le cordon n'est pas sur sa ligne")
	elif police.cops.size() > 0 and float(pc["start_tension"]) < Tension.STAGES[1]:
		_fail("pas de cordon demandé mais %d policiers au départ" % police.cops.size())
	var patrol_cars := 0
	for v in police.vehicles:
		if v.kind == "car" and v.is_parked():
			patrol_cars += 1
	if bool(pc["enabled"]) and bool(pc["cordon"]) and float(pc["start_tension"]) <= 0.0 and patrol_cars != (1 if bool(pc["patrol"]) else 0):
		_fail("voiture de patrouille garée : %d" % patrol_cars)
	if ten.max_stage != int(pc["max_stage"]):
		_fail("palier maximal %d au lieu de %d" % [ten.max_stage, int(pc["max_stage"])])
	if ten.stage > int(pc["max_stage"]) or police.stage > int(pc["max_stage"]):
		_fail("palier %d / police %d au-delà du maximum %d" % [ten.stage, police.stage, int(pc["max_stage"])])
	var st := float(pc["start_tension"])
	if st > 0.0 and absf(ten.value - minf(st, ten.ceiling())) > 0.03:
		_fail("tension de départ %.2f au lieu de %.2f" % [ten.value, minf(st, ten.ceiling())])
	if ten.frozen != bool(pc["tension_frozen"]):
		_fail("tension figée : %s" % str(ten.frozen))
	if not bool(pc["enabled"]):
		# aucun renfort, même si ça chauffe
		ten.set_value(0.7)
	# passants, habitants, départ
	var civ: Civilians = main.get_node_or_null("Civilians")
	if civ == null or absf(civ.density - float((cfg["civilians"] as Dictionary)["density"])) > 0.001:
		_fail("densité de passants non appliquée")
	var has_res := main.get_node_or_null("Residents") != null
	if has_res != bool(cfg["residents"]):
		_fail("habitants : %s au lieu de %s" % [str(has_res), str(cfg["residents"])])
	var spawn := str(cfg["spawn"])
	var want_pos := Quartier.spot(spawn) if spawn != "" else Vector3.ZERO
	var pp: Vector3 = main.get("player").global_position
	if Vector2(pp.x - want_pos.x, pp.z - want_pos.z).length() > 1.5:
		_fail("joueur en %s au lieu de %s" % [str(pp.snapped(Vector3.ONE * 0.1)), str(want_pos)])
	print("  %-70s foule %3d %s | policiers %2d | palier max %d | tension %.2f%s" % [str(c["name"]), crowd.npcs.size(),
		str(roles), police.cops.size(), ten.max_stage, ten.value, " (figée)" if ten.frozen else ""])


func _process(_d: float) -> bool:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if phase == "build":
		_next_case()
		return phase == "done"
	if phase == "done":
		return true
	if phase == "menus":
		_menus()
		return false
	frame += 1
	var kind := str(cases[ci].get("kind", ""))
	if frame == SETTLE:
		_check_world()
		if kind == "sommations":
			ten.set_value(0.4)
		elif kind == "patrol":
			car = police.patrol_pass(Quartier.spot("square"), 2.0)
			car_x0 = car.global_position.x
	var end := SETTLE + 60
	if kind == "sommations":
		end = SETTLE + 30 * 45
		if frame > SETTLE and events.count("police_sommation") >= 3 and frame > SETTLE + 30 * 30:
			end = frame
	elif kind == "patrol":
		end = SETTLE + 30 * 120
		if is_instance_valid(car):
			car_min_x = minf(car_min_x, car.global_position.x)
		elif frame > SETTLE:
			car_gone = true
			end = frame
	elif not bool((WorldSetup.merge(WorldSetup.DEFAULT, cases[ci]["over"])["police"] as Dictionary)["enabled"]):
		end = SETTLE + 150
		if frame == end and (not police.cops.is_empty() or police.stage > 0):
			_fail("des renforts sont venus alors que la police est désactivée")
	if frame >= end:
		if kind == "sommations":
			var first_force := -1
			for i in events.size():
				if events[i] != "police_sommation":
					first_force = i
					break
			var before := events.slice(0, first_force if first_force >= 0 else events.size()).count("police_sommation")
			print("  sommations : %s" % str(events))
			if events.count("police_sommation") < 3:
				_fail("seulement %d sommations" % events.count("police_sommation"))
			if first_force >= 0 and before < 3:
				_fail("usage de la force après %d sommation(s)" % before)
		elif kind == "patrol":
			print("  patrouille : x %.0f -> %.0f, partie : %s" % [car_x0, car_min_x, str(car_gone)])
			if not car_gone or car_min_x > -60.0:
				_fail("la patrouille n'a pas traversé le boulevard")
		main.queue_free()
		current_scene = null
		phase = "build"
	return false


func _finish() -> void:
	if phase != "menus":
		phase = "menus"
		mstep = 0
		mframe = 0
		Campaign.autoplay = true            # les tests n'écrasent pas la sauvegarde du joueur
		TitleScreen.force_show = true
		WorldSetup.sandbox = {}
		main = load("res://main.tscn").instantiate()
		root.add_child(main)
		current_scene = main
		return
	phase = "done"
	WorldSetup.sandbox = {}
	Campaign.reset()
	if errors.is_empty():
		print("RÉSULTAT : OK (%d mondes)" % cases.size())
	else:
		print("RÉSULTAT : ÉCHEC (%d erreurs)" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _title() -> TitleScreen:
	var pm: PauseMenu = current_scene.get_node_or_null("PauseMenu") if current_scene else null
	return pm.title if pm != null and is_instance_valid(pm.title) else null


func _pause() -> PauseMenu:
	return current_scene.get_node_or_null("PauseMenu") if current_scene else null


func _crowd_size() -> int:
	for n in current_scene.get_children():
		if n is Crowd:
			return (n as Crowd).npcs.size()
	return -1


## Parcours des menus : accueil -> bac à sable sans rechargement -> retour au menu -> bac à sable réglé (rechargé)
## -> retour au menu -> nouvelle campagne -> « Recommencer le chapitre » -> « Quitter vers le menu »
func _menus() -> void:
	mframe += 1
	if mframe < 25:
		return
	mframe = 0
	var t := _title()
	match mstep:
		0:
			if t == null or not t.is_showing():
				_menu_fail("l'écran titre n'apparaît pas au lancement")
				return
			if not t._cols.has("campaign") or not t._cols.has("sandbox"):
				_menu_fail("colonnes Campagne / Bac à sable absentes")
			main_before = current_scene
			t._show_col("sandbox")
			t._launch_sandbox(SandboxMenu.to_sandbox(SandboxMenu.DEFAULTS))
		1:
			if current_scene != main_before:
				_menu_fail("le bac à sable d'origine a rechargé la scène")
			mframe = -40               # le fondu de sortie de l'accueil dure ~1,3 s
		2:
			if t != null:
				_menu_fail("l'écran titre est resté après « Bac à sable »")
			_pause()._to_title()
		3:
			if t == null or not t.is_showing():
				_menu_fail("« Quitter vers le menu » ne ramène pas l'écran titre")
				return
			t._launch_sandbox({"crowd": {"size": 25}, "tod": "nuit", "police": {"enabled": false}})
			mframe = -20
		4:
			if t != null:
				_menu_fail("l'écran titre réapparaît après un lancement de bac à sable")
			if _crowd_size() != 25:
				_menu_fail("bac à sable réglé : foule de %d au lieu de 25" % _crowd_size())
			if SandboxMenu.from_sandbox(WorldSetup.sandbox)["size"] != 25:
				_menu_fail("le menu bac à sable ne relit pas ses derniers réglages")
			_pause()._to_title()
		5:
			if t == null:
				_menu_fail("pas d'écran titre pour lancer la campagne")
				return
			t._new_campaign()
			mframe = -10
		6:
			if t != null or not Campaign.active or current_scene.get_node_or_null("ChapterDirector") == null:
				_menu_fail("« Nouvelle partie » : campagne non lancée (titre %s, active %s)" % [str(t != null), str(Campaign.active)])
			Campaign.chapter = 0
			Campaign.begin_chapter()
			_pause()._restart_chapter()
		7:
			if t != null or not Campaign.active or Campaign.chapter != 0:
				_menu_fail("« Recommencer le chapitre » : titre %s, active %s, chapitre %d" % [str(t != null), str(Campaign.active), Campaign.chapter])
			_pause()._to_title()
		8:
			if t == null or Campaign.active:
				_menu_fail("« Quitter vers le menu » en campagne : titre %s, active %s" % [str(t != null), str(Campaign.active)])
			print("  menus : accueil, bac à sable, retour au menu, campagne, recommencer le chapitre : vus")
			Campaign.reset()
			Campaign.active = false
			Campaign.autoplay = false
			TitleScreen.force_show = false
			_finish()
			return
	mstep += 1


func _menu_fail(msg: String) -> void:
	errors.append("menus (étape %d) : %s" % [mstep, msg])
	print("ÉCHEC : ", errors[-1])
