class_name GameSession
extends Node3D
## Déroulement d'une journée : arrivées, accueil, salle d'attente, appel,
## consultation libre (dialogue, examens physiques avec les outils,
## positions du patient), ordonnance sur l'ordinateur, départ, bilan.

signal quit_to_menu
signal next_day_requested

enum State { INTRO, PLAY, DIALOGUE, EXAM_VIEW, COMPUTER, PAUSE, REPORT, CUTSCENE, NOTES }

const OFFICE_CHAIR_2 := Vector3(3.45, 0, 2.55)
const TABLE_SEAT_OFFSET := 0.25

var state: State = State.INTRO
var clinic: Clinic
var player: Player
var records: Array[PatientRecord] = []
var current: PatientRecord
var camille: Character
var marchand: Character

var ui_root: Control
var hud: Hud
var wheel: ToolWheel
var dialogue: DialoguePanel
var exam_view: ExamView
var software: MedicalSoftware
var overlay: Control
var fader: ColorRect

var _rng := RandomNumberGenerator.new()
var _day_over_pending := false
var _delayed: Array = []
var _marchand_done := false


func _ready() -> void:
	_rng.seed = 1000 + Game.day * 77
	clinic = Clinic.new()
	clinic.name = "Clinic"
	add_child(clinic)
	clinic.build()
	clinic.computer.used.connect(_open_computer)

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.global_position = Clinic.PLAYER_SPAWN
	player.set_look(deg_to_rad(-115), deg_to_rad(-6))
	player.focus_changed.connect(_on_focus_changed)
	player.spot_changed.connect(_on_spot_changed)
	player.exam_progress.connect(_on_exam_progress)
	player.exam_performed.connect(_on_exam_performed)
	player.tool_changed.connect(_on_tool_changed)
	player.position_of = _spot_position
	player.spot_allowed = _spot_allowed

	_spawn_camille()
	_build_ui()
	_load_day()
	Game.time_changed.connect(_on_time_changed)
	_show_intro()


func _spawn_camille() -> void:
	clinic.secretary.visible = false
	var cast: Dictionary = Cases.CAST["camille"]
	camille = Character.new()
	camille.name = "Camille"
	add_child(camille)
	camille.setup(cast["avatar"], cast["gender"])
	camille.place_seated(Vector3(-6.42, 0, 3.5), Vector3.RIGHT, 0.0, "type")
	camille.look_target = player.camera
	var it := Interactable.create(camille, Vector3(0.8, 1.4, 0.8), Vector3(0, 0.8, 0), "Parler à Camille")
	it.used.connect(_talk_to_camille)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = UITheme.get_theme()
	layer.add_child(ui_root)

	hud = Hud.new()
	ui_root.add_child(hud)
	wheel = ToolWheel.new()
	ui_root.add_child(wheel)
	player.wheel = wheel
	player.wheel_toggled.connect(_on_wheel_toggled)
	dialogue = DialoguePanel.new()
	ui_root.add_child(dialogue)
	dialogue.option_chosen.connect(_on_dialogue_option)
	dialogue.closed.connect(_on_dialogue_closed)
	exam_view = ExamView.new()
	ui_root.add_child(exam_view)
	exam_view.closed.connect(_on_exam_view_closed)
	software = MedicalSoftware.new()
	software.session = self
	ui_root.add_child(software)
	software.closed.connect(_on_computer_closed)
	fader = ColorRect.new()
	fader.color = Color(0, 0, 0, 0)
	fader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(fader)
	Game.notify.connect(hud.toast)


func _on_wheel_toggled(open: bool) -> void:
	hud.set_dim(open)


func _load_day() -> void:
	records.clear()
	var day := Cases.day_data(Game.day)
	for p in day["patients"]:
		var r := PatientRecord.new()
		r.case_id = p["case"]
		r.data = Cases.get_case(r.case_id)
		r.appointment = float(p["time"])
		r.walk_in = p.get("walk_in", false)
		r.arrival_time = r.appointment if r.walk_in else r.appointment + _rng.randf_range(-9.0, 1.0)
		records.append(r)
	_refresh_info()


# --- États ------------------------------------------------------------------------

func _set_state(s: State) -> void:
	state = s
	var playing := s == State.PLAY
	player.input_enabled = playing
	if not playing:
		player.close_wheel_if_open()
	_update_clock()
	hud.set_play_mode(playing)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if playing else Input.MOUSE_MODE_VISIBLE


func _update_clock() -> void:
	# L'horloge tourne librement hors consultation ; pendant une consultation,
	# seul le temps des actions (questions, examens) est décompté.
	Game.clock_running = state == State.PLAY and current == null
	hud.set_consulting(current != null)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		match state:
			State.PLAY:
				_open_pause()
			State.PAUSE:
				_close_pause()
			State.DIALOGUE:
				dialogue.close()
			State.COMPUTER:
				software.request_close()
			State.EXAM_VIEW:
				exam_view.close()
			State.NOTES:
				_close_notes()
	elif event.is_action_pressed("notes"):
		if state == State.PLAY and current:
			get_viewport().set_input_as_handled()
			_open_notes()
		elif state == State.NOTES:
			get_viewport().set_input_as_handled()
			_close_notes()
	elif state == State.PLAY and event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAY:
		_open_pause()


# --- Boucle temporelle ---------------------------------------------------------------

func _on_time_changed(m: float) -> void:
	for r in records:
		if r.status == PatientRecord.Status.EXPECTED and m >= r.arrival_time:
			_spawn_patient(r)
	var i := 0
	while i < _delayed.size():
		if m >= _delayed[i][0]:
			var cb: Callable = _delayed[i][1]
			_delayed.remove_at(i)
			cb.call()
		else:
			i += 1
	hud.set_clock(Game.clock_text())
	_refresh_info()


func _at(minute: float, cb: Callable) -> void:
	_delayed.append([minute, cb])


func _process(_delta: float) -> void:
	if state == State.PLAY and not _day_over_pending and _all_done():
		_day_over_pending = true
		get_tree().create_timer(2.0).timeout.connect(_end_day)


func _all_done() -> bool:
	for r in records:
		if r.status != PatientRecord.Status.DONE:
			return false
	return true


func next_arrival_minute() -> float:
	var best := INF
	for r in records:
		if r.status == PatientRecord.Status.EXPECTED:
			best = minf(best, r.arrival_time)
	return best


## Fait avancer le temps jusqu'à la prochaine arrivée (salle d'attente vide).
func skip_to_next_arrival() -> bool:
	var nxt := next_arrival_minute()
	if nxt == INF or waiting_count() > 0 or current != null:
		return false
	var tw := create_tween()
	tw.tween_property(fader, "color:a", 1.0, 0.35)
	tw.tween_callback(_advance_to.bind(nxt + 0.2))
	tw.tween_interval(0.5)
	tw.tween_property(fader, "color:a", 0.0, 0.5)
	return true


func _advance_to(minute: float) -> void:
	if minute > Game.minutes:
		Game.advance(minute - Game.minutes)


# --- Voix ----------------------------------------------------------------------------

## Fait dire une réplique à un personnage (voix + sous-titre). Renvoie la durée.
func speak(who: Character, speaker_id: String, speaker_name: String, text: String) -> float:
	var stream := Voices.stream(speaker_id, text)
	var env := Voices.envelope(speaker_id, text)
	var shown := String(Cases.split_speaker(text)[1])
	var dur := clampf(shown.length() / 15.0, 1.4, 7.0)
	if stream:
		dur = stream.get_length()
	if who and is_instance_valid(who):
		who.say(stream, dur, env)
	elif stream:
		Sfx.play_stream(stream, "Voice", 0.0, speaker_id == "regulateur")
	if Game.settings.get("subtitles", true):
		hud.subtitle(speaker_name, shown, dur + 0.6)
	return dur


func _patient_speak(r: PatientRecord, text: String) -> float:
	var sp: Array = Cases.split_speaker(text)
	if sp[0] == "La mère" and r.companion and is_instance_valid(r.companion):
		var comp: Dictionary = r.data.get("companion", {})
		return speak(r.companion, r.case_id + "_mere", comp.get("name", "La mère"), text)
	return speak(r.body, r.case_id, r.display_name(), text)


func _camille_say(text: String) -> float:
	return speak(camille, "camille", "Camille", text)


# --- Patients ----------------------------------------------------------------------

func _make_character(avatar: String, gender: String, seed_value: int) -> Character:
	var c := Character.new()
	add_child(c)
	c.setup(avatar, gender, seed_value)
	c.look_target = player.camera
	return c


func _spawn_patient(r: PatientRecord) -> void:
	r.status = PatientRecord.Status.ARRIVING
	r.arrived_at = Game.minutes
	r.position = "walking"
	var p: Dictionary = r.data.get("patient", {})
	var c := _make_character(p["avatar"], r.gender_code(), hash(r.case_id))
	c.name = "Patient_" + r.case_id
	c.walk_style = p.get("walk", "walk")
	c.cough = p.get("cough", false)
	c.base_expression = p.get("mood", "")
	if p.has("skin"):
		c.set_skin_look(p["skin"])
	c.global_position = Clinic.OUTSIDE
	r.body = c
	c.action_done.connect(_on_character_action.bind(r))
	r.hotspots = Hotspot.attach_all(c)
	r.set_hotspots_active(false)
	r.talk = Interactable.create(c, Vector3(0.7, 1.5, 0.7), Vector3(0, 0.85, 0), "Parler à %s" % r.title_name())
	r.talk.used.connect(_on_patient_interact.bind(r))
	var comp: Dictionary = r.data.get("companion", {})
	if not comp.is_empty():
		var cc := _make_character(comp["avatar"], comp["gender"], hash(r.case_id + "m"))
		cc.name = "Accompagnant_" + r.case_id
		cc.global_position = Clinic.OUTSIDE + Vector3(0.6, 0, 0.5)
		r.companion = cc
	var path: Array[Vector3] = [Clinic.ENTRY, Clinic.RECEPTION]
	c.walk_to(path, {"face": Vector3.LEFT})
	c.arrived.connect(_on_reached_reception.bind(r), CONNECT_ONE_SHOT)
	if r.companion:
		var path2: Array[Vector3] = [Clinic.ENTRY + Vector3(0.5, 0, 0.2), Clinic.RECEPTION + Vector3(0.45, 0, 0.55)]
		r.companion.walk_to(path2, {"face": Vector3.LEFT})
	clinic.ring_door()


func _on_character_action(action: String, r: PatientRecord) -> void:
	if action == "cough" and r.body and is_instance_valid(r.body):
		Sfx.play_at("people/cough_%s" % r.gender_code(), r.body.head_position(), self, -6.0, _rng.randf_range(0.92, 1.08))


func _on_reached_reception(r: PatientRecord) -> void:
	if r.status != PatientRecord.Status.ARRIVING:
		return
	r.position = "reception"
	camille.look_target = r.body
	var d := 0.0
	if r.is_child() and r.companion:
		d = speak(r.companion, r.case_id + "_mere", r.data["companion"]["name"], Cases.GENERIC["hello"])
	else:
		d = _patient_speak(r, Cases.GENERIC["hello"])
	get_tree().create_timer(d + 0.4).timeout.connect(_announce_arrival.bind(r))


func _announce_arrival(r: PatientRecord) -> void:
	if not is_instance_valid(camille) or r.status != PatientRecord.Status.ARRIVING:
		return
	var line := Voices.arrival_line(r, r.walk_in)
	if r.is_urgent():
		Sfx.play("music/sting_urgent", "Music", -4.0)
	var d := _camille_say(line)
	Game.say("Camille : " + line, "danger" if r.is_urgent() else ("warning" if r.walk_in else "info"))
	get_tree().create_timer(minf(d, 2.5) + 0.3).timeout.connect(_go_to_waiting_room.bind(r))


func _go_to_waiting_room(r: PatientRecord) -> void:
	if not is_instance_valid(r.body) or r.status != PatientRecord.Status.ARRIVING:
		return
	camille.look_target = player.camera
	r.seat_index = _free_seat()
	r.status = PatientRecord.Status.WAITING
	_sit_on(r.body, clinic.wait_seat(r.seat_index), Vector3.BACK, [clinic.wait_front(r.seat_index)])
	r.position = "waiting"
	if r.companion:
		var s2 := _free_seat_except(r.seat_index)
		r.set_meta("companion_seat", s2)
		_sit_on(r.companion, clinic.wait_seat(s2), Vector3.BACK, [clinic.wait_front(s2)])
	_refresh_info()


## Envoie un personnage s'asseoir : chemin, point d'approche, puis assis.
func _sit_on(c: Character, seat: Vector3, facing: Vector3, via: Array, seat_offset: float = 0.0) -> void:
	var pts: Array[Vector3] = []
	for p in via:
		pts.append(p)
	pts.append(c.sit_approach_point(seat, facing))
	c.walk_to(pts, {"do": "sit", "face": facing, "seat": seat_offset})


func _free_seat() -> int:
	return _free_seat_except(-1)


func _free_seat_except(except: int) -> int:
	var used: Array[int] = [except]
	for r in records:
		if r.status in [PatientRecord.Status.ARRIVING, PatientRecord.Status.WAITING]:
			if r.seat_index >= 0:
				used.append(r.seat_index)
			if r.has_meta("companion_seat"):
				used.append(int(r.get_meta("companion_seat")))
	for i in range(Clinic.WAIT_SEATS_X.size()):
		if not (i in used):
			return i
	return Clinic.WAIT_SEATS_X.size() - 1


func waiting_count() -> int:
	var n := 0
	for r in records:
		if r.status == PatientRecord.Status.WAITING:
			n += 1
	return n


func office_busy() -> bool:
	return current != null


func call_patient(r: PatientRecord) -> bool:
	if r.status != PatientRecord.Status.WAITING or office_busy():
		return false
	r.status = PatientRecord.Status.CALLED
	current = r
	r.position = "walking"
	var seat := r.seat_index
	r.seat_index = -1
	_sit_on(r.body, Clinic.PATIENT_SEAT, Vector3.FORWARD, [clinic.wait_front(seat), Clinic.DOOR_W, Clinic.DOOR_E, Clinic.OFFICE_APPROACH])
	r.body.arrived.connect(_on_patient_seated_in_office.bind(r), CONNECT_ONE_SHOT)
	if r.companion:
		var s2 := int(r.get_meta("companion_seat", 0))
		r.remove_meta("companion_seat")
		_sit_on(r.companion, OFFICE_CHAIR_2, Vector3.FORWARD, [clinic.wait_front(s2), Clinic.DOOR_W, Clinic.DOOR_E, Clinic.OFFICE_APPROACH + Vector3(0.7, 0, 0.2)])
	_camille_say(Voices.call_line(r))
	_update_clock()
	_refresh_info()
	return true


func _on_patient_seated_in_office(r: PatientRecord) -> void:
	if r.status != PatientRecord.Status.CALLED:
		return
	r.status = PatientRecord.Status.IN_OFFICE
	r.position = "chair"
	r.consult_started_at = Game.minutes
	r.set_hotspots_active(true)
	_patient_speak(r, r.data.get("greeting", "Bonjour docteur."))
	r.add_note("motif", "Motif de consultation", r.data.get("motif", "").replace("SANS RDV — ", ""), false, Game.minutes)
	_update_clock()
	_refresh_info()


func _on_patient_interact(r: PatientRecord) -> void:
	if state != State.PLAY:
		return
	if r.status == PatientRecord.Status.WAITING:
		if office_busy():
			Game.say("Terminez d'abord la consultation en cours.", "warning")
			return
		_patient_speak(r, Cases.GENERIC["follow"])
		call_patient(r)
	elif r == current and r.status == PatientRecord.Status.IN_OFFICE and r.position != "walking":
		_open_dialogue(r)
	elif r == current:
		Game.say("%s s'installe, un instant." % r.title_name(), "info")


# --- Camille --------------------------------------------------------------------

func _talk_to_camille() -> void:
	if state != State.PLAY:
		return
	var opts: Array = []
	if waiting_count() > 0 and not office_busy():
		opts.append({"id": "next", "text": "Faites entrer le patient suivant, s'il vous plaît.", "kind": "order", "icon": "door-open"})
	opts.append({"id": "who", "text": "Qui attend en salle d'attente ?", "kind": "question", "icon": "users"})
	opts.append({"id": "bye", "text": "Rien, merci Camille.", "kind": "end", "icon": "x"})
	_set_state(State.DIALOGUE)
	var hello: String = Cases.LINES["camille"]["hello"]
	dialogue.open_simple("Camille", "Secrétaire médicale", hello, opts, "camille")
	_camille_say(hello)


func _camille_option(id: String) -> void:
	match id:
		"next":
			var r := _next_waiting()
			dialogue.close()
			if r:
				call_patient(r)
		"who":
			var names: Array[String] = []
			for r in records:
				if r.status == PatientRecord.Status.WAITING:
					names.append(r.title_name())
			var txt: String = Cases.LINES["camille"]["none"] if names.is_empty() else "En salle d'attente : %s." % ", ".join(names)
			dialogue.set_line("Camille", txt)
			if names.is_empty():
				_camille_say(txt)
		_:
			dialogue.close()


func _next_waiting() -> PatientRecord:
	var best: PatientRecord = null
	for r in records:
		if r.status == PatientRecord.Status.WAITING:
			if best == null or (r.is_urgent() and not best.is_urgent()) or (r.is_urgent() == best.is_urgent() and r.arrived_at < best.arrived_at):
				best = r
	return best


# --- Dialogue avec le patient ------------------------------------------------------

func _open_dialogue(r: PatientRecord) -> void:
	_set_state(State.DIALOGUE)
	player.focus_on(r.body.head_position() + Vector3(0, -0.05, 0), 0.5)
	dialogue.open_patient(r, _dialogue_options(r))


func _dialogue_options(r: PatientRecord) -> Array:
	var opts: Array = []
	for q in Cases.QUESTIONS:
		opts.append({"id": "q:" + q["id"], "text": q["text"], "kind": "question", "done": ("q:" + q["id"]) in r.questions})
	var extra: Array = r.data.get("extra_questions", [])
	for i in extra.size():
		opts.append({"id": "x:%d" % i, "text": extra[i]["text"], "kind": "question", "done": ("x:%d" % i) in r.questions})
	match r.position:
		"chair":
			opts.append({"id": "pos:table", "text": "Pouvez-vous vous installer sur la table d'examen ?", "kind": "order", "icon": "bed"})
		"table":
			opts.append({"id": "pos:lie", "text": "Allongez-vous sur le dos, s'il vous plaît.", "kind": "order", "icon": "bed"})
			opts.append({"id": "pos:chair", "text": "Vous pouvez vous rasseoir sur la chaise.", "kind": "order", "icon": "armchair"})
		"lying":
			opts.append({"id": "pos:sit", "text": "Asseyez-vous au bord de la table, s'il vous plaît.", "kind": "order", "icon": "armchair"})
			opts.append({"id": "pos:chair", "text": "C'est terminé, vous pouvez vous rasseoir sur la chaise.", "kind": "order", "icon": "armchair"})
	opts.append({"id": "end", "text": "Merci. Je vais rédiger votre ordonnance.", "kind": "end", "icon": "file-text"})
	return opts


func _on_dialogue_option(id: String) -> void:
	if dialogue.mode == "camille":
		_camille_option(id)
		return
	var r := current
	if r == null:
		dialogue.close()
		return
	if id.begins_with("q:") or id.begins_with("x:"):
		var answer := ""
		var qtext := ""
		if id.begins_with("q:"):
			var qid := id.substr(2)
			answer = Cases.answer(r.data, qid)
			for q in Cases.QUESTIONS:
				if q["id"] == qid:
					qtext = q["text"]
		else:
			var idx := int(id.substr(2))
			var ex: Dictionary = r.data.get("extra_questions", [])[idx]
			answer = ex["answer"]
			qtext = ex["text"]
		var shown := String(Cases.split_speaker(answer)[1])
		if not (id in r.questions):
			r.questions.append(id)
			Game.advance(1.0)
			r.add_note("question", qtext, shown, false, Game.minutes)
		var speaker_name := r.display_name()
		if String(Cases.split_speaker(answer)[0]) == "La mère":
			speaker_name = r.data.get("companion", {}).get("name", "La mère")
		dialogue.set_line(speaker_name, shown)
		_patient_speak(r, answer)
		dialogue.refresh_options(_dialogue_options(r))
	elif id.begins_with("pos:"):
		dialogue.close()
		_move_patient(r, id.substr(4))
	elif id == "end":
		dialogue.close()
		Game.say("Allez sur l'ordinateur du bureau pour poser le diagnostic et rédiger l'ordonnance.", "info")


func _on_dialogue_closed() -> void:
	if state == State.DIALOGUE:
		_set_state(State.PLAY)


func _move_patient(r: PatientRecord, where: String) -> void:
	var c := r.body
	if c == null or c.is_busy():
		return
	r.position = "walking"
	match where:
		"table":
			_patient_speak(r, Cases.GENERIC["table"])
			_sit_on(c, Clinic.EXAM_SEAT, Vector3.LEFT, [Clinic.OFFICE_APPROACH, Clinic.EXAM_APPROACH], TABLE_SEAT_OFFSET)
			c.arrived.connect(_set_position.bind(r, "table"), CONNECT_ONE_SHOT)
		"lie":
			_patient_speak(r, Cases.GENERIC["lie"])
			c.walk_to([], {"do": "lie", "head": Vector3.FORWARD, "bed": Clinic.EXAM_BED, "bed_height": 0.72})
			c.arrived.connect(_set_position.bind(r, "lying"), CONNECT_ONE_SHOT)
		"sit":
			c.stand_up()
			c.action_done.connect(_after_get_up_to_table.bind(r), CONNECT_ONE_SHOT)
		"chair":
			_patient_speak(r, Cases.GENERIC["chair"])
			_sit_on(c, Clinic.PATIENT_SEAT, Vector3.FORWARD, [Clinic.EXAM_APPROACH, Clinic.OFFICE_APPROACH])
			c.arrived.connect(_set_position.bind(r, "chair"), CONNECT_ONE_SHOT)
	Game.advance(1.0)
	_refresh_info()


func _after_get_up_to_table(_a: String, r: PatientRecord) -> void:
	if r.body == null:
		return
	_sit_on(r.body, Clinic.EXAM_SEAT, Vector3.LEFT, [Clinic.EXAM_APPROACH], TABLE_SEAT_OFFSET)
	r.body.arrived.connect(_set_position.bind(r, "table"), CONNECT_ONE_SHOT)


func _set_position(r: PatientRecord, pos: String) -> void:
	r.position = pos
	_refresh_info()


# --- Examens -----------------------------------------------------------------------

func _spot_position(spot: Hotspot) -> String:
	for r in records:
		if r.body == spot.character:
			return r.position
	return "chair"


func _spot_allowed(spot: Hotspot) -> bool:
	return current != null and current.body == spot.character and current.status == PatientRecord.Status.IN_OFFICE and current.position != "walking"


func _on_spot_changed(spot: Hotspot, exam_id: String, ok: bool, reason: String) -> void:
	if spot == null or exam_id == "":
		hud.set_exam_prompt("", "", "")
		return
	var e: Dictionary = ExamDB.EXAMS[exam_id]
	hud.set_exam_prompt(e["verb"], spot.display_name(), "" if ok else reason)


func _on_exam_progress(ratio: float) -> void:
	hud.set_progress(ratio)
	if current and ratio > 0.0 and player._hold_exam in ["cardio", "pulmo_d", "pulmo_g"]:
		Sfx.stethoscope(Cases.sound_state(current.data, player._hold_exam), player._hold_exam == "cardio", int(Cases.vitals(current.data)["fc"]))
	elif ratio <= 0.0 and state == State.PLAY:
		Sfx.stethoscope_stop()


func _on_exam_performed(spot: Hotspot, exam_id: String) -> void:
	var r := current
	if r == null or not _spot_allowed(spot):
		return
	var e: Dictionary = ExamDB.EXAMS[exam_id]
	var minutes := int(e["min"])
	var first := not r.exams.has(exam_id)
	var text := Cases.exam_result(r.data, exam_id)
	var abnormal := Cases.exam_is_abnormal(r.data, exam_id)
	Game.advance(float(minutes) if first else 0.5)
	r.exams[exam_id] = {"text": text, "abnormal": abnormal, "minute": Game.minutes}
	if first:
		r.add_note("exam", e["name"], text, abnormal, Game.minutes)
	_exam_reaction(r, spot, exam_id)
	player.viewmodel.set_display(_device_text(r, exam_id))
	if exam_id == "bu":
		_play_fade_message("%s revient avec un échantillon d'urine." % r.title_name(), _show_exam.bind(r, exam_id, text, abnormal, minutes))
	elif exam_id == "tdr":
		_play_fade_message("Prélèvement de gorge effectué… résultat après 5 minutes.", _show_exam.bind(r, exam_id, text, abnormal, minutes))
	else:
		_show_exam(r, exam_id, text, abnormal, minutes)
	_refresh_info()


func _show_exam(r: PatientRecord, exam_id: String, text: String, abnormal: bool, minutes: int) -> void:
	if ExamView.has_visual(exam_id):
		_set_state(State.EXAM_VIEW)
		exam_view.open(exam_id, r.data, text, abnormal, minutes)
		if exam_id in ["cardio", "pulmo_d", "pulmo_g"]:
			Sfx.stethoscope(Cases.sound_state(r.data, exam_id), exam_id == "cardio", int(Cases.vitals(r.data)["fc"]))
		else:
			Sfx.ui("result")
	else:
		hud.exam_card(ExamDB.EXAMS[exam_id]["name"], text, abnormal, minutes)
		Sfx.ui("result")


func _on_exam_view_closed() -> void:
	Sfx.stethoscope_stop()
	if state == State.EXAM_VIEW:
		_set_state(State.PLAY)


func _device_text(r: PatientRecord, exam_id: String) -> String:
	var v := Cases.vitals(r.data)
	match exam_id:
		"temp":
			return ("%.1f" % float(v["temp"])).replace(".", ",")
		"spo2":
			return "%d%%  %d" % [int(v["spo2"]), int(v["fc"])]
		"ta":
			return str(v["ta"])
		"glycemie":
			return ("%.2f" % float(v["glyc"])).replace(".", ",")
	return ""


func _exam_reaction(r: PatientRecord, spot: Hotspot, exam_id: String) -> void:
	var pain: Array = r.data.get("pain", [])
	if spot.spot_id in pain:
		r.body.express("pain", 2.2)
		_patient_speak(r, Cases.GENERIC["pain"])
		Game.say("%s grimace : la zone est douloureuse." % r.title_name(), "warning")
		var key := "douleur_" + spot.spot_id
		if not r.exams.has(key):
			r.exams[key] = {"text": "Douleur provoquée", "abnormal": true, "minute": Game.minutes}
			r.add_note("exam", "Douleur provoquée", "Douleur à l'examen : %s." % spot.display_name().to_lower(), true, Game.minutes)
		return
	match exam_id:
		"cardio", "pulmo_d", "pulmo_g":
			if not r.said_cold:
				r.said_cold = true
				_patient_speak(r, Cases.GENERIC["cold"])
		"orl", "tdr":
			r.body.express("open_mouth", 2.0)
			_patient_speak(r, Cases.GENERIC["aah"])
		"dep":
			r.body.express("blow", 1.5)
			_patient_speak(r, Cases.GENERIC["blow"])
		"glycemie":
			_patient_speak(r, Cases.GENERIC["prick"])
		"reflexes":
			Sfx.play_at("tools/reflex", spot.global_position, self, -4.0)
		"bu":
			_patient_speak(r, Cases.GENERIC["sample"])


func _play_fade_message(msg: String, then: Callable) -> void:
	_set_state(State.CUTSCENE)
	var tw := create_tween()
	tw.tween_property(fader, "color:a", 1.0, 0.4)
	tw.tween_callback(hud.center_message.bind(msg, 1.6))
	tw.tween_interval(1.8)
	tw.tween_property(fader, "color:a", 0.0, 0.5)
	tw.tween_callback(_after_fade.bind(then))


func _after_fade(then: Callable) -> void:
	_set_state(State.PLAY)
	then.call()


func _on_tool_changed(_id: String) -> void:
	hud.set_tool(player.tool)


# --- Ordinateur ----------------------------------------------------------------------

func _open_computer() -> void:
	if state != State.PLAY:
		return
	_set_state(State.COMPUTER)
	software.open()


func _on_computer_closed() -> void:
	if state == State.COMPUTER:
		_set_state(State.PLAY)


## Appelé par le logiciel quand le médecin valide la consultation.
func conclude_consultation(diagnosis: String, treatments: Array) -> Dictionary:
	var r := current
	if r == null:
		return {}
	r.diagnosis = diagnosis
	r.treatments = treatments.duplicate()
	Game.advance(2.0)
	var spent := Game.minutes - r.consult_started_at
	var waited := maxf(0.0, r.consult_started_at - maxf(r.arrived_at, r.appointment))
	r.result = Cases.evaluate(r.case_id, diagnosis, treatments, r.exams.keys(), r.questions, spent, waited)
	Game.record_result(r.result)
	return r.result


## Appelé par le logiciel après le compte rendu.
func finish_consultation() -> void:
	var r := current
	if r == null:
		return
	software.force_close()
	_set_state(State.PLAY)
	if r.result.get("samu", false) and r.is_urgent():
		_samu_sequence(r)
		return
	_send_home(r)
	if r.result.get("critical_miss", false):
		var msg := "Camille : Docteur… l'épouse de %s a appelé. Il a fait un arrêt cardiaque sur la route. Il est en réanimation." % r.title_name()
		_at(Game.minutes + 20.0, Game.say.bind(msg, "danger"))


func _send_home(r: PatientRecord) -> void:
	r.status = PatientRecord.Status.DONE
	r.set_hotspots_active(false)
	current = null
	_update_clock()
	var bye: String = Cases.GENERIC["bye"]
	if r.companion:
		speak(r.companion, r.case_id + "_mere", r.data["companion"]["name"], bye)
	else:
		_patient_speak(r, bye)
	if r.body:
		r.body.express("smile", 2.5)
	get_tree().create_timer(1.6).timeout.connect(_walk_out.bind(r))
	_refresh_info()


func _exit_path(r: PatientRecord, offset: Vector3 = Vector3.ZERO) -> Array[Vector3]:
	var exit: Array[Vector3] = []
	if r.position in ["table", "lying"]:
		exit.append(Clinic.EXAM_APPROACH + offset)
	for p in [Clinic.OFFICE_APPROACH, Clinic.DOOR_E, Clinic.DOOR_W, Clinic.ENTRY, Clinic.OUTSIDE]:
		exit.append(p + offset)
	return exit


func _walk_out(r: PatientRecord) -> void:
	if r.body == null or not is_instance_valid(r.body):
		return
	var path := _exit_path(r)
	r.position = "leaving"
	r.body.walk_to(path)
	r.body.arrived.connect(_remove_bodies.bind(r), CONNECT_ONE_SHOT)
	if r.companion and is_instance_valid(r.companion):
		r.companion.walk_to(_exit_path(r, Vector3(0.4, 0, 0.3)))


func _remove_bodies(r: PatientRecord) -> void:
	for c in [r.body, r.companion]:
		if c and is_instance_valid(c):
			c.queue_free()
	r.body = null
	r.companion = null
	r.hotspots.clear()


func _samu_sequence(r: PatientRecord) -> void:
	_set_state(State.CUTSCENE)
	r.set_hotspots_active(false)
	var reg: Dictionary = Cases.CAST["regulateur"]
	var lines: Dictionary = Cases.LINES["regulateur"]
	hud.phone_call(true)
	var d1 := speak(null, "regulateur", reg["name"], lines["answer"])
	var tw := create_tween()
	tw.tween_interval(d1 + 0.3)
	tw.tween_callback(hud.subtitle.bind("Vous", "Douleur thoracique typique depuis quarante minutes, sus-décalage du ST en inférieur sur l'ECG. Patient de 61 ans, diabétique et fumeur.", 4.5))
	tw.tween_interval(4.6)
	tw.tween_callback(speak.bind(null, "regulateur", reg["name"], lines["ok"]))
	tw.tween_interval(6.5)
	tw.tween_callback(_samu_hangup)
	tw.tween_property(fader, "color:a", 1.0, 0.8)
	tw.tween_callback(_samu_arrival.bind(r))
	tw.tween_interval(2.0)
	tw.tween_property(fader, "color:a", 0.0, 0.8)
	tw.tween_callback(_set_state.bind(State.PLAY))


func _samu_hangup() -> void:
	hud.phone_call(false)
	Sfx.play("ambience/siren", "SFX", -6.0)


func _samu_arrival(r: PatientRecord) -> void:
	Game.advance(10.0)
	hud.center_message("Dix minutes plus tard…", 1.8)
	clinic.show_ambulance(true)
	var doc_cast: Dictionary = Cases.CAST["smur_medecin"]
	var nurse_cast: Dictionary = Cases.CAST["smur_infirmiere"]
	var doc := _make_character(doc_cast["avatar"], "m", 11)
	var nurse := _make_character(nurse_cast["avatar"], "f", 12)
	doc.place_standing(Clinic.OFFICE_APPROACH + Vector3(-0.9, 0, 0.6), Vector3.FORWARD)
	nurse.place_standing(Clinic.OFFICE_APPROACH + Vector3(-1.5, 0, 0.9), Vector3.FORWARD)
	get_tree().create_timer(2.2).timeout.connect(_smur_talk.bind(r, doc, nurse))


func _smur_talk(r: PatientRecord, doc: Character, nurse: Character) -> void:
	var name: String = Cases.CAST["smur_medecin"]["name"]
	var d := speak(doc, "smur_medecin", name, Cases.LINES["smur_medecin"]["hello"])
	get_tree().create_timer(d + 0.4).timeout.connect(func():
		var d2 := speak(doc, "smur_medecin", name, Cases.LINES["smur_medecin"]["take"])
		get_tree().create_timer(d2 + 0.3).timeout.connect(_smur_leave.bind(r, doc, nurse)))


func _smur_leave(r: PatientRecord, doc: Character, nurse: Character) -> void:
	current = null
	r.status = PatientRecord.Status.DONE
	_update_clock()
	if r.body and is_instance_valid(r.body):
		r.body.walk_style = "walk_slow"
		r.body.walk_to(_exit_path(r))
		r.body.arrived.connect(_remove_bodies.bind(r), CONNECT_ONE_SHOT)
	r.position = "leaving"
	for k in 2:
		var who: Character = doc if k == 0 else nurse
		who.walk_to(_exit_path(r, Vector3(0.45 * (k + 1), 0, 0.3)))
		who.arrived.connect(who.queue_free, CONNECT_ONE_SHOT)
	Game.say("Le SMUR a pris en charge %s. Direction la salle de coronarographie." % r.title_name(), "success")
	_refresh_info()


# --- Notes rapides ------------------------------------------------------------------

func _open_notes() -> void:
	_set_state(State.NOTES)
	hud.show_notes(current)


func _close_notes() -> void:
	hud.hide_notes()
	if state == State.NOTES:
		_set_state(State.PLAY)


# --- Interface : informations ---------------------------------------------------------

func _on_focus_changed(target: Interactable) -> void:
	hud.set_prompt(target.prompt if target else "")


func _refresh_info() -> void:
	if hud == null:
		return
	var waiting := waiting_count()
	var next_text := "Aucun rendez-vous à venir"
	var next_min := INF
	var screen_lines: Array[String] = []
	for r in records:
		if r.status in [PatientRecord.Status.EXPECTED, PatientRecord.Status.ARRIVING] and not r.walk_in and r.appointment < next_min:
			next_min = r.appointment
			next_text = "Prochain RDV  %s · %s" % [Game.clock_text(r.appointment), r.short_name()]
		if not r.walk_in or r.status != PatientRecord.Status.EXPECTED:
			var mark := "✓" if r.status == PatientRecord.Status.DONE else ("●" if r.status == PatientRecord.Status.WAITING else "·")
			screen_lines.append("%s  %s   %s" % [mark, Game.clock_text(r.appointment) if not r.walk_in else "S.RDV", r.short_name()])
	hud.set_next(next_text)
	hud.set_waiting(waiting)
	hud.set_objective(_objective_text(waiting))
	hud.set_patient(current)
	clinic.set_screen("Agenda · %s" % Game.clock_text(), "\n".join(screen_lines))
	if software and software.visible:
		software.refresh()


func _objective_text(waiting: int) -> String:
	if current:
		var r := current
		match r.status:
			PatientRecord.Status.CALLED:
				return "%s arrive dans votre cabinet." % r.title_name()
			PatientRecord.Status.IN_OFFICE:
				if r.questions.size() < 2:
					return "Interrogez %s : approchez-vous et appuyez sur E." % r.title_name()
				if r.exams.size() < 2:
					return "Examinez %s : TAB pour choisir un outil, visez une zone du corps, maintenez le clic gauche." % r.title_name()
				return "Posez le diagnostic et rédigez l'ordonnance sur l'ordinateur du bureau."
	for r in records:
		if r.status == PatientRecord.Status.WAITING and r.is_urgent():
			return "URGENCE en salle d'attente : appelez %s immédiatement !" % r.title_name()
	if waiting > 0:
		return "%d patient%s en salle d'attente. Appelez le suivant : ordinateur, Camille, ou directement." % [waiting, "s" if waiting > 1 else ""]
	if _all_done():
		return "Tous les patients ont été vus."
	return "Personne en salle d'attente. Préparez-vous, ou avancez le temps depuis l'ordinateur."


# --- Menus ----------------------------------------------------------------------------

func _open_pause() -> void:
	_set_state(State.PAUSE)
	overlay = Overlays.pause_menu(_close_pause, _leave_to_menu)
	ui_root.add_child(overlay)


func _close_pause() -> void:
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	_set_state(State.PLAY)


func _leave_to_menu() -> void:
	Game.clock_running = false
	quit_to_menu.emit()


func _show_intro() -> void:
	_set_state(State.INTRO)
	var d := Cases.day_data(Game.day)
	overlay = Overlays.day_intro(Game.day, d["title"], d["intro"], records, _begin_day)
	ui_root.add_child(overlay)
	Sfx.music("menu_theme", 1.0)


func _begin_day() -> void:
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	Sfx.music("", 2.0)
	_set_state(State.PLAY)
	hud.set_tool(player.tool)
	get_tree().create_timer(1.0).timeout.connect(_morning_greeting)


func _morning_greeting() -> void:
	_camille_say(Cases.LINES["camille"]["morning"])
	Game.say("Astuce : maintenez TAB pour choisir un outil, visez une zone du corps et maintenez le clic gauche pour examiner.", "info")


func _end_day() -> void:
	if state != State.PLAY or current != null:
		_day_over_pending = false
		return
	if Cases.day_data(Game.day).get("marchand_visit", false) and not _marchand_done:
		_marchand_done = true
		_marchand_visit()
		return
	_camille_say(Cases.LINES["camille"]["done"])
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	_set_state(State.REPORT)
	var last := Game.day >= Cases.day_count()
	overlay = Overlays.day_report(Game.day, Game.day_results, last, _on_report_continue.bind(last), _leave_to_menu)
	ui_root.add_child(overlay)
	Sfx.music("day_end", 1.0)


func _marchand_visit() -> void:
	var cast: Dictionary = Cases.CAST["marchand"]
	marchand = _make_character(cast["avatar"], "f", 99)
	marchand.global_position = Clinic.OUTSIDE
	var path: Array[Vector3] = [Clinic.ENTRY, Clinic.DOOR_W, Clinic.DOOR_E, Clinic.OFFICE_APPROACH + Vector3(-0.4, 0, 0.3)]
	marchand.walk_to(path)
	clinic.ring_door()
	Game.say("Le Dr Marchand arrive au cabinet.", "info")
	marchand.arrived.connect(_marchand_talk, CONNECT_ONE_SHOT)


func _marchand_talk() -> void:
	var cast: Dictionary = Cases.CAST["marchand"]
	marchand.face(player.global_position - marchand.global_position)
	var d := speak(marchand, "marchand", cast["name"], Cases.LINES["marchand"]["hello"])
	get_tree().create_timer(d + 0.6).timeout.connect(func():
		var d2 := speak(marchand, "marchand", cast["name"], Cases.LINES["marchand"]["proud"])
		get_tree().create_timer(d2 + 1.0).timeout.connect(_marchand_end))


func _marchand_end() -> void:
	_day_over_pending = false


func _on_report_continue(last: bool) -> void:
	if last:
		Game.delete_save()
		quit_to_menu.emit()
	else:
		Game.next_day()
		next_day_requested.emit()
