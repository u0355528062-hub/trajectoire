extends SceneTree
## Carte de la campagne (module Carte) : chaque lieu de l'histoire (Quartier.SPOTS) est sur le sol praticable, hors
## obstacles, atteignable sur la grille de navigation depuis le départ, et les vitrines nommées sont devant leur lieu ;
## les plans de caméra des chapitres (cam("lieu", …)) restent à l'air libre avec la cible en vue (aucune façade entre
## les deux) ; le décor attendu par le kit est là (étiquettes de prix, piles de tracts, panneaux d'affichage libre,
## totem de la station, mairie) ; la patrouille de passage traverse malgré le cordon qui barre la chaussée.
## Sans affichage : tools/dev/gd --headless --path . --fixed-fps 30 -s tools/tests/campaign_map.gd

const CAM_RE := "cam\\(\"(\\w+)\",\\s*([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)\\)"
var frame := 0
var main: Node
var crowd: Crowd
var police: Police
var errors: Array[String] = []
var car: PoliceVehicle
var car_min_x := INF
var car_t := 0


func _initialize() -> void:
	Campaign.active = false
	WorldSetup.sandbox = {"crowd": {"size": 20, "cortege": false, "gather": "square", "calm": true},
		"police": {"enabled": true, "cordon": true, "max_stage": 1, "start_tension": 0.0, "tension_frozen": true}}
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main


func _fail(msg: String) -> void:
	errors.append(msg)
	print("ÉCHEC : ", msg)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 10:
		for n in main.get_children():
			if n is Crowd: crowd = n
			if n is Police: police = n
		_check_spots()
		_check_storefronts()
		_check_cameras()
		_check_kit()
		car = police.patrol_pass(Quartier.spot("square"), 2.0)
		print("patrouille : départ %s (cordon x = %.0f)" % [str(car.global_position), police.line_c.x])
	if frame > 10:
		car_t += 1
		if is_instance_valid(car):
			car_min_x = minf(car_min_x, car.global_position.x)
		if not is_instance_valid(car) or car_t > 30 * 150:
			print("patrouille : x min %.0f, partie : %s, %.0f s" % [car_min_x, str(not is_instance_valid(car)), car_t / 30.0])
			if is_instance_valid(car) or car_min_x > -100.0:
				_fail("la patrouille n'a pas traversé le quartier (bloquée par le cordon ?)")
			_finish()
			return true
	return false


func _space() -> PhysicsDirectSpaceState3D:
	return (main as Node3D).get_world_3d().direct_space_state


func _check_spots() -> void:
	crowd.rebuild_nav()
	var from := Quartier.spot("depart")
	for id: String in Quartier.SPOTS:
		var p := Quartier.spot(id)
		if not Quartier.walkable(p, 0.3):
			_fail("%s %s : pas sur le sol praticable" % [id, str(p)])
		if Quartier.walk_clamp(p).distance_to(p) > 0.01:
			_fail("%s : ramené ailleurs par Quartier.walk_clamp" % id)
		if not crowd.nav.is_free(p):
			_fail("%s %s : cellule bloquée sur la grille de navigation" % [id, str(p)])
		var ids := crowd.nav.astar.get_id_path(crowd.nav.cell(from), crowd.nav.cell(p))
		if ids.is_empty() or crowd.nav.world(ids[ids.size() - 1]).distance_to(p) > 1.0:
			_fail("%s : pas de chemin depuis le départ" % id)
		# rien de solide sur place (immeuble, mobilier, véhicule garé)
		var q := PhysicsShapeQueryParameters3D.new()
		var sh := CapsuleShape3D.new()
		sh.radius = 0.35
		sh.height = 1.6
		q.shape = sh
		q.transform = Transform3D(Basis(), p + Vector3(0, 0.95, 0))
		q.collision_mask = 1
		q.exclude = [(main.get("player") as CollisionObject3D).get_rid()]
		var hits := _space().intersect_shape(q, 4)
		if not hits.is_empty():
			_fail("%s : occupé par %s" % [id, str((hits[0]["collider"] as Node).name)])
	print("lieux : %d vérifiés" % Quartier.SPOTS.size())


func _check_storefronts() -> void:
	var found := {}
	for s in root.get_tree().get_nodes_in_group("shops"):
		var sh := s as Shop
		if sh.frontage.has("story"):
			found[str(sh.frontage["story"])] = sh
	for id: String in MapStory.STOREFRONTS:
		if not found.has(id):
			_fail("vitrine « %s » absente" % id)
			continue
		var sh: Shop = found[id]
		var sf: Dictionary = MapStory.STOREFRONTS[id]
		if sh.kind != sf["kind"]:
			_fail("vitrine « %s » : commerce %s au lieu de %s" % [id, sh.kind, sf["kind"]])
		var fp := sh.front_point()
		var d := Vector2(fp.x - Quartier.spot(id).x, fp.z - Quartier.spot(id).z).length()
		if d > 3.0:
			_fail("lieu « %s » à %.1f m de sa vitrine (%s)" % [id, d, str(fp)])
		print("vitrine %s : %s, lieu à %.1f m" % [id, sf["name"], d])


func _check_cameras() -> void:
	var re := RegEx.new()
	re.compile(CAM_RE)
	var n := 0
	for f in DirAccess.get_files_at("res://scripts/story"):
		if not f.begins_with("ch_") or not f.ends_with(".gd"):
			continue
		var txt := FileAccess.get_file_as_string("res://scripts/story/" + f)
		for m in re.search_all(txt):
			var id := m.get_string(1)
			if not Quartier.SPOTS.has(id):
				continue
			var t := Quartier.spot(id)
			var a := deg_to_rad(float(m.get_string(4)))
			var dist := float(m.get_string(2))
			var raw := t + Vector3(sin(a) * dist, float(m.get_string(3)), cos(a) * dist)
			var c := Quartier.camera_point(t, raw)
			n += 1
			if not Quartier.open_air(c):
				_fail("%s : plan %s dans un immeuble (%s)" % [f, m.get_string(0), str(c)])
				continue
			var rq := PhysicsRayQueryParameters3D.create(c, t + Vector3(0, 1.2, 0), 1)
			var hit := _space().intersect_ray(rq)
			if hit and _in_building(hit["collider"]):
				_fail("%s : plan %s, une façade cache la cible" % [f, m.get_string(0)])
	print("plans de caméra des chapitres : %d vérifiés" % n)


func _in_building(n: Object) -> bool:
	var node := n as Node
	while node != null:
		if node is ParisBuilding or node is MapStation or node is MapMairie:
			return true
		node = node.get_parent()
	return false


func _near(group: String, p: Vector3, r: float) -> int:
	var k := 0
	for n in root.get_tree().get_nodes_in_group(group):
		if n is Node3D and (n as Node3D).global_position.distance_to(p) < r:
			k += 1
	return k


func _check_kit() -> void:
	var tags := _near("price_tags", Quartier.spot("supermarche"), 6.0)
	var totem := _near("price_tags", Quartier.spot("station_service"), 14.0)
	var tracts := _near("tract_stacks", Quartier.spot("bar_qg"), 3.4)
	var boards := root.get_tree().get_nodes_in_group("affichage_libre").size()
	print("décor : %d étiquettes à la supérette, %d prix au totem, %d pile(s) de tracts au Zinc, %d panneau(x) d'affichage libre" % [tags, totem, tracts, boards])
	if tags < 6:
		_fail("étiquettes de prix de la supérette : %d" % tags)
	if totem < 4:
		_fail("totem de prix de la station : %d" % totem)
	if tracts < 1:
		_fail("pas de pile de tracts au QG")
	if boards < MapStory.BOARDS.size():
		_fail("panneaux d'affichage libre : %d" % boards)
	for b in root.get_tree().get_nodes_in_group("affichage_libre"):
		if not b is CollisionObject3D:
			_fail("panneau d'affichage libre sans collision (le kit le vise au rayon)")
	if main.find_child("Mairie", true, false) == null:
		_fail("mairie absente")


func _finish() -> void:
	print("RÉSULTAT : ", "OK" if errors.is_empty() else "ÉCHEC (%d)" % errors.size())
	main.queue_free()
	WorldSetup.sandbox = {}
