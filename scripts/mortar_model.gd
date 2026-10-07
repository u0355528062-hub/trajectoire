class_name MortarModel
extends RefCounted
## Modèle 3D du mortier : tube en carton imprimé (étiquette, feuille dorée), bague
## en plastique noir au sommet, base lestée à nervures.

const TUBE_LEN := 0.31
const TUBE_R := 0.0245
const DIR := "res://assets/mortar/"


static func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


static func _cyl(top: float, bottom: float, h: float, seg := 48, cap_top := true, cap_bottom := true) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	c.cap_top = cap_top
	c.cap_bottom = cap_bottom
	return c


static func build() -> Node3D:
	var root := Node3D.new()
	var paper := StandardMaterial3D.new()
	paper.albedo_texture = load(DIR + "tube_albedo.png")
	paper.normal_enabled = true
	paper.normal_texture = load(DIR + "tube_n.png")
	paper.normal_scale = 0.6
	paper.roughness = 0.52
	paper.metallic_specular = 0.6
	paper.clearcoat_enabled = true
	paper.clearcoat = 0.25
	paper.clearcoat_roughness = 0.35
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	var inner := StandardMaterial3D.new()
	inner.albedo_color = Color(0.012, 0.01, 0.01)
	inner.cull_mode = BaseMaterial3D.CULL_FRONT
	inner.roughness = 1.0
	var plastic := StandardMaterial3D.new()
	plastic.albedo_color = Color(0.04, 0.04, 0.045)
	plastic.roughness = 0.38
	plastic.metallic_specular = 0.7
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.72, 0.55, 0.2)
	metal.metallic = 0.95
	metal.roughness = 0.3

	# tube de carton (ouvert en haut)
	_mi(root, _cyl(TUBE_R, TUBE_R, TUBE_LEN, 64, false, true), paper, Vector3(0, TUBE_LEN * 0.5, 0))
	# âme intérieure sombre
	_mi(root, _cyl(TUBE_R - 0.0022, TUBE_R - 0.0022, TUBE_LEN - 0.01, 64, false, true), inner, Vector3(0, TUBE_LEN * 0.5, 0))
	# bague plastique au sommet (collerette arrondie)
	var tm := TorusMesh.new()
	tm.inner_radius = TUBE_R - 0.0016
	tm.outer_radius = TUBE_R + 0.0035
	tm.rings = 64
	tm.ring_segments = 12
	_mi(root, tm, plastic, Vector3(0, TUBE_LEN, 0))
	_mi(root, _cyl(TUBE_R + 0.0024, TUBE_R + 0.0024, 0.014, 64, false, false), plastic, Vector3(0, TUBE_LEN - 0.007, 0))
	# base lestée : plateau + nervures + pied
	_mi(root, _cyl(TUBE_R + 0.0035, TUBE_R + 0.0095, 0.016, 64), plastic, Vector3(0, 0.0, 0))
	for i in 3:
		var rt := TorusMesh.new()
		rt.inner_radius = TUBE_R + 0.0045 + i * 0.0006
		rt.outer_radius = TUBE_R + 0.0075 + i * 0.0006
		rt.rings = 64
		rt.ring_segments = 8
		_mi(root, rt, plastic, Vector3(0, 0.0045 + i * 0.0045, 0))
	_mi(root, _cyl(TUBE_R + 0.0105, TUBE_R + 0.0125, 0.006, 64), metal, Vector3(0, -0.011, 0))
	return root
