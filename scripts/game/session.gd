class_name GameSession
extends Node3D
## Déroulement d'une journée de consultations : arrivée des patients,
## salle d'attente, appel, consultation, compte rendu et fin de journée.

signal quit_to_menu
signal next_day_requested

enum State { INTRO, PLAY, AGENDA, CONSULT, PAUSE, REPORT }

const SEAT_HEIGHT := 0.46
const TABLE_HEIGHT := 0.72

var state: State = State.INTRO
var clinic: Clinic
var player: Player
var records: Array[PatientRecord] = []
var current: PatientRecord

var ui_root: Control
var hud: Hud
var agenda: AgendaPanel
var consult: ConsultPanel
var overlay: Control

var _rng := RandomNumberGenerator.new()
var _day_over_pending := false
var _delayed: Array = [] # [minute, Callable]


func _ready() -> void:
	_rng.seed = 1000 + Game.day * 77
	clinic = Clinic.new()
	clinic.name = "Clinic"
	add_child(clinic)
	clinic.build()
	clinic.computer.used.connect(_open_agenda)

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.global_position = Clinic.PLAYER_SPAWN
	player.set_look(deg_to_rad(-115), deg_to_rad(-8))
	player.focus_changed.connect(_on_focus_changed)
	clinic.secretary.look_target = player.camera

	_build_ui()
	_load_day()
	Game.time_changed.connect(_on_time_changed)
	_show_intro()


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
	agenda = AgendaPanel.new()
	agenda.visible = false
	ui_root.add_child(agenda)
	agenda.call_requested.connect(_call_patient)
	agenda.closed.connect(_close_overlays)
	consult = ConsultPanel.new()
	consult.visible = false
	ui_root.add_child(consult)
	consult.question_asked.connect(_on_question)
	consult.exam_requested.connect(_on_exam)
	consult.concluded.connect(_on_concluded)
	consult.finished.connect(_on_consult_finished)
	Game.notify.connect(hud.toast)


func _load_day() -> void:
	records.clear()
	var day := Cases.day_data(Game.day)
	for p in day["patients"]:
		var r := PatientRecord.new()
		r.case_id = p["case"]
		r.data = Cases.get_case(r.case_id)
		r.appointment = float(p["time"])
		r.walk_in = p.get("walk_in", false)
		if r.walk_in:
			r.arrival_time = r.appointment
		else:
			r.arrival_time = r.appointment + _rng.randf_range(-9.0, 2.0)
		records.append(r)
	_refresh_info()


# --- États et souris ----------------------------------------------------------------

func _set_state(s: State) -> void:
	state = s
	var playing := s == State.PLAY
	player.input_enabled = playing
	Game.clock_running = playing
	hud.set_crosshair_visible(playing)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if playing else Input.MOUSE_MODE_VISIBLE
	if not playing:
		hud.set_prompt("")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		match state:
			State.PLAY:
				_open_pause()
			State.PAUSE:
				_close_pause()
			State.AGENDA:
				_close_overlays()
	elif event.is_action_pressed("agenda"):
		get_viewport().set_input_as_handled()
		if state == State.PLAY:
			_open_agenda()
		elif state == State.AGENDA:
			_close_overlays()
	elif state == State.PLAY and event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAY:
		_open_pause()


func _on_focus_changed(target: Interactable) -> void:
	hud.set_prompt(target.prompt if target else "")


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
		get_tree().create_timer(2.5).timeout.connect(_end_day)


func _all_done() -> bool:
	for r in records:
		if r.status != PatientRecord.Status.DONE:
			return false
	return true


# --- Patients ----------------------------------------------------------------------

func _spawn_patient(r: PatientRecord) -> void:
	r.status = PatientRecord.Status.ARRIVING
	r.arrived_at = Game.minutes
	var h := Humanoid.new()
	h.name = "Patient_%s" % r.case_id
	add_child(h)
	h.setup(r.data.get("patient", {}).get("look", {}), r.case_id.hash())
	h.global_position = Clinic.OUTSIDE + Vector3(_rng.randf_range(-0.3, 0.3), 0, 0)
	h.look_target = player.camera
	r.body = h
	r.interact = Interactable.create(h, Vector3(0.7, 1.4, 0.7), Vector3(0, 0.75, 0), "Commencer la consultation")
	r.interact.enabled = false
	r.interact.used.connect(_start_consultation.bind(r))
	var path: Array[Vector3] = [Clinic.ENTRY, Clinic.RECEPTION]
	h.walk_path(path, Humanoid.Pose.STAND, Vector3.LEFT)
	h.arrived.connect(_on_reached_reception.bind(r), CONNECT_ONE_SHOT)


func _on_reached_reception(r: PatientRecord) -> void:
	r.body.talk(1.5)
	clinic.secretary.talk(1.5)
	get_tree().create_timer(1.6).timeout.connect(_go_to_waiting_room.bind(r))
	if r.is_urgent():
		Game.say("Camille : Docteur ! %s, sans rendez-vous, se plaint d'une douleur dans la poitrine. Il est très pâle !" % r.title_name(), "danger")
	elif r.walk_in:
		Game.say("Camille : %s se présente sans rendez-vous — %s." % [r.title_name(), r.data.get("motif", "").replace("SANS RDV — ", "")], "warning")
	else:
		Game.say("Camille : %s est arrivé%s pour son rendez-vous de %s." % [r.title_name(), "e" if r.data.get("patient", {}).get("sex", "M") == "F" else "", Game.clock_text(r.appointment)], "info")


func _go_to_waiting_room(r: PatientRecord) -> void:
	if not is_instance_valid(r.body) or r.status != PatientRecord.Status.ARRIVING:
		return
	r.seat_index = _free_seat()
	var path: Array[Vector3] = [clinic.wait_front(r.seat_index), clinic.wait_seat(r.seat_index)]
	r.body.walk_path(path, Humanoid.Pose.SIT, Vector3.BACK, SEAT_HEIGHT)
	r.status = PatientRecord.Status.WAITING
	_refresh_info()


func _free_seat() -> int:
	var used: Array[int] = []
	for r in records:
		if r.seat_index >= 0 and r.status in [PatientRecord.Status.ARRIVING, PatientRecord.Status.WAITING]:
			used.append(r.seat_index)
	for i in range(Clinic.WAIT_SEATS_X.size()):
		if not (i in used):
			return i
	return 0


func office_busy() -> bool:
	for r in records:
		if r.status in [PatientRecord.Status.CALLED, PatientRecord.Status.IN_OFFICE, PatientRecord.Status.CONSULTING]:
			return true
	return false


func _call_patient(r: PatientRecord) -> void:
	if r.status != PatientRecord.Status.WAITING or office_busy():
		return
	_close_overlays()
	r.status = PatientRecord.Status.CALLED
	var seat := r.seat_index
	r.seat_index = -1
	var path: Array[Vector3] = [clinic.wait_front(seat), Clinic.DOOR_W, Clinic.DOOR_E, Clinic.OFFICE_APPROACH, Clinic.PATIENT_SEAT]
	r.body.walk_path(path, Humanoid.Pose.SIT, Vector3.FORWARD, SEAT_HEIGHT)
	r.body.arrived.connect(_on_patient_seated.bind(r), CONNECT_ONE_SHOT)
	Game.say("Vous appelez %s en salle d'attente." % r.title_name(), "info")
	_refresh_info()


func _on_patient_seated(r: PatientRecord) -> void:
	r.status = PatientRecord.Status.IN_OFFICE
	r.interact.enabled = true
	r.body.talk(1.2)
	_refresh_info()


func _start_consultation(r: PatientRecord) -> void:
	if r.status != PatientRecord.Status.IN_OFFICE or state != State.PLAY:
		return
	current = r
	r.status = PatientRecord.Status.CONSULTING
	r.consult_started_at = Game.minutes
	r.interact.enabled = false
	_set_state(State.CONSULT)
	player.focus_on(_patient_head(r))
	r.body.talk(3.0)
	consult.open(r)
	_refresh_info()


func _patient_head(r: PatientRecord) -> Vector3:
	if r.body and r.body.head:
		return r.body.head.global_position + Vector3(0, 0.1 * r.body.height_scale, 0)
	return Clinic.PATIENT_SEAT + Vector3(0, 1.2, 0)


func _on_question(_id: String) -> void:
	Game.advance(1.0)
	if current and current.body:
		current.body.talk(2.6)


func _on_exam(exam_id: String) -> void:
	var def := Cases.exam_def(exam_id)
	Game.advance(float(def.get("time", 1)))
	if current == null or current.body == null:
		return
	if def.get("table", false) and not current.on_table:
		current.on_table = true
		var path: Array[Vector3] = [Clinic.OFFICE_APPROACH, Clinic.EXAM_APPROACH, Clinic.EXAM_SEAT]
		current.body.walk_path(path, Humanoid.Pose.SIT, Vector3.LEFT, TABLE_HEIGHT)
		current.body.arrived.connect(_on_reached_table.bind(current), CONNECT_ONE_SHOT)


func _on_reached_table(r: PatientRecord) -> void:
	if state == State.CONSULT and current == r:
		player.focus_on(_patient_head(r))


func _on_concluded(diagnosis: String, treatments: Array, exams_done: Array) -> void:
	var r := current
	if r == null:
		return
	Game.advance(2.0)
	var spent := Game.minutes - r.consult_started_at
	var waited := maxf(0.0, r.consult_started_at - maxf(r.arrived_at, r.appointment))
	r.result = Cases.evaluate(r.case_id, diagnosis, treatments, exams_done, spent, waited)
	Game.record_result(r.result)
	consult.show_result(r.result)


func _on_consult_finished() -> void:
	var r := current
	current = null
	_set_state(State.PLAY)
	if r == null:
		return
	if r.result.get("samu", false) and r.is_urgent():
		r.status = PatientRecord.Status.LEAVING
		Game.say("SAMU (15) contacté. Le SMUR est en route — restez auprès du patient.", "danger")
		Game.advance(12.0)
		r.body.visible = false
		r.status = PatientRecord.Status.DONE
		Game.say("Le SMUR a pris en charge %s. Direction la salle de coronarographie." % r.title_name(), "success")
		_remove_body(r)
	else:
		_send_home(r)
		if r.result.get("critical_miss", false):
			_at(Game.minutes + 20.0, Game.say.bind("Camille : Docteur… l'épouse de %s a appelé. Il a fait un arrêt cardiaque sur la route. Il est en réanimation." % r.title_name(), "danger"))
	_refresh_info()


func _send_home(r: PatientRecord) -> void:
	r.status = PatientRecord.Status.LEAVING
	r.interact.enabled = false
	var path: Array[Vector3] = []
	if r.on_table:
		path.append(Clinic.EXAM_APPROACH)
	path.append_array([Clinic.OFFICE_APPROACH, Clinic.DOOR_E, Clinic.DOOR_W, Clinic.ENTRY, Clinic.OUTSIDE])
	r.body.walk_path(path, Humanoid.Pose.STAND)
	r.body.arrived.connect(_on_left.bind(r), CONNECT_ONE_SHOT)
	# Le cabinet est libre dès que le patient sort.
	r.status = PatientRecord.Status.DONE


func _on_left(r: PatientRecord) -> void:
	_remove_body(r)


func _remove_body(r: PatientRecord) -> void:
	if r.body and is_instance_valid(r.body):
		r.body.queue_free()
	r.body = null
	r.interact = null


# --- Informations HUD et écran du bureau ---------------------------------------------

func _refresh_info() -> void:
	if hud == null:
		return
	var waiting := 0
	var next_text := "Aucun rendez-vous à venir"
	var next_min := INF
	var screen_lines: Array[String] = []
	for r in records:
		if r.status == PatientRecord.Status.WAITING:
			waiting += 1
		if r.status in [PatientRecord.Status.EXPECTED, PatientRecord.Status.ARRIVING] and not r.walk_in and r.appointment < next_min:
			next_min = r.appointment
			next_text = "Prochain RDV  %s · %s" % [Game.clock_text(r.appointment), r.short_name()]
		if not r.walk_in or r.status != PatientRecord.Status.EXPECTED:
			var mark := "✓" if r.status == PatientRecord.Status.DONE else ("●" if r.status == PatientRecord.Status.WAITING else "·")
			screen_lines.append("%s  %s   %s" % [mark, Game.clock_text(r.appointment) if not r.walk_in else "S.RDV", r.short_name()])
	hud.set_next(next_text)
	hud.set_waiting(waiting)
	hud.set_objective(_objective_text(waiting))
	clinic.set_screen("Agenda · %s" % Game.clock_text(), "\n".join(screen_lines))


func _objective_text(waiting: int) -> String:
	for r in records:
		if r.status == PatientRecord.Status.IN_OFFICE:
			return "%s est installé%s. Approchez-vous et commencez la consultation." % [r.title_name(), "e" if r.data.get("patient", {}).get("sex", "M") == "F" else ""]
		if r.status == PatientRecord.Status.CALLED:
			return "%s arrive dans votre cabinet." % r.title_name()
	for r in records:
		if r.status == PatientRecord.Status.WAITING and r.is_urgent():
			return "URGENCE en salle d'attente : appelez %s immédiatement (ordinateur ou TAB)." % r.title_name()
	if waiting > 0:
		return "%d patient%s en salle d'attente. Appelez le suivant depuis l'ordinateur (ou TAB)." % [waiting, "s" if waiting > 1 else ""]
	if _all_done():
		return "Tous les patients ont été vus."
	return "Personne en salle d'attente. Préparez-vous pour le prochain patient."


# --- Panneaux ------------------------------------------------------------------------

func _open_agenda() -> void:
	if state != State.PLAY:
		return
	_set_state(State.AGENDA)
	agenda.open(records, office_busy())


func _close_overlays() -> void:
	agenda.visible = false
	if state == State.AGENDA:
		_set_state(State.PLAY)


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


func _begin_day() -> void:
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	_set_state(State.PLAY)
	Game.say("Camille : Bonjour docteur ! L'agenda du jour est sur votre ordinateur.", "info")


func _end_day() -> void:
	if state == State.CONSULT:
		_day_over_pending = false
		return
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	agenda.visible = false
	_set_state(State.REPORT)
	var last := Game.day >= Cases.day_count()
	overlay = Overlays.day_report(Game.day, Game.day_results, last, _on_report_continue.bind(last), _leave_to_menu)
	ui_root.add_child(overlay)


func _on_report_continue(last: bool) -> void:
	if last:
		Game.delete_save()
		quit_to_menu.emit()
	else:
		Game.next_day()
		next_day_requested.emit()
