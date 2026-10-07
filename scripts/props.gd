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


## Mégaphone : origine = poignée, pavillon vers +Z
static func megaphone() -> Node3D:
	var root := Node3D.new()
	root.name = "Megaphone"
	var white := _m("mega_white", func() -> Material: return _col(Color(0.88, 0.88, 0.86), 0.45))
	var red := _m("mega_red", func() -> Material: return _col(Color(0.75, 0.08, 0.06), 0.5))
	var grey := _m("mega_grey", func() -> Material: return _col(Color(0.15, 0.15, 0.16), 0.6))
	var horn := CylinderMesh.new()
	horn.top_radius = 0.035
	horn.bottom_radius = 0.12
	horn.height = 0.28
	horn.radial_segments = 24
	_mi(root, horn, white, Vector3(0, 0.07, 0.17), Vector3(PI / 2, 0, 0))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.11
	rim.outer_radius = 0.13
	_mi(root, rim, red, Vector3(0, 0.07, 0.31), Vector3(PI / 2, 0, 0))
	var body := CylinderMesh.new()
	body.top_radius = 0.042
	body.bottom_radius = 0.042
	body.height = 0.14
	_mi(root, body, red, Vector3(0, 0.07, -0.03), Vector3(PI / 2, 0, 0))
	var mouth := CylinderMesh.new()
	mouth.top_radius = 0.03
	mouth.bottom_radius = 0.035
	mouth.height = 0.03
	_mi(root, mouth, grey, Vector3(0, 0.07, -0.11), Vector3(PI / 2, 0, 0))
	var grip := BoxMesh.new()
	grip.size = Vector3(0.03, 0.1, 0.04)
	_mi(root, grip, grey, Vector3(0, 0.0, 0.0), Vector3(-0.25, 0, 0))
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
