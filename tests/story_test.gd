extends Node
## Test automatisé : joue les 3 journées du mode Histoire de bout en bout
## (appel des patients, consultation complète, compte rendu, fin de journée).
## Lancement : godot --headless --path . res://tests/story_test.tscn

var main: Node
var failures: Array[String] = []


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
	await _frames(2)
	var vp := get_viewport().get_visible_rect().size
	for c in [s.hud, s.agenda, s.consult]:
		_check(c.size.is_equal_approx(vp), "l'interface %s couvre l'écran (%s)" % [c.get_class(), c.size])
	_check(s.state == GameSession.State.PLAY, "état PLAY après l'intro")
	var guard := 0
	while not s._all_done() and guard < 400:
		guard += 1
		Game.advance(2.0)
		await _frames(3)
		var next: PatientRecord = null
		for r in s.records:
			if r.status == PatientRecord.Status.WAITING:
				if next == null or r.is_urgent():
					next = r
		if next and not s.office_busy() and s.state == GameSession.State.PLAY:
			s._open_agenda()
			await _frames(2)
			_check(s.agenda.visible, "agenda visible")
			s._call_patient(next)
			await _wait_until(func(): return next.status == PatientRecord.Status.IN_OFFICE, 3000, "patient installé (%s)" % next.case_id)
			await _consult(s, next)
	_check(s._all_done(), "tous les patients vus le jour %d" % day)
	await _wait_until(func(): return s.state == GameSession.State.REPORT, 1200, "bilan de fin de journée")
	_check(Game.day_results.size() == s.records.size(), "un résultat par patient")
	var last := day >= Cases.day_count()
	s._on_report_continue(last)
	await _frames(10)


func _consult(s: GameSession, r: PatientRecord) -> void:
	r.interact.interact()
	await _frames(2)
	_check(s.state == GameSession.State.CONSULT, "consultation ouverte (%s)" % r.case_id)
	var c := s.consult
	for q in Cases.QUESTIONS.slice(0, 4):
		c._ask(q["id"], q["text"])
		await _frames(1)
	for i in range(r.data.get("extra_questions", []).size()):
		c._ask("extra_%d" % i, "?")
	c._show_tab(1)
	var exams := ["constantes"]
	exams.append_array(r.data.get("findings", {}).keys())
	for e in exams:
		c._exam(e)
		await _frames(1)
	c._show_tab(2)
	c._pick_diagnosis(r.data["diagnosis"])
	c._show_tab(3)
	for t in r.data["treatment"]["good"]:
		c._toggle_treatment(true, t)
	await _frames(2)
	_check(not c._conclude_btn.disabled, "bouton conclure actif")
	c._conclude()
	await _frames(2)
	_check(not r.result.is_empty(), "résultat calculé (%s)" % r.case_id)
	_check(r.result.get("diagnosis_ok", false), "diagnostic exact (%s)" % r.case_id)
	_check(r.result.get("grade", "F") in ["A", "B"], "note A/B pour une prise en charge correcte (%s : %s, %s)" % [r.case_id, r.result.get("grade"), r.result.get("notes")])
	await _wait_until(func(): return not r.body or not r.body.is_walking(), 3000, "patient immobile")
	c._finish()
	await _frames(3)
	_check(s.state == GameSession.State.PLAY, "retour en jeu après consultation")


func _finish() -> void:
	# Cas limites de l'évaluation
	var miss := Cases.evaluate("thoracique", "rgo", ["ipp"], [], 10.0, 0.0)
	_check(miss["critical_miss"] and miss["grade"] == "F", "urgence manquée notée F")
	var abx := Cases.evaluate("rhino", "rhinopharyngite", ["paracetamol", "lavage_nez", "surveillance", "amoxicilline"], ["orl"], 8.0, 0.0)
	_check(abx["score"] < 100.0 and abx["notes"].size() > 0, "antibiotique inutile pénalisé")
	var no_tdr := Cases.evaluate("angine", "angine_strepto", ["amoxicilline", "paracetamol"], [], 8.0, 0.0)
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
	if failures.is_empty():
		print("STORY TEST OK — %d patients vus, réputation %.1f, honoraires %d €" % [Game.total_seen, Game.reputation, int(Game.money)])
		get_tree().quit(0)
	else:
		print("STORY TEST FAILED (%d)" % failures.size())
		for f in failures:
			print("  - " + f)
		get_tree().quit(1)
