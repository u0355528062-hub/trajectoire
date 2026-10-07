class_name PublicBin
extends StreetProp
## Poubelle de rue (corbeille) : un coup de pied l'ébranle, le deuxième la renverse et répand les détritus
## (papiers qu'on peut ramasser et brûler).

var litter := 4


func _build() -> void:
	mass = 14.0
	damage_limit = 1.6
	top_y = 0.8
	reach = Vector3(0.34, 1.0, 0.34)
	nav_half = Vector2(0.26, 0.26)
	vandal_amount = 0.12
	hit_sound = "sfx:metal_clang_s"
	fall_sound = "sfx:metal_fall"
	var green := Furniture.mat("pbin_green", Color(0.1, 0.24, 0.17), 0.4, 0.5)
	var gra := Furniture.mat("graphite", Color(0.1, 0.1, 0.12), 0.5, 0.4)
	var dark := Furniture.mat("pbin_dark", Color(0.03, 0.03, 0.035), 0.9)
	Furniture.cyl(_model, 0.23, 0.23, 0.82, green, Vector3(0, 0.49, 0))
	Furniture.cyl(_model, 0.25, 0.25, 0.05, gra, Vector3(0, 0.92, 0))
	Furniture.cyl(_model, 0.2, 0.2, 0.005, dark, Vector3(0, 0.948, 0))
	Furniture.cyl(_model, 0.05, 0.05, 0.1, gra, Vector3(0, 0.04, 0))
	Furniture.box(_model, Vector3(0.18, 0.04, 0.02), gra, Vector3(0, 0.76, 0.235))
	Furniture.col_cyl(self, 0.25, 0.95, Vector3(0, 0.475, 0))
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.4, 0)


func _on_toppled(d: Vector3) -> void:
	var up := Vector3.UP
	for i in litter:
		var b := Burnable.make("paper")
		get_tree().current_scene.add_child(b)
		b.global_position = global_position + Vector3(randf_range(-0.1, 0.1), 0.95, randf_range(-0.1, 0.1))
		b.linear_velocity = d * randf_range(0.8, 2.4) + up * randf_range(0.5, 1.8) + Vector3(randf_range(-0.7, 0.7), 0, randf_range(-0.7, 0.7))
		b.angular_velocity = Vector3(randf_range(-7, 7), randf_range(-7, 7), randf_range(-7, 7))
	litter = 0
