extends Node
## Outil de captures d'écran (nécessite un affichage) :
## godot --path . res://tests/screenshots.tscn -- <dossier_sortie>

var main: Node
var out_dir := "user://shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var q := OS.get_environment("SHOT_QUALITY")
	Game.settings["quality"] = int(q) if q != "" else 1
	main = load("res://scripts/main.gd").new()
	add_child(main)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("capture : ", name)


func _run() -> void:
	await _frames(30)
	await _shot("01_menu")
	if OS.get_environment("SHOT_ONLY_WINDOW") != "":
		main._on_new_game()
		await _frames(5)
		var w: GameSession = main._current
		w._begin_day()
		w.player.global_position = Vector3(-3.5, 0, 3.0)
		w.player.set_look(0.0, deg_to_rad(8))
		await _frames(20)
		await _shot("w1_north_windows")
		get_tree().quit()
		return
	main._on_new_game()
	await _frames(40)
	await _shot("02_intro")
	var s: GameSession = main._current
	s._begin_day()
	await _frames(40)
	await _shot("03_office")
	# Vue vers le bureau et la fenêtre
	s.player.global_position = Vector3(1.0, 0, 4.2)
	s.player.set_look(deg_to_rad(-140), deg_to_rad(-8))
	await _frames(30)
	await _shot("04_office_desk")
	# Salle d'attente
	# Installe directement tous les patients en salle d'attente (sans marche).
	var i := 0
	for x in s.records:
		s._spawn_patient(x)
		x.seat_index = i
		x.body.walk_path([])
		x.body.place_seated(s.clinic.wait_seat(i), Vector3.BACK, GameSession.SEAT_HEIGHT)
		x.status = PatientRecord.Status.WAITING
		i += 1
	s._refresh_info()
	s.player.global_position = Vector3(-1.2, 0, 4.6)
	s.player.set_look(deg_to_rad(50), deg_to_rad(-6))
	await _frames(20)
	await _shot("05_waiting_room")
	s.player.global_position = Vector3(-3.0, 0, 3.0)
	s.player.set_look(deg_to_rad(90), deg_to_rad(-4))
	await _frames(20)
	await _shot("06_reception")
	# Agenda
	s.player.global_position = Vector3(3.0, 0, 0.75)
	s.player.set_look(deg_to_rad(180), deg_to_rad(-25))
	await _frames(10)
	s._open_agenda()
	await _frames(20)
	await _shot("07_agenda")
	var r: PatientRecord = null
	for x in s.records:
		if x.status == PatientRecord.Status.WAITING:
			r = x
			break
	if r:
		s._call_patient(r)
		r.body.walk_path([])
		r.body.place_seated(Clinic.PATIENT_SEAT, Vector3.FORWARD, GameSession.SEAT_HEIGHT)
		s._on_patient_seated(r)
		s.player.global_position = Vector3(2.6, 0, 1.1)
		s.player.set_look(deg_to_rad(180), deg_to_rad(-10))
		await _frames(30)
		await _shot("08_patient_seated")
		r.interact.interact()
		await _frames(30)
		var c := s.consult
		c._ask("debut", Cases.QUESTIONS[0]["text"])
		c._ask("description", Cases.QUESTIONS[1]["text"])
		await _frames(60)
		await _shot("09_consult_questions")
		c._show_tab(1)
		c._exam("constantes")
		c._exam("orl")
		await _frames(60)
		await _shot("10_consult_exams")
		c._show_tab(2)
		c._pick_diagnosis(r.data["diagnosis"])
		c._show_tab(3)
		for t in r.data["treatment"]["good"]:
			c._toggle_treatment(true, t)
		c._toggle_treatment(true, "amoxicilline")
		await _frames(20)
		await _shot("11_consult_rx")
		c._conclude()
		await _frames(40)
		await _shot("12_consult_result")
		c._finish()
		await _frames(20)
	# Patient sur la table d'examen (vue rapprochée)
	s.player.global_position = Vector3(3.2, 0, 3.9)
	s.player.set_look(deg_to_rad(-90), deg_to_rad(-8))
	await _frames(20)
	await _shot("13_exam_area")
	s._open_pause()
	await _frames(20)
	await _shot("14_pause")
	get_tree().quit()
