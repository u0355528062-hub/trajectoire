class_name Npc
extends Actor
## Manifestant non joueur : ajoute à l'Actor un petit cerveau (activité de fond + réactions),
## des accessoires (pancarte, banderole, fumigène, mégaphone, mortier...) et des états
## (regarder un feu, l'entretenir, attaquer l'abribus...).

var curious := 0.5
var role := "loner"          # march, chat, loner, bloc
var group := -1
var slot := Vector2.ZERO     # cortège : (latéral, recul)
var home_pos := Vector3.ZERO
var prop := ""               # sign, banner, flare, megaphone, mortar
var sign_idx := 1
var smoker := false

var state := "home"
var state_t := 0.0
var sub := ""
var sub_t := 0.0
var data := {}
var react_cd := 0.0
var _idle_t := 0.0
var _idle_pose := "idle"
var _glance_cd := 0.0
var _look_cd := 0.0
var _home_sub := ""
var _home_t := 0.0
var _home_dur := 0.0
var _mortar_cd := 0.0
var _flare_cd := 0.0
var _cig_t := 0.0
var _whistle_cd := 0.0

# --- humeurs (0..1) : elles montent avec les événements et redescendent avec le temps
var fear := 0.0
var anger := 0.0
var fatigue := 0.0
var thirst := 0.0
var cold := 0.5               # sensibilité au froid (trait)
var stance := ""              # "", "sit" : attitude prise dans le face-à-face
var _cop: Cop
var _cop_cd := 0.0

# --- accessoires
var phone: Node3D
var sign_node: Node3D
var flare: Flare
var mortar_m: Node3D
var lighter: Node3D
var cig: Node3D
var bottle_node: Node3D      # bouteille d'eau (créée à la première utilisation)
var cam_hang: Node3D         # reporter : appareil pendu au cou
var cam_held: Node3D         # reporter : appareil au visage
var _press_t := 0.0
var shutter_cd := 0.0
var item: Node3D             # objet porté (Burnable)
var stone_vis: MeshInstance3D
var pole_node: Node3D
var _fuse_fx: GPUParticles3D
var _fuse_light: OmniLight3D
var _cig_smoke: GPUParticles3D


func _ready() -> void:
	super._ready()
	_build_props()
	NpcRoles.build_gear(self)
	_idle_pose = _pick_idle()
	_mortar_cd = _rng.randf_range(25.0, 50.0)
	_flare_cd = _rng.randf_range(2.0, 12.0)
	_cig_t = _rng.randf_range(0.0, 8.0)
	_whistle_cd = _rng.randf_range(10.0, 40.0)
	cold = _rng.randf_range(0.1, 0.9) if outfit.get("top", "hoodie") != "jacket" else _rng.randf_range(0.0, 0.5)
	if outfit.get("top", "") == "tshirt":
		cold = clampf(cold + 0.35, 0.0, 1.0)
	thirst = _rng.randf_range(0.0, 0.45)
	fatigue = _rng.randf_range(0.0, 0.4)


func _pre_tick(delta: float) -> void:
	gas_level = maxf(gas_level - delta * 0.35, 0.0)
	hostile = maxf(hostile - delta * 0.02, 0.0)
	react_cd = maxf(react_cd - delta, 0.0)
	_glance_cd = maxf(_glance_cd - delta, 0.0)
	_look_cd = maxf(_look_cd - delta, 0.0)
	state_t += delta
	fear = maxf(fear - delta * 0.035, 0.0)
	anger = maxf(anger - delta * 0.012, 0.0)
	fatigue = clampf(fatigue + delta * (0.0035 if human.sit < 0.5 else -0.02), 0.0, 1.0)
	thirst = minf(thirst + delta * 0.004, 1.0)
	if human.kneel > 0.0 and state not in ["arrested", "aid"]:
		human.kneel = move_toward(human.kneel, 0.0, delta * 2.0)
	# assis seulement quand l'attitude le prévoit : toute autre situation relève le personnage
	if human.sit > 0.0 and not (state == "home" and _home_sub in ["f_sit", "r_sit", "rest_sit"]):
		human.sit = move_toward(human.sit, 0.0, delta * 2.5)
		if human.sit <= 0.0:
			stance = ""


## La peur monte plus vite chez les craintifs
func scare(a: float) -> void:
	fear = clampf(fear + a * (1.35 - bold), 0.0, 1.0)


## La colère monte plus vite chez les audacieux et les moins calmes
func enrage(a: float) -> void:
	anger = clampf(anger + a * (0.5 + bold * 0.8) * (1.3 - calm * 0.6), 0.0, 1.0)


# =================================================================== accessoires
func _build_props() -> void:
	phone = Props.phone("feed")
	phone.visible = false
	phone.top_level = true
	add_child(phone)
	match prop:
		"sign":
			sign_node = Props.sign_board(sign_idx)
			sign_node.top_level = true
			add_child(sign_node)
		"banner":
			pole_node = Node3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.016
			pm.bottom_radius = 0.018
			pm.height = 2.05
			pm.radial_segments = 8
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			mi.material_override = Props.wood()
			mi.position.y = 0.42
			pole_node.add_child(mi)
			pole_node.top_level = true
			add_child(pole_node)
		"flare":
			_new_flare()
		"megaphone":
			mega = Props.megaphone()
			mega.top_level = true
			add_child(mega)
		"mortar":
			mortar_m = MortarModel.build()
			mortar_m.top_level = true
			add_child(mortar_m)
			_fuse_fx = Fx.embers(30, Vector3(0.005, 0.005, 0.005), Color(1, 0.75, 0.4), 1.2)
			_fuse_fx.lifetime = 0.4
			_fuse_fx.emitting = false
			_fuse_fx.top_level = true
			add_child(_fuse_fx)
			_fuse_light = OmniLight3D.new()
			_fuse_light.light_color = Color(1, 0.6, 0.25)
			_fuse_light.omni_range = 2.5
			_fuse_light.light_energy = 0.0
			_fuse_light.top_level = true
			add_child(_fuse_light)
	if prop == "mortar":
		lighter = Props.lighter(Color(0.1, 0.3, 0.8) if _rng.randf() < 0.5 else Color(0.8, 0.15, 0.1))
		lighter.top_level = true
		lighter.visible = false
		add_child(lighter)
	if smoker:
		cig = Props.cigarette()
		cig.top_level = true
		add_child(cig)
		_cig_smoke = Fx.smoke(Color(0.75, 0.75, 0.78, 0.18), 10, 3.0, 0.06, true, 0.25, 6.0)
		_cig_smoke.top_level = true
		add_child(_cig_smoke)
	stone_vis = MeshInstance3D.new()
	stone_vis.mesh = Stone.make_mesh(idx + 3)
	stone_vis.material_override = Stone.material()
	stone_vis.scale = Vector3.ONE * 0.11
	stone_vis.top_level = true
	stone_vis.visible = false
	add_child(stone_vis)


func _new_flare() -> void:
	flare = Flare.new()
	flare.burn_time = _rng.randf_range(55.0, 80.0)
	flare.held = true
	add_child(flare)
	flare.top_level = true
	flare.burnt_out.connect(_on_flare_out)


func _on_flare_out() -> void:
	# fumigène fini : on le jette par terre, un autre plus tard
	if flare == null:
		return
	var f := flare
	flare = null
	_flare_cd = _rng.randf_range(25.0, 55.0)
	_drop_flare.call_deferred(f)


func _drop_flare(f: Flare) -> void:
	if not is_instance_valid(f):
		return
	var fwd := _bd(Vector3(0.3, 0.2, 1.0)).normalized()
	f.reparent(get_tree().current_scene, true)
	f.release(fwd * 2.5, Vector3(_rng.randf_range(-4, 4), 0, _rng.randf_range(-4, 4)))


# =================================================================== accessoires (placement)
func _place_props() -> void:
	var phone_on := act in ["phone", "film", "call", "selfie"] and _blend > 0.4
	if _prev_act in ["phone", "film", "call", "selfie"] and act in ["phone", "film", "call", "selfie"]:
		phone_on = true
	phone.visible = phone_on
	var pr := human.palm("R")
	var pl := human.palm("L")
	if phone_on:
		var f: Vector3 = pr["f"]
		var p: Vector3 = pr["p"]
		phone.global_transform = Transform3D(Props.basis_up(f, p), (pr["pos"] as Vector3) + p * 0.018 + f * 0.012)
	var thumb: Vector3 = pr["thumb"]
	var grip: Vector3 = (pr["pos"] as Vector3) + (pr["p"] as Vector3) * 0.03
	var fwd := forward()
	if sign_node:
		var face_dir := _bd(Vector3(-1, 0, 0)) if act == "sign_rest" else fwd
		sign_node.global_transform = Transform3D(Props.basis_up(thumb, face_dir), grip)
	if pole_node:
		var gh: Dictionary = pr if banner_side > 0.0 else pl
		var g2: Vector3 = (gh["pos"] as Vector3) + (gh["p"] as Vector3) * 0.03
		pole_node.global_transform = Transform3D(Props.basis_up(gh["thumb"], fwd), g2)
	if flare and flare.held:
		flare.hold(Transform3D(Props.basis_up(thumb, fwd), grip + thumb * 0.06))
	if mega:
		var mb := Props.basis_up(thumb, pr["f"])
		var gl: Vector3 = mega.get_meta("grip")
		mega.global_transform = Transform3D(mb, (pr["pos"] as Vector3) - mb * gl)
	if mortar_m:
		var axis: Vector3 = data.get("axis_w", _bd(Vector3(0, 0.71, 0.70)))
		var origin: Vector3 = (pr["pos"] as Vector3) - axis * 0.075 + (pr["p"] as Vector3) * (MortarModel.TUBE_R + 0.008)
		mortar_m.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, axis.normalized())), origin)
		_fuse_fx.global_position = origin + axis * (MortarModel.TUBE_LEN + 0.04)
		_fuse_light.global_position = _fuse_fx.global_position
	if lighter:
		lighter.visible = (act == "mortar_light" or act == "ignite") and _blend > 0.5
		if lighter.visible:
			var hand: Dictionary = pr if act == "ignite" else pl
			var lp: Vector3 = hand["pos"]
			lighter.global_position = lp + (hand["p"] as Vector3) * 0.04
			lighter.global_basis = Basis(Quaternion(Vector3.UP, (hand["thumb"] as Vector3)))
	if cig:
		var in_hand := act in ["smoke_drag", "smoke_hold", "idle"] and not phone_on
		var cp: Vector3
		var ax2: Vector3
		if in_hand:
			cp = (pr["pos"] as Vector3) + (pr["f"] as Vector3) * 0.075 + thumb * 0.012
			ax2 = (-(pr["p"] as Vector3) + (pr["f"] as Vector3) * 0.3).normalized()
		else:
			# la main droite est occupée (téléphone, geste) : la cigarette reste au coin des lèvres
			var mx := mouth_xf()
			cp = mx * Vector3(0.016, 0.004, 0.012)
			ax2 = (mx.basis * Vector3(0.35, -0.3, 1.0)).normalized()
		cig.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, ax2)), cp)
		var cyc := fmod(_cig_t, 9.0)
		if cyc > 1.8 and cyc < 3.4:   # on recrache la fumée
			_cig_smoke.global_position = human.head_world() + forward() * 0.13 + Vector3.DOWN * 0.03
		else:
			_cig_smoke.global_position = cp + ax2 * 0.075
	# bouteille d'eau : tenue pour boire ou pour la tendre
	var bottle_on := act in ["drink", "give"] and _blend > 0.4
	if bottle_on and bottle_node == null:
		bottle_node = Props.bottle()
		bottle_node.top_level = true
		add_child(bottle_node)
	if bottle_node != null:
		bottle_node.visible = bottle_on
		if bottle_on:
			bottle_node.global_transform = Transform3D(Props.basis_up(thumb, fwd), grip + thumb * 0.02)
	if cam_held != null:
		var shoot_on := act == "shoot" and _blend > 0.4
		cam_held.visible = shoot_on
		if cam_hang != null:
			cam_hang.visible = not shoot_on
		if shoot_on:
			var cd := _bd(_film_d).normalized()
			cam_held.global_transform = Transform3D(Basis.looking_at(-cd, Vector3.UP), (pr["pos"] as Vector3) + Vector3.UP * 0.0)
	if stone_vis.visible:
		stone_vis.global_position = (pr["pos"] as Vector3) + (pr["p"] as Vector3) * 0.035 + (pr["f"] as Vector3) * 0.02
	if item and is_instance_valid(item) and item.get_parent() == self:
		if act == "carry" or act == "toss2" or act == "dep2":
			item.global_position = ((pr["pos"] as Vector3) + (pl["pos"] as Vector3)) * 0.5 + Vector3.UP * 0.02
			item.global_basis = global_basis
		else:
			item.global_position = (pr["pos"] as Vector3) + (pr["p"] as Vector3) * 0.06


# =================================================================== cerveau
func _pick_idle() -> String:
	var opts := ["pocket", "crossed", "akimbo", "back", "idle", "idle"]
	if role == "bloc":
		opts = ["akimbo", "crossed", "pocket", "idle"]
	return opts[_rng.randi() % opts.size()]


## Pose « libre » compatible avec l'accessoire tenu
func _prop_rest_pose() -> String:
	if smoker and prop == "" and role != "march":
		return "smoke_drag" if fmod(_cig_t, 9.0) < 1.4 else "smoke_hold"
	match prop:
		"sign":
			return "sign_rest"
		"banner":
			return "banner"
		"flare":
			return "flare_low" if flare else _idle_pose
		"megaphone":
			return "mega_low"
		"mortar":
			return "mortar_carry"
	return _idle_pose


func _prop_cheer_pose() -> Array:
	match prop:
		"sign":
			return ["sign", {"raise": 1.0}]
		"banner":
			return ["banner", {}]
		"flare":
			return ["flare_up", {}] if flare else ["fist", {"k": 1.0}]
		"megaphone":
			return ["mega_low", {}]
		"mortar":
			return ["mortar_carry", {}]
	return ["cheer", {"open": _rng.randf() < 0.5}]


func busy() -> bool:
	return state in ["rally", "feed", "mortar", "panic", "dodge", "gassed", "hit", "sprayed", "arrested", "boarded", "rescue", "throwcop", "carattack", "vandal", "aid", "brawl"]


## Réaction courte : pose, durée, point regardé, options {voice, loud, hop, face, run_to}
func react(pose: String, dur: float, look_at_p: Vector3, opt := {}) -> bool:
	opt = opt.duplicate()
	if busy() and not opt.get("force", false):
		return false
	if prop != "" and pose in ["cheer", "fist", "clap", "head", "wave", "refuse", "film", "phone", "point", "cup"]:
		if prop in ["banner", "megaphone", "mortar"] or (prop == "sign") or (prop == "flare" and flare != null):
			var pc := _prop_cheer_pose()
			if pose in ["cheer", "fist", "clap", "wave", "point", "cup"]:
				pose = pc[0]
				opt["prm"] = pc[1]
			else:
				pose = _prop_rest_pose()
				opt["prm"] = {}
	state = "react"
	state_t = 0.0
	data = {"dur": dur, "look": look_at_p}
	set_act(pose, opt.get("prm", {}), 4.0)
	look(look_at_p, 1.0)
	jaw_extra = 0.0
	if opt.get("face", true) and not has_goal and prop != "banner":
		face(look_at_p)
	if opt.has("voice") and _rng.randf() < float(opt.get("voice_p", 1.0)):
		var delay: float = opt.get("delay", _rng.randf_range(0.05, 0.5))
		var cat: String = opt["voice"]
		var loud: bool = opt.get("loud", true)
		get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(self):
				say_cat(cat, loud))
	if opt.get("hop", false):
		hop(int(opt.get("hops", 2)))
	react_cd = dur + _rng.randf_range(1.0, 3.0)
	return true


## Objet rangé dans `data` ; null s'il a été libéré depuis (évite « assign invalid previously freed instance »)
func dnode(key: String) -> Node:
	var v: Variant = data.get(key)
	return v as Node if is_instance_valid(v) else null


func go_home() -> void:
	state = "home"
	state_t = 0.0
	sub = ""
	data = {}
	fire_ok = false
	_home_sub = ""
	_home_t = 0.0
	stone_vis.visible = false
	set_act(_prop_rest_pose(), {}, 2.5)
	_look_want = 0.0


func _think(delta: float) -> void:
	match state:
		"home":
			_think_home(delta)
		"react":
			if state_t > float(data.get("dur", 2.0)):
				go_home()
			else:
				look(data.get("look", look_p), 1.0)
		"dodge":
			_think_dodge(delta)
		"panic":
			_think_panic(delta)
		"watch":
			_think_watch(delta)
		"feed":
			_think_feed(delta)
		"rally":
			_think_rally(delta)
		"mortar":
			_think_mortar(delta)
		"gassed":
			_think_gassed(delta)
		"hit":
			_think_hit(delta)
		"sprayed":
			_think_sprayed(delta)
		"arrested":
			_think_arrested(delta)
		"rescue":
			_think_rescue(delta)
		"throwcop":
			_think_throwcop(delta)
		"carattack":
			_think_carattack(delta)
		"vandal":
			_think_vandal(delta)
		"aid":
			NpcCare.think(self, delta)
		"brawl":
			_think_brawl(delta)
		"goto_look":
			if not has_goal or state_t > 12.0:
				react("film" if _rng.randf() < 0.5 else _idle_pose, _rng.randf_range(4.0, 8.0), data.get("look", global_position))


# ------------------------------------------------------------------- activité de fond
func _think_home(delta: float) -> void:
	_home_t += delta
	# coup d'œil au joueur quand il passe tout près
	if crowd and _glance_cd <= 0.0:
		var pp := crowd.player_pos()
		var d := pp.distance_to(global_position)
		if d < 4.5 and forward().dot((pp - global_position).normalized()) > -0.2:
			look(pp + Vector3.UP * 1.6, 1.0)
			_look_cd = _rng.randf_range(1.5, 3.0)
			_glance_cd = _rng.randf_range(6.0, 12.0)
	# terrorisé en plein face-à-face : on quitte son poste pour l'arrière
	if crowd.standoff.active and role in ["chat", "loner"] and fear > 0.5 and prop == "":
		_home_rear(delta)
		_home_props(delta)
		return
	match role:
		"march":
			_home_march(delta)
		"chat":
			_home_chat(delta)
		"medic":
			NpcRoles.think_medic(self, delta)
		"press":
			NpcRoles.think_press(self, delta)
		_:
			if role == "bloc" and crowd.standoff.active:
				_home_march(delta)
			else:
				_home_loner(delta)
	_home_props(delta)


func _home_rear(delta: float) -> void:
	var spot := crowd.standoff.rear_spot(self)
	if not has_goal and Vector2(spot.x - global_position.x, spot.z - global_position.z).length() > 3.0:
		go(spot, true, 0.6)
	NpcFront.think_rear(self, delta)


func _home_props(delta: float) -> void:
	# fumigène : l'allumer, puis le brandir
	if prop == "flare":
		if flare == null:
			_flare_cd -= delta
			if _flare_cd <= 0.0 and crowd and crowd.flare_budget_ok():
				_new_flare()
				_home_sub = "flare_light"
				_home_t = 0.0
				set_act("flare_light", {}, 4.0)
		elif not flare.lit and not flare.spent:
			if _home_sub != "flare_light":
				_flare_cd -= delta
				if _flare_cd <= 0.0 and crowd and crowd.flare_budget_ok():
					_home_sub = "flare_light"
					_home_t = 0.0
					set_act("flare_light", {}, 4.0)
			elif _home_t > 0.95:
				flare.ignite()
				_home_sub = ""
				if _rng.randf() < 0.6:
					say_cat("ouais", true)
	# mortier : un tir vers le ciel de temps en temps
	if prop == "mortar":
		_mortar_cd -= delta
		if _mortar_cd <= 0.0 and crowd and crowd.mortar_ok(self):
			_start_mortar()
	# cigarette : bouffée toutes les ~9 s (la braise rougit), fumée recrachée
	if smoker and cig:
		_cig_t += delta
		var cyc := fmod(_cig_t, 9.0)
		var drag := act == "smoke_drag" and cyc < 1.4
		(cig.get_node("Ember") as MeshInstance3D).scale = Vector3.ONE * (1.7 if drag else 1.0)
		_cig_smoke.emitting = true
		_cig_smoke.amount_ratio = 1.0 if cyc > 1.8 and cyc < 3.4 else 0.2


func _home_march(delta: float) -> void:
	if crowd == null:
		return
	var tgt: Array = crowd.march_target(self)
	var p: Vector3 = tgt[0]
	var fdir: Vector3 = tgt[1]
	var d := Vector2(p.x - global_position.x, p.z - global_position.z).length()
	var cs: float = crowd.cortege_speed
	var so_on: bool = crowd.standoff.active
	var seated: bool = human.sit > 0.3 and _home_sub in ["f_sit", "rest_sit"]
	if seated:
		pass                                    # sit-in : on ne bouge plus
	elif d > 3.5:
		# face à la police on s'y rend d'un pas décidé ; on ne recalcule le chemin que si la cible a bougé
		if not has_goal or goal.distance_to(p) > 1.5 or path.size() <= 1 and d > 6.0:
			go(p, d > 30.0 or not so_on, 0.4)
	elif d > 0.2 or cs > 0.05:
		follow(p, clampf(cs + d * 0.9, 0.0, RUN * 0.8))
	if not seated:
		face(global_position + fdir * 5.0)
	if prop == "megaphone" and crowd.cortege_speed < 0.05 and not so_on:
		face(crowd.cortege_center())
	# haut du corps selon le chant
	var chanting: bool = crowd.chanting
	var beat: float = crowd.beat_pulse(idx)
	if _home_sub == "flare_light":
		return
	if so_on and crowd.standoff.is_rear(self):
		# trop effrayé pour tenir le rang : on regarde de loin
		if prop == "":
			NpcFront.think_rear(self, delta)
		else:
			set_act(_prop_rest_pose(), {}, 2.0)
			look(NpcFront.target_point(self, NpcFront.cop_of(self, delta)), 0.7)
		return
	match prop:
		"sign":
			set_act("sign", {"raise": 0.9 if so_on and not chanting else (clampf(0.35 + beat * 0.65, 0.0, 1.0) if chanting else 0.0)}, 3.0)
		"banner":
			set_act("banner", {}, 2.0)
		"flare":
			if flare and flare.lit:
				set_act("flare_up" if chanting or fmod(_home_t, 14.0) < 8.0 else "flare_low", {}, 2.0)
			else:
				set_act("flare_low" if flare else _idle_pose, {}, 2.0)
		"megaphone":
			if crowd.leader_speaking:
				set_act("megaphone", {"left": "fist" if beat > 0.2 or fmod(_home_t, 7.0) < 3.0 else "hip", "pump": beat}, 4.0)
			else:
				set_act("mega_low", {}, 2.0)
		_:
			if so_on:
				NpcFront.think(self, delta)
			elif chanting:
				chant_pose(beat)
			else:
				_home_idle_cycle(delta, true)
	if chanting and prop != "megaphone":
		jaw_extra = crowd.chant_jaw(idx)
		if not so_on:
			look(crowd.cortege_center() + Vector3.UP * 2.0 + fdir * 6.0, 0.4)
	else:
		jaw_extra = 0.0
	# coup de sifflet de temps en temps
	_whistle_cd -= delta
	if _whistle_cd <= 0.0 and prop == "" and not chanting:
		_whistle_cd = _rng.randf_range(25.0, 60.0)
		if crowd.near_listener(global_position, 40.0):
			set_act("whistle", {}, 5.0)
			get_tree().create_timer(0.35).timeout.connect(func():
				if is_instance_valid(self):
					AudioLib.play_at(self, "whistle_%d" % (_rng.randi() % 3), head_pos(), 0.0, 9.0))
			_home_sub = "whistle"
			_home_t = 0.0


## Gestes pendant un chant : applaudir, poing levé en rythme
func chant_pose(beat: float) -> void:
	if idx % 3 == 0:
		set_act("clap", {"gap": 0.02 + 0.2 * (1.0 - beat)}, 4.0)
	elif idx % 3 == 1:
		set_act("fist", {"k": beat}, 4.0)
	else:
		set_act("fist", {"k": beat * 0.8, "left": "akimbo"}, 4.0)


## Besoins du moment (soif, fatigue, froid) : renvoie l'occupation à prendre, "" si rien de particulier
func _need_activity(marching: bool) -> String:
	if prop != "" or smoker and _rng.randf() < 0.4:
		return ""
	if thirst > 0.6 and _rng.randf() < 0.5:
		return "drink"
	if fatigue > 0.6 and _rng.randf() < 0.5:
		if not marching or crowd.cortege_speed < 0.05:
			return "rest_sit"
		return "stretch"
	if fatigue > 0.3 and _rng.randf() < 0.12:
		return "stretch"
	if cold > 0.6 and _rng.randf() < 0.1:
		return "shiver"
	return ""


func _start_need(need: String) -> void:
	_home_sub = need
	_home_t = 0.0
	match need:
		"drink":
			_home_dur = 4.9
		"rest_sit":
			_home_dur = _rng.randf_range(18.0, 40.0)
			stop_move()
			if _rng.randf() < 0.5:
				say_cat("tired", false, -2.0)
		"stretch":
			_home_dur = 3.8
			if _rng.randf() < 0.4:
				say_cat("tired", false, -2.0)
		"shiver":
			_home_dur = _rng.randf_range(6.0, 12.0)
			if _rng.randf() < 0.55:
				say_cat("cold", false, -2.0)


## Joue l'occupation de besoin en cours ; false si `_home_sub` n'en est pas une
func _run_need(delta: float) -> bool:
	match _home_sub:
		"drink":
			set_act("drink", {}, 3.0)
			var tilt := clampf((_home_t - 0.9) / 0.6, 0.0, 1.0) * clampf((4.2 - _home_t) / 0.5, 0.0, 1.0)
			look(head_pos() + forward() * 0.5 + Vector3.UP * (0.15 + 1.3 * tilt), 1.0)
			if _home_t > _home_dur - 0.15:
				thirst = 0.0
				_home_t = _home_dur + 1.0
				# on propose à boire à un voisin
				if crowd and _rng.randf() < 0.35:
					for o in crowd.neighbors(global_position, 3.5):
						if o != self and o is Npc and (o as Npc).state == "home":
							say_cat("drink", false, -3.0)
							break
		"rest_sit":
			stop_move()
			human.sit = move_toward(human.sit, 1.0, delta * 1.6)
			if human.sit > 0.7:
				set_act("rest_knee" if idx % 2 == 0 else "phone", {"two": true}, 3.0)
				if act == "phone":
					Props.set_phone_screen(phone, "feed")
			else:
				set_act("crossed", {}, 3.0)
			if fatigue < 0.05 or (role == "march" and crowd.cortege_speed > 0.08 and not crowd.standoff.active):
				_home_t = _home_dur + 1.0
			if crowd and crowd.standoff.active:
				_home_t = _home_dur + 1.0
		"stretch":
			set_act("stretch", {}, 3.0)
			human.lean_extra = lerpf(human.lean_extra, -0.1 * clampf(sin(_home_t / _home_dur * PI) * 2.0, 0.0, 1.0), minf(1.0, delta * 3.0))
			jaw_extra = 0.7 * clampf(sin(_home_t * 2.2), 0.0, 1.0) if _home_t < 2.8 else 0.0
			if _home_t > _home_dur - 0.15:
				fatigue = maxf(fatigue - 0.15, 0.0)
				human.lean_extra = 0.0
				jaw_extra = 0.0
		"shiver":
			set_act("warm", {"rub": 1.0}, 3.0)
			human.hunch = lerpf(human.hunch, 0.22, minf(1.0, delta * 2.0))
			human.shake = 0.0
			if _home_t > _home_dur - 0.2:
				human.hunch = 0.0
		_:
			return false
	return true


## Petites occupations quand on n'a rien de particulier à faire
func _home_idle_cycle(delta: float, marching := false) -> void:
	if _home_sub == "whistle":
		if _home_t > 1.4:
			_home_sub = ""
		return
	if prop != "":
		# la main droite tient déjà quelque chose : pas de téléphone
		set_act(_prop_rest_pose(), {}, 2.0)
		if _look_cd <= 0.0:
			_look_cd = _rng.randf_range(2.5, 6.0)
			if crowd:
				look(crowd.interest_point(self), _rng.randf_range(0.5, 1.0))
		return
	if human.sit > 0.05 and _home_sub != "rest_sit":
		# on se relève avant de faire autre chose
		human.sit = move_toward(human.sit, 0.0, delta * 2.2)
		stop_move()
		return
	if _home_sub == "" or _home_t > _home_dur:
		_home_t = 0.0
		var r := _rng.randf()
		var need := _need_activity(marching)
		if need != "":
			_start_need(need)
		elif r < 0.28:
			_home_sub = "phone"
			_home_dur = _rng.randf_range(6.0, 16.0)
			Props.set_phone_screen(phone, "feed")
		elif r < 0.36 and not marching:
			_home_sub = "call"
			_home_dur = _rng.randf_range(8.0, 14.0)
		elif r < 0.44 and not marching and smoker:
			_home_sub = "smoke"
			_home_dur = _rng.randf_range(10.0, 20.0)
		elif r < 0.5 and not marching:
			_home_sub = "film"
			_home_dur = _rng.randf_range(5.0, 10.0)
			Props.set_phone_screen(phone, "cam")
			if _rng.randf() < 0.18:
				say_cat("film", false, -3.0)
		else:
			_home_sub = "stand"
			_idle_pose = _pick_idle()
			_home_dur = _rng.randf_range(6.0, 15.0)
	if _run_need(delta):
		return
	match _home_sub:
		"phone":
			set_act("phone", {"two": idx % 2 == 0}, 2.5)
			look(phone.global_position if phone.visible else _bw(Vector3(0.05, 1.2, 0.4)), 0.9)
		"call":
			set_act("call", {}, 2.5)
			if not speaking() and _rng.randf() < delta * 0.5:
				say(AudioLib.pick(voice, "talk" if _rng.randf() < 0.6 else "reply"), false, -3.0)
			look(_bw(Vector3(-1.5, 1.3, 4.0)), 0.5)
		"smoke":
			pass
		"film":
			var tgt := crowd.interest_point(self) if crowd else _bw(Vector3(0, 1.5, 8))
			set_act("film", {"dir": _wbd(tgt - head_pos()).normalized()}, 2.5)
			face(tgt)
			look(tgt, 0.7)
		_:
			set_act(_prop_rest_pose(), {}, 2.0)
			if _look_cd <= 0.0:
				_look_cd = _rng.randf_range(2.5, 6.0)
				if crowd and _rng.randf() < 0.7:
					look(crowd.interest_point(self), _rng.randf_range(0.5, 1.0))
				else:
					_look_want = 0.0


func _home_chat(delta: float) -> void:
	if crowd == null:
		return
	var spot: Array = crowd.chat_spot(self)
	var p: Vector3 = spot[0]
	var center: Vector3 = spot[1]
	if Vector2(p.x - global_position.x, p.z - global_position.z).length() > 0.5 and not has_goal and human.sit < 0.3:
		go(p, false, 0.3)
	if not has_goal and human.sit < 0.3:
		face(center)
	var spk: Npc = crowd.chat_speaker(group)
	var watching: bool = crowd.standoff.active and not speaking() and idx % 2 == 0
	if watching:
		look(NpcFront.target_point(self, NpcFront.cop_of(self, delta)), 0.7)
	if speaking():
		set_act("talk", {"two": idx % 2 == 1}, 2.5)
		var other: Npc = crowd.chat_listener_target(self)
		if other:
			look(other.head_pos(), 1.0)
	else:
		if spk and spk != self and not watching:
			look(spk.head_pos(), 1.0)
			if _rng.randf() < delta * 0.25:
				human.nod = 1.0
				get_tree().create_timer(0.9).timeout.connect(func():
					if is_instance_valid(self):
						human.nod = 0.0)
		if smoker:
			set_act(_prop_rest_pose(), {}, 2.5)
		else:
			if _home_sub == "" or _home_t > _home_dur:
				_home_t = 0.0
				_home_dur = _rng.randf_range(8.0, 18.0)
				_home_sub = "phone" if _rng.randf() < 0.2 else "stand"
				_idle_pose = _pick_idle()
				var need := _need_activity(false)
				if need != "":
					_start_need(need)
			if human.sit > 0.05 and _home_sub != "rest_sit":
				human.sit = move_toward(human.sit, 0.0, delta * 2.2)
			elif _run_need(delta):
				pass
			elif _home_sub == "phone" and (spk == null or spk == self):
				set_act("phone", {}, 2.5)
				look(phone.global_position if phone.visible else _bw(Vector3(0.05, 1.2, 0.4)), 0.9)
			else:
				set_act(_idle_pose, {}, 2.0)


func _home_loner(delta: float) -> void:
	if crowd == null:
		return
	# se balade dans sa zone de temps en temps
	if not has_goal and human.sit < 0.1 and _rng.randf() < delta * (0.03 if role == "bloc" else 0.05):
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(1.0, 7.0 if role == "loner" else 4.0)
		go(crowd.safe_from_gas(crowd.clamp_area(home_pos + Vector3(cos(a), 0, sin(a)) * r)), false, 0.4)
		_home_sub = "stand"
		_home_t = 0.0
		_home_dur = _rng.randf_range(4.0, 8.0)
	if prop == "mortar":
		set_act("mortar_carry", {}, 2.0)
		if _look_cd <= 0.0:
			_look_cd = _rng.randf_range(2.5, 6.0)
			look(crowd.interest_point(self), 0.8)
		return
	if prop == "flare" and flare and flare.lit:
		set_act("flare_up" if fmod(_home_t, 10.0) < 5.0 else "flare_low", {}, 2.0)
		return
	if _home_sub == "flare_light":
		return
	_home_idle_cycle(delta)


# ------------------------------------------------------------------- esquive / panique
func dodge(from: Vector3, dir: Vector3) -> void:
	if busy():
		return
	var to := global_position - from
	var side := dir.cross(Vector3.UP).normalized()
	if to.dot(side) < 0.0:
		side = -side
	var target := global_position + side * _rng.randf_range(2.5, 4.0) + dir.normalized() * _rng.randf_range(-0.5, 0.5)
	state = "dodge"
	state_t = 0.0
	data = {"from": from}
	stop_move()
	go(crowd.clamp_area(target) if crowd else target, true, 0.5)
	set_act("cover" if calm < 0.4 else "refuse", {}, 5.0)
	look(from + Vector3.UP * 1.5, 1.0)
	if _rng.randf() < 0.5:
		say_cat("warn", true)


func _think_dodge(_delta: float) -> void:
	var from: Vector3 = data.get("from", global_position)
	look(from + Vector3.UP * 1.5, 1.0)
	if not has_goal or state_t > 4.0:
		state = "react"
		state_t = 0.0
		data = {"dur": _rng.randf_range(2.0, 4.0), "look": from + Vector3.UP * 1.5}
		face(from)
		set_act("refuse" if bold < 0.6 else "crossed", {}, 3.0)


func panic(from: Vector3, strength := 1.0) -> void:
	if state == "panic" or state == "mortar":
		return
	var away := flee_dir(from)
	var target := global_position + away * _rng.randf_range(5.0, 9.0) * strength
	_drop_item()
	state = "panic"
	state_t = 0.0
	data = {"from": from}
	go(crowd.clamp_area(target) if crowd else target, true, 0.6)
	set_act("cover", {}, 6.0)
	if _rng.randf() < 0.35:
		say_cat("warn", true)


func _think_panic(_delta: float) -> void:
	var from: Vector3 = data.get("from", global_position)
	human.crouch = lerpf(human.crouch, 0.0, 0.1)
	if not has_goal or state_t > 5.0:
		state = "react"
		state_t = 0.0
		data = {"dur": _rng.randf_range(2.5, 4.5), "look": from + Vector3.UP * 1.0}
		face(from)
		set_act("head" if _rng.randf() < 0.5 else _idle_pose, {}, 3.0)


func startle(from: Vector3) -> void:
	# sursaut : petit recul + regard
	if busy():
		return
	look(from, 1.0)
	human.kick_back(0.6)
	react(_idle_pose if prop == "" else _prop_rest_pose(), 1.5, from, {"face": true})


# ------------------------------------------------------------------- feu : regarder / alimenter
func watch_fire(bin: Node3D, ring: Vector3) -> void:
	if busy() and state != "watch" and state != "feed":
		return
	if state == "feed":
		_drop_item()
		human.crouch = 0.0
		human.lean_extra = 0.0
		fire_ok = false
	state = "watch"
	state_t = 0.0
	data = {"bin": bin, "ring": ring, "next": 0.0}
	go(ring, false, 0.35)
	if _rng.randf() < 0.35:
		say_cat("fire", true)


func _think_watch(delta: float) -> void:
	var bin: Node3D = dnode("bin")
	if bin == null or not is_instance_valid(bin):
		go_home()
		return
	var fc: Vector3 = bin.fire_center()
	if not bin.burning:
		data["out_t"] = float(data.get("out_t", 0.0)) + delta
		if float(data["out_t"]) > 3.5:
			go_home()
			return
	if state_t > float(data.get("max", 60.0 + curious * 90.0)):
		go_home()
		return
	var ring: Vector3 = crowd.ring_point(self, bin)
	if not has_goal and Vector2(ring.x - global_position.x, ring.z - global_position.z).length() > 0.8:
		go(ring, false, 0.35)
	if not has_goal:
		face(fc)
	look(fc, 1.0)
	data["next"] = float(data.get("next", 0.0)) - delta
	if float(data["next"]) <= 0.0:
		data["next"] = _rng.randf_range(4.0, 9.0)
		var r := _rng.randf()
		var close := global_position.distance_to(bin.global_position) < 2.6
		var hot_close: bool = global_position.distance_to(bin.global_position) < 3.2 and float(bin.heat) > 0.85
		if hot_close and _rng.randf() < 0.5:
			# trop près d'un grand feu : on prévient et on recule un peu
			say_cat("fireclose", true)
			scare(0.05)
			go(crowd.clamp_area(global_position + flee_dir(bin.global_position) * 1.6), false, 0.4)
		if prop != "":
			set_act(_prop_cheer_pose()[0] if _rng.randf() < 0.4 else _prop_rest_pose(), _prop_cheer_pose()[1] if _rng.randf() < 0.4 else {}, 2.5)
		elif r < 0.32:
			Props.set_phone_screen(phone, "cam")
			set_act("film", {"dir": _wbd(fc - head_pos()).normalized()}, 2.5)
			if _rng.randf() < 0.3 and crowd.near_listener(global_position, 12.0):
				AudioLib.play_at(self, "phone_shutter", phone.global_position, -16.0, 2.0)
		elif r < 0.45:
			set_act("head", {}, 2.5)
			if _rng.randf() < 0.4:
				say_cat("wow", true)
		elif r < 0.6 and close and bin.heat < 1.0:
			set_act("warm", {"rub": float(_rng.randf() < 0.5)}, 2.0)
		elif r < 0.75:
			set_act(_pick_idle(), {}, 2.0)
		elif r < 0.85:
			set_act("phone", {}, 2.0)
		else:
			set_act("point", {"dir": _wbd(fc - human.shoulder_world("R")).normalized()}, 3.0)
			if _rng.randf() < 0.5:
				say_cat("fire", true)
	if act == "film":
		prm = {"dir": _wbd(fc - head_pos()).normalized()}


func feed_fire(src: Node3D) -> void:
	if busy():
		return
	state = "feed"
	state_t = 0.0
	sub = "find"
	sub_t = 0.0
	data = {"bin": src, "mode": "feed"}
	fire_ok = true


## Fait un feu (rare) : au sol à `spot`, ou dans une poubelle fermée `bin` : il ramasse un déchet, le dépose et l'allume au briquet.
func make_fire(spot: Vector3, bin: TrashBin = null) -> void:
	if busy():
		return
	state = "feed"
	state_t = 0.0
	sub = "find"
	sub_t = 0.0
	data = {"bin": bin, "mode": "make", "spot": spot}
	fire_ok = true
	_ensure_lighter()


func _ensure_lighter() -> void:
	if lighter == null:
		lighter = Props.lighter(Color(0.1, 0.3, 0.8) if _rng.randf() < 0.5 else Color(0.8, 0.15, 0.1))
		lighter.top_level = true
		lighter.visible = false
		add_child(lighter)


func _pocket_paper() -> void:
	var b := Burnable.make("news" if _rng.randf() < 0.6 else "paper")
	b.held = true
	add_child(b)
	b.top_level = true
	item = b


func _give_up_feed() -> void:
	_drop_item()
	human.crouch = 0.0
	human.lean_extra = 0.0
	go_home()


func _fire_spot(src: Node3D, spot: Vector3, make: bool) -> Vector3:
	var c := spot if (make and src == null) else src.global_position
	var d := global_position - c
	d.y = 0
	if d.length() < 0.1:
		d = Vector3(1, 0, 0)
	var r := 0.82
	if src is FloorFire:
		r = (src as FloorFire).stand_pos(global_position).distance_to(c)
	elif make and src == null:
		r = 0.7
	return c + d.normalized() * r


func _think_feed(delta: float) -> void:
	sub_t += delta
	var make: bool = data.get("mode", "feed") == "make"
	var src: Node3D = dnode("bin")
	var spot: Vector3 = data.get("spot", Vector3.ZERO)
	if state_t > 80.0 or (not make and (src == null or not is_instance_valid(src))):
		_give_up_feed()
		return
	if src is TrashBin and (src as TrashBin).tipped:
		_give_up_feed()
		return
	var ground := make and src == null
	var center := spot if ground else src.global_position
	var soft := minf(1.0, delta * 4.0)
	match sub:
		"find":
			var it: Burnable = crowd.reserve_burnable(self, center, 22.0 if make else 18.0)
			if it:
				data["item"] = it
				var ip := it.global_position
				var away := global_position - ip
				away.y = 0
				go(ip + away.normalized() * 0.45, false, 0.25)
				sub = "goto_item"
			else:
				_pocket_paper()
				sub = "goto_fire"
				go(_fire_spot(src, spot, make), false, 0.3)
			sub_t = 0.0
		"goto_item":
			var it2: Burnable = dnode("item")
			if it2 == null or not is_instance_valid(it2) or it2.in_bin != null or it2.held or it2.fire != null:
				sub = "find"
				return
			face(it2.global_position)
			if not has_goal or sub_t > 12.0:
				sub = "pick"
				sub_t = 0.0
				stop_move()
		"pick":
			var it3: Burnable = dnode("item")
			if it3 == null or not is_instance_valid(it3) or it3.held:
				sub = "find"
				human.crouch = 0.0
				return
			face(it3.global_position)
			human.crouch = lerpf(human.crouch, 0.85, soft * 1.2)
			human.lean_extra = lerpf(human.lean_extra, 0.25, soft * 1.2)
			set_act("pick", {"target": _wb(it3.global_position)}, 3.0)
			look(it3.global_position, 1.0)
			if sub_t > 0.9:
				it3.set_held(true)
				it3.reparent(self, true)
				item = it3
				sub = "goto_fire"
				sub_t = 0.0
				go(_fire_spot(src, spot, make), false, 0.3)
		"goto_fire":
			human.crouch = lerpf(human.crouch, 0.0, soft)
			human.lean_extra = lerpf(human.lean_extra, 0.0, soft)
			var it4 := item as Burnable
			if it4 and it4.kind in ["box", "plank"]:
				set_act("carry", {"w": 0.5 if it4.kind == "plank" else 0.34}, 3.0)
			else:
				set_act("stone", {}, 3.0)
			if src != null and src.burning:
				look(src.fire_center(), 0.8)
			if not has_goal:
				var sp := _fire_spot(src, spot, make)
				if Vector2(sp.x - global_position.x, sp.z - global_position.z).length() > 0.45:
					go(sp, false, 0.12)
				else:
					face(center)
					sub_t = 0.0
					if ground:
						sub = "place"
					elif src is TrashBin and not (src as TrashBin).is_open():
						if src.burning:
							# quelqu'un a étouffé le feu : on n'insiste pas
							_drop_item()
							watch_fire(src, crowd.ring_point(self, src))
							fire_ok = false
						else:
							sub = "open"
					else:
						sub = "dep"
		"open":
			face(center)
			var bin := src as TrashBin
			var u0 := clampf(sub_t / 0.6, 0.0, 1.0)
			human.lean_extra = lerpf(human.lean_extra, 0.15, soft)
			set_act("reach", {"target": _wb(bin.top_center() - (bin.global_position - global_position).normalized() * 0.34 + Vector3.UP * 0.05)}, 5.0)
			if sub_t > 0.6:
				bin.set_lid(true)
				sub = "dep"
				sub_t = 0.0
		"dep":
			face(center)
			var itd := item as Burnable
			var two := itd != null and itd.kind in ["box", "plank"]
			var u := clampf(sub_t / 0.55, 0.0, 1.0)
			var op := clampf((sub_t - 0.58) / 0.14, 0.0, 1.0)
			var tgw: Vector3
			if src is TrashBin:
				var dn := (src.global_position - global_position) * Vector3(1, 0, 1)
				dn = dn.normalized() if dn.length() > 0.01 else forward()
				tgw = (src as TrashBin).top_center() - dn * 0.1
				human.lean_extra = lerpf(human.lean_extra, 0.42, soft)
				human.crouch = lerpf(human.crouch, 0.16, soft)
			else:
				tgw = global_position + forward() * 0.6 + Vector3.UP * 0.55
				human.lean_extra = lerpf(human.lean_extra, 0.24, soft)
				human.crouch = lerpf(human.crouch, 0.18, soft)
			set_act("dep2" if two else "dep1", {"target": _wb(tgw), "u": u, "open": op, "w": 0.5 if (itd != null and itd.kind == "plank") else 0.34}, 6.0)
			look(src.fire_center() if src.burning else src.global_position, 1.0)
			if sub_t > 0.6 and item != null:
				_release_item_into(src)
			if sub_t > 1.3:
				human.crouch = 0.0
				human.lean_extra = 0.0
				sub = "after"
				sub_t = 0.0
				if _rng.randf() < 0.6:
					say_cat("fire" if _rng.randf() < 0.6 else "ouais", true)
		"place":
			# pose le déchet au sol à `spot`
			face(center)
			var itp := item as Burnable
			var up := clampf(sub_t / 0.5, 0.0, 1.0)
			human.crouch = lerpf(human.crouch, 0.8, soft)
			human.lean_extra = lerpf(human.lean_extra, 0.18, soft)
			var two2 := itp != null and itp.kind in ["box", "plank"]
			set_act("dep2" if two2 else "dep1", {"target": _wb(spot + Vector3.UP * 0.02), "u": up, "open": clampf((sub_t - 0.55) / 0.15, 0.0, 1.0), "w": 0.5 if (itp != null and itp.kind == "plank") else 0.34}, 6.0)
			look(spot, 1.0)
			if sub_t > 0.62 and item != null:
				var pi := item as Burnable
				item = null
				pi.reserved_by = null
				pi.reparent(get_tree().current_scene, true)
				pi.set_held(false)
				pi.global_position = spot + Vector3(0, pi.size.y * 0.5 + 0.03, 0)
				pi.rotation = Vector3(0, _rng.randf() * TAU, 0)
				pi.linear_velocity = Vector3.ZERO
				pi.angular_velocity = Vector3.ZERO
				data["placed"] = pi
				AudioLib.play_at(self, "cardboard_land" if pi.kind in ["box", "plank"] else "paper_rustle", spot, -12.0, 3.0)
			if sub_t > 1.1:
				sub = "light"
				sub_t = 0.0
		"light":
			face(center)
			human.crouch = lerpf(human.crouch, 0.8 if ground else 0.12, soft)
			human.lean_extra = lerpf(human.lean_extra, 0.2, soft)
			var tgt_w: Vector3
			var placed: Variant = data.get("placed")
			if ground:
				tgt_w = (placed.global_position if (placed != null and is_instance_valid(placed)) else spot) + Vector3.UP * 0.06
			else:
				tgt_w = (src as TrashBin).hand_target() - Vector3.UP * 0.2
			set_act("ignite", {"target": _wb(tgt_w), "u": clampf(sub_t / 0.55, 0.0, 1.0), "brace": ground}, 6.0)
			look(tgt_w, 1.0)
			if lighter:
				Props.set_lighter_lit(lighter, sub_t > 0.5 and sub_t < 1.6, state_t)
			if sub_t > 0.9 and not data.get("lit", false):
				data["lit"] = true
				AudioLib.play_at(self, "sfx:click", tgt_w, -10.0, 3.0)
				if ground and placed != null and is_instance_valid(placed):
					(placed as Burnable).ignite()
				elif src is TrashBin:
					(src as TrashBin).ignite()
					for bi in (src as TrashBin)._items:
						if is_instance_valid(bi) and bi is Burnable:
							(bi as Burnable).ignite()
			if sub_t > 1.7:
				human.crouch = 0.0
				human.lean_extra = 0.0
				sub = "step_back"
				sub_t = 0.0
				var away2 := global_position - center
				away2.y = 0
				go(clamp_pos(center + away2.normalized() * 2.4), false, 0.4)
		"step_back":
			human.crouch = lerpf(human.crouch, 0.0, soft)
			human.lean_extra = lerpf(human.lean_extra, 0.0, soft)
			look(center + Vector3.UP * 0.4, 1.0)
			set_act(_prop_rest_pose() if prop != "" else "fist", {"k": 0.0} if prop == "" else {}, 3.0)
			if not has_goal or sub_t > 4.0:
				var f := crowd.nearest_fire(center, 3.0)
				fire_ok = false
				if f:
					watch_fire(f, crowd.ring_point(self, f))
				else:
					go_home()
		"after":
			look(src.fire_center(), 1.0)
			var pc := _prop_cheer_pose()
			set_act(pc[0], pc[1], 3.0)
			if sub_t > 1.5:
				if _rng.randf() < 0.4 + bold * 0.3 and src.burning:
					sub = "find"
				else:
					watch_fire(src, crowd.ring_point(self, src))
					fire_ok = false


func clamp_pos(p: Vector3) -> Vector3:
	return crowd.clamp_area(p)


func _release_item_into(src: Node3D) -> void:
	if item == null or not is_instance_valid(item):
		item = null
		return
	var it := item as Burnable
	item = null
	it.reserved_by = null
	var from := global_position
	it.reparent(get_tree().current_scene, true)
	var dest: Vector3 = src.hand_target()
	AudioLib.play_at(self, "paper_rustle" if it.kind in ["paper", "news"] else "cardboard_land", it.global_position, -10.0, 3.0)
	it.fly_to(dest, 0.22 if src is TrashBin else 0.3, func():
		if is_instance_valid(src) and is_instance_valid(it):
			if not src.feed_item(it, from):
				it.set_held(false))


func _drop_item() -> void:
	human.crouch = 0.0
	human.lean_extra = 0.0
	if item and is_instance_valid(item):
		var it := item as Burnable
		item = null
		if it:
			it.reparent(get_tree().current_scene, true)
			it.reserved_by = null
			it.set_held(false)
			it.linear_velocity = vel + Vector3.UP
	item = null
	if data.has("item"):
		var r: Variant = data["item"]
		if r is Burnable and is_instance_valid(r) and (r as Burnable).reserved_by == self:
			(r as Burnable).reserved_by = null


## Vitesse initiale pour atteindre `target` (tir tendu, vitesse ~v, sinon arc)
func _ballistic(origin: Vector3, target: Vector3, v: float) -> Vector3:
	var d := Vector3(target.x - origin.x, 0, target.z - origin.z)
	var dist := maxf(d.length(), 0.3)
	var h := target.y - origin.y
	var g := 9.8
	var disc := v * v * v * v - g * (g * dist * dist + 2.0 * h * v * v)
	while disc < 0.0 and v < 30.0:
		v += 1.0
		disc = v * v * v * v - g * (g * dist * dist + 2.0 * h * v * v)
	var tan_t := (v * v - sqrt(maxf(disc, 0.0))) / (g * dist)
	# pour jeter DANS la poubelle on préfère une cloche (arc haut)
	if dist < 3.0:
		tan_t = (v * v + sqrt(maxf(disc, 0.0))) / (g * dist)
	var ang := atan(tan_t)
	return (d.normalized() * cos(ang) + Vector3.UP * sin(ang)) * v


# ------------------------------------------------------------------- casser l'abribus
func rally(bus: BusStop) -> void:
	_drop_item()
	state = "rally"
	state_t = 0.0
	sub = "pick_slot"
	sub_t = 0.0
	data = {"bus": bus, "hits": 0}


func _think_rally(delta: float) -> void:
	sub_t += delta
	var bus: BusStop = dnode("bus")
	if bus == null or not crowd.rally_active:
		_end_rally()
		return
	match sub:
		"pick_slot":
			var s: Dictionary = crowd.attack_slot(self)
			if s.is_empty():
				_end_rally(true)
				return
			data["slot"] = s
			go(s["pos"], true, 0.3)
			sub = "go"
			sub_t = 0.0
		"go":
			var s2: Dictionary = data["slot"]
			look(s2["target"], 0.8)
			if not bus.pane_alive(s2["pane"]):
				crowd.free_slot(self)
				sub = "pick_slot"
				return
			if not has_goal or sub_t > 14.0:
				stop_move()
				face(s2["face"])
				sub = "kick" if s2["kind"] == "kick" else "stone_pick"
				sub_t = -_rng.randf_range(0.2, 0.8)
		"kick":
			var s3: Dictionary = data["slot"]
			face(s3["face"])
			look(s3["target"], 1.0)
			set_act(_idle_pose if prop == "" else _prop_rest_pose(), {}, 2.0)
			if not bus.pane_alive(s3["pane"]):
				_on_pane_broken()
				return
			if sub_t > 0.0 and human.kick_t < 0.0 and absf(wrapf(_yaw_to(s3["face"]) - yaw, -PI, PI)) < 0.25:
				human.start_kick()
				sub_t = -_rng.randf_range(2.4, 4.4)
				if _rng.randf() < 0.45:
					say_cat("ouais" if _rng.randf() < 0.5 else "allez", true)
		"stone_pick":
			var s4: Dictionary = data["slot"]
			if not bus.pane_alive(s4["pane"]):
				_on_pane_broken()
				return
			if sub_t < 0.0:
				return
			face(s4["face"])
			human.crouch = lerpf(human.crouch, 0.8, minf(1.0, delta * 5.0))
			human.lean_extra = lerpf(human.lean_extra, 0.25, minf(1.0, delta * 5.0))
			set_act("pick", {"target": Vector3(0.18, 0.05, 0.45)}, 3.0)
			if sub_t > 0.75:
				stone_vis.visible = true
				sub = "stone_throw"
				sub_t = 0.0
		"stone_throw":
			human.crouch = lerpf(human.crouch, 0.0, minf(1.0, delta * 5.0))
			human.lean_extra = lerpf(human.lean_extra, 0.0, minf(1.0, delta * 5.0))
			var s5: Dictionary = data["slot"]
			face(s5["face"])
			look(s5["target"], 1.0)
			var dir := _wbd(s5["target"] - human.shoulder_world("R")).normalized()
			if sub_t < 0.45:
				set_act("stone", {}, 4.0)
			else:
				set_act("throw", {"dir": dir}, 8.0)
				if act_t > 0.48 and stone_vis.visible:
					_throw_stone(s5["target"])
			if sub_t > 1.6:
				sub = "stone_pick"
				sub_t = -_rng.randf_range(1.6, 3.4)
				if _rng.randf() < 0.4:
					say_cat("allez" if _rng.randf() < 0.5 else "ouais", true)
		"celebrate":
			if sub_t > 3.5:
				_end_rally()


func _yaw_to(p: Vector3) -> float:
	var d := p - global_position
	return atan2(-d.x, -d.z)


func _on_pane_broken() -> void:
	crowd.free_slot(self)
	human.crouch = 0.0
	human.lean_extra = 0.0
	stone_vis.visible = false
	sub = "pick_slot"
	sub_t = 0.0


func _end_rally(celebrate := false) -> void:
	crowd.free_slot(self)
	human.crouch = 0.0
	human.lean_extra = 0.0
	stone_vis.visible = false
	if celebrate and sub != "celebrate":
		sub = "celebrate"
		sub_t = 0.0
		var pc := _prop_cheer_pose()
		set_act(pc[0], pc[1], 4.0)
		hop(3)
		say_cat("broke", true)
		return
	go_home()


func _throw_stone(target: Vector3) -> void:
	stone_vis.visible = false
	var origin := stone_vis.global_position
	var err := Vector3(_rng.randf_range(-0.45, 0.45), _rng.randf_range(-0.35, 0.4), _rng.randf_range(-0.45, 0.45))
	var s := Stone.new()
	get_tree().current_scene.add_child(s)
	s.setup(_rng.randi(), _rng.randf_range(0.04, 0.055))
	s.collision_mask = 1
	s.global_position = origin
	s.linear_velocity = _ballistic(origin, target + err, 13.0)
	s.angular_velocity = Vector3(_rng.randf_range(-10, 10), _rng.randf_range(-10, 10), _rng.randf_range(-10, 10))
	AudioLib.play_at(self, "sfx:throw", origin, -8.0, 5.0)
	get_tree().create_timer(40.0).timeout.connect(func():
		if is_instance_valid(s):
			s.queue_free())


func _on_kick_impact(point: Vector3) -> void:
	var fwd := forward()
	var bus: BusStop = dnode("bus") if state == "rally" else null
	if bus:
		bus.kick(point + fwd * 0.12, fwd, 0.55)
	var car: PoliceVehicle = dnode("car") if state == "carattack" else null
	if car != null and is_instance_valid(car):
		if car.kick(point + fwd * 0.12, fwd, 0.9):
			data["hits"] = int(data.get("hits", 0)) + 1
	# corps à corps : le coup de pied part vers le policier visé
	if state == "brawl":
		var bc: Cop = dnode("cop")
		if bc != null and is_instance_valid(bc) and point.distance_to(bc.global_position + Vector3.UP * 0.9) < 1.7:
			bc.on_hit("kick", fwd, 0.7, self)
			data["hits"] = int(data.get("hits", 0)) + 1
	# les meubles de rue sur le passage (barrière, cône, panneau...) encaissent aussi
	if state == "vandal":
		for n in get_tree().get_nodes_in_group("kickable"):
			if n.has_method("kick") and not (n is PoliceVehicle) and n.kick(point + fwd * 0.12, fwd, 0.8):
				data["done"] = true
				break


## Touché par une pierre du joueur
func on_stone_hit(from_dir: Vector3) -> void:
	human.kick_back(0.8)
	if state in ["mortar"]:
		return
	var src := global_position - from_dir.normalized() * 6.0
	if crowd:
		src = crowd.player_pos()
	react("refuse", 2.5, src + Vector3.UP * 1.6, {"voice": "warn", "force": true})


# ------------------------------------------------------------------- vandalisme d'une voiture de police
func attack_car(car: PoliceVehicle) -> void:
	if busy() or car == null or not is_instance_valid(car):
		return
	_drop_item()
	state = "carattack"
	state_t = 0.0
	sub = "pick"
	sub_t = 0.0
	data = {"car": car, "style": "kick" if _rng.randf() < 0.62 else "stone", "hits": 0, "throws": 0}
	stop_move()


func _car_slot(car: PoliceVehicle, near_pane: GlassPane = null) -> Vector3:
	if near_pane != null:
		# lanceur de pierres : à 4-6 m de la vitre visée, face à elle
		var n := (near_pane.global_basis * Vector3(0, 0, 1))
		n.y = 0.0
		n = n.normalized()
		if (global_position - near_pane.global_position).dot(n) < 0.0:
			n = -n
		return near_pane.global_position * Vector3(1, 0, 1) + n * _rng.randf_range(4.0, 5.5) + n.cross(Vector3.UP) * _rng.randf_range(-1.5, 1.5)
	var side := 1.0 if (global_position - car.global_position).dot(car.global_basis.x) > 0.0 else -1.0
	var lz := _rng.randf_range(-car.half.y * 0.55, car.half.y * 0.55)
	return car.to_global(Vector3(side * (car.half.x + 0.72), 0, lz))


func _think_carattack(delta: float) -> void:
	sub_t += delta
	var car: PoliceVehicle = dnode("car")
	if car == null or not is_instance_valid(car) or state_t > 55.0:
		go_home()
		return
	if car.burning and car.heat > 0.4:
		go_home()
		if crowd:
			watch_fire(car, crowd.ring_point(self, car))
		return
	# les CRS qui arrivent : on file
	if crowd and crowd.police and crowd.police.stage >= 1:
		var c: Cop = crowd.police.nearest_cop(global_position, 5.5)
		if c != null and c.state in ["charge", "strike", "arrest"] and bold < 0.9:
			panic(c.global_position, 1.0)
			return
	var tgt_c := car.global_position + Vector3.UP * 0.7
	match sub:
		"pick":
			var pane: GlassPane = null
			if data["style"] == "stone":
				var alive: Array = car.damage.panes.filter(func(p): return is_instance_valid(p) and p.alive())
				if not alive.is_empty():
					pane = alive[_rng.randi() % alive.size()]
				else:
					data["style"] = "kick"
			data["pane"] = pane
			var slot := _car_slot(car, pane)
			data["slot"] = slot
			go(crowd.clamp_area(slot) if crowd else slot, true, 0.3)
			sub = "go"
			sub_t = 0.0
		"go":
			look(tgt_c, 0.8)
			if not has_goal or sub_t > 12.0:
				stop_move()
				face(tgt_c)
				sub = "kick" if data["style"] == "kick" else "stone_pick"
				sub_t = -_rng.randf_range(0.2, 0.8)
		"kick":
			face(tgt_c)
			look(tgt_c, 1.0)
			set_act(_idle_pose if prop == "" else _prop_rest_pose(), {}, 2.0)
			if sub_t > 0.0 and human.kick_t < 0.0 and absf(wrapf(_yaw_to(tgt_c) - yaw, -PI, PI)) < 0.35:
				human.start_kick()
				sub_t = -_rng.randf_range(1.3, 3.0)
				if _rng.randf() < 0.5:
					say_cat("ouais" if _rng.randf() < 0.5 else "allez", true)
				# après quelques coups, certains passent aux pierres ou s'en vont
				if int(data.get("hits", 0)) >= 6 and _rng.randf() < 0.4:
					data["style"] = "stone"
					sub = "pick"
		"stone_pick":
			var pn: GlassPane = dnode("pane")
			if pn == null or not is_instance_valid(pn) or not pn.alive():
				sub = "pick"
				return
			if sub_t < 0.0:
				return
			face(pn.global_position)
			human.crouch = lerpf(human.crouch, 0.8, minf(1.0, delta * 5.0))
			human.lean_extra = lerpf(human.lean_extra, 0.25, minf(1.0, delta * 5.0))
			set_act("pick", {"target": Vector3(0.18, 0.05, 0.45)}, 3.0)
			if sub_t > 0.75:
				stone_vis.visible = true
				sub = "stone_throw"
				sub_t = 0.0
		"stone_throw":
			human.crouch = lerpf(human.crouch, 0.0, minf(1.0, delta * 5.0))
			human.lean_extra = lerpf(human.lean_extra, 0.0, minf(1.0, delta * 5.0))
			var pn2: GlassPane = dnode("pane")
			if pn2 == null or not is_instance_valid(pn2) or not pn2.alive():
				stone_vis.visible = false
				sub = "pick"
				return
			var tp := pn2.global_position
			face(tp)
			look(tp, 1.0)
			var dir := _wbd(tp - human.shoulder_world("R")).normalized()
			if sub_t < 0.45:
				set_act("stone", {}, 4.0)
			else:
				set_act("throw", {"dir": dir}, 8.0)
				if act_t > 0.48 and stone_vis.visible:
					_throw_stone(tp)
					data["throws"] = int(data.get("throws", 0)) + 1
			if sub_t > 1.6:
				sub = "stone_pick"
				sub_t = -_rng.randf_range(1.2, 2.6)
				if _rng.randf() < 0.35:
					say_cat("allez" if _rng.randf() < 0.5 else "ouais", true)
				if int(data.get("throws", 0)) >= 5 and _rng.randf() < 0.35:
					data["style"] = "kick"
					sub = "pick"


## Vandalisme de mobilier de rue (cônes, barrières, panneaux, corbeilles...) : un manifestant décidé
## s'approche de l'objet et lui donne un coup de pied
func start_vandal(target: Node3D) -> void:
	if busy() or target == null or not is_instance_valid(target):
		return
	_drop_item()
	state = "vandal"
	state_t = 0.0
	sub = "go"
	sub_t = 0.0
	data = {"t": target, "done": false}
	var away := global_position - target.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.RIGHT
	go(crowd.clamp_area(target.global_position + away * 1.0) if crowd else target.global_position + away, false, 0.25)


func _think_vandal(delta: float) -> void:
	sub_t += delta
	var t: Node3D = dnode("t")
	if t == null or not is_instance_valid(t) or state_t > 25.0 or bool(data.get("done", false)):
		if bool(data.get("done", false)) and _rng.randf() < 0.5:
			say_cat("ouais", true)
		go_home()
		return
	var tp := t.global_position + Vector3.UP * 0.2
	match sub:
		"go":
			look(tp, 0.8)
			if not has_goal or sub_t > 10.0:
				stop_move()
				face(tp)
				sub = "kick"
				sub_t = -_rng.randf_range(0.2, 0.6)
		"kick":
			face(tp)
			look(tp, 1.0)
			if sub_t > 0.0 and human.kick_t < 0.0 and absf(wrapf(_yaw_to(tp) - yaw, -PI, PI)) < 0.35:
				human.start_kick()
				sub_t = -1.6
				if sub_t < 0.0 and state_t > 14.0:
					data["done"] = true


# ------------------------------------------------------------------- corps à corps avec un policier
func start_brawl(cop: Cop) -> void:
	if busy() or cop == null:
		return
	_drop_item()
	state = "brawl"
	state_t = 0.0
	sub = "run"
	sub_t = 0.0
	data = {"cop": cop, "hits": 0}
	hostile = 1.0
	say_cat("anger", true)
	go(cop.global_position, true, 0.4)


func _think_brawl(delta: float) -> void:
	sub_t += delta
	var cop: Cop = dnode("cop")
	if cop == null or not is_instance_valid(cop) or cop.state == "down" or state_t > 16.0 or int(data.get("hits", 0)) >= 4:
		panic(cop.global_position if cop != null and is_instance_valid(cop) else global_position - forward() * 3.0, 1.0)
		return
	var to := cop.global_position - global_position
	to.y = 0.0
	var tp := cop.global_position + Vector3.UP * 0.9
	look(tp, 1.0)
	if sub == "run":
		if to.length() > 1.5:
			if not has_goal or goal.distance_to(cop.global_position) > 1.3:
				go(cop.global_position - to.normalized() * 0.8, true, 0.3)
			set_act("fist", {"k": 0.6}, 5.0)
		else:
			stop_move()
			sub = "fight"
			sub_t = -0.2
		return
	face(cop.global_position)
	if to.length() > 2.6:
		sub = "run"
		return
	set_act("fist", {"k": 0.9}, 4.0)
	if sub_t > 0.0 and human.kick_t < 0.0 and absf(wrapf(_yaw_to(cop.global_position) - yaw, -PI, PI)) < 0.4:
		human.start_kick()
		sub_t = -_rng.randf_range(1.1, 1.8)
		if _rng.randf() < 0.5:
			say_cat("anger", true)


# ------------------------------------------------------------------- tir de mortier (PNJ)
func _start_mortar() -> void:
	state = "mortar"
	state_t = 0.0
	sub = "light"
	sub_t = 0.0
	stop_move()
	var away: Vector3 = crowd.safe_sky_dir(self)
	face(global_position + Vector3(away.x, 0, away.z) * 4.0)
	data = {"dir": away}
	set_act("mortar_light", {}, 3.0)


func _think_mortar(delta: float) -> void:
	sub_t += delta
	var dir: Vector3 = data.get("dir", Vector3.UP)
	var hdir := Vector3(dir.x, 0, dir.z).normalized() if Vector2(dir.x, dir.z).length() > 0.01 else -global_basis.z
	var axis_b := _wbd((hdir * 0.55 + Vector3.UP).normalized())   # ~60° au-dessus de l'horizon, loin de la foule
	match sub:
		"light":
			data["axis_w"] = _bd(Vector3(0, 0.84, 0.54))
			if lighter:
				Props.set_lighter_lit(lighter, sub_t > 0.6 and sub_t < 1.6, state_t)
			look(mortar_m.global_position + data["axis_w"] * 0.3, 1.0)
			if sub_t > 1.25:
				_fuse_fx.emitting = true
			if sub_t > 1.7:
				sub = "aim"
				sub_t = 0.0
				set_act("mortar_aim", {"axis": axis_b}, 3.5)
				AudioLib.play_at(self, "sfx:hiss", mortar_m.global_position, -12.0, 5.0)
		"aim":
			data["axis_w"] = Fx.vslerp(data["axis_w"], _bd(axis_b), minf(1.0, delta * 4.0))
			_fuse_light.light_energy = 0.8 + randf() * 0.6
			look(mortar_m.global_position + (data["axis_w"] as Vector3) * 3.0, 0.8)
			if sub_t > 1.1:
				_mortar_launch(data["axis_w"])
				sub = "recoil"
				sub_t = 0.0
		"recoil":
			_fuse_light.light_energy = 0.0
			look(global_position + Vector3.UP * 30.0 + forward() * 10.0, 1.0)
			if sub_t > 0.9:
				set_act("mortar_carry", {}, 2.0)
				data["axis_w"] = Fx.vslerp(data["axis_w"], _bd(Vector3(0, 0.71, 0.70)), minf(1.0, delta * 3.0))
			if sub_t > 3.5:
				data.erase("axis_w")
				_mortar_cd = _rng.randf_range(40.0, 80.0)
				go_home()


func _mortar_launch(axis: Vector3) -> void:
	_fuse_fx.emitting = false
	var scene := get_tree().current_scene
	var mouth := mortar_m.global_position + axis * MortarModel.TUBE_LEN
	var s := FireworkShell.new()
	scene.add_child(s)
	s.global_position = mouth
	s.velocity = (axis + Vector3(_rng.randf_range(-0.04, 0.04), 0, _rng.randf_range(-0.04, 0.04))).normalized() * 34.0
	Fx.muzzle(scene, mouth, axis)
	AudioLib.play_at(self, "sfx:thump", mouth, 4.0, 30.0)
	human.kick_back(1.0)
	if _rng.randf() < 0.5:
		get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(self):
				say_cat("ouais", true))
	if crowd:
		crowd.on_event("mortar_fire", {"pos": mouth, "dir": axis, "npc": self})


## Pétard déjà allumé, lancé vers la cible : la mèche est réglée pour qu'il éclate à peu près à l'arrivée
func _launch_petard(tg: Node3D, sz: int) -> void:
	var f := Firecracker.make(sz, false, self)
	get_tree().current_scene.add_child(f)
	var pr := human.palm("R")
	f.global_position = (pr["pos"] as Vector3) + Vector3.UP * 0.05
	var aim := tg.global_position + Vector3(0, 0.9, 0)
	var v := _ballistic(f.global_position, aim, 13.0) * _rng.randf_range(0.97, 1.03)
	f.linear_velocity = v
	f.angular_velocity = Vector3(_rng.randf_range(-12, 12), _rng.randf_range(-12, 12), _rng.randf_range(-12, 12))
	var flight := f.global_position.distance_to(aim) / maxf(Vector2(v.x, v.z).length(), 1.0)
	f.fuse = clampf(flight + _rng.randf_range(-0.1, 0.9), 0.5, 3.6)
	f.add_collision_exception_with(self)
	AudioLib.play_at(self, "toss", f.global_position, -4.0, 6.0)
	hostile = minf(hostile + 0.9, 1.5)
	if _rng.randf() < 0.6:
		say_cat("throw" if _rng.randf() < 0.5 else "anger", true)


# =================================================================== police : gaz, coups, arrestation, jets
var hostile := 0.0            # a agressé la police : visé en priorité par les interpellations
var gas_level := 0.0
var _cough_t := 0.0
var _escort_p := Vector3.ZERO
var _escort_t := 0.0


func _cough() -> void:
	human.kick_back(0.5)
	human.hunch = maxf(human.hunch, 0.6)
	var nm := "cough_f_%d" % _rng.randi_range(0, 1) if female else "cough_m_%d" % _rng.randi_range(0, 2)
	AudioLib.play_at(self, nm, head_pos(), -2.0, 6.0, vpitch)


## Direction de fuite loin d'un point, sans jamais courir vers la ligne de police quand on en est proche
func flee_dir(from: Vector3) -> Vector3:
	var away := global_position - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	var pol := crowd.police if crowd else null
	if pol != null:
		var gap := pol.line_c.x - global_position.x
		if gap < 16.0:
			var k := clampf((16.0 - gap) / 12.0, 0.0, 1.0)
			away.x = lerpf(away.x, minf(away.x, -0.2) - 0.6, k)
			away = away.normalized()
	return away


## Un nuage de gaz s'étend près de moi : on s'écarte avant d'être pris dedans
func avoid_gas(c: Vector3) -> void:
	scare(0.12)
	var away := flee_dir(c).rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
	react("cover", 1.4, c + Vector3.UP * 3.0, {"voice": "retreat" if _rng.randf() < 0.55 else "fear", "voice_p": 0.5})
	go(crowd.clamp_area(global_position + away * _rng.randf_range(5.0, 8.0)), true, 0.6)


## Du gaz sur moi (appelé ~8 fois par seconde par les nuages)
func on_gas(density: float, from: Vector3) -> void:
	gas_level = maxf(gas_level, density)
	scare(0.03 * density)
	if state == "gassed":
		data["from"] = from
		return
	if state in ["arrested", "boarded", "hit", "sprayed", "mortar"] or density < 0.12:
		return
	# les cagoulés tiennent un peu plus : ils toussent sur place
	var tough: bool = outfit.get("face", "") == "balaclava" and bold > 0.6 and _rng.randf() < 0.5
	_drop_item()
	state = "gassed"
	state_t = 0.0
	sub = "tough" if tough else "flee"
	data = {"from": from}
	stop_move()
	if not tough:
		var away := flee_dir(from)
		var dest := global_position + away.rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5)) * _rng.randf_range(13.0, 19.0)
		go(crowd.clamp_area(dest) if crowd else dest, true, 0.8)
	set_act("cover", {}, 6.0)
	_cough_t = _rng.randf_range(0.2, 0.9)
	if _rng.randf() < 0.7:
		say_cat("gas", true)


func _think_gassed(delta: float) -> void:
	human.hunch = lerpf(human.hunch, 0.5, minf(1.0, delta * 3.0))
	_cough_t -= delta
	if _cough_t <= 0.0:
		_cough_t = _rng.randf_range(1.1, 2.4)
		_cough()
		if _rng.randf() < 0.3:
			say_cat("gas", true)
	var from: Vector3 = data.get("from", global_position)
	if sub == "flee" and (not has_goal) and gas_level > 0.1:
		# toujours dans le gaz : on court plus loin
		var away := flee_dir(from)
		go(crowd.clamp_area(global_position + away * 10.0) if crowd else global_position + away * 10.0, true, 0.8)
	if gas_level < 0.04 and (not has_goal or sub == "tough") and state_t > 2.5:
		human.hunch = 0.0
		state = "react"
		state_t = 0.0
		data = {"dur": _rng.randf_range(2.5, 4.5), "look": from + Vector3.UP * 1.5}
		set_act("head" if _rng.randf() < 0.6 else _idle_pose, {}, 3.0)
		return
	if state_t > 24.0:
		human.hunch = 0.0
		go_home()


## Coup de matraque / LBD / gazeuse / bousculade de la police
func on_police_hit(kind: String, dir: Vector3, cop: Node3D) -> void:
	if state in ["arrested", "boarded"]:
		return
	scare(0.4)
	enrage(0.3)
	_drop_item()
	stop_move()
	var d := Vector3(dir.x, 0, dir.z)
	d = d.normalized() if d.length() > 0.01 else -forward()
	if kind == "spray":
		state = "sprayed"
		state_t = 0.0
		data = {"from": cop.global_position if cop else global_position}
		set_act("cover", {}, 8.0)
		human.eye_open = 0.1
		_cough_t = 0.4
		say_cat("pain", true)
		return
	var down := kind == "lbd" or (kind == "baton" and _rng.randf() < 0.72) or (kind == "shove" and _rng.randf() < 0.35)
	state = "hit"
	state_t = 0.0
	sub = "down" if down else "stagger"
	data = {"dir": d, "dur": _rng.randf_range(4.5, 8.0) if kind == "lbd" else _rng.randf_range(2.6, 5.0), "cop": cop}
	var dl := global_basis.inverse() * d
	human.fall_dir = atan2(dl.x, dl.z)
	human.kick_back(1.2)
	set_act("cover" if down else "head", {}, 8.0)
	say_cat("pain", true)
	AudioLib.play_at(self, "body_fall" if down else "shove", global_position + Vector3.UP * 0.6, -3.0, 6.0)
	if kind != "shove" and crowd:
		hostile = maxf(hostile, 0.15)
	get_tree().call_group("crowd", "on_event", "civil_hit", {"pos": global_position, "kind": kind, "who": self})


## Un secouriste s'occupe de moi : je me remets plus vite
func on_aid(_by: Node3D) -> void:
	match state:
		"hit":
			data["aided"] = true
			data["dur"] = minf(float(data.get("dur", 3.0)), state_t)
		"sprayed":
			data["aided"] = true
			state_t = maxf(state_t, 6.2)
		"gassed":
			data["aided"] = true
			gas_level = 0.0
			fear = maxf(fear - 0.2, 0.0)


func _think_hit(delta: float) -> void:
	var dur: float = data.get("dur", 3.0)
	if sub == "down":
		human.fall = move_toward(human.fall, 1.0 if state_t < dur else 0.0, delta * (4.5 if state_t < dur else 1.0))
		if state_t > dur + (0.6 if data.get("aided", false) else 1.0):
			human.fall = 0.0
			if data.get("aided", false):
				# relevé par un secouriste : on souffle, puis on reprend sa place (sans paniquer)
				human.hunch = 0.0
				go_home()
				react("head", 2.0, global_position + forward() * 3.0 + Vector3.UP, {"voice": "ouais", "voice_p": 0.3})
				return
			var cop: Node3D = dnode("cop")
			panic(cop.global_position if cop and is_instance_valid(cop) else global_position - forward() * 3.0, 1.0)
	else:
		if state_t > 1.4:
			var cop2: Node3D = dnode("cop")
			panic(cop2.global_position if cop2 and is_instance_valid(cop2) else global_position - forward() * 3.0, 0.8)


func _think_sprayed(delta: float) -> void:
	human.hunch = lerpf(human.hunch, 0.6, minf(1.0, delta * 3.0))
	human.eye_open = lerpf(human.eye_open, 0.1, minf(1.0, delta * 6.0))
	_cough_t -= delta
	if _cough_t <= 0.0:
		_cough_t = _rng.randf_range(1.0, 2.0)
		_cough()
	# trébuche à l'aveugle
	if not has_goal:
		go(global_position + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3)), false, 0.5)
	if state_t > 7.0:
		human.hunch = 0.0
		human.eye_open = 1.0
		go_home()


# --- interpellation
func on_grabbed(cop: Node3D) -> void:
	_drop_item()
	state = "arrested"
	state_t = 0.0
	sub = "struggle"
	sub_t = 0.0
	data = {"cop": cop}
	stop_move()
	set_act("resist", {}, 8.0)
	look(cop.global_position + Vector3.UP * 1.6, 1.0)
	say_cat("arrested", true)
	get_tree().call_group("crowd", "on_event", "grab", {"pos": global_position, "who": self, "cop": cop})


func on_cuffed(_cop: Node3D) -> void:
	sub = "kneel"
	sub_t = 0.0
	set_act("cuffed", {}, 5.0)


func escort_to(p: Vector3) -> void:
	_escort_p = p
	_escort_t = 0.0
	if sub in ["kneel", "struggle", "stand"]:
		sub = "escort"
		sub_t = 0.0


func on_boarded(_van: Node3D) -> void:
	state = "boarded"
	human.kneel = 0.0
	visible = false
	set_physics_process(false)
	if crowd:
		crowd.unregister_actor(self)
	AudioLib.play_at(self, "door_close", global_position + Vector3.UP, -4.0, 8.0)
	get_tree().call_group("crowd", "on_event", "boarded", {"pos": global_position})
	queue_free()


## Libéré par la foule
func free_up() -> void:
	if state != "arrested":
		return
	human.kneel = 0.0
	human.hunch = 0.0
	go_home()
	panic(global_position - forward() * 3.0, 0.9)


func _think_arrested(delta: float) -> void:
	_escort_t += delta
	match sub:
		"struggle":
			human.lean_extra = lerpf(human.lean_extra, -0.1, 0.1)
			if fmod(state_t, 0.55) < delta:
				human.kick_back(0.5)
			if _rng.randf() < 0.01:
				say_cat("arrested", true)
		"kneel":
			human.kneel = move_toward(human.kneel, 1.0, delta * 1.2)
			human.hunch = lerpf(human.hunch, 0.35, 0.1)
		"escort":
			human.kneel = move_toward(human.kneel, 0.0, delta * 1.6)
			human.hunch = lerpf(human.hunch, 0.25, 0.1)
			follow(_escort_p, 1.9)
			set_act("cuffed", {}, 5.0)
			if _escort_t > 1.5:
				sub = "stand"
				sub_t = 0.0
			if _rng.randf() < 0.004:
				say_cat("arrested" if _rng.randf() < 0.7 else "free", true)
		"stand":
			human.kneel = move_toward(human.kneel, 0.0, delta * 1.6)
			stop_move()
			if sub_t > 10.0:
				free_up()


## Un manifestant décidé fonce libérer l'interpellé
func rescue(cop: Node3D) -> void:
	if busy() or cop == null:
		return
	state = "rescue"
	state_t = 0.0
	sub = "run"
	data = {"cop": cop}
	if _rng.randf() < 0.8:
		say_cat("free", true)


func _think_rescue(delta: float) -> void:
	var cop: Node3D = dnode("cop")
	if cop == null or not is_instance_valid(cop) or state_t > 12.0:
		go_home()
		return
	var d := cop.global_position - global_position
	d.y = 0.0
	if d.length() > 1.3:
		go(cop.global_position - d.normalized() * 0.9, true, 0.3)
		set_act("fist", {"k": 0.6}, 5.0)
		return
	stop_move()
	face(cop.global_position)
	if sub == "run":
		sub = "shove"
		sub_t = 0.0
		set_act("refuse", {}, 10.0)
		human.kick_back(0.6)
		if cop is Cop:
			(cop as Cop).on_hit("shove", d.normalized(), 1.3, self)
			var tgt: Node3D = (cop as Cop).arrestee
			if tgt is Npc and _rng.randf() < 0.6:
				(cop as Cop).arrestee = null
				(cop as Cop).set_state("hold")
				(tgt as Npc).free_up()
			elif tgt is Player:
				# on aide le joueur à se dégager : la jauge de lutte bondit
				var pl := tgt as Player
				pl.struggle = minf(pl.struggle + 0.55, 1.0)
				pl.message.emit("Un manifestant te vient en aide !")
		hostile = 1.0
	elif sub_t > 0.8:
		panic(cop.global_position, 1.0)


# --- jets d'objets sur la police
func throw_at(target: Node3D, kind := "") -> void:
	if busy() or target == null:
		return
	if prop in ["banner", "megaphone", "mortar"] or (prop == "sign" and _rng.randf() < 0.6):
		return
	if kind == "":
		var r := _rng.randf()
		kind = "stone" if r < 0.5 else ("can" if r < 0.78 else ("bag" if r < 0.9 else ("bottle" if r < 0.96 else "pencil")))
		# les plus déterminés (cagoulés, très audacieux) sortent un pétard quand ça chauffe
		var stage: int = crowd.police.stage if crowd and crowd.police else 0
		var hard: bool = outfit.get("face", "") == "balaclava" or bold > 0.78
		if stage >= 2 and hard and _rng.randf() < 0.16 + 0.1 * float(stage - 2):
			kind = "petard_m" if (stage >= 3 and _rng.randf() < 0.4) else "petard_s"
	state = "throwcop"
	state_t = 0.0
	sub = "wind"
	sub_t = 0.0
	data = {"t": target, "kind": kind}
	stop_move()
	face(target.global_position)
	var dirb := _wbd((target.global_position + Vector3.UP * 1.2 - head_pos()).normalized())
	set_act("throw", {"dir": dirb}, 10.0)


func _think_throwcop(delta: float) -> void:
	var tg: Node3D = dnode("t")
	if tg == null or not is_instance_valid(tg) or state_t > 3.0:
		go_home()
		return
	face(tg.global_position)
	if sub == "wind" and sub_t >= 0.47:
		sub = "done"
		sub_t = 0.0
		_launch_throwable(tg, data.get("kind", "stone"))
	elif sub == "done" and sub_t > 0.8:
		go_home()


func _launch_throwable(tg: Node3D, kind: String) -> void:
	if kind.begins_with("petard"):
		_launch_petard(tg, 2 if kind == "petard_m" else 1)
		return
	var t := Throwable.make(kind)
	t.thrower = self
	get_tree().current_scene.add_child(t)
	var pr := human.palm("R")
	t.global_position = (pr["pos"] as Vector3) + Vector3.UP * 0.05
	var aim := tg.global_position + Vector3(0, 1.25, 0)
	t.linear_velocity = _ballistic(t.global_position, aim, 14.0 if kind != "pencil" else 10.0) * _rng.randf_range(0.97, 1.03)
	t.angular_velocity = Vector3(_rng.randf_range(-9, 9), _rng.randf_range(-9, 9), _rng.randf_range(-9, 9))
	t.add_collision_exception_with(self)
	AudioLib.play_at(self, "toss", t.global_position, -4.0, 6.0)
	hostile = minf(hostile + 0.7, 1.5)
	if _rng.randf() < 0.45:
		say_cat("throw" if _rng.randf() < 0.5 else "anger", true)
