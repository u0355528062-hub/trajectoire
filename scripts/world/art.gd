class_name Art
extends RefCounted
## Bibliothèque graphique : matériaux PBR et maillages procéduraux
## (boîtes arrondies, etc.), mis en cache pour être partagés.

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}
static var _noise: NoiseTexture2D
static var _noise_normal: NoiseTexture2D
static var _fabric_normal: NoiseTexture2D


static func noise() -> NoiseTexture2D:
	if _noise == null:
		_noise = NoiseTexture2D.new()
		_noise.width = 512
		_noise.height = 512
		_noise.seamless = true
		_noise.generate_mipmaps = true
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 0.01
		fn.fractal_octaves = 5
		_noise.noise = fn
	return _noise


static func noise_normal() -> NoiseTexture2D:
	if _noise_normal == null:
		_noise_normal = NoiseTexture2D.new()
		_noise_normal.width = 512
		_noise_normal.height = 512
		_noise_normal.seamless = true
		_noise_normal.as_normal_map = true
		_noise_normal.bump_strength = 1.5
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 0.03
		fn.fractal_octaves = 4
		_noise_normal.noise = fn
	return _noise_normal


static func fabric_normal() -> NoiseTexture2D:
	if _fabric_normal == null:
		_fabric_normal = NoiseTexture2D.new()
		_fabric_normal.width = 256
		_fabric_normal.height = 256
		_fabric_normal.seamless = true
		_fabric_normal.as_normal_map = true
		_fabric_normal.bump_strength = 3.0
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_CELLULAR
		fn.frequency = 0.12
		_fabric_normal.noise = fn
	return _fabric_normal


# --- Matériaux ------------------------------------------------------------------

static func mat(name: String) -> Material:
	if _mats.has(name):
		return _mats[name]
	var m: Material = _make(name)
	_mats[name] = m
	return m


static func color_mat(c: Color, roughness: float = 0.6, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "c_%s_%.2f_%.2f" % [c.to_html(), roughness, metallic]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	m.metallic = metallic
	_mats[key] = m
	return m


static func fabric_mat(c: Color) -> StandardMaterial3D:
	var key := "fab_%s" % c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.92
	m.normal_enabled = true
	m.normal_texture = fabric_normal()
	m.normal_scale = 0.35
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(12, 12, 12)
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	_mats[key] = m
	return m


static func skin_mat(tone: int) -> StandardMaterial3D:
	var tones := [
		Color(0.93, 0.76, 0.66), Color(0.86, 0.66, 0.53), Color(0.72, 0.52, 0.38),
		Color(0.5, 0.33, 0.22), Color(0.34, 0.22, 0.15),
	]
	tone = clampi(tone, 0, tones.size() - 1)
	var key := "skin_%d" % tone
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tones[tone]
	m.roughness = 0.55
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.35
	m.subsurf_scatter_skin_mode = true
	m.rim_enabled = true
	m.rim = 0.15
	m.rim_tint = 0.4
	_mats[key] = m
	return m


static func hair_mat(c: Color) -> StandardMaterial3D:
	var key := "hair_%s" % c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	m.normal_enabled = true
	m.normal_texture = noise_normal()
	m.normal_scale = 0.6
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(30, 4, 30)
	m.anisotropy_enabled = true
	m.anisotropy = 0.6
	_mats[key] = m
	return m


static func _make(name: String) -> Material:
	match name:
		"floor_wood":
			var s := ShaderMaterial.new()
			s.shader = load("res://shaders/wood_floor.gdshader")
			s.set_shader_parameter("noise_tex", noise())
			return s
		"floor_tiles":
			var s := ShaderMaterial.new()
			s.shader = load("res://shaders/stone_tiles.gdshader")
			s.set_shader_parameter("noise_tex", noise())
			return s
		"floor_outside":
			var s := ShaderMaterial.new()
			s.shader = load("res://shaders/stone_tiles.gdshader")
			s.set_shader_parameter("noise_tex", noise())
			s.set_shader_parameter("tile_color", Color(0.52, 0.5, 0.47))
			s.set_shader_parameter("tile_color_2", Color(0.44, 0.42, 0.4))
			s.set_shader_parameter("grout_color", Color(0.3, 0.3, 0.3))
			s.set_shader_parameter("tile_size", 0.4)
			s.set_shader_parameter("polish", 0.15)
			return s
		"wood":
			var s := ShaderMaterial.new()
			s.shader = load("res://shaders/wood.gdshader")
			s.set_shader_parameter("noise_tex", noise())
			return s
		"wood_light":
			var s := ShaderMaterial.new()
			s.shader = load("res://shaders/wood.gdshader")
			s.set_shader_parameter("noise_tex", noise())
			s.set_shader_parameter("color_a", Color(0.82, 0.68, 0.5))
			s.set_shader_parameter("color_b", Color(0.7, 0.55, 0.38))
			return s
		"wall":
			return _plaster(Color(0.93, 0.92, 0.89))
		"wall_accent":
			return _plaster(Color(0.47, 0.6, 0.56))
		"wall_accent_blue":
			return _plaster(Color(0.3, 0.42, 0.55))
		"wall_outside":
			return _plaster(Color(0.86, 0.8, 0.7))
		"ceiling":
			return _plaster(Color(0.96, 0.96, 0.95))
		"baseboard":
			return color_mat(Color(0.95, 0.95, 0.94), 0.4)
		"white_plastic":
			return color_mat(Color(0.92, 0.92, 0.93), 0.35)
		"black_plastic":
			return color_mat(Color(0.05, 0.05, 0.06), 0.4)
		"dark_metal":
			return color_mat(Color(0.12, 0.12, 0.13), 0.35, 0.9)
		"chrome":
			return color_mat(Color(0.9, 0.9, 0.92), 0.08, 1.0)
		"brushed_metal":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.75, 0.76, 0.78)
			m.metallic = 1.0
			m.roughness = 0.3
			m.anisotropy_enabled = true
			m.anisotropy = 0.8
			return m
		"vinyl_teal":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.13, 0.42, 0.45)
			m.roughness = 0.42
			m.clearcoat_enabled = true
			m.clearcoat = 0.4
			m.normal_enabled = true
			m.normal_texture = fabric_normal()
			m.normal_scale = 0.12
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(20, 20, 20)
			return m
		"paper":
			return color_mat(Color(0.97, 0.97, 0.95), 0.9)
		"glass":
			var m := StandardMaterial3D.new()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.75, 0.85, 0.9, 0.12)
			m.roughness = 0.12
			m.metallic = 0.0
			m.metallic_specular = 0.35
			m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			return m
		"light_panel":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(1, 1, 1)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.97, 0.92)
			m.emission_energy_multiplier = 4.0
			return m
		"leaf":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.2, 0.42, 0.18)
			m.roughness = 0.55
			m.backlight_enabled = true
			m.backlight = Color(0.35, 0.5, 0.15)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			return m
		"ceramic":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.9, 0.88, 0.84)
			m.roughness = 0.25
			m.clearcoat_enabled = true
			m.clearcoat = 0.8
			return m
		"terracotta":
			return color_mat(Color(0.62, 0.36, 0.25), 0.8)
		"soil":
			return color_mat(Color(0.18, 0.12, 0.08), 1.0)
		"grass":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.26, 0.38, 0.16)
			m.roughness = 1.0
			m.normal_enabled = true
			m.normal_texture = noise_normal()
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.5, 0.5, 0.5)
			return m
		"asphalt":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.17, 0.17, 0.18)
			m.roughness = 0.9
			m.normal_enabled = true
			m.normal_texture = fabric_normal()
			m.normal_scale = 0.5
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(3, 3, 3)
			return m
		"bark":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.3, 0.22, 0.16)
			m.roughness = 0.95
			m.normal_enabled = true
			m.normal_texture = noise_normal()
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(4, 0.6, 4)
			return m
		"foliage":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.2, 0.34, 0.14)
			m.roughness = 0.9
			return m
		"eye_white":
			return color_mat(Color(0.95, 0.94, 0.92), 0.15)
		"eye_iris":
			return color_mat(Color(0.12, 0.08, 0.05), 0.1)
		"lips":
			return color_mat(Color(0.62, 0.35, 0.33), 0.5)
		"shoe":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.08, 0.07, 0.07)
			m.roughness = 0.35
			m.clearcoat_enabled = true
			m.clearcoat = 0.5
			return m
		"secretary_top":
			return fabric_mat(Color(0.86, 0.84, 0.8))
	push_warning("Matériau inconnu : %s" % name)
	return color_mat(Color.MAGENTA)


static func _plaster(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.88
	m.normal_enabled = true
	m.normal_texture = noise_normal()
	m.normal_scale = 0.12
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.6, 0.6, 0.6)
	return m


# --- Maillages ----------------------------------------------------------------------

## Boîte aux arêtes arrondies (normales lisses, UV en mètres).
static func rounded_box(size: Vector3, radius: float, segments: int = 3) -> ArrayMesh:
	var h := size * 0.5
	var r := minf(radius, minf(h.x, minf(h.y, h.z)) * 0.98)
	r = maxf(r, 0.0005)
	var key := "rb_%.4f_%.4f_%.4f_%.4f_%d" % [size.x, size.y, size.z, r, segments]
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
		[Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
	]
	var inner := h - Vector3(r, r, r)
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var hn := absf(n.dot(h))
		var hu := absf(u.dot(h))
		var hv := absf(v.dot(h))
		var us := _samples(hu, r, segments)
		var vs := _samples(hv, r, segments)
		var verts: Array[Vector3] = []
		var norms: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for b in vs:
			for a in us:
				var p: Vector3 = n * hn + u * a + v * b
				var c := Vector3(clampf(p.x, -inner.x, inner.x), clampf(p.y, -inner.y, inner.y), clampf(p.z, -inner.z, inner.z))
				var d := p - c
				var nn := n if d.length() < 0.000001 else d.normalized()
				verts.append(c + nn * r)
				norms.append(nn)
				uvs.append(Vector2(a + hu, hv - b))
		var w := us.size()
		for j in range(vs.size() - 1):
			for i in range(w - 1):
				var i0 := j * w + i
				var i1 := i0 + 1
				var i2 := i0 + w
				var i3 := i2 + 1
				_tri(st, verts, norms, uvs, i0, i1, i3, n)
				_tri(st, verts, norms, uvs, i0, i3, i2, n)
	st.generate_tangents()
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


static func _samples(half: float, r: float, segs: int) -> Array[float]:
	var out: Array[float] = []
	for i in range(segs + 1):
		out.append(-half + r * float(i) / segs)
	if half - r > -half + r + 0.0001:
		for i in range(segs + 1):
			out.append(half - r + r * float(i) / segs)
	else:
		out.append(half)
	return out


static func _tri(st: SurfaceTool, verts: Array[Vector3], norms: Array[Vector3], uvs: Array[Vector2], a: int, b: int, c: int, n: Vector3) -> void:
	var cross := (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if cross.length_squared() < 1e-14:
		return
	# Godot considère les faces avant dans le sens horaire.
	var order := [a, b, c] if cross.dot(n) < 0.0 else [a, c, b]
	for idx in order:
		st.set_normal(norms[idx])
		st.set_uv(uvs[idx])
		st.add_vertex(verts[idx])


static func box_mesh(size: Vector3) -> BoxMesh:
	var key := "box_%.4f_%.4f_%.4f" % [size.x, size.y, size.z]
	if _meshes.has(key):
		return _meshes[key]
	var m := BoxMesh.new()
	m.size = size
	_meshes[key] = m
	return m


static func sphere(radius: float, rings: int = 24) -> SphereMesh:
	var key := "sph_%.4f_%d" % [radius, rings]
	if _meshes.has(key):
		return _meshes[key]
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.rings = rings
	m.radial_segments = rings * 2
	_meshes[key] = m
	return m


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var key := "cap_%.4f_%.4f" % [radius, height]
	if _meshes.has(key):
		return _meshes[key]
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	m.radial_segments = 32
	m.rings = 12
	_meshes[key] = m
	return m


static func cylinder(top: float, bottom: float, height: float, segs: int = 32) -> CylinderMesh:
	var key := "cyl_%.4f_%.4f_%.4f_%d" % [top, bottom, height, segs]
	if _meshes.has(key):
		return _meshes[key]
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segs
	_meshes[key] = m
	return m


static func torus(inner: float, outer: float) -> TorusMesh:
	var key := "tor_%.4f_%.4f" % [inner, outer]
	if _meshes.has(key):
		return _meshes[key]
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 32
	m.ring_segments = 16
	_meshes[key] = m
	return m


# --- Aides de construction -----------------------------------------------------------

static func add_mesh(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scale
	parent.add_child(mi)
	return mi


static func add_rbox(parent: Node3D, size: Vector3, pos: Vector3, material: Material, radius: float = 0.01, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return add_mesh(parent, rounded_box(size, radius, 3 if radius > 0.004 else 1), material, pos, rot_deg)


## Ajoute une boîte de collision statique (en coordonnées locales du parent).
static func add_collider(parent: Node3D, size: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot_deg
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	return body
