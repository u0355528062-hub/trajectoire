class_name Planter
extends StreetProp
## Pot de fleurs en terre cuite : un coup de pied le couche, le deuxième (ou une chute) le fait éclater
## en morceaux et en terre.

var _smashed := false


func _build() -> void:
	mass = 12.0
	damage_limit = 1.0
	top_y = 0.4
	reach = Vector3(0.4, 0.5, 0.4)
	nav_half = Vector2(0.27, 0.27)
	vandal_amount = 0.12
	hit_sound = "sfx:pot_smash"
	fall_sound = "sfx:whump"
	var clay := Furniture.mat("clay", Color(0.62, 0.3, 0.17), 0.8)
	var soil := Furniture.mat("soil", Color(0.16, 0.1, 0.07), 0.95)
	var pot := MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.15, 0.0), Vector2(0.19, 0.04), Vector2(0.245, 0.36), Vector2(0.275, 0.4), Vector2(0.275, 0.44), Vector2(0.24, 0.445), Vector2(0.225, 0.4), Vector2(0.0, 0.4)]), 18)
	Furniture.add(_model, pot, clay)
	Furniture.cyl(_model, 0.225, 0.225, 0.02, soil, Vector3(0, 0.39, 0))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var greens := [Furniture.mat("leaf", Color(0.12, 0.34, 0.1), 0.7), Furniture.mat("leaf2", Color(0.2, 0.44, 0.13), 0.7), Furniture.mat("leaf3", Color(0.08, 0.26, 0.09), 0.7)]
	# feuillage : des lames qui partent du centre en éventail
	for i in 22:
		var blade := CylinderMesh.new()
		blade.top_radius = 0.0
		blade.bottom_radius = rng.randf_range(0.022, 0.04)
		blade.height = rng.randf_range(0.26, 0.46)
		blade.radial_segments = 5
		var holder := Node3D.new()
		holder.position = Vector3(rng.randf_range(-0.07, 0.07), 0.4, rng.randf_range(-0.07, 0.07))
		holder.rotation = Vector3(0, rng.randf() * TAU, rng.randf_range(0.15, 0.85))
		_model.add_child(holder)
		var bm := Furniture.add(holder, blade, greens[i % 3], Vector3(0, blade.height * 0.5, 0))
		bm.scale = Vector3(1.0, 1.0, 0.45)
	var flower := Furniture.mat("flower", Color(0.85, 0.2, 0.35), 0.6)
	var flower2 := Furniture.mat("flower2", Color(0.95, 0.75, 0.15), 0.6)
	for i in 7:
		var fs := SphereMesh.new()
		fs.radius = 0.04
		fs.height = 0.08
		fs.radial_segments = 6
		fs.rings = 3
		var ang := rng.randf() * TAU
		var rr := rng.randf_range(0.08, 0.22)
		Furniture.add(_model, fs, flower if i % 3 != 0 else flower2, Vector3(cos(ang) * rr, 0.62 + rng.randf() * 0.2, sin(ang) * rr))
	Furniture.col_cyl(self, 0.24, 0.42, Vector3(0, 0.21, 0))
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.22, 0)


func kick(point: Vector3, dir: Vector3, power := 1.0) -> bool:
	if _smashed:
		return false
	var l := to_local(point)
	if absf(l.x) > reach.x or absf(l.z) > reach.z or l.y > reach.y + 0.2:
		return false
	var d := Vector3(dir.x, 0, dir.z).normalized()
	if toppled:
		_smash(point, d)
		return true
	# premier coup : le pot part en vol / se couche
	topple(d)
	apply_impulse(d * mass * (2.0 + 1.2 * power) + Vector3.UP * mass * 0.8, point - global_position)
	return true


func _on_body(_b: Node) -> void:
	if toppled and not _smashed and linear_velocity.length() > 2.4 and _b is StaticBody3D:
		_smash(global_position, linear_velocity.normalized())


func _smash(pos: Vector3, dir: Vector3) -> void:
	if _smashed:
		return
	_smashed = true
	AudioLib.play_at(self, "sfx:pot_smash", global_position + Vector3.UP * 0.1, 0.0, 9.0, randf_range(0.92, 1.1))
	var scene := get_tree().current_scene
	var clay := Furniture.mat("clay", Color(0.62, 0.3, 0.17), 0.8)
	var soil := Furniture.mat("soil", Color(0.16, 0.1, 0.07), 0.95)
	for i in 11:
		var sh := RigidBody3D.new()
		sh.collision_layer = 4
		sh.collision_mask = 1
		sh.mass = 0.12
		var bm := BoxMesh.new()
		var sz := Vector3(randf_range(0.04, 0.12), randf_range(0.015, 0.03), randf_range(0.04, 0.1))
		bm.size = sz
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = clay
		sh.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = sz
		cs.shape = bs
		sh.add_child(cs)
		scene.add_child(sh)
		sh.global_position = global_position + Vector3(randf_range(-0.15, 0.15), 0.1 + randf() * 0.25, randf_range(-0.15, 0.15))
		sh.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		sh.linear_velocity = dir * randf_range(0.8, 3.0) + Vector3(randf_range(-1.5, 1.5), randf_range(1.0, 3.2), randf_range(-1.5, 1.5))
		sh.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		var life := randf_range(18.0, 30.0)
		get_tree().create_timer(life).timeout.connect(func():
			if is_instance_valid(sh):
				Fx.shrink_and_free(sh, 0.8))
	# terre + feuillage éparpillés
	var dust := Fx.smoke(Color(0.28, 0.2, 0.14, 0.55), 12, 1.6, 0.5, true, 0.5, 2.4)
	dust.one_shot = true
	dust.explosiveness = 0.95
	scene.add_child(dust)
	dust.global_position = global_position + Vector3(0, 0.25, 0)
	dust.emitting = true
	get_tree().create_timer(3.0).timeout.connect(func(): if is_instance_valid(dust): dust.queue_free())
	for i in 7:
		var lf := RigidBody3D.new()
		lf.collision_layer = 4
		lf.collision_mask = 1
		lf.mass = 0.08
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.14
		sm.radial_segments = 6
		sm.rings = 3
		var lm := MeshInstance3D.new()
		lm.mesh = sm
		lm.material_override = Furniture.mat("leaf", Color(0.12, 0.34, 0.1), 0.7) if i % 2 == 0 else soil
		lf.add_child(lm)
		var lcs := CollisionShape3D.new()
		var ss := SphereShape3D.new()
		ss.radius = 0.06
		lcs.shape = ss
		lf.add_child(lcs)
		scene.add_child(lf)
		lf.global_position = global_position + Vector3(randf_range(-0.12, 0.12), 0.3 + randf() * 0.2, randf_range(-0.12, 0.12))
		lf.linear_velocity = dir * randf_range(0.5, 2.0) + Vector3(randf_range(-1.2, 1.2), randf_range(0.5, 2.5), randf_range(-1.2, 1.2))
		var lfr := lf
		get_tree().create_timer(randf_range(14.0, 24.0)).timeout.connect(func():
			if is_instance_valid(lfr):
				Fx.shrink_and_free(lfr, 0.8))
	get_tree().call_group("crowd", "on_event", "vandal", {"pos": global_position, "amount": 0.25})
	if _nav_in and crowd != null:
		crowd.remove_obstacle(self)
		_nav_in = false
	queue_free()
