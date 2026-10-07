class_name Igniter
extends Node3D
## Briquet + déchets (touche 3). Clic gauche : déposer le journal (ou le carton / la planche ramassé) dans
## une poubelle ouverte, dans un feu, ou par terre, puis l'allumer au briquet. Le bras qui tient le briquet
## plonge dans la poubelle ; au sol on s'accroupit. Clic droit : briquet seul. Rien n'est lancé.

signal message(text: String)

const REACH_BIN := 1.22
const REACH_FIRE := 1.6
const REACH_LIGHT := 1.4
const REACH_PICK := 1.5

var human: Human
var equipped := false
var busy := false
var equip_t := 0.0
var aim_t := 0.0                 # compat. caméra : jamais de zoom avec cet outil
var lit := false                 # flamme du briquet allumée
var lock_yaw := NAN              # orientation imposée au corps pendant le geste
var approach_pos := Vector3.ZERO # le joueur se rapproche de ce point (centre de la poubelle) jusqu'à approach_d
var approach_d := 0.0
var held: Burnable               # objet ramassé (null : journal sorti de la poche)
var plan := {}
var near_pick: Burnable

var _aim_input := false
var _ph: Array = []
var _pi := -1
var _pt := 0.0
var _ctx := {}
var _fresh := 1.0
var _lighter: Node3D
var _paper: Node3D
var _rng := RandomNumberGenerator.new()
var _queued_pick: Burnable
var _lighter_on := false
var _crouch := 0.0
var _lean := 0.0
var _plan_scan := 0.0
var _rw := 0.0                   # poids de la main droite guidée
var _lw := 0.0
var _released := false           # le journal a quitté la main
var _post_on := false


func _ready() -> void:
	_rng.randomize()
	_paper = Props.newspaper_roll()
	_paper.top_level = true
	_paper.visible = false
	add_child(_paper)
	_lighter = Props.lighter(Color(0.85, 0.2, 0.1))
	_lighter.top_level = true
	_lighter.visible = false
	add_child(_lighter)


func attach_to(h: Human) -> void:
	human = h
	h.add_child(self)


func set_equipped(on: bool) -> void:
	if busy and not on:
		return
	equipped = on
	if not on:
		plan = {}


func hide_now() -> void:
	_abort()
	equipped = false
	equip_t = 0.0
	_aim_input = false
	lit = false
	_paper.visible = false
	_lighter.visible = false
	_drop_held()


func set_aim(on: bool) -> void:
	_aim_input = on and equipped


func _abort() -> void:
	busy = false
	_pi = -1
	_ph = []
	_pt = 0.0
	_ctx = {}
	_lighter_on = false
	_released = false
	lock_yaw = NAN
	approach_d = 0.0
	_crouch = 0.0
	_lean = 0.0
	_apply_posture(0.0)


func _drop_held() -> void:
	if held != null and is_instance_valid(held) and human != null:
		var b := held
		held = null
		b.reparent(get_tree().current_scene, true)
		b.set_held(false)
		b.global_position = human.global_position + Vector3.UP * 0.6 + Basis(Vector3.UP, human.rotation.y) * Vector3(0, 0, -0.45)
		b.linear_velocity = Vector3.UP * 0.5
	held = null


func held_label() -> String:
	return Burnable.label_of(held.kind) if held != null and is_instance_valid(held) else "le journal"


# ------------------------------------------------------------------ cibles
func _fwd() -> Vector3:
	return Basis(Vector3.UP, human.rotation.y) * Vector3(0, 0, -1)


func _ground_at(p: Vector3) -> Variant:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.2, p + Vector3.DOWN * 1.0, 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r and (r["normal"] as Vector3).y > 0.7 and (r["position"] as Vector3).y < 0.4:
		return r["position"]
	return null


## Ce que le clic gauche ferait maintenant : {type: bin|fire|light|ground, node, pos}
func _plan() -> Dictionary:
	var pp := human.global_position
	var fwd := _fwd()
	var best := 99.0
	var out := {}
	for b in get_tree().get_nodes_in_group("bins"):
		var bin := b as TrashBin
		if bin.tipped or bin.grabbed_by != null:
			continue
		var d := bin.global_position - pp
		d.y = 0.0
		var l := d.length()
		if l < REACH_BIN and l < best and fwd.dot(d / maxf(l, 0.01)) > 0.45:
			best = l
			out = {"type": "bin", "node": bin}
	if not out.is_empty():
		return out
	for f in get_tree().get_nodes_in_group("fires"):
		var fire := f as FloorFire
		if not fire.burning:
			continue
		var d2 := fire.global_position - pp
		d2.y = 0.0
		var l2 := d2.length()
		if l2 < REACH_FIRE and l2 < best and fwd.dot(d2 / maxf(l2, 0.01)) > 0.4:
			best = l2
			out = {"type": "fire", "node": fire}
	if not out.is_empty():
		return out
	best = REACH_LIGHT
	for o in get_tree().get_nodes_in_group("burnables"):
		var bu := o as Burnable
		if bu == held or bu.held or bu.lit or bu.fire != null or bu.in_bin != null or bu._dying:
			continue
		var d3 := bu.global_position - pp
		if d3.y > 0.8:
			continue
		d3.y = 0.0
		var l3 := d3.length()
		if l3 < best and fwd.dot(d3 / maxf(l3, 0.01)) > 0.35:
			best = l3
			out = {"type": "light", "node": bu}
	if not out.is_empty():
		return out
	var gp: Variant = _ground_at(pp + fwd * 0.78)
	if gp != null:
		return {"type": "ground", "pos": gp}
	return {}


## Objet à ramasser (touche E) : le plus proche devant soi
func find_pickable() -> Burnable:
	if held != null or human == null:
		return null
	var pp := human.global_position
	var fwd := _fwd()
	var best := REACH_PICK
	var out: Burnable = null
	for o in get_tree().get_nodes_in_group("burnables"):
		var bu := o as Burnable
		if not bu.can_pickup():
			continue
		var d := bu.global_position - pp
		if d.y > 0.9:
			continue
		d.y = 0.0
		var l := d.length()
		if l < best and (l < 0.6 or fwd.dot(d / maxf(l, 0.01)) > 0.3):
			best = l
			out = bu
	return out


func prompt() -> Array:
	if busy:
		return []
	var nm := held_label()
	match plan.get("type", ""):
		"bin":
			var bin: TrashBin = plan["node"]
			if not bin.is_open():
				return [["CLIC GAUCHE"], "Ouvrir et déposer " + nm]
			if bin.burning:
				return [["CLIC GAUCHE"], "Jeter %s dans le feu" % nm]
			return [["CLIC GAUCHE"], "Déposer %s et l'allumer" % nm]
		"fire":
			return [["CLIC GAUCHE"], "Jeter %s dans le feu" % nm]
		"light":
			return [["CLIC GAUCHE"], "Allumer " + Burnable.label_of((plan["node"] as Burnable).kind)]
		"ground":
			return [["CLIC GAUCHE"], "Faire un feu : poser %s et l'allumer" % nm]
	return [["CLIC DROIT"], "Briquet"]


# ------------------------------------------------------------------ actions
func use() -> void:
	if not equipped or busy or equip_t < 0.6 or human == null:
		return
	if _fresh < 0.45 and held == null:
		return   # il sort un nouveau journal de sa poche
	plan = _plan()
	if plan.is_empty():
		message.emit("Pas la place ici")
		return
	_ctx = plan.duplicate()
	var dv := Vector3.ZERO
	match plan["type"]:
		"bin", "fire", "light":
			var n: Node3D = plan["node"]
			dv = n.global_position - human.global_position
			_ctx["pos"] = n.global_position
		"ground":
			dv = (plan["pos"] as Vector3) - human.global_position
	dv.y = 0.0
	dv = dv.normalized() if dv.length() > 0.01 else _fwd()
	_ctx["dv"] = dv
	match plan["type"]:
		"ground":
			_ctx["top"] = (held.size.y if held != null else 0.07) * 0.9
		"light":
			_ctx["top"] = (plan["node"] as Burnable).size.y * 0.5
	lock_yaw = atan2(-dv.x, -dv.z)
	if plan["type"] == "bin":
		approach_pos = (plan["node"] as Node3D).global_position
		approach_d = 0.7
	_ph = _phases(plan)
	_pi = 0
	_pt = 0.0
	busy = true


func _phases(p: Dictionary) -> Array:
	var out: Array = []
	match p["type"]:
		"bin":
			var bin: TrashBin = p["node"]
			if not bin.is_open():
				out.append(["open", 0.8])
			out.append(["raise", 0.32])
			if bin.burning:
				out.append(["drop_hot", 0.75])
			else:
				out.append(["reach", 0.42])
				out.append(["drop", 0.6])
				out.append(["light", 0.9])
			out.append(["retreat", 0.45])
		"fire":
			out = [["raise", 0.3], ["toss", 0.7], ["retreat", 0.35]]
		"ground":
			out = [["crouch", 0.6], ["place", 0.55], ["light", 1.05], ["stand", 0.6]]
		"light":
			out = [["crouch", 0.55], ["light", 1.05], ["stand", 0.55]]
	return out


## Ramassage (appelé par le joueur avec E) : s'accroupit, saisit, se relève avec l'objet
func queue_pick(b: Burnable) -> void:
	if b == null or not is_instance_valid(b) or busy or held != null:
		return
	_queued_pick = b


func _start_pick(b: Burnable) -> void:
	_ctx = {"type": "pick", "node": b, "pos": b.global_position}
	var dv := b.global_position - human.global_position
	dv.y = 0.0
	dv = dv.normalized() if dv.length() > 0.01 else _fwd()
	_ctx["dv"] = dv
	_ctx["top"] = b.size.y * 0.5
	lock_yaw = atan2(-dv.x, -dv.z)
	b.reserved_by = self
	_ph = [["crouch", 0.5], ["grab", 0.4], ["stand", 0.55]]
	_pi = 0
	_pt = 0.0
	busy = true


## Poser l'objet porté devant soi (sans l'allumer)
func put_down() -> void:
	if held == null or busy:
		return
	var b := held
	held = null
	b.reparent(get_tree().current_scene, true)
	var fwd := _fwd()
	b.set_held(false)
	b.global_position = human.global_position + fwd * 0.55 + Vector3.UP * 0.5
	b.linear_velocity = fwd * 0.6
	AudioLib.play_at(self, "cardboard_land", b.global_position, -12.0, 4.0)


func _advance(delta: float) -> void:
	if _pi < 0 or _pi >= _ph.size():
		_finish()
		return
	var name: String = _ph[_pi][0]
	var dur: float = _ph[_pi][1]
	var t0 := _pt
	_pt += delta
	_events(name, t0, _pt)
	if _pt >= dur:
		_pt -= dur
		_phase_end(name)
		_pi += 1
		if _pi >= _ph.size():
			_finish()


func _at(t0: float, t1: float, x: float) -> bool:
	return t0 < x and t1 >= x


func _events(name: String, t0: float, t1: float) -> void:
	var bin: TrashBin = _ctx["node"] if _ctx.get("type", "") == "bin" else null
	match name:
		"open":
			if _at(t0, t1, 0.4) and bin != null:
				bin.set_lid(true)
		"drop":
			if _at(t0, t1, 0.2):
				_release_into_bin()
		"drop_hot":
			if _at(t0, t1, 0.4):
				_release_into_bin()
		"toss":
			if _at(t0, t1, 0.34):
				_release_into_fire()
		"place":
			if _at(t0, t1, 0.3):
				_place_on_ground()
		"grab":
			if _at(t0, t1, 0.22):
				_grab_item()
		"light":
			if _at(t0, t1, 0.18):
				_lighter_on = true
				AudioLib.play_at(self, "sfx:click", _lighter.global_position, -8.0, 3.0)
				AudioLib.play_at(self, "sfx:ignite", _lighter.global_position, -10.0, 3.0)
			if _at(t0, t1, 0.52):
				_ignite_target()
			if _at(t0, t1, 0.7):
				_lighter_on = false


func _phase_end(name: String) -> void:
	if name == "light":
		_lighter_on = false


func _finish() -> void:
	var was_pick: bool = _ctx.get("type", "") == "pick"
	var b: Burnable = _ctx.get("node") if was_pick else null
	if b != null and is_instance_valid(b) and b.reserved_by == self:
		b.reserved_by = null
	var consumed := _released
	_abort()
	if consumed:
		_fresh = 0.0


func _take_item() -> Burnable:
	var scene := get_tree().current_scene
	var b: Burnable
	if held != null and is_instance_valid(held):
		b = held
		held = null
		b.reparent(scene, true)
	else:
		b = Burnable.make("news")
		scene.add_child(b)
		var pl := human.palm("L")
		b.global_position = pl["pos"]
	if human.get_parent() is PhysicsBody3D:
		b.add_collision_exception_with(human.get_parent())
	_paper.visible = false
	_released = true
	return b


func _release_into_bin() -> void:
	var bin: TrashBin = _ctx["node"]
	var b := _take_item()
	_ctx["item"] = b
	AudioLib.play_at(self, "paper_rustle", b.global_position, -10.0, 3.0)
	if not is_instance_valid(bin):
		b.set_held(false)
		return
	var from := human.global_position
	var dest := bin.top_center() + Vector3(0, 0.0, 0) - (_ctx["dv"] as Vector3) * 0.02
	b.fly_to(dest, 0.2, func():
		if is_instance_valid(bin) and is_instance_valid(b):
			if not bin.deposit(b, from):
				b.set_held(false))


func _release_into_fire() -> void:
	var fire: FloorFire = _ctx["node"]
	var b := _take_item()
	_ctx["item"] = b
	AudioLib.play_at(self, "paper_rustle", b.global_position, -10.0, 3.0)
	if not is_instance_valid(fire):
		b.set_held(false)
		return
	var from := human.global_position
	b.fly_to(fire.hand_target() + Vector3(0, 0.1, 0), 0.26, func():
		if is_instance_valid(fire) and is_instance_valid(b):
			if not fire.feed_item(b, from):
				b.set_held(false))


func _place_on_ground() -> void:
	var gp: Vector3 = _ctx["pos"]
	var b := _take_item()
	_ctx["item"] = b
	b.set_held(false)
	b.global_position = gp + Vector3(0, b.size.y * 0.5 + 0.03, 0)
	b.rotation = Vector3(0, _rng.randf() * TAU, 0)
	b.linear_velocity = Vector3.ZERO
	b.angular_velocity = Vector3.ZERO
	AudioLib.play_at(self, "cardboard_land" if b.kind != "news" and b.kind != "paper" else "paper_rustle", gp, -12.0, 3.0)


func _grab_item() -> void:
	var b: Burnable = _ctx.get("node")
	if b == null or not is_instance_valid(b) or not b.can_pickup_for(self):
		return
	b.set_held(true)
	b.reparent(self, true)
	b.top_level = true
	held = b
	b.reserved_by = null
	_fresh = 1.0
	AudioLib.play_at(self, "paper_rustle" if b.kind in ["paper", "news"] else "cardboard_land", b.global_position, -10.0, 3.0)


func _ignite_target() -> void:
	var b: Burnable = _ctx.get("item") if _ctx.has("item") else _ctx.get("node")
	if _ctx.get("type", "") == "light":
		b = _ctx["node"]
	if b == null or not is_instance_valid(b):
		return
	b.ignite()
	var bin: TrashBin = _ctx["node"] if _ctx.get("type", "") == "bin" else null
	if bin != null and is_instance_valid(bin):
		bin.ignite()
		get_tree().call_group("crowd", "on_event", "player_fire", {"pos": b.global_position})
	elif _ctx.get("type", "") in ["ground", "light"]:
		get_tree().call_group("crowd", "on_event", "player_fire", {"pos": b.global_position})


# ------------------------------------------------------------------ pas de temps
func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func step(delta: float) -> void:
	var t_now := Time.get_ticks_msec() / 1000.0
	equip_t = move_toward(equip_t, 1.0 if equipped else 0.0, delta * 3.0)
	_fresh = move_toward(_fresh, 1.0, delta * 1.7)
	if equipped and human != null:
		_plan_scan -= delta
		if not busy and _plan_scan <= 0.0:
			_plan_scan = 0.1
			plan = _plan()
			near_pick = find_pickable()
		if not busy and _queued_pick != null:
			if is_instance_valid(_queued_pick) and _queued_pick.can_pickup() and equip_t > 0.6:
				_start_pick(_queued_pick)
				_queued_pick = null
			elif not is_instance_valid(_queued_pick) or equip_t > 0.9:
				_queued_pick = null
		if busy:
			_advance(delta)
	lit = _lighter_on or (_aim_input and equipped and not busy)
	var two := held != null and is_instance_valid(held) and held.kind in ["box", "plank"]
	var r_need := busy or _aim_input or two
	var l_need := busy or two or held != null or (_fresh > 0.4 and not _released)
	_rw = move_toward(_rw, 1.0 if (r_need and equipped) else 0.0, delta * 5.0)
	_lw = move_toward(_lw, 1.0 if (l_need and equipped) else 0.0, delta * 5.0)
	if human:
		_apply_posture(delta)
	if equip_t <= 0.0 and not equipped:
		_paper.visible = false
		_lighter.visible = false
	if _lighter.visible:
		Props.set_lighter_lit(_lighter, lit, t_now)


## Posture du corps selon la phase (accroupi / penché pour atteindre)
func _apply_posture(delta: float) -> void:
	var cr := 0.0
	var ln := 0.0
	if busy and _pi >= 0 and _pi < _ph.size():
		var name: String = _ph[_pi][0]
		var dur: float = _ph[_pi][1]
		var u := _ease(_pt / dur)
		match _ctx.get("type", ""):
			"bin":
				var opened: bool = _ph[0][0] == "open"
				match name:
					"open":
						ln = 0.12 * u
					"raise":
						ln = lerpf(0.12 if opened else 0.0, 0.22, u)
					"reach", "drop_hot":
						ln = lerpf(0.22, 0.5, u)
					"drop", "light":
						ln = 0.5
					"retreat":
						ln = lerpf(0.5, 0.0, u)
				if name in ["reach", "drop", "light"]:
					cr = 0.3 if not _ctx["node"].burning or name == "light" else 0.14
				elif name == "retreat":
					cr = lerpf(0.3, 0.0, u)
			"fire":
				match name:
					"raise":
						ln = 0.2 * u
					"toss":
						ln = 0.28
						cr = 0.2
					"retreat":
						ln = lerpf(0.28, 0.0, u)
						cr = lerpf(0.2, 0.0, u)
			_:
				match name:
					"crouch":
						cr = 0.8 * u
						ln = 0.18 * u
					"place", "light", "grab":
						cr = 0.8
						ln = 0.18
					"stand":
						cr = lerpf(0.8, 0.0, u)
						ln = lerpf(0.18, 0.0, u)
	if delta > 0.0:
		_crouch = move_toward(_crouch, cr, delta * 5.0)
		_lean = move_toward(_lean, ln, delta * 3.0)
	else:
		_crouch = cr
		_lean = ln
	if busy or _crouch > 0.001 or _lean > 0.001:
		human.crouch = _crouch
		human.lean_extra = _lean
		_post_on = true
	elif _post_on:
		human.crouch = 0.0
		human.lean_extra = 0.0
		_post_on = false


# ------------------------------------------------------------------ mains
func _hd(pos: Vector3, f: Vector3, p: Vector3, curl := 0.9, w := 1.0) -> Dictionary:
	return {"pos": pos, "f": f.normalized(), "p": p.normalized(), "curl": curl, "w": w}


func _bl(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	k = clampf(k, 0.0, 1.0)
	return {
		"pos": (a["pos"] as Vector3).lerp(b["pos"], k),
		"f": Fx.vslerp(a["f"], b["f"], k).normalized(),
		"p": Fx.vslerp(a["p"], b["p"], k).normalized(),
		"curl": lerpf(a["curl"], b["curl"], k),
		"w": 1.0,
	}


func _open_hand(a: Dictionary, k: float) -> Dictionary:
	return _bl(a, _hd(a["pos"], a["f"], a["p"], 0.12), k)


func _hand_targets() -> Array:
	if equip_t <= 0.0 or human == null:
		return [null, null]
	var yawb := Basis(Vector3.UP, human.rotation.y)
	var fwd: Vector3 = yawb * Vector3(0, 0, -1)
	var rgt: Vector3 = yawb * Vector3(1, 0, 0)
	var up := Vector3.UP
	var s := human.arm_length() / 0.58
	var shR := human.shoulder_world("R")
	var shL := human.shoulder_world("L")
	var two := held != null and is_instance_valid(held) and held.kind in ["box", "plank"]
	var plank := two and held.kind == "plank"
	var news := held == null and _fresh > 0.4 and not _released
	var hw := (0.27 if plank else 0.2) + 0.02
	var palm_dir := -up if plank else rgt
	# --- poses de repos
	var rest_r := _hd(shR + fwd * 0.2 * s - up * 0.42 * s - rgt * 0.04 * s, fwd * 0.7 - up * 0.5, -rgt, 0.7)
	var rest_l := _hd(shL + fwd * 0.27 * s - up * 0.33 * s + rgt * 0.05 * s, fwd, rgt, 0.9)
	var c2 := (shR + shL) * 0.5 + fwd * 0.36 * s - up * 0.4 * s
	var carry_r := _hd(c2 + rgt * hw, fwd, -palm_dir if not plank else palm_dir, 0.5)
	var carry_l := _hd(c2 - rgt * hw, fwd, palm_dir, 0.5)
	var R: Dictionary = carry_r if two else rest_r
	var L: Dictionary = carry_l if two else rest_l
	var want_lighter := false
	if _aim_input and not busy and not two:
		R = _hd(shR + fwd * 0.3 * s - up * 0.04 * s - rgt * 0.02 * s, fwd * 0.8 + up * 0.25, -rgt, 0.85)
		want_lighter = true
	var type: String = _ctx.get("type", "") if busy else ""
	if busy and _pi >= 0 and _pi < _ph.size():
		var name: String = _ph[_pi][0]
		var dur: float = _ph[_pi][1]
		var u := _ease(_pt / dur)
		var dv: Vector3 = _ctx["dv"]
		var tpos: Vector3 = _ctx["pos"]
		var rest_rr: Dictionary = carry_r if two else rest_r
		var rest_ll: Dictionary = carry_l if two else rest_l
		match type:
			"bin":
				var bin: TrashBin = _ctx["node"]
				var c := bin.top_center()
				var ov := c - dv * 0.1 * s + up * (0.27 if not two else 0.32) * s
				var over_l := _hd(ov, dv * 0.5 - up * 0.5 + fwd * 0.2, rgt, 0.85)
				var over_2l := _hd(ov - rgt * hw, dv, palm_dir, 0.5)
				var over_2r := _hd(ov + rgt * hw, dv, -palm_dir if not plank else palm_dir, 0.5)
				var side_r := _hd(c - dv * 0.18 * s + rgt * 0.2 * s + up * 0.22 * s, dv * 0.9 - up * 0.1, -rgt, 0.85)
				var inside_r := _hd(c + up * (-0.13 if not bin.burning else 0.05) * s, dv * 0.92 - up * 0.2, -rgt, 0.85)
				var edge := c - dv * 0.37 + up * 0.04
				var lid_r := _hd(edge, dv, up, 0.4)
				var lid_up := _hd(edge + up * 0.3 * s + dv * 0.06, dv, up, 0.4)
				var left_over: Dictionary = over_2l if two else over_l
				match name:
					"open":
						R = _bl(_bl(rest_rr, lid_r, _ease(_pt / 0.4)), lid_up, _ease((_pt - 0.4) / 0.35))
						if _pt > 0.55:
							R = _bl(R, rest_rr, _ease((_pt - 0.55) / 0.25))
					"raise":
						L = _bl(rest_ll, left_over, u * 0.7)
						R = _bl(rest_rr, over_2r if two else side_r, u * 0.7)
					"reach":
						L = _bl(rest_ll, left_over, 0.7 + 0.3 * u)
						R = _bl(rest_rr, over_2r if two else side_r, 0.7 + 0.3 * u)
						want_lighter = not two
					"drop_hot":
						var uu := _ease(_pt / 0.4)
						L = _bl(rest_ll, left_over, uu)
						if two:
							R = _bl(rest_rr, over_2r, uu)
						if _pt > 0.4:
							L = _bl(_open_hand(left_over, _ease((_pt - 0.4) / 0.12)), rest_ll, _ease((_pt - 0.5) / 0.25))
							if two:
								R = _bl(_open_hand(over_2r, _ease((_pt - 0.4) / 0.12)), rest_rr, _ease((_pt - 0.5) / 0.25))
					"drop":
						L = _bl(_open_hand(left_over, _ease((_pt - 0.12) / 0.14)), rest_ll, _ease((_pt - 0.3) / 0.28))
						if two:
							R = _bl(_open_hand(over_2r, _ease((_pt - 0.12) / 0.14)), rest_rr, _ease((_pt - 0.3) / 0.28))
						else:
							R = _bl(side_r, inside_r, _ease((_pt - 0.12) / 0.4))
							want_lighter = true
					"light":
						var wob := Vector3(sin(_pt * 17.0) * 0.004, sin(_pt * 11.0) * 0.004, 0)
						R = _hd(inside_r["pos"] + wob, inside_r["f"], inside_r["p"], 0.85)
						L = rest_ll
						want_lighter = true
					"retreat":
						R = _bl(side_r if bin.burning else inside_r, rest_rr, u)
						want_lighter = u < 0.5 and not two and not bin.burning
			"fire":
				var tp := tpos - dv * 0.6 * s + up * 0.68 * s
				var f_l := _hd(tp, dv * 0.9 - up * 0.3, rgt, 0.85)
				var f_2l := _hd(tp - rgt * hw, dv, palm_dir, 0.5)
				var f_2r := _hd(tp + rgt * hw, dv, -palm_dir if not plank else palm_dir, 0.5)
				var f_left: Dictionary = f_2l if two else f_l
				match name:
					"raise":
						L = _bl(rest_l if not two else carry_l, f_left, u)
						if two:
							R = _bl(carry_r, f_2r, u)
					"toss":
						var ok := _ease((_pt - 0.22) / 0.14)
						L = _bl(_open_hand(f_left, ok), rest_l if not two else carry_l, _ease((_pt - 0.45) / 0.25))
						if two:
							R = _bl(_open_hand(f_2r, ok), carry_r, _ease((_pt - 0.45) / 0.25))
					"retreat":
						L = rest_l if not two else carry_l
			"ground", "light", "pick":
				var g := tpos
				var top := float(_ctx.get("top", 0.1))
				var item_at := g + up * top
				var hov_l := _hd(g + up * (top + 0.28) * s - dv * 0.05, dv * 0.6 - up * 0.7, rgt, 0.85)
				var low_l := _hd(g + up * (top + 0.07) * s - rgt * 0.02, dv * 0.5 - up * 0.8, rgt, 0.85)
				var hov_2l := _hd(g + up * (top + 0.3) * s - rgt * hw, dv, palm_dir, 0.5)
				var hov_2r := _hd(g + up * (top + 0.3) * s + rgt * hw, dv, -palm_dir if not plank else palm_dir, 0.5)
				var low_2l := _hd(g + up * (top + 0.04) * s - rgt * hw, dv, palm_dir, 0.5)
				var low_2r := _hd(g + up * (top + 0.04) * s + rgt * hw, dv, -palm_dir if not plank else palm_dir, 0.5)
				var hov_r := _hd(g + up * (top + 0.2) * s + rgt * 0.22 * s - dv * 0.05, dv * 0.9 - up * 0.3, -rgt, 0.85)
				var at_r := _hd(item_at - up * 0.07 + rgt * 0.045 - dv * 0.03, dv * 0.9 - up * 0.25, -rgt, 0.85)
				var up_r := _hd(g + up * 0.28 * s, dv * 0.5 - up * 0.8, -up * 0.2 - rgt * 0.8, 0.4)
				var grab_r := _hd(g + up * 0.06 * s, dv * 0.5 - up * 0.8, -up * 0.2 - rgt * 0.8, 0.55)
				var knee_l := _hd(shL + fwd * 0.12 * s - up * 0.55 * s, fwd * 0.4 - up * 0.8, rgt, 0.6)
				match name:
					"crouch":
						if type == "pick":
							R = _bl(rest_r, up_r, u)
						elif type == "ground":
							if two:
								L = _bl(carry_l, hov_2l, u)
								R = _bl(carry_r, hov_2r, u)
							else:
								L = _bl(rest_l, hov_l, u) if news or held != null else _bl(rest_l, knee_l, u)
								R = _bl(rest_r, hov_r, u)
								want_lighter = true
						else:
							L = _bl(rest_l, knee_l, u)
							R = _bl(rest_r, hov_r, u)
							want_lighter = true
					"grab":
						R = _bl(up_r, grab_r, _ease(_pt / 0.22))
						R["curl"] = lerpf(0.4, 0.95, _ease((_pt - 0.12) / 0.15))
					"place":
						if two:
							var k := _ease(_pt / 0.28)
							L = _bl(_open_hand(hov_2l, 0.0), low_2l, k)
							R = _bl(hov_2r, low_2r, k)
							if _pt > 0.3:
								var o := _ease((_pt - 0.3) / 0.25)
								L = _bl(_open_hand(low_2l, 1.0), rest_l, o)
								R = _bl(_open_hand(low_2r, 1.0), rest_r, o)
						else:
							var pl := _bl(hov_l, low_l, _ease(_pt / 0.3))
							if _pt < 0.3:
								L = pl
							else:
								L = _bl(_open_hand(low_l, 1.0), knee_l, _ease((_pt - 0.4) / 0.15))
							R = hov_r
							want_lighter = true
					"light":
						R = _bl(hov_r, at_r, _ease(_pt / 0.4))
						L = knee_l
						want_lighter = true
					"stand":
						var back_r: Dictionary = rest_rr
						R = _bl(grab_r if type == "pick" else at_r, back_r, u)
						L = _bl(knee_l, rest_ll, u)
						want_lighter = u < 0.4 and type != "pick"
	_place_props(want_lighter, fwd, up, two)
	R["w"] = _ease(equip_t) * _rw
	L["w"] = _ease(equip_t) * _lw
	return [R if _rw > 0.001 else null, L if _lw > 0.001 else null]


func _place_props(want_lighter: bool, fwd: Vector3, up: Vector3, two: bool) -> void:
	var vis := equip_t > 0.15
	_lighter.visible = vis and want_lighter
	if _lighter.visible:
		var pr := human.palm("R")
		_lighter.global_position = (pr["pos"] as Vector3) + (pr["p"] as Vector3) * 0.04
		_lighter.global_basis = Basis(Quaternion(Vector3.UP, pr["thumb"] as Vector3))
	_paper.visible = vis and held == null and _fresh > 0.4 and not _released
	if _paper.visible:
		var pl := human.palm("L")
		var th: Vector3 = pl["thumb"]
		var g: Vector3 = (pl["pos"] as Vector3) + (pl["p"] as Vector3) * 0.03
		_paper.global_transform = Transform3D(Props.basis_up(th, fwd), g + th * 0.04)
	if held != null and is_instance_valid(held):
		held.visible = vis
		if two:
			var pr2 := human.palm("R")
			var pl2 := human.palm("L")
			var mid := ((pr2["pos"] as Vector3) + (pl2["pos"] as Vector3)) * 0.5 + up * 0.03
			held.global_transform = Transform3D(Basis(Vector3.UP, human.rotation.y), mid)
		else:
			var pl3 := human.palm("L")
			var th2: Vector3 = pl3["thumb"]
			held.global_transform = Transform3D(Basis(Vector3.UP, human.rotation.y), (pl3["pos"] as Vector3) + (pl3["p"] as Vector3) * 0.05 + th2 * 0.03)
