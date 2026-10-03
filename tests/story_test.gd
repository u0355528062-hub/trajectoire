extends Node
## Test automatisé du mode Histoire : joue les 3 journées de bout en bout
## avec la vraie logique de jeu (appel des patients, interrogatoire,
## déplacements vers la table, examens physiques sur les zones du corps,
## diagnostic et ordonnance, appel du SAMU, bilans de fin de journée).
## Lancement : godot --headless --path . res://tests/story_test.tscn

var main: Node
var failures: Array[String] = []
var exams_done := 0


func _ready() -> void:
	Engine.time_scale = 6.0
	main = load("res://scripts/main.gd").new()
	add_child(main)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		push_error("ÉCHEC : " + msg)


func _wait_until(cond: Callable, max_frames: int, label: String) -> bool:
	for i in range(max_frames):
		if cond.call():
			return true
		await get_tree().process_frame
	_check(false, "délai dépassé : " + label)
	return false


func _session() -> GameSession:
	return main._current as GameSession


func _run() -> void:
	await _frames(10)
	_check(main._current is MainMenu, "le menu principal doit s'afficher")
	main._on_new_game()
	await _frames(10)
	for day in range(1, Cases.day_count() + 1):
		await _play_day(day)
		if not failures.is_empty():
			break
	_finish()


func _play_day(day: int) -> void:
	var s := _session()
	_check(s != null, "session jour %d" % day)
	if s == null:
		return
	_check(Game.day == day, "numéro de jour %d (obtenu %d)" % [day, Game.day])
	s._begin_day()
	await _frames(3)
	_check(s.state == GameSession.State.PLAY, "état PLAY après l'intro")
	var vp := get_viewport().get_visible_rect().size
	for c in [s.hud, s.dialogue, s.exam_view, s.software, s.wheel]:
		_check(c.size.is_equal_approx(vp), "l'interface %s couvre l'écran (%s)" % [c.get_class(), c.size])
	var guard := 0
	while not s._all_done() and guard < 600:
		guard += 1
		if s.state == GameSession.State.PLAY and s.current == null:
			Game.advance(2.0)
		await _frames(3)
		if s.current == null and s.state == GameSession.State.PLAY:
			var next := s._next_waiting()
			if next:
				# Appel via le logiciel du bureau, comme le joueur.
				s._open_computer()
				await _frames(2)
				_check(s.software.visible, "logiciel ouvert")
				s.software._call(next)
				await _frames(2)
				_check(not s.software.visible and s.state == GameSession.State.PLAY, "logiciel fermé après l'appel")
				await _wait_until(func(): return next.status == PatientRecord.Status.IN_OFFICE, 4000, "patient installé (%s)" % next.case_id)
				await _consult(s, next)
		await _wait_until(func(): return s.state == GameSession.State.PLAY or s.state == GameSession.State.REPORT, 2000, "retour en jeu")
	_check(s._all_done(), "tous les patients vus le jour %d" % day)
	await _wait_until(func(): return s.state == GameSession.State.REPORT, 3000, "bilan de fin de journée")
	_check(Game.day_results.size() == s.records.size(), "un résultat par patient")
	var last := day >= Cases.day_count()
	s._on_report_continue(last)
	await _frames(10)


func _spot(r: PatientRecord, ids: Array) -> Hotspot:
	for h in r.hotspots:
		if h.spot_id in ids:
			return h
	return null


func _move(s: GameSession, r: PatientRecord, where: String, expect: String) -> void:
	s._move_patient(r, where)
	await _wait_until(func(): return r.position == expect and not r.body.is_busy(), 3000, "patient %s → %s" % [r.case_id, expect])


func _consult(s: GameSession, r: PatientRecord) -> void:
	# Interrogatoire par le dialogue
	r.talk.interact()
	await _frames(2)
	_check(s.state == GameSession.State.DIALOGUE and s.dialogue.visible, "dialogue ouvert (%s)" % r.case_id)
	for q in Cases.QUESTIONS.slice(0, 5):
		s._on_dialogue_option("q:" + q["id"])
		await _frames(1)
	for i in r.data.get("extra_questions", []).size():
		s._on_dialogue_option("x:%d" % i)
	_check(r.questions.size() >= 5, "questions enregistrées (%s)" % r.case_id)
	s.dialogue.close()
	await _frames(2)
	_check(s.state == GameSession.State.PLAY, "dialogue fermé (%s)" % r.case_id)

	# Examens clés : on choisit la première alternative et on installe le patient.
	var wanted: Array[String] = []
	for k in r.data.get("key_exams", []):
		wanted.append(String(k).split("|")[0])
	if "temp" not in wanted:
		wanted.append("temp")
	# Ordre : assis d'abord, allongé ensuite.
	wanted.sort_custom(func(a, b): return int(ExamDB.EXAMS[a]["pos"] == "lying") < int(ExamDB.EXAMS[b]["pos"] == "lying"))
	for ex in wanted:
		var e: Dictionary = ExamDB.EXAMS[ex]
		var need: String = e["pos"]
		if need == "lying" and r.position != "lying":
			if r.position == "chair":
				await _move(s, r, "table", "table")
			await _move(s, r, "lie", "lying")
		elif need == "not_lying" and r.position == "lying":
			await _move(s, r, "sit", "table")
		var h := _spot(r, e["spots"]) if not ("*" in e["spots"]) else r.hotspots[0]
		_check(h != null, "zone trouvée pour %s" % ex)
		if h == null:
			continue
		_check(s._spot_allowed(h), "zone autorisée %s (%s, position %s)" % [h.spot_id, r.case_id, r.position])
		var found := ExamDB.exam_for(e["tool"], h.spot_id, r.position)
		_check(found == ex, "outil %s sur %s → %s (obtenu %s)" % [e["tool"], h.spot_id, ex, found])
		s._on_exam_performed(h, ex)
		await _wait_until(func(): return s.state != GameSession.State.CUTSCENE, 1500, "fin de séquence d'examen")
		if s.state == GameSession.State.EXAM_VIEW:
			await _frames(3)
			s.exam_view.close()
		await _frames(2)
		_check(r.exams.has(ex), "examen %s enregistré (%s)" % [ex, r.case_id])
		exams_done += 1
	if r.position == "lying":
		await _move(s, r, "chair", "chair")

	# Ordinateur : diagnostic + ordonnance, comme le joueur.
	s._open_computer()
	await _frames(2)
	_check(s.software.visible and s.software.page == "dossier", "logiciel ouvert sur le dossier (%s)" % r.case_id)
	s.software.show_page("diagnostic")
	s.software._pick_diag(r, r.data["diagnosis"])
	s.software.show_page("ordonnance")
	for t in r.data["treatment"]["good"]:
		s.software._toggle_rx(true, r, t)
	s.software.show_page("cloture")
	await _frames(2)
	s.software._conclude(r)
	await _frames(2)
	_check(not r.result.is_empty(), "résultat calculé (%s)" % r.case_id)
	_check(r.result.get("diagnosis_ok", false), "diagnostic exact (%s)" % r.case_id)
	_check(r.result.get("grade", "F") in ["A", "B"], "note A/B pour une prise en charge correcte (%s : %s, %s)" % [r.case_id, r.result.get("grade"), r.result.get("notes")])
	s.software.request_close()
	await _frames(3)
	await _wait_until(func(): return r.status == PatientRecord.Status.DONE, 3000, "patient parti (%s)" % r.case_id)
	await _wait_until(func(): return s.state == GameSession.State.PLAY, 3000, "retour en jeu après consultation")
	_check(s.current == null, "cabinet libéré")


func _finish() -> void:
	# Cas limites de l'évaluation
	var miss := Cases.evaluate("thoracique", "rgo", ["ipp"], [], ["q:debut"], 10.0, 0.0)
	_check(miss["critical_miss"] and miss["grade"] == "F", "urgence manquée notée F")
	var abx := Cases.evaluate("rhino", "rhinopharyngite", ["paracetamol", "lavage_nez", "surveillance", "amoxicilline"], ["orl", "temp", "pulmo_d"], ["q:debut"], 8.0, 0.0)
	_check(abx["notes"].size() > 0, "antibiotique inutile pénalisé")
	var no_tdr := Cases.evaluate("angine", "angine_strepto", ["amoxicilline", "paracetamol"], ["orl"], [], 8.0, 0.0)
	_check(no_tdr["notes"].size() > 0, "absence de TROD signalée")
	for id in Cases.CASES:
		var c: Dictionary = Cases.CASES[id]
		_check(Cases.DIAGNOSES.has(c["diagnosis"]), "diagnostic connu (%s)" % id)
		for d in c["differentials"]:
			_check(Cases.DIAGNOSES.has(d), "différentiel connu %s (%s)" % [d, id])
		for t in c["options"]:
			_check(Cases.TREATMENTS.has(t), "traitement connu %s (%s)" % [t, id])
		for t in c["treatment"]["good"]:
			_check(t in c["options"], "traitement attendu proposé %s (%s)" % [t, id])
		for k in c.get("key_exams", []):
			for a in String(k).split("|"):
				_check(ExamDB.EXAMS.has(a), "examen clé connu %s (%s)" % [a, id])
		for f in c.get("findings", {}).keys():
			_check(ExamDB.EXAMS.has(f), "résultat d'examen connu %s (%s)" % [f, id])
		for p in c.get("pain", []):
			_check(ExamDB.SPOTS.has(p), "zone douloureuse connue %s (%s)" % [p, id])
		var pdata: Dictionary = c["patient"]
		_check(ResourceLoader.exists("res://assets/characters/%s/%s.scn" % [pdata["avatar"], pdata["avatar"]]), "avatar présent (%s)" % id)
	if failures.is_empty():
		print("STORY TEST OK — %d patients vus, %d examens physiques, réputation %.1f, honoraires %d €" % [Game.total_seen, exams_done, Game.reputation, int(Game.money)])
		get_tree().quit(0)
	else:
		print("STORY TEST FAILED (%d)" % failures.size())
		for f in failures.slice(0, 40):
			print("  - " + f)
		get_tree().quit(1)
