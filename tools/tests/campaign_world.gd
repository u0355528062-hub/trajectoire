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


class Spy extends Node:
	var seen: Array
	func _ready() -> void:
		add_to_group("crowd")
	func on_event(type: String, _d: Dictionary) -> void:
		if type in ["police_sommation", "police_gas", "police_charge", "police_lbd"]:
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
	cases.append({"name": "sommations avant la force", "over": {}, "kind": "sommations"})
	cases.append({"name": "patrouille de passage", "over": {"crowd": {"size": 12, "cortege": false, "gather": "square", "calm": true},
		"police": {"enabled": false}}, "kind": "patrol"})


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
		var near := 0
		for n in crowd.npcs:
			if n.global_position.distance_to(gc) < 16.0:
				near += 1
		if near < crowd.npcs.size() * 0.75:
			_fail("seulement %d / %d personnes autour du lieu de rassemblement" % [near, crowd.npcs.size()])
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
		return ci >= cases.size()
	if phase == "done":
		return true
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
	phase = "done"
	WorldSetup.sandbox = {}
	Campaign.reset()
	if errors.is_empty():
		print("RÉSULTAT : OK (%d mondes)" % cases.size())
	else:
		print("RÉSULTAT : ÉCHEC (%d erreurs)" % errors.size())
	quit(0 if errors.is_empty() else 1)
