class_name Police
extends Node
## Coordination des forces de l'ordre. Un cordon de CRS tient le bout de la rue dès le début ; la tension
## décide du reste : voiture de patrouille, fourgons, grenadiers, LBD, charges, interpellations.
## Les renforts arrivent par la route et se garent (la baseplate reste nue : rien d'autre n'est construit).

const STREET_X := 54.0
const ROAD_Z := -7.4
const LANE_IN := -9.15           # voie d'arrivée (on roule vers -X)
const VARIANTS := ["male_a", "male_b", "male_c", "male_d", "male_e", "female_a", "female_b", "female_c", "female_d"]
const MAX_COPS := 32

var crowd: Crowd
var player: Player
var tension: Tension
var cops: Array[Cop] = []
var vehicles: Array[PoliceVehicle] = []
var mode := "hold"                # hold | advance | push | retreat
var line_c := Vector3(STREET_X, 0.0, ROAD_Z)
var line_dir := Vector3(-1, 0, 0)
var arrested_count := 0
var boss: Cop
var stage := 0

var _rng := RandomNumberGenerator.new()
var _next_idx := 200
var _t := 0.0
var _queue: Array = []            # [temps, Callable]
var _adv_cd := 6.0
var _adv_goal := STREET_X
var _gas_cd := 18.0
var _charge_cd := 35.0
var _lbd_cd := 12.0
var _arrest_cd := 20.0
var _mega_cd := 10.0
var _som := 0
var _park_n := 0
var _alert_t := 0.0
var _player_seen_t := 0.0
var _calm_t := 0.0
var _car_alert_t := -99.0
var _veh_cd := 6.0


func setup(c: Crowd, p: Player, t: Tension) -> void:
	crowd = c
	crowd.police = self
	player = p
	tension = t


func nearest_cop(from: Vector3, r: float) -> Cop:
	var best: Cop = null
	var bd := r
	for c in cops:
		if not is_instance_valid(c) or c.state in ["down"]:
			continue
		var d := c.global_position.distance_to(from)
		if d < bd:
			bd = d
			best = c
	return best


func _ready() -> void:
	add_to_group("police")
	add_to_group("crowd")
	_rng.seed = 2026
	if tension:
		tension.stage_up.connect(_on_stage_up)
		tension.stage_down.connect(_on_stage_down)
	_spawn_cordon()


# =================================================================== création
func _spawn_cop(loadout: String, pos: Vector3, yaw: float, role := "line") -> Cop:
	var c := Cop.new()
	c.police = self
	c.crowd = crowd
	c.idx = _next_idx
	_next_idx += 1
	c.variant = VARIANTS[_rng.randi() % 9] if _rng.randf() < 0.82 else VARIANTS[5 + _rng.randi() % 4]
	c.female = c.variant.begins_with("female")
	c.voice = "f1" if c.female else ("m1" if _rng.randf() < 0.5 else "m2")
	c.vpitch = _rng.randf_range(0.92, 1.08)
	c.loadout = loadout
	c.role = role
	c.bold = _rng.randf_range(0.4, 0.95)
	c.position = pos          # avant add_child : un corps cinématique qui « se téléporte » transmet une vitesse énorme
	c.rotation.y = yaw
	add_child(c)
	c.yaw = yaw
	c.line_dir = line_dir
	c.line_slot = pos
	cops.append(c)
	crowd.register_cop(c)
	return c


func _spawn_cordon() -> void:
	var yaw := atan2(-line_dir.x, -line_dir.z)
	for i in 6:
		var z := ROAD_Z + (i - 2.5) * 1.1
		_spawn_cop("shield", Vector3(STREET_X, 0, z), yaw, "line")
	boss = _spawn_cop("boss", Vector3(STREET_X + 2.4, 0, ROAD_Z), yaw, "boss")
	_spawn_cop("grenadier", Vector3(STREET_X + 2.2, 0, ROAD_Z - 2.2), yaw, "support")
	_spawn_cop("lbd", Vector3(STREET_X + 2.2, 0, ROAD_Z + 2.2), yaw, "support")
	# véhicules déjà là, à l'arrêt, gyrophares éteints
	var van := _make_vehicle("truck", Vector3(STREET_X + 8.0, 0, -8.7), PI / 2.0)
	van.state = "parked"
	# la voiture de patrouille est garée de travers devant la ligne : à portée des manifestants (et de leur colère)
	var car := _make_vehicle("car", Vector3(STREET_X - 4.6, 0, -8.7), PI / 2.0 + 0.5)
	car.state = "parked"
	_layout()


func _make_vehicle(kind: String, pos: Vector3, yaw: float) -> PoliceVehicle:
	var v := PoliceVehicle.new()
	v.crowd = crowd
	v.position = pos
	v.rotation.y = yaw
	add_child(v)
	v.build(kind)
	vehicles.append(v)
	crowd.add_obstacle(v, v.half, Vector2.ZERO, false, true)
	crowd.nav_dirty()
	return v


## Renfort : un véhicule arrive par la route (sirène), se gare, l'équipage descend et rejoint le dispositif.
func _send_vehicle(kind: String, crew: Array, stage_tag: int) -> void:
	if cops.size() >= MAX_COPS:
		return
	var lane_z := LANE_IN if (_park_n % 2 == 0) else -5.65
	_park_n += 1
	var start := Vector3(118.0, 0, lane_z)
	var v := PoliceVehicle.new()
	v.crowd = crowd
	v.position = start
	v.rotation.y = PI / 2.0
	add_child(v)
	v.build(kind)
	vehicles.append(v)
	v.urgent = stage_tag >= 3
	v.set_lights(true, true)
	var px := maxf(line_c.x + 9.0 + 3.5 * float(_park_n), STREET_X + 3.0) if kind == "truck" else maxf(line_c.x + 7.0 + 2.0 * float(_park_n), STREET_X)
	px = minf(px, 100.0)
	var park := Vector3(px, 0, lane_z + (1.0 if lane_z > -7.0 else -0.4))
	var path: Array[Vector3] = [Vector3(px + 14.0, 0, lane_z), park]
	v.drive(path, PI / 2.0 + (0.0 if kind == "truck" else 0.12), 13.0 if kind == "car" else 10.5)
	v.parked.connect(func(): _on_parked(v, crew))


func _on_parked(v: PoliceVehicle, crew: Array) -> void:
	if not is_instance_valid(v):
		return
	v.set_lights(true, false)
	if v.kind == "truck":
		v.open_doors(["BL", "BR", "Lf"], true)
	else:
		v.open_doors(["Lf", "Rf"], true)
	var pts := v.exit_points()
	var yaw := atan2(-line_dir.x, -line_dir.z)
	for i in crew.size():
		var cdef: Array = crew[i]
		var delay := 0.9 + 0.5 * i
		_later(delay, func():
			if not is_instance_valid(v) or cops.size() >= MAX_COPS:
				return
			var c := _spawn_cop(cdef[0], pts[i % pts.size()], yaw, cdef[1])
			c.state = "exit"
			c.alert = alert_level()
			_layout())


func _later(dt: float, cb: Callable) -> void:
	_queue.append([_t + dt, cb])


func alert_level() -> float:
	return 1.0 if stage >= 2 else (0.6 if stage == 1 else 0.0)


# =================================================================== formation
## Distribue les places de la ligne aux policiers de ligne et de soutien
func _layout() -> void:
	var line: Array[Cop] = []
	var support: Array[Cop] = []
	for c in cops:
		if not is_instance_valid(c):
			continue
		if c.role in ["line", "patrol"]:
			line.append(c)
		elif c.role in ["support", "boss"]:
			support.append(c)
	var right := line_dir.cross(Vector3.UP).normalized()
	var n := line.size()
	var per := clampi(n, 4, 9)
	for i in n:
		var rank := i / per
		var col := i % per
		var in_rank := mini(per, n - rank * per)
		var off := (col - (in_rank - 1) * 0.5) * 1.12
		var c: Cop = line[i]
		c.line_dir = line_dir
		c.line_slot = line_c + right * off - line_dir * (rank * 1.2)
	var rows := 0
	for j in support.size():
		var c2: Cop = support[j]
		var off2 := (j - (support.size() - 1) * 0.5) * 2.3
		c2.line_dir = line_dir
		c2.line_slot = line_c - line_dir * 2.6 + right * off2


func _on_stage_up(s: int) -> void:
	stage = s
	_alert_all(alert_level())
	get_tree().call_group("crowd", "on_event", "police_stage", {"stage": s, "pos": line_c})
	var announce := func(t: String): get_tree().call_group("hud", "announce", t)
	match s:
		1:
			_send_vehicle("car", [["shield", "patrol"], ["shield", "patrol"]], 1)
			_say_mega(0)
		2:
			mode = "advance"
			_send_vehicle("truck", [["shield", "line"], ["shield", "line"], ["lbd", "support"], ["shield", "line"], ["grenadier", "support"]], 2)
			_say_mega(1)
			_set_all_lights(true)
		3:
			mode = "push"
			_send_vehicle("truck", [["shield", "line"], ["shield", "line"], ["arrester", "team"], ["arrester", "team"], ["shield", "line"], ["lbd", "support"]], 3)
			_later(6.0, func(): _send_vehicle("car", [["spray", "team"], ["arrester", "team"]], 3))
			_say_mega(2)
		4:
			mode = "push"
			_send_vehicle("truck", [["shield", "line"], ["shield", "line"], ["shield", "line"], ["grenadier", "support"], ["lbd", "support"]], 4)
			_later(5.0, func(): _send_vehicle("car", [["arrester", "team"], ["arrester", "team"]], 4))
			_say_mega(3)
			_gas_cd = minf(_gas_cd, 4.0)
			_charge_cd = minf(_charge_cd, 8.0)


func _on_stage_down(s: int) -> void:
	stage = s
	_alert_all(alert_level())
	if s <= 1:
		mode = "hold"
		_adv_goal = line_c.x
	elif s == 2:
		mode = "advance"


func _alert_all(a: float) -> void:
	for c in cops:
		if is_instance_valid(c):
			c.alert = a


func _set_all_lights(on: bool) -> void:
	for v in vehicles:
		if is_instance_valid(v):
			v.set_lights(on, on and v.siren_on)   # un renfort encore en route garde sa sirène


func _say_mega(i: int) -> void:
	if boss != null and is_instance_valid(boss) and not boss.busy():
		boss.speak_mega(clampi(i, 0, 5))


# =================================================================== événements reçus
func on_event(type: String, d: Dictionary) -> void:
	match type:
		"burst":
			_react_burst(d.get("pos", Vector3.ZERO))
		"mortar_fire":
			pass
		"mortar_aim":
			pass
		"petard_boom":
			_react_petard(d)
		"car_vandal":
			_react_car_vandal(d)
		"car_burn":
			_react_car_burn(d)


## Une voiture de police est attaquée : les policiers les plus proches foncent sur les agresseurs
func _react_car_vandal(d: Dictionary) -> void:
	var car: PoliceVehicle = d.get("car")
	if car == null or not is_instance_valid(car) or stage < 1:
		return
	var now := _t
	if now - _car_alert_t < 5.0:
		return
	_car_alert_t = now
	var tgt: Node3D = null
	if player != null and player.global_position.distance_to(car.global_position) < 7.0:
		tgt = player
		player.wanted = minf(player.wanted + 0.4, 1.0)
	else:
		# le manifestant le plus proche de la voiture
		var bd := 14.0
		for n in crowd.npcs:
			if n.state in ["carattack"] and n.data.get("car") == car:
				var dd := n.global_position.distance_to(car.global_position)
				if dd < bd:
					bd = dd
					tgt = n
		if tgt == null:
			tgt = _nearest_civilian(car.global_position, 12.0)
	if tgt == null:
		return
	var cand := _free_cops(["shield", "arrester", "spray"], ["team", "line", "patrol"])
	cand.sort_custom(func(a: Cop, b: Cop): return a.global_position.distance_to(car.global_position) < b.global_position.distance_to(car.global_position))
	var k := 0
	for c in cand:
		if k >= 2 or c.global_position.distance_to(car.global_position) > 40.0:
			break
		c.charge(tgt, 6.0)
		k += 1
	_assign_arrest(tgt, 2 if tgt is Player else 1)


## Voiture en feu : réaction dure (gaz, charge) et le joueur est recherché s'il y est pour quelque chose
func _react_car_burn(d: Dictionary) -> void:
	_gas_cd = minf(_gas_cd, 2.5)
	_charge_cd = minf(_charge_cd, 4.0)
	_say_mega(3)
	if d.get("player", false) and player != null:
		player.wanted = 1.0
	for c in cops:
		if is_instance_valid(c):
			c.alert = 1.0


## Un pétard explose : les policiers les plus proches sursautent, les autres se tournent vers le bruit.
## Si le joueur l'a lancé près du cordon, on le remarque.
func _react_petard(d: Dictionary) -> void:
	var p: Vector3 = d["pos"]
	var big: bool = int(d.get("size", 1)) >= 2
	var reach := 34.0 if big else 15.0
	var closest := INF
	for c in cops:
		if not is_instance_valid(c) or c.state in ["down", "arrest", "escort"]:
			continue
		var dist := c.global_position.distance_to(p)
		if dist > reach:
			continue
		closest = minf(closest, dist)
		c.alert = maxf(c.alert, 0.35 if not big else 0.55)
		c.look(p + Vector3.UP, 1.0)
		if dist < (6.0 if big else 2.5) and not c.busy():
			c.stagger(0.9 if big else 0.45, (c.global_position - p).normalized())
	if closest < reach and d.get("player", false) and player != null:
		player.wanted = minf(player.wanted + (0.3 if big else 0.1), 1.0)


## Un obus éclate près des policiers : certains reculent, d'autres foncent, d'autres se couvrent
func _react_burst(p: Vector3) -> void:
	for c in cops:
		if not is_instance_valid(c) or c.state in ["down", "arrest", "escort"]:
			continue
		var d := c.global_position.distance_to(p)
		if d > 26.0:
			continue
		var r := _rng.randf()
		var away := (c.global_position - p)
		away.y = 0.0
		away = away.normalized() if away.length() > 0.1 else -line_dir
		if d < 9.0 and r < 0.3:
			c.knock_down(2.5)
		elif r < 0.55:
			c.retreat_to(c.global_position + away * _rng.randf_range(8.0, 14.0), true)
		elif r < 0.8 and player != null and stage >= 1:
			c.charge(player if _rng.randf() < 0.5 else _nearest_civilian(c.global_position, 40.0), 6.0)
		else:
			c.stagger(1.0)
	if stage < 4:
		tension.add(0.03, "obus près de la police")


func on_cop_hit(cop: Cop, kind: String, by: Node3D = null) -> void:
	if tension:
		tension.add(0.02, "policier touché")
	# riposte : on interpelle le lanceur (le joueur s'il est le plus proche)
	if by != null and is_instance_valid(by):
		_assign_arrest(by, 2)
	elif player != null and player.global_position.distance_to(cop.global_position) < 22.0 and kind == "stone":
		player.wanted = minf(player.wanted + 0.35, 1.0)


func on_cop_kicked(cop: Cop) -> void:
	if player:
		player.wanted = minf(player.wanted + 0.5, 1.0)
	if tension:
		tension.add(0.03, "coup de pied à un policier")
	if stage >= 1:
		_assign_arrest(player, 2)


func nearest_van(pos: Vector3) -> PoliceVehicle:
	var best: PoliceVehicle = null
	var bd := INF
	for v in vehicles:
		if not is_instance_valid(v) or not v.is_parked():
			continue
		var d := v.global_position.distance_to(pos) - (30.0 if v.kind == "truck" else 0.0)
		if d < bd:
			bd = d
			best = v
	return best


# =================================================================== cibles
func _nearest_civilian(from: Vector3, r: float) -> Node3D:
	var best: Node3D = null
	var bd := r
	for n in crowd.npcs:
		if n.state in ["arrested", "boarded"]:
			continue
		var d := n.global_position.distance_to(from)
		if d < bd:
			bd = d
			best = n
	return best


func _front_civilians(r: float) -> Array[Npc]:
	var out: Array[Npc] = []
	for n in crowd.npcs:
		if n.state in ["arrested", "boarded"]:
			continue
		if n.global_position.distance_to(line_c) < r:
			out.append(n)
	out.sort_custom(func(a: Npc, b: Npc): return a.global_position.distance_to(line_c) < b.global_position.distance_to(line_c))
	return out


func _free_cops(loadouts: Array, roles: Array = []) -> Array[Cop]:
	var out: Array[Cop] = []
	for c in cops:
		if not is_instance_valid(c) or c.busy() or c.state in ["exit", "mega"] or c.stun_t > 0.0:
			continue
		if c.loadout in loadouts and (roles.is_empty() or c.role in roles):
			out.append(c)
	return out


func _assign_arrest(t: Node3D, n_cops: int) -> void:
	if t == null or not is_instance_valid(t):
		return
	if t is Player and (player.arrest_phase != "" or player.invuln_t > 0.0):
		return
	if t is Npc and (t as Npc).state in ["arrested", "boarded"]:
		return
	# déjà pris en charge ?
	for c in cops:
		if is_instance_valid(c) and c.state == "arrest" and c.arrestee == t:
			return
	var cand := _free_cops(["arrester", "shield", "spray"], ["team", "line", "patrol"])
	cand.sort_custom(func(a: Cop, b: Cop): return a.global_position.distance_to(t.global_position) < b.global_position.distance_to(t.global_position))
	var k := 0
	for c in cand:
		if k >= n_cops:
			break
		if c.global_position.distance_to(t.global_position) > 45.0:
			break
		c.arrest(t)
		k += 1


# =================================================================== boucle
func _physics_process(delta: float) -> void:
	_t += delta
	_run_queue()
	cops = cops.filter(func(c): return is_instance_valid(c))
	vehicles = vehicles.filter(func(v): return is_instance_valid(v))
	if tension:
		tension.police_active = stage >= 1
	_update_line(delta)
	_follow_vehicles(delta)
	# de retour au calme, la ligne se replie vers le cordon d'origine
	if stage <= 1 and mode == "hold" and line_c.x < STREET_X - 0.5 and tension != null and tension.value < 0.12:
		_calm_t += delta
		if _calm_t > 25.0:
			mode = "retreat"
			get_tree().call_group("crowd", "on_event", "police_retreat", {"pos": line_c})
	else:
		_calm_t = 0.0
	if stage >= 1:
		_mega_cd -= delta
		if _mega_cd <= 0.0:
			_mega_cd = _rng.randf_range(34.0, 55.0)
			_som = (_som + 1) % 6
			_say_mega(_som if stage < 3 else 3 + (_som % 3))
	if stage >= 2:
		_gas_cd -= delta
		if _gas_cd <= 0.0:
			_gas_cd = _rng.randf_range(18.0, 32.0) / (1.0 + 0.35 * float(stage - 2))
			_do_gas()
	if stage >= 3:
		_charge_cd -= delta
		if _charge_cd <= 0.0:
			_charge_cd = _rng.randf_range(26.0, 48.0) / (1.0 + 0.3 * float(stage - 3))
			_do_charge()
		_lbd_cd -= delta
		if _lbd_cd <= 0.0:
			_lbd_cd = _rng.randf_range(7.0, 15.0) / (1.0 + 0.4 * float(stage - 3))
			_do_lbd()
		_arrest_cd -= delta
		if _arrest_cd <= 0.0:
			_arrest_cd = _rng.randf_range(14.0, 28.0) / (1.0 + 0.4 * float(stage - 3))
			_do_arrest()
	elif stage == 2:
		_arrest_cd -= delta
		if _arrest_cd <= 0.0:
			_arrest_cd = _rng.randf_range(30.0, 50.0)
			_do_arrest(true)
	# le joueur visé : s'il est recherché, une équipe vient le chercher
	if player != null and stage >= 2 and player.wanted > 0.55 and player.arrest_phase == "":
		_player_seen_t += delta
		if _player_seen_t > 6.0:
			_player_seen_t = 0.0
			_assign_arrest(player, 2)
	if player != null:
		player.wanted = maxf(player.wanted - delta * 0.012, 0.0)


func _run_queue() -> void:
	var i := 0
	while i < _queue.size():
		if _queue[i][0] <= _t:
			var cb: Callable = _queue[i][1]
			_queue.remove_at(i)
			cb.call()
		else:
			i += 1


func _update_line(delta: float) -> void:
	# avance par bonds : on avance de quelques mètres, on s'arrête, on regarde, on repart
	match mode:
		"advance":
			_adv_cd -= delta
			if _adv_cd <= 0.0 and absf(line_c.x - _adv_goal) < 0.3:
				_adv_cd = _rng.randf_range(7.0, 13.0)
				_adv_goal = maxf(line_c.x - _rng.randf_range(3.0, 5.5), _advance_limit())
			_move_line(delta, 0.9)
		"push":
			_adv_cd -= delta
			if _adv_cd <= 0.0 and absf(line_c.x - _adv_goal) < 0.3:
				_adv_cd = _rng.randf_range(3.5, 7.0)
				_adv_goal = maxf(line_c.x - _rng.randf_range(2.5, 4.5), _advance_limit())
			_move_line(delta, 1.25)
		"retreat":
			_adv_goal = minf(line_c.x + 6.0, STREET_X)
			_move_line(delta, 1.5)
			if line_c.x >= STREET_X - 0.1:
				mode = "hold"
	# la ligne se resserre autour du centre de la foule en s'approchant
	var spread := clampf((STREET_X - line_c.x) / 32.0, 0.0, 1.0)
	line_c.z = lerpf(ROAD_Z, -1.5, spread)
	_alert_t -= delta
	if _alert_t <= 0.0:
		_alert_t = 0.5
		_layout()


## Les véhicules suivent le dispositif quand il avance (ils restent à portée des équipes... et des manifestants)
func _follow_vehicles(delta: float) -> void:
	_veh_cd -= delta
	if _veh_cd > 0.0 or stage < 2 or mode == "hold":
		return
	_veh_cd = 4.0
	var i := 0
	for v in vehicles:
		if not is_instance_valid(v) or not v.is_parked() or v.burning:
			continue
		i += 1
		var want_x := line_c.x + 12.0 + 5.0 * float(i)
		if v.global_position.x > want_x + 9.0:
			v.relocate(Vector3(want_x, 0.0, v.global_position.z))
			break


func _advance_limit() -> float:
	return 30.0 if stage <= 2 else (18.0 if stage == 3 else 6.0)


func _move_line(delta: float, speed: float) -> void:
	var dx := _adv_goal - line_c.x
	if absf(dx) > 0.05:
		line_c.x += signf(dx) * minf(absf(dx), speed * delta)
		for c in cops:
			if is_instance_valid(c) and c.state == "hold" and c.role in ["line", "patrol", "support", "boss"]:
				c.state = "advance"
	else:
		for c in cops:
			if is_instance_valid(c) and c.state == "advance":
				c.state = "hold"


# =================================================================== actions de la police
func _do_gas() -> void:
	var gren := _free_cops(["grenadier"])
	if gren.is_empty():
		return
	var g: Cop = gren[_rng.randi() % gren.size()]
	var tp := Vector3.ZERO
	var front := _front_civilians(60.0)
	if front.is_empty():
		return
	# vise le gros de la foule, à bonne distance
	var pick: Npc = front[mini(front.size() - 1, _rng.randi_range(2, 8))]
	tp = pick.global_position
	if player != null and player.wanted > 0.3 and _rng.randf() < 0.4 and player.global_position.distance_to(g.global_position) < 45.0:
		tp = player.global_position
	if tp.distance_to(g.global_position) < 13.0 or tp.distance_to(g.global_position) > 48.0:
		return
	g.fire_gas(tp, _rng.randi_range(1, 2 + (1 if stage >= 4 else 0)))
	_set_masks(true)


func _set_masks(on: bool) -> void:
	for c in cops:
		if is_instance_valid(c):
			c.set_masked(on)


func _do_charge() -> void:
	var line := _free_cops(["shield"], ["line", "patrol"])
	if line.size() < 3:
		return
	line.shuffle()
	var n := mini(line.size() - 1, _rng.randi_range(3, 4 + stage))
	var used: Array[Node3D] = []
	for i in n:
		var c: Cop = line[i]
		var t: Node3D = _nearest_civilian(c.global_position, 28.0)
		if player != null and _rng.randf() < 0.25 and player.global_position.distance_to(c.global_position) < 24.0 and player.wanted > 0.2:
			t = player
		if t == null:
			continue
		c.charge(t, _rng.randf_range(5.0, 8.0))
		used.append(t)
	if not used.is_empty():
		tension.add(0.012, "charge de la police")


func _do_lbd() -> void:
	var shooters := _free_cops(["lbd"])
	if shooters.is_empty():
		return
	var s: Cop = shooters[_rng.randi() % shooters.size()]
	var t: Node3D = null
	if player != null and player.arrest_phase == "" and player.wanted > 0.45 and s.global_position.distance_to(player.global_position) < 42.0 and s.global_position.distance_to(player.global_position) > 6.0:
		t = player
	else:
		var front := _front_civilians(40.0)
		var cand: Array[Npc] = []
		for n in front:
			if n.global_position.distance_to(s.global_position) > 8.0 and (n.hostile > 0.2 or n.bold > 0.7):
				cand.append(n)
		if cand.is_empty():
			return
		t = cand[_rng.randi() % mini(cand.size(), 6)]
	s.fire_lbd(t, _rng.randi_range(1, 2))


func _do_arrest(calm := false) -> void:
	var t: Node3D = null
	if player != null and player.arrest_phase == "" and player.invuln_t <= 0.0 and player.wanted > 0.5 and player.global_position.distance_to(line_c) < 40.0:
		t = player
	else:
		var front := _front_civilians(36.0)
		var cand: Array[Npc] = []
		for n in front:
			if n.hostile > 0.25 or (not calm and n.bold > 0.8):
				cand.append(n)
		if cand.is_empty():
			return
		t = cand[0]
	_assign_arrest(t, 2 if t is Player else 1)
