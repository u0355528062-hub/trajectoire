class_name Signpost
extends StreetProp
## Panneau de signalisation sur poteau : les coups de pied le tordent, puis il se couche dans un grand fracas.

var kind := "no_park"      # no_park | no_entry | stop


func _build() -> void:
	mass = 16.0
	damage_limit = 3.2
	top_y = 2.1
	reach = Vector3(0.35, 1.7, 0.35)
	nav_half = Vector2(0.1, 0.1)
	vandal_amount = 0.3
	var alu := Furniture.mat("alu", Color(0.72, 0.74, 0.77), 0.35, 0.85)
	var gra := Furniture.mat("graphite", Color(0.1, 0.1, 0.12), 0.5, 0.4)
	Furniture.cyl(_model, 0.031, 0.031, 2.6, alu, Vector3(0, 1.3, 0))
	Furniture.cyl(_model, 0.058, 0.058, 0.05, gra, Vector3(0, 0.025, 0))
	Furniture.cyl(_model, 0.036, 0.036, 0.05, gra, Vector3(0, 2.58, 0))
	var face := Node3D.new()
	face.position = Vector3(0, 2.2, 0.04)
	_model.add_child(face)
	var back := Furniture.cyl(face, 0.31, 0.31, 0.012, alu, Vector3(0, 0, 0), Vector3(PI * 0.5, 0, 0), 24)
	back.position.z = 0.0
	match kind:
		"no_entry":
			Furniture.cyl(face, 0.3, 0.3, 0.01, Furniture.mat("sign_red", Color(0.78, 0.05, 0.06), 0.4), Vector3(0, 0, 0.008), Vector3(PI * 0.5, 0, 0), 28)
			Furniture.box(face, Vector3(0.42, 0.1, 0.008), Furniture.mat("sign_white", Color(0.95, 0.95, 0.93), 0.4), Vector3(0, 0, 0.016))
		"stop":
			Furniture.cyl(face, 0.315, 0.315, 0.01, Furniture.mat("sign_white", Color(0.95, 0.95, 0.93), 0.4), Vector3(0, 0, 0.006), Vector3(PI * 0.5, PI / 8.0, 0), 8)
			Furniture.cyl(face, 0.285, 0.285, 0.01, Furniture.mat("sign_red", Color(0.78, 0.05, 0.06), 0.4), Vector3(0, 0, 0.012), Vector3(PI * 0.5, PI / 8.0, 0), 8)
			for i in 4:
				Furniture.box(face, Vector3(0.05, 0.1, 0.006), Furniture.mat("sign_white", Color(0.95, 0.95, 0.93), 0.4), Vector3(-0.115 + i * 0.077, 0, 0.02))
		_:
			Furniture.cyl(face, 0.3, 0.3, 0.01, Furniture.mat("sign_red", Color(0.78, 0.05, 0.06), 0.4), Vector3(0, 0, 0.008), Vector3(PI * 0.5, 0, 0), 28)
			Furniture.cyl(face, 0.25, 0.25, 0.01, Furniture.mat("sign_blue", Color(0.08, 0.22, 0.62), 0.4), Vector3(0, 0, 0.012), Vector3(PI * 0.5, 0, 0), 28)
			Furniture.box(face, Vector3(0.5, 0.055, 0.006), Furniture.mat("sign_red", Color(0.78, 0.05, 0.06), 0.4), Vector3(0, 0, 0.019), Vector3(0, 0, PI * 0.25))
			Furniture.box(face, Vector3(0.5, 0.055, 0.006), Furniture.mat("sign_red", Color(0.78, 0.05, 0.06), 0.4), Vector3(0, 0, 0.022), Vector3(0, 0, -PI * 0.25))
	Furniture.col_cyl(self, 0.05, 2.6, Vector3(0, 1.3, 0))


func _on_wobble(k: float) -> void:
	# chaque coup tord un peu plus le poteau dans le sens du coup (axe de rotation = -_wob_axis)
	_perm = -_wob_axis * (0.1 * k)
