class_name NpcFront
extends RefCounted
## Tenue d'un PNJ du cortège pendant le face-à-face avec la police (voir Standoff) : poing levé, cris en porte-voix,
## doigt pointé vers les CRS, bras croisés, téléphone levé, sit-in pour les plus calmes, recul des craintifs.
## Le choix des attitudes dépend des humeurs (colère, peur) et du caractère (audace, calme).

const SIT_MAX := 5               # nombre de manifestants assis en même temps


## Plus proche policier (mis en cache : recalculé deux fois par seconde)
static func cop_of(n: Npc, delta: float) -> Cop:
	n._cop_cd -= delta
	if n._cop_cd <= 0.0 or (n._cop != null and not is_instance_valid(n._cop)):
		n._cop_cd = 0.5 + n._rng.randf() * 0.2
		n._cop = n.crowd.police.nearest_cop(n.global_position, 45.0) if n.crowd.police else null
	return n._cop


static func target_point(n: Npc, cop: Cop) -> Vector3:
	if cop != null and is_instance_valid(cop):
		return cop.global_position + Vector3.UP * 1.5
	var pol := n.crowd.police
	if pol != null:
		return pol.line_c + Vector3.UP * 1.5
	return n.global_position + Vector3(6, 1.5, 0)


## Humeur du moment : la proximité des policiers excite ou effraie
static func mood_tick(n: Npc, delta: float) -> void:
	var pol := n.crowd.police
	if pol == null or pol.stage < 2:
		return
	var cop := cop_of(n, 0.0)
	if cop == null:
		return
	var d := cop.global_position.distance_to(n.global_position)
	if d < 22.0:
		n.anger = minf(n.anger + delta * 0.006 * (0.6 + n.bold) * float(pol.stage - 1), 1.0)
		if d < 8.0 and n.bold < 0.5:
			n.fear = minf(n.fear + delta * 0.03 * (1.0 - n.bold), 1.0)


## Debout face à la police, selon la rang et l'humeur
static func think(n: Npc, delta: float) -> void:
	var crowd := n.crowd
	var so := crowd.standoff
	var cop := cop_of(n, delta)
	var tp := target_point(n, cop)
	mood_tick(n, delta)
	if n.human.sit > 0.05 and n._home_sub != "f_sit":
		n.stop_move()
		n.human.sit = move_toward(n.human.sit, 0.0, delta * 2.2)
		n.set_act("crossed", {}, 3.0)
		return
	# attente en cours ?
	if n._home_sub.begins_with("f_") and n._home_t < n._home_dur:
		_run_sub(n, delta, tp, cop)
		return
	# nouvelle attitude
	n._home_t = 0.0
	var st: int = crowd.police.stage if crowd.police else 2
	var d_cop := cop.global_position.distance_to(n.global_position) if cop else 30.0
	# sit-in : les plus calmes s'assoient face aux CRS tant que ça reste « tendu »
	if st == 2 and n.prop == "" and n.calm > 0.55 and n.bold < 0.8 and n.fear < 0.15 and d_cop > 8.0 \
			and so.row_of(n) <= 1 and sitters(crowd) < SIT_MAX and n._rng.randf() < 0.3:
		n._home_sub = "f_sit"
		n._home_dur = n._rng.randf_range(22.0, 48.0)
		n.stance = "sit"
		n.stop_move()
		if n._rng.randf() < 0.6:
			n.say_cat("defy", true)
		return
	var w := {
		"f_fist": 0.8 + 2.4 * n.anger + 0.9 * n.bold,
		"f_shout": 0.3 + 2.2 * n.anger + 0.9 * n.bold,
		"f_point": 0.2 + 0.9 * n.bold + 0.8 * n.anger,
		"f_film": 0.9 * n.curious * (1.0 - n.anger * 0.5),
		"f_cross": 0.5 + 1.4 * n.calm - 0.6 * n.bold,
		"f_akimbo": 0.5 + 0.4 * n.bold,
		"f_clap": 0.3 + 0.7 * n.anger,
	}
	if n.prop == "" and n.fear < 0.3 and n.calm > 0.6:
		# les plus posés tentent de ramener le calme quand la colère monte autour d'eux
		w["f_calm"] = 1.8 * clampf(n.calm - 0.55, 0.0, 1.0) * (0.25 + so.anger_avg)
	if n.fear > 0.35:
		w["f_scared"] = 1.0 + 3.0 * n.fear
		w["f_fist"] *= 0.3
		w["f_shout"] *= 0.4
	if n.prop != "":
		# les accessoires occupent déjà les mains : seulement des cris et du regard
		w = {"f_hold": 1.0}
	var tot := 0.0
	for k in w:
		tot += float(w[k])
	var r := n._rng.randf() * tot
	var pick := "f_cross"
	for k in w:
		r -= float(w[k])
		if r <= 0.0:
			pick = k
			break
	n._home_sub = pick
	match pick:
		"f_fist":
			n._home_dur = n._rng.randf_range(3.0, 7.0)
		"f_shout":
			n._home_dur = n._rng.randf_range(2.4, 3.6)
			var cat := "defy" if n._rng.randf() < 0.45 else ("anger" if n._rng.randf() < 0.6 else "slogan")
			if n.anger < 0.15 and cat == "anger":
				cat = "defy"
			n.say_cat(cat, true)
		"f_point":
			n._home_dur = n._rng.randf_range(2.0, 3.8)
			if n._rng.randf() < 0.4:
				n.say_cat("police" if n._rng.randf() < 0.5 else "anger", true)
		"f_film":
			n._home_dur = n._rng.randf_range(6.0, 12.0)
			Props.set_phone_screen(n.phone, "cam")
			if n._rng.randf() < 0.3:
				n.say_cat("film", false, -3.0)
		"f_calm":
			n._home_dur = n._rng.randf_range(3.0, 4.5)
			n.say_cat("calm", true)
		"f_scared":
			n._home_dur = n._rng.randf_range(3.0, 6.0)
			if n._rng.randf() < 0.5:
				n.say_cat("fear" if n._rng.randf() < 0.5 else "retreat", true)
		"f_clap":
			n._home_dur = n._rng.randf_range(3.0, 6.0)
		"f_hold":
			n._home_dur = n._rng.randf_range(4.0, 9.0)
			if n._rng.randf() < 0.25 + 0.5 * n.anger:
				n.say_cat("defy" if n._rng.randf() < 0.6 else "slogan", true)
		_:
			n._home_dur = n._rng.randf_range(5.0, 12.0)


static func sitters(crowd: Crowd) -> int:
	var c := 0
	for m in crowd.npcs:
		if m.stance == "sit":
			c += 1
	return c


static func _run_sub(n: Npc, delta: float, tp: Vector3, cop: Cop) -> void:
	n.look(tp, 0.8)
	if not n.has_goal:
		n.face(tp)
	var dir := (tp - n.head_pos()).normalized()
	# pendant un chant, les gestes suivent le rythme (sauf assis, apeuré ou en train de filmer)
	if n.crowd.chanting and n._home_sub in ["f_fist", "f_shout", "f_point", "f_cross", "f_akimbo", "f_clap"]:
		n.chant_pose(n.crowd.beat_pulse(n.idx))
		n.human.hunch = lerpf(n.human.hunch, 0.0, minf(1.0, delta * 2.0))
		return
	match n._home_sub:
		"f_fist":
			var k := 0.55 + 0.45 * sin(n._home_t * 3.2 + float(n.idx)) if n.crowd.chanting else 0.85
			n.set_act("fist", {"k": clampf(k, 0.0, 1.0)}, 4.0)
			n.jaw_extra = 0.0
		"f_shout":
			n.set_act("cup", {}, 4.0)
		"f_point":
			var ld := n._wbd(dir)                  # direction dans le repère du corps (+X = droite)
			n.set_act("point", {"dir": Vector3(ld.x, clampf(ld.y, 0.0, 0.5), ld.z)}, 5.0)
		"f_film":
			n.set_act("film", {"dir": n._wbd(dir).normalized()}, 2.5)
		"f_calm":
			# paumes ouvertes, on fait signe de baisser d'un ton ; l'entourage s'apaise un peu
			n.set_act("refuse", {}, 3.0)
			if int(n._home_t * 2.0) != int((n._home_t - delta) * 2.0):
				for o in n.crowd.neighbors(n.global_position, 6.0):
					if o != n and o is Npc:
						(o as Npc).anger = maxf((o as Npc).anger - 0.035, 0.0)
		"f_scared":
			n.set_act("head" if n.fear > 0.6 else "cover", {}, 3.0)
			n.human.hunch = lerpf(n.human.hunch, 0.35, minf(1.0, delta * 3.0))
		"f_clap":
			n.set_act("clap", {"gap": 0.04 + 0.12 * (0.5 + 0.5 * sin(n._home_t * 9.0))}, 4.0)
		"f_hold":
			n.set_act(n._prop_rest_pose() if not n.crowd.chanting else n._prop_cheer_pose()[0], {} if not n.crowd.chanting else n._prop_cheer_pose()[1], 3.0)
		"f_sit":
			_run_sit(n, delta, tp, cop)
		"f_akimbo":
			n.set_act("akimbo", {}, 3.0)
		_:
			n.set_act("crossed", {}, 3.0)
	if n._home_sub != "f_scared":
		n.human.hunch = lerpf(n.human.hunch, 0.0, minf(1.0, delta * 2.0))


static func _run_sit(n: Npc, delta: float, tp: Vector3, cop: Cop) -> void:
	n.stop_move()
	n.human.sit = move_toward(n.human.sit, 1.0, delta * 1.6)
	var pol := n.crowd.police
	var close := cop != null and cop.global_position.distance_to(n.global_position) < 6.5
	if n.human.sit > 0.7:
		var ph := fmod(n._home_t, 14.0)
		if ph < 5.0 and n.crowd.chanting:
			n.set_act("fist", {"k": 0.9}, 4.0)
		elif ph < 9.0:
			n.set_act("crossed", {}, 3.0)
		else:
			n.set_act("akimbo", {}, 3.0)
	if (pol != null and pol.stage >= 3) or n.fear > 0.2 or close or n.anger > 0.65:
		n._home_t = n._home_dur          # on se lève
		n.stance = ""
		if n.fear > 0.2 or close:
			n.say_cat("retreat", true)
	if n._home_t >= n._home_dur - delta:
		n.stance = ""


## À l'arrière : on se tient à distance, on regarde, on commente
static func think_rear(n: Npc, delta: float) -> void:
	var cop := cop_of(n, delta)
	var tp := target_point(n, cop)
	if n.human.sit > 0.05:
		n.human.sit = move_toward(n.human.sit, 0.0, delta * 2.2)
		n.stop_move()
		return
	n.look(tp, 0.8)
	if not n.has_goal:
		n.face(tp)
	if n._home_sub.begins_with("r_") and n._home_t < n._home_dur:
		match n._home_sub:
			"r_head":
				n.set_act("head", {}, 3.0)
				n.human.hunch = lerpf(n.human.hunch, 0.3, minf(1.0, delta * 3.0))
			"r_film":
				var dir := (tp - n.head_pos()).normalized()
				n.set_act("film", {"dir": n._wbd(dir).normalized()}, 2.5)
			_:
				n.set_act("crossed", {}, 3.0)
				n.human.hunch = lerpf(n.human.hunch, 0.12, minf(1.0, delta * 3.0))
		return
	n._home_t = 0.0
	var r := n._rng.randf()
	if n.fear > 0.5 and r < 0.6:
		n._home_sub = "r_head"
		if n._rng.randf() < 0.5:
			n.say_cat("fear" if n._rng.randf() < 0.6 else "retreat", true)
	elif r < 0.5 and n.fear < 0.6:
		n._home_sub = "r_film"
		Props.set_phone_screen(n.phone, "cam")
	else:
		n._home_sub = "r_cross"
	n._home_dur = n._rng.randf_range(4.0, 9.0)
