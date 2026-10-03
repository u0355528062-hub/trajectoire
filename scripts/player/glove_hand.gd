class_name GloveHand
extends Node3D
## Main gantée (nitrile) articulée, vue à la première personne.
## Repère : poignet à l'origine, doigts vers -Z, paume vers -Y.
## `side` = 1 pour la main droite, -1 pour la main gauche (miroir en X).

const FINGERS := {
	"index": {"x": -0.027, "len": [0.042, 0.026, 0.021], "r": 0.0098},
	"middle": {"x": -0.0085, "len": [0.046, 0.029, 0.022], "r": 0.0101},
	"ring": {"x": 0.0105, "len": [0.043, 0.027, 0.021], "r": 0.0094},
	"pinky": {"x": 0.0285, "len": [0.034, 0.021, 0.018], "r": 0.0084},
}

const POSES := {
	"relaxed": {"index": [14, 22, 12], "middle": [18, 26, 14], "ring": [22, 30, 16], "pinky": [26, 32, 18], "thumb": [12, 18, 10], "spread": 22},
	"grip": {"index": [58, 78, 46], "middle": [64, 82, 48], "ring": [66, 84, 46], "pinky": [68, 84, 44], "thumb": [34, 30, 26], "spread": 40},
	"pinch": {"index": [38, 52, 30], "middle": [52, 70, 40], "ring": [70, 86, 46], "pinky": [76, 88, 46], "thumb": [30, 26, 18], "spread": 46},
	"flat": {"index": [4, 4, 2], "middle": [3, 3, 2], "ring": [4, 4, 2], "pinky": [6, 5, 3], "thumb": [6, 8, 4], "spread": 18},
	"point": {"index": [6, 6, 4], "middle": [72, 86, 46], "ring": [76, 88, 46], "pinky": [78, 88, 44], "thumb": [36, 30, 22], "spread": 40},
	"cup": {"index": [24, 30, 18], "middle": [26, 32, 18], "ring": [28, 34, 18], "pinky": [30, 36, 18], "thumb": [20, 22, 14], "spread": 30},
}

var side := 1.0
var grip: Node3D
var _joints: Dictionary = {}
var _thumb_base: Node3D
var _pose: Dictionary = POSES["relaxed"].duplicate(true)
var _target: Dictionary = POSES["relaxed"].duplicate(true)


func build(glove: Material, sleeve: Material, skin_cuff: Material) -> void:
	# Paume : un bloc arrondi légèrement bombé.
	_mesh(Art.rounded_box(Vector3(0.082, 0.026, 0.09), 0.011), glove, Vector3(0.0, 0.0, -0.05))
	_mesh(Art.rounded_box(Vector3(0.07, 0.012, 0.07), 0.006), glove, Vector3(0.0, 0.009, -0.048))
	# Éminence thénar (base du pouce)
	_mesh(Art.sphere(0.024, 16), glove, Vector3(-0.026 * side, -0.006, -0.03), Vector3.ZERO, Vector3(0.9, 0.6, 1.2))
	# Poignet et manchette de gant
	_mesh(Art.cylinder(0.026, 0.028, 0.06, 24), glove, Vector3(0, 0.0, 0.02), Vector3(90, 0, 0), Vector3(1.25, 1.0, 0.85))
	_mesh(Art.torus(0.027, 0.033), glove, Vector3(0, 0.0, 0.048), Vector3(90, 0, 0), Vector3(1.25, 1.0, 0.85))
	# Manche de blouse blanche
	_mesh(Art.cylinder(0.046, 0.05, 0.26, 28), sleeve, Vector3(0, 0.004, 0.17), Vector3(90, 0, 0), Vector3(1.15, 1.0, 0.95))
	_mesh(Art.torus(0.042, 0.05), sleeve, Vector3(0, 0.004, 0.045), Vector3(90, 0, 0), Vector3(1.15, 1.0, 0.95))
	if skin_cuff:
		_mesh(Art.cylinder(0.03, 0.031, 0.02, 20), skin_cuff, Vector3(0, 0.0, 0.058), Vector3(90, 0, 0), Vector3(1.2, 1.0, 0.85))

	for f in FINGERS.keys():
		var d: Dictionary = FINGERS[f]
		var parent: Node3D = self
		var joints: Array[Node3D] = []
		var base := Vector3(d["x"] * side, 0.002, -0.093)
		var r: float = d["r"]
		for i in 3:
			var j := Node3D.new()
			j.position = base if i == 0 else Vector3(0, 0, -float(d["len"][i - 1]))
			parent.add_child(j)
			var l: float = d["len"][i]
			var rr := r * (1.0 - i * 0.09)
			_mesh_on(j, Art.capsule(rr, l + rr * 2.0), glove, Vector3(0, 0, -l * 0.5), Vector3(90, 0, 0), Vector3(1.05, 1.0, 0.9))
			# Articulation légèrement plus large (jointure)
			_mesh_on(j, Art.sphere(rr * 1.06, 12), glove, Vector3.ZERO, Vector3.ZERO, Vector3(1.05, 0.95, 1.0))
			joints.append(j)
			parent = j
		_joints[f] = joints

	# Pouce : base orientée vers l'avant et l'intérieur de la main.
	_thumb_base = Node3D.new()
	_thumb_base.position = Vector3(-0.036 * side, -0.008, -0.034)
	add_child(_thumb_base)
	var tparent: Node3D = _thumb_base
	var tj: Array[Node3D] = []
	var tl := [0.034, 0.03, 0.025]
	for i in 3:
		var j := Node3D.new()
		j.position = Vector3.ZERO if i == 0 else Vector3(0, 0, -float(tl[i - 1]))
		tparent.add_child(j)
		var rr := 0.0118 * (1.0 - i * 0.1)
		_mesh_on(j, Art.capsule(rr, tl[i] + rr * 2.0), glove, Vector3(0, 0, -tl[i] * 0.5), Vector3(90, 0, 0), Vector3(1.1, 1.0, 0.9))
		tj.append(j)
		tparent = j
	_joints["thumb"] = tj

	grip = Node3D.new()
	grip.name = "Grip"
	grip.position = Vector3(0.0, -0.028, -0.062)
	add_child(grip)
	_apply(1.0)


func _mesh(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	return _mesh_on(self, mesh, mat, pos, rot, scl)


func _mesh_on(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func set_pose(name: String) -> void:
	if POSES.has(name):
		_target = POSES[name].duplicate(true)


func _process(delta: float) -> void:
	_apply(1.0 - exp(-14.0 * delta))


func _apply(k: float) -> void:
	for f in ["index", "middle", "ring", "pinky", "thumb"]:
		var cur: Array = _pose[f]
		var tgt: Array = _target[f]
		for i in 3:
			cur[i] = lerpf(float(cur[i]), float(tgt[i]), k)
		var joints: Array = _joints.get(f, [])
		for i in joints.size():
			var j: Node3D = joints[i]
			j.rotation = Vector3(-deg_to_rad(float(cur[i])), 0, 0)
	_pose["spread"] = lerpf(float(_pose["spread"]), float(_target["spread"]), k)
	if _thumb_base:
		var sp := deg_to_rad(float(_pose["spread"]))
		_thumb_base.rotation = Vector3(-deg_to_rad(18.0), sp * side, deg_to_rad(-38.0) * side)
	# Léger écartement des doigts selon la pose
	var fan := {"index": -3.0, "middle": 0.0, "ring": 2.5, "pinky": 6.0}
	for f in fan.keys():
		var j0: Node3D = _joints[f][0]
		j0.rotation.y = deg_to_rad(fan[f]) * side
