class_name MortarModel
extends RefCounted
## Modèle 3D du mortier : tube en carton rouge, bandes dorées, base lestée.

const TUBE_LEN := 0.5
const TUBE_R := 0.045


static func build() -> Node3D:
	var root := Node3D.new()
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.58, 0.07, 0.05)
	paper.roughness = 0.5
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	paper.clearcoat_enabled = true
	paper.clearcoat = 0.35
	paper.clearcoat_roughness = 0.3
	var inner := StandardMaterial3D.new()
	inner.albedo_color = Color(0.015, 0.012, 0.012)
	inner.cull_mode = BaseMaterial3D.CULL_FRONT
	inner.roughness = 1.0
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.86, 0.64, 0.2)
	gold.metallic = 0.9
	gold.roughness = 0.28
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.05, 0.06)
	dark.roughness = 0.45
	dark.metallic = 0.4

	var tube := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = TUBE_R
	cm.bottom_radius = TUBE_R
	cm.height = TUBE_LEN
	cm.radial_segments = 48
	cm.rings = 1
	cm.cap_top = false
	tube.mesh = cm
	tube.material_override = paper
	tube.position.y = TUBE_LEN * 0.5
	root.add_child(tube)

	var bore := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = TUBE_R - 0.004
	bm.bottom_radius = TUBE_R - 0.004
	bm.height = TUBE_LEN - 0.01
	bm.radial_segments = 48
	bm.cap_top = false
	bore.mesh = bm
	bore.material_override = inner
	bore.position.y = TUBE_LEN * 0.5
	root.add_child(bore)

	for y in [0.06, 0.44]:
		var band := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = TUBE_R + 0.0015
		bc.bottom_radius = TUBE_R + 0.0015
		bc.height = 0.02
		bc.radial_segments = 48
		band.mesh = bc
		band.material_override = gold
		band.position.y = y
		root.add_child(band)
	for y in [0.075, 0.425]:
		var thin := MeshInstance3D.new()
		var tc := CylinderMesh.new()
		tc.top_radius = TUBE_R + 0.001
		tc.bottom_radius = TUBE_R + 0.001
		tc.height = 0.004
		tc.radial_segments = 48
		thin.mesh = tc
		thin.material_override = gold
		thin.position.y = y
		root.add_child(thin)

	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = TUBE_R - 0.004
	tm.outer_radius = TUBE_R + 0.007
	tm.rings = 48
	tm.ring_segments = 10
	rim.mesh = tm
	rim.material_override = dark
	rim.position.y = TUBE_LEN
	root.add_child(rim)

	var base := MeshInstance3D.new()
	var bc2 := CylinderMesh.new()
	bc2.top_radius = TUBE_R + 0.008
	bc2.bottom_radius = TUBE_R + 0.026
	bc2.height = 0.028
	bc2.radial_segments = 48
	base.mesh = bc2
	base.material_override = dark
	base.position.y = 0.0
	root.add_child(base)
	return root
