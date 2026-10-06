class_name Human
extends Node3D
## Personnage réaliste : modèle skinné (MakeHuman, CC0) généré par tools/build_character.py.
## Matériaux, tête masquable en 1re personne, animation procédurale (IK jambes/bras).

const MODEL_PATH := "res://assets/character/character.glb"
const DIR := "res://assets/character/"
const HEAD_LAYER := 2 # calque masqué par la caméra 1re personne

const PALM_TO_WRIST := 0.075   # centre de la paume -> articulation du poignet
const PALM_SIGN := -1.0        # signe de la normale de paume mesurée sur le modèle

var model: Node3D
var skeleton: Skeleton3D
var head_meshes: Array[MeshInstance3D] = []
var hand_provider := Callable() # -> [droite, gauche] : null ou {pos, f, p, curl} en coordonnées monde

var bone := {}       # nom -> index
var rest := {}       # nom -> position de repos (espace squelette)
var hand_f := {}     # "L"/"R" -> direction des doigts au repos
var palm_n := {}     # "L"/"R" -> normale de paume (côté paume)
var phase := 0.0
var t_idle := 0.0
var air := 0.0
var kick := 0.0
var look_pitch := 0.0
var _walk_w := 0.0
var _lean := 0.0


func _tex(file: String) -> Texture2D:
	return load(DIR + file) as Texture2D


func _ready() -> void:
	var scene: PackedScene = load(MODEL_PATH)
	var inst := scene.instantiate()
	model = Node3D.new()
	model.name = "Model"
	model.rotation.y = PI # le modèle regarde vers +Z ; Godot avance vers -Z
	add_child(model)
	model.add_child(inst)
	skeleton = _find_skeleton(inst)
	_apply_materials(inst)
	_cache_bones()


func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r:
			return r
	return null


func _std(color: Color, rough: float, normal_file := "", normal_scale := 1.0, uv_scale := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if normal_file != "":
		m.normal_enabled = true
		m.normal_texture = _tex(normal_file)
		m.normal_scale = normal_scale
		m.uv1_scale = Vector3(uv_scale, uv_scale, 1.0)
	return m


func _apply_materials(root: Node) -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_texture = _tex("skin_albedo.png")
	skin.roughness = 0.52
	skin.metallic_specular = 0.45
	skin.normal_enabled = true
	skin.normal_texture = _tex("skin_n.png")
	skin.normal_scale = 0.28
	skin.subsurf_scatter_enabled = true
	skin.subsurf_scatter_strength = 0.22

	var eye := StandardMaterial3D.new()
	eye.albedo_texture = _tex("eye_brown.png")
	eye.albedo_color = Color(1.25, 1.25, 1.2)
	eye.roughness = 0.22
	eye.metallic_specular = 0.5

	var hoodie := _std(Color(0.17, 0.19, 0.24), 0.96, "knit_n.png", 0.2, 6.0)
	var jeans := _std(Color.WHITE, 0.88, "denim_n.png", 0.12, 3.0)
	jeans.albedo_texture = _tex("denim_a.png")
	var beanie := _std(Color(0.06, 0.06, 0.08), 1.0, "rib_n.png", 0.8, 6.0)
	var shoes := _std(Color.WHITE, 0.62, "canvas_n.png", 0.12, 6.0)
	shoes.vertex_color_use_as_albedo = true

	var table := {
		"Body": skin, "Head": skin, "Eyes": eye,
		"Hoodie": hoodie, "Jeans": jeans, "Beanie": beanie, "Shoes": shoes,
	}
	for mi in _meshes(root):
		var nm := String(mi.name)
		if table.has(nm):
			mi.material_override = table[nm]
		if nm in ["Head", "Eyes", "Beanie"]:
			mi.layers = HEAD_LAYER
			head_meshes.append(mi)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.extra_cull_margin = 1.0



# ----------------------------------------------------------------- squelette

func _cache_bones() -> void:
	for i in skeleton.get_bone_count():
		var n := skeleton.get_bone_name(i)
		bone[n] = i
		rest[n] = skeleton.get_bone_global_rest(i).origin
	var f := FileAccess.open(DIR + "rig.json", FileAccess.READ)
	var info: Dictionary = JSON.parse_string(f.get_as_text())
	for side: String in ["L", "R"]:
		var ff := Vector3(info["hand_f_" + side][0], info["hand_f_" + side][1], info["hand_f_" + side][2])
		var pp := Vector3(info["palm_n_" + side][0], info["palm_n_" + side][1], info["palm_n_" + side][2])
		if side == "R": # la mesure PCA n'est fiable que sur L : on symétrise
			ff = Vector3(-info["hand_f_L"][0], info["hand_f_L"][1], info["hand_f_L"][2])
			pp = Vector3(-info["palm_n_L"][0], info["palm_n_L"][1], info["palm_n_L"][2])
		hand_f[side] = ff.normalized()
		palm_n[side] = (pp * PALM_SIGN).normalized()


func chest_xf() -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone["spine02"])


func shoulder_world(side: String) -> Vector3:
	return skeleton.global_transform * _gp("upperarm01_" + side)


func kick_back(amount := 1.0) -> void:
	kick = maxf(kick, amount)


func _gq(n: String) -> Quaternion:
	return skeleton.get_bone_global_pose(bone[n]).basis.get_rotation_quaternion()


func _gp(n: String) -> Vector3:
	return skeleton.get_bone_global_pose(bone[n]).origin


func _parent_of(n: String) -> String:
	return skeleton.get_bone_name(skeleton.get_bone_parent(bone[n]))


## Fixe la rotation locale d'un os (repère de repos = repère monde du squelette)
func _local(n: String, q: Quaternion) -> void:
	skeleton.set_bone_pose_rotation(bone[n], q)


## Oriente un os (rotation globale `q`) : convertit en rotation locale selon le parent courant
func _global(n: String, q: Quaternion) -> void:
	var p := _parent_of(n)
	skeleton.set_bone_pose_rotation(bone[n], _gq(p).inverse() * q)


## Fait pointer l'os `n`, dont la direction de repos est rest_dir, vers new_dir
func _aim(n: String, rest_dir: Vector3, new_dir: Vector3) -> void:
	_global(n, Quaternion(rest_dir.normalized(), new_dir.normalized()))


func _to_skel(p: Vector3) -> Vector3:
	return skeleton.global_transform.affine_inverse() * p


func _dir_to_skel(d: Vector3) -> Vector3:
	return skeleton.global_transform.basis.inverse() * d


## IK 2 os : renvoie la position du coude/genou
func _mid_joint(a: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Array:
	var to := target - a
	var d := clampf(to.length(), 0.05, (l1 + l2) * 0.999)
	var u := to.normalized()
	var po := (pole - u * pole.dot(u)).normalized()
	var x := (d * d + l1 * l1 - l2 * l2) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	return [a + u * x + po * h, a + u * d]


func _solve_limb(upper: String, lower: String, end: String, target: Vector3, pole: Vector3) -> void:
	var a := _gp(upper)
	var l1: float = (rest[lower] - rest[upper]).length()
	var l2: float = (rest[end] - rest[lower]).length()
	var r := _mid_joint(a, target, l1, l2, pole)
	var m: Vector3 = r[0]
	var e: Vector3 = r[1]
	_aim(upper, rest[lower] - rest[upper], m - a)
	_aim(lower, rest[end] - rest[lower], e - m)


func _curl_fingers(side: String, amount: float, thumb := 0.4) -> void:
	var axis: Vector3 = hand_f[side].cross(palm_n[side]).normalized()
	for fi in range(1, 6):
		var k := thumb if fi == 1 else 1.0
		var spread := 0.0
		for seg in range(1, 4):
			var nm := "finger%d-%d_%s" % [fi, seg, side]
			if not bone.has(nm):
				continue
			var ang := amount * k * (0.9 if seg == 1 else 1.0)
			_local(nm, Quaternion(axis, ang))


# ------------------------------------------------------------------ animation

## speed : vitesse horizontale (m/s) ; run_t : 0 marche -> 1 course ; pitch : regard vertical
func animate(delta: float, speed: float, run_t: float, grounded: bool, vy: float, pitch: float) -> void:
	if skeleton == null:
		return
	t_idle += delta
	kick = move_toward(kick, 0.0, delta * 2.6)
	look_pitch = lerpf(look_pitch, pitch, minf(1.0, delta * 10.0))
	air = move_toward(air, 0.0 if grounded else 1.0, delta * 7.0)

	var moving := speed > 0.15 and grounded
	_walk_w = move_toward(_walk_w, 1.0 if moving else 0.0, delta * 6.0)
	var period := lerpf(1.02, 0.60, run_t)
	if moving:
		phase = fposmod(phase + delta / period, 1.0)
	var beta := lerpf(0.62, 0.40, run_t)       # fraction d'appui
	var stride := speed * beta * period          # amplitude avant/arrière du pied (m)
	var w := _walk_w
	var breath := sin(t_idle * 1.6) * 0.5 + 0.5

	# --- bassin / colonne
	var dy := -(0.02 + 0.045 * run_t) * w - 0.012 * (1.0 - w) * 0.0
	dy += (0.012 + 0.03 * run_t) * w * (1.0 - cos(4.0 * PI * phase)) * 0.5
	dy -= 0.1 * air
	var root_rest: Vector3 = skeleton.get_bone_rest(bone["root"]).origin
	skeleton.set_bone_pose_position(bone["root"], root_rest + Vector3(0, dy, 0))
	var yaw := sin(TAU * phase) * 0.11 * w
	var roll := cos(TAU * phase) * 0.035 * w
	_lean = lerpf(_lean, (0.03 + 0.17 * run_t) * w + 0.05 * clampf(-vy * 0.15, 0.0, 1.0) * air, minf(1.0, delta * 6.0))
	skeleton.set_bone_pose_rotation(bone["root"], Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.BACK, roll))
	var spine := ["spine05", "spine04", "spine03", "spine02", "spine01"]
	for i in spine.size():
		var share := 1.0 / spine.size()
		var rx := _lean * share + kick * 0.05 + (breath - 0.5) * 0.004 + 0.0
		var ry := -yaw * 1.5 * share
		var rz := -roll * 1.2 * share
		if i == 0:
			rx -= 0.0
		_local(spine[i], Quaternion(Vector3.UP, ry) * Quaternion(Vector3.RIGHT, rx) * Quaternion(Vector3.BACK, rz))
	var hp := clampf(-look_pitch * 0.55, -0.9, 0.7)
	for nm in ["neck01", "neck02", "neck03"]:
		_local(nm, Quaternion(Vector3.RIGHT, hp * 0.18 - _lean * 0.12))
	_local("head", Quaternion(Vector3.RIGHT, hp * 0.46 - _lean * 0.1))

	# --- jambes (IK) : appui plat, balancier en arc
	for side: String in ["L", "R"]:
		var is_l := side == "L"
		var ph := fposmod(phase + (0.0 if is_l else 0.5), 1.0)
		var foot_rest: Vector3 = rest["foot_" + side]
		var z := 0.0
		var lift := 0.0
		var pitch_f := 0.0
		if ph < beta:
			var u := ph / beta
			z = stride * (0.5 - u)
			pitch_f = lerpf(0.18, -0.35, smoothstep(0.55, 1.0, u)) * (1.0 - smoothstep(0.0, 0.25, u) * 0.0)
		else:
			var u := (ph - beta) / (1.0 - beta)
			var e := u * u * (3.0 - 2.0 * u)
			z = stride * (-0.5 + e)
			lift = sin(PI * u) * lerpf(0.09, 0.2, run_t)
			pitch_f = lerpf(-0.35, 0.22, e)
		var target := foot_rest + Vector3(0, lift * w, z * w)
		var fpitch := pitch_f * w
		# en l'air : jambes repliées
		target += Vector3(0, 0.22 * air, (0.12 if is_l else -0.06) * air)
		var hip_n := "upperleg01_" + side
		var pole := Vector3(0.12 if is_l else -0.12, 0.0, 1.0)
		_solve_limb(hip_n, "lowerleg01_" + side, "foot_" + side, target, pole)
		_global("foot_" + side, Quaternion(Vector3.RIGHT, fpitch - 0.25 * air))
		var toe := "toe1-1_" + side
		if bone.has(toe):
			_local(toe, Quaternion.IDENTITY)

	# --- bras : animation libre (FK), puis IK pondérée si le mortier les guide
	var targets: Array = [null, null]
	if hand_provider.is_valid():
		targets = hand_provider.call()
	var swing := lerpf(0.5, 0.95, run_t) * w
	for idx in 2:
		var side := "R" if idx == 0 else "L"
		var is_l := side == "L"
		var sgn := 1.0 if is_l else -1.0
		var up := "upperarm01_" + side
		var lo := "lowerarm01_" + side
		var wr := "wrist_" + side
		var cl := "clavicle_" + side
		var ph := fposmod(phase + (0.5 if is_l else 0.0), 1.0)
		var sw := -sin(TAU * ph) * swing
		var adduct := 0.5 + 0.05 * breath * (1.0 - w) - 0.35 * air
		_local(cl, Quaternion.IDENTITY)
		_local(up, Quaternion(Vector3.BACK, -sgn * adduct) * Quaternion(Vector3.RIGHT, sw - 0.5 * air))
		var flex := 0.14 - (0.1 * w + 0.95 * run_t * w) - 0.4 * air
		_local(lo, Quaternion(Vector3.RIGHT, flex))
		_local(wr, Quaternion.IDENTITY)
		var fk_curl := 0.35 + 0.2 * run_t
		_curl_fingers(side, fk_curl)
		if targets[idx] == null:
			continue
		var tg: Dictionary = targets[idx]
		var wt: float = tg.get("w", 1.0)
		if wt <= 0.001:
			continue
		var ids := [up, lo, wr]
		var fk_q: Array[Quaternion] = []
		for n in ids:
			fk_q.append(skeleton.get_bone_pose_rotation(bone[n]))
		var f_w: Vector3 = _dir_to_skel(tg["f"]).normalized()
		var p_w: Vector3 = _dir_to_skel(tg["p"]).normalized()
		var palm_pos := _to_skel(tg["pos"])
		var wrist := palm_pos - f_w * PALM_TO_WRIST - p_w * 0.012
		var pole := Vector3(0.5 * sgn, -1.0, -0.45)
		_solve_limb(up, lo, wr, wrist, pole)
		var br := _frame(hand_f[side], palm_n[side])
		var bt := _frame(f_w, p_w)
		_global(wr, (bt * br.inverse()).get_rotation_quaternion())
		if wt < 0.999:
			for i in 3:
				var ik_q := skeleton.get_bone_pose_rotation(bone[ids[i]])
				skeleton.set_bone_pose_rotation(bone[ids[i]], fk_q[i].slerp(ik_q, wt))
		_curl_fingers(side, lerpf(fk_curl, tg.get("curl", 0.9), wt))


func _frame(f: Vector3, p: Vector3) -> Basis:
	var y := f.normalized()
	var z := p - y * p.dot(y)
	z = z.normalized()
	var x := y.cross(z)
	return Basis(x, y, z)


func _meshes(n: Node, acc: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	if n is MeshInstance3D:
		acc.append(n)
	for c in n.get_children():
		_meshes(c, acc)
	return acc
