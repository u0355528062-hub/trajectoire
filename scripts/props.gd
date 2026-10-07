class_name Props
extends RefCounted
## Accessoires de manifestation : pancartes, téléphone, mégaphone, briquet, journal,
## cigarette, cartons et planches. Origine = point de prise en main.

const DIR := "res://assets/props/"
static var _mats := {}
static var _meshes := {}


static func _m(key: String, maker: Callable) -> Material:
	if not _mats.has(key):
		_mats[key] = maker.call()
	return _mats[key]


static func _tex_mat(file: String, rough := 0.9, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(DIR + file)
	m.roughness = rough
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _col(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Repère d'un objet tenu : axe +Y = `up`, face +Z tournée au mieux vers `fwd` (jamais dégénéré)
static func basis_up(up: Vector3, fwd: Vector3) -> Basis:
	var y := up.normalized()
	var ref := fwd
	if absf(y.dot(ref.normalized())) > 0.95:
		ref = Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT
	var z := (ref - y * ref.dot(y)).normalized()
	return Basis(y.cross(z), y, z).orthonormalized()


static func wood() -> Material:
	return _m("wood", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(DIR + "crate.png")
		m.albedo_color = Color(0.95, 0.85, 0.75)
		m.roughness = 0.85
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(2, 2, 2)
		return m)


## Pancarte : manche vertical (axe +Y), carton face +Z. idx 1..4
static func sign_board(idx: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Sign"
	var stick := CylinderMesh.new()
	stick.top_radius = 0.012
	stick.bottom_radius = 0.014
	stick.height = 1.22
	stick.radial_segments = 8
	_mi(root, stick, wood(), Vector3(0, 0.17, -0.012))
	var board := Node3D.new()
	board.position = Vector3(0, 0.98, 0)
	board.rotation.z = randf_range(-0.04, 0.04)
	root.add_child(board)
	var w := 0.62
	var h := 0.465
	var front := QuadMesh.new()
	front.size = Vector2(w, h)
	_mi(board, front, _m("sign%d" % idx, func() -> Material: return _tex_mat("sign_%d.png" % idx, 0.92)), Vector3(0, 0, 0.004))
	_mi(board, front, _m("sign_back", func() -> Material: return _tex_mat("sign_back.png", 0.95)), Vector3(0, 0, -0.004), Vector3(0, PI, 0))
	var edge := BoxMesh.new()
	edge.size = Vector3(w, h, 0.007)
	var em := _m("cardboard_edge", func() -> Material: return _col(Color(0.5, 0.38, 0.25), 0.95))
	var e := _mi(board, edge, em)
	e.scale = Vector3(1.0, 1.0, 1.0)
	# agrafes
	var st := BoxMesh.new()
	st.size = Vector3(0.012, 0.004, 0.003)
	var sm := _m("staple", func() -> Material: return _col(Color(0.8, 0.8, 0.82), 0.3, 1.0))
	for y in [-0.18, 0.0, 0.16]:
		_mi(board, st, sm, Vector3(0, y, -0.0065))
	return root


## Téléphone : axe long +Y, écran face +Z. `screen` = "feed" ou "cam"
static func phone(screen := "feed") -> Node3D:
	var root := Node3D.new()
	root.name = "Phone"
	var b := BoxMesh.new()
	b.size = Vector3(0.071, 0.148, 0.0085)
	_mi(root, b, _m("phone_body", func() -> Material: return _col(Color(0.05, 0.05, 0.06), 0.35, 0.6)))
	var q := QuadMesh.new()
	q.size = Vector2(0.065, 0.14)
	var mat := _m("screen_" + screen, func() -> Material:
		var m := _tex_mat("phone_" + screen + ".png", 0.2, true)
		m.albedo_color = Color(1.25, 1.25, 1.3)
		return m)
	var s := _mi(root, q, mat, Vector3(0, 0, 0.0045))
	s.name = "Screen"
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cam := CylinderMesh.new()
	cam.top_radius = 0.006
	cam.bottom_radius = 0.006
	cam.height = 0.002
	_mi(root, cam, _m("lens", func() -> Material: return _col(Color(0.02, 0.02, 0.03), 0.1, 0.8)), Vector3(-0.022, 0.055, -0.0048), Vector3(PI / 2, 0, 0))
	return root


static func set_phone_screen(p: Node3D, screen: String) -> void:
	var s := p.get_node_or_null("Screen") as MeshInstance3D
	if s:
		s.material_override = _m("screen_" + screen, func() -> Material:
			var m := _tex_mat("phone_" + screen + ".png", 0.2, true)
			m.albedo_color = Color(1.25, 1.25, 1.3)
			return m)


## Mégaphone à main : origine = point de contact de la bouche (embout), pavillon vers +Z, poignée dessous.
## meta "grip" = position de la paume sur la poignée.
static func megaphone() -> Node3D:
	var root := Node3D.new()
	root.name = "Megaphone"
	var white := _m("mega_white", func() -> Material:
		var m := _col(Color(0.9, 0.9, 0.87), 0.3)
		m.metallic_specular = 0.6
		return m)
	var inner := _m("mega_inner", func() -> Material: return _col(Color(0.05, 0.05, 0.055), 0.9))
	var grey := _m("mega_grey", func() -> Material: return _col(Color(0.2, 0.21, 0.23), 0.45))
	var rubber := _m("mega_rubber", func() -> Material: return _col(Color(0.03, 0.03, 0.035), 0.9))
	var red := _m("mega_red", func() -> Material: return _col(Color(0.78, 0.07, 0.05), 0.4))
	var tilt := Vector3(PI / 2.0, 0, 0)    # l'axe du solide de révolution (Y) devient l'axe du pavillon (+Z)
	# embout caoutchouc
	var cup := PackedVector2Array([Vector2(0.036, 0.0), Vector2(0.052, 0.0), Vector2(0.058, 0.01), Vector2(0.056, 0.03), Vector2(0.05, 0.036)])
	_mi(root, MeshKit.lathe(cup, 24), rubber, Vector3.ZERO, tilt)
	# corps (batterie, haut-parleur)
	var body := PackedVector2Array([Vector2(0.05, 0.036), Vector2(0.062, 0.042), Vector2(0.066, 0.06), Vector2(0.066, 0.12), Vector2(0.064, 0.13), Vector2(0.06, 0.134)])
	_mi(root, MeshKit.lathe(body, 28), grey, Vector3.ZERO, tilt)
	# pavillon : profil exponentiel, face externe blanche, face interne sombre
	var outer := PackedVector2Array()
	var innerp := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var t := float(i) / steps
		var r := 0.06 + 0.078 * pow(t, 1.7)
		var y := 0.134 + 0.236 * t
		outer.append(Vector2(r, y))
		innerp.append(Vector2(r - 0.004, y))
	outer.append(Vector2(0.141, 0.373))
	outer.append(Vector2(0.137, 0.376))
	_mi(root, MeshKit.lathe(outer, 36), white, Vector3.ZERO, tilt)
	var inn := PackedVector2Array()
	for i in range(innerp.size() - 1, -1, -1):
		inn.append(innerp[i])
	inn.append(Vector2(0.056, 0.134))
	_mi(root, MeshKit.lathe(inn, 36), inner, Vector3.ZERO, tilt)
	# bandes rouges du pavillon
	for yb: float in [0.31, 0.347]:
		var t := (yb - 0.134) / 0.236
		var r := 0.06 + 0.078 * pow(t, 1.7)
		var band := PackedVector2Array([Vector2(r + 0.0005, yb - 0.011), Vector2(r + 0.0012, yb - 0.01), Vector2(r + 0.0012, yb + 0.01), Vector2(r + 0.0005, yb + 0.011)])
		_mi(root, MeshKit.lathe(band, 36), red, Vector3.ZERO, tilt)
	# poignée pistolet + gâchette + bouton de volume
	var grip := _mi(root, MeshKit.rbox(Vector3(0.036, 0.115, 0.05), 0.012, 2), grey, Vector3(0, -0.098, 0.088), Vector3(-0.2, 0, 0))
	grip.name = "Grip"
	_mi(root, MeshKit.rbox(Vector3(0.014, 0.034, 0.014), 0.004, 1), red, Vector3(0, -0.062, 0.122), Vector3(-0.2, 0, 0))
	var knob := CylinderMesh.new()
	knob.top_radius = 0.011
	knob.bottom_radius = 0.012
	knob.height = 0.012
	_mi(root, knob, rubber, Vector3(0, 0.069, 0.075))
	root.set_meta("grip", Vector3(0, -0.092, 0.092))
	return root


## Sac à dos : le côté plat (contre le dos) regarde +Z, l'extérieur -Z ; origine au centre du sac.
static func backpack(col := Color(0.1, 0.12, 0.2)) -> Node3D:
	var root := Node3D.new()
	root.name = "Backpack"
	var nyl := _m("pack" + str(col), func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.7
		m.metallic_specular = 0.35
		m.normal_enabled = true
		m.normal_texture = load("res://assets/character/nylon_n.png")
		m.normal_scale = 0.3
		m.uv1_scale = Vector3(3, 3, 1)
		return m)
	var dark := _m("pack_dark", func() -> Material: return _col(Color(0.02, 0.02, 0.025), 0.6))
	var metal := _m("pack_zip", func() -> Material: return _col(Color(0.65, 0.66, 0.7), 0.3, 1.0))
	_mi(root, MeshKit.rbox(Vector3(0.3, 0.44, 0.15), 0.06, 3), nyl)
	# poche frontale (extérieur)
	_mi(root, MeshKit.rbox(Vector3(0.25, 0.22, 0.07), 0.03, 2), nyl, Vector3(0, -0.07, -0.1))
	# rabat supérieur
	var lid := _mi(root, MeshKit.rbox(Vector3(0.28, 0.13, 0.05), 0.022, 2), nyl, Vector3(0, 0.185, -0.072), Vector3(-0.25, 0, 0))
	lid.name = "Lid"
	# poches latérales
	for sx: float in [-1.0, 1.0]:
		_mi(root, MeshKit.rbox(Vector3(0.05, 0.2, 0.1), 0.02, 2), nyl, Vector3(sx * 0.165, -0.1, -0.01))
	# fermetures éclair et poignée
	for sx: float in [-1.0, 1.0]:
		_mi(root, MeshKit.rbox(Vector3(0.006, 0.17, 0.004), 0.002, 1), dark, Vector3(sx * 0.08, -0.07, -0.137))
	_mi(root, MeshKit.rbox(Vector3(0.1, 0.012, 0.012), 0.005, 1), dark, Vector3(0, 0.255, 0.0))
	_mi(root, MeshKit.rbox(Vector3(0.018, 0.012, 0.01), 0.004, 1), metal, Vector3(0.0, 0.045, -0.139))
	# bretelles : deux bandes qui montent vers les épaules (côté dos)
	for sx: float in [-1.0, 1.0]:
		_mi(root, MeshKit.rbox(Vector3(0.05, 0.4, 0.012), 0.005, 1), dark, Vector3(sx * 0.09, 0.02, 0.078))
	return root


## Canette 33 cl (origine au centre, axe Y). `tint` = couleur de la bande.
static func can(tint := Color(0.75, 0.1, 0.1)) -> Node3D:
	var root := Node3D.new()
	root.name = "Can"
	var body := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.024, 0.0), Vector2(0.028, 0.006), Vector2(0.033, 0.014), Vector2(0.033, 0.1), Vector2(0.028, 0.109), Vector2(0.024, 0.113), Vector2(0.0, 0.113)])
	var paint := _m("can" + str(tint), func() -> Material:
		var m := _col(tint, 0.3, 0.55)
		return m)
	_mi(root, MeshKit.lathe(body, 20), paint, Vector3(0, -0.0565, 0))
	var silver := _m("can_ends", func() -> Material: return _col(Color(0.8, 0.82, 0.85), 0.22, 1.0))
	var top := PackedVector2Array([Vector2(0.0, 0.1128), Vector2(0.022, 0.1128), Vector2(0.024, 0.1142)])
	_mi(root, MeshKit.lathe(top, 16), silver, Vector3(0, -0.0565, 0))
	_mi(root, MeshKit.rbox(Vector3(0.016, 0.003, 0.009), 0.0012, 1), silver, Vector3(0, 0.0585, 0))
	return root


## Bouteille d'eau (origine au centre du corps)
static func bottle() -> Node3D:
	var root := Node3D.new()
	root.name = "Bottle"
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.026, 0.0), Vector2(0.033, 0.01), Vector2(0.034, 0.12), Vector2(0.031, 0.148), Vector2(0.016, 0.172), Vector2(0.014, 0.19), Vector2(0.0, 0.19)])
	var plastic := _m("bottle", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.72, 0.88, 0.98, 0.35)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.08
		m.metallic_specular = 0.8
		return m)
	_mi(root, MeshKit.lathe(prof, 20), plastic, Vector3(0, -0.095, 0))
	var cap := CylinderMesh.new()
	cap.top_radius = 0.0155
	cap.bottom_radius = 0.0155
	cap.height = 0.02
	_mi(root, cap, _m("bottle_cap", func() -> Material: return _col(Color(0.1, 0.35, 0.8), 0.4)), Vector3(0, 0.105, 0))
	var water := PackedVector2Array([Vector2(0.0, 0.002), Vector2(0.025, 0.002), Vector2(0.032, 0.012), Vector2(0.033, 0.075), Vector2(0.0, 0.075)])
	_mi(root, MeshKit.lathe(water, 18), _m("bottle_water", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.7, 0.9, 1.0, 0.25)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		return m), Vector3(0, -0.093, 0))
	return root


## Crayon à papier (origine au milieu, axe Y)
static func pencil() -> Node3D:
	var root := Node3D.new()
	root.name = "Pencil"
	_mi(root, MeshKit.lathe(PackedVector2Array([Vector2(0.0036, -0.075), Vector2(0.0036, 0.062), Vector2(0.0018, 0.074), Vector2(0.0006, 0.089)]), 6), _m("pencil", func() -> Material: return _col(Color(0.95, 0.75, 0.1), 0.5)))
	_mi(root, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0825), Vector2(0.0012, 0.0825), Vector2(0.0, 0.0896)]), 6), _m("pencil_lead", func() -> Material: return _col(Color(0.1, 0.1, 0.1), 0.5)))
	var fer := CylinderMesh.new()
	fer.top_radius = 0.0038
	fer.bottom_radius = 0.0038
	fer.height = 0.012
	fer.radial_segments = 8
	_mi(root, fer, _m("pencil_met", func() -> Material: return _col(Color(0.75, 0.75, 0.78), 0.3, 1.0)), Vector3(0, -0.081, 0))
	var er := CylinderMesh.new()
	er.top_radius = 0.0034
	er.bottom_radius = 0.0034
	er.height = 0.008
	er.radial_segments = 8
	_mi(root, er, _m("pencil_er", func() -> Material: return _col(Color(0.9, 0.5, 0.55), 0.8)), Vector3(0, -0.091, 0))
	return root


## Briquet : flamme (enfant "Flame") + lumière ("Light")
static func lighter(col := Color(0.8, 0.15, 0.1)) -> Node3D:
	var root := Node3D.new()
	root.name = "Lighter"
	var b := BoxMesh.new()
	b.size = Vector3(0.022, 0.06, 0.012)
	_mi(root, b, _m("lighter" + str(col), func() -> Material: return _col(col, 0.35)))
	var top := BoxMesh.new()
	top.size = Vector3(0.023, 0.012, 0.013)
	_mi(root, top, _m("lighter_top", func() -> Material: return _col(Color(0.75, 0.76, 0.8), 0.25, 1.0)), Vector3(0, 0.035, 0))
	var f := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.007
	sm.height = 0.032
	f.mesh = sm
	f.material_override = _m("lighter_flame", func() -> Material:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.62, 0.2) * 2.6
		return m)
	f.position.y = 0.058
	f.name = "Flame"
	f.visible = false
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(f)
	var l := OmniLight3D.new()
	l.name = "Light"
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 0.0
	l.omni_range = 3.0
	l.position.y = 0.06
	root.add_child(l)
	return root


static func set_lighter_lit(l: Node3D, on: bool, t := 0.0) -> void:
	var f := l.get_node_or_null("Flame") as MeshInstance3D
	var li := l.get_node_or_null("Light") as OmniLight3D
	if f:
		f.visible = on
		if on:
			f.scale = Vector3(1, 0.8 + 0.4 * absf(sin(t * 31.0)), 1)
	if li:
		li.light_energy = (0.7 + 0.4 * Fx.flicker(t, 1.0) - 0.4) if on else 0.0


## Cigarette : origine au filtre, axe +Y ; braise "Ember"
static func cigarette() -> Node3D:
	var root := Node3D.new()
	root.name = "Cigarette"
	var c := CylinderMesh.new()
	c.top_radius = 0.0038
	c.bottom_radius = 0.0038
	c.height = 0.062
	c.radial_segments = 8
	_mi(root, c, _m("cig_paper", func() -> Material: return _col(Color(0.95, 0.94, 0.9), 0.8)), Vector3(0, 0.043, 0))
	var f := CylinderMesh.new()
	f.top_radius = 0.004
	f.bottom_radius = 0.004
	f.height = 0.02
	f.radial_segments = 8
	_mi(root, f, _m("cig_filter", func() -> Material: return _col(Color(0.85, 0.55, 0.25), 0.8)), Vector3(0, 0.002, 0))
	var e := SphereMesh.new()
	e.radius = 0.0042
	e.height = 0.006
	var em := _mi(root, e, _m("cig_ember", func() -> Material:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.35, 0.08) * 2.0
		return m), Vector3(0, 0.075, 0))
	em.name = "Ember"
	return root


## Journal roulé (torche) : axe +Y, origine au milieu
static func newspaper_roll() -> Node3D:
	var root := Node3D.new()
	root.name = "Paper"
	var c := CylinderMesh.new()
	c.top_radius = 0.034
	c.bottom_radius = 0.022
	c.height = 0.3
	c.radial_segments = 12
	_mi(root, c, _m("paper", func() -> Material:
		var m := _tex_mat("newspaper.png", 0.95)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m), Vector3(0, 0.03, 0))
	# extrémité froissée
	var top := SphereMesh.new()
	top.radius = 0.045
	top.height = 0.07
	top.radial_segments = 8
	top.rings = 4
	var t := _mi(root, top, _m("paper", func() -> Material: return _tex_mat("newspaper.png", 0.95)), Vector3(0, 0.19, 0))
	t.scale = Vector3(1.0, 0.8, 0.85)
	t.name = "Tip"
	return root


## Boule de papier froissé (maillage bosselé)
static func paper_ball_mesh() -> Mesh:
	if not _meshes.has("ball"):
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.14
		sm.radial_segments = 10
		sm.rings = 6
		var arr := sm.get_mesh_arrays()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i in v.size():
			var k := 0.75 + 0.35 * absf(sin(v[i].x * 61.0 + v[i].y * 37.0) * cos(v[i].z * 53.0 + v[i].x * 13.0))
			v[i] *= k
		arr[Mesh.ARRAY_VERTEX] = v
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		_meshes["ball"] = am
	return _meshes["ball"]


static func paper_material() -> Material:
	return _m("paper", func() -> Material: return _tex_mat("newspaper.png", 0.95))


static func box_material() -> Material:
	return _m("box", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(DIR + "box.png")
		m.roughness = 0.95
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(2.4, 2.4, 2.4)
		return m)


static func flare_label_material() -> Material:
	return _m("flare_label", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(DIR + "flare_label.png")
		m.roughness = 0.6
		return m)
