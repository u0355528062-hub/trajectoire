class_name CopGear
extends RefCounted
## Équipement des CRS, modélisé à la main : casque à visière, masque à gaz, gilet pare-coups, épaulières,
## protège-bras, genouillères, jambières, ceinture ; et ce qu'ils tiennent : bouclier, matraque, LBD,
## lance-grenades, bombe lacrymogène, menottes. Les pièces fixes se collent aux os (suivent l'animation).
## Repère des pièces : celui du squelette (devant = +Z, haut = +Y, gauche du personnage = +X), mètres.

static var _m := {}
static var _mesh := {}


static func mat(key: String) -> Material:
	if _m.has(key):
		return _m[key]
	var r: StandardMaterial3D
	match key:
		"shell":
			r = MeshKit.std_mat(Color(0.035, 0.04, 0.06), 0.3, 0.1, 0.8)
		"navy":
			r = MeshKit.std_mat(Color(0.045, 0.06, 0.11), 0.72, 0.0, 0.35)
		"black":
			r = MeshKit.std_mat(Color(0.03, 0.03, 0.035), 0.55, 0.0, 0.55)
		"rubber":
			r = MeshKit.std_mat(Color(0.025, 0.025, 0.03), 0.92, 0.0, 0.15)
		"plate":
			r = MeshKit.std_mat(Color(0.06, 0.07, 0.1), 0.45, 0.0, 0.6)
		"fabric":
			r = MeshKit.std_mat(Color(0.05, 0.065, 0.1), 0.9, 0.0, 0.2)
		"metal":
			r = MeshKit.std_mat(Color(0.62, 0.64, 0.68), 0.28, 0.9, 0.7)
		"steel_dark":
			r = MeshKit.std_mat(Color(0.14, 0.15, 0.17), 0.4, 0.85, 0.6)
		"visor":
			r = MeshKit.std_mat(Color(0.42, 0.52, 0.62, 0.2), 0.05, 0.0, 1.0)
			r.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			r.cull_mode = BaseMaterial3D.CULL_DISABLED
		"shield":
			r = MeshKit.std_mat(Color(0.7, 0.82, 0.95, 1.0), 0.08, 0.0, 1.0)
			r.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			r.cull_mode = BaseMaterial3D.CULL_DISABLED
			r.albedo_texture = load(Props.DIR + "shield.png")
			r.metallic_specular = 1.0
		"white":
			r = MeshKit.std_mat(Color(0.9, 0.9, 0.92), 0.6, 0.0, 0.3)
		"red":
			r = MeshKit.std_mat(Color(0.7, 0.08, 0.06), 0.5, 0.0, 0.4)
		"orange":
			r = MeshKit.std_mat(Color(0.9, 0.42, 0.06), 0.5, 0.0, 0.4)
		_:
			r = MeshKit.std_mat(Color(0.5, 0.5, 0.5))
	_m[key] = r
	return r


static func _cached(key: String, maker: Callable) -> Mesh:
	if not _mesh.has(key):
		_mesh[key] = maker.call()
	return _mesh[key]


static func _xf(pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled(scl), pos)


# ------------------------------------------------------------------ tête
## Casque : coque, jugulaire arrière, visière relevable (origine = centre de la tête, devant = +Z)
static func helmet() -> Node3D:
	var root := Node3D.new()
	root.name = "Helmet"
	var shell := _cached("helmet_shell", func() -> Mesh:
		var prof := PackedVector2Array([Vector2(0.1, -0.075), Vector2(0.108, -0.045), Vector2(0.111, 0.0), Vector2(0.105, 0.04), Vector2(0.088, 0.078),
			Vector2(0.058, 0.105), Vector2(0.025, 0.118), Vector2(0.0, 0.121)])
		var dome := MeshKit.lathe(prof, 28, 50.0)
		var parts := [[dome, _xf(Vector3.ZERO, Vector3.ZERO, Vector3(0.97, 1.0, 1.17))]]
		# jugulaire / protège-nuque : bande évasée à l'arrière
		parts.append([MeshKit.curved_panel(0.2, 0.075, 0.022, 10, 3, 0.012), _xf(Vector3(0, -0.062, -0.1), Vector3(deg_to_rad(-12), PI, 0))])
		# rebord avant renforcé (bandeau)
		parts.append([MeshKit.rbox(Vector3(0.215, 0.012, 0.03), 0.005, 2), _xf(Vector3(0, -0.012, 0.126))])
		# arête médiane
		parts.append([MeshKit.rbox(Vector3(0.016, 0.012, 0.24), 0.005, 2), _xf(Vector3(0, 0.116, 0.0), Vector3(deg_to_rad(-6), 0, 0))])
		return MeshKit.merge(parts))
	MeshKit.mesh_instance(shell, mat("shell"), Vector3.ZERO, Vector3.ZERO, root)
	var visor := _cached("helmet_visor", func() -> Mesh:
		return MeshKit.curved_panel(0.19, 0.088, 0.034, 12, 3, 0.004))
	var pivot := Node3D.new()      # charnière : rotation.x = 0 visière baissée, -1.9 relevée
	pivot.name = "Visor"
	pivot.position = Vector3(0, 0.035, 0.1)
	root.add_child(pivot)
	var vis := MeshKit.mesh_instance(visor, mat("visor"), Vector3(0, -0.047, 0.037), Vector3(deg_to_rad(-6), 0, 0), pivot)
	vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# charnières de visière
	for sx in [-1.0, 1.0]:
		MeshKit.mesh_instance(_cached("hinge", func() -> Mesh: return MeshKit.rbox(Vector3(0.016, 0.026, 0.026), 0.005, 2)), mat("steel_dark"), Vector3(sx * 0.101, 0.012, 0.06), Vector3.ZERO, root)
	return root


## Masque à gaz (origine au centre de la tête)
static func gas_mask() -> Node3D:
	var root := Node3D.new()
	root.name = "Mask"
	var body := _cached("mask_body", func() -> Mesh:
		var prof := PackedVector2Array([Vector2(0.0, -0.05), Vector2(0.055, -0.045), Vector2(0.07, -0.02), Vector2(0.075, 0.015), Vector2(0.068, 0.045), Vector2(0.0, 0.06)])
		var lath := MeshKit.lathe(prof, 20, 50.0)
		var parts := [[lath, _xf(Vector3(0, 0, 0), Vector3(deg_to_rad(90), 0, 0), Vector3(1.0, 1.0, 1.0))]]
		return MeshKit.merge(parts))
	# demi-ellipsoïde posé sur le visage
	var face := MeshKit.mesh_instance(_cached("mask_face", func() -> Mesh:
		var prof := PackedVector2Array([Vector2(0.0, -0.03), Vector2(0.06, -0.02), Vector2(0.078, 0.0), Vector2(0.07, 0.03), Vector2(0.035, 0.05), Vector2(0.0, 0.055)])
		return MeshKit.lathe(prof, 20, 50.0)), mat("rubber"), Vector3(0, -0.042, 0.095), Vector3(deg_to_rad(80), 0, 0), root)
	face.scale = Vector3(1.0, 1.0, 1.0)
	# cartouche filtrante sur la joue
	MeshKit.mesh_instance(_cached("mask_filter", func() -> Mesh:
		var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.032, 0.012), Vector2(0.032, 0.05), Vector2(0.028, 0.058), Vector2(0.0, 0.058)])
		return MeshKit.lathe(prof, 14, 40.0)), mat("steel_dark"), Vector3(-0.05, -0.052, 0.115), Vector3(deg_to_rad(90), deg_to_rad(-25), 0), root)
	# sangles
	for y in [0.0, -0.045]:
		MeshKit.mesh_instance(_cached("strap", func() -> Mesh: return MeshKit.rbox(Vector3(0.2, 0.012, 0.2), 0.004, 1)), mat("rubber"), Vector3(0, y - 0.006, 0.0), Vector3.ZERO, root)
	return root


# ------------------------------------------------------------------ buste
## Gilet pare-coups avec plaques et poches (origine au centre du buste)
static func vest() -> Node3D:
	var root := Node3D.new()
	root.name = "Vest"
	var body := _cached("vest_body", func() -> Mesh:
		var parts := []
		parts.append([MeshKit.rbox(Vector3(0.33, 0.33, 0.05), 0.016, 3), _xf(Vector3(0, 0.0, 0.15))])        # plaque avant
		parts.append([MeshKit.rbox(Vector3(0.33, 0.34, 0.04), 0.016, 3), _xf(Vector3(0, 0.0, -0.09))])       # dos
		for sx in [-1.0, 1.0]:
			parts.append([MeshKit.rbox(Vector3(0.05, 0.3, 0.26), 0.014, 2), _xf(Vector3(sx * 0.17, -0.01, 0.03))])   # flancs
			parts.append([MeshKit.rbox(Vector3(0.075, 0.03, 0.27), 0.01, 2), _xf(Vector3(sx * 0.09, 0.185, 0.03), Vector3(0, 0, sx * -0.18))])   # bretelles
		return MeshKit.merge(parts))
	MeshKit.mesh_instance(body, mat("fabric"), Vector3.ZERO, Vector3.ZERO, root)
	var plates := _cached("vest_plates", func() -> Mesh:
		var parts := []
		parts.append([MeshKit.rbox(Vector3(0.27, 0.19, 0.016), 0.008, 2), _xf(Vector3(0, 0.05, 0.178))])
		parts.append([MeshKit.rbox(Vector3(0.27, 0.22, 0.014), 0.008, 2), _xf(Vector3(0, 0.03, -0.118))])
		for sx in [-1.0, 1.0]:
			for k in 2:
				parts.append([MeshKit.rbox(Vector3(0.1, 0.075, 0.034), 0.01, 2), _xf(Vector3(sx * 0.07, -0.105 - 0.0 * k, 0.17))])   # poches
		parts.append([MeshKit.rbox(Vector3(0.05, 0.05, 0.03), 0.008, 2), _xf(Vector3(0.0, 0.14, 0.175))])      # col
		return MeshKit.merge(parts))
	MeshKit.mesh_instance(plates, mat("plate"), Vector3.ZERO, Vector3.ZERO, root)
	# marquage dorsal et poitrine
	var back := Label3D.new()
	back.text = "POLICE"
	back.font_size = 64
	back.pixel_size = 0.0019
	back.modulate = Color(0.92, 0.93, 0.97)
	back.outline_size = 0
	back.shaded = false
	back.double_sided = false
	back.position = Vector3(0, 0.06, -0.128)
	back.rotation.y = PI
	root.add_child(back)
	var front := Label3D.new()
	front.text = "POLICE"
	front.font_size = 48
	front.pixel_size = 0.0011
	front.modulate = Color(0.92, 0.93, 0.97)
	front.shaded = false
	front.double_sided = false
	front.position = Vector3(0.075, 0.1, 0.1875)
	root.add_child(front)
	# radio d'épaule
	var radio := MeshKit.mesh_instance(_cached("radio", func() -> Mesh: return MeshKit.rbox(Vector3(0.035, 0.07, 0.025), 0.008, 2)), mat("black"), Vector3(0.115, 0.16, 0.175), Vector3.ZERO, root)
	radio.name = "Radio"
	MeshKit.mesh_instance(_cached("antenna", func() -> Mesh: return MeshKit.tube(PackedVector3Array([Vector3.ZERO, Vector3(0, 0.07, 0)]), 0.003, 5)), mat("rubber"), Vector3(0.115, 0.195, 0.175), Vector3.ZERO, root)
	return root


## Ceinture et holster (origine : os racine, bassin)
static func belt() -> Node3D:
	var root := Node3D.new()
	root.name = "Belt"
	var mesh := _cached("belt", func() -> Mesh:
		var parts := []
		var prof := PackedVector2Array([Vector2(0.17, -0.025), Vector2(0.176, -0.02), Vector2(0.176, 0.02), Vector2(0.17, 0.025)])
		parts.append([MeshKit.lathe(prof, 24, 30.0), _xf(Vector3(0, 0, 0.03), Vector3.ZERO, Vector3(1.0, 1.0, 0.84))])
		parts.append([MeshKit.rbox(Vector3(0.06, 0.12, 0.05), 0.012, 2), _xf(Vector3(-0.16, -0.075, 0.03))])        # holster
		parts.append([MeshKit.rbox(Vector3(0.05, 0.08, 0.04), 0.01, 2), _xf(Vector3(0.1, -0.01, 0.13))])           # pochette
		parts.append([MeshKit.rbox(Vector3(0.05, 0.08, 0.04), 0.01, 2), _xf(Vector3(-0.1, -0.01, 0.13))])
		parts.append([MeshKit.rbox(Vector3(0.1, 0.05, 0.04), 0.01, 2), _xf(Vector3(0.0, 0.0, -0.1))])
		parts.append([MeshKit.rbox(Vector3(0.04, 0.09, 0.04), 0.01, 2), _xf(Vector3(0.16, -0.05, 0.03))])         # étui matraque
		return MeshKit.merge(parts))
	MeshKit.mesh_instance(mesh, mat("black"), Vector3.ZERO, Vector3.ZERO, root)
	return root


## Épaulière (côté +1 gauche / -1 droite ; origine à l'épaule)
static func shoulder_pad(side: float) -> Node3D:
	var root := Node3D.new()
	var m := _cached("shoulder_pad", func() -> Mesh:
		var prof := PackedVector2Array([Vector2(0.078, 0.0), Vector2(0.082, 0.015), Vector2(0.072, 0.045), Vector2(0.045, 0.07), Vector2(0.0, 0.08)])
		var d := MeshKit.lathe(prof, 16, 40.0)
		return MeshKit.merge([[d, _xf(Vector3.ZERO, Vector3.ZERO, Vector3(1.05, 1.0, 1.0))],
			[MeshKit.rbox(Vector3(0.12, 0.016, 0.1), 0.006, 2), _xf(Vector3(0.0, -0.01, 0.0))]]))
	var mi := MeshKit.mesh_instance(m, mat("plate"), Vector3.ZERO, Vector3(0, 0, side * -0.55), root)
	mi.position = Vector3(side * 0.02, 0.0, 0.0)
	return root


## Protège-bras (tube sur l'avant-bras ; origine à l'articulation du coude, axe = vers le poignet)
static func forearm_guard() -> Node3D:
	var root := Node3D.new()
	var m := _cached("forearm", func() -> Mesh:
		var prof := PackedVector2Array([Vector2(0.046, 0.0), Vector2(0.051, 0.02), Vector2(0.05, 0.19), Vector2(0.042, 0.215)])
		return MeshKit.lathe(prof, 14, 40.0))
	MeshKit.mesh_instance(m, mat("plate"), Vector3.ZERO, Vector3.ZERO, root)
	return root


static func knee_pad() -> Node3D:
	var root := Node3D.new()
	var m := _cached("knee", func() -> Mesh:
		return MeshKit.merge([[MeshKit.rbox(Vector3(0.1, 0.12, 0.05), 0.02, 3), _xf(Vector3.ZERO)],
			[MeshKit.rbox(Vector3(0.1, 0.05, 0.03), 0.012, 2), _xf(Vector3(0, 0.07, -0.02))]]))
	MeshKit.mesh_instance(m, mat("plate"), Vector3.ZERO, Vector3.ZERO, root)
	return root


static func shin_guard() -> Node3D:
	var root := Node3D.new()
	var m := _cached("shin", func() -> Mesh:
		return MeshKit.merge([[MeshKit.curved_panel(0.115, 0.3, 0.026, 8, 3, 0.008), _xf(Vector3.ZERO)]]))
	MeshKit.mesh_instance(m, mat("plate"), Vector3.ZERO, Vector3.ZERO, root)
	return root


# ------------------------------------------------------------------ tenu en main
## Bouclier anti-émeute : origine = poignée (au dos), devant = +Z, haut = +Y
static func shield() -> Node3D:
	var root := Node3D.new()
	root.name = "Shield"
	var w := 0.56
	var h := 0.95
	var panel := _cached("shield_panel", func() -> Mesh:
		return MeshKit.curved_panel(w, h, 0.075, 14, 6, 0.012))
	var pan := MeshKit.mesh_instance(panel, mat("shield"), Vector3(0, 0.0, 0.05), Vector3.ZERO, root)
	pan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var frame := _cached("shield_frame", func() -> Mesh:
		var parts := []
		var segs := 14
		for sy in [-1.0, 1.0]:
			# bandes haut / bas suivent la courbure
			for i in segs:
				var u0 := float(i) / segs
				var u1 := float(i + 1) / segs
				var x0 := (u0 - 0.5) * w
				var x1 := (u1 - 0.5) * w
				var t0 := (u0 - 0.5) * 2.0
				var t1 := (u1 - 0.5) * 2.0
				var z0 := -0.075 * t0 * t0
				var z1 := -0.075 * t1 * t1
				var mid := Vector3((x0 + x1) * 0.5, sy * (h * 0.5 - 0.008), (z0 + z1) * 0.5)
				var ang := atan2(z1 - z0, x1 - x0)
				parts.append([MeshKit.rbox(Vector3(maxf((x1 - x0) * 1.06, 0.01), 0.026, 0.02), 0.006, 1), _xf(mid, Vector3(0, -ang, 0))])
		for sx in [-1.0, 1.0]:
			for i in 6:
				var v := (float(i) + 0.5) / 6.0
				var y := (v - 0.5) * (h - 0.05)
				parts.append([MeshKit.rbox(Vector3(0.026, (h - 0.05) / 6.0 * 1.08, 0.02), 0.006, 1), _xf(Vector3(sx * (w * 0.5 - 0.012), y, -0.075 + 0.0), Vector3(0, sx * 0.75, 0))])
		return MeshKit.merge(parts))
	MeshKit.mesh_instance(frame, mat("black"), Vector3(0, 0.0, 0.05), Vector3.ZERO, root)
	# poignée horizontale et sangle de bras (au dos)
	var grip := _cached("shield_grip", func() -> Mesh:
		return MeshKit.merge([[MeshKit.tube(PackedVector3Array([Vector3(-0.07, 0, 0), Vector3(0.07, 0, 0)]), 0.014, 8), _xf()],
			[MeshKit.rbox(Vector3(0.02, 0.05, 0.05), 0.006, 1), _xf(Vector3(-0.075, 0, 0.0))],
			[MeshKit.rbox(Vector3(0.02, 0.05, 0.05), 0.006, 1), _xf(Vector3(0.075, 0, 0.0))],
			[MeshKit.rbox(Vector3(0.06, 0.016, 0.05), 0.005, 1), _xf(Vector3(0.0, 0.2, 0.0))]]))
	MeshKit.mesh_instance(grip, mat("rubber"), Vector3(0, 0, 0.0), Vector3.ZERO, root)
	return root


## Matraque (origine à la poignée, axe +Y)
static func baton() -> Node3D:
	var root := Node3D.new()
	root.name = "Baton"
	var m := _cached("baton", func() -> Mesh:
		var shaft := MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.1), Vector2(0.019, -0.1), Vector2(0.02, -0.08), Vector2(0.017, 0.0), Vector2(0.015, 0.45), Vector2(0.0, 0.452)]), 12, 40.0)
		var side := MeshKit.tube(PackedVector3Array([Vector3(0, 0.0, 0), Vector3(0, 0.0, 0.1)]), 0.014, 8)
		return MeshKit.merge([[shaft, _xf()], [side, _xf(Vector3(0, 0.035, 0))]]))
	MeshKit.mesh_instance(m, mat("rubber"), Vector3.ZERO, Vector3.ZERO, root)
	return root


## Lanceur de balles de défense (LBD) : origine = poignée de tir, devant = +Z
static func lbd() -> Node3D:
	var root := Node3D.new()
	root.name = "LBD"
	var m := _cached("lbd", func() -> Mesh:
		var parts := []
		parts.append([MeshKit.rbox(Vector3(0.05, 0.085, 0.26), 0.012, 2), _xf(Vector3(0, 0.03, 0.04))])           # boîtier
		parts.append([MeshKit.tube(PackedVector3Array([Vector3(0, 0.045, 0.16), Vector3(0, 0.045, 0.46)]), 0.0235, 12), _xf()])   # canon
		parts.append([MeshKit.rbox(Vector3(0.045, 0.1, 0.2), 0.012, 2), _xf(Vector3(0, 0.03, -0.17), Vector3(deg_to_rad(-6), 0, 0))])      # crosse
		parts.append([MeshKit.rbox(Vector3(0.032, 0.09, 0.04), 0.01, 2), _xf(Vector3(0, -0.04, -0.02), Vector3(deg_to_rad(18), 0, 0))])  # poignée
		parts.append([MeshKit.rbox(Vector3(0.03, 0.03, 0.14), 0.008, 2), _xf(Vector3(0, 0.1, 0.06))])            # rail + viseur
		parts.append([MeshKit.rbox(Vector3(0.04, 0.05, 0.12), 0.01, 2), _xf(Vector3(0, -0.01, 0.2))])          # garde-main
		return MeshKit.merge(parts))
	MeshKit.mesh_instance(m, mat("black"), Vector3.ZERO, Vector3.ZERO, root)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.045, 0.47)
	root.add_child(muzzle)
	return root


## Lance-grenades lacrymogènes (type Cougar) : origine = poignée
static func launcher() -> Node3D:
	var root := Node3D.new()
	root.name = "Launcher"
	var m := _cached("launcher", func() -> Mesh:
		var parts := []
		parts.append([MeshKit.tube(PackedVector3Array([Vector3(0, 0.05, 0.1), Vector3(0, 0.05, 0.62)]), 0.034, 14), _xf()])
		parts.append([MeshKit.tube(PackedVector3Array([Vector3(0, 0.05, 0.6), Vector3(0, 0.05, 0.66)]), 0.04, 14), _xf()])
		parts.append([MeshKit.rbox(Vector3(0.07, 0.1, 0.22), 0.015, 2), _xf(Vector3(0, 0.03, 0.04))])
		parts.append([MeshKit.rbox(Vector3(0.04, 0.1, 0.24), 0.012, 2), _xf(Vector3(0, 0.03, -0.17), Vector3(deg_to_rad(-5), 0, 0))])
		parts.append([MeshKit.rbox(Vector3(0.034, 0.09, 0.04), 0.01, 2), _xf(Vector3(0, -0.05, -0.02), Vector3(deg_to_rad(18), 0, 0))])
		parts.append([MeshKit.rbox(Vector3(0.04, 0.045, 0.16), 0.01, 2), _xf(Vector3(0, -0.03, 0.26))])
		return MeshKit.merge(parts))
	MeshKit.mesh_instance(m, mat("black"), Vector3.ZERO, Vector3.ZERO, root)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.05, 0.67)
	root.add_child(muzzle)
	return root


## Bombe lacrymogène à main (origine à la base, axe +Y, buse vers +Z quand la main la tend)
static func spray() -> Node3D:
	var root := Node3D.new()
	root.name = "Spray"
	var m := _cached("spray", func() -> Mesh:
		return MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.024, 0.0), Vector2(0.026, 0.01), Vector2(0.026, 0.1), Vector2(0.02, 0.118), Vector2(0.01, 0.124), Vector2(0.0, 0.124)]), 14, 40.0))
	MeshKit.mesh_instance(m, mat("orange"), Vector3(0, -0.06, 0), Vector3.ZERO, root)
	MeshKit.mesh_instance(_cached("spray_nozzle", func() -> Mesh: return MeshKit.rbox(Vector3(0.02, 0.016, 0.03), 0.004, 1)), mat("black"), Vector3(0, 0.066, 0.01), Vector3.ZERO, root)
	return root


## Menottes (origine au milieu de la chaîne)
static func cuffs() -> Node3D:
	var root := Node3D.new()
	root.name = "Cuffs"
	var m := _cached("cuffs", func() -> Mesh:
		var parts := []
		for sx in [-1.0, 1.0]:
			var pts := PackedVector3Array()
			for k in 13:
				var a := float(k) / 12.0 * TAU
				pts.append(Vector3(sx * 0.045 + cos(a) * 0.028, 0.0, sin(a) * 0.028))
			parts.append([MeshKit.tube(pts, 0.006, 6, false), _xf()])
		parts.append([MeshKit.tube(PackedVector3Array([Vector3(-0.02, 0, 0), Vector3(0.02, 0, 0)]), 0.004, 5), _xf()])
		return MeshKit.merge(parts))
	MeshKit.mesh_instance(m, mat("metal"), Vector3.ZERO, Vector3.ZERO, root)
	return root


## Grenade lacrymogène (origine au centre, axe +Y)
static func grenade() -> Node3D:
	var root := Node3D.new()
	var m := _cached("grenade", func() -> Mesh:
		return MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.065), Vector2(0.027, -0.06), Vector2(0.033, -0.03), Vector2(0.033, 0.04), Vector2(0.03, 0.06), Vector2(0.015, 0.07), Vector2(0.0, 0.072)]), 14, 40.0))
	MeshKit.mesh_instance(m, mat("steel_dark"), Vector3.ZERO, Vector3.ZERO, root)
	MeshKit.mesh_instance(_cached("grenade_band", func() -> Mesh: return MeshKit.lathe(PackedVector2Array([Vector2(0.034, -0.012), Vector2(0.034, 0.012)]), 14, 40.0)), mat("red"), Vector3.ZERO, Vector3.ZERO, root)
	return root


## Tenue de base (bleu marine) : le reste est ajouté par equip()
static func outfit(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"top": "jacket", "top_color": Color(0.035, 0.05, 0.095), "hood": false, "vest": false,
		"pants_tex": false, "pants_color": Color(0.035, 0.045, 0.08), "shoe_color": Color(0.02, 0.02, 0.025),
		"head": "", "face": "", "backpack": false, "no_hair": true,
		"hair_color": [Color(0.05, 0.035, 0.025), Color(0.12, 0.08, 0.05), Color(0.3, 0.2, 0.1)][rng.randi() % 3],
	}


# ------------------------------------------------------------------ assemblage
## Habille un humain : pièces fixes collées aux os. Renvoie un dictionnaire des nœuds utiles
## (helmet, visor, mask, vest, radio).
static func equip(h: Human, with_mask := false) -> Dictionary:
	var out := {}
	var s := h.hscale()
	var helm := helmet()
	helm.scale = Vector3.ONE * s
	h.attach("head", helm, Vector3(0, 0.073, 0.027) * s)
	out["helmet"] = helm
	out["visor"] = helm.get_node("Visor")
	var mask := gas_mask()
	mask.scale = Vector3.ONE * s
	h.attach("head", mask, Vector3(0, 0.073, 0.027) * s)
	mask.visible = with_mask
	out["mask"] = mask
	var v := vest()
	v.scale = Vector3.ONE * s
	h.attach("spine02", v, Vector3(0, 0.135, 0.03) * s)
	out["vest"] = v
	var b := belt()
	b.scale = Vector3.ONE * s
	h.attach("root", b, Vector3(0, 0.03, 0.0) * s)
	for sd in [1.0, -1.0]:
		var side := "L" if sd > 0.0 else "R"
		var sp := shoulder_pad(sd)
		sp.scale = Vector3.ONE * s
		h.attach("upperarm01_" + side, sp, Vector3(sd * 0.0, 0.07, 0.0) * s)
		var fg := forearm_guard()
		fg.scale = Vector3.ONE * s
		h.attach_limb("lowerarm01_" + side, "wrist_" + side, fg, 0.18)
		var kn := knee_pad()
		kn.scale = Vector3.ONE * s
		h.attach("lowerleg01_" + side, kn, Vector3(0, 0.0, 0.06) * s)
		var sg := shin_guard()
		sg.scale = Vector3.ONE * s
		h.attach("lowerleg01_" + side, sg, Vector3(sd * 0.012, -0.2, 0.068) * s, Basis(Vector3.RIGHT, deg_to_rad(-3)))
	return out
