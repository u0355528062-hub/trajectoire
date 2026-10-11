class_name PlaneTree
extends RefCounted
## Platanes procéduraux : tronc et charpentières en tubes (écorce tachetée), houppier en cartes de feuilles
## instanciées (MultiMesh, atlas de bouquets, vent dans le shader). Quelques variantes partagées par tous les
## arbres, chacune tournée, mise à l'échelle et teintée différemment : pas deux arbres identiques à l'œil.

const VARIANTS := 6
static var _variants: Array = []
static var _bark: StandardMaterial3D
static var _leaf_mat: ShaderMaterial
static var _card: QuadMesh


static func _materials() -> void:
	if _bark != null:
		return
	_bark = StandardMaterial3D.new()
	_bark.albedo_texture = load("res://assets/quartier/ecorce_a.png")
	_bark.albedo_color = Color(1.12, 1.1, 1.02)
	_bark.normal_enabled = true
	_bark.normal_texture = load("res://assets/quartier/ecorce_n.png")
	_bark.normal_scale = 1.2
	_bark.roughness = 0.86
	_bark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_leaf_mat = ShaderMaterial.new()
	_leaf_mat.shader = load("res://shaders/foliage.gdshader")
	_leaf_mat.set_shader_parameter("leaves", load("res://assets/quartier/feuilles_a.png"))
	_card = QuadMesh.new()
	_card.size = Vector2.ONE


static func variants() -> Array:
	if _variants.is_empty():
		_materials()
		for i in VARIANTS:
			_variants.append(_build_variant(9001 + i * 37))
	return _variants


## Plante un arbre : corps statique (tronc solide) + tronc + houppier. `s` : échelle, `tint` : teinte du feuillage.
static func plant(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator, s := 1.0, tint := Color(1, 1, 1), crowd: Crowd = null) -> StaticBody3D:
	var vs := variants()
	var v: Dictionary = vs[rng.randi() % vs.size()]
	var body := StaticBody3D.new()
	body.name = "Platane"
	body.add_to_group("trees")
	body.position = pos
	var yaw := rng.randf() * TAU
	body.rotation.y = yaw
	parent.add_child(body)
	var vis := Node3D.new()
	vis.scale = Vector3.ONE * s
	body.add_child(vis)
	var trunk := MeshInstance3D.new()
	trunk.mesh = v["trunk"]
	trunk.material_override = _bark
	vis.add_child(trunk)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = v["leaves"]
	mmi.material_override = _leaf_mat
	vis.add_child(mmi)
	var c: Vector3 = v["center"]
	var wc := pos + Basis(Vector3.UP, yaw) * (c * s)
	mmi.set_instance_shader_parameter("crown_center", wc)
	mmi.set_instance_shader_parameter("crown_radius", (v["radius"] as Vector3) * s)
	mmi.set_instance_shader_parameter("tree_tint", Vector3(tint.r, tint.g, tint.b))
	# les petits arbres lointains : ombres coupées au-delà de 90 m (économie)
	mmi.visibility_range_end = 260.0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = float(v["r0"]) * s * 1.05
	cyl.height = 3.2
	cs.shape = cyl
	cs.position = Vector3(0, 1.6, 0)
	body.add_child(cs)
	if crowd != null:
		crowd.add_obstacle(body, Vector2(float(v["r0"]) * s + 0.12, 0.0), Vector2.ZERO, true, true)
	return body


## Tube effilé le long d'un chemin (repères transportés), UV en mètres d'écorce
static func _tube(st: SurfaceTool, base: Array, pts: PackedVector3Array, radii: PackedFloat32Array, sides: int) -> void:
	var n := pts.size()
	var urep := maxf(1.0, roundf(TAU * radii[0] / 0.52))
	var nrm := Vector3.RIGHT
	var t0 := (pts[1] - pts[0]).normalized()
	if absf(t0.dot(nrm)) > 0.9:
		nrm = Vector3.FORWARD
	nrm = (nrm - t0 * nrm.dot(t0)).normalized()
	var vacc := 0.0
	var b0: int = base[0]
	for i in n:
		var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		nrm = (nrm - t * nrm.dot(t)).normalized()
		var bin := t.cross(nrm)
		if i > 0:
			vacc += pts[i].distance_to(pts[i - 1])
		for k in sides + 1:
			var a := TAU * float(k) / sides
			var d := nrm * cos(a) + bin * sin(a)
			st.set_normal(d)
			st.set_uv(Vector2(float(k) / sides * urep, vacc / 1.04))
			st.add_vertex(pts[i] + d * radii[i])
	# ordre (a, c, b) : face avant vers l'extérieur (convention Godot, sens horaire)
	for i in n - 1:
		for k in sides:
			var a := b0 + i * (sides + 1) + k
			var c := a + sides + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(a + 1)
			st.add_index(a + 1)
			st.add_index(c)
			st.add_index(c + 1)
	base[0] = b0 + n * (sides + 1)


static func _build_variant(sd: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := [0]
	var r0 := rng.randf_range(0.2, 0.27)
	var h0 := rng.randf_range(3.9, 5.0)
	var lean := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
	# tronc : évasé au collet, légèrement sinueux
	var tp := PackedVector3Array()
	var tr := PackedFloat32Array()
	for k in 9:
		var t := float(k) / 8.0
		var y := -0.05 + (h0 + 0.05) * t
		tp.append(lean * t * t + Vector3(sin(t * 5.0 + sd) * 0.03, y, cos(t * 4.0 + sd) * 0.03))
		tr.append(r0 * (1.0 + 0.45 * exp(-y / 0.3)) * lerpf(1.0, 0.82, t))
	_tube(st, base, tp, tr, 16)
	var top := tp[8]
	var leaf_pts: Array[Vector3] = []
	var nl := rng.randi_range(4, 5)
	var az0 := rng.randf() * TAU
	for i in nl:
		var az := az0 + TAU * float(i) / nl + rng.randf_range(-0.35, 0.35)
		var tilt := deg_to_rad(rng.randf_range(24.0, 44.0))
		var d := Vector3(cos(az) * sin(tilt), cos(tilt), sin(az) * sin(tilt))
		var out := Vector3(cos(az), 0, sin(az))
		var L := rng.randf_range(4.2, 6.0)
		var lp := PackedVector3Array()
		var lr := PackedFloat32Array()
		var start := top - Vector3(0, 0.35, 0) + out * r0 * 0.3
		for k in 8:
			var t := float(k) / 7.0
			var bend := out * (t * t * 0.9) - Vector3(0, t * t * 0.4, 0)
			lp.append(start + d * L * t + bend + Vector3(sin(t * 7.0 + az) * 0.08, 0, cos(t * 6.0 + az) * 0.08))
			lr.append(lerpf(r0 * 0.66, 0.045, pow(t, 0.8)))
		_tube(st, base, lp, lr, 10)
		leaf_pts.append(lp[5])
		leaf_pts.append(lp[7])
		var nb := rng.randi_range(3, 4)
		for j in nb:
			var tj := rng.randf_range(0.3, 0.85)
			var kk := int(tj * 7.0)
			var bp := lp[kk]
			var br := lr[kk] * 0.62
			var az2 := az + rng.randf_range(-1.2, 1.2)
			var tilt2 := tilt + rng.randf_range(0.25, 0.75)
			var d2 := Vector3(cos(az2) * sin(tilt2), cos(tilt2), sin(az2) * sin(tilt2))
			var L2 := rng.randf_range(1.8, 3.3)
			var bp2 := PackedVector3Array()
			var brr := PackedFloat32Array()
			for k in 5:
				var t := float(k) / 4.0
				bp2.append(bp + d2 * L2 * t + Vector3(0, t * t * 0.35, 0))
				brr.append(lerpf(br, 0.022, t))
			_tube(st, base, bp2, brr, 6)
			leaf_pts.append(bp2[2])
			leaf_pts.append(bp2[4])
	var am := st.commit()
	# houppier : bouquets autour des bouts de branches
	var cards: Array = []
	var cen := Vector3.ZERO
	for lp in leaf_pts:
		var nc := rng.randi_range(7, 9)
		for c in nc:
			var off := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 1), rng.randf_range(-1, 1)).normalized() * pow(rng.randf(), 0.6) * 1.25
			var horiz := Vector3(lp.x, 0, lp.z).normalized() * 0.25
			cards.append(lp + off + horiz)
	# quelques cartes à l'intérieur pour épaissir le volume
	for c in 50:
		var a := rng.randf() * TAU
		var rr := rng.randf_range(0.5, 2.6)
		cards.append(Vector3(cos(a) * rr, h0 + rng.randf_range(2.0, 5.5), sin(a) * rr))
	for p in cards:
		cen += p
	cen /= cards.size()
	var ext := Vector3.ZERO
	for p in cards:
		var d := (p as Vector3) - cen
		ext = Vector3(maxf(ext.x, absf(d.x)), maxf(ext.y, absf(d.y)), maxf(ext.z, absf(d.z)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _card
	mm.instance_count = cards.size()
	for i in cards.size():
		var p: Vector3 = cards[i]
		var sz := rng.randf_range(1.4, 2.1)
		var b := Basis.from_euler(Vector3(rng.randf_range(-1.2, 1.2), rng.randf() * TAU, rng.randf_range(-0.6, 0.6)))
		mm.set_instance_transform(i, Transform3D(b.scaled(Vector3(sz, sz, sz)), p))
		var g := rng.randf_range(0.82, 1.12)
		var y := rng.randf_range(-0.04, 0.08)
		mm.set_instance_color(i, Color(g * (1.0 + y), g, g * (0.95 - y)))
		var cell := float(rng.randi() % 4)
		mm.set_instance_custom_data(i, Color(0, 0, 0, (cell + rng.randf() * 0.95) / 4.0))
	return {"trunk": am, "leaves": mm, "center": cen, "radius": ext * 0.9 + Vector3.ONE * 0.5, "r0": r0, "h0": h0}
