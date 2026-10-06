class_name Human
extends Node3D
## Personnage humain procédural : corps lofté (sections elliptiques), visage,
## vêtements, animation de marche/course/saut et IK 2 os pour les bras.

const THIGH := 0.44
const SHIN := 0.43
const UPPER_ARM := 0.30
const FOREARM := 0.27
const HIP_Y := 0.92
const HEAD_LAYER := 2 # calque visuel masqué par la caméra 1re personne

var pelvis: Node3D
var torso: Node3D
var neck: Node3D
var head: Node3D
var thigh := [null, null]
var knee := [null, null]
var ankle := [null, null]
var shoulder := [null, null]
var elbow := [null, null]
var torso_mesh: MeshInstance3D
var head_meshes: Array[MeshInstance3D] = []

var phase := 0.0
var t_idle := 0.0
var air_t := 0.0
var kick := 0.0 # recul (0..1) ajouté au haut du corps
var look_pitch := 0.0

# IK : positions monde des mains (null = animation libre)
var hand_provider := Callable() # renvoie [main droite, main gauche] en monde, ou null


# ---------------------------------------------------------------- mesh utils

## rings : Array[Vector4(y, rx, rz, zoff)] ordonnés. Dôme automatique aux deux bouts.
static func loft(rings_in: Array, segs := 28, dome := 0.9) -> ArrayMesh:
	var first: Vector4 = rings_in[0]
	var last: Vector4 = rings_in[rings_in.size() - 1]
	var dir_first := signf(first.x - (rings_in[1] as Vector4).x)
	var dir_last := signf(last.x - (rings_in[rings_in.size() - 2] as Vector4).x)
	var rf := minf(first.y, first.z) * dome
	var rl := minf(last.y, last.z) * dome
	var rings: Array = []
	for a in [90.0, 68.0, 38.0]:
		var c := cos(deg_to_rad(a))
		var s := sin(deg_to_rad(a))
		rings.append(Vector4(first.x + dir_first * s * rf, first.y * c, first.z * c, first.w))
	rings.append_array(rings_in)
	for a in [38.0, 68.0, 90.0]:
		var c := cos(deg_to_rad(a))
		var s := sin(deg_to_rad(a))
		rings.append(Vector4(last.x + dir_last * s * rl, last.y * c, last.z * c, last.w))

	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := segs + 1
	for i in rings.size():
		var r: Vector4 = rings[i]
		for j in cols:
			var ang := TAU * float(j) / float(segs)
			verts.append(Vector3(cos(ang) * r.y, r.x, sin(ang) * r.z + r.w))
			uvs.append(Vector2(float(j) / segs, float(i) / (rings.size() - 1)))
	var idx := PackedInt32Array()
	for i in rings.size() - 1:
		for j in segs:
			var a := i * cols + j
			var b := a + 1
			var c := a + cols
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for t in range(0, idx.size(), 3):
		var p0 := verts[idx[t]]
		var fn := (verts[idx[t + 1]] - p0).cross(verts[idx[t + 2]] - p0)
		for k in 3:
			normals[idx[t + k]] += fn
	for i in rings.size(): # couture
		var m := normals[i * cols] + normals[i * cols + segs]
		normals[i * cols] = m
		normals[i * cols + segs] = m
	for i in normals.size():
		normals[i] = normals[i].normalized()
	# Godot : face avant = sens horaire. Si les normales calculées sortent vers
	# l'extérieur, les triangles sont anti-horaires -> on inverse l'ordre.
	var probe := rings.size() / 2
	var pr: Vector4 = rings[probe]
	var outward := verts[probe * cols] - Vector3(0, pr.x, pr.w)
	if normals[probe * cols].dot(outward) > 0.0:
		for t in range(0, idx.size(), 3):
			var tmp := idx[t + 1]
			idx[t + 1] = idx[t + 2]
			idx[t + 2] = tmp
	else:
		for i in normals.size():
			normals[i] = -normals[i]

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, is_head := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	if is_head:
		m.layers = HEAD_LAYER
		head_meshes.append(m)
	parent.add_child(m)
	return m


func _node(parent: Node3D, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


static func _mat(color: Color, rough := 0.85, extra := {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	for k in extra:
		m.set(k, extra[k])
	return m


func _sphere(r: float, scl := Vector3.ONE) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	return s


# ---------------------------------------------------------------------- build

func _ready() -> void:
	var skin := _mat(Color(0.90, 0.70, 0.58), 0.5, {
		"subsurf_scatter_enabled": true, "subsurf_scatter_strength": 0.35,
		"rim_enabled": true, "rim": 0.15, "rim_tint": 0.5})
	var hoodie := _mat(Color(0.20, 0.22, 0.27), 0.95, {"rim_enabled": true, "rim": 0.25, "rim_tint": 0.3})
	var pants := _mat(Color(0.13, 0.16, 0.26), 0.88)
	var shoe := _mat(Color(0.10, 0.10, 0.11), 0.6)
	var sole := _mat(Color(0.92, 0.92, 0.9), 0.5)
	var beanie := _mat(Color(0.10, 0.10, 0.12), 1.0)
	var eye_white := _mat(Color(0.95, 0.95, 0.93), 0.2)
	var iris := _mat(Color(0.18, 0.12, 0.08), 0.15)
	var lips := _mat(Color(0.62, 0.30, 0.28), 0.4)
	var brow := _mat(Color(0.12, 0.08, 0.06), 0.9)

	pelvis = _node(self, Vector3(0, HIP_Y, 0))
	# bassin / pantalon
	_mi(pelvis, loft([
		Vector4(-0.10, 0.145, 0.100, 0.0),
		Vector4(0.0, 0.158, 0.108, 0.0),
		Vector4(0.10, 0.146, 0.100, 0.0)]), pants)

	torso = _node(pelvis, Vector3(0, 0.10, 0))
	torso_mesh = _mi(torso, loft([
		Vector4(-0.20, 0.162, 0.108, 0.0),
		Vector4(-0.12, 0.150, 0.100, 0.0),
		Vector4(0.0, 0.138, 0.095, 0.0),
		Vector4(0.14, 0.150, 0.102, -0.004),
		Vector4(0.28, 0.175, 0.114, -0.010),
		Vector4(0.38, 0.195, 0.108, -0.004),
		Vector4(0.45, 0.150, 0.092, 0.0),
		Vector4(0.50, 0.080, 0.070, 0.0)]), hoodie)
	# capuche baissée autour du cou
	_mi(torso, loft([
		Vector4(0.44, 0.125, 0.112, 0.012),
		Vector4(0.50, 0.108, 0.105, 0.016),
		Vector4(0.57, 0.090, 0.088, 0.012)]), hoodie)

	neck = _node(torso, Vector3(0, 0.50, 0))
	_mi(neck, loft([
		Vector4(-0.02, 0.052, 0.054, 0.0),
		Vector4(0.10, 0.046, 0.048, -0.004)]), skin, Vector3.ZERO, true)
	head = _node(neck, Vector3(0, 0.14, -0.005))
	_build_head(head, skin, beanie, eye_white, iris, lips, brow)

	for side in 2:
		var sx := 1.0 if side == 0 else -1.0 # 0 = droite (+x), 1 = gauche (-x)
		# jambe
		thigh[side] = _node(pelvis, Vector3(0.088 * sx, 0.0, 0.0))
		_mi(thigh[side], loft([
			Vector4(0.0, 0.086, 0.090, 0.004),
			Vector4(-0.10, 0.082, 0.088, 0.004),
			Vector4(-0.24, 0.068, 0.076, 0.0),
			Vector4(-0.36, 0.056, 0.064, 0.0),
			Vector4(-0.44, 0.051, 0.056, 0.0)]), pants)
		knee[side] = _node(thigh[side], Vector3(0, -THIGH, 0))
		_mi(knee[side], loft([
			Vector4(0.0, 0.051, 0.056, 0.0),
			Vector4(-0.08, 0.056, 0.064, 0.008),
			Vector4(-0.18, 0.058, 0.068, 0.014),
			Vector4(-0.30, 0.044, 0.050, 0.008),
			Vector4(-0.43, 0.034, 0.036, 0.0)]), pants)
		ankle[side] = _node(knee[side], Vector3(0, -SHIN, 0))
		var foot := MeshInstance3D.new()
		foot.mesh = loft([
			Vector4(-0.075, 0.034, 0.036, 0.0),
			Vector4(0.0, 0.042, 0.046, 0.0),
			Vector4(0.10, 0.047, 0.040, 0.0),
			Vector4(0.19, 0.047, 0.030, 0.0),
			Vector4(0.255, 0.032, 0.022, 0.0)], 20, 0.8)
		foot.material_override = shoe
		foot.rotation = Vector3(-PI / 2.0, 0, 0)
		foot.position = Vector3(0, -0.012, 0)
		ankle[side].add_child(foot)
		var sole_m := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.095, 0.024, 0.335)
		sole_m.mesh = bx
		sole_m.material_override = sole
		sole_m.position = Vector3(0, -0.048, -0.093)
		ankle[side].add_child(sole_m)
		# bras
		shoulder[side] = _node(torso, Vector3(0.205 * sx, 0.395, 0.0))
		_mi(shoulder[side], _sphere(0.062), hoodie)
		_mi(shoulder[side], loft([
			Vector4(0.0, 0.060, 0.060, 0.0),
			Vector4(-0.10, 0.055, 0.056, 0.0),
			Vector4(-0.22, 0.047, 0.048, 0.0),
			Vector4(-UPPER_ARM, 0.043, 0.044, 0.0)]), hoodie)
		elbow[side] = _node(shoulder[side], Vector3(0, -UPPER_ARM, 0))
		_mi(elbow[side], loft([
			Vector4(0.0, 0.043, 0.044, 0.0),
			Vector4(-0.12, 0.040, 0.041, 0.0),
			Vector4(-FOREARM, 0.034, 0.034, 0.0)]), hoodie)
		var hand := _node(elbow[side], Vector3(0, -FOREARM, 0))
		_mi(hand, loft([
			Vector4(0.012, 0.027, 0.020, 0.0),
			Vector4(-0.03, 0.037, 0.018, 0.0),
			Vector4(-0.08, 0.039, 0.016, 0.0),
			Vector4(-0.125, 0.030, 0.013, 0.0)], 18, 0.9), skin)
		# pouce
		var th := _mi(hand, _sphere(0.014), skin, Vector3(-0.03 * sx, -0.045, -0.014))
		th.scale = Vector3(1, 2.2, 1)


func _build_head(h: Node3D, skin: Material, beanie: Material, eye_white: Material, iris: Material, lips: Material, brow: Material) -> void:
	# crâne / visage (le visage regarde vers -Z)
	_mi(h, loft([
		Vector4(-0.130, 0.030, 0.042, -0.046),
		Vector4(-0.100, 0.066, 0.070, -0.030),
		Vector4(-0.050, 0.085, 0.090, -0.012),
		Vector4(0.000, 0.094, 0.100, 0.000),
		Vector4(0.050, 0.096, 0.104, 0.004),
		Vector4(0.090, 0.082, 0.098, 0.006),
		Vector4(0.125, 0.055, 0.075, 0.006)], 32), skin, Vector3.ZERO, true)
	# bonnet
	_mi(h, loft([
		Vector4(0.030, 0.094, 0.109, 0.005),
		Vector4(0.070, 0.093, 0.107, 0.006),
		Vector4(0.110, 0.078, 0.092, 0.006),
		Vector4(0.150, 0.045, 0.058, 0.006)], 32), beanie, Vector3.ZERO, true)
	var bn := TorusMesh.new()
	bn.inner_radius = 0.094
	bn.outer_radius = 0.108
	var cuff := _mi(h, bn, beanie, Vector3(0, 0.032, 0.006), true)
	cuff.scale = Vector3(1.0, 0.55, 1.12)
	# yeux
	for sx in [-1.0, 1.0]:
		var eye := _mi(h, _sphere(0.0150), eye_white, Vector3(0.036 * sx, 0.012, -0.088), true)
		eye.scale = Vector3(1.15, 0.8, 0.8)
		var ir := _mi(h, _sphere(0.0085), iris, Vector3(0.036 * sx, 0.012, -0.0995), true)
		ir.scale = Vector3(1, 1, 0.5)
		var b := _mi(h, _sphere(0.02), brow, Vector3(0.034 * sx, 0.036, -0.088), true)
		b.scale = Vector3(1.5, 0.28, 0.5)
		b.rotation.z = -0.12 * sx
		var ear := _mi(h, _sphere(0.021), skin, Vector3(0.089 * sx, -0.005, 0.01), true)
		ear.scale = Vector3(0.45, 1.25, 0.85)
	var nose := _mi(h, _sphere(0.014), skin, Vector3(0, -0.022, -0.099), true)
	nose.scale = Vector3(0.85, 1.3, 1.1)
	var mouth := _mi(h, _sphere(0.02), lips, Vector3(0, -0.063, -0.083), true)
	mouth.scale = Vector3(1.35, 0.3, 0.5)


# -------------------------------------------------------------------- animate

func kick_back(amount := 1.0) -> void:
	kick = maxf(kick, amount)


## speed : vitesse horizontale (m/s) ; run_t : 0 marche -> 1 course
func animate(delta: float, speed: float, run_t: float, grounded: bool, vy: float, pitch: float) -> void:
	t_idle += delta
	kick = move_toward(kick, 0.0, delta * 3.2)
	look_pitch = lerpf(look_pitch, pitch, minf(1.0, delta * 10.0))

	var amount := clampf(speed / 1.8, 0.0, 1.0)
	if speed > 0.1:
		var cycle := lerpf(1.45, 2.5, run_t)
		phase += TAU * speed * delta / cycle
	var amp := lerpf(0.42, 0.85, run_t) * amount
	var knee_amp := lerpf(0.55, 1.5, run_t) * amount

	if grounded:
		air_t = move_toward(air_t, 0.0, delta * 6.0)
	else:
		air_t = move_toward(air_t, 1.0, delta * 8.0)

	var breath := sin(t_idle * 1.7) * 0.5 + 0.5
	for side in 2:
		var ph := phase + (0.0 if side == 0 else PI)
		var s := sin(ph)
		var c := cos(ph)
		var th_x := -s * amp
		var kn_x := (0.08 + maxf(0.0, c) * knee_amp + maxf(0.0, -s) * 0.12 * amount)
		# en l'air : jambes repliées
		th_x = lerpf(th_x, -0.55 + (0.35 if side == 1 else 0.0), air_t)
		kn_x = lerpf(kn_x, 0.95 - (0.4 if side == 1 else 0.0), air_t)
		(thigh[side] as Node3D).rotation = Vector3(th_x, 0.0, 0.025 * (1.0 if side == 0 else -1.0))
		(knee[side] as Node3D).rotation = Vector3(kn_x, 0, 0)
		(ankle[side] as Node3D).rotation = Vector3(-(th_x + kn_x) * 0.85 + 0.1 * s * amount, 0, 0)

	# bassin & torse
	var bob := absf(cos(phase)) * lerpf(0.018, 0.05, run_t) * amount
	pelvis.position.y = HIP_Y - 0.012 + bob - 0.05 * air_t
	pelvis.rotation = Vector3(0, sin(phase) * 0.10 * amount, sin(phase) * 0.03 * amount)
	var lean := lerpf(0.04, 0.26, run_t) * amount + 0.05 * clampf(-vy * 0.2, 0.0, 1.0) * air_t
	torso.rotation = Vector3(-lean + kick * 0.18, -sin(phase) * 0.14 * amount, -sin(phase) * 0.02 * amount)
	torso_mesh.scale = Vector3(1.0 + breath * 0.008, 1.0 + breath * 0.012, 1.0 + breath * 0.012)
	neck.rotation.x = lean * 0.6 - kick * 0.1
	head.rotation.x = clampf(-look_pitch * 0.55, -0.7, 0.7) - lean * 0.3

	# bras (animation libre si pas d'IK)
	var swing := lerpf(0.55, 1.1, run_t) * amount
	var targets: Array = [null, null]
	if hand_provider.is_valid():
		targets = hand_provider.call()
	for side in 2:
		var sh := shoulder[side] as Node3D
		var el := elbow[side] as Node3D
		if targets[side] != null:
			_solve_arm(side, targets[side])
		else:
			var ph := phase + (PI if side == 0 else 0.0)
			var sx := 1.0 if side == 0 else -1.0
			var idle_sway := sin(t_idle * 1.3 + side) * 0.02
			sh.rotation = Vector3(sin(ph) * swing + idle_sway + 0.07 * air_t * -1.0 - 0.9 * air_t, 0.0, sx * (0.07 + 0.06 * air_t + 0.04 * breath))
			el.rotation = Vector3(-(0.18 + run_t * 1.0 * amount + maxf(0.0, -sin(ph)) * 0.35 * amount) - 0.5 * air_t, 0, 0)


func _aim_down(node: Node3D, dir: Vector3) -> void:
	var y := -dir.normalized()
	var ref := global_basis * Vector3(0, 0, -1)
	var z := ref - y * ref.dot(y)
	if z.length() < 0.01:
		z = global_basis * Vector3(1, 0, 0)
		z -= y * z.dot(y)
	z = z.normalized()
	var x := y.cross(z)
	node.global_basis = Basis(x, y, z)


func _solve_arm(side: int, target: Vector3) -> void:
	var sh := shoulder[side] as Node3D
	var el := elbow[side] as Node3D
	var sx := 1.0 if side == 0 else -1.0
	var s := sh.global_position
	var to := target - s
	var d := clampf(to.length(), 0.08, (UPPER_ARM + FOREARM) * 0.998)
	var u := to.normalized()
	var pole := global_basis * Vector3(sx * 0.7, -1.0, 0.35)
	pole = (pole - u * pole.dot(u)).normalized()
	var x := (d * d + UPPER_ARM * UPPER_ARM - FOREARM * FOREARM) / (2.0 * d)
	var h := sqrt(maxf(UPPER_ARM * UPPER_ARM - x * x, 0.0))
	var e := s + u * x + pole * h
	_aim_down(sh, e - s)
	_aim_down(el, (s + u * d) - e)
