class_name Human
extends Node3D
## Personnage réaliste : modèle skinné (MakeHuman, CC0) généré par tools/build_character.py.
## Matériaux, tête masquable en 1re personne, animation procédurale (IK jambes/bras).

const DIR := "res://assets/character/"
const HEAD_LAYER := 2 # calque masqué par la caméra 1re personne

const PALM_TO_WRIST := 0.075   # centre de la paume -> articulation du poignet
const PALM_SIGN := -1.0        # signe de la normale de paume mesurée sur le modèle

## Variante de corps (fichier assets/character/<variant>.glb) et tenue, à fixer avant l'ajout à la scène.
var variant := "male_a"
var outfit := {}
const DEFAULT_OUTFIT := {
	"top": "hoodie", "top_color": Color(0.17, 0.19, 0.24), "hood": false, "vest": false,
	"pants_color": Color(1, 1, 1), "pants_tex": true, "shoe_color": Color(0.2, 0.21, 0.25),
	"head": "beanie", "head_color": Color(0.06, 0.06, 0.08), "face": "", "face_color": Color(0.05, 0.05, 0.06),
	"backpack": false, "bag_color": Color(0.1, 0.1, 0.12),
}
static var _mat_cache := {}

var model: Node3D
var skeleton: Skeleton3D
var head_meshes: Array[MeshInstance3D] = []
var _mesh_by_name := {}
signal kick_impact(point: Vector3)
signal footstep(speed: float)
signal landed(speed: float)

var twist := 0.0 # torsion supplémentaire du bassin (lancer)
# --- commandes d'expression (PNJ surtout)
var look_target := Vector3.ZERO
var look_w := 0.0        # 0 = regard selon la caméra, 1 = suit look_target
var jaw := 0.0           # ouverture de la bouche (parole, cris)
var crouch := 0.0        # 0 debout -> 1 accroupi
var hop := 0.0           # petit saut (joie)
var nod := 0.0           # hochement « oui »
var shake := 0.0         # « non » de la tête
var lean_extra := 0.0    # inclinaison du buste (+ en avant)
var idle_sway := 1.0     # transfert de poids au repos
var step_in_place := 0.0 # > 0.5 : petits pas sur place (demi-tour sans avancer)
var sway_seed := 0.0
var _ly := 0.0
var _lp := 0.0
var _blink := 0.0
var _next_blink := 2.5
var _prev_ph := {"L": 0.0, "R": 0.0}
var _was_air := false
var _air_vy := 0.0

const KICK_DUR := 1.0
var kick_t := -1.0
var _kick_fired := false
var _whoosh: AudioStreamPlayer3D

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
	var scene: PackedScene = load(DIR + variant + ".glb")
	var inst := scene.instantiate()
	model = Node3D.new()
	model.name = "Model"
	model.rotation.y = PI # le modèle regarde vers +Z ; Godot avance vers -Z
	add_child(model)
	model.add_child(inst)
	skeleton = _find_skeleton(inst)
	_apply_materials(inst)
	_cache_bones()
	_whoosh = AudioStreamPlayer3D.new()
	_whoosh.stream = Sfx.get_stream(&"kick_whoosh")
	_whoosh.volume_db = -6.0
	add_child(_whoosh)


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


func _cached(key: String, maker: Callable) -> Material:
	if not _mat_cache.has(key):
		_mat_cache[key] = maker.call()
	return _mat_cache[key]


func _cloth(kind: String, color: Color) -> Material:
	return _cached(kind + str(color), func() -> Material:
		match kind:
			"knit":
				return _std(color, 0.96, "knit_n.png", 0.2, 6.0)
			"cotton":
				return _std(color, 0.9, "knit_n.png", 0.12, 9.0)
			"nylon":
				var m := _std(color, 0.6, "nylon_n.png", 0.15, 5.0)
				m.metallic_specular = 0.45
				return m
			"rib":
				return _std(color, 1.0, "rib_n.png", 0.8, 6.0)
			"twill":
				return _std(color, 0.85, "denim_n.png", 0.25, 6.0)
			"bandana":
				var b := _std(color, 0.9, "knit_n.png", 0.1, 3.0)
				b.albedo_texture = _tex("bandana_a.png")
				b.uv1_scale = Vector3(3, 3, 1)
				return b
			"jeans":
				var j := _std(color, 0.88, "denim_n.png", 0.12, 3.0)
				j.albedo_texture = _tex("denim_a.png")
				return j
			"pants":
				return _std(color, 0.9, "knit_n.png", 0.15, 7.0)
			"shoes":
				var sh := _std(color, 0.62, "canvas_n.png", 0.12, 6.0)
				sh.vertex_color_use_as_albedo = true
				return sh
			"vest":
				var v := _std(Color(0.92, 0.92, 0.9), 0.62, "canvas_n.png", 0.15, 8.0)
				v.vertex_color_use_as_albedo = true
				v.metallic_specular = 0.5
				v.emission_enabled = true
				v.emission = Color(0.05, 0.045, 0.0)
				return v
			"hair":
				var h := _std(color, 0.55, "hair_n.png", 0.9, 4.0)
				h.metallic_specular = 0.7
				return h
		return _std(color, 0.9))


func _apply_materials(root: Node) -> void:
	var o := DEFAULT_OUTFIT.duplicate()
	o.merge(outfit, true)
	outfit = o
	var skin: Material = _cached("skin_" + variant, func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_texture = _tex("skin_" + variant + ".png")
		m.roughness = 0.52
		m.metallic_specular = 0.45
		m.normal_enabled = true
		m.normal_texture = _tex("skin_n.png")
		m.normal_scale = 0.1
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = 0.22
		return m)
	var eye: Material = _cached("eye", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_texture = _tex("eye_brown.png")
		m.albedo_color = Color(1.25, 1.25, 1.2)
		m.roughness = 0.22
		m.metallic_specular = 0.5
		return m)
	var top: String = o["top"]
	var head_item: String = o["head"]
	var face: String = o["face"]
	var hood: bool = o["hood"] and top == "hoodie"
	if hood:
		head_item = ""
	if face == "balaclava":
		head_item = "" if head_item == "cap" else head_item
	var top_kind := {"hoodie": "knit", "jacket": "nylon", "tshirt": "cotton"}.get(top, "knit") as String
	var top_mat := _cloth(top_kind, o["top_color"])
	var table := {
		"Body": skin, "Head": skin, "Eyes": eye,
		"Hoodie": top_mat, "Hood": top_mat, "Jacket": top_mat, "Tshirt": top_mat,
		"Vest": _cloth("vest", Color.WHITE),
		"Jeans": _cloth("jeans" if o["pants_tex"] else "pants", o["pants_color"]),
		"Shoes": _cloth("shoes", o["shoe_color"]),
		"Beanie": _cloth("rib", o["head_color"]),
		"Cap": _cloth("twill", o["head_color"]), "CapBrim": _cloth("twill", o["head_color"]),
		"Balaclava": _cloth("rib", o["face_color"]),
		"Bandana": _cloth("bandana", o["face_color"]),
		"Backpack": _cloth("nylon", o["bag_color"]),
		"Hair": _cloth("hair", o.get("hair_color", Color(0.12, 0.08, 0.05))),
		"Ponytail": _cloth("hair", o.get("hair_color", Color(0.12, 0.08, 0.05))),
	}
	var visible_set := {
		"Body": true, "Head": true, "Eyes": true, "Jeans": true, "Shoes": true,
		"Hoodie": top == "hoodie", "Hood": hood, "Jacket": top == "jacket", "Tshirt": top == "tshirt",
		"Vest": o["vest"] and top != "jacket",
		"Beanie": head_item == "beanie", "Cap": head_item == "cap", "CapBrim": head_item == "cap",
		"Balaclava": face == "balaclava", "Bandana": face == "bandana",
		"Backpack": o["backpack"],
		"Hair": head_item == "" and not hood and face != "balaclava",
		"Ponytail": not hood and face != "balaclava",
	}
	const HEAD_PARTS := ["Head", "Eyes", "Beanie", "Cap", "CapBrim", "Balaclava", "Bandana", "Hood", "Hair", "Ponytail"]
	for mi in _meshes(root):
		var nm := String(mi.name)
		_mesh_by_name[nm] = mi
		if table.has(nm):
			mi.material_override = table[nm]
		mi.visible = visible_set.get(nm, true)
		if nm in HEAD_PARTS:
			mi.layers = HEAD_LAYER
			head_meshes.append(mi)
		var small := nm in ["Eyes", "CapBrim", "Ponytail", "Bandana"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if small else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.extra_cull_margin = 1.0


# ----------------------------------------------------------------- squelette

func _cache_bones() -> void:
	for i in skeleton.get_bone_count():
		var n := skeleton.get_bone_name(i)
		bone[n] = i
		rest[n] = skeleton.get_bone_global_rest(i).origin
	var f := FileAccess.open(DIR + "rig_" + variant + ".json", FileAccess.READ)
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


func start_kick() -> void:
	if kick_t >= 0.0:
		return
	kick_t = 0.0
	_kick_fired = false
	get_tree().create_timer(0.22).timeout.connect(_whoosh.play)


func foot_world(side := "R") -> Vector3:
	return skeleton.global_transform * _gp("foot_" + side)


func head_world() -> Vector3:
	return skeleton.global_transform * _gp("head")


## Repère réel de la paume (après animation) : {pos, f (doigts), p (normale de paume), thumb}
func palm(side: String) -> Dictionary:
	var q := _gq("wrist_" + side)
	var gb := skeleton.global_transform.basis
	var f: Vector3 = (gb * (q * hand_f[side])).normalized()
	var p: Vector3 = (gb * (q * palm_n[side])).normalized()
	var w := skeleton.global_transform * _gp("wrist_" + side)
	# repère monde direct : main droite -> pouce = f x p ; main gauche -> p x f
	var thumb := f.cross(p) if side == "R" else p.cross(f)
	return {"pos": w + f * PALM_TO_WRIST + p * 0.012, "f": f, "p": p, "thumb": thumb.normalized()}


## Longueur bras + avant-bras (pour adapter les poses à la morphologie)
func arm_length() -> float:
	return (rest["lowerarm01_R"] - rest["upperarm01_R"]).length() + (rest["wrist_R"] - rest["lowerarm01_R"]).length()


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


func _curl_fingers(side: String, amount: float, thumb := 0.4, index_ext := 0.0) -> void:
	var axis: Vector3 = hand_f[side].cross(palm_n[side]).normalized()
	for fi in range(1, 6):
		var k := thumb if fi == 1 else 1.0
		if fi == 2:
			k *= 1.0 - index_ext
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

	var moving := (speed > 0.15 or step_in_place > 0.5) and grounded
	if not grounded:
		_air_vy = vy
	if _was_air and grounded:
		landed.emit(absf(_air_vy))
	_was_air = not grounded
	_walk_w = move_toward(_walk_w, 1.0 if moving else 0.0, delta * 6.0)
	var period := lerpf(1.02, 0.66, run_t)
	if moving:
		phase = fposmod(phase + delta / period, 1.0)
	var beta := lerpf(0.62, 0.36, run_t)       # fraction d'appui
	var stride := speed * beta * period * lerpf(1.0, 0.86, run_t) # amplitude avant/arrière du pied (m)
	var off := lerpf(0.5, 0.34, run_t)          # l'appui se pose moins loin devant le bassin en courant
	var w := _walk_w
	var breath := sin(t_idle * 1.6) * 0.5 + 0.5
	var ku := -1.0
	var kk := 0.0        # intensité globale (cloche)
	var k_ant := 0.0     # préparation : transfert de poids
	var k_cham := 0.0    # genou levé
	var k_str := 0.0     # extension
	var k_rec := 0.0     # retour
	if kick_t >= 0.0:
		kick_t += delta
		ku = kick_t / KICK_DUR
		kk = sin(PI * clampf(ku, 0.0, 1.0))
		k_ant = smoothstep(0.0, 0.24, ku)
		k_cham = smoothstep(0.2, 0.44, ku)
		k_str = smoothstep(0.42, 0.53, ku)
		k_rec = smoothstep(0.64, 1.0, ku)
		if ku >= 0.52 and not _kick_fired:
			_kick_fired = true
			kick_impact.emit(foot_world("R"))
		if ku >= 1.0:
			kick_t = -1.0
			ku = -1.0
			kk = 0.0
			k_ant = 0.0
			k_cham = 0.0
			k_str = 0.0
			k_rec = 0.0
	var kfx := k_ant * (1.0 - k_rec)  # poids transféré sur la jambe d'appui, jusqu'au retour

	# --- bassin / colonne
	var dy := -(0.02 + 0.05 * run_t) * w
	# marche : le bassin est le plus haut en milieu d'appui ; course : le plus bas (rebond)
	var bob := cos(4.0 * PI * (phase - beta * 0.5))
	dy += w * bob * (0.014 * (1.0 - run_t) - 0.04 * run_t)
	dy -= 0.1 * air + 0.03 * kfx + 0.02 * k_cham * (1.0 - k_rec)
	var root_rest: Vector3 = skeleton.get_bone_rest(bone["root"]).origin
	# coup de pied : le bassin se décale sur la jambe gauche (+x) puis lance la hanche vers l'avant
	var shift := 0.05 * kfx + sin(t_idle * 0.31 + sway_seed) * 0.022 * (1.0 - w) * idle_sway * (1.0 - crouch)
	dy += hop - 0.42 * crouch
	var lunge := 0.07 * k_str * (1.0 - k_rec)
	skeleton.set_bone_pose_position(bone["root"], root_rest + Vector3(shift, dy, lunge))
	var kyaw := lerpf(-0.18 * k_cham, 0.32, k_str) * (1.0 - k_rec) if kick_t >= 0.0 else 0.0
	var yaw := sin(TAU * phase) * 0.11 * w + kyaw + twist
	var roll := cos(TAU * phase) * 0.035 * w
	_lean = lerpf(_lean, (0.03 + 0.24 * run_t) * w + 0.05 * clampf(-vy * 0.15, 0.0, 1.0) * air, minf(1.0, delta * 6.0))
	skeleton.set_bone_pose_rotation(bone["root"], Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.BACK, roll))
	var spine := ["spine05", "spine04", "spine03", "spine02", "spine01"]
	for i in spine.size():
		var share := 1.0 / spine.size()
		var rx := _lean * share + kick * 0.05 + (breath - 0.5) * 0.004 - 0.06 * k_cham * (1.0 - k_rec) - 0.06 * k_str * (1.0 - k_rec) + (0.55 * crouch + lean_extra) * share
		var ry := -yaw * 1.5 * share
		var rz := -roll * 1.2 * share
		if i == 0:
			rx -= 0.0
		_local(spine[i], Quaternion(Vector3.UP, ry) * Quaternion(Vector3.RIGHT, rx) * Quaternion(Vector3.BACK, rz))
	var hp := clampf(-look_pitch * 0.55, -0.9, 0.7)
	var ty := 0.0
	var tp := hp
	if look_w > 0.001:
		var hpos := skeleton.global_transform * _gp("head")
		var d := _dir_to_skel(look_target - hpos)
		var ly := clampf(atan2(d.x, d.z), -1.35, 1.35)
		var lp := clampf(-atan2(d.y, Vector2(d.x, d.z).length()), -0.75, 0.6)
		ty = ly * look_w
		tp = lerpf(hp, lp, look_w)
	_ly = lerpf(_ly, ty, minf(1.0, delta * 5.0))
	_lp = lerpf(_lp, tp, minf(1.0, delta * 5.0))
	var nod_a := sin(t_idle * 8.5) * 0.13 * nod
	var shake_a := sin(t_idle * 7.5) * 0.3 * shake
	var crouch_comp := -0.4 * crouch - lean_extra * 0.5  # garde le regard vers l'avant quand on se penche
	for nm in ["neck01", "neck02", "neck03"]:
		_local(nm, Quaternion(Vector3.UP, _ly * 0.16) * Quaternion(Vector3.RIGHT, _lp * 0.18 - _lean * 0.12 + crouch_comp * 0.2))
	_local("head", Quaternion(Vector3.UP, _ly * 0.4 + shake_a) * Quaternion(Vector3.RIGHT, _lp * 0.46 - _lean * 0.1 + nod_a + crouch_comp * 0.3))
	if bone.has("jaw"):
		_local("jaw", Quaternion(Vector3.RIGHT, 0.3 * clampf(jaw, 0.0, 1.0)))
	# yeux : suivent un peu la cible ; clignements
	for sd: String in ["L", "R"]:
		if bone.has("eye_" + sd):
			_local("eye_" + sd, Quaternion(Vector3.UP, clampf(ty - _ly, -0.3, 0.3) * 0.8) * Quaternion(Vector3.RIGHT, clampf(tp - _lp, -0.2, 0.2) * 0.8))
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 1.0
		_next_blink = randf_range(2.0, 6.0)
	_blink = move_toward(_blink, 0.0, delta * 7.0)
	var lid := sin(PI * _blink)
	for sd: String in ["L", "R"]:
		if bone.has("orbicularis03_" + sd):
			_local("orbicularis03_" + sd, Quaternion(Vector3.RIGHT, 0.55 * lid))
		if bone.has("orbicularis04_" + sd):
			_local("orbicularis04_" + sd, Quaternion(Vector3.RIGHT, -0.18 * lid))

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
			z = stride * (off - u)
			pitch_f = lerpf(0.18, -0.35, smoothstep(0.55, 1.0, u)) * (1.0 - smoothstep(0.0, 0.25, u) * 0.0)
		else:
			var u := (ph - beta) / (1.0 - beta)
			var e := u * u * (3.0 - 2.0 * u)
			z = stride * (off - 1.0 + e)
			lift = pow(sin(PI * u), 0.85) * lerpf(0.09, 0.30, run_t)
			pitch_f = lerpf(-0.35, 0.22, e)
		var target := foot_rest + Vector3(0, lift * w + hop * 0.9, z * w)
		var fpitch := pitch_f * w
		if side == "R" and ku >= 0.0:
			var wind := foot_rest + Vector3(0.0, 0.04, -0.07)
			var cham := Vector3(-0.2, 0.76, 0.30)
			var strike := Vector3(-0.16, 0.86, 0.86)
			var cham2 := Vector3(-0.21, 0.66, 0.36)
			if ku < 0.24:
				target = foot_rest.lerp(wind, k_ant)
				fpitch = 0.15 * k_ant
			elif ku < 0.44:
				target = wind.lerp(cham, k_cham)
				fpitch = lerpf(0.15, 0.7, k_cham)
			elif ku < 0.64:
				var path := cham.lerp(strike, k_str)
				path.y += sin(PI * k_str) * 0.05   # petite courbe : le pied part en arc
				target = path
				fpitch = lerpf(0.7, -1.2, k_str)
			else:
				var k2 := smoothstep(0.64, 0.82, ku)
				var k3 := smoothstep(0.8, 1.0, ku)
				target = strike.lerp(cham2, k2).lerp(foot_rest, k3)
				fpitch = lerpf(lerpf(-1.2, 0.5, k2), 0.0, k3)
		# en l'air : jambes repliées
		target += Vector3(0, 0.22 * air, (0.12 if is_l else -0.06) * air)
		var hip_n := "upperleg01_" + side
		var pole := Vector3(0.12 if is_l else -0.12, 0.0, 1.0)
		# empreintes de pas
		if moving and grounded and w > 0.5 and ph < float(_prev_ph[side]) - 0.5:
			footstep.emit(speed)
		_prev_ph[side] = ph
		_solve_limb(hip_n, "lowerleg01_" + side, "foot_" + side, target, pole)
		_global("foot_" + side, Quaternion(Vector3.RIGHT, fpitch - 0.25 * air))
		var toe := "toe1-1_" + side
		if bone.has(toe):
			_local(toe, Quaternion.IDENTITY)

	# --- bras : animation libre (FK), puis IK pondérée si le mortier les guide
	var targets: Array = [null, null]
	if hand_provider.is_valid():
		targets = hand_provider.call()
	var swing := lerpf(0.5, 1.0, run_t) * w
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
		sw += (0.75 if not is_l else -0.55) * kfx * (1.0 - 0.3 * k_str)
		var adduct := 0.5 + 0.05 * breath * (1.0 - w) - 0.35 * air - 0.28 * kk
		_local(cl, Quaternion.IDENTITY)
		_local(up, Quaternion(Vector3.BACK, -sgn * adduct) * Quaternion(Vector3.RIGHT, sw - 0.5 * air))
		var flex := 0.14 - (0.1 * w + 1.35 * run_t * w) - 0.4 * air
		_local(lo, Quaternion(Vector3.RIGHT, flex))
		_local(wr, Quaternion.IDENTITY)
		var fk_curl := 0.35 + 0.6 * run_t * w
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
		if tg.has("pole"):
			pole = _dir_to_skel(tg["pole"]).normalized()
		_solve_limb(up, lo, wr, wrist, pole)
		var br := _frame(hand_f[side], palm_n[side])
		var bt := _frame(f_w, p_w)
		_global(wr, (bt * br.inverse()).get_rotation_quaternion())
		if wt < 0.999:
			for i in 3:
				var ik_q := skeleton.get_bone_pose_rotation(bone[ids[i]])
				skeleton.set_bone_pose_rotation(bone[ids[i]], fk_q[i].slerp(ik_q, wt))
		_curl_fingers(side, lerpf(fk_curl, tg.get("curl", 0.9), wt), 0.4, tg.get("index", 0.0) * wt)


func _frame(f: Vector3, p: Vector3) -> Basis:
	if f.length_squared() < 1e-8:
		f = Vector3.UP
	var y := f.normalized()
	var z := p - y * p.dot(y)
	if z.length_squared() < 1e-6:   # doigts et paume alignés : repère de secours
		z = y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.BACK)
	z = z.normalized()
	var x := y.cross(z)
	return Basis(x, y, z)


func _meshes(n: Node, acc: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	if n is MeshInstance3D:
		acc.append(n)
	for c in n.get_children():
		_meshes(c, acc)
	return acc
