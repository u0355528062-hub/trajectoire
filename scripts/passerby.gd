class_name Passerby
extends Actor
## Passant : un civil ordinaire (pas un manifestant) qui traverse le quartier d'une entrée à une sortie
## (bouts du boulevard, rues adjacentes), le long des façades, en traversant aux passages piétons.
## Il peut s'arrêter pour regarder ou filmer la manifestation quand c'est calme ; dès que ça chauffe il
## presse le pas vers la sortie la plus sûre, fuit les charges, les explosions et le gaz.
## Ce n'est pas un Npc : la foule ne le recrute jamais (feux, pillage, jets, barricades, cortège...) et
## la police ne le cible pas. Il est seulement inscrit dans `crowd.actors` pour l'évitement mutuel.
## Créé, animé (LOD) et retiré par le gestionnaire Civilians.

var mgr: Civilians
var kind := "walker"          # walker, phone, shopper, elder, stroller, dog
var age := "adult"            # young, adult, elder
var curious := 0.5
var base_speed := 1.3
var lane_n := 17.4            # trottoir nord suivi (z)
var lane_s := -24.2           # trottoir sud suivi (z)
var route: Array[Vector3] = []
var wp := 0
var state := "walk"           # walk, stop, flee, gassed
var state_t := 0.0
var leaving := false          # a décidé de quitter le quartier au plus vite
var done := false             # arrivé à sa sortie : le gestionnaire le retire
var fear := 0.0
var gas_level := 0.0
var hurry := false
var lead: Passerby = null     # marche avec quelqu'un (couple, amis) : on le suit à côté
var lead_side := 1.0
var stuck_t := 0.0

var _walk_act := "idle"
var _walk_prm := {}
var _hold_t := 0.0            # pose de réaction temporaire (sursaut) pendant la marche
var _stop_p := Vector3.ZERO
var _stop_dur := 0.0
var _stops := 0
var _stop_cd := 0.0
var _think_cd := 0.0
var _glance_cd := 0.0
var _glance_off := 0.0
var leave_at := 0.0           # départ différé (annonce du stade 2) : compte à rebours
var leave_run := false
var _cough_t := 0.0
var _danger := Vector3.ZERO
var _prog_t := 0.0
var _prog_ref := Vector3.ZERO
var _skip := 0
var _skip_acc := 0.0

# --- accessoires
var phone: Node3D
var bag_r: Node3D
var bag_l: Node3D
var cane_n: Node3D
var stroller_n: Node3D
var dog_n: Node3D
var leash_n: MeshInstance3D
var _dog_pos := Vector3.ZERO
var _dog_yaw := 0.0
var _dog_ph := 0.0
var _dog_t := 0.0
var gear := {}


func _ready() -> void:
	super._ready()
	gear = CivilKit.dress(human, outfit)
	if age == "elder":
		human.hunch = 0.2
	phone = Props.phone("feed")
	phone.visible = false
	phone.top_level = true
	add_child(phone)
	match kind:
		"phone":
			_walk_act = "call" if _rng.randf() < 0.55 else "phone"
		"shopper":
			bag_r = CivilKit.shopping_bag(_rng)
			bag_r.top_level = true
			add_child(bag_r)
			if _rng.randf() < 0.45:
				bag_l = CivilKit.shopping_bag(_rng)
				bag_l.top_level = true
				add_child(bag_l)
		"elder":
			if _rng.randf() < 0.6:
				cane_n = CivilKit.cane()
				cane_n.top_level = true
				add_child(cane_n)
				_walk_act = "cane"
			else:
				_walk_act = "back" if _rng.randf() < 0.5 else "idle"
		"stroller":
			stroller_n = CivilKit.stroller(_rng)
			stroller_n.top_level = true
			add_child(stroller_n)
			_walk_act = "push"
		"dog":
			dog_n = CivilKit.dog(_rng)
			dog_n.top_level = true
			add_child(dog_n)
			leash_n = CivilKit.leash()
			leash_n.top_level = true
			add_child(leash_n)
			_dog_pos = global_position + global_basis * Vector3(0.6, 0, -0.8)
			_dog_yaw = yaw
			_walk_act = "leash"
		_:
			if _rng.randf() < 0.3:
				_walk_act = "pocket"
	set_act(_walk_act, _walk_prm, 6.0)
	_stop_cd = _rng.randf_range(4.0, 15.0)
	_prog_ref = global_position


## Bornes d'un piéton dans le quartier : pied des façades, rues adjacentes, fronts des deux bouts
static func street_clamp(p: Vector3) -> Vector3:
	p.x = clampf(p.x, -Quartier.BLVD_END + 2.0, Quartier.BLVD_END - 2.0)
	var lim := Quartier.z_limits(p.x)
	p.z = clampf(p.z, lim.x, lim.y)
	if p.z > Quartier.NORTH_Z - 0.35:
		p.x = clampf(p.x, Quartier.SIDE_NORTH[0] + 0.35, Quartier.SIDE_NORTH[1] - 0.35)
	elif p.z < Quartier.SOUTH_Z + 0.35:
		p.x = clampf(p.x, Quartier.SIDE_SOUTH[0] + 0.35, Quartier.SIDE_SOUTH[1] - 0.35)
	return p


func lane(side: String) -> float:
	return lane_n if side == "N" else lane_s


# =================================================================== poses propres aux civils
func _pose(name: String, t: float, p: Dictionary) -> Array:
	match name:
		"push":
			# poignée de poussette tenue à deux mains, paumes vers le bas
			var bob := sin(t * 1.3) * 0.004
			return [_h(Vector3(0.19, 0.99 + bob, 0.44), Vector3(0, -0.25, 1), Vector3(0, -1, 0.2), 0.85, 0.0, Vector3(1, -1, -0.3)),
				_h(Vector3(-0.19, 0.99 + bob, 0.44), Vector3(0, -0.25, 1), Vector3(0, -1, 0.2), 0.85, 0.0, Vector3(-1, -1, -0.3))]
		"leash":
			# laisse dans la main gauche, avant-bras un peu levé
			return [null, _h(_wb(human.shoulder_world("L")) + Vector3(-0.04, -0.4, 0.22) * _k, Vector3(0.1, -0.2, 1), Vector3(0, -0.2, -1), 0.95, 0.0, Vector3(-1, -1, -0.3))]
		"cane":
			# pommeau de la canne dans la main droite, le bras accompagne le pas
			var sw := sin(t * 3.4) * 0.05
			return [_h(_wb(human.shoulder_world("R")) + Vector3(0.06, -0.5, 0.14 + sw) * _k, Vector3(0, -0.2, 1), Vector3(-1, 0, 0), 0.95, 0.0, Vector3(1, -1, -0.3)), null]
	return super._pose(name, t, p)


# =================================================================== accessoires (placement)
func _place_props() -> void:
	var phone_on := act in ["phone", "film", "call", "selfie"] and (_blend > 0.4 or _prev_act in ["phone", "film", "call", "selfie"])
	phone.visible = phone_on
	var pr := human.palm("R")
	if phone_on:
		var f: Vector3 = pr["f"]
		var pp: Vector3 = pr["p"]
		phone.global_transform = Transform3D(Props.basis_up(f, pp), (pr["pos"] as Vector3) + pp * 0.018 + f * 0.012)
	var yb := Basis(Vector3.UP, yaw)
	if bag_r:
		bag_r.global_transform = Transform3D(yb, (pr["pos"] as Vector3) + (pr["p"] as Vector3) * 0.02)
	if bag_l:
		var pl := human.palm("L")
		bag_l.global_transform = Transform3D(yb, (pl["pos"] as Vector3) + (pl["p"] as Vector3) * 0.02)
	if cane_n:
		var top: Vector3 = (pr["pos"] as Vector3) + (pr["p"] as Vector3) * 0.02
		var foot := Vector3(top.x, global_position.y, top.z) + forward() * 0.1
		var axis := (top - foot)
		var bs := Props.basis_up(axis.normalized(), forward())
		bs.y *= axis.length()
		cane_n.global_transform = Transform3D(bs, top)


## Poussette et chien : suivis à chaque mise à jour (même hors des images d'animation)
func _update_followers(delta: float) -> void:
	if stroller_n:
		stroller_n.global_transform = Transform3D(Basis(Vector3.UP, yaw), global_position + forward() * 0.87)
	if dog_n:
		_dog_t += delta
		var k: float = dog_n.get_meta("k", 1.0)
		var want := global_position + Basis(Vector3.UP, yaw) * Vector3(0.55, 0.0, -0.85)
		var to := want - _dog_pos
		to.y = 0.0
		var dist := to.length()
		var spd := clampf(dist * 2.4, 0.0, 6.0) if dist > 0.12 else 0.0
		if spd > 0.0:
			_dog_pos += to / dist * minf(spd * delta, dist)
			if spd > 0.3:
				_dog_yaw = lerp_angle(_dog_yaw, atan2(-to.x, -to.z), minf(1.0, delta * 6.0))
		_dog_pos.y = global_position.y
		dog_n.global_transform = Transform3D(Basis(Vector3.UP, _dog_yaw), _dog_pos)
		var body := dog_n.get_node("Body") as Node3D
		_dog_ph += delta * (4.0 + spd * 5.0 / k) * float(spd > 0.0)
		var amp := clampf(spd, 0.0, 1.2) * 0.45
		var legs := body.get_node("Legs")
		for i in 4:
			var off := [0.0, PI, PI, 0.0][i] as float
			(legs.get_child(i) as Node3D).rotation.x = sin(_dog_ph + off) * amp
		(body.get_node("Tail") as Node3D).rotation.y = sin(_dog_t * (14.0 if spd < 0.3 else 8.0)) * 0.5
		# à l'arrêt : il renifle le trottoir
		var head := body.get_node("Head") as Node3D
		head.rotation.x = lerpf(head.rotation.x, -0.5 if spd < 0.1 and fmod(_dog_t, 6.0) > 2.5 else 0.05, minf(1.0, delta * 3.0))
		if leash_n:
			var pl := human.palm("L")
			CivilKit.span(leash_n, pl["pos"], dog_n.global_transform * (Vector3(0, 0.44, -0.2) * k))


# =================================================================== boucle (LOD)
## La foule espace déjà les mises à jour selon la distance (temps accumulé dans `delta`)
func tick(delta: float, anim: bool) -> void:
	super.tick(delta, anim)
	_update_followers(delta)


func _speed() -> float:
	var s := base_speed
	if hurry or leaving:
		s *= 1.3
	if state in ["flee", "gassed"]:
		s = RUN * (0.55 if age == "elder" or kind == "stroller" else 0.85)
	return s


func _go_wp() -> void:
	if wp >= route.size():
		done = true
		stop_move()
		return
	go(route[wp], false, 0.8)
	speed_want = _speed()


func _set_walk_pose() -> void:
	set_act(_walk_act, _walk_prm, 3.0)


func _think(delta: float) -> void:
	state_t += delta
	_stop_cd -= delta
	_glance_cd -= delta
	gas_level = maxf(gas_level - delta * 0.35, 0.0)
	fear = maxf(fear - delta * 0.025, 0.0)
	if _glance_off > 0.0:
		_glance_off -= delta
		if _glance_off <= 0.0 and state == "walk":
			_look_want = 0.0
	if leave_at > 0.0:
		leave_at -= delta
		if leave_at <= 0.0 and not leaving:
			leave(_danger, leave_run)
	if _hold_t > 0.0:
		_hold_t -= delta
		if _hold_t <= 0.0 and state == "walk":
			_set_walk_pose()
	# avance-t-il vraiment ? (sinon le gestionnaire le retire hors de vue)
	_prog_t += delta
	if _prog_t > 3.0:
		if has_goal and global_position.distance_to(_prog_ref) < 0.6:
			stuck_t += _prog_t
			if stuck_t > 6.0 and wp < route.size() - 1:
				wp += 1             # étape inaccessible : on passe à la suivante
				_go_wp()
		else:
			stuck_t = 0.0
		_prog_t = 0.0
		_prog_ref = global_position
	if lead != null and not is_instance_valid(lead):
		lead = null
	match state:
		"walk":
			_think_walk(delta)
		"stop":
			_think_stop(delta)
		"flee":
			_think_flee(delta)
		"gassed":
			_think_gassed(delta)


func _think_walk(delta: float) -> void:
	if lead != null and not leaving:
		_think_companion(delta)
		return
	if not has_goal:
		wp += 1
		_go_wp()
		if done:
			return
	speed_want = _speed()
	_think_cd -= delta
	if _think_cd > 0.0:
		return
	_think_cd = _rng.randf_range(1.2, 2.5)
	var st := mgr.stage()
	var ip := mgr.interest_point(st)
	var d := Vector2(ip.x - global_position.x, ip.z - global_position.z).length()
	# tension montante : on presse le pas près de la manif (les craintifs dès le calme)
	hurry = leaving or (d < 24.0 and (st >= 1 or calm < 0.3 or fear > 0.25))
	if d < 32.0 and _glance_cd <= 0.0 and _rng.randf() < 0.6:
		look(ip, 1.0)
		_glance_cd = _rng.randf_range(3.0, 7.0)
		_glance_off = _rng.randf_range(1.5, 3.0)
	if leaving or st >= 2 or _stop_cd > 0.0 or _stops >= 2 or d > 26.0 or d < 5.0:
		return
	if _rng.randf() < curious * (0.35 if st == 0 else 0.2):
		start_stop(ip)


## Marche aux côtés de son compagnon ; s'arrête quand il s'arrête
func _think_companion(_delta: float) -> void:
	if lead.done:
		done = true
		return
	if lead.state == "stop":
		if has_goal:
			stop_move()
			face(lead._stop_p)
			set_act("crossed" if idx % 2 == 0 else "pocket", {}, 2.5)
		look(lead._stop_p if fmod(state_t, 7.0) < 4.5 else lead.head_pos(), 1.0)
		return
	if lead.state != "walk" or lead.leaving:
		# il part en courant : chacun pour soi
		var from := lead._danger
		lead = null
		leave(from, fear > 0.5)
		return
	var lb := Basis(Vector3.UP, lead.yaw)
	var tgt := lead.global_position + lb * Vector3(lead_side * 0.7, 0.0, 0.15)
	var dist := Vector2(tgt.x - global_position.x, tgt.z - global_position.z).length()
	var lv := Vector2(lead.vel.x, lead.vel.z).length()
	if dist > 0.15 or lv > 0.2:
		follow(tgt, clampf(lv + dist * 1.5, 0.0, 2.6))
	else:
		stop_move()
	if act != _walk_act and act != "talk":
		_set_walk_pose()
	if fmod(state_t + idx, 9.0) < 2.0:
		look(lead.head_pos(), 1.0)
	else:
		_look_want = 0.0


func start_stop(p: Vector3) -> void:
	state = "stop"
	state_t = 0.0
	_stop_p = p
	_stop_dur = _rng.randf_range(5.0, 13.0)
	_stops += 1
	_stop_cd = _rng.randf_range(18.0, 40.0)
	stop_move()
	face(p)
	look(p, 1.0)
	var r := _rng.randf()
	if kind in ["stroller", "dog"] or r > 0.5 + curious * 0.15:
		set_act(["crossed", "pocket", "idle", "back"][_rng.randi() % 4] if kind not in ["stroller", "dog"] else _walk_act, {}, 2.5)
	else:
		var dir := (p - head_pos()).normalized()
		set_act("film", {"dir": _wbd(dir).normalized()}, 2.5)


func _think_stop(_delta: float) -> void:
	look(_stop_p, 1.0)
	if act == "film" and int(state_t * 2.0) % 4 == 0:
		var dir := (_stop_p - head_pos()).normalized()
		prm = {"dir": _wbd(dir).normalized()}
	if state_t > _stop_dur or mgr.stage() >= 2:
		resume()


func resume() -> void:
	state = "walk"
	state_t = 0.0
	has_face = false
	_look_want = 0.0
	human.hunch = 0.2 if age == "elder" else 0.0
	_set_walk_pose()
	if wp < route.size():
		_go_wp()


# =================================================================== réactions
## Quitter le quartier par la sortie la plus sûre ; en courant si `run`
func leave(from: Vector3, run: bool) -> void:
	_danger = from
	if not leaving or run:
		route = mgr.exit_route(self, from)
		wp = 0
	leaving = true
	lead = null
	if run:
		state = "flee"
		state_t = 0.0
		set_act("cover", {}, 5.0)
	elif state != "walk":
		state = "walk"
		state_t = 0.0
		_set_walk_pose()
	has_face = false
	_go_wp()


func _think_flee(_delta: float) -> void:
	if state_t > 1.3 and act == "cover":
		set_act(_walk_act if kind in ["stroller", "dog"] else "idle", {}, 3.0)
	if not has_goal:
		wp += 1
		_go_wp()
	speed_want = _speed()
	var far := Vector2(_danger.x - global_position.x, _danger.z - global_position.z).length() > 28.0
	if state_t > 4.0 and far and fear < 0.6:
		state = "walk"
		state_t = 0.0
		_set_walk_pose()


## Sursaut à une détonation, une vitre, une charge : regard, petit recul ; fuite si la peur l'emporte
func startle(from: Vector3, amount: float, run := false) -> void:
	if done:
		return
	if run and state != "gassed":
		fear = clampf(fear + amount, 0.0, 1.0)
		look(from + Vector3.UP * 1.2, 1.0)
		if state != "flee":
			leave(from, true)
			if _rng.randf() < 0.35:
				say_cat("fear" if _rng.randf() < 0.6 else "retreat", true)
		return
	fear = clampf(fear + amount * (1.25 - calm * 0.5), 0.0, 1.0)
	look(from + Vector3.UP * 1.2, 1.0)
	if state != "flee" and state != "gassed":
		human.kick_back(0.5)
	if fear > 0.4 or mgr.stage() >= 2:
		if state != "flee" and state != "gassed":
			leave(from, fear > 0.55)
			if _rng.randf() < 0.3:
				say_cat("fear" if _rng.randf() < 0.6 else "warn", true)
	elif state == "walk":
		set_act("head" if _rng.randf() < 0.5 else "cover", {}, 5.0)
		_hold_t = 1.2


## Du gaz sur moi : on se couvre le visage, on tousse et on court hors du nuage
func on_gas(density: float, from: Vector3) -> void:
	gas_level = maxf(gas_level, density)
	if density < 0.1 or done:
		return
	if state == "gassed":
		_danger = from
		return
	fear = clampf(fear + 0.4, 0.0, 1.0)
	leave(from, true)
	state = "gassed"
	state_t = 0.0
	set_act("cover", {}, 6.0)
	_cough_t = _rng.randf_range(0.2, 0.8)
	if _rng.randf() < 0.6:
		say_cat("gas", true)


func _think_gassed(delta: float) -> void:
	human.hunch = lerpf(human.hunch, 0.5, minf(1.0, delta * 3.0))
	_cough_t -= delta
	if _cough_t <= 0.0:
		_cough_t = _rng.randf_range(1.1, 2.4)
		human.kick_back(0.4)
		var nm := "cough_f_%d" % _rng.randi_range(0, 1) if female else "cough_m_%d" % _rng.randi_range(0, 2)
		AudioLib.play_at(self, nm, head_pos(), -4.0, 6.0, vpitch)
	if not has_goal:
		wp += 1
		_go_wp()
	speed_want = _speed()
	if gas_level < 0.04 and state_t > 3.0:
		human.hunch = 0.2 if age == "elder" else 0.0
		state = "flee"
		state_t = 2.0
