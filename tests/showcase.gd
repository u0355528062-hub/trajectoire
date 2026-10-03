extends Node3D
## Captures de présentation : personnages réalistes dans le cabinet.

var out_dir := "user://showcase"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.settings["quality"] = 1
	var clinic := Clinic.new()
	add_child(clinic)
	clinic.build()
	clinic.secretary.visible = false
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 62

	# Secrétaire à l'accueil
	var camille := _char("camille_secretaire", "f")
	camille.place_seated(Vector3(-6.4, 0, 3.5), Vector3(1, 0, 0), 0.0, "type")
	# Patients en salle d'attente
	var waiting := [["patrick_morel", "m"], ["monique_lefevre", "f"], ["leo_dubois", "m"], ["claire_dubois", "f"], ["ines_garcia", "f"]]
	for i in waiting.size():
		var c := _char(waiting[i][0], waiting[i][1])
		c.place_seated(clinic.wait_seat(i), Vector3.BACK, 0.0)
		c.look_target = cam
	# Patient dans le cabinet, face au bureau
	var lucas := _char("lucas_bernard", "m")
	lucas.place_seated(Clinic.PATIENT_SEAT, Vector3.FORWARD, 0.0)
	lucas.look_target = cam
	# Patient debout à l'accueil
	var gerard := _char("gerard_roux", "m")
	gerard.place_standing(Clinic.RECEPTION, Vector3.LEFT)
	gerard.look_target = cam
	camille.look_target = gerard

	await get_tree().create_timer(1.0).timeout
	# 1. Salle d'attente
	cam.global_position = Vector3(-0.9, 1.62, 4.6)
	cam.look_at(Vector3(-4.2, 0.95, 0.8))
	await _shot("s1_salle_attente")
	# 2. Accueil
	cam.global_position = Vector3(-3.2, 1.6, 4.8)
	cam.look_at(Vector3(-6.0, 1.15, 3.3))
	await _shot("s2_accueil")
	# 3. Consultation : vue du médecin
	cam.global_position = Vector3(2.75, 1.55, 0.85)
	cam.look_at(Vector3(2.5, 1.15, 2.4))
	lucas.say(null, 3.0)
	await _shot("s3_consultation")
	# 4. Gros plan patient
	cam.fov = 40
	cam.global_position = Vector3(2.55, 1.38, 1.6)
	cam.look_at(Vector3(2.5, 1.28, 2.45))
	await _shot("s4_gros_plan")
	get_tree().quit()


func _char(id: String, g: String) -> Character:
	var c := Character.new()
	add_child(c)
	c.setup(id, g)
	return c


func _shot(n: String) -> void:
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(n + ".png"))
	print("capture : ", n)
