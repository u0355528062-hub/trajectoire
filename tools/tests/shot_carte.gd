extends SceneTree
## Captures du module Carte (rendu) : chaque lieu de l'histoire, de jour puis de nuit, en une seule exécution, avec
## les plans de chapitre qui posaient problème (caméra calée sur un lieu, passée par Quartier.camera_point).
##   tools/dev/gd --render --path . --resolution 1280x720 -s tools/tests/shot_carte.gd -- <dossier> [matin nuit …]
##   [vues=zinc,mairie]
var out := "/tmp/carte"
var cam: Camera3D
var only: PackedStringArray = []          # « vues=zinc,mairie » : seulement ces vues

## [nom, lieu, distance, hauteur, lacet (degrés, 0 = côté +Z), hauteur visée]
const VIEWS := [
	["prologue_ouverture", "supermarche", 34.0, 11.0, 130.0, 1.2],
	["prologue_approche", "supermarche", 18.0, 4.5, 155.0, 1.2],
	["supermarche", "supermarche", 6.5, 1.7, 20.0, 1.6],
	["zinc", "bar_qg", 7.0, 2.4, 160.0, 1.4],
	["zinc_large", "bar_qg", 16.0, 6.0, 200.0, 1.2],
	["boulangerie", "boulangerie", 8.0, 2.0, 200.0, 2.0],
	["pharmacie", "pharmacie", 8.0, 2.0, 160.0, 2.0],
	["banque", "banque", 9.0, 2.0, 20.0, 1.6],
	["morris", "morris", 6.0, 2.2, 160.0, 1.8],
	["square", "square", 14.0, 4.0, 195.0, 1.0],
	["metro", "metro", 9.0, 2.0, 200.0, 1.5],
	["station", "station_service", 16.0, 5.0, 30.0, 1.5],
	["station_totem", "station_service", 10.0, 1.7, 15.0, 3.0],
	["rue_sud", "rue_sud", 12.0, 3.0, 0.0, 2.0],
	["rue_nord", "rue_nord", 12.0, 3.0, 180.0, 2.0],
	["carrefour", "carrefour_ouest", 18.0, 12.0, 60.0, 1.0],
	["parvis", "parvis_mairie", 22.0, 1.6, 270.0, 4.0],
	["mairie", "mairie", 14.0, 2.0, 250.0, 6.0],
	["boulevard_haut", "abribus", 40.0, 16.0, 250.0, 0.0],
]


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("captures ignorées : pas de rendu (lancer avec --render)")
		quit()
		return
	var a := OS.get_cmdline_user_args()
	var tods: Array[String] = []
	for i in a.size():
		if i == 0:
			out = a[0]
		elif a[i].begins_with("vues="):
			only = a[i].substr(5).split(",")
		else:
			tods.append(a[i])
	if tods.is_empty():
		tods = ["matin", "nuit"]
	DirAccess.make_dir_recursive_absolute(out)
	_run(tods)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run(tods: Array[String]) -> void:
	for tod in tods:
		WorldSetup.sandbox = {"tod": tod, "weather": "sec", "crowd": {"size": 10, "cortege": false, "gather": "square",
			"calm": true}, "police": {"enabled": false}, "civilians": {"density": 0.4}}
		var main: Node = load("res://main.tscn").instantiate()
		root.add_child(main)
		current_scene = main
		await frames(12)
		for c in main.get_children():
			if c is CanvasLayer:
				(c as CanvasLayer).visible = false
		cam = Camera3D.new()
		cam.far = 600.0
		main.add_child(cam)
		for v in VIEWS:
			if not only.is_empty() and not only.has(v[0]):
				continue
			var t := Quartier.spot(v[1])
			var y := deg_to_rad(float(v[4]))
			var p := Quartier.camera_point(t, t + Vector3(sin(y) * float(v[2]), float(v[3]), cos(y) * float(v[2])))
			cam.fov = 55.0
			cam.global_position = p
			cam.look_at(t + Vector3(0, float(v[5]), 0))
			cam.current = true
			await frames(6)
			root.get_texture().get_image().save_png("%s/%s_%s.png" % [out, tod, v[0]])
			print("SHOT ", tod, " ", v[0])
		main.queue_free()
		await frames(4)
	WorldSetup.sandbox = {}
	quit()
