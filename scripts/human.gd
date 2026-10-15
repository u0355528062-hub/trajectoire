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
const SKIN_SHADER := preload("res://assets/character/skin.gdshader")
const CLOTH_SHADER := preload("res://assets/character/cloth.gdshader")
const HAIR_SHADER := preload("res://assets/character/hair.gdshader")
## Couleur des yeux et des cheveux propre à chaque corps (la tenue peut les remplacer : "eyes", "hair_color")
const EYES := {
	"male_a": "hazel", "male_b": "dark", "male_c": "dark", "male_d": "blue", "male_e": "brown",
	"female_a": "green", "female_b": "dark", "female_c": "dark", "female_d": "brown",
}
const HAIR_COLOR := {
	"male_a": Color(0.13, 0.085, 0.06), "male_b": Color(0.04, 0.035, 0.03), "male_c": Color(0.04, 0.035, 0.035),
	"male_d": Color(0.36, 0.34, 0.32), "male_e": Color(0.05, 0.04, 0.03), "female_a": Color(0.3, 0.18, 0.1),
	"female_b": Color(0.03, 0.025, 0.02), "female_c": Color(0.03, 0.03, 0.03), "female_d": Color(0.12, 0.07, 0.04),
}

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
var crouch_user := 0.0   # accroupi volontaire du joueur (le plus grand des deux s'applique)
var hop := 0.0           # petit saut (joie)
var nod := 0.0           # hochement « oui »
var shake := 0.0         # « non » de la tête
var lean_extra := 0.0    # inclinaison du buste (+ en avant)
var idle_sway := 1.0     # transfert de poids au repos
var step_in_place := 0.0 # > 0.5 : petits pas sur place (demi-tour sans avancer)
# --- postures supplémentaires (PNJ, policiers, joueur arrêté)
var sit := 0.0           # assis par terre, genoux relevés
var kneel := 0.0         # à genoux
var fall := 0.0          # 0 debout -> 1 allongé
var fall_dir := 0.0      # sens de la chute : 0 = en arrière, PI = en avant, ±PI/2 = sur les côtés
var hunch := 0.0         # dos voûté, tête en avant (toux, coup reçu)
var side_lean := 0.0     # buste penché sur le côté (+ = vers la droite du personnage)
var eye_open := 1.0      # 1 normal, < 1 yeux plissés, 0 fermés
var breath_amp := 0.0    # essoufflement (0 calme -> 1 haletant)
# noms d'os précalculés (évite de reconstruire les chaînes à chaque image pour chaque personnage)
const SPINE_IDS := ["spine05", "spine04", "spine03", "spine02", "spine01"]
const NECK_IDS := ["neck01", "neck02", "neck03"]
const SIDES := ["L", "R"]
const N_FOOT := {"L": "foot_L", "R": "foot_R"}
const N_UPLEG := {"L": "upperleg01_L", "R": "upperleg01_R"}
const N_LOLEG := {"L": "lowerleg01_L", "R": "lowerleg01_R"}
const N_TOE := {"L": "toe1-1_L", "R": "toe1-1_R"}
const N_EYE := {"L": "eye_L", "R": "eye_R"}
const N_UPARM := {"L": "upperarm01_L", "R": "upperarm01_R"}
const N_LOARM := {"L": "lowerarm01_L", "R": "lowerarm01_R"}
const N_WRIST := {"L": "wrist_L", "R": "wrist_R"}
const N_CLAV := {"L": "clavicle_L", "R": "clavicle_R"}
var lod := 0             # 0 complet, 1 sans yeux ni mâchoire, 2 sans bras IK
var _shadows := true
var _shadow_meshes: Array[MeshInstance3D] = []
var _fall_on := false
var _fc := {}            # cache de la courbure des doigts
var _finger_idx := {}
var _finger_axis := {}
var _leg_len := 0.9
var _i := {}             # indices d'os fréquents
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


## Ombres portées du personnage (coupées au loin par la foule pour alléger le rendu)
func set_shadows(on: bool) -> void:
	if on == _shadows:
		return
	_shadows = on
	for mi in _shadow_meshes:
		if is_instance_valid(mi):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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


## Tissu d'un vêtement porté (shader cloth) : couleur, motif tissé répété et détails cuits du vêtement
## (`garment` : préfixe des textures cloth_<garment>_n/_m.png, communes à tous les corps).
func _garment(garment: String, color: Color, p: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CLOTH_SHADER
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("garment_n", _tex("cloth_" + garment + "_n.png"))
	m.set_shader_parameter("garment_m", _tex("cloth_" + garment + "_m.png"))
	m.set_shader_parameter("weave_n", _tex(str(p.get("weave", "knit_n.png"))))
	for k: String in p:
		if k != "weave":
			m.set_shader_parameter(k, _tex(str(p[k])) if p[k] is String else p[k])
	return m


func _cloth(kind: String, color: Color) -> Material:
	return _cached(kind + str(color), func() -> Material:
		match kind:
			"fleece": # sweat molletonné : côtes, cordons, poche kangourou, duvet en lumière rasante
				return _garment("hoodie", color, {"weave_scale": 7.0, "weave_depth": 0.35, "rough": 0.93, "sheen": 0.22,
					"trim_color": color.darkened(0.12), "trim_mix": 1.0, "special_color": Color(0.62, 0.6, 0.56),
					"special_metal": 0.7, "garment_depth": 1.0})
			"tee": # jersey de coton
				return _garment("tshirt", color, {"weave_scale": 11.0, "weave_depth": 0.2, "rough": 0.9, "sheen": 0.1,
					"trim_color": color.darkened(0.08), "trim_mix": 1.0, "special_on": 0.0})
			"puffer": # doudoune en nylon : piqûres, zip métallique
				return _garment("jacket", color, {"weave": "nylon_n.png", "weave_scale": 6.0, "weave_depth": 0.25,
					"rough": 0.48, "sheen": 0.04, "trim_color": color.darkened(0.25), "trim_mix": 1.0,
					"special_color": Color(0.32, 0.32, 0.33), "special_metal": 0.8})
			"denim": # jean brut : sergé indigo, surpiqûres dorées, usure claire aux cuisses et aux plis
				return _garment("jeans", color, {"weave": "denim_n.png", "weave_scale": 3.0, "weave_depth": 0.35,
					"weave_a": "denim_a.png", "weave_albedo": 1.0, "rough": 0.9,
					"trim_color": Color(0.72, 0.5, 0.22), "trim_mix": 1.0,
					"wear_color": Color(0.42, 0.5, 0.62) * color, "wear_amount": 0.75, "special_on": 0.0})
			"chino": # pantalon de toile ou jogging sombre : coutures ton sur ton, sans usure
				return _garment("jeans", color, {"weave": "denim_n.png", "weave_scale": 5.0, "weave_depth": 0.18,
					"rough": 0.88, "trim_color": color.lightened(0.08), "trim_mix": 0.6,
					"wear_color": color.lightened(0.1), "wear_amount": 0.25, "special_on": 0.0})
			"vest": # gilet jaune : bandes réfléchissantes, biais
				return _garment("vest", Color(0.86, 0.78, 0.06), {"weave": "canvas_n.png", "weave_scale": 8.0,
					"weave_depth": 0.2, "rough": 0.7, "wear_color": Color(0.72, 0.74, 0.76), "wear_amount": 1.0,
					"special_on": 0.0, "trim_color": Color(0.8, 0.72, 0.05), "trim_mix": 1.0})
			"medic": # gilet de street medic : blanc, croix rouges devant et dans le dos
				return _garment("vest", Color(0.86, 0.86, 0.84), {"weave": "canvas_n.png", "weave_scale": 8.0,
					"weave_depth": 0.2, "rough": 0.75, "wear_color": Color(0.7, 0.71, 0.72), "wear_amount": 0.0,
					"special_color": Color(0.72, 0.05, 0.05), "trim_color": Color(0.72, 0.05, 0.05), "trim_mix": 1.0})
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
			"shoes":
				var sh := _std(color, 0.62, "canvas_n.png", 0.12, 6.0)
				sh.vertex_color_use_as_albedo = true
				return sh
			"hair":
				var h := ShaderMaterial.new()
				h.shader = HAIR_SHADER
				h.set_shader_parameter("color", color)
				h.set_shader_parameter("strands", _tex("hair_strands.png"))
				h.set_shader_parameter("strands_n", _tex("hair_strands_n.png"))
				return h
		return _std(color, 0.9))


## Peau : texture cuite du corps (teint + brillance) dans le shader de peau
func _skin(tint: Color) -> Material:
	return _cached("skin_" + variant + str(tint), func() -> Material:
		var m := ShaderMaterial.new()
		m.shader = SKIN_SHADER
		m.set_shader_parameter("albedo_tex", _tex("skin_" + variant + ".png"))
		m.set_shader_parameter("pores", _tex("skin_n.png"))
		m.set_shader_parameter("tint", tint)
		return m)


## Yeux : iris détaillé (couleur au choix), cornée humide (spéculaire net)
func _eyes(iris: String) -> Material:
	return _cached("eye_" + iris, func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_texture = _tex("eye_" + iris + ".png")
		m.roughness = 0.08
		m.metallic_specular = 0.7
		m.clearcoat_enabled = true
		m.clearcoat = 1.0
		m.clearcoat_roughness = 0.03
		return m)


func _apply_materials(root: Node) -> void:
	var o := DEFAULT_OUTFIT.duplicate()
	o.merge(outfit, true)
	outfit = o
	var skin := _skin(o.get("skin_tint", Color.WHITE))
	var eye := _eyes(str(o.get("eyes", EYES.get(variant, "brown"))))
	var top: String = o["top"]
	var head_item: String = o["head"]
	var face: String = o["face"]
	var hood: bool = o["hood"] and top == "hoodie"
	if hood:
		head_item = ""
	if face == "balaclava":
		head_item = "" if head_item == "cap" else head_item
	var top_kind := {"hoodie": "fleece", "jacket": "puffer", "tshirt": "tee"}.get(top, "fleece") as String
	var top_mat := _cloth(top_kind, o["top_color"])
	var hood_mat := _cloth({"hoodie": "knit", "jacket": "nylon", "tshirt": "cotton"}.get(top, "knit") as String, o["top_color"])
	# cheveux de la couleur cuite dans la peau (sourcils, barbe, racines) ; la tenue ne l'impose
	# que pour les cheveux gris des personnes âgées ou si elle le demande ("hair_force")
	var hair_col: Color = HAIR_COLOR.get(variant, Color(0.12, 0.08, 0.05))
	if o.has("hair_color") and (o.get("hair_force", false) or str(o.get("age", "")) == "elder"):
		hair_col = o["hair_color"]
	var table := {
		"Body": skin, "Head": skin, "Eyes": eye,
		"Hoodie": top_mat, "Hood": hood_mat, "Jacket": top_mat, "Tshirt": top_mat,
		"Vest": _cloth("medic" if o.get("vest_style", "") == "medic" else "vest", Color.WHITE),
		"Jeans": _cloth("denim" if o["pants_tex"] else "chino", o["pants_color"]),
		"Shoes": _cloth("shoes", o["shoe_color"]),
		"Beanie": _cloth("rib", o["head_color"]),
		"Cap": _cloth("twill", o["head_color"]), "CapBrim": _cloth("twill", o["head_color"]),
		"Balaclava": _cloth("rib", o["face_color"]),
		"Bandana": _cloth("bandana", o["face_color"]),
		"Backpack": _cloth("nylon", o["bag_color"]),
		"Hair": _cloth("hair", hair_col),
		"Ponytail": _cloth("hair", hair_col),
	}
	var visible_set := {
		"Body": true, "Head": true, "Eyes": true, "Jeans": true, "Shoes": true,
		"Hoodie": top == "hoodie", "Hood": hood, "Jacket": top == "jacket", "Tshirt": top == "tshirt",
		"Vest": o["vest"] and top != "jacket",
		"Beanie": head_item == "beanie", "Cap": head_item == "cap", "CapBrim": head_item == "cap",
		"Balaclava": face == "balaclava", "Bandana": face == "bandana",
		"Backpack": o["backpack"],
		"Hair": head_item == "" and not hood and face != "balaclava" and not o.get("no_hair", false),
		"Ponytail": not hood and face != "balaclava" and not o.get("no_hair", false),
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
		if not small:
			_shadow_meshes.append(mi)
		mi.extra_cull_margin = 1.0


# ----------------------------------------------------------------- squelette

func _cache_bones() -> void:
	for i in skeleton.get_bone_count():
		var n := skeleton.get_bone_name(i)
		bone[n] = i
		rest[n] = skeleton.get_bone_global_rest(i).origin
	_leg_len = (rest["lowerleg01_L"] - rest["upperleg01_L"]).length() + (rest["foot_L"] - rest["lowerleg01_L"]).length()
	for nm in ["spine05", "spine04", "spine03", "spine02", "spine01", "neck01", "neck02", "neck03", "head", "jaw", "root"]:
		if bone.has(nm):
			_i[nm] = bone[nm]
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
		_finger_axis[side] = hand_f[side].cross(palm_n[side]).normalized()
		var lists: Array = []
		for fi in range(1, 6):
			var ids: Array[int] = []
			for seg in range(1, 4):
				var nm := "finger%d-%d_%s" % [fi, seg, side]
				if bone.has(nm):
					ids.append(bone[nm])
			lists.append(ids)
		_finger_idx[side] = lists


## Accroche un nœud à un os (il suit l'animation). `offset` : position relative à l'origine de l'os
## au repos (axes du squelette), `rot` : orientation relative au repos.
func attach(bone_name: String, node: Node3D, offset := Vector3.ZERO, rot := Basis.IDENTITY) -> BoneAttachment3D:
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone_name
	skeleton.add_child(ba)
	node.transform = Transform3D(rot * Basis.from_scale(node.scale), offset)
	ba.add_child(node)
	return ba


## Accroche un nœud le long d'un segment d'os (de `bone_name` vers `child_bone`) à la fraction `t`.
## L'axe +Y du nœud est aligné sur le segment.
func attach_limb(bone_name: String, child_bone: String, node: Node3D, t := 0.0) -> BoneAttachment3D:
	var a: Vector3 = rest[bone_name]
	var b: Vector3 = rest[child_bone]
	var d := (b - a).normalized()
	var up := d
	var rgt := up.cross(Vector3.BACK if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := rgt.cross(up).normalized()
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone_name
	skeleton.add_child(ba)
	var bs := Basis(rgt, up, fwd).scaled(node.scale)
	node.transform = Transform3D(bs, (b - a) * t)
	ba.add_child(node)
	return ba


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


## Échelle du corps par rapport à la morphologie de référence (1,80 m)
func hscale() -> float:
	return float(rest["head"].y) / 1.6767


## Longueur bras + avant-bras (pour adapter les poses à la morphologie)
func arm_length() -> float:
	return (rest["lowerarm01_R"] - rest["upperarm01_R"]).length() + (rest["wrist_R"] - rest["lowerarm01_R"]).length()


func kick_back(amount := 1.0) -> void:
	kick = maxf(kick, amount)


func _gq(n: String) -> Quaternion:
	return skeleton.get_bone_global_pose(bone[n]).basis.get_rotation_quaternion()


func _gp(n: String) -> Vector3:
	return skeleton.get_bone_global_pose(bone[n]).origin


var _parent_cache := {}

func _parent_of(n: String) -> String:
	var p: Variant = _parent_cache.get(n)
	if p == null:
		p = skeleton.get_bone_name(skeleton.get_bone_parent(bone[n]))
		_parent_cache[n] = p
	return p


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


## Pose globale de l'os `n` connaissant celle de son ancêtre `anc` (os intermédiaires : pose locale actuelle).
## Évite get_bone_global_pose, qui recalcule tout le squelette dès qu'un os a bougé.
var _chain_cache := {}

func _global_from(n: String, anc: String, g_anc: Transform3D) -> Transform3D:
	var key := n + ">" + anc
	var chain: Variant = _chain_cache.get(key)
	if chain == null:
		var ids: Array[int] = []
		var i: int = bone[n]
		var stop: int = bone[anc]
		while i != stop and i >= 0:
			ids.push_front(i)
			i = skeleton.get_bone_parent(i)
		chain = ids
		_chain_cache[key] = ids
	var g := g_anc
	for b: int in chain:
		g = g * Transform3D(Basis(skeleton.get_bone_pose_rotation(b)), skeleton.get_bone_pose_position(b))
	return g


## IK 2 os rapide : `g_par` est la pose globale du parent de `upper`. Renvoie la rotation globale de `lower`.
func _solve_limb_g(upper: String, lower: String, end: String, target: Vector3, pole: Vector3, g_par: Transform3D) -> Quaternion:
	var a := g_par * skeleton.get_bone_pose_position(bone[upper])
	var l1: float = (rest[lower] - rest[upper]).length()
	var l2: float = (rest[end] - rest[lower]).length()
	var r := _mid_joint(a, target, l1, l2, pole)
	var m: Vector3 = r[0]
	var e: Vector3 = r[1]
	var q_up := Quaternion((rest[lower] - rest[upper]).normalized(), (m - a).normalized()).normalized()
	skeleton.set_bone_pose_rotation(bone[upper], g_par.basis.get_rotation_quaternion().normalized().inverse() * q_up)
	var q_lo := Quaternion((rest[end] - rest[lower]).normalized(), (e - m).normalized()).normalized()
	skeleton.set_bone_pose_rotation(bone[lower], q_up.inverse() * q_lo)
	return q_lo


func _solve_limb(upper: String, lower: String, end: String, target: Vector3, pole: Vector3) -> void:
	var a := _gp(upper)
	var l1: float = (rest[lower] - rest[upper]).length()
	var l2: float = (rest[end] - rest[lower]).length()
	var r := _mid_joint(a, target, l1, l2, pole)
	var m: Vector3 = r[0]
	var e: Vector3 = r[1]
	_aim(upper, rest[lower] - rest[upper], m - a)
	_aim(lower, rest[end] - rest[lower], e - m)


func _curl_fingers(side: String, amount: float, thumb := 0.4, index_ext := 0.0, middle_ext := 0.0) -> void:
	var key := Vector4(amount, thumb, index_ext, middle_ext)
	if _fc.has(side) and (_fc[side] as Vector4).distance_squared_to(key) < 0.000004:
		return
	_fc[side] = key
	var axis: Vector3 = _finger_axis[side]
	var lists: Array = _finger_idx[side]
	for fi in 5:
		var k := thumb if fi == 0 else 1.0
		if fi == 1:
			k *= 1.0 - index_ext
		elif fi == 2:
			k *= 1.0 - middle_ext
		var ids: Array = lists[fi]
		for sg in ids.size():
			skeleton.set_bone_pose_rotation(ids[sg], Quaternion(axis, amount * k * (0.9 if sg == 0 else 1.0)))


# ------------------------------------------------------------------ animation

## speed : vitesse horizontale (m/s) ; run_t : 0 marche -> 1 course ; pitch : regard vertical
func animate(delta: float, speed: float, run_t: float, grounded: bool, vy: float, pitch: float) -> void:
	if skeleton == null:
		return
	var crouch_saved := crouch
	crouch = maxf(crouch, crouch_user)
	_animate(delta, speed, run_t, grounded, vy, pitch)
	crouch = crouch_saved


func _animate(delta: float, speed: float, run_t: float, grounded: bool, vy: float, pitch: float) -> void:
	var _pt := Time.get_ticks_usec() if Actor.prof else 0
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
	var sit_e := sit * sit * (3.0 - 2.0 * sit)
	var kneel_e := kneel * kneel * (3.0 - 2.0 * kneel)
	var fall_e := fall * fall * (3.0 - 2.0 * fall)
	var lscale := _leg_len / 0.9
	var dy := -(0.02 + 0.05 * run_t) * w
	# marche : le bassin est le plus haut en milieu d'appui ; course : le plus bas (rebond)
	var bob := cos(4.0 * PI * (phase - beta * 0.5))
	dy += w * bob * (0.014 * (1.0 - run_t) - 0.04 * run_t)
	dy -= 0.1 * air + 0.03 * kfx + 0.02 * k_cham * (1.0 - k_rec)
	var root_rest: Vector3 = skeleton.get_bone_rest(bone["root"]).origin
	# coup de pied : le bassin se décale sur la jambe gauche (+x) puis lance la hanche vers l'avant
	var shift := 0.05 * kfx + sin(t_idle * 0.31 + sway_seed) * 0.022 * (1.0 - w) * idle_sway * (1.0 - crouch) * (1.0 - sit_e) * (1.0 - kneel_e)
	dy += hop - 0.42 * crouch
	dy -= (root_rest.y - 0.14 * lscale) * sit_e + root_rest.y * 0.47 * kneel_e
	var lunge := 0.07 * k_str * (1.0 - k_rec) - 0.06 * sit_e
	skeleton.set_bone_pose_position(_i["root"], root_rest + Vector3(shift, dy, lunge))
	var kyaw := lerpf(-0.18 * k_cham, 0.32, k_str) * (1.0 - k_rec) if kick_t >= 0.0 else 0.0
	var yaw := sin(TAU * phase) * 0.11 * w + kyaw + twist
	var roll := cos(TAU * phase) * 0.035 * w
	_lean = lerpf(_lean, (0.03 + 0.24 * run_t) * w + 0.05 * clampf(-vy * 0.15, 0.0, 1.0) * air, minf(1.0, delta * 6.0))
	skeleton.set_bone_pose_rotation(_i["root"], Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.BACK, roll))
	var breath := sin(t_idle * (1.6 + 4.0 * breath_amp)) * 0.5 + 0.5
	var spine_ids := SPINE_IDS
	for i in 5:
		var share := 0.2
		var rx := _lean * share + kick * 0.05 + (breath - 0.5) * (0.004 + 0.022 * breath_amp) - 0.06 * k_cham * (1.0 - k_rec) - 0.06 * k_str * (1.0 - k_rec) + (0.55 * crouch + lean_extra + 0.7 * hunch + 0.18 * sit_e) * share
		var ry := -yaw * 1.5 * share
		var rz := -roll * 1.2 * share + side_lean * 0.9 * share
		skeleton.set_bone_pose_rotation(_i[spine_ids[i]], Quaternion(Vector3.UP, ry) * Quaternion(Vector3.RIGHT, rx) * Quaternion(Vector3.BACK, rz))
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
	var crouch_comp := -0.4 * crouch - lean_extra * 0.5 - 0.5 * hunch  # garde le regard vers l'avant quand on se penche
	var nq := Quaternion(Vector3.UP, _ly * 0.16) * Quaternion(Vector3.RIGHT, _lp * 0.18 - _lean * 0.12 + crouch_comp * 0.2 + 0.25 * hunch) * Quaternion(Vector3.BACK, -side_lean * 0.12)
	for nm in NECK_IDS:
		skeleton.set_bone_pose_rotation(_i[nm], nq)
	skeleton.set_bone_pose_rotation(_i["head"], Quaternion(Vector3.UP, _ly * 0.4 + shake_a) * Quaternion(Vector3.RIGHT, _lp * 0.46 - _lean * 0.1 + nod_a + crouch_comp * 0.3) * Quaternion(Vector3.BACK, -side_lean * 0.2))
	if lod == 0:
		if _i.has("jaw"):
			skeleton.set_bone_pose_rotation(_i["jaw"], Quaternion(Vector3.RIGHT, 0.3 * clampf(jaw, 0.0, 1.0)))
		# yeux : suivent un peu la cible ; clignements
		for sd: String in ["L", "R"]:
			if bone.has(N_EYE[sd]):
				_local(N_EYE[sd], Quaternion(Vector3.UP, clampf(ty - _ly, -0.3, 0.3) * 0.8) * Quaternion(Vector3.RIGHT, clampf(tp - _lp, -0.2, 0.2) * 0.8))
		_next_blink -= delta
		if _next_blink <= 0.0:
			_blink = 1.0
			_next_blink = randf_range(2.0, 6.0)
		_blink = move_toward(_blink, 0.0, delta * 7.0)
		var lid := clampf(sin(PI * _blink) + (1.0 - eye_open), 0.0, 1.2)
		for sd: String in ["L", "R"]:
			if bone.has("orbicularis03_" + sd):
				_local("orbicularis03_" + sd, Quaternion(Vector3.RIGHT, 0.55 * lid))
			if bone.has("orbicularis04_" + sd):
				_local("orbicularis04_" + sd, Quaternion(Vector3.RIGHT, -0.18 * lid))

	if Actor.prof:
		_pt = Actor._prof_add("a_tronc", _pt)
	# --- jambes (IK) : appui plat, balancier en arc
	var g_hip := {}
	for side: String in SIDES:
		g_hip[side] = skeleton.get_bone_global_pose(bone[_parent_of(N_UPLEG[side])])
	for side: String in SIDES:
		var is_l := side == "L"
		var ph := fposmod(phase + (0.0 if is_l else 0.5), 1.0)
		var foot_rest: Vector3 = rest[N_FOOT[side]]
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
		var hip_n: String = N_UPLEG[side]
		var pole := Vector3(0.12 if is_l else -0.12, 0.0, 1.0)
		var sgx := 1.0 if is_l else -1.0
		if sit_e > 0.001:     # assis, genoux relevés, pieds à plat devant
			var st := foot_rest + Vector3(0.05 * sgx, 0.0, 0.52 * lscale)
			target = target.lerp(st, sit_e)
			fpitch = lerpf(fpitch, 0.0, sit_e)
			pole = pole.lerp(Vector3(0.1 * sgx, 1.0, 0.2), sit_e)
		if kneel_e > 0.001:   # à genoux : tibias au sol derrière
			var kt := foot_rest + Vector3(0.02 * sgx, 0.07, -0.42 * lscale)
			target = target.lerp(kt, kneel_e)
			fpitch = lerpf(fpitch, -1.25, kneel_e)
		if fall_e > 0.001:    # allongé : jambes molles, un peu écartées
			target = target.lerp(foot_rest + Vector3(0.05 * sgx, 0.03, -0.05 * lscale), fall_e * 0.8)
		# empreintes de pas
		if moving and grounded and w > 0.5 and ph < float(_prev_ph[side]) - 0.5:
			footstep.emit(speed)
		_prev_ph[side] = ph
		var q_lo := _solve_limb_g(hip_n, N_LOLEG[side], N_FOOT[side], target, pole, g_hip[side])
		skeleton.set_bone_pose_rotation(bone[N_FOOT[side]], q_lo.inverse() * Quaternion(Vector3.RIGHT, fpitch - 0.25 * air))
		var toe: String = N_TOE[side]
		if bone.has(toe):
			_local(toe, Quaternion.IDENTITY)

	if Actor.prof:
		_pt = Actor._prof_add("a_jambes", _pt)
	# --- bras : animation libre (FK), puis IK pondérée si le mortier les guide
	var targets: Array = [null, null]
	if hand_provider.is_valid():
		targets = hand_provider.call()
	if Actor.prof:
		_pt = Actor._prof_add("a_mains", _pt)
	var swing := lerpf(0.5, 1.0, run_t) * w
	var hunch_arm := 0.12 * hunch
	var g_clp := {}
	if targets[0] != null or targets[1] != null:
		for sd: String in ["R", "L"]:
			g_clp[sd] = skeleton.get_bone_global_pose(bone[_parent_of(N_CLAV[sd])])
	for idx in 2:
		var side := "R" if idx == 0 else "L"
		var is_l := side == "L"
		var sgn := 1.0 if is_l else -1.0
		var up: String = N_UPARM[side]
		var lo: String = N_LOARM[side]
		var wr: String = N_WRIST[side]
		var cl: String = N_CLAV[side]
		var ph := fposmod(phase + (0.5 if is_l else 0.0), 1.0)
		var sw := -sin(TAU * ph) * swing
		sw += (0.75 if not is_l else -0.55) * kfx * (1.0 - 0.3 * k_str)
		var adduct := 0.5 + 0.05 * breath * (1.0 - w) - 0.35 * air - 0.28 * kk - 0.22 * fall_e + 0.1 * hunch
		_local(cl, Quaternion(Vector3.UP, sgn * hunch_arm) if hunch > 0.01 else Quaternion.IDENTITY)
		_local(up, Quaternion(Vector3.BACK, -sgn * adduct) * Quaternion(Vector3.RIGHT, sw - 0.5 * air))
		var flex := 0.14 - (0.1 * w + 1.35 * run_t * w) - 0.4 * air
		_local(lo, Quaternion(Vector3.RIGHT, flex))
		_local(wr, Quaternion.IDENTITY)
		var fk_curl := 0.35 + 0.6 * run_t * w
		_curl_fingers(side, fk_curl)
		if targets[idx] == null or lod >= 2:
			continue
		var tg: Dictionary = targets[idx]
		var wt: float = tg.get("w", 1.0)
		if wt <= 0.001:
			continue
		var ids := [up, lo, wr]
		var fk_q: Array[Quaternion] = []
		for n in ids:
			fk_q.append(skeleton.get_bone_pose_rotation(bone[n]).normalized())
		var f_w: Vector3 = _dir_to_skel(tg["f"]).normalized()
		var p_w: Vector3 = _dir_to_skel(tg["p"]).normalized()
		var palm_pos := _to_skel(tg["pos"])
		var wrist := palm_pos - f_w * PALM_TO_WRIST - p_w * 0.012
		var pole := Vector3(0.5 * sgn, -1.0, -0.45)
		if tg.has("pole"):
			pole = _dir_to_skel(tg["pole"]).normalized()
		var g_upp := _global_from(_parent_of(up), _parent_of(cl), g_clp[side])
		var q_lo2 := _solve_limb_g(up, lo, wr, wrist, pole, g_upp)
		var br := _frame(hand_f[side], palm_n[side])
		var bt := _frame(f_w, p_w)
		skeleton.set_bone_pose_rotation(bone[wr], q_lo2.inverse() * (bt * br.inverse()).get_rotation_quaternion())
		if wt < 0.999:
			for i in 3:
				var ik_q := skeleton.get_bone_pose_rotation(bone[ids[i]]).normalized()
				skeleton.set_bone_pose_rotation(bone[ids[i]], fk_q[i].slerp(ik_q, wt))
		_curl_fingers(side, lerpf(fk_curl, tg.get("curl", 0.9), wt), lerpf(0.4, tg.get("thumb", 0.4), wt), tg.get("index", 0.0) * wt, tg.get("middle", 0.0) * wt)
	if Actor.prof:
		_pt = Actor._prof_add("a_bras", _pt)
	if fall > 0.002 or _fall_on:
		_fall_on = fall > 0.002
		_apply_fall()


## Bascule du corps entier (chute, K.O.) : rotation autour du bassin qui descend vers le sol.
func _apply_fall() -> void:
	var e := fall * fall * (3.0 - 2.0 * fall)
	var th := e * PI * 0.5
	var d := Vector3(sin(fall_dir), 0.0, cos(fall_dir))
	var axis := Vector3(d.z, 0.0, -d.x)
	var h0: float = rest["root"].y
	var hh := lerpf(h0, 0.16, e)
	var slide := d * (0.55 * h0 * e)
	var xf := Transform3D(Basis(axis, th), Vector3(slide.x, hh, slide.z)) * Transform3D(Basis.IDENTITY, Vector3(0, -h0, 0)) * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	model.transform = xf


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
