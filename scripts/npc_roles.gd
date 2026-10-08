class_name NpcRoles
extends RefCounted
## Rôles particuliers dans la foule : le médic (gilet à croix rouge, sac de secours) qui reste en retrait et accourt
## vers les blessés (voir NpcCare), et le reporter (brassard PRESSE, appareil à longue focale) qui cherche le bon
## angle pour photographier ce qui se passe : interpellations, charges, incendies, nuages de gaz...

static var _tex := {}
static var _quad: QuadMesh


static func _badge_mat(file: String) -> StandardMaterial3D:
	if not _tex.has(file):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(Props.DIR + file)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.roughness = 0.8
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_tex[file] = m
	return _tex[file]


static func _badge(h: Human, file: String, size: Vector2, bone: String, off: Vector3, back := false) -> void:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _badge_mat(file)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var s := h.hscale()
	h.attach(bone, mi, off * s, Basis(Vector3.UP, PI) if back else Basis.IDENTITY)


## Équipement visuel du rôle (appelé une fois, à la création du PNJ)
static func build_gear(n: Npc) -> void:
	match n.role:
		"medic":
			_badge(n.human, "badge_cross.png", Vector2(0.11, 0.11), "spine02", Vector3(0.075, 0.1, 0.218))
			_badge(n.human, "badge_cross.png", Vector2(0.22, 0.22), "spine02", Vector3(0.0, 0.1, -0.2), true)
		"press":
			_badge(n.human, "badge_press.png", Vector2(0.15, 0.056), "spine02", Vector3(0.0, 0.13, 0.19))
			_badge(n.human, "badge_press.png", Vector2(0.32, 0.12), "spine02", Vector3(0.0, 0.1, -0.2), true)
			n.cam_hang = Props.camera()
			n.human.attach("spine02", n.cam_hang, Vector3(-0.05, -0.04, 0.2) * n.human.hscale(), Basis(Vector3.RIGHT, deg_to_rad(18)))
			n.cam_held = Props.camera()
			n.cam_held.top_level = true
			n.cam_held.visible = false
			n.add_child(n.cam_held)


# ------------------------------------------------------------------ médic
static func medic_post(n: Npc) -> Vector3:
	var so := n.crowd.standoff
	if so.active:
		var side := 1.0 if n.idx % 2 == 0 else -1.0
		return n.crowd.clamp_area(Vector3(so.center.x - 9.0, 0.0, so.center.z + 8.0 * side))
	return n.home_pos


static func think_medic(n: Npc, delta: float) -> void:
	var crowd := n.crowd
	if n.fear > 0.6 and crowd.standoff.active:
		# trop dangereux : on se met à l'abri, mais on reste à portée de la foule
		var rp := crowd.standoff.rear_spot(n)
		if not n.has_goal and Vector2(rp.x - n.global_position.x, rp.z - n.global_position.z).length() > 3.0:
			n.go(rp, true, 0.6)
		NpcFront.think_rear(n, delta)
		return
	var post := medic_post(n)
	if not n.has_goal and Vector2(post.x - n.global_position.x, post.z - n.global_position.z).length() > (2.5 if crowd.standoff.active else 5.0) and n.human.sit < 0.3:
		n.go(post, false, 0.8)
	if not n.has_goal and n._home_sub in ["", "stand"] and n._rng.randf() < delta * 0.05 and not crowd.standoff.active:
		var a := n._rng.randf() * TAU
		n.go(crowd.clamp_area(n.home_pos + Vector3(cos(a), 0, sin(a)) * n._rng.randf_range(1.5, 6.0)), false, 0.5)
	if crowd.standoff.active:
		# veille attentive : regarde la ligne, bras croisés
		var tp := NpcFront.target_point(n, NpcFront.cop_of(n, delta))
		n.look(tp, 0.6)
		if not n.has_goal:
			n.face(tp)
	n._home_idle_cycle(delta)


# ------------------------------------------------------------------ reporter
## Cherche un sujet à photographier : {"pos": Vector3, "w": poids}
static func press_subject(n: Npc) -> Dictionary:
	var crowd := n.crowd
	var pol := crowd.police
	var best := [0.0, {}]            # [poids, sujet] : tableau car une lambda ne modifie pas les variables locales
	var add := func(pos: Vector3, w: float, kind: String) -> void:
		w *= n._rng.randf_range(0.8, 1.2)
		if kind == str(n.data.get("press_kind", "")) and pos.distance_to(n.data.get("press_pos", Vector3.ZERO)) < 4.0:
			w *= 0.35                      # pas deux fois la même scène
		if w > float(best[0]):
			best[0] = w
			best[1] = {"pos": pos, "kind": kind}
	if pol != null:
		for c in pol.cops:
			if not is_instance_valid(c):
				continue
			if c.state in ["arrest", "escort"]:
				add.call(c.global_position, 5.0, "arrest")
			elif c.state in ["charge", "strike"]:
				add.call(c.global_position, 3.2, "charge")
			elif c.state in ["gas", "lbd", "spray"]:
				add.call(c.global_position, 2.6, "shot")
		if pol.stage >= 1:
			add.call(pol.line_c + Vector3.UP, 1.2 + 0.4 * float(pol.stage), "line")
	for fs in crowd.fire_srcs:
		if fs.burning:
			add.call(fs.global_position, 3.6 if fs is PoliceVehicle else 2.2, "fire")
	for g in n.get_tree().get_nodes_in_group("gas_clouds"):
		add.call(g.global_position + Vector3.UP, 2.4, "gas")
	if crowd.player != null and crowd.player.wanted > 0.25:
		add.call(crowd.player.global_position, 1.6 + crowd.player.wanted, "player")
	add.call(crowd.cortege_center(), 1.0, "crowd")
	return best[1]


static func vantage(n: Npc, subject: Vector3) -> Vector3:
	var crowd := n.crowd
	var pol := crowd.police
	var away := Vector3(n.global_position.x - subject.x, 0.0, n.global_position.z - subject.z)
	away = away.normalized() if away.length() > 0.5 else Vector3.LEFT
	var spot := subject + away * n._rng.randf_range(8.0, 12.0)
	# jamais en première ligne : à distance de la ligne de police, hors du gaz
	if pol != null:
		var keep := maxf(crowd.standoff.gap + 1.5, 10.0) if crowd.standoff.active else 12.0
		spot.x = minf(spot.x, pol.line_c.x - keep)
	var tries := 0
	while crowd.gas_near(spot, 2.0) != null and tries < 4:
		spot += away * 3.0
		tries += 1
	return crowd.clamp_area(spot)


static func think_press(n: Npc, delta: float) -> void:
	var crowd := n.crowd
	n._press_t -= delta
	var shooting: bool = n._home_sub == "shoot"
	# sujet : on en cherche un nouveau de temps en temps
	if n._press_t <= 0.0 or not n.data.has("press_pos"):
		var sub := press_subject(n)
		if sub.is_empty():
			n._press_t = 4.0
			return
		n.data["press_pos"] = sub["pos"]
		n.data["press_kind"] = sub["kind"]
		n.data["press_spot"] = vantage(n, sub["pos"])
		n._press_t = n._rng.randf_range(9.0, 15.0)
		n._home_sub = "walk"
		n._home_t = 0.0
		n.go(n.data["press_spot"], false, 0.8)
		shooting = false
	var subj: Vector3 = n.data["press_pos"]
	var spot: Vector3 = n.data["press_spot"]
	var d := Vector2(spot.x - n.global_position.x, spot.z - n.global_position.z).length()
	if d > 1.2 and n._home_sub == "walk":
		if not n.has_goal:
			n.go(spot, d > 14.0, 0.8)
		n.set_act("idle", {}, 3.0)
		n.look(subj + Vector3.UP * 1.5, 0.6)
		n.shutter_cd = 0.0
		return
	# en position : on cadre et on déclenche
	if n._home_sub != "shoot":
		n._home_sub = "shoot"
		n._home_t = 0.0
		n.stop_move()
		if n._rng.randf() < 0.3:
			n.say_cat("film", false, -2.0)
	n.face(subj)
	var tgt := subj + Vector3.UP * 1.3
	n.look(tgt, 1.0)
	var dir := (tgt - n.head_pos()).normalized()
	n.set_act("shoot", {"dir": n._wbd(dir).normalized()}, 3.0)
	n.shutter_cd -= delta
	if n.shutter_cd <= 0.0:
		n.shutter_cd = n._rng.randf_range(0.7, 2.2)
		if crowd.near_listener(n.global_position, 25.0):
			AudioLib.play_at(n, "phone_shutter", n.head_pos(), -8.0, 6.0, n._rng.randf_range(0.9, 1.1))
