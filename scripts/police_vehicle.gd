class_name PoliceVehicle
extends Node3D
## Véhicules de police modélisés à la main (surfaces lissées) : voiture de patrouille et fourgon de CRS.
## Ils arrivent par la rue (sirène, gyrophares), se garent, ouvrent leurs portières et déversent les équipages.
## Repère : l'avant est -Z, la largeur sur X, le sol à y = 0.

signal parked
signal crew_out

static var _m := {}
static var _meshes := {}

var kind := "car"                 # car | truck
var state := "parked"             # driving | braking | parked
var lights_on := false
var siren_on := false
var urgent := false               # renfort pressé : sirène « hi-lo » rapide au lieu du deux-tons
var speed := 0.0
var max_speed := 11.0
var half := Vector2(0.95, 2.25)   # demi-dimensions au sol (x, z)
var crowd: Crowd
var body_hp := 1.0                # pour le vandalisme (voir plus bas)
var doors := {}                   # nom -> pivot
var _path: Array[Vector3] = []
var _front_wheels: Array[Node3D] = []
var _spin: Array[Node3D] = []
var _wheel_r := 0.33
var _steer := 0.0
var _body: Node3D
var _bar_a: StandardMaterial3D
var _bar_b: StandardMaterial3D
var _bar_lights: Array[OmniLight3D] = []
var _siren: AudioStreamPlayer3D
var _engine: AudioStreamPlayer3D
var _radio: AudioStreamPlayer3D
var _squelch_t := 4.0
var _t := 0.0
var _pitch := 0.0
var _hw := 1.0
var _blocked_t := 0.0
var _static_body: StaticBody3D
var damage: VehicleDamage
var glass_loft: MeshInstance3D          # habitacle vitré de la voiture (devient mat une fois les vitres posées)
var glass_meshes: Array[Node3D] = []    # vitres « décor » du fourgon, remplacées par de vraies vitres cassables
var _relocating := false
var sag := 0.0                         # affaissement (pneus crevés)
var _bounce := 0.0
var _bounce_v := 0.0
var _roll := 0.0
var _roll_v := 0.0
var burning: bool:
	get:
		return damage != null and damage.burning
var heat: float:
	get:
		return damage.heat if damage != null else 0.0


# ------------------------------------------------------------------ matériaux
static func mat(key: String) -> Material:
	if _m.has(key):
		return _m[key]
	var r: StandardMaterial3D
	match key:
		"car_white":
			r = MeshKit.std_mat(Color(0.60, 0.62, 0.67), 0.42, 0.0, 0.55)
			r.clearcoat_enabled = true
			r.clearcoat = 0.3
			r.clearcoat_roughness = 0.22
		"van_navy":
			r = MeshKit.std_mat(Color(0.035, 0.06, 0.14), 0.42, 0.0, 0.7)
			r.clearcoat_enabled = true
			r.clearcoat = 0.5
			r.clearcoat_roughness = 0.2
		"glass":
			r = MeshKit.std_mat(Color(0.03, 0.045, 0.07), 0.04, 0.2, 1.0)
		"tire":
			r = MeshKit.std_mat(Color(0.025, 0.025, 0.03), 0.92, 0.0, 0.2)
		"hub":
			r = MeshKit.std_mat(Color(0.62, 0.64, 0.68), 0.3, 0.9, 0.7)
		"dark":
			r = MeshKit.std_mat(Color(0.04, 0.04, 0.05), 0.6, 0.0, 0.5)
		"plastic":
			r = MeshKit.std_mat(Color(0.12, 0.13, 0.15), 0.7, 0.0, 0.4)
		"chrome":
			r = MeshKit.std_mat(Color(0.7, 0.72, 0.76), 0.2, 1.0, 0.8)
		"head":
			r = MeshKit.std_mat(Color(0.95, 0.93, 0.8), 0.15, 0.0, 1.0)
			r.emission_enabled = true
			r.emission = Color(1.0, 0.95, 0.75)
			r.emission_energy_multiplier = 1.4
		"tail":
			r = MeshKit.std_mat(Color(0.5, 0.02, 0.02), 0.2, 0.0, 0.8)
			r.emission_enabled = true
			r.emission = Color(1.0, 0.05, 0.03)
			r.emission_energy_multiplier = 0.9
		"bar_base":
			r = MeshKit.std_mat(Color(0.03, 0.03, 0.035), 0.5, 0.0, 0.5)
		"plate":
			r = MeshKit.std_mat(Color(0.9, 0.9, 0.85), 0.5)
		_:
			r = MeshKit.std_mat(Color(0.5, 0.5, 0.5))
	_m[key] = r
	return r


static func _decal_mat(file: String) -> StandardMaterial3D:
	var key := "decal_" + file
	if _m.has(key):
		return _m[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(Props.DIR + file)
	m.albedo_color = Color(0.72, 0.72, 0.74)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.metallic_specular = 0.5
	_m[key] = m
	return m


static func _section(z: float, y0: float, y1: float, hw0: float, hw1: float, e: float, n: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var cy := (y0 + y1) * 0.5
	var hh := (y1 - y0) * 0.5
	for i in n:
		var a := TAU * float(i) / n
		var c := cos(a)
		var s := sin(a)
		var sx := signf(c) * pow(absf(c), 2.0 / e)
		var sy := signf(s) * pow(absf(s), 2.0 / e)
		var hw := lerpf(hw0, hw1, (sy + 1.0) * 0.5)
		pts.append(Vector3(sx * hw, cy + sy * hh, z))
	return pts


## Arc supérieur seulement (toit) décalé vers l'extérieur
static func _arc(z: float, y0: float, y1: float, hw0: float, hw1: float, e: float, n: int, a0: float, a1: float, grow: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var cy := (y0 + y1) * 0.5
	var hh := (y1 - y0) * 0.5
	for i in n:
		var a := lerpf(a0, a1, float(i) / (n - 1))
		var c := cos(a)
		var s := sin(a)
		var sx := signf(c) * pow(absf(c), 2.0 / e)
		var sy := signf(s) * pow(absf(s), 2.0 / e)
		var hw := lerpf(hw0, hw1, (sy + 1.0) * 0.5)
		pts.append(Vector3(sx * (hw + grow), cy + sy * (hh + grow), z))
	return pts


func _add(mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, parent: Node = null, shadow := true) -> MeshInstance3D:
	var mi := MeshKit.mesh_instance(mesh, m, pos, rot, parent if parent else _body)
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _box(size: Vector3, m: Material, pos: Vector3, rot := Vector3.ZERO, parent: Node = null, r := 0.012) -> MeshInstance3D:
	var key := "box%s%s" % [str(size), str(r)]
	if not _meshes.has(key):
		_meshes[key] = MeshKit.rbox(size, r, 2)
	return _add(_meshes[key], m, pos, rot, parent)


func _decal(file: String, size: Vector2, pos: Vector3, rot: Vector3, parent: Node = null) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := _add(q, _decal_mat(file), pos, rot, parent, false)
	return mi


func _wheel(pos: Vector3, r: float, w: float, steer: bool) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	_body.get_parent().add_child(pivot)     # roues hors du tangage de la caisse
	var spin := Node3D.new()
	pivot.add_child(spin)
	var tire := CylinderMesh.new()
	tire.top_radius = r
	tire.bottom_radius = r
	tire.height = w
	tire.radial_segments = 20
	var ti := MeshKit.mesh_instance(tire, mat("tire"), Vector3.ZERO, Vector3(0, 0, PI / 2.0), spin)
	var hub := CylinderMesh.new()
	hub.top_radius = r * 0.62
	hub.bottom_radius = r * 0.62
	hub.height = w + 0.01
	hub.radial_segments = 16
	MeshKit.mesh_instance(hub, mat("hub"), Vector3.ZERO, Vector3(0, 0, PI / 2.0), spin)
	# boulons : repère visuel de la rotation
	for k in 5:
		var a := TAU * float(k) / 5.0
		_box(Vector3(w + 0.02, 0.05, 0.05), mat("dark"), Vector3(0, sin(a) * r * 0.3, cos(a) * r * 0.3), Vector3(a, 0, 0), spin, 0.01)
	_spin.append(spin)
	if steer:
		_front_wheels.append(pivot)
	_wheel_r = r


# ------------------------------------------------------------------ voiture
func build(k: String) -> void:
	kind = k
	_body = Node3D.new()
	_body.name = "Caisse"
	var holder := Node3D.new()
	holder.name = "Chassis"
	add_child(holder)
	holder.add_child(_body)
	if kind == "car":
		_build_car()
	else:
		_build_truck()
	_build_collision()
	_build_sounds()
	add_to_group("vehicles")
	add_to_group("kickable")
	damage = VehicleDamage.new()
	damage.name = "Degats"
	add_child(damage)
	damage.setup(self)


func _build_car() -> void:
	half = Vector2(0.95, 2.25)
	_hw = 0.95
	var low := [[-2.2, 0.44, 0.66, 0.60], [-2.12, 0.34, 0.76, 0.78], [-1.9, 0.30, 0.82, 0.86], [-1.4, 0.28, 0.90, 0.90], [-0.95, 0.28, 0.95, 0.91],
		[-0.2, 0.28, 0.98, 0.91], [0.8, 0.28, 0.98, 0.91], [1.45, 0.28, 0.97, 0.90], [1.95, 0.30, 0.95, 0.88], [2.15, 0.36, 0.86, 0.80], [2.2, 0.46, 0.74, 0.62]]
	var rings: Array = []
	for s in low:
		rings.append(_section(s[0], s[1], s[2], s[3], s[3] * 0.97, 4.0, 28))
	_add(MeshKit.loft(rings, true, true), mat("car_white"))
	# habitacle vitré
	var gh := [[-0.95, 0.95, 0.99, 0.80, 0.78], [-0.6, 0.96, 1.24, 0.79, 0.72], [-0.2, 0.97, 1.40, 0.77, 0.67], [0.45, 0.97, 1.44, 0.77, 0.66], [1.0, 0.97, 1.41, 0.77, 0.67],
		[1.45, 0.96, 1.22, 0.79, 0.72], [1.85, 0.95, 0.99, 0.83, 0.80]]
	var grings: Array = []
	for s in gh:
		grings.append(_section(s[0], s[1], s[2], s[3], s[4], 3.0, 24))
	glass_loft = _add(MeshKit.loft(grings, true, true), mat("glass"), Vector3.ZERO, Vector3.ZERO, null, false)
	# toit et montants carrosserie
	var roof: Array = []
	for s in gh:
		roof.append(_arc(s[0], s[1], s[2], s[3], s[4], 3.0, 12, deg_to_rad(28), deg_to_rad(152), 0.012))
	_add(MeshKit.loft(roof, false, false), mat("car_white"))
	# montants : bandes sombres plaquées sur la vitre (A, B, C)
	for sx in [-1.0, 1.0]:
		for pz in [0.38]:
			_box(Vector3(0.02, 0.44, 0.07), mat("dark"), Vector3(sx * 0.775, 1.2, pz), Vector3(0, 0, sx * 0.12), null, 0.005)
	# pare-chocs, calandre, optiques
	_box(Vector3(1.5, 0.22, 0.14), mat("plastic"), Vector3(0, 0.46, -2.2), Vector3.ZERO, null, 0.04)
	_box(Vector3(0.9, 0.12, 0.05), mat("dark"), Vector3(0, 0.62, -2.18), Vector3.ZERO, null, 0.02)
	_box(Vector3(1.5, 0.22, 0.14), mat("plastic"), Vector3(0, 0.5, 2.2), Vector3.ZERO, null, 0.04)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.34, 0.1, 0.06), mat("head"), Vector3(sx * 0.66, 0.74, -2.15), Vector3(0, sx * 0.15, 0), null, 0.03)
		_box(Vector3(0.3, 0.1, 0.06), mat("tail"), Vector3(sx * 0.66, 0.78, 2.17), Vector3(0, -sx * 0.15, 0), null, 0.03)
		# rétroviseurs
		_box(Vector3(0.12, 0.1, 0.16), mat("dark"), Vector3(sx * 0.98, 1.0, -0.8), Vector3.ZERO, null, 0.03)
	# plaque
	_box(Vector3(0.5, 0.11, 0.02), mat("plate"), Vector3(0, 0.62, 2.27), Vector3.ZERO, null, 0.005)
	# portières (panneaux articulés : s'ouvrent à la sortie de l'équipage)
	for sx in [-1.0, 1.0]:
		for dn in [["f", -0.92, 0.84], ["r", -0.04, 0.82]]:
			var pivot := Node3D.new()
			pivot.position = Vector3(sx * 0.915, 0.0, dn[1])
			_body.add_child(pivot)
			_box(Vector3(0.035, 0.52, dn[2] - 0.03), mat("car_white"), Vector3(0, 0.66, dn[2] * 0.5), Vector3.ZERO, pivot, 0.012)
			_box(Vector3(0.04, 0.012, dn[2] - 0.06), mat("dark"), Vector3(sx * 0.003, 0.9, dn[2] * 0.5), Vector3.ZERO, pivot, 0.003)
			doors[("L" if sx > 0.0 else "R") + dn[0]] = pivot
	# bandes et lettrage
	for sx in [-1.0, 1.0]:
		_decal("pol_side.png", Vector2(2.3, 0.48), Vector3(sx * 0.936, 0.66, 0.1), Vector3(0, sx * PI / 2.0, 0), null)
		# passages de roues
		for wz in [-1.35, 1.32]:
			var arch := _decal("pol_text_blue.png", Vector2(0.01, 0.01), Vector3.ZERO, Vector3.ZERO, null)
			arch.queue_free()
	_decal("pol_text_blue.png", Vector2(1.1, 0.42), Vector3(0, 0.945, -1.28), Vector3(-PI / 2.0 + 0.09, 0, 0), null)
	# gyrophares de toit
	_build_bar(Vector3(0, 1.47, 0.25), 1.0, 0.26)
	# roues
	for sz in [-1.35, 1.32]:
		for sx in [-1.0, 1.0]:
			_wheel(Vector3(sx * 0.84, 0.33, sz), 0.33, 0.24, sz < 0.0)


func _build_bar(pos: Vector3, w: float, d: float) -> void:
	_box(Vector3(w, 0.05, d), mat("bar_base"), pos, Vector3.ZERO, null, 0.012)
	_bar_a = MeshKit.std_mat(Color(0.05, 0.1, 0.5), 0.15, 0.0, 1.0)
	_bar_a.emission_enabled = true
	_bar_a.emission = Color(0.1, 0.25, 1.0)
	_bar_a.emission_energy_multiplier = 0.0
	_bar_b = MeshKit.std_mat(Color(0.05, 0.1, 0.5), 0.15, 0.0, 1.0)
	_bar_b.emission_enabled = true
	_bar_b.emission = Color(0.1, 0.25, 1.0)
	_bar_b.emission_energy_multiplier = 0.0
	for sx in [-1.0, 1.0]:
		var lens := _box(Vector3(w * 0.46, 0.085, d * 0.92), _bar_a if sx < 0.0 else _bar_b, pos + Vector3(sx * w * 0.245, 0.06, 0), Vector3.ZERO, null, 0.03)
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var l := OmniLight3D.new()
		l.light_color = Color(0.2, 0.35, 1.0)
		l.omni_range = 16.0
		l.light_energy = 0.0
		l.position = pos + Vector3(sx * w * 0.25, 0.4, 0)
		_body.add_child(l)
		_bar_lights.append(l)


# ------------------------------------------------------------------ fourgon de CRS
func _build_truck() -> void:
	half = Vector2(1.12, 3.25)
	_hw = 1.12
	var st := [[-3.2, 0.56, 1.0, 0.86], [-3.12, 0.44, 1.3, 1.0], [-2.9, 0.42, 1.52, 1.07], [-2.55, 0.4, 2.3, 1.1], [-1.52, 0.4, 2.36, 1.1],
		[-1.46, 0.4, 2.8, 1.1], [3.1, 0.4, 2.8, 1.1], [3.2, 0.5, 2.62, 1.06]]
	var rings: Array = []
	for s in st:
		rings.append(_section(s[0], s[1], s[2], s[3], s[3] * 0.98, 6.0, 28))
	_add(MeshKit.loft(rings, true, true), mat("van_navy"))
	# pare-brise et vitres
	var ws := _box(Vector3(1.9, 0.8, 0.04), mat("glass"), Vector3(0, 1.91, -2.745), Vector3(deg_to_rad(24), 0, 0), null, 0.02)
	ws.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass_meshes.append(ws)
	for sx in [-1.0, 1.0]:
		var cw := _box(Vector3(0.04, 0.78, 1.0), mat("glass"), Vector3(sx * 1.098, 1.88, -2.0), Vector3.ZERO, null, 0.015)
		cw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glass_meshes.append(cw)
		for z in [-0.35, 0.95, 2.2]:
			var bw := _box(Vector3(0.04, 0.62, 0.95), mat("glass"), Vector3(sx * 1.098, 2.1, z), Vector3.ZERO, null, 0.015)
			bw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_decal("grille.png", Vector2(0.95, 0.62), Vector3(sx * 1.122, 2.1, z), Vector3(0, sx * PI / 2.0, 0), null)
		# bande blanche et lettrage
		_decal("pol_van_side.png", Vector2(3.3, 0.58), Vector3(sx * 1.108, 1.25, 1.0), Vector3(0, sx * PI / 2.0, 0), null)
		# rétroviseurs
		_box(Vector3(0.14, 0.34, 0.2), mat("dark"), Vector3(sx * 1.28, 1.72, -2.4), Vector3.ZERO, null, 0.04)
		# phares / feux
		_box(Vector3(0.36, 0.14, 0.06), mat("head"), Vector3(sx * 0.7, 0.86, -3.16), Vector3(0, sx * 0.1, 0), null, 0.03)
		_box(Vector3(0.16, 0.5, 0.06), mat("tail"), Vector3(sx * 1.0, 0.98, 3.17), Vector3(0, -sx * 0.1, 0), null, 0.03)
	# calandre, pare-chocs
	_box(Vector3(1.1, 0.34, 0.06), mat("dark"), Vector3(0, 0.88, -3.12), Vector3.ZERO, null, 0.02)
	_box(Vector3(2.02, 0.26, 0.2), mat("plastic"), Vector3(0, 0.5, -3.2), Vector3.ZERO, null, 0.05)
	_box(Vector3(2.0, 0.24, 0.2), mat("plastic"), Vector3(0, 0.5, 3.2), Vector3.ZERO, null, 0.05)
	# hayon : portes arrière à deux battants
	for sx in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(sx * 1.08, 0.0, 3.17)
		_body.add_child(pivot)
		_box(Vector3(1.06, 1.9, 0.05), mat("van_navy"), Vector3(-sx * 0.53, 1.55, 0.0), Vector3.ZERO, pivot, 0.015)
		var rw := _box(Vector3(0.62, 0.5, 0.06), mat("glass"), Vector3(-sx * 0.53, 2.1, 0.01), Vector3.ZERO, pivot, 0.012)
		rw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		doors["B" + ("L" if sx > 0.0 else "R")] = pivot
	_decal("pol_text_white.png", Vector2(1.0, 0.4), Vector3(0, 1.4, 3.215), Vector3(0, 0, 0), null)
	_decal("pol_text_white.png", Vector2(1.1, 0.42), Vector3(0, 1.06, -3.205), Vector3(0, PI, 0), null)
	# portières de cabine
	for sx in [-1.0, 1.0]:
		var piv := Node3D.new()
		piv.position = Vector3(sx * 1.108, 0.0, -2.55)
		_body.add_child(piv)
		_box(Vector3(0.03, 1.0, 1.1), mat("van_navy"), Vector3(0, 1.15, 0.55), Vector3.ZERO, piv, 0.01)
		doors[("L" if sx > 0.0 else "R") + "f"] = piv
	# gyrophares
	_build_bar(Vector3(0, 2.4, -2.0), 1.7, 0.3)
	# roues
	for sz in [-2.05, 1.9]:
		for sx in [-1.0, 1.0]:
			_wheel(Vector3(sx * 0.95, 0.45, sz), 0.45, 0.3, sz < 0.0)


func _build_collision() -> void:
	_static_body = StaticBody3D.new()
	_static_body.collision_layer = 1
	_static_body.collision_mask = 0
	add_child(_static_body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	if kind == "car":
		bs.size = Vector3(1.84, 0.7, 4.4)
		cs.position = Vector3(0, 0.62, 0)
	else:
		bs.size = Vector3(2.2, 2.2, 6.4)
		cs.position = Vector3(0, 1.5, 0)
	cs.shape = bs
	_static_body.add_child(cs)
	if kind == "car":
		var cs2 := CollisionShape3D.new()
		var b2 := BoxShape3D.new()
		b2.size = Vector3(1.5, 0.5, 2.3)
		cs2.shape = b2
		cs2.position = Vector3(0, 1.2, 0.3)
		_static_body.add_child(cs2)
	_static_body.set_meta("vehicle", self)


func _build_sounds() -> void:
	_siren = AudioStreamPlayer3D.new()
	_siren.stream = AudioLib.stream("pol_siren_loop", true)
	_siren.unit_size = 30.0
	_siren.max_distance = 600.0
	_siren.volume_db = -4.0
	add_child(_siren)
	_engine = AudioStreamPlayer3D.new()
	_engine.stream = AudioLib.stream("engine_idle_loop" if kind == "truck" else "engine_car_loop", true)
	_engine.unit_size = 8.0
	_engine.max_distance = 150.0
	_engine.volume_db = -60.0
	add_child(_engine)
	# grésillement de la radio de bord, audible seulement de près
	_radio = AudioStreamPlayer3D.new()
	_radio.stream = AudioLib.stream("radio_static_loop", true)
	_radio.unit_size = 1.6
	_radio.max_distance = 22.0
	_radio.volume_db = -20.0
	_radio.position = Vector3(0, 1.3, -1.2)
	add_child(_radio)


# ------------------------------------------------------------------ pilotage
func set_lights(on: bool, with_siren := false) -> void:
	lights_on = on
	siren_on = with_siren and on
	if siren_on and not _siren.playing:
		_siren.stream = AudioLib.stream("pol_siren_wail" if urgent else "pol_siren_loop", true)
		_siren.play(randf() * maxf(_siren.stream.get_length() - 0.1, 0.0))   # départ décalé, dans la boucle
	elif not siren_on and _siren.playing:
		_siren.stop()
	if on and not _radio.playing:
		_radio.play(randf() * maxf(_radio.stream.get_length() - 0.1, 0.0))
	elif not on and _radio.playing:
		_radio.stop()
	if not on:
		for l in _bar_lights:
			l.light_energy = 0.0
		if _bar_a:
			_bar_a.emission_energy_multiplier = 0.0
			_bar_b.emission_energy_multiplier = 0.0


## Roule le long du chemin (liste de points monde) puis se gare au dernier point, orienté `park_yaw`.
func drive(path: Array[Vector3], park_yaw: float, spd := 11.0) -> void:
	_path = path.duplicate()
	max_speed = spd
	state = "driving"
	set_meta("park_yaw", park_yaw)
	if not _engine.playing:
		_engine.play(randf() * 2.0)


func is_parked() -> bool:
	return state == "parked"


## Positions de sortie des passagers (monde) : cabine, ou portes arrière du fourgon
func exit_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if kind == "car":
		for d in [Vector3(-1.5, 0, -0.5), Vector3(1.5, 0, -0.5), Vector3(-1.5, 0, 0.5), Vector3(1.5, 0, 0.5)]:
			out.append(global_transform * d)
	else:
		for i in 8:
			out.append(global_transform * Vector3(((i % 3) - 1) * 0.6, 0, 3.9 + (i / 3) * 0.7))
	return out


func open_doors(names: Array, on := true) -> void:
	for n in names:
		if not doors.has(n):
			continue
		var d: Node3D = doors[n]
		var sx := -1.0 if String(n).begins_with("R") else 1.0
		var ang := 1.15
		var target := 0.0
		if String(n).begins_with("B"):
			target = (1.8 if String(n).ends_with("R") else -1.8) if on else 0.0
			# les battants arrière pivotent sur Y
			var tw := create_tween()
			tw.tween_property(d, "rotation:y", target, 0.7).set_trans(Tween.TRANS_QUAD)
		else:
			target = (ang * (-sx)) if on else 0.0
			var tw2 := create_tween()
			tw2.tween_property(d, "rotation:y", target, 0.45).set_trans(Tween.TRANS_QUAD)
	var cargo := false
	for n in names:
		cargo = cargo or String(n).begins_with("B")
	if cargo:
		AudioLib.play_at(self, "door_slide", global_transform * Vector3(0, 1.2, 3.2), -1.0, 9.0, randf_range(0.92, 1.05))
	AudioLib.play_at(self, "door_open" if on else "door_close", global_position + Vector3.UP, -2.0, 10.0)


func _physics_process(delta: float) -> void:
	_t += delta
	# gyrophares
	if lights_on:
		var ph := fmod(_t, 0.5)
		var a := 1.0 if ph < 0.25 else 0.0
		if _bar_a:
			_bar_a.emission_energy_multiplier = lerpf(_bar_a.emission_energy_multiplier, 6.0 * a + 0.4, minf(1.0, delta * 30.0))
			_bar_b.emission_energy_multiplier = lerpf(_bar_b.emission_energy_multiplier, 6.0 * (1.0 - a) + 0.4, minf(1.0, delta * 30.0))
		for i in _bar_lights.size():
			var on := a if i == 0 else 1.0 - a
			_bar_lights[i].light_energy = lerpf(_bar_lights[i].light_energy, 4.5 * on, minf(1.0, delta * 30.0))
	var vol := -60.0
	if state == "driving" or state == "braking":
		vol = linear_to_db(clampf(speed / 12.0 + 0.2, 0.05, 1.0)) - 4.0
	elif state == "parked" and _engine.playing and _engine.volume_db > -50.0 and not lights_on:
		vol = -60.0
	elif state == "parked":
		vol = -22.0 if lights_on else -60.0
	_engine.volume_db = lerpf(_engine.volume_db, vol, minf(1.0, delta * 3.0))
	# appels radio de temps en temps quand le véhicule est en faction
	if lights_on and state == "parked":
		_squelch_t -= delta
		if _squelch_t <= 0.0:
			_squelch_t = randf_range(7.0, 16.0)
			AudioLib.play_at(self, "radio_squelch", global_transform * _radio.position, -8.0, 3.0, randf_range(0.95, 1.05))
	_engine.pitch_scale = 0.7 + speed * 0.05
	if state == "parked" and not lights_on and _engine.playing and _engine.volume_db < -55.0:
		_engine.stop()
	_drive(delta)
	# roues
	for s in _spin:
		s.rotation.x -= speed * delta / _wheel_r
	_steer = lerpf(_steer, _steer_target, minf(1.0, delta * 6.0))
	for w in _front_wheels:
		w.rotation.y = _steer
	_pitch = lerpf(_pitch, _pitch_target, minf(1.0, delta * 4.0))
	# rebond de suspension après un choc (ressort amorti)
	_bounce_v += (-_bounce * 140.0 - _bounce_v * 9.0) * delta
	_bounce += _bounce_v * delta
	_roll_v += (-_roll * 120.0 - _roll_v * 8.0) * delta
	_roll += _roll_v * delta
	if _body:
		_body.rotation.x = _pitch
		_body.rotation.z = _roll
		_body.position.y = _bounce - sag


var _steer_target := 0.0
var _pitch_target := 0.0


func _drive(delta: float) -> void:
	if state == "parked" or _path.is_empty():
		speed = move_toward(speed, 0.0, 8.0 * delta)
		_pitch_target = 0.0
		_steer_target = 0.0
		return
	var tgt := _path[0]
	var to := tgt - global_position
	to.y = 0.0
	var dist := to.length()
	var last := _path.size() == 1
	# freinage avant le dernier point
	var want := max_speed
	if last:
		want = minf(max_speed, sqrt(maxf(2.0 * 4.5 * maxf(dist - 0.2, 0.0), 0.0)) + 0.6)
	# obstacle devant (personne / véhicule)
	var fwd := -global_basis.z
	if _blocked(fwd):
		want = 0.0
		_blocked_t += delta
	else:
		_blocked_t = 0.0
	var acc := 3.2 if want > speed else 7.5
	speed = move_toward(speed, want, acc * delta)
	_pitch_target = clampf((speed - want) * -0.004 - (0.02 if want < speed else 0.0), -0.04, 0.04)
	# direction
	if dist > 0.15:
		var want_yaw := atan2(-to.x, -to.z)
		var err := wrapf(want_yaw - rotation.y, -PI, PI)
		var max_turn := clampf(speed * 0.45, 0.0, 1.6) * delta
		rotation.y += clampf(err, -max_turn, max_turn)
		_steer_target = clampf(err, -0.5, 0.5)
	global_position += -global_basis.z * speed * delta
	if dist < 0.35 or (last and dist < 0.5 and speed < 0.4):
		_path.pop_front()
		if _path.is_empty():
			_finish_parking()


func _finish_parking() -> void:
	var yaw: float = get_meta("park_yaw", rotation.y)
	rotation.y = yaw
	speed = 0.0
	state = "parked"
	_steer_target = 0.0
	if crowd:
		crowd.add_obstacle(self, half, Vector2.ZERO, false, true)
		crowd.nav_dirty()
	if _relocating:
		_relocating = false      # simple changement de place : l'équipage est déjà sorti
		return
	parked.emit()


## Le véhicule suit la ligne qui avance : il redémarre et se gare plus près du dispositif
func relocate(dest: Vector3, spd := 5.5) -> void:
	if state != "parked" or burning:
		return
	if crowd:
		crowd.remove_obstacle(self)
		crowd.nav_dirty()
	_relocating = true
	var path: Array[Vector3] = [dest]
	_path = path
	max_speed = spd
	state = "driving"
	set_meta("park_yaw", rotation.y)
	if not _engine.playing:
		_engine.play(randf() * 2.0)


func _blocked(fwd: Vector3) -> bool:
	if speed < 0.5:
		return false
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 0.9, 0) + fwd * (half.y + 0.2)
	var to := from + fwd * (2.2 + speed * 0.45)
	var q := PhysicsRayQueryParameters3D.create(from, to, 16 | 4)   # acteurs (16) et joueur
	q.collide_with_areas = false
	var r := space.intersect_ray(q)
	if r:
		return true
	# le joueur (couche 1) : proche devant
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl:
		var d := pl.global_position - global_position
		if d.dot(fwd) > 0.0 and d.dot(fwd) < half.y + 2.5 + speed * 0.4 and absf(d.dot(fwd.cross(Vector3.UP))) < half.x + 0.5:
			return true
	return false


## Écran de vérification : retourne un nœud du véhicule
func get_door(n: String) -> Node3D:
	return doors.get(n)


# ------------------------------------------------------------------ vandalisme
## Coup de pied ou de poing sur la carrosserie : bosse et secousse (les vitres ont leur propre réaction)
func kick(point: Vector3, dir: Vector3, power := 1.0) -> bool:
	if damage == null:
		return false
	for p in damage.panes:
		if is_instance_valid(p) and p.alive() and p.contains(point, 0.35, Vector2(0.05, 0.05)) >= 0.0:
			return false
	return damage.hit_body(point, dir, power)


## Secousse de suspension : `power` ~0.5 (coup) à 2 (explosion), `n` normale de l'impact
func bump(power: float, n := Vector3.UP) -> void:
	_bounce_v -= 0.5 * power * (1.0 if n.y < 0.5 else 0.3)
	var side := global_basis.inverse() * n
	_roll_v += clampf(-side.x, -1.0, 1.0) * 0.5 * power


# interface commune des foyers (foule) : voir VehicleDamage
func fire_center() -> Vector3:
	return damage.fire_center() if damage else global_position


func stand_pos(from: Vector3) -> Vector3:
	return damage.stand_pos(from) if damage else global_position


func hand_target() -> Vector3:
	return fire_center()


func can_take_items() -> bool:
	return false


func feed_item(_item: Node3D, _from: Vector3) -> bool:
	return false


func ring_radius() -> float:
	return 4.2 + (1.2 if kind == "truck" else 0.0)
