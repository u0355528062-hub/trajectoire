class_name Civilians
extends Node3D
## Passants du quartier : crée les Passerby aux entrées (bouts du boulevard, rues adjacentes, portes
## d'immeubles) hors de la vue du joueur, leur donne un itinéraire le long des trottoirs avec traversée aux
## passages piétons, les retire à la sortie. Leur nombre baisse quand la tension monte ; à partir du stade 2
## ceux qui restent quittent le quartier à l'opposé de la police. Relaie aux passants les événements
## de la foule (charges, explosions, vitres, gaz) : le nœud est dans le groupe « crowd » comme Tension.
## Les passants ne sont pas dans `crowd.npcs` : aucune activité de manifestant ni interpellation.

const TARGET := [14, 11, 6, 3, 1]            # passants voulus selon le stade de tension (0..4)
const MAX_ACTIVE := 14
const END_X := 98.0                          # entrées / sorties aux bouts du boulevard
const FEMALE := ["female_a", "female_b", "female_c", "female_d"]
const MALE := ["male_a", "male_b", "male_c", "male_d", "male_e"]
const KINDS := ["walker", "walker", "walker", "phone", "phone", "shopper", "shopper", "elder", "elder", "stroller", "dog", "dog"]

var crowd: Crowd
var police: Police
var player: Player
var walkers: Array[Passerby] = []
var spawned := 0
var removed := 0
var _rng := RandomNumberGenerator.new()
var _spawn_cd := 0.0
var _upd_t := 0.0
var _next_idx := 600
var _populated := false


func setup(c: Crowd, p: Police, pl: Player) -> void:
	crowd = c
	police = p
	player = pl


func _ready() -> void:
	add_to_group("crowd")          # reçoit les événements de la foule (voir on_event)
	add_to_group("civilians")
	_rng.seed = 5150


func stage() -> int:
	return police.stage if police != null else 0


## Ce que les passants regardent : le cortège, ou la ligne de police quand elle est là
func interest_point(st: int) -> Vector3:
	if st >= 1 and police != null and _rng.randf() < 0.3:
		return police.line_c + Vector3.UP * 1.5
	return crowd.cortege_center() if crowd else Vector3.UP * 1.5


func _allow_east() -> bool:
	return stage() <= 1 and (police == null or police.line_c.x > 45.0)


# =================================================================== itinéraires
## Sorties possibles : {id, side ("N"/"S"), x (jonction avec le trottoir du boulevard), far (étapes au-delà)}
func _exits(east: bool) -> Array:
	var out := [
		{"id": "WN", "side": "N", "x": -END_X, "far": []},
		{"id": "WS", "side": "S", "x": -END_X, "far": []},
	]
	var sn: Array = Quartier.SIDE_NORTH
	var xn: float = (sn[0] + _rng.randf_range(1.0, 2.2)) if _rng.randf() < 0.5 else (sn[1] - _rng.randf_range(1.0, 2.2))
	out.append({"id": "SN", "side": "N", "x": xn, "far": [Vector3(xn, 0, 40.0), Vector3(xn, 0, float(sn[2]) - 3.0)]})
	var ss: Array = Quartier.SIDE_SOUTH
	var xs: float = (ss[0] + _rng.randf_range(1.0, 2.2)) if _rng.randf() < 0.5 else (ss[1] - _rng.randf_range(1.0, 2.2))
	out.append({"id": "SS", "side": "S", "x": xs, "far": [Vector3(xs, 0, -45.0), Vector3(xs, 0, float(ss[2]) + 3.0)]})
	if east:
		out.append({"id": "EN", "side": "N", "x": END_X, "far": []})
		out.append({"id": "ES", "side": "S", "x": END_X, "far": []})
	return out


func _crosswalk(x0: float, x1: float) -> float:
	var best := 0.0
	var bd := INF
	for cw: float in Quartier.CROSSWALKS:
		# tendu : on ne traverse pas sous le nez de la police
		if stage() >= 2 and police != null and cw > police.line_c.x - 14.0:
			continue
		var d := absf(x0 - cw) + absf(cw - x1) + _rng.randf_range(0.0, 6.0)
		if d < bd:
			bd = d
			best = cw
	return best + _rng.randf_range(-1.2, 1.2)


## Étapes de `p` jusqu'à la sortie `ex` (trottoir du passant, traversée éventuelle, rue adjacente)
func _route(w: Passerby, p: Vector3, ex: Dictionary) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var sp := "N" if p.z > Quartier.ROAD_Z else "S"
	if p.z > Quartier.NORTH_Z - 0.6 or p.z < Quartier.SOUTH_Z + 0.6:
		pts.append(Vector3(p.x, 0, w.lane(sp)))         # sortir de la rue adjacente / de la porte
	var side: String = ex["side"]
	var exx: float = ex["x"]
	if side != sp:
		var cw := _crosswalk(p.x, exx)
		pts.append(Vector3(cw, 0, w.lane(sp)))
		pts.append(Vector3(cw, 0, w.lane(side)))
	pts.append(Vector3(exx, 0, w.lane(side)))
	for f: Vector3 in ex["far"]:
		pts.append(f)
	return _subdivide(p, pts)


## Découpe les longues lignes droites (le chemin A* reste court, les décisions plus fréquentes)
func _subdivide(from: Vector3, pts: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var prev := from
	for q in pts:
		var d := Vector2(q.x - prev.x, q.z - prev.z).length()
		var n := int(d / 22.0)
		for i in range(1, n + 1):
			var t := float(i) / float(n + 1)
			out.append(prev.lerp(q, t))
		out.append(q)
		prev = q
	return out


## Itinéraire de fuite : la sortie la plus proche qui ne fait pas passer par le danger
func exit_route(w: Passerby, from: Vector3) -> Array[Vector3]:
	var p := w.global_position
	var best: Dictionary = {}
	var bs := INF
	for ex: Dictionary in _exits(_allow_east()):
		var exx: float = ex["x"]
		var s := absf(exx - p.x) + (14.0 if (ex["side"] == "N") != (p.z > Quartier.ROAD_Z) else 0.0) + (ex["far"] as Array).size() * 12.0
		# la sortie est-elle derrière le danger ?
		if signf(exx - p.x) == signf(from.x - p.x) and absf(from.x - p.x) < absf(exx - p.x) and absf(from.x - p.x) > 1.0:
			s += 160.0
		if police != null and stage() >= 1 and exx > police.line_c.x - 6.0:
			s += 300.0
		s += _rng.randf_range(0.0, 15.0)
		if s < bs:
			bs = s
			best = ex
	return _route(w, p, best)


# =================================================================== création / retrait
func _hidden(p: Vector3, cam: Camera3D, near := 38.0) -> bool:
	if cam == null:
		return true
	var d := p.distance_to(cam.global_position)
	return d > near or (d > 12.0 and not cam.is_position_in_frustum(p + Vector3.UP))


func _make(pos: Vector3) -> Passerby:
	var w := Passerby.new()
	w.mgr = self
	w.crowd = crowd
	w.idx = _next_idx
	_next_idx += 1
	w.kind = KINDS[_rng.randi() % KINDS.size()]
	if w.kind == "elder":
		w.age = "elder"
	else:
		var r := _rng.randf()
		w.age = "young" if r < 0.35 else ("elder" if r > 0.92 and w.kind != "stroller" else "adult")
	w.female = _rng.randf() < (0.7 if w.kind == "stroller" else 0.5)
	w.variant = FEMALE[_rng.randi() % FEMALE.size()] if w.female else MALE[_rng.randi() % MALE.size()]
	w.voice = "f1" if w.female else ("m1" if _rng.randf() < 0.5 else "m2")
	w.vpitch = _rng.randf_range(0.96, 1.1) if w.female else _rng.randf_range(0.9, 1.06)
	w.outfit = CivilKit.outfit(_rng, w.female, w.age)
	match w.age:
		"elder":
			w.base_speed = _rng.randf_range(0.72, 0.95)
		"young":
			w.base_speed = _rng.randf_range(1.25, 1.6)
		_:
			w.base_speed = _rng.randf_range(1.12, 1.45)
	if w.kind == "stroller":
		w.base_speed = minf(w.base_speed, _rng.randf_range(1.0, 1.2))
	w.curious = _rng.randf_range(0.15, 0.95)
	w.calm = _rng.randf_range(0.15, 0.9)
	w.bold = _rng.randf_range(0.1, 0.6)
	w.lane_n = _rng.randf_range(16.3, 18.3)
	w.lane_s = _rng.randf_range(-25.2, -23.1)
	w.position = Vector3(pos.x, crowd.ground_y(pos), pos.z)
	return w


func _add(w: Passerby) -> void:
	if not w.route.is_empty():
		var d := w.route[mini(w.wp, w.route.size() - 1)] - w.position
		if Vector2(d.x, d.z).length() > 0.1:
			w.rotation.y = atan2(-d.x, -d.z)
	add_child(w)
	crowd.actors.append(w)
	walkers.append(w)
	spawned += 1
	w.call_deferred("_go_wp")


## Un nouveau passant à une entrée cachée (ou en cours de route au début de la partie)
func _spawn(cam: Camera3D, mid_route := false) -> bool:
	var exs := _exits(_allow_east())
	var ent: Dictionary = exs[_rng.randi() % exs.size()]
	var ex: Dictionary = ent
	for _i in 6:
		ex = exs[_rng.randi() % exs.size()]
		if ex["id"] != ent["id"] and not (ent["id"] in ["WN", "WS"] and ex["id"] in ["WN", "WS"]) and not (ent["id"] in ["EN", "ES"] and ex["id"] in ["EN", "ES"]):
			break
	if ex["id"] == ent["id"]:
		return false
	var w := _make(Vector3.ZERO)
	var start: Vector3
	var pre: Array[Vector3] = []
	var far: Array = ent["far"]
	var door := not mid_route and _rng.randf() < 0.25
	if door:
		# sort d'un immeuble (porte cochère) près du joueur mais hors de sa vue
		var px := player.global_position.x if player else 0.0
		var x := clampf(px + _rng.randf_range(-45.0, 45.0), -90.0, 90.0)
		var north := _rng.randf() < 0.5
		start = Vector3(x, 0, Quartier.NORTH_Z - 0.5 if north else Quartier.SOUTH_Z + 0.5)
	elif far.is_empty():
		start = Vector3(ent["x"], 0, w.lane(ent["side"]))
	else:
		start = far[far.size() - 1]
		for i in range(far.size() - 2, -1, -1):
			pre.append(far[i])
		pre.append(Vector3(ent["x"], 0, w.lane(ent["side"])))
	var from := pre[pre.size() - 1] if not pre.is_empty() else start
	var rt: Array[Vector3] = pre.duplicate()
	rt.append_array(_route(w, from, ex))
	if mid_route:
		# au début de la partie : déjà en chemin, quelque part sur l'itinéraire
		var i := _rng.randi_range(0, rt.size() - 2)
		start = rt[i].lerp(rt[i + 1], _rng.randf())
		w.wp = i + 1
	if not _hidden(start, cam, 30.0 if mid_route else 38.0):
		w.free()
		return false
	w.route = rt
	w.position = Vector3(start.x, crowd.ground_y(start), start.z)
	_add(w)
	# un couple ou deux amis : le second marche à côté du premier
	if stage() <= 1 and w.kind in ["walker", "shopper", "elder", "dog"] and _rng.randf() < 0.18 and walkers.size() < MAX_ACTIVE:
		var c := _make(start)
		c.age = w.age
		c.outfit = CivilKit.outfit(_rng, c.female, c.age)
		c.kind = "walker" if w.kind != "elder" else "elder"
		c.base_speed = w.base_speed
		c.lane_n = w.lane_n
		c.lane_s = w.lane_s
		c.lead = w
		c.lead_side = 1.0 if _rng.randf() < 0.5 else -1.0
		c.route = rt.duplicate()
		c.wp = w.wp
		c.position = w.position + Basis(Vector3.UP, w.rotation.y) * Vector3(c.lead_side * 0.7, 0, 0.2)
		_add(c)
	return true


func _remove(w: Passerby) -> void:
	walkers.erase(w)
	for o in walkers:
		if o.lead == w:
			o.lead = null
	if crowd:
		crowd.unregister_actor(w)
	w.queue_free()
	removed += 1


# =================================================================== boucle
func _physics_process(delta: float) -> void:
	_upd_t -= delta
	if _upd_t > 0.0 or crowd == null:
		return
	var dt := 0.25 - _upd_t
	_upd_t = 0.25
	var cam := get_viewport().get_camera_3d()
	var st := stage()
	if not _populated:
		_populated = true
		var tries := 0
		while walkers.size() < 9 and tries < 40:
			_spawn(cam, true)
			tries += 1
	var target: int = TARGET[clampi(st, 0, 4)]
	var clouds := get_tree().get_nodes_in_group("gas_clouds")
	var excess := walkers.size() - target
	for i in range(walkers.size() - 1, -1, -1):
		var w := walkers[i]
		if not is_instance_valid(w):
			walkers.remove_at(i)
			continue
		var hid := _hidden(w.global_position, cam, 40.0)
		if w.done or (w.stuck_t > 15.0 and hid):
			_remove(w)
			continue
		if excess > 2 and hid and w.leaving:
			_remove(w)
			excess -= 1
			continue
		if st >= 2 and not w.leaving and _rng.randf() < 0.25:
			w.leave(police.line_c if police else w.global_position, st >= 3 and _rng.randf() < 0.4)
		for c in clouds:
			var g := c as GasCloud
			if g == null or g.fade() < 0.1:
				continue
			var dd := Vector2(w.global_position.x - g.global_position.x, w.global_position.z - g.global_position.z).length()
			if dd < g.radius:
				w.on_gas(g.density_at(w.global_position), g.global_position)
			elif dd < g.radius + 5.0 and w.state not in ["flee", "gassed"]:
				w.startle(g.global_position, 0.35)
	_spawn_cd -= dt
	if _spawn_cd <= 0.0 and walkers.size() < mini(target, MAX_ACTIVE):
		_spawn_cd = _rng.randf_range(1.5, 3.5) * (1.0 + st)
		_spawn(cam)


# =================================================================== événements
func on_event(type: String, d: Dictionary) -> void:
	if not d.has("pos"):
		return
	var p: Vector3 = d["pos"]
	match type:
		"police_charge":
			_scare(p, 24.0, 0.6, true)
		"burst":
			_scare(p, 26.0, 0.45)
		"petard_boom":
			_scare(p, 20.0, 0.4)
		"mortar_fire":
			_scare(p, 12.0, 0.25)
		"gas_land":
			_scare(p, 22.0, 0.5)
		"police_gas":
			_scare(p, 14.0, 0.25)
		"police_lbd", "police_baton", "civil_hit", "grab":
			_scare(p, 16.0, 0.35)
		"glass_break":
			_scare(p, 14.0, 0.3)
		"car_burn", "fire_start", "bus_collapse":
			_scare(p, 12.0, 0.2)
		"police_stage":
			var s := int(d.get("stage", 0))
			if s >= 2:
				# chacun réalise à son rythme qu'il vaut mieux partir
				for w in walkers:
					if is_instance_valid(w) and not w.leaving and w.leave_at <= 0.0:
						w._danger = p
						w.leave_at = _rng.randf_range(0.2, 4.0)
						w.leave_run = s >= 3 and w.calm < 0.4


func _scare(p: Vector3, r: float, a: float, run := false) -> void:
	for w in walkers:
		if not is_instance_valid(w):
			continue
		var dd := Vector2(w.global_position.x - p.x, w.global_position.z - p.z).length()
		if dd < r:
			w.startle(p, a * (1.0 - 0.5 * dd / r), run and dd < r * 0.8)
