class_name Resident
extends Actor
## Habitant à son balcon ou à sa fenêtre : sort de chez lui, s'accoude, regarde la manifestation, la filme,
## fume, téléphone, applaudit ou crie sur la police ; rentre quand il y a du gaz ou des détonations proches.
## Pas de physique : il glisse simplement entre l'intérieur et sa place (le sol de la rue ne le concerne pas).
## Animé et retiré par le gestionnaire Residents ; il n'est ni dans `crowd.npcs` ni dans `crowd.actors`.

const STEP := 0.75             # vitesse pour sortir / rentrer (m/s)

var mgr: Residents
var kind := "balcony"          # balcony | window
var mood := "curious"          # curious, supporter, angry, grumpy
var smoker := false
var post := Vector3.ZERO       # place tenue (pieds)
var inside := Vector3.ZERO     # point d'entrée/sortie, derrière la façade
var base_yaw := 0.0            # face à la rue
var spot_i := -1
var state := "out"             # out, idle, in, gone
var state_t := 0.0
var activity := ""
var _target := Vector3.ZERO
var _act_t := 0.0
var _act_dur := 0.0
var _speak_cd := 0.0
var _focus := Vector3.ZERO
var _cig_t := 0.0
var _hurry := false
var _skip := 0
var _skip_acc := 0.0

var phone: Node3D
var cig: Node3D


func _ready() -> void:
	super._ready()
	collision_layer = 0            # pas de collision : hors d'atteinte et sans gêner la physique
	CivilKit.dress(human, outfit)
	if outfit.get("age", "") == "elder":
		human.hunch = 0.15
	phone = Props.phone("feed")
	phone.visible = false
	phone.top_level = true
	add_child(phone)
	if smoker:
		cig = Props.cigarette()
		cig.top_level = true
		cig.visible = false
		add_child(cig)
	_target = post
	_speak_cd = _rng.randf_range(4.0, 12.0)
	_cig_t = _rng.randf_range(0.0, 8.0)


func _fwd() -> Vector3:
	return Vector3(-sin(base_yaw), 0, -cos(base_yaw))


# =================================================================== déplacement simplifié
func _move(delta: float) -> void:
	var to := _target - global_position
	var d := to.length()
	var spd := STEP * (1.8 if _hurry else 1.0)
	if d > 0.01:
		global_position += to / d * minf(d, spd * delta)
		vel = to / d * spd if d > 0.05 else Vector3.ZERO
	else:
		vel = Vector3.ZERO
	var want := base_yaw
	if state == "in" and d > 0.15:
		want = base_yaw + PI           # on se retourne pour rentrer
	elif has_face:
		var fd := face_point - global_position
		if Vector2(fd.x, fd.z).length() > 0.1:
			want = base_yaw + clampf(wrapf(atan2(-fd.x, -fd.z) - base_yaw, -PI, PI), -0.8, 0.8)
	var err := wrapf(want - yaw, -PI, PI)
	yaw += clampf(err, -3.0 * delta, 3.0 * delta)
	rotation = Vector3(0, yaw, 0)
	human.step_in_place = 1.0 if (vel.length() < 0.1 and absf(err) > 0.3) else 0.0


## Mise à jour rare de loin / hors champ (le gestionnaire choisit `every`)
func tick_every(delta: float, anim_every: int) -> void:
	_skip_acc += delta
	_skip += 1
	if _skip % maxi(anim_every, 1) != 0:
		return
	var dd := _skip_acc
	_skip_acc = 0.0
	super.tick(dd, true)


# =================================================================== poses
func _pose(name: String, t: float, p: Dictionary) -> Array:
	if name == "rail":
		# accoudé : avant-bras posés sur la main courante (hauteur h, à z devant soi)
		var h: float = p.get("h", 1.0)
		var z: float = p.get("z", 0.36)
		var tap := sin(t * 0.8) * 0.01
		return [_h(Vector3(0.17, h + tap, z), Vector3(-0.35, 0, 1), Vector3(0, -1, 0), 0.4, 0.0, Vector3(1, -0.2, -0.6)),
			_h(Vector3(-0.17, h, z), Vector3(0.35, 0, 1), Vector3(0, -1, 0), 0.4, 0.0, Vector3(-1, -0.2, -0.6))]
	return super._pose(name, t, p)


func _place_props() -> void:
	var phone_on := act in ["phone", "film", "call"] and _blend > 0.4
	phone.visible = phone_on
	var pr := human.palm("R")
	if phone_on:
		var f: Vector3 = pr["f"]
		var pp: Vector3 = pr["p"]
		phone.global_transform = Transform3D(Props.basis_up(f, pp), (pr["pos"] as Vector3) + pp * 0.018 + f * 0.012)
	if cig:
		cig.visible = activity == "smoke"
		if cig.visible:
			var cp: Vector3 = (pr["pos"] as Vector3) + (pr["f"] as Vector3) * 0.075 + (pr["thumb"] as Vector3) * 0.012
			var ax := (-(pr["p"] as Vector3) + (pr["f"] as Vector3) * 0.3).normalized()
			cig.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, ax)), cp)


# =================================================================== cerveau
func _think(delta: float) -> void:
	state_t += delta
	_speak_cd -= delta
	_cig_t += delta
	match state:
		"out":
			if global_position.distance_to(post) < 0.05:
				state = "idle"
				state_t = 0.0
				pick_activity()
		"idle":
			_act_t += delta
			_run_activity(delta)
			if _act_t > _act_dur:
				pick_activity()
		"in":
			if global_position.distance_to(inside) < 0.05:
				state = "gone"


## Rentre chez soi (calmement, ou en vitesse s'il y a du danger)
func retreat(fast: bool) -> void:
	if state in ["in", "gone"]:
		return
	state = "in"
	state_t = 0.0
	if mgr:
		mgr.retreated += 1
	_target = inside
	_hurry = fast
	has_face = false
	human.lean_extra = 0.0
	set_act("cover" if fast and _rng.randf() < 0.6 else "idle", {}, 4.0)
	_look_want = 0.0


func pick_activity() -> void:
	_act_t = 0.0
	_act_dur = _rng.randf_range(6.0, 16.0)
	human.lean_extra = 0.0
	human.shake = 0.0
	var st := mgr.stage()
	_focus = mgr.interest_point(st)
	var opts: Array[String] = ["watch", "watch", "film"]
	if kind == "balcony":
		opts.append_array(["lean", "lean", "lean"])
	else:
		opts.append("lean")
	if smoker:
		opts.append_array(["smoke", "smoke"])
	if _rng.randf() < 0.25:
		opts.append("call")
	match mood:
		"supporter":
			if st <= 2:
				opts.append_array(["clap", "cheer", "wave"])
				if mgr.crowd and mgr.crowd.chanting:
					opts.append_array(["clap", "clap"])
		"angry":
			if st >= 1:
				opts.append_array(["shout", "shout", "film"])
		"grumpy":
			opts.append_array(["grumpy", "grumpy"])
	if st >= 3:
		opts.append_array(["film", "watch"])
	activity = opts[_rng.randi() % opts.size()]
	face(_focus)
	look(_focus, 1.0)
	match activity:
		"lean":
			var h := 1.0 if kind == "balcony" else 0.92
			set_act("rail", {"h": h, "z": 0.36 if kind == "balcony" else 0.26}, 2.0)
			human.lean_extra = 0.28 if kind == "balcony" else 0.18
		"watch":
			set_act(["crossed", "pocket", "akimbo", "idle", "back"][_rng.randi() % 5], {}, 2.5)
		"film":
			set_act("film", {"dir": _film_target_dir()}, 2.5)
		"smoke":
			set_act("smoke_hold", {}, 2.5)
		"call":
			set_act("call", {}, 2.5)
			_look_want = 0.3
		"clap":
			set_act("clap", {"gap": 0.1}, 3.0)
		"cheer":
			set_act("cheer", {"open": _rng.randf() < 0.5}, 3.0)
			_act_dur = _rng.randf_range(3.0, 5.0)
		"wave":
			set_act("wave", {}, 3.0)
			_act_dur = _rng.randf_range(2.5, 4.0)
		"shout":
			if mgr.police:
				_focus = mgr.police.line_c + Vector3.UP * 1.5
				face(_focus)
				look(_focus, 1.0)
			set_act("point" if _rng.randf() < 0.5 else "fist", {"dir": _film_target_dir(), "k": 1.0}, 3.0)
			_act_dur = _rng.randf_range(3.0, 6.0)
			_speak_cd = 0.0
		"grumpy":
			set_act("crossed", {}, 2.5)


func _film_target_dir() -> Vector3:
	return _wbd((_focus - head_pos()).normalized()).normalized()


func _run_activity(delta: float) -> void:
	match activity:
		"film", "shout":
			if int(_act_t * 2.0) != int((_act_t - delta) * 2.0):
				prm = prm.duplicate()
				prm["dir"] = _film_target_dir()
			if activity == "shout" and _speak_cd <= 0.0:
				_speak_cd = _rng.randf_range(2.5, 5.0)
				say_cat("defy" if _rng.randf() < 0.6 else "anger", true, -2.0)
		"smoke":
			var drag := fmod(_cig_t, 9.0) < 1.4
			set_act("smoke_drag" if drag else "smoke_hold", {}, 3.0)
		"clap":
			prm = {"gap": 0.04 + 0.12 * (0.5 + 0.5 * sin(_act_t * 9.0))}
			if _speak_cd <= 0.0 and _rng.randf() < 0.3:
				_speak_cd = _rng.randf_range(6.0, 14.0)
				say_cat("bravo", true, -4.0)
		"cheer":
			if _speak_cd <= 0.0:
				_speak_cd = _rng.randf_range(6.0, 14.0)
				say_cat("allez" if _rng.randf() < 0.5 else "ouais", true, -4.0)
		"grumpy":
			human.shake = sin(_act_t * 5.0) * 0.6 if fmod(_act_t, 5.0) < 1.2 else 0.0


## Une détonation, une vitre, une charge : on sursaute ; on rentre si c'est trop près
func startle(from: Vector3, near: bool) -> void:
	if state in ["in", "gone"]:
		return
	look(from, 1.0)
	human.kick_back(0.4)
	if near and _rng.randf() < (0.4 if mood == "angry" else 0.7):
		retreat(true)
	elif state == "idle" and activity not in ["film", "shout"] and _rng.randf() < 0.5:
		_focus = from
		activity = "film"
		_act_t = 0.0
		_act_dur = _rng.randf_range(5.0, 10.0)
		human.lean_extra = 0.0
		face(from)
		set_act("film", {"dir": _film_target_dir()}, 3.0)
