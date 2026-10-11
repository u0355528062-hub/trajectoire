class_name BagBin
extends PublicBin
## Corbeille de rue parisienne « Vigipirate » : sac plastique transparent tendu sur un cerceau vert, sur un pied.
## Même comportement que PublicBin (un coup l'ébranle, le deuxième la renverse et répand les papiers).

static var _bag_mat: StandardMaterial3D


func _build() -> void:
	mass = 9.0
	damage_limit = 1.6
	top_y = 0.8
	reach = Vector3(0.32, 1.0, 0.32)
	nav_half = Vector2(0.24, 0.24)
	vandal_amount = 0.12
	hit_sound = "bin_hit"
	fall_sound = "bin_tip"
	var green := Furniture.mat("pbin_green", Color(0.1, 0.24, 0.17), 0.4, 0.5)
	if _bag_mat == null:
		_bag_mat = StandardMaterial3D.new()
		_bag_mat.albedo_color = Color(0.86, 0.9, 0.92, 0.32)
		_bag_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_bag_mat.roughness = 0.18
		_bag_mat.metallic_specular = 0.8
		_bag_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_bag_mat.rim_enabled = true
		_bag_mat.rim = 0.4
	var trash := Furniture.mat("bag_trash", Color(0.42, 0.38, 0.3), 0.9)
	var b := MeshBatch.new()
	# pied et support du cerceau
	b.cyl("g", green, 0.028, 0.028, 0.92, Vector3(0, 0.46, -0.22))
	b.cyl("g", green, 0.1, 0.12, 0.03, Vector3(0, 0.015, -0.22))
	b.box("g", green, Vector3(0.08, 0.06, 0.06), Vector3(0, 0.88, -0.2))
	b.commit(_model, true)
	# cerceau
	var hoop := TorusMesh.new()
	hoop.inner_radius = 0.2
	hoop.outer_radius = 0.225
	hoop.rings = 20
	hoop.ring_segments = 6
	Furniture.add(_model, hoop, green, Vector3(0, 0.9, 0))
	# sac : pend sous le cerceau, plis et ventre (déchets visibles au fond)
	var bag := MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.28), Vector2(0.12, 0.29), Vector2(0.19, 0.36), Vector2(0.215, 0.5),
		Vector2(0.21, 0.72), Vector2(0.235, 0.86), Vector2(0.22, 0.91)]), 14, 60.0)
	var bi := Furniture.add(_model, bag, _bag_mat)
	bi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bi.scale = Vector3(1.0, 1.0, 0.94)
	var junk := SphereMesh.new()
	junk.radius = 0.15
	junk.height = 0.2
	Furniture.add(_model, junk, trash, Vector3(0, 0.37, 0))
	Furniture.col_cyl(self, 0.24, 0.92, Vector3(0, 0.46, 0))
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.4, 0)
