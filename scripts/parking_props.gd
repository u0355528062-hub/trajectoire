class_name ParkingProps
extends RefCounted
## Mobilier vandalisable du parking et de la station de vélos (tous dérivés de `StreetProp`, groupe « kickable ») :
## scooters et motos sur béquille, vélos en libre-service, bras de barrière levante, horodateur, panneau « P ».
## Les modèles sont fusionnés par matériau (`GeoBatch`) et partagés entre exemplaires identiques.

const DIR := "res://assets/quartier/"

static var _meshes := {}


static func m(key: String, c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	return Furniture.mat("pk_" + key, c, rough, metal)


static func tex_mat(key: String, file: String, alpha := false) -> StandardMaterial3D:
	var mm := Furniture.mat("pk_tex_" + key, Color(1, 1, 1), 0.5)
	if mm.albedo_texture == null:
		mm.albedo_texture = load(DIR + file)
		if alpha:
			mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mm.alpha_scissor_threshold = 0.5
	return mm


static func _mesh(key: String, make: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = make.call()
	return _meshes[key]


static func _wheel(b: GeoBatch, c: Vector3, r: float, w: float, tire: Material, hub: Material, spokes := 0) -> void:
	var t := TorusMesh.new()
	t.inner_radius = r - w
	t.outer_radius = r
	t.rings = 18
	t.ring_segments = 6
	var bas := Basis(Vector3.BACK, PI * 0.5)
	b.add_mesh("tire", tire, t, Transform3D(bas, c))
	if spokes > 0:
		for k in spokes:
			var a := PI * float(k) / float(spokes)
			b.box("hub", hub, Vector3(0.006, (r - w) * 2.0, 0.006), c, Basis(Vector3.RIGHT, a))
		b.cyl("hub", hub, 0.03, 0.03, 0.08, c, bas, 8)
	else:
		b.cyl("hub", hub, r - w * 0.9, r - w * 0.9, w * 0.9, c, bas, 14)


# =================================================================== deux-roues motorisés
## Scooter (« scooter ») ou moto (« moto ») garé sur sa béquille : un coup de pied et il se couche sur le flanc
class Scooter:
	extends StreetProp
	var kind := "scooter"
	var color := Color(0.85, 0.85, 0.83)
	var top_case := false

	func _build() -> void:
		mass = 95.0 if kind == "scooter" else 160.0
		damage_limit = 1.0
		top_y = 0.95
		reach = Vector3(0.45, 1.3, 1.0)
		nav_half = Vector2(0.38, 0.95)
		vandal_amount = 0.25
		hit_sound = "car_dent_1"
		fall_sound = "barrier_fall"
		var key := "%s_%s_%s" % [kind, color.to_html(false), top_case]
		var mesh := ParkingProps._mesh(key, _make)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.visibility_range_end = 80.0
		_model.add_child(mi)
		_model.rotation.z = 0.09           # appuyé sur la béquille latérale
		Furniture.col_box(self, Vector3(0.42, 0.8, 1.7), Vector3(0, 0.55, 0))
		center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = Vector3(0, 0.45, 0)

	func _make() -> Mesh:
		var b := GeoBatch.new()
		var paint := ParkingProps.m("moto_" + color.to_html(false), color, 0.28, 0.2)
		paint.clearcoat_enabled = true
		paint.clearcoat = 0.8
		var blk := ParkingProps.m("moto_black", Color(0.03, 0.03, 0.035), 0.55)
		var tire := ParkingProps.m("moto_tire", Color(0.025, 0.025, 0.028), 0.9)
		var alu := ParkingProps.m("moto_alu", Color(0.62, 0.63, 0.66), 0.3, 0.9)
		var seat := ParkingProps.m("moto_seat", Color(0.04, 0.035, 0.03), 0.75)
		var lamp := ParkingProps.m("moto_lamp", Color(0.85, 0.86, 0.9), 0.1, 0.4)
		var red := ParkingProps.m("moto_tail", Color(0.5, 0.02, 0.02), 0.2)
		if kind == "scooter":
			ParkingProps._wheel(b, Vector3(0, 0.22, -0.62), 0.22, 0.07, tire, alu)
			ParkingProps._wheel(b, Vector3(0, 0.22, 0.6), 0.22, 0.07, tire, alu)
			# tablier, plancher, coque arrière, selle
			b.box("paint", paint, Vector3(0.42, 0.75, 0.12), Vector3(0, 0.72, -0.52), Basis(Vector3.RIGHT, -0.32), 0.05)
			b.box("paint", paint, Vector3(0.3, 0.09, 0.62), Vector3(0, 0.33, -0.08), Basis(), 0.03)
			b.box("paint", paint, Vector3(0.36, 0.34, 0.72), Vector3(0, 0.55, 0.42), Basis(Vector3.RIGHT, 0.12), 0.1)
			b.box("seat", seat, Vector3(0.3, 0.1, 0.68), Vector3(0, 0.76, 0.32), Basis(Vector3.RIGHT, 0.05), 0.045)
			b.box("paint", paint, Vector3(0.12, 0.4, 0.12), Vector3(0, 0.38, -0.66), Basis(Vector3.RIGHT, -0.35), 0.03)
			b.box("paint", paint, Vector3(0.2, 0.08, 0.36), Vector3(0, 0.46, -0.66), Basis(), 0.03)
			# guidon, rétroviseurs, phare
			b.box("blk", blk, Vector3(0.68, 0.035, 0.035), Vector3(0, 1.07, -0.52), Basis(), 0.0)
			b.box("paint", paint, Vector3(0.24, 0.12, 0.14), Vector3(0, 1.08, -0.55), Basis(), 0.04)
			b.box("lamp", lamp, Vector3(0.14, 0.08, 0.03), Vector3(0, 1.08, -0.63), Basis(), 0.02)
			for sx in [-1.0, 1.0]:
				b.box("blk", blk, Vector3(0.015, 0.2, 0.015), Vector3(sx * 0.25, 1.17, -0.52), Basis(Vector3.BACK, sx * 0.2), 0.0)
				b.box("blk", blk, Vector3(0.09, 0.06, 0.02), Vector3(sx * 0.28, 1.28, -0.52), Basis(), 0.01)
			b.box("red", red, Vector3(0.16, 0.05, 0.03), Vector3(0, 0.66, 0.79), Basis(), 0.01)
			b.cyl("alu", alu, 0.035, 0.04, 0.4, Vector3(0.14, 0.3, 0.55), Basis(Vector3.RIGHT, PI * 0.5 - 0.15), 10)
			if top_case:
				b.box("blk", blk, Vector3(0.4, 0.3, 0.38), Vector3(0, 0.96, 0.62), Basis(), 0.06)
		else:
			ParkingProps._wheel(b, Vector3(0, 0.31, -0.7), 0.31, 0.09, tire, alu)
			ParkingProps._wheel(b, Vector3(0, 0.31, 0.68), 0.31, 0.1, tire, alu)
			# réservoir, selle, moteur, fourche, échappement
			b.box("paint", paint, Vector3(0.34, 0.24, 0.52), Vector3(0, 0.92, -0.2), Basis(Vector3.RIGHT, -0.12), 0.1)
			b.box("seat", seat, Vector3(0.28, 0.1, 0.56), Vector3(0, 0.88, 0.3), Basis(Vector3.RIGHT, 0.06), 0.04)
			b.box("paint", paint, Vector3(0.2, 0.12, 0.34), Vector3(0, 0.9, 0.62), Basis(Vector3.RIGHT, -0.25), 0.04)
			b.box("blk", blk, Vector3(0.3, 0.36, 0.42), Vector3(0, 0.5, -0.06), Basis(), 0.06)
			b.box("alu", alu, Vector3(0.34, 0.2, 0.14), Vector3(0, 0.62, -0.22), Basis(), 0.04)
			for sx in [-1.0, 1.0]:
				b.cyl("alu", alu, 0.022, 0.022, 0.75, Vector3(sx * 0.09, 0.66, -0.6), Basis(Vector3.RIGHT, -0.4), 8)
			b.cyl("alu", alu, 0.04, 0.045, 0.6, Vector3(0.17, 0.42, 0.42), Basis(Vector3.RIGHT, PI * 0.5 - 0.25), 10)
			b.box("blk", blk, Vector3(0.72, 0.03, 0.03), Vector3(0, 1.08, -0.42), Basis(), 0.0)
			b.cyl("lamp", lamp, 0.09, 0.09, 0.08, Vector3(0, 0.98, -0.66), Basis(Vector3.RIGHT, PI * 0.5), 14)
			b.box("red", red, Vector3(0.12, 0.05, 0.03), Vector3(0, 0.86, 0.8), Basis(), 0.01)
			b.box("blk", blk, Vector3(0.05, 0.05, 0.3), Vector3(0, 0.7, 0.2), Basis(), 0.0)
		return b.build()

	## Tombe toujours sur le flanc, du côté où on l'a poussé
	func topple(dir: Vector3) -> void:
		var side := global_basis.x
		super.topple(side * (1.0 if dir.dot(side) >= 0.0 else -1.0))


# =================================================================== vélo en libre-service
## Vélo de la station (cadre gris, garde-boue et panier vert) : un coup de pied le fait tomber de sa borne
class SharedBike:
	extends StreetProp
	var electric := false

	func _build() -> void:
		mass = 23.0
		damage_limit = 1.0
		top_y = 0.9
		reach = Vector3(0.35, 1.2, 0.95)
		nav_half = Vector2(0.3, 0.88)
		vandal_amount = 0.15
		hit_sound = "barrier_hit"
		fall_sound = "barrier_fall"
		var mi := MeshInstance3D.new()
		mi.mesh = ParkingProps._mesh("bike_%s" % electric, _make)
		mi.visibility_range_end = 70.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_model.add_child(mi)
		Furniture.col_box(self, Vector3(0.24, 0.75, 1.7), Vector3(0, 0.5, 0))
		center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = Vector3(0, 0.5, 0)

	func _make() -> Mesh:
		var b := GeoBatch.new()
		var frame := ParkingProps.m("bike_frame", Color(0.42, 0.44, 0.45), 0.4, 0.5)
		var green := ParkingProps.m("bike_green", Color(0.33, 0.62, 0.22) if not electric else Color(0.12, 0.42, 0.62), 0.45)
		var tire := ParkingProps.m("bike_tire", Color(0.03, 0.03, 0.03), 0.9)
		var alu := ParkingProps.m("bike_alu", Color(0.7, 0.71, 0.73), 0.3, 0.9)
		var blk := ParkingProps.m("bike_black", Color(0.05, 0.05, 0.05), 0.6)
		ParkingProps._wheel(b, Vector3(0, 0.33, -0.56), 0.33, 0.035, tire, alu, 9)
		ParkingProps._wheel(b, Vector3(0, 0.33, 0.56), 0.33, 0.035, tire, alu, 9)
		# cadre ouvert (col de cygne), tube de selle, bases
		b.add_mesh("frame", frame, MeshKit.tube(PackedVector3Array([Vector3(0, 0.95, -0.42), Vector3(0, 0.62, -0.28), Vector3(0, 0.36, 0.0), Vector3(0, 0.36, 0.08)]), 0.032, 8, true))
		b.add_mesh("frame", frame, MeshKit.tube(PackedVector3Array([Vector3(0, 0.36, 0.06), Vector3(0, 0.82, 0.2)]), 0.03, 8, true))
		for sx in [-1.0, 1.0]:
			b.add_mesh("frame", frame, MeshKit.tube(PackedVector3Array([Vector3(sx * 0.05, 0.36, 0.06), Vector3(sx * 0.05, 0.33, 0.56)]), 0.016, 6, true))
			b.add_mesh("frame", frame, MeshKit.tube(PackedVector3Array([Vector3(sx * 0.05, 0.78, 0.2), Vector3(sx * 0.05, 0.33, 0.56)]), 0.014, 6, true))
			b.add_mesh("frame", frame, MeshKit.tube(PackedVector3Array([Vector3(sx * 0.045, 0.95, -0.42), Vector3(sx * 0.045, 0.33, -0.56)]), 0.018, 6, true))
		# carter de chaîne, garde-boue, selle, guidon, panier avant
		b.box("green", green, Vector3(0.05, 0.13, 0.62), Vector3(0.09, 0.36, 0.28), Basis(), 0.03)
		b.add_mesh("green", green, MeshKit.tube(PackedVector3Array([Vector3(0, 0.5, 0.36), Vector3(0, 0.66, 0.6), Vector3(0, 0.6, 0.86), Vector3(0, 0.4, 0.92)]), 0.035, 6, false))
		b.add_mesh("green", green, MeshKit.tube(PackedVector3Array([Vector3(0, 0.6, -0.42), Vector3(0, 0.67, -0.6), Vector3(0, 0.58, -0.82)]), 0.035, 6, false))
		b.box("blk", blk, Vector3(0.17, 0.07, 0.27), Vector3(0, 0.88, 0.22), Basis(), 0.03)
		b.box("blk", blk, Vector3(0.6, 0.03, 0.03), Vector3(0, 1.07, -0.36), Basis(), 0.0)
		b.box("frame", frame, Vector3(0.03, 0.14, 0.03), Vector3(0, 1.0, -0.4), Basis(), 0.0)
		for sx in [-1.0, 1.0]:
			b.box("blk", blk, Vector3(0.1, 0.035, 0.04), Vector3(sx * 0.27, 1.07, -0.36), Basis(), 0.012)
		# panier : fond et parois ajourées
		b.box("green", green, Vector3(0.38, 0.02, 0.3), Vector3(0, 0.84, -0.66), Basis(), 0.0)
		for k in 4:
			b.box("green", green, Vector3(0.38, 0.018, 0.012), Vector3(0, 0.88 + k * 0.05, -0.81), Basis(), 0.0)
			b.box("green", green, Vector3(0.38, 0.018, 0.012), Vector3(0, 0.88 + k * 0.05, -0.51), Basis(), 0.0)
			for sx in [-1.0, 1.0]:
				b.box("green", green, Vector3(0.012, 0.018, 0.3), Vector3(sx * 0.19, 0.88 + k * 0.05, -0.66), Basis(), 0.0)
		if electric:
			b.box("blk", blk, Vector3(0.09, 0.26, 0.1), Vector3(0, 0.55, 0.0), Basis(Vector3.RIGHT, 0.6), 0.03)
		return b.build()

	func topple(dir: Vector3) -> void:
		var side := global_basis.x
		super.topple(side * (1.0 if dir.dot(side) >= 0.0 else -1.0))


# =================================================================== barrière levante
## Bras de barrière (rayé rouge et blanc) : l'origine est au sol sous le milieu du bras ; deux coups de pied et il
## se casse net au ras du boîtier, puis tombe.
class GateArm:
	extends StreetProp
	var length := 3.3

	func _build() -> void:
		mass = 9.0
		damage_limit = 2.0
		top_y = 1.0
		reach = Vector3(length * 0.5, 1.35, 0.3)
		nav_half = Vector2(length * 0.5, 0.08)
		vandal_amount = 0.3
		hit_sound = "sign_bend"
		fall_sound = "sign_fall"
		var mi := MeshInstance3D.new()
		mi.mesh = ParkingProps._mesh("gate_%.2f" % length, _make)
		_model.add_child(mi)
		Furniture.col_box(self, Vector3(length, 0.09, 0.07), Vector3(0, 1.0, 0))

	func _make() -> Mesh:
		var b := GeoBatch.new()
		var red := ParkingProps.m("gate_red", Color(0.72, 0.05, 0.05), 0.35)
		var white := ParkingProps.m("gate_white", Color(0.92, 0.92, 0.9), 0.35)
		var n := int(length / 0.3)
		for k in n:
			var x := -length * 0.5 + (float(k) + 0.5) * (length / n)
			b.box("red" if k % 2 == 0 else "white", red if k % 2 == 0 else white, Vector3(length / n + 0.001, 0.08, 0.06), Vector3(x, 1.0, 0), Basis(), 0.0)
		return b.build()

	func _on_toppled(_d: Vector3) -> void:
		# éclats au point de rupture
		for i in 4:
			var sh := RigidBody3D.new()
			sh.collision_layer = 0
			sh.collision_mask = 1
			sh.mass = 0.2
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(randf_range(0.04, 0.1), 0.03, 0.03)
			mi.mesh = bm
			mi.material_override = ParkingProps.m("gate_white", Color(0.92, 0.92, 0.9), 0.35)
			sh.add_child(mi)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = bm.size
			cs.shape = bs
			sh.add_child(cs)
			get_tree().current_scene.add_child(sh)
			sh.global_position = global_transform * Vector3(length * 0.5, 1.0, 0)
			sh.linear_velocity = Vector3(randf_range(-2, 2), randf_range(1, 3), randf_range(-2, 2))
			Fx.after(sh, 8.0, Fx.shrink_and_free.bind(sh, 0.6))


# =================================================================== horodateur
## Horodateur : il encaisse trois coups avant de basculer et de cracher sa monnaie
class PayStation:
	extends StreetProp

	func _build() -> void:
		mass = 70.0
		damage_limit = 3.0
		top_y = 1.4
		reach = Vector3(0.3, 1.6, 0.3)
		nav_half = Vector2(0.25, 0.2)
		vandal_amount = 0.3
		hit_sound = "news_box_hit"
		fall_sound = "sign_fall"
		var mi := MeshInstance3D.new()
		mi.mesh = ParkingProps._mesh("paystation", _make)
		_model.add_child(mi)
		Furniture.col_box(self, Vector3(0.4, 1.6, 0.3), Vector3(0, 0.8, 0))
		center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = Vector3(0, 0.7, 0)

	func _make() -> Mesh:
		var b := GeoBatch.new()
		var body := ParkingProps.m("pay_body", Color(0.16, 0.18, 0.2), 0.45, 0.6)
		var grey := ParkingProps.m("pay_grey", Color(0.55, 0.57, 0.6), 0.4, 0.7)
		var face := ParkingProps.tex_mat("paystation", "paystation.png")
		b.box("body", body, Vector3(0.18, 0.7, 0.16), Vector3(0, 0.35, 0), Basis(), 0.02)
		b.box("body", body, Vector3(0.38, 0.95, 0.26), Vector3(0, 1.15, 0), Basis(), 0.04)
		b.box("grey", grey, Vector3(0.42, 0.06, 0.3), Vector3(0, 1.65, 0), Basis(), 0.025)
		b.box("grey", grey, Vector3(0.3, 0.04, 0.22), Vector3(0, 0.02, 0), Basis(), 0.01)
		b.poly_facing("face", face, PackedVector3Array([Vector3(0.17, 0.72, -0.131), Vector3(-0.17, 0.72, -0.131), Vector3(-0.17, 1.6, -0.131), Vector3(0.17, 1.6, -0.131)]),
			Vector3(0, 0, -1), PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]))
		# panneau solaire sur le toit
		b.box("grey", ParkingProps.m("pay_solar", Color(0.05, 0.07, 0.14), 0.15, 0.3), Vector3(0.36, 0.015, 0.26), Vector3(0, 1.69, 0), Basis(Vector3.RIGHT, -0.2), 0.0)
		return b.build()

	func _on_toppled(_d: Vector3) -> void:
		AudioLib.play_at(self, "can_clink", global_position + Vector3.UP * 0.8, 0.0, 6.0)
		var coin := ParkingProps.m("pay_coin", Color(0.8, 0.66, 0.3), 0.3, 0.9)
		for i in 9:
			var c := RigidBody3D.new()
			c.collision_layer = 0
			c.collision_mask = 1
			c.mass = 0.01
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.012
			cm.bottom_radius = 0.012
			cm.height = 0.003
			cm.radial_segments = 8
			mi.mesh = cm
			mi.material_override = coin
			c.add_child(mi)
			var cs := CollisionShape3D.new()
			var sh := CylinderShape3D.new()
			sh.radius = 0.012
			sh.height = 0.004
			cs.shape = sh
			c.add_child(cs)
			get_tree().current_scene.add_child(c)
			c.global_position = global_transform * Vector3(randf_range(-0.1, 0.1), 0.9, -0.15)
			c.linear_velocity = Vector3(randf_range(-1.5, 1.5), randf_range(1, 2.5), randf_range(-1.5, 1.5))
			Fx.after(c, 14.0, c.queue_free)


# =================================================================== panneau « P »
## Panneau de parking sur poteau (avec panonceau « PARKING ») : se tord sous les coups puis tombe
class ParkSign:
	extends StreetProp

	func _build() -> void:
		mass = 16.0
		damage_limit = 3.2
		top_y = 2.4
		reach = Vector3(0.35, 1.7, 0.35)
		nav_half = Vector2(0.1, 0.1)
		vandal_amount = 0.3
		hit_sound = "sign_bend"
		fall_sound = "sign_fall"
		var mi := MeshInstance3D.new()
		mi.mesh = ParkingProps._mesh("psign", _make)
		_model.add_child(mi)
		Furniture.col_cyl(self, 0.05, 2.9, Vector3(0, 1.45, 0))

	func _make() -> Mesh:
		var b := GeoBatch.new()
		var alu := ParkingProps.m("sign_alu", Color(0.72, 0.74, 0.77), 0.35, 0.85)
		var gra := ParkingProps.m("sign_graphite", Color(0.1, 0.1, 0.12), 0.5, 0.4)
		var face := ParkingProps.tex_mat("sign_p", "sign_p.png", true)
		b.cyl("alu", alu, 0.031, 0.031, 2.9, Vector3(0, 1.45, 0), Basis(), 10)
		b.cyl("gra", gra, 0.058, 0.058, 0.05, Vector3(0, 0.025, 0), Basis(), 12)
		b.box("alu", alu, Vector3(0.6, 0.9, 0.012), Vector3(0, 2.3, 0.035), Basis(), 0.0)
		var w := 0.3
		b.poly("face", face, PackedVector3Array([Vector3(w, 1.85, 0.043), Vector3(-w, 1.85, 0.043), Vector3(-w, 2.75, 0.043), Vector3(w, 2.75, 0.043)]), false,
			PackedVector2Array([Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0)]))
		return b.build()

	func _on_wobble(k: float) -> void:
		_perm = -_wob_axis * (0.1 * k)
