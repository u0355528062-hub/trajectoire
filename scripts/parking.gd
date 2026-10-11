class_name Parking
extends Node3D
## Voitures garées du quartier et leurs abords : files de stationnement le long du boulevard (`Quartier.PARK_LANES`)
## et des rues adjacentes, parking à ciel ouvert (`Quartier.PARKING` : enrobé, places numérotées, bordures, potelets,
## barrière levante, horodateur, panneau « P », deux-roues) et station de vélos en libre-service (`Quartier.VELIB`).
## Tout est vandalisable ; les vitres des voitures ne sont créées qu'à proximité du joueur ou d'une pierre.

const ROAD_Y := 0.02                 # dessus de la chaussée du boulevard
const ARM_NEAR := 18.0               # le joueur à moins de 18 m : vitres cassables
const ARM_FAR := 30.0                # au-delà de 30 m (et intactes) : retour au vitrage statique
## Modèles et poids relatifs (les citadines dominent à Paris)
const MODEL_W := {"citadine": 30, "berline": 14, "break": 14, "suv": 18, "ludospace": 12, "mini": 10}
const SCOOTER_COLORS := [Color(0.88, 0.88, 0.86), Color(0.05, 0.05, 0.06), Color(0.42, 0.43, 0.45), Color(0.6, 0.05, 0.05), Color(0.12, 0.22, 0.45), Color(0.75, 0.68, 0.5)]

var crowd: Crowd
var cars: Array[CivilCar] = []
var props: Array[StreetProp] = []
var gate: ParkingProps.GateArm
var pay: ParkingProps.PayStation
var bikes: Array[ParkingProps.SharedBike] = []
var scooters: Array[ParkingProps.Scooter] = []
var _rng := RandomNumberGenerator.new()
var _arm_t := 0.0
var _static: StaticBody3D
var _b: GeoBatch
var _marks: GeoBatch


func _ready() -> void:
	_rng.seed = 7511
	_static = StaticBody3D.new()
	_static.name = "Solides"
	_static.collision_layer = 1
	_static.collision_mask = 0
	add_child(_static)
	_b = GeoBatch.new()
	_marks = GeoBatch.new()
	_build_lanes()
	_build_side_streets()
	_build_lot()
	_build_velib()
	var mi := GeoBatch.instance(_b.build(), self, true, 0.0)
	mi.name = "Decor"
	var mk := GeoBatch.instance(_marks.build(), self, false, 60.0)
	mk.name = "Marquages"
	if crowd != null:
		crowd.nav_dirty()


# =================================================================== voitures
func _pick_model() -> String:
	var tot := 0
	for k in MODEL_W:
		tot += int(MODEL_W[k])
	var r := _rng.randi() % tot
	for k in MODEL_W:
		r -= int(MODEL_W[k])
		if r < 0:
			return k
	return "citadine"


func _opts(m: String) -> Dictionary:
	var o := {}
	o["paint"] = _rng.randi() % CivilCar.PAINTS.size()
	o["rim"] = (1 if _rng.randf() < 0.55 else 0) if m in ["berline", "ludospace", "mini"] else _rng.randi() % 4
	o["roof_black"] = m in ["citadine", "suv", "mini"] and _rng.randf() < 0.2
	o["beige"] = _rng.randf() < 0.15
	o["dusty"] = _rng.randf() < 0.22
	o["steer"] = _rng.randf_range(-1.0, 1.0) if _rng.randf() < 0.3 else 0.0
	o["plate"] = _rng.randi() % 18
	return o


func add_car(pos: Vector3, yaw: float, m := "") -> CivilCar:
	if m == "":
		m = _pick_model()
	var c := CivilCar.new()
	c.crowd = crowd
	c.position = pos
	c.rotation.y = yaw
	add_child(c)
	c.build_civil(m, _opts(m), _rng)
	cars.append(c)
	if crowd != null:
		crowd.add_obstacle(c, c.half, Vector2.ZERO, false, true)
	return c


## File de voitures le long d'une bordure. `s0`..`s1` : abscisse le long de la file ; `place` (s, demi-largeur)
## -> position du centre ; `yaw` : orientation ; `skip` : intervalles [a, b] à laisser libres.
func _row(s0: float, s1: float, place: Callable, yaw: float, skip: Array = []) -> void:
	var s := s0 + _rng.randf_range(0.0, 1.5)
	while true:
		var m := _pick_model()
		var L: float = CivilCar.MODELS[m]["L"]
		if s + L > s1:
			break
		var blocked := false
		for sk in skip:
			if s + L > float(sk[0]) and s < float(sk[1]):
				blocked = true
				s = float(sk[1]) + _rng.randf_range(0.5, 1.5)
				break
		if blocked:
			continue
		# une place libre de temps en temps (parfois occupée par des deux-roues)
		if _rng.randf() < 0.12:
			if _rng.randf() < 0.5:
				for k in 1 + _rng.randi() % 2:
					var p2: Vector3 = place.call(s + 0.9 + k * 1.1, 0.0)
					var fwd := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
					var side := fwd.cross(Vector3.UP)
					_scooter(p2 + side * 0.2, yaw + PI * 0.5 + _rng.randf_range(-0.15, 0.15))
			s += _rng.randf_range(4.8, 6.5)
			continue
		var hw: float = CivilCar.MODELS[m]["hw"]
		var pos: Vector3 = place.call(s + L * 0.5, hw)
		add_car(pos, yaw + _rng.randf_range(-0.025, 0.025), m)
		s += L + _rng.randf_range(0.55, 1.6)


func _build_lanes() -> void:
	var sr: Array = Quartier.SIDE_SOUTH
	var nr: Array = Quartier.SIDE_NORTH
	for lane in Quartier.PARK_LANES:
		var x0: float = lane[0]
		var x1: float = lane[1]
		var z: float = lane[2]
		# la file au-delà du barrage de police est laissée vide : les renforts y roulent et s'y garent (voie z = -5.65)
		if x0 > 40.0:
			continue
		var north := z > Quartier.ROAD_Z
		var skip: Array = []
		var mouth: Array = nr if north else sr
		skip.append([float(mouth[0]) - 2.5, float(mouth[1]) + 2.5])
		for cx in Quartier.CROSSWALKS:
			skip.append([float(cx) - 4.0, float(cx) + 4.0])
		if north:
			# côté nord : on roule vers +X, les voitures regardent vers +X
			_row(x0, x1, func(s: float, hw: float): return Vector3(s, ROAD_Y, Quartier.ROAD_Z1 - hw - 0.14 - _rng.randf_range(0.0, 0.08)), -PI * 0.5, skip)
		else:
			_row(x0, x1, func(s: float, hw: float): return Vector3(s, ROAD_Y, Quartier.ROAD_Z0 + hw + 0.14 + _rng.randf_range(0.0, 0.08)), PI * 0.5, skip)


func _build_side_streets() -> void:
	var w := Quartier.SIDE_ROAD_W * 0.5
	# rue nord : chaussée x -53..-47 ; stationnement le long du trottoir ouest, voitures tournées vers +Z
	var nmid := (float(Quartier.SIDE_NORTH[0]) + float(Quartier.SIDE_NORTH[1])) * 0.5
	_row(Quartier.NORTH_Z + 4.5, float(Quartier.SIDE_NORTH[2]) - 2.5, func(s: float, hw: float): return Vector3(nmid - w + hw + 0.14 + _rng.randf_range(0.0, 0.07), 0.0, s), PI)
	# rue sud : chaussée x -80..-74 ; stationnement le long du trottoir est, voitures tournées vers -Z
	var smid := (float(Quartier.SIDE_SOUTH[0]) + float(Quartier.SIDE_SOUTH[1])) * 0.5
	_row(-Quartier.SOUTH_Z + 4.5, -float(Quartier.SIDE_SOUTH[2]) - 2.5,
		func(s: float, hw: float): return Vector3(smid + w - hw - 0.14 - _rng.randf_range(0.0, 0.07), 0.0, -s), 0.0)


# =================================================================== deux-roues
func _scooter(pos: Vector3, yaw: float) -> ParkingProps.Scooter:
	var s := ParkingProps.Scooter.new()
	s.crowd = crowd
	s.kind = "moto" if _rng.randf() < 0.3 else "scooter"
	s.color = SCOOTER_COLORS[_rng.randi() % SCOOTER_COLORS.size()]
	s.top_case = s.kind == "scooter" and _rng.randf() < 0.5
	s.position = pos
	s.rotation.y = yaw
	add_child(s)
	scooters.append(s)
	props.append(s)
	return s


# =================================================================== parking à ciel ouvert
func _mat(key: String) -> Material:
	match key:
		"asphalt":
			var a := Furniture.mat("pk_asphalt", Color(0.5, 0.5, 0.52), 0.82)
			if a.albedo_texture == null:
				a.albedo_texture = load("res://assets/busstop/asphalt_a.png")
				a.normal_enabled = true
				a.normal_texture = load("res://assets/busstop/asphalt_n.png")
				a.normal_scale = 0.5
				a.uv1_triplanar = true
				a.uv1_scale = Vector3(0.9, 0.9, 0.9)
			return a
		"line":
			return Furniture.mat("pk_line", Color(0.86, 0.86, 0.82), 0.7)
		"yellow":
			return Furniture.mat("pk_yellow", Color(0.86, 0.68, 0.1), 0.7)
		"curb":
			return Furniture.mat("pk_curb", Color(0.6, 0.59, 0.56), 0.8)
		"bollard":
			return Furniture.mat("pk_bollard", Color(0.16, 0.12, 0.09), 0.5, 0.5)
		"housing":
			return Furniture.mat("pk_housing", Color(0.85, 0.66, 0.08), 0.45, 0.2)
		"red":
			return Furniture.mat("pk_red", Color(0.7, 0.05, 0.05), 0.4)
		"marks":
			var mm := Furniture.mat("pk_marks", Color(1, 1, 1), 0.8)
			if mm.albedo_texture == null:
				mm.albedo_texture = load("res://assets/quartier/ground_marks.png")
				mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			return mm
	return Furniture.mat("pk_grey", Color(0.5, 0.5, 0.5))


func _ground_quad(b: GeoBatch, key: String, c: Vector3, size: Vector2, yaw := 0.0, uv := Rect2(0, 0, 1, 1)) -> void:
	var bas := Basis(Vector3.UP, yaw)
	var hx := bas * Vector3(size.x * 0.5, 0, 0)
	var hz := bas * Vector3(0, 0, size.y * 0.5)
	var pts := PackedVector3Array([c - hx + hz, c + hx + hz, c + hx - hz, c - hx - hz])
	var uvs := PackedVector2Array([Vector2(uv.position.x, uv.end.y), Vector2(uv.end.x, uv.end.y), Vector2(uv.end.x, uv.position.y), uv.position])
	b.poly_facing(key, _mat(key), pts, Vector3.UP, uvs)


func _col_box(size: Vector3, pos: Vector3, yaw := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	cs.rotation.y = yaw
	_static.add_child(cs)


func _obstacle(pos: Vector3, half: Vector2, yaw := 0.0) -> void:
	if crowd == null:
		return
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	crowd.add_obstacle(n, half, Vector2.ZERO, false, true)


func _build_lot() -> void:
	var r := Quartier.PARKING
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	var top := 0.03
	# enrobé
	_b.box("asphalt", _mat("asphalt"), Vector3(r.size.x, top, r.size.y), Vector3((x0 + x1) * 0.5, top * 0.5, (z0 + z1) * 0.5))
	# bordures (l'entrée est au nord-est, côté boulevard)
	var ent0 := x1 - 4.3
	var ent1 := x1 - 0.9
	var ch := 0.12
	var cw := 0.18
	_b.box("curb", _mat("curb"), Vector3(r.size.x, ch, cw), Vector3((x0 + x1) * 0.5, ch * 0.5, z0 + cw * 0.5), Basis(), 0.02)
	_b.box("curb", _mat("curb"), Vector3(cw, ch, r.size.y), Vector3(x0 + cw * 0.5, ch * 0.5, (z0 + z1) * 0.5), Basis(), 0.02)
	_b.box("curb", _mat("curb"), Vector3(cw, ch, r.size.y), Vector3(x1 - cw * 0.5, ch * 0.5, (z0 + z1) * 0.5), Basis(), 0.02)
	_b.box("curb", _mat("curb"), Vector3(ent0 - x0, ch, cw), Vector3((x0 + ent0) * 0.5, ch * 0.5, z1 - cw * 0.5), Basis(), 0.02)
	_b.box("curb", _mat("curb"), Vector3(x1 - ent1, ch, cw), Vector3((ent1 + x1) * 0.5, ch * 0.5, z1 - cw * 0.5), Basis(), 0.02)
	# potelets le long du trottoir (hors entrée)
	var x := x0 + 0.6
	while x < x1 - 0.3:
		if x < ent0 - 0.3 or x > ent1 + 0.3:
			_bollard(Vector3(x, 0, z1 + 0.25))
		x += 1.6
	# places : rangée du fond (8 places de 2,5 m), une place longitudinale à l'ouest
	var row_z0 := z0 + 0.3
	var depth := 5.0
	var stall_x0 := x0 + 2.4
	var n := 7
	var lw := 0.1
	for i in n + 1:
		var lx := stall_x0 + 2.5 * i
		_ground_quad(_marks, "line", Vector3(lx, top + 0.002, row_z0 + depth * 0.5), Vector2(lw, depth))
	_ground_quad(_marks, "line", Vector3(stall_x0 + 2.5 * n * 0.5, top + 0.002, row_z0 + 0.05), Vector2(2.5 * n, lw))
	var slots: Array = []
	for i in n:
		var cx := stall_x0 + 2.5 * (i + 0.5)
		slots.append(cx)
		# numéro peint au pied de la place
		var cell := Rect2(float(i % 4) * 0.25, float(i / 4) * 0.25, 0.25, 0.25)
		_ground_quad(_marks, "marks", Vector3(cx, top + 0.003, row_z0 + depth - 0.55), Vector2(0.7, 0.7), PI, cell)
	# place longitudinale contre la bordure ouest, et le marquage « deux-roues » en jaune
	var pz0 := row_z0 + 0.2
	_ground_quad(_marks, "line", Vector3(x0 + 2.2, top + 0.002, (pz0 + z1 - 0.6) * 0.5), Vector2(lw, z1 - 0.6 - pz0))
	var moto_x0 := x1 - 9.2
	for k in 4:
		_ground_quad(_marks, "yellow", Vector3(moto_x0 + k * 1.1, top + 0.002, z1 - 1.3), Vector2(0.08, 1.9))
	_ground_quad(_marks, "yellow", Vector3(moto_x0 + 1.65, top + 0.002, z1 - 2.25), Vector2(3.3, 0.08))
	# taches d'huile sous les places
	for i in n:
		if _rng.randf() < 0.7:
			var cell2 := Rect2(float(_rng.randi() % 4) * 0.25, 0.75, 0.25, 0.25)
			_ground_quad(_marks, "marks", Vector3(slots[i] + _rng.randf_range(-0.4, 0.4), top + 0.0025, row_z0 + _rng.randf_range(1.2, 3.8)), Vector2.ONE * _rng.randf_range(0.7, 1.3), _rng.randf() * TAU, cell2)
	# voitures : 6 places du fond sur 7, la place longitudinale
	var empty := [2, 5]
	for i in n:
		if i in empty:
			continue
		var m := _pick_model()
		var L: float = CivilCar.MODELS[m]["L"]
		var nose_in := _rng.randf() < 0.7
		var cz := row_z0 + 0.25 + L * 0.5
		add_car(Vector3(slots[i] + _rng.randf_range(-0.12, 0.12), top, cz), (0.0 if nose_in else PI) + _rng.randf_range(-0.04, 0.04), m)
	add_car(Vector3(x0 + 1.15, top, (pz0 + z1 - 0.6) * 0.5), PI + 0.01, "citadine")
	# deux-roues
	for k in 3:
		_scooter(Vector3(moto_x0 + 0.55 + k * 1.1, top, z1 - 1.25), PI + _rng.randf_range(-0.12, 0.12))
	# barrière levante : boîtier à l'est de l'entrée, bras vers l'ouest
	var hx := ent1 + 0.25
	var hz := z1 - 0.45
	_b.box("housing", _mat("housing"), Vector3(0.36, 1.05, 0.32), Vector3(hx, 0.525 + top, hz), Basis(), 0.04)
	_b.box("red", _mat("red"), Vector3(0.37, 0.08, 0.33), Vector3(hx, 0.8 + top, hz), Basis(), 0.0)
	_b.box("curb", _mat("curb"), Vector3(0.46, 0.08, 0.42), Vector3(hx, top + 0.04, hz), Basis(), 0.02)
	_b.box("housing", _mat("housing"), Vector3(0.32, 0.08, 0.07), Vector3(hx - 0.32, 1.0 + top, hz), Basis(), 0.0)
	_col_box(Vector3(0.36, 1.05, 0.32), Vector3(hx, 0.525, hz))
	_obstacle(Vector3(hx, 0, hz), Vector2(0.22, 0.2))
	gate = ParkingProps.GateArm.new()
	gate.crowd = crowd
	gate.length = (hx - 0.48) - (ent0 + 0.1)
	gate.position = Vector3((hx - 0.48 + ent0 + 0.1) * 0.5, top, hz)
	add_child(gate)
	props.append(gate)
	# horodateur et panneau « P » à côté de l'entrée
	pay = ParkingProps.PayStation.new()
	pay.crowd = crowd
	pay.position = Vector3(ent0 - 1.2, top, z1 - 0.5)
	pay.rotation.y = PI
	add_child(pay)
	props.append(pay)
	var sign := ParkingProps.ParkSign.new()
	sign.crowd = crowd
	sign.position = Vector3(ent1 + 0.35, 0.0, z1 + 0.35)
	sign.rotation.y = PI
	add_child(sign)
	props.append(sign)


func _bollard(p: Vector3) -> void:
	var bm := _mat("bollard")
	_b.cyl("bollard", bm, 0.05, 0.055, 0.82, p + Vector3(0, 0.41, 0), Basis(), 10)
	_b.cyl("bollard", bm, 0.07, 0.07, 0.05, p + Vector3(0, 0.025, 0), Basis(), 10)
	_b.cyl("bollard", bm, 0.045, 0.06, 0.05, p + Vector3(0, 0.84, 0), Basis(), 10)
	_b.box("bollard", bm, Vector3(0.12, 0.025, 0.12), p + Vector3(0, 0.62, 0), Basis(Vector3.UP, PI * 0.25), 0.0)
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 0.06
	cy.height = 0.9
	cs.shape = cy
	cs.position = p + Vector3(0, 0.45, 0)
	_static.add_child(cs)


# =================================================================== station de vélos
func _build_velib() -> void:
	var r := Quartier.VELIB
	var grey := Furniture.mat("pk_borne", Color(0.36, 0.38, 0.4), 0.45, 0.6)
	var dark := Furniture.mat("pk_borne_dark", Color(0.08, 0.09, 0.1), 0.5, 0.3)
	var green := Furniture.mat("pk_borne_led", Color(0.2, 0.85, 0.3), 0.3, 0.0, 1.6)
	var z_b := r.position.y + 0.15            # bornes au fond de la zone (sud)
	# borne d'accueil (totem) à l'ouest
	var tx := r.position.x + 0.35
	_b.box("borne", grey, Vector3(0.5, 1.85, 0.3), Vector3(tx, 0.925, z_b + 0.2), Basis(), 0.05)
	_b.box("borne_dark", dark, Vector3(0.36, 0.5, 0.02), Vector3(tx, 1.35, z_b + 0.36), Basis(), 0.01)
	_b.box("led", green, Vector3(0.4, 0.06, 0.02), Vector3(tx, 1.75, z_b + 0.36), Basis(), 0.0)
	_col_box(Vector3(0.5, 1.85, 0.3), Vector3(tx, 0.925, z_b + 0.2))
	_obstacle(Vector3(tx, 0, z_b + 0.2), Vector2(0.3, 0.2))
	var x := r.position.x + 1.2
	var i := 0
	while x < r.end.x - 0.3:
		_b.box("borne", grey, Vector3(0.13, 0.86, 0.16), Vector3(x, 0.43, z_b), Basis(), 0.03)
		_b.box("borne_dark", dark, Vector3(0.1, 0.12, 0.18), Vector3(x, 0.62, z_b + 0.02), Basis(), 0.02)
		_b.box("led", green, Vector3(0.05, 0.02, 0.02), Vector3(x, 0.8, z_b + 0.085), Basis(), 0.0)
		_b.box("borne", grey, Vector3(0.24, 0.03, 0.26), Vector3(x, 0.015, z_b), Basis(), 0.01)
		_col_box(Vector3(0.13, 0.86, 0.16), Vector3(x, 0.43, z_b))
		if i % 4 != 2 and i != 7:
			var bk := ParkingProps.SharedBike.new()
			bk.crowd = crowd
			bk.electric = _rng.randf() < 0.3
			bk.position = Vector3(x + 0.12, 0.0, z_b + 0.95)
			bk.rotation.y = 0.0
			add_child(bk)
			bikes.append(bk)
			props.append(bk)
		x += 0.85
		i += 1
	_obstacle(Vector3((r.position.x + 1.2 + x - 0.85) * 0.5, 0, z_b), Vector2((x - 0.85 - r.position.x - 1.2) * 0.5 + 0.1, 0.12))


# =================================================================== vitres à la demande
func _physics_process(delta: float) -> void:
	_arm_t -= delta
	if _arm_t > 0.0:
		return
	_arm_t = 0.2
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	var stones := get_tree().get_nodes_in_group("stones")
	for c in cars:
		if not is_instance_valid(c) or c.damage == null:
			continue
		var d := c.damage as CivilDamage
		var cp := c.global_position
		var dist := pl.global_position.distance_to(cp) if pl != null else 1e9
		var near := dist < ARM_NEAR
		if not near:
			for s in stones:
				var st := s as RigidBody3D
				if st != null and st.linear_velocity.length_squared() > 9.0 and st.global_position.distance_squared_to(cp) < 100.0:
					near = true
					break
		if near:
			d.arm()
		elif dist > ARM_FAR and d.armed:
			d.disarm()


## Statistiques (tests, rapport)
func stats() -> Dictionary:
	return {"cars": cars.size(), "scooters": scooters.size(), "bikes": bikes.size(), "props": props.size(), "tris_car": CivilCar.tris_per_car()}
