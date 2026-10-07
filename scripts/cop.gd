class_name Cop
extends Actor
## Policier (CRS) : tient une ligne avec bouclier et matraque, avance en formation, charge, tire du lacrymo
## ou du LBD, gaze, frappe, interpelle (voir police.gd pour la coordination).

var police: Police
var loadout := "shield"      # shield | grenadier | lbd | spray | boss | arrester
var squad := 0
var line_slot := Vector3.ZERO     # place voulue dans la ligne (monde)
var line_dir := Vector3(-1, 0, 0)  # direction de regard de la ligne
var state := "hold"
var sub := ""
var sub_t := 0.0
var state_t := 0.0
var data := {}
var target: Node3D
var masked := false
var gear := {}
var stun_t := 0.0
var alert := 0.0                    # 0 au repos .. 1 en garde
var hp := 1.0
var hold_pose := "cop_rest"

# accessoires tenus
var shield: Node3D
var baton: Node3D
var weapon: Node3D
var spray_n: Node3D
var cuffs_n: Node3D
var _shield_pos := Vector3.ZERO
var _shield_mode := "palm"          # palm | ground
var _shield_tilt := 0.0
var _shield_on := true
var _weapon_xf := Transform3D.IDENTITY
var _weapon_on := false
var _idle_cd := 0.0
var _idle_kind := ""
var _idle_t := 0.0
var _talk_cd := 0.0
var _voice_cd := 0.0


func _ready() -> void:
	outfit = CopGear.outfit(_rng) if outfit.is_empty() else outfit
	super._ready()
	gear = CopGear.equip(human, masked)
	_build_props()
	_idle_cd = _rng.randf_range(2.0, 8.0)
	_talk_cd = _rng.randf_range(10.0, 40.0)
	human.idle_sway = 0.6
	line_slot = global_position


func _build_props() -> void:
	if loadout in ["shield", "boss", "arrester"] or true:
		shield = CopGear.shield()
		shield.top_level = true
		add_child(shield)
		_shield_on = loadout in ["shield", "arrester"]
		shield.visible = _shield_on
	baton = CopGear.baton()
	baton.top_level = true
	add_child(baton)
	match loadout:
		"lbd":
			weapon = CopGear.lbd()
		"grenadier":
			weapon = CopGear.launcher()
	if weapon:
		weapon.top_level = true
		add_child(weapon)
		weapon.visible = false
	spray_n = CopGear.spray()
	spray_n.top_level = true
	spray_n.visible = false
	add_child(spray_n)
	cuffs_n = CopGear.cuffs()
	cuffs_n.top_level = true
	cuffs_n.visible = false
	add_child(cuffs_n)
	if loadout == "boss":
		mega = Props.megaphone()
		mega.top_level = true
		mega.visible = false
		add_child(mega)


func set_masked(on: bool) -> void:
	masked = on
	if gear.has("mask"):
		(gear["mask"] as Node3D).visible = on
	if gear.has("visor"):
		var tw := create_tween()
		tw.tween_property(gear["visor"], "rotation:x", 0.0, 0.25)


func raise_visor(on: bool) -> void:
	if gear.has("visor"):
		var tw := create_tween()
		tw.tween_property(gear["visor"], "rotation:x", -1.9 if on else 0.0, 0.3)


# =================================================================== poses
## Poignée de la main (matraque, bouclier) : `shaft` = direction de l'objet (axe du pouce), `palm` = côté de la paume.
func _grip(pos: Vector3, shaft: Vector3, palm: Vector3, left: bool, curl := 1.0) -> Dictionary:
	var s := shaft.normalized()
	var pn := palm - s * palm.dot(s)
	if pn.length() < 0.05:
		pn = Vector3(0, 1, 0) - s * s.y
	pn = pn.normalized()
	var f := pn.cross(s) if left else s.cross(pn)
	return _h(pos, f, pn, curl, 0.0, Vector3(-1.0 if left else 1.0, -1.0, -0.3))


func _pose(name: String, t: float, p: Dictionary) -> Array:
	if not name.begins_with("cop_"):
		return super(name, t, p)
	var k := _k
	var cur := name == act
	var sr := _wb(human.shoulder_world("R"))
	var sl := _wb(human.shoulder_world("L"))
	var handle := sl + Vector3(0.12, -0.4, 0.32) * k
	var base_r := sr + Vector3(-0.04, -0.46, 0.13) * k
	var r_hand: Variant = null
	var l_hand: Variant = null
	var shield_mode := "palm"
	match name:
		"cop_rest":
			# au repos : bouclier posé au sol à gauche, main sur le bord haut, matraque au côté
			shield_mode = "ground"
			l_hand = _h(sl + Vector3(0.0, -0.47, 0.2) * k, Vector3(0.2, -0.4, 0.9), Vector3(1, 0, 0), 0.6, 0.0, Vector3(-1, -1, -0.3))
			r_hand = _grip(sr + Vector3(-0.1, -0.5, 0.06) * k, Vector3(0, -1, 0.15), Vector3(-1, 0, 0), false, 0.8)
		"cop_guard":
			var lift: float = p.get("lift", 0.0)
			var push: float = p.get("push", 0.0)
			handle = sl + Vector3(0.12, -0.4 + 0.06 * lift, 0.3 + 0.2 * push) * k
			l_hand = _grip(handle, Vector3(1, 0, 0), Vector3(0, -0.2, 1), true, 1.0)
			r_hand = _grip(base_r, Vector3(0, -0.45, 1), Vector3(-1, 0, 0), false)
		"cop_ready":
			handle = sl + Vector3(0.12, -0.36, 0.3) * k
			l_hand = _grip(handle, Vector3(1, 0, 0), Vector3(0, -0.2, 1), true, 1.0)
			r_hand = _grip(sr + Vector3(-0.07, 0.0, 0.25) * k + Vector3(0, sin(t * 6.0) * 0.01, 0), Vector3(0, 0.85, 0.5), Vector3(-1, 0, 0), false)
		"cop_strike":
			var side: float = p.get("side", 1.0)
			handle = sl + Vector3(0.12, -0.36, 0.3) * k
			l_hand = _grip(handle, Vector3(1, 0, 0), Vector3(0, -0.2, 1), true, 1.0)
			var ready_pos := sr + Vector3(-0.07, 0.0, 0.25) * k
			var up_pos := sr + Vector3(0.1 * side + 0.02, 0.22, -0.02) * k
			var hit_pos := sr + Vector3(-0.22 * side - 0.05, -0.32, 0.5) * k
			var rec_pos := sr + Vector3(-0.1, -0.2, 0.34) * k
			var pos_r := ready_pos
			var sh := Vector3(0, 0.85, 0.5)
			if t < 0.26:
				var u := _ease(t / 0.26)
				pos_r = ready_pos.lerp(up_pos, u)
				sh = Vector3(0, 0.85, 0.5).lerp(Vector3(0.1 * side, 0.9, -0.5), u)
			elif t < 0.4:
				var u2 := clampf((t - 0.26) / 0.14, 0.0, 1.0)
				pos_r = up_pos.lerp(hit_pos, u2 * u2)
				sh = Vector3(0.1 * side, 0.9, -0.5).lerp(Vector3(-0.25 * side, -0.35, 0.9), u2)
			else:
				var u3 := _ease((t - 0.4) / 0.45)
				pos_r = hit_pos.lerp(rec_pos, u3)
				sh = Vector3(-0.25 * side, -0.35, 0.9).lerp(Vector3(0, 0.3, 0.9), u3)
			r_hand = _grip(pos_r, sh, Vector3(-1, 0, 0), false)
		"cop_lbd", "cop_gl":
			shield_mode = "none"
			var aim: Vector3 = p.get("dir", Vector3(0, 0.05, 1)).normalized()
			var low: float = p.get("low", 0.0)
			# repère de l'arme (monde)
			var aim_w := _bd(aim)
			var up_w := Vector3.UP - aim_w * aim_w.y
			up_w = up_w.normalized() if up_w.length() > 0.05 else Vector3.BACK
			var xw := up_w.cross(aim_w).normalized()
			var shr_w := human.shoulder_world("R")
			var origin := shr_w + aim_w * 0.30 - up_w * 0.1 + xw * 0.03
			if cur:
				_weapon_xf = Transform3D(Basis(xw, up_w, aim_w), origin)
				_weapon_on = true
			var gp := _wb(origin + up_w * -0.035 + aim_w * 0.0)
			var gl := _wb(origin + up_w * -0.04 + aim_w * (0.27 if name == "cop_lbd" else 0.3))
			r_hand = _h(gp, _bd_inv(aim_w * 0.4 - up_w * 0.9), _bd_inv(-xw * 1.0 + aim_w * 0.1), 0.95, 0.5, Vector3(1, -1, -0.2))
			l_hand = _h(gl, _bd_inv(aim_w * 0.7 - up_w * 0.3), _bd_inv(xw), 0.9, 0.0, Vector3(-1, -1, -0.3))
		"cop_spray":
			var dr: Vector3 = p.get("dir", Vector3(0, 0, 1)).normalized()
			handle = sl + Vector3(0.12, -0.36, 0.3) * k
			l_hand = _grip(handle, Vector3(1, 0, 0), Vector3(0, -0.2, 1), true, 1.0)
			r_hand = _grip(sr + dr * 0.52 * k + Vector3(-0.03, -0.04, 0), dr + Vector3(0, 0.15, 0), Vector3(-1, 0, 0), false)
		"cop_grab":
			var tg: Vector3 = p.get("target", Vector3(0.0, 1.2, 0.7))
			var u4: float = clampf(p.get("u", 0.0), 0.0, 1.0)
			l_hand = _h(sl + Vector3(0.12, -0.3, 0.3) * k, Vector3(0, 0, 1), Vector3(1, 0, 0), 0.5, 0.0, Vector3(-1, -1, -0.3))
			var rp := base_r.lerp(tg, _ease(u4))
			r_hand = _h(rp, (tg - rp).normalized(), Vector3(-1, 0, 0), 1.0 if u4 > 0.9 else 0.5, 0.0, Vector3(1, -1, -0.3))
			if p.get("both", false):
				l_hand = _h(sl.lerp(tg, 0.0) + Vector3(0.12, -0.3, 0.3) * k, Vector3(0, 0, 1), Vector3(1, 0, 0), 0.5)
		"cop_cuff":
			var tg2: Vector3 = p.get("target", Vector3(0.0, 1.0, 0.45))
			var jig := Vector3(sin(t * 9.0) * 0.012, sin(t * 7.0) * 0.012, 0)
			r_hand = _h(tg2 + Vector3(-0.07, 0, 0) + jig, Vector3(0.3, -0.2, 1), Vector3(-1, 0, 0), 0.9, 0.0, Vector3(1, -1, -0.3))
			l_hand = _h(tg2 + Vector3(0.07, 0, 0) - jig, Vector3(-0.3, -0.2, 1), Vector3(1, 0, 0), 0.9, 0.0, Vector3(-1, -1, -0.3))
		"cop_hold_arm":
			# tient fermement un bras (escorte)
			var tg3: Vector3 = p.get("target", Vector3(0.4, 1.1, 0.4))
			r_hand = _h(tg3, Vector3(0.2, -0.6, 0.5), Vector3(-1, 0, 0), 1.0, 0.0, Vector3(1, -1, -0.3))
			l_hand = _h(sl + Vector3(0.1, -0.5, 0.15) * k, Vector3(0, -1, 0.3), Vector3(1, 0, 0), 0.6)
		"cop_stop":
			handle = sl + Vector3(0.12, -0.4, 0.3) * k
			l_hand = _grip(handle, Vector3(1, 0, 0), Vector3(0, -0.2, 1), true, 1.0)
			var wv := sin(t * 3.0) * 0.03
			r_hand = _h(sr + Vector3(-0.05, 0.05 + wv, 0.4) * k, Vector3(0, 0.9, 0.3), Vector3(0, 0, 1), 0.1, 0.0, Vector3(1, -1, -0.2))
		"cop_radio":
			handle = sl + Vector3(0.12, -0.42, 0.28) * k
			shield_mode = "ground" if loadout != "boss" else "none"
			l_hand = _h(sl + Vector3(0.0, -0.47, 0.2) * k, Vector3(0.2, -0.4, 0.9), Vector3(1, 0, 0), 0.6, 0.0, Vector3(-1, -1, -0.3))
			r_hand = _h(sl + Vector3(0.13, 0.0, 0.18) * k, Vector3(0.3, 0.9, 0.2), Vector3(-1, 0, 0.3), 0.8, 0.0, Vector3(1, -1, -0.3))
		"cop_helmet":
			shield_mode = "ground"
			l_hand = _h(sl + Vector3(0.0, -0.47, 0.2) * k, Vector3(0.2, -0.4, 0.9), Vector3(1, 0, 0), 0.6, 0.0, Vector3(-1, -1, -0.3))
			var hd := _wb(human.head_world())
			r_hand = _h(hd + Vector3(-0.1, 0.1 + sin(t * 4.0) * 0.01, 0.05), Vector3(0.6, 0.6, 0.3), Vector3(-0.3, -0.3, 1), 0.3, 0.0, Vector3(1, 0, -0.3))
		"cop_hit":
			handle = sl + Vector3(0.12, -0.3, 0.26) * k
			l_hand = _grip(handle, Vector3(1, 0, 0), Vector3(0, -0.2, 1), true, 1.0)
			r_hand = _h(_wb(human.head_world()) + Vector3(-0.1, 0.05, 0.1), Vector3(0.3, 0.9, 0.2), Vector3(-1, 0, 0), 0.4, 0.0, Vector3(1, 0, -0.3))
		"cop_mega":
			shield_mode = "none"
			if mega:
				var mp := mouth_xf()
				var mg: Vector3 = mega.get_meta("grip", Vector3(0, -0.092, 0.092))
				var mouth_b := _wb(mp.origin)
				r_hand = _h(mouth_b + Vector3(0.09, -0.09, 0.14), Vector3(0, 0.3, 1), Vector3(-1, 0, 0), 0.9, 0.0, Vector3(1, -1, -0.3))
				l_hand = _h(sl + Vector3(0.1, -0.5, 0.15) * k, Vector3(0, -1, 0.3), Vector3(1, 0, 0), 0.6)
		"cop_fall_cover":
			shield_mode = "palm"
			handle = sl + Vector3(0.1, -0.1, 0.28) * k
			l_hand = _grip(handle, Vector3(1, 0, 0), Vector3(0, -0.2, 1), true, 1.0)
			r_hand = _h(_wb(human.head_world()) + Vector3(-0.08, 0.1, 0.06), Vector3(0.4, 0.8, 0.2), Vector3(-1, 0, 0), 0.4)
	if cur:
		_shield_mode = shield_mode
		_shield_hand_b = handle
	return [r_hand, l_hand]


var _shield_hand_b := Vector3.ZERO


func _bd_inv(world_dir: Vector3) -> Vector3:
	return _wbd(world_dir)


# =================================================================== accessoires (placement)
func _place_props() -> void:
	var pl := human.palm("L")
	var pr := human.palm("R")
	# bouclier
	if shield:
		var show := _shield_on and _shield_mode != "none"
		shield.visible = show
		if show:
			var tgt: Vector3
			var ax := global_basis * Basis(Vector3.UP, PI)
			if _shield_mode == "ground":
				tgt = _bw(Vector3(-0.31, 0.5, 0.16))
				ax = ax * Basis(Vector3.RIGHT, deg_to_rad(-6.0))
			else:
				tgt = (pl["pos"] as Vector3) + (pl["p"] as Vector3) * 0.02
				ax = ax * Basis(Vector3.RIGHT, deg_to_rad(-4.0 + _shield_tilt))
			if _shield_pos == Vector3.ZERO:
				_shield_pos = tgt
			_shield_pos = _shield_pos.lerp(tgt, 0.6)
			shield.global_transform = Transform3D(ax, _shield_pos)
	# matraque dans la main droite
	var wants_baton := act in ["cop_guard", "cop_ready", "cop_strike", "cop_rest", "cop_stop", "cop_spray", "cop_hold_arm", "cop_helmet"] or (act == "cop_radio" and false)
	if baton:
		baton.visible = wants_baton and loadout != "grenadier" and act != "cop_spray"
		if baton.visible:
			var th: Vector3 = pr["thumb"]
			var grip: Vector3 = (pr["pos"] as Vector3) + (pr["p"] as Vector3) * 0.015
			baton.global_transform = Transform3D(Props.basis_up(th, pr["f"]), grip - th * 0.06)
	# arme longue
	if weapon:
		var on := act in ["cop_lbd", "cop_gl"] and _weapon_on
		weapon.visible = on
		if on:
			weapon.global_transform = _weapon_xf
	# bombe lacrymogène
	if spray_n:
		spray_n.visible = act == "cop_spray"
		if spray_n.visible:
			var th2: Vector3 = pr["thumb"]
			spray_n.global_transform = Transform3D(Props.basis_up(pr["f"], th2), (pr["pos"] as Vector3) + (pr["p"] as Vector3) * 0.01 + (pr["f"] as Vector3) * 0.03)
	# menottes
	if cuffs_n:
		cuffs_n.visible = act == "cop_cuff"
		if cuffs_n.visible:
			cuffs_n.global_position = ((pr["pos"] as Vector3) + (pl["pos"] as Vector3)) * 0.5
			cuffs_n.global_basis = global_basis
	# mégaphone
	if mega:
		mega.visible = act == "cop_mega"
		if mega.visible:
			var mb := Props.basis_up(pr["thumb"], pr["f"])
			var gl: Vector3 = mega.get_meta("grip")
			mega.global_transform = Transform3D(mb, (pr["pos"] as Vector3) - mb * gl)


# =================================================================== cerveau
var role := "line"                  # line | support | team | patrol | boss
var _strike_side := 1.0
var _strike_hit := false
var _shots := 0
var _target_refresh := 0.0
var _gas_left := 0
var arrestee: Node3D                # personne qu'on interpelle / escorte
var van: PoliceVehicle
var _flash: OmniLight3D
var _kick_cd := 0.0
var _pending_state := ""


func _pre_tick(delta: float) -> void:
	state_t += delta
	sub_t += delta
	stun_t = maxf(stun_t - delta, 0.0)
	_idle_cd = maxf(_idle_cd - delta, 0.0)
	_voice_cd = maxf(_voice_cd - delta, 0.0)
	_kick_cd = maxf(_kick_cd - delta, 0.0)
	_target_refresh = maxf(_target_refresh - delta, 0.0)


func set_state(s: String, d := {}) -> void:
	state = s
	sub = ""
	sub_t = 0.0
	state_t = 0.0
	data = d
	if s != "hold" and s != "advance":
		_idle_kind = ""


func busy() -> bool:
	return state in ["strike", "gas", "lbd", "spray", "arrest", "escort", "stagger", "down", "charge"]


func _think(delta: float) -> void:
	if stun_t > 0.0 and state != "down":
		_think_stagger(delta)
		return
	match state:
		"hold", "advance":
			_think_line(delta)
		"exit":
			_think_exit(delta)
		"charge":
			_think_charge(delta)
		"strike":
			_think_strike(delta)
		"gas":
			_think_gas(delta)
		"lbd":
			_think_lbd(delta)
		"spray":
			_think_spray(delta)
		"arrest":
			_think_arrest(delta)
		"retreat":
			_think_retreat(delta)
		"stagger":
			_think_stagger(delta)
		"down":
			_think_down(delta)
		"mega":
			_think_mega(delta)


func _say_pol(cat: String, loud := true, cd := 3.0) -> void:
	if _voice_cd > 0.0 or speaking():
		return
	_voice_cd = cd
	var nm := AudioLib.pick(voice, cat)
	if nm != "":
		say(nm, loud, 3.0)


# --- tenue de ligne / avance ------------------------------------------------
func _think_line(delta: float) -> void:
	var to := line_slot - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 0.45:
		var run := dist > 7.0 and (state == "advance" or role != "line")
		if not has_goal or goal.distance_to(line_slot) > 0.8:
			go(line_slot, run, 0.3)
		set_act("cop_guard", {"lift": 0.4 + alert * 0.4}, 4.0)
		return
	stop_move()
	face(global_position + line_dir * 8.0)
	if alert > 0.5:
		var push: float = 1.0 if (police and police.mode == "push") else 0.0
		set_act("cop_guard", {"lift": 0.8, "push": push * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 1.5 + idx))}, 4.0)
		look(global_position + line_dir * 10.0 + Vector3(0, 1.5, 0), 0.7)
		return
	if _idle_cd <= 0.0 and _idle_kind == "":
		_idle_kind = ["radio", "helmet", "rest", "rest", "look", "talk"][_rng.randi() % 6]
		_idle_t = _rng.randf_range(2.5, 5.0)
	if _idle_kind != "":
		_idle_t -= delta
		match _idle_kind:
			"radio":
				set_act("cop_radio", {}, 3.5)
				look(global_position + line_dir * 8.0 + Vector3(0, 1.5, 0), 0.6)
				if _idle_t > 1.0 and _voice_cd <= 0.0 and _rng.randf() < 0.01:
					_voice_cd = 12.0
					var nm := AudioLib.pick(voice, "pol_radio")
					if nm != "":
						say(nm, false, -4.0)
			"helmet":
				set_act("cop_helmet", {}, 3.5)
			"look":
				var side := Vector3(-line_dir.z, 0, line_dir.x) * (6.0 if _idle_t > 1.5 else -6.0)
				look(global_position + line_dir * 8.0 + side + Vector3(0, 1.5, 0), 1.0)
				set_act("cop_rest", {}, 3.0)
			"talk":
				set_act("cop_rest", {}, 3.0)
				if _voice_cd <= 0.0 and _rng.randf() < 0.02:
					_say_pol("pol_idle", false, 14.0)
			_:
				set_act("cop_rest", {}, 3.0)
		if _idle_t <= 0.0:
			_idle_kind = ""
			_idle_cd = _rng.randf_range(3.0, 9.0)
	else:
		set_act("cop_rest", {}, 3.0)


func _think_exit(delta: float) -> void:
	# sortie du véhicule : rejoint sa place
	set_act("cop_guard", {"lift": 0.3}, 4.0)
	if not has_goal or goal.distance_to(line_slot) > 1.0:
		go(line_slot, false, 0.4)
	if global_position.distance_to(line_slot) < 0.9 or state_t > 20.0:
		set_state("hold")


# --- charge / matraque --------------------------------------------------------
func charge(t: Node3D, dur := 7.0) -> void:
	set_state("charge", {"dur": dur})
	target = t
	_say_pol("pol_charge", true, 4.0)


func _live_target() -> bool:
	return target != null and is_instance_valid(target) and not (target is Npc and (target as Npc).state in ["arrested", "boarded"])


func _think_charge(delta: float) -> void:
	if not _live_target() or state_t > float(data.get("dur", 7.0)):
		_end_action()
		return
	var tp := target.global_position
	var to := tp - global_position
	to.y = 0.0
	var d := to.length()
	look(tp + Vector3.UP * 1.3, 1.0)
	if d > 1.7:
		go(tp - to.normalized() * 1.0, true, 0.2)
		set_act("cop_ready", {}, 5.0)
		face(tp)
		return
	stop_move()
	face(tp)
	_start_strike()


func _start_strike() -> void:
	if _kick_cd > 0.0:
		set_act("cop_ready", {}, 6.0)
		return
	_pending_state = state
	state = "strike"
	sub_t = 0.0
	_strike_hit = false
	_strike_side = 1.0 if _rng.randf() < 0.5 else -1.0
	set_act("cop_strike", {"side": _strike_side}, 14.0)
	AudioLib.play_at(self, "baton_swing", global_position + Vector3.UP * 1.3, -4.0, 6.0, _rng.randf_range(0.9, 1.1))
	if _rng.randf() < 0.5:
		_say_pol("pol_order", true, 3.0)


func _think_strike(_delta: float) -> void:
	if _live_target():
		face(target.global_position)
	if not _strike_hit and sub_t >= 0.34:
		_strike_hit = true
		_apply_strike()
	if sub_t >= 0.9:
		_kick_cd = _rng.randf_range(0.5, 1.1)
		state = _pending_state if _pending_state != "" else "charge"
		sub_t = 0.0


func _apply_strike() -> void:
	if not _live_target():
		return
	var tp := target.global_position
	var to := tp - global_position
	to.y = 0.0
	if to.length() > 2.0:
		return
	var dir := to.normalized()
	if target is Player:
		(target as Player).take_hit("baton", dir)
	elif target.has_method("on_police_hit"):
		target.on_police_hit("baton", dir, self)
	get_tree().call_group("crowd", "on_event", "police_baton", {"pos": tp})


func _end_action() -> void:
	target = null
	arrestee = null
	set_state("hold" if (police == null or police.mode != "advance") else "advance")


# --- grenadier ------------------------------------------------------------------
func fire_gas(pos: Vector3, count := 1) -> void:
	set_state("gas", {"pos": pos})
	_gas_left = count
	_say_pol("pol_gas", true, 2.0)


func _think_gas(delta: float) -> void:
	var tp: Vector3 = data["pos"]
	var aim := _wbd((tp + Vector3.UP * 4.0 - human.shoulder_world("R")).normalized())
	aim.y = clampf(aim.y, 0.15, 0.7)
	if weapon == null:
		_end_action()
		return
	face(tp)
	if global_position.distance_to(tp) < 9.0:
		# trop près : on se replie d'abord
		go(global_position - (tp - global_position).normalized() * 6.0, false, 0.4)
		return
	stop_move()
	set_act("cop_gl", {"dir": aim}, 5.0)
	look(tp + Vector3.UP * 3.0, 1.0)
	if sub == "":
		sub = "aim"
		sub_t = 0.0
	if sub == "aim" and sub_t > 0.85:
		_launch_grenade(tp)
		_gas_left -= 1
		sub = "recoil"
		sub_t = 0.0
	elif sub == "recoil" and sub_t > 0.9:
		if _gas_left > 0:
			sub = "aim"
			sub_t = 0.2
		else:
			_end_action()


func _launch_grenade(tp: Vector3) -> void:
	var muzzle: Vector3 = weapon.global_transform * (weapon.get_node("Muzzle") as Node3D).position
	var err := Vector3(_rng.randf_range(-2.5, 2.5), 0, _rng.randf_range(-2.5, 2.5))
	var g := GasGrenade.new()
	get_tree().current_scene.add_child(g)
	g.global_position = muzzle
	g.launch_to(tp + err, 17.0)
	AudioLib.play_at(self, "gas_launch", muzzle, 2.0, 25.0)
	human.kick_back(0.6)
	_flash_at(muzzle)
	get_tree().call_group("crowd", "on_event", "police_gas", {"pos": tp, "from": global_position})


func _flash_at(p: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.45)
	l.light_energy = 6.0
	l.omni_range = 5.0
	get_tree().current_scene.add_child(l)
	l.global_position = p
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.09)
	tw.tween_callback(l.queue_free)


# --- LBD ---------------------------------------------------------------------------
func fire_lbd(t: Node3D, shots := 1) -> void:
	set_state("lbd", {})
	target = t
	_shots = shots
	_say_pol("pol_lbd", true, 2.0)


func _think_lbd(delta: float) -> void:
	if not _live_target() or weapon == null:
		_end_action()
		return
	var tp := _aim_point(target)
	var aim := _wbd((tp - human.shoulder_world("R")).normalized())
	face(target.global_position)
	stop_move()
	set_act("cop_lbd", {"dir": aim}, 6.0)
	look(tp, 1.0)
	if sub == "":
		sub = "aim"
		sub_t = 0.0
	if sub == "aim" and sub_t > 0.9:
		_shoot_lbd(tp)
		_shots -= 1
		sub = "recoil"
		sub_t = 0.0
	elif sub == "recoil" and sub_t > 0.7:
		if _shots > 0 and _live_target():
			sub = "aim"
			sub_t = 0.45
		else:
			_end_action()


func _aim_point(t: Node3D) -> Vector3:
	if t is Player:
		return (t as Player).global_position + Vector3(0, 1.0, 0)
	if t is Actor:
		return (t as Actor).global_position + Vector3(0, 1.0, 0)
	return t.global_position


func _shoot_lbd(tp: Vector3) -> void:
	var muzzle: Vector3 = weapon.global_transform * (weapon.get_node("Muzzle") as Node3D).position
	var dist := muzzle.distance_to(tp)
	var chance := clampf(1.05 - dist / 42.0, 0.2, 0.9)
	AudioLib.play_at(self, "lbd_shot", muzzle, 4.0, 30.0)
	_flash_at(muzzle)
	human.kick_back(1.0)
	var dir := (tp - muzzle).normalized()
	get_tree().call_group("crowd", "on_event", "police_lbd", {"pos": tp, "from": muzzle})
	if randf() < chance:
		if target is Player:
			(target as Player).take_hit("lbd", dir)
		elif target.has_method("on_police_hit"):
			target.on_police_hit("lbd", dir, self)
	else:
		# manqué : impact au sol derrière la cible
		var miss := tp + dir * 3.0 + Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5))
		AudioLib.play_at(self, "can_clink", Vector3(miss.x, 0.1, miss.z), -6.0, 8.0, 1.4)


# --- gazeuse ------------------------------------------------------------------------
func spray_at(t: Node3D) -> void:
	set_state("spray", {})
	target = t
	_say_pol("pol_spray", true, 2.0)


func _think_spray(delta: float) -> void:
	if not _live_target():
		_end_action()
		return
	var tp := _aim_point(target)
	var to := tp - global_position
	to.y = 0.0
	face(tp)
	if to.length() > 1.9:
		go(tp - to.normalized() * 1.4, true, 0.25)
		set_act("cop_ready", {}, 5.0)
		return
	stop_move()
	var aim := _wbd((tp - human.shoulder_world("R")).normalized())
	set_act("cop_spray", {"dir": aim}, 8.0)
	if sub == "":
		sub = "spray"
		sub_t = 0.0
		AudioLib.play_at(self, "pepper_spray", global_position + Vector3.UP * 1.3, 0.0, 8.0)
		_spray_fx(tp)
	if sub == "spray" and sub_t > 0.5 and sub_t < 0.52:
		pass
	if sub == "spray" and sub_t > 0.45 and not data.get("done", false):
		data["done"] = true
		if target is Player:
			(target as Player).apply_pepper(1.0)
		elif target.has_method("on_police_hit"):
			target.on_police_hit("spray", to.normalized(), self)
	if sub_t > 1.5:
		_end_action()


func _spray_fx(tp: Vector3) -> void:
	var p := Fx.smoke(Color(0.95, 0.5, 0.3, 0.55), 26, 0.7, 0.07, false, 0.2, 2.5)
	p.one_shot = true
	p.explosiveness = 0.6
	get_tree().current_scene.add_child(p)
	p.global_position = (spray_n.global_position if spray_n else global_position + Vector3.UP * 1.3)
	var dirw := (tp - p.global_position).normalized()
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = dirw
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 4.5
	pm.spread = 8.0
	pm.gravity = Vector3(0, -0.4, 0)
	p.emitting = true
	get_tree().create_timer(2.5).timeout.connect(p.queue_free)


# --- interpellation ----------------------------------------------------------------
func arrest(t: Node3D) -> void:
	set_state("arrest", {})
	arrestee = t
	sub = "run"
	_say_pol("pol_warn" if t is Player else "pol_arrest", true, 3.0)


func _think_arrest(delta: float) -> void:
	if arrestee == null or not is_instance_valid(arrestee):
		_end_action()
		return
	var tp := arrestee.global_position
	var to := tp - global_position
	to.y = 0.0
	var d := to.length()
	match sub:
		"run":
			if arrestee is Npc and (arrestee as Npc).state in ["arrested", "boarded"] and (arrestee as Npc).data.get("cop") != self:
				_end_action()
				return
			if d > 1.25:
				go(tp - to.normalized() * 0.8, true, 0.2)
				set_act("cop_ready", {}, 5.0)
				face(tp)
				if state_t > 14.0:
					_end_action()
				return
			stop_move()
			face(tp)
			if arrestee is Player:
				var pl := arrestee as Player
				if not pl.begin_arrest(self):
					# libéré tout juste : on temporise
					if sub_t > 3.0:
						_end_action()
					return
				sub = "hold_player"
			else:
				var np := arrestee as Npc
				np.on_grabbed(self)
				sub = "grab"
			sub_t = 0.0
		"grab":
			var tgb := _wb(tp + Vector3(0, 1.15, 0) - to.normalized() * 0.15)
			set_act("cop_grab", {"target": tgb, "u": clampf(sub_t / 0.4, 0.0, 1.0)}, 8.0)
			face(tp)
			if sub_t > 0.9:
				sub = "cuff"
				sub_t = 0.0
				AudioLib.play_at(self, "cuff_click", global_position + Vector3.UP, -2.0, 5.0)
		"cuff":
			var tgc := _wb(tp + Vector3(0, 1.0, 0.0) - to.normalized() * 0.1)
			set_act("cop_cuff", {"target": tgc}, 6.0)
			face(tp)
			if sub_t > 2.6:
				AudioLib.play_at(self, "cuff_click", global_position + Vector3.UP, 0.0, 5.0)
				if arrestee is Npc:
					(arrestee as Npc).on_cuffed(self)
				sub = "escort"
				sub_t = 0.0
				van = police.nearest_van(global_position) if police else null
				get_tree().call_group("crowd", "on_event", "arrest", {"pos": tp})
		"escort":
			if van == null or not is_instance_valid(van):
				van = police.nearest_van(global_position) if police else null
			var dest := (van.global_position + van.global_basis * Vector3(0, 0, 4.4)) if (van != null and van.kind == "truck") else line_slot
			if van != null and van.kind == "car":
				dest = van.global_position + van.global_basis * Vector3(1.6, 0, 0.9)
			set_act("cop_hold_arm", {"target": _wb(tp + Vector3(0.1, 1.15, 0.0))}, 5.0)
			if not has_goal or goal.distance_to(dest) > 1.5:
				go(dest, false, 0.6)
			if arrestee is Npc:
				(arrestee as Npc).escort_to(global_position - forward() * 0.55 + global_basis.x * 0.2)
			if global_position.distance_to(dest) < 1.8 or sub_t > 40.0:
				if arrestee is Npc:
					(arrestee as Npc).on_boarded(van)
				if police:
					police.arrested_count += 1
				arrestee = null
				_end_action()
		"hold_player":
			var pl2 := arrestee as Player
			face(tp)
			stop_move()
			if pl2.arrest_phase == "":
				# il s'est libéré
				_end_action()
				return
			if pl2.arrest_phase == "cuffed":
				var tgp := _wb(tp + Vector3(0, 1.0, 0.0) - to.normalized() * 0.1)
				set_act("cop_cuff", {"target": tgp}, 6.0)
			else:
				var tgg := _wb(tp + Vector3(0, 1.15, 0) - to.normalized() * 0.15)
				set_act("cop_grab", {"target": tgg, "u": 1.0, "both": true}, 8.0)
				pl2.hit_flash = maxf(pl2.hit_flash, 0.15)


func on_player_broke_free(from: Vector3) -> void:
	set_state("stagger", {"from": from})
	stun_t = 1.1
	human.kick_back(1.0)


# --- repli / retrait --------------------------------------------------------------------
func retreat_to(p: Vector3, run := false) -> void:
	set_state("retreat", {"pos": p, "run": run})
	_say_pol("pol_retreat", true, 3.0)


func _think_retreat(delta: float) -> void:
	var p: Vector3 = data["pos"]
	set_act("cop_guard", {"lift": 0.6}, 4.0)
	if global_position.distance_to(p) > 0.8:
		if not has_goal:
			go(p, bool(data.get("run", false)), 0.5)
	else:
		_end_action()
	if state_t > 18.0:
		_end_action()


# --- coups reçus ---------------------------------------------------------------------------
func on_hit(kind: String, from_dir: Vector3, power := 1.0, by: Node3D = null) -> void:
	# `from_dir` : sens du projectile (de l'attaquant vers nous)
	var front := forward()
	var blocked := shield != null and _shield_on and _shield_mode == "palm" and from_dir.dot(front) < -0.2
	if blocked:
		AudioLib.play_at(self, "baton_hit_shield" if kind != "stone" else "shield_tap_%d" % _rng.randi_range(0, 2), global_position + Vector3.UP * 1.1, 0.0, 6.0)
		human.kick_back(0.4 * power)
		if police and by != null:
			police.on_cop_hit(self, kind, by)
		return
	hp -= 0.12 * power
	human.kick_back(1.0)
	AudioLib.play_at(self, "punch" if kind != "stone" else "stone_thud", global_position + Vector3.UP * 1.5, -2.0, 6.0)
	_say_pol("pol_hit", true, 2.5)
	get_tree().call_group("crowd", "on_event", "cop_hit", {"pos": global_position, "kind": kind})
	if police:
		police.on_cop_hit(self, kind, by)
	if power >= 1.0 or _rng.randf() < 0.4:
		stagger(0.9 * power, from_dir)


func stagger(dur: float, from_dir := Vector3.ZERO) -> void:
	if state in ["down", "stagger"]:
		return
	_pending_state = state if state != "strike" else "charge"
	state = "stagger"
	state_t = 0.0
	sub_t = 0.0
	stun_t = dur
	data = {"dir": from_dir}
	stop_move()
	set_act("cop_hit", {}, 10.0)


func _think_stagger(delta: float) -> void:
	set_act("cop_hit", {}, 10.0)
	if stun_t <= 0.0:
		state = "hold" if _pending_state in ["", "stagger"] else _pending_state
		if state in ["charge", "arrest", "lbd", "gas", "spray"] and not _live_target() and arrestee == null:
			state = "hold"


func on_gas(density: float, from: Vector3) -> void:
	# les policiers enfilent leur masque quand le gaz s'approche ; sans masque ils toussent
	if not masked and density > 0.08:
		set_masked(true)
		_say_pol("pol_gas", true, 6.0)
	if masked:
		return
	human.hunch = maxf(human.hunch, 0.5)


func knock_down(dur := 4.0) -> void:
	set_state("down", {"dur": dur})
	stop_move()
	human.fall_dir = 0.0 if _rng.randf() < 0.5 else PI
	_say_pol("pol_down", true, 3.0)
	get_tree().call_group("crowd", "on_event", "cop_down", {"pos": global_position})


func _think_down(delta: float) -> void:
	var dur: float = data.get("dur", 4.0)
	human.fall = move_toward(human.fall, 1.0 if state_t < dur else 0.0, delta * (4.0 if state_t < dur else 1.0))
	if state_t > dur + 1.1:
		human.fall = 0.0
		set_state("hold")


func kick(point: Vector3, dir: Vector3, _power := 1.0) -> bool:
	if global_position.distance_to(Vector3(point.x, global_position.y, point.z)) > 0.95:
		return false
	on_hit("shove", dir, 1.3)
	if police:
		police.on_cop_kicked(self)
	return true


# --- mégaphone -------------------------------------------------------------------------------
func speak_mega(line: int) -> void:
	set_state("mega", {"line": line})
	sub = ""


func _think_mega(delta: float) -> void:
	stop_move()
	face(global_position + line_dir * 8.0)
	set_act("cop_mega", {}, 4.0)
	if sub == "":
		sub = "say"
		sub_t = 0.0
		var nm := "pol_mega_%d" % int(data.get("line", 0))
		say(nm, true, 8.0)
	elif sub_t > 1.0 and not speaking():
		set_state("hold")
