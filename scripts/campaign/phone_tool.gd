class_name PhoneTool
extends KitTool
## Téléphone de Sam : clic gauche bref = photo, maintenu = filmer (clic gauche pour arrêter), clic droit = lever le
## téléphone pour cadrer. Le cadre compte : seul ce qui est dans le champ ET assez près fait la valeur d'une vidéo
## (violences policières, taille de la foule, étiquettes de prix, témoignage face caméra…). Batterie et stockage
## limités. Une vidéo arrêtée reste dans le téléphone : la publier est un choix (P : telle quelle, O : visages
## floutés). Événements : film_start, film_stop, film_clip, photo, testimony.

const HOLD_TO_FILM := 0.35        # clic maintenu plus longtemps : on filme au lieu de photographier
const STORAGE_MAX := 900.0        # place libre, en secondes de vidéo
const DRAIN_REC := 0.09           # % de batterie par seconde de vidéo
const DRAIN_IDLE := 0.004
const SAMPLE := 0.25              # analyse du cadre
const HALF_FOV := 0.866           # cos(30°) : demi-champ du capteur
## Valeur de chaque sujet dans une vidéo (le module Opinion décide de l'effet sur les jauges)
const WEIGHT := {"police_lbd": 10.0, "police_baton": 8.0, "arrest": 7.0, "police_gas": 5.0, "police_charge": 6.0,
	"temoignage": 6.0, "prix": 4.0, "crowd": 3.0, "police": 1.0, "casse": 4.0, "cop_hit": 4.0}
## Événements du bus qui se filment (type -> sujet)
const EVENT_SUBJECT := {"police_lbd": "police_lbd", "police_baton": "police_baton", "police_gas": "police_gas",
	"gas_land": "police_gas", "police_charge": "police_charge", "arrest": "arrest", "grab": "arrest",
	"glass_break": "casse", "car_burn": "casse", "car_vandal": "casse", "bus_destroyed": "casse", "shop_smash": "casse",
	"fire_start": "casse", "vandal": "casse", "kick_bus": "casse", "cop_hit": "cop_hit", "cop_down": "cop_hit"}

var battery := 86.0
var storage := STORAGE_MAX
var recording := false
var rec_t := 0.0
var clips: Array = []             # [{clip, sec, subjects, score, published, blur}]
var photos := 0
var confiscated := false

var _press_t := -1.0
var _raise := 0.0
var _sample_t := 0.0
var _q := {}                      # sujet -> qualité accumulée (secondes pondérées) pendant la prise
var _testi := {}                  # id de personnage -> secondes face caméra
var _recent: Array = []           # [heure, sujet, positions]
var _model: Node3D
var _cam_screen := false
var _clock := 0.0


func _ready() -> void:
	super._ready()
	add_to_group("crowd")         # pour entendre les événements à filmer (on_event)


func _build() -> void:
	if _model == null:
		_model = Props.phone("feed")
		_model.top_level = true
		add_child(_model)


func _show(on: bool) -> void:
	if _model:
		_model.visible = on


func _cancel() -> void:
	if recording:
		stop_film()
	_press_t = -1.0


func use() -> void:
	if not equipped or equip_t < 0.5 or confiscated:
		return
	if battery <= 0.0:
		say("Plus de batterie")
		return
	if recording:
		stop_film()
		return
	_press_t = 0.0


func release() -> void:
	if _press_t >= 0.0:
		_press_t = -1.0
		take_photo()


func count_text() -> String:
	return "%d%%" % int(ceilf(battery)) if not confiscated else "—"


func count_pair() -> Array:
	return [str(int(ceilf(battery))), "%"]


func is_empty() -> bool:
	return battery <= 0.0 or confiscated


func prompt() -> Array:
	if confiscated:
		return []
	if battery <= 0.0:
		return [["—"], "Batterie à plat"]
	if recording:
		return [["CLIC GAUCHE"], "Arrêter  ·  ● REC %d:%02d" % [int(rec_t) / 60, int(rec_t) % 60]]
	var unpub := last_unpublished()
	if not unpub.is_empty() and not aim_input:
		return [["P", "O"], "Publier la vidéo (%d s) · en floutant les visages" % int(unpub["sec"])]
	if aim_input:
		return [["CLIC GAUCHE"], "Photo  ·  maintenir : filmer"]
	return [["CLIC DROIT", "CLIC GAUCHE"], "Cadrer · photo (maintenir : filmer)"]


# =================================================================== prises de vue
func start_film() -> void:
	if recording or confiscated or battery <= 0.0:
		return
	if storage < 1.0:
		say("Stockage plein : plus de place pour filmer")
		return
	recording = true
	rec_t = 0.0
	_q = {}
	_testi = {}
	_sample_t = 0.0
	emit_event("film_start", {})


func stop_film() -> void:
	if not recording:
		return
	recording = false
	var sec := snappedf(rec_t, 0.1)
	emit_event("film_stop", {"sec": sec})
	var subj := _subjects_of(_q, true)
	var clip := {"clip": clips.size(), "sec": sec, "subjects": subj, "score": _score(_q, sec), "published": false, "blur": false}
	clips.append(clip)
	emit_event("film_clip", _clip_data(clip))
	for who in _testi:
		if float(_testi[who]) >= 3.0:
			emit_event("testimony", {"who": who})
	if sec >= 1.0:
		say("Vidéo enregistrée (%d s)%s" % [int(sec), "" if subj.is_empty() else " : " + _subjects_label(subj)])
	count_changed.emit()


## Photo : un seul coup d'œil au cadre (avec ce qui vient de se passer dans le champ)
func take_photo() -> void:
	if confiscated or battery <= 0.0:
		return
	if storage < 0.5:
		say("Stockage plein")
		return
	var q := {}
	_sample(q, 1.0)
	var subj := _subjects_of(q, false)
	photos += 1
	storage -= 0.5
	battery = maxf(battery - 0.05, 0.0)
	AudioLib.play_at(self, "phone_shutter", global_position, -8.0, 3.0)
	emit_event("photo", {"subjects": subj})
	count_changed.emit()


## Dernière vidéo pas encore publiée ({} s'il n'y en a pas)
func last_unpublished() -> Dictionary:
	for i in range(clips.size() - 1, -1, -1):
		var c: Dictionary = clips[i]
		if not c["published"] and float(c["sec"]) >= 1.0:
			return c
	return {}


## Publier la dernière vidéo (choix du joueur, ou du script du chapitre) ; false s'il n'y a rien à publier
func publish_last(blur := false) -> bool:
	if confiscated:
		return false
	var c := last_unpublished()
	if c.is_empty():
		return false
	if battery <= 0.0:
		say("Plus de batterie : impossible de publier")
		return false
	c["published"] = true
	c["blur"] = blur
	battery = maxf(battery - 0.5, 0.0)
	emit_event("film_clip", _clip_data(c))
	say("Vidéo publiée%s" % (" (visages floutés)" if blur else ""))
	count_changed.emit()
	return true


## Interpellation : la police garde le téléphone (les vidéos non publiées sont perdues)
func confiscate() -> void:
	if recording:
		stop_film()
	confiscated = true
	for c in clips:
		if not c["published"]:
			c["lost"] = true
	count_changed.emit()


func reload_all() -> void:
	battery = 100.0
	storage = STORAGE_MAX
	count_changed.emit()


func _clip_data(c: Dictionary) -> Dictionary:
	return {"sec": c["sec"], "subjects": (c["subjects"] as Array).duplicate(), "score": c["score"], "published": c["published"],
		"blur": c["blur"], "clip": c["clip"]}


# =================================================================== analyse du cadre
## Bus de la foule : on retient où se sont passées les choses filmables
func on_event(type: String, d: Dictionary) -> void:
	if not EVENT_SUBJECT.has(type):
		return
	var pts: Array = []
	for k in ["pos", "from"]:
		if d.get(k) is Vector3:
			pts.append(d[k])
	if pts.is_empty():
		return
	_recent.append([_clock, EVENT_SUBJECT[type], pts])
	if _recent.size() > 40:
		_recent.pop_front()


func _in_frame(p: Vector3, max_d: float, cos_min := HALF_FOV) -> float:
	var x := cam_xf()
	var to := p - x.origin
	if to.length() < 0.05:
		return 0.0
	if (-x.basis.z).dot(to.normalized()) < cos_min:
		return 0.0
	var d := p.distance_to(global_position)
	if d > max_d:
		return 0.0
	return clampf(1.0 - (d - max_d * 0.35) / (max_d * 0.65), 0.0, 1.0)


## Ajoute à `q` la qualité de chaque sujet visible pendant `dt` secondes
func _sample(q: Dictionary, dt: float) -> void:
	var k := 1.0
	if player and Vector3(player.velocity.x, 0, player.velocity.z).length() > 3.0:
		k = 0.6                    # en courant, l'image tremble
	var c := crowd()
	# foule
	if c:
		var n := 0
		for npc in c.npcs:
			if is_instance_valid(npc) and _in_frame(npc.global_position + Vector3.UP * 1.2, 30.0) > 0.0:
				n += 1
		if n >= 8:
			_add(q, "crowd", dt * k * clampf(float(n) / 40.0, 0.25, 1.0))
		# policiers dans le champ
		if c.police:
			for cop in c.police.cops:
				if is_instance_valid(cop) and _in_frame(cop.global_position + Vector3.UP * 1.2, 25.0) > 0.0:
					_add(q, "police", dt * k * 0.5)
					break
		# témoignage : un personnage d'histoire tout près, face caméra
		for a in c.actors:
			if a is StoryActor and is_instance_valid(a):
				var hp: Vector3 = (a as StoryActor).head_pos()
				if _in_frame(hp, 3.4, 0.93) <= 0.0:
					continue
				var to_me := (global_position - a.global_position) * Vector3(1, 0, 1)
				if (a as StoryActor).forward().dot(to_me.normalized()) > 0.3:
					_add(q, "temoignage", dt * k)
					var id := (a as StoryActor).story_id
					_testi[id] = float(_testi.get(id, 0.0)) + dt
	# étiquettes de prix (supérette, totem de la station-service)
	var tags: Array = get_tree().get_nodes_in_group("price_tags")
	var seen_tag := false
	for t in tags:
		if t is Node3D and _in_frame((t as Node3D).global_position, 6.0) > 0.0:
			seen_tag = true
			break
	if not seen_tag:
		for id in ["supermarche", "station_service"]:
			if Quartier.SPOTS.has(id) and _in_frame(Quartier.spot(id) + Vector3.UP * 1.5, 8.0) > 0.0:
				seen_tag = true
	if seen_tag:
		_add(q, "prix", dt * k)
	# ce qui vient de se passer dans le champ (dans les 1,5 dernières secondes)
	for e in _recent:
		if _clock - float(e[0]) > 1.5:
			continue
		for p in e[2]:
			var qq := _in_frame(p, 35.0)
			if qq > 0.0:
				_add(q, e[1], maxf(qq, 0.3) * k * maxf(dt, 0.5))
				break


func _add(q: Dictionary, s: String, v: float) -> void:
	q[s] = float(q.get(s, 0.0)) + v


## Sujets retenus : un événement vu une fois suffit ; un sujet continu doit être tenu dans le cadre
func _subjects_of(q: Dictionary, video: bool) -> Array:
	var out: Array = []
	for s in q:
		var need := 0.1 if EVENT_SUBJECT.values().has(s) else (1.0 if video else 0.2)
		if float(q[s]) >= need:
			out.append(s)
	out.sort_custom(func(a, b): return float(WEIGHT.get(a, 1.0)) > float(WEIGHT.get(b, 1.0)))
	return out


func _score(q: Dictionary, sec: float) -> float:
	var s := 0.0
	for k in _subjects_of(q, true):
		var ref := 0.5 if EVENT_SUBJECT.values().has(k) else 4.0
		s += float(WEIGHT.get(k, 1.0)) * clampf(float(q[k]) / ref, 0.0, 1.0)
	if sec < 3.0:
		s *= 0.4                   # trop court pour être utilisable
	return snappedf(s, 0.1)


static func _subjects_label(subj: Array) -> String:
	var names := {"police_lbd": "tir de LBD", "police_baton": "coups de matraque", "arrest": "interpellation",
		"police_gas": "gaz", "police_charge": "charge", "temoignage": "témoignage", "prix": "prix", "crowd": "la foule",
		"police": "la police", "casse": "casse", "cop_hit": "violences sur la police"}
	var out: PackedStringArray = []
	for s in subj:
		out.append(str(names.get(s, s)))
	return ", ".join(out)


# =================================================================== boucle et mains
func step(delta: float) -> void:
	super.step(delta)
	_clock += delta
	if _press_t >= 0.0:
		_press_t += delta
		if _press_t > HOLD_TO_FILM:
			_press_t = -1.0
			start_film()
	battery = maxf(battery - DRAIN_IDLE * delta, 0.0)
	if recording:
		rec_t += delta
		storage -= delta
		battery = maxf(battery - DRAIN_REC * delta, 0.0)
		_sample_t += delta
		if _sample_t >= SAMPLE:
			_sample(_q, _sample_t)
			_sample_t = 0.0
		if int(rec_t) != int(rec_t - delta):
			count_changed.emit()
		if battery <= 0.0:
			stop_film()
			say("Batterie à plat : la vidéo s'arrête")
		elif storage <= 0.0:
			stop_film()
			say("Stockage plein : la vidéo s'arrête")
	var want := 1.0 if (equipped and (aim_input or recording or _press_t >= 0.0)) else 0.0
	_raise = move_toward(_raise, want, delta * 4.0)
	if _model:
		var cam := _raise > 0.5
		if cam != _cam_screen:
			_cam_screen = cam
			Props.set_phone_screen(_model, "cam" if cam else "feed")


func _hand_targets() -> Array:
	if equip_t <= 0.0 or human == null:
		return [null, null]
	var w := ease01(equip_t)
	var k := human.arm_length() / 0.58
	var shr := human.shoulder_world("R")
	var t := Time.get_ticks_msec() / 1000.0
	# bas : on regarde l'écran
	var low_pos := shr + bdir(Vector3(-0.1, -0.3, 0.3) * k) + Vector3(0, sin(t * 0.7) * 0.01, 0)
	var low_f := bdir(Vector3(0, 0.6, 0.8))
	var low_p := bdir(Vector3(0, 0.8, -0.6))
	var r := hand(low_pos, low_f, low_p, 0.55, w)
	var l: Variant = null
	var e := ease01(_raise)
	var cf := cam_fwd()
	var right := cf.cross(Vector3.UP).normalized()
	var upp := right.cross(cf).normalized()
	var center := human.head_world() + cf * 0.34 - upp * 0.12 + right * 0.05
	if e > 0.0:
		# levé : tenu à deux mains devant le visage, objectif vers la scène
		var rp := center + right * 0.045 - upp * 0.02
		r = hand(low_pos.lerp(rp, e), low_f.slerp(upp, e), low_p.slerp(-cf, e), lerpf(0.55, 0.45, e), w)
		l = hand(center - right * 0.05 - upp * 0.02, upp, right, 0.5, w * e)
	if _model and _model.visible:
		if e > 0.5:
			_model.global_transform = Transform3D(Props.basis_up(upp, -cf), center)
		else:
			var pr := human.palm("R")
			var f: Vector3 = pr["f"]
			var p: Vector3 = pr["p"]
			_model.global_transform = Transform3D(Props.basis_up(f, p), (pr["pos"] as Vector3) + p * 0.018 + f * 0.012)
	return [r, l]
