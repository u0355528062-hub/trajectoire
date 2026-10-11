class_name Residents
extends Node3D
## Habitants aux fenêtres et aux balcons : une poignée (MAX_VISIBLE) choisie près du joueur parmi les places
## exposées par les immeubles (groupe « paris_buildings », ParisBuilding.spots_world()), renouvelée quand
## il se déplace. Ils sortent de chez eux, regardent, filment, fument, applaudissent ou crient sur la
## police, et rentrent quand il y a du gaz ou des détonations proches. Reçoit les événements de la foule.

const MAX_VISIBLE := 8
const NEAR := 42.0             # distance (au sol) max d'une place choisie autour du joueur
const DROP := 55.0             # au-delà, l'habitant rentre
const WINDOW_FWD := 0.55       # fenêtre : on se tient dans l'embrasure, devant le vitrage (corps coupé par l'allège)
const FEMALE := ["female_a", "female_b", "female_c", "female_d"]
const MALE := ["male_a", "male_b", "male_c", "male_d", "male_e"]

var crowd: Crowd
var police: Police
var player: Player
var residents: Array[Resident] = []
var spawned := 0
var retreated := 0
var _spots: Array = []         # {pos, xf, kind, floor, yaw, fwd, cd}
var _n_buildings := -1
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _upd_t := 0.0
var _spawn_cd := 1.0
var _scan_t := 0.0
var _next_idx := 900


func setup(c: Crowd, p: Police, pl: Player) -> void:
	crowd = c
	police = p
	player = pl


func _ready() -> void:
	add_to_group("crowd")          # reçoit les événements de la foule (voir on_event)
	add_to_group("residents")
	_rng.seed = 7311


func stage() -> int:
	return police.stage if police != null else 0


func interest_point(st: int) -> Vector3:
	var r := _rng.randf()
	if st >= 1 and police != null and r < 0.35:
		return police.line_c + Vector3.UP * 1.5
	if player != null and r > 0.85:
		return player.global_position + Vector3.UP * 1.6
	return crowd.cortege_center() if crowd else Vector3.UP * 1.5


## Relève les places d'habitants (les immeubles peuvent être reconstruits : on vérifie leur nombre)
func _refresh_spots() -> void:
	var bs := get_tree().get_nodes_in_group("paris_buildings")
	if bs.size() == _n_buildings and not _spots.is_empty():
		return
	_n_buildings = bs.size()
	var old := {}
	for s in _spots:
		old[Vector3i(s["pos"].round())] = s["cd"]
	_spots.clear()
	for b in bs:
		if not b.has_method("spots_world"):
			continue
		for s: Dictionary in b.spots_world():
			var xf: Transform3D = s["xf"]
			var fwd := -xf.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			var key := Vector3i(xf.origin.round())
			_spots.append({"pos": xf.origin, "kind": s.get("kind", "window"), "floor": int(s.get("floor", 0)),
				"yaw": atan2(-fwd.x, -fwd.z), "fwd": fwd, "cd": old.get(key, 0.0), "used": false})


func _physics_process(delta: float) -> void:
	_time += delta
	_tick_residents(delta)
	_upd_t -= delta
	if _upd_t > 0.0:
		return
	_upd_t = 0.5
	_scan_t -= 0.5
	if _scan_t <= 0.0 or _spots.is_empty():
		_scan_t = 10.0
		_refresh_spots()
	_update(0.5)


## Animation avec LOD : près et dans le champ à chaque image, sinon rarement
func _tick_residents(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var cp := cam.global_position if cam else Vector3.ZERO
	for r in residents:
		var d := r.global_position.distance_to(cp)
		var every := 1 if d < 25.0 else (2 if d < 45.0 else 4)
		var lod := 0 if d < 22.0 else (1 if d < 45.0 else 2)
		if cam != null and not cam.is_position_in_frustum(r.global_position + Vector3.UP):
			every = maxi(every * 3, 6)
			lod = 2
		r.human.lod = lod
		r.tick_every(delta, every)


func _update(_dt: float) -> void:
	var pp := player.global_position if player else Vector3.ZERO
	var st := stage()
	var cap := MAX_VISIBLE if st <= 2 else (6 if st == 3 else 4)
	var clouds := get_tree().get_nodes_in_group("gas_clouds")
	for i in range(residents.size() - 1, -1, -1):
		var r := residents[i]
		if r.state == "gone":
			_free(r, _rng.randf_range(30.0, 80.0))
			continue
		var dd := Vector2(r.post.x - pp.x, r.post.z - pp.z).length()
		if dd > DROP:
			r.retreat(false)
		# gaz au pied de l'immeuble : on ferme la fenêtre
		for c in clouds:
			var g := c as GasCloud
			if g != null and g.fade() > 0.2 and Vector2(r.post.x - g.global_position.x, r.post.z - g.global_position.z).length() < g.radius + 9.0:
				r.retreat(true)
	var active := 0
	for r in residents:
		if r.state != "in":
			active += 1
	if active > cap:
		for r in residents:
			if r.state == "idle" and _rng.randf() < 0.3:
				r.retreat(false)
				break
	_spawn_cd -= 0.5
	if _spawn_cd <= 0.0 and active < cap and not _spots.is_empty():
		_spawn_cd = 0.4 if spawned < 5 else _rng.randf_range(2.5, 6.0)
		_spawn(pp, clouds)


func _spawn(pp: Vector3, clouds: Array) -> void:
	var cands: Array = []
	var weights: Array[float] = []
	var total := 0.0
	for s: Dictionary in _spots:
		if s["used"] or float(s["cd"]) > _time:
			continue
		var p: Vector3 = s["pos"]
		var to := Vector3(pp.x - p.x, 0, pp.z - p.z)
		var d := to.length()
		if d > NEAR or d < 5.0 or to.dot(s["fwd"]) <= 0.0:
			continue
		var gassy := false
		for c in clouds:
			if Vector2(p.x - (c as Node3D).global_position.x, p.z - (c as Node3D).global_position.z).length() < 15.0:
				gassy = true
		if gassy:
			continue
		var crowded := false
		for r in residents:
			if r.post.distance_to(p) < 3.0:
				crowded = true
				break
		if crowded:
			continue
		var w := (1.0 - d / NEAR * 0.7) * (1.4 if s["kind"] == "balcony" else 1.0) * (0.5 if int(s["floor"]) >= 4 else 1.0)
		cands.append(s)
		weights.append(w)
		total += w
	if cands.is_empty():
		return
	var x := _rng.randf() * total
	var pick: Dictionary = cands[cands.size() - 1]
	for i in cands.size():
		x -= weights[i]
		if x <= 0.0:
			pick = cands[i]
			break
	_make(pick)


func _make(s: Dictionary) -> void:
	var r := Resident.new()
	r.mgr = self
	r.crowd = crowd
	r.idx = _next_idx
	_next_idx += 1
	r.kind = s["kind"]
	r.female = _rng.randf() < 0.55
	r.variant = FEMALE[_rng.randi() % FEMALE.size()] if r.female else MALE[_rng.randi() % MALE.size()]
	r.voice = "f1" if r.female else ("m1" if _rng.randf() < 0.5 else "m2")
	r.vpitch = _rng.randf_range(0.96, 1.1) if r.female else _rng.randf_range(0.9, 1.06)
	var ar := _rng.randf()
	var age := "young" if ar < 0.35 else ("elder" if ar > 0.78 else "adult")
	var o := CivilKit.outfit(_rng, r.female, age)
	# chez soi : pas de manteau ni de sac, rarement un chapeau ; t-shirt, pull ou gilet
	o["coat"] = false
	o["handbag"] = false
	o["backpack"] = false
	o["hat"] = ""
	o["head"] = ""
	o["scarf"] = _rng.randf() < 0.15
	o["top"] = ["tshirt", "hoodie", "jacket", "tshirt"][_rng.randi() % 4]
	o["top_color"] = (CivilKit.BRIGHT + CivilKit.COATS)[_rng.randi() % (CivilKit.BRIGHT.size() + CivilKit.COATS.size())]
	r.outfit = o
	var m := _rng.randf()
	r.mood = "supporter" if m < 0.35 else ("angry" if m < 0.55 else ("grumpy" if m < 0.65 else "curious"))
	r.smoker = _rng.randf() < 0.3
	r.calm = _rng.randf_range(0.2, 0.9)
	r.bold = _rng.randf_range(0.2, 0.8)
	var fwd: Vector3 = s["fwd"]
	var base: Vector3 = s["pos"]
	if r.kind == "window":
		r.post = base + fwd * WINDOW_FWD
		r.inside = base - fwd * 0.5
	else:
		r.post = base
		r.inside = base - fwd * 1.1
	r.base_yaw = s["yaw"]
	r.position = r.inside
	r.rotation.y = r.base_yaw
	s["used"] = true
	r.set_meta("spot", s)
	add_child(r)
	residents.append(r)
	spawned += 1


func _free(r: Resident, cd: float) -> void:
	residents.erase(r)
	var s: Variant = r.get_meta("spot", null)
	if s is Dictionary:
		(s as Dictionary)["used"] = false
		(s as Dictionary)["cd"] = _time + cd
	r.queue_free()


# =================================================================== événements
func on_event(type: String, d: Dictionary) -> void:
	if not d.has("pos"):
		return
	var p: Vector3 = d["pos"]
	var r_near := 0.0
	var r_far := 0.0
	match type:
		"burst", "petard_boom":
			r_near = 16.0
			r_far = 40.0
		"gas_land":
			r_near = 22.0
			r_far = 35.0
		"glass_break", "police_lbd", "bus_collapse":
			r_near = 9.0
			r_far = 30.0
		"police_charge", "car_burn", "fire_start", "grab", "police_baton":
			r_far = 35.0
		"police_stage":
			if int(d.get("stage", 0)) >= 3:
				for r in residents:
					if r.mood != "angry" and _rng.randf() < 0.3:
						r.retreat(false)
			return
		_:
			return
	for r in residents:
		var dd := r.global_position.distance_to(p)
		if dd < r_far:
			r.startle(p, dd < r_near)
