class_name GeoBatch
extends RefCounted
## Accumulateur de géométrie statique par matériau : on y verse des pavés, cylindres, polygones et maillages
## transformés, puis on en tire un ArrayMesh à une surface par matériau (un seul MeshInstance, peu d'appels de
## dessin). Les maillages produits peuvent être partagés entre plusieurs objets (voitures du même modèle).

var _parts := {}        # clé -> [verts, normales, uvs, indices]
var _mats := {}         # clé -> Material
var _order: Array[String] = []

static var _cache := {}


func _part(key: String, m: Material) -> Array:
	if not _parts.has(key):
		_parts[key] = [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedInt32Array()]
		_mats[key] = m
		_order.append(key)
	return _parts[key]


func has(key: String) -> bool:
	return _parts.has(key)


## Verse la surface `surf` d'un maillage, transformée par `xf`
func add_mesh(key: String, m: Material, mesh: Mesh, xf := Transform3D.IDENTITY, surf := 0) -> void:
	var a := mesh.surface_get_arrays(surf)
	var p := _part(key, m)
	var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var uv = a[Mesh.ARRAY_TEX_UV]
	var ix = a[Mesh.ARRAY_INDEX]
	var base: int = (p[0] as PackedVector3Array).size()
	var nb := xf.basis.inverse().transposed()
	var flip := xf.basis.determinant() < 0.0
	for i in vs.size():
		p[0].append(xf * vs[i])
		p[1].append((nb * ns[i]).normalized() if i < ns.size() else Vector3.UP)
		p[2].append(uv[i] if uv != null and i < (uv as PackedVector2Array).size() else Vector2.ZERO)
	if ix == null or (ix as PackedInt32Array).is_empty():
		for i in range(0, vs.size(), 3):
			if flip:
				p[3].append_array([base + i, base + i + 2, base + i + 1])
			else:
				p[3].append_array([base + i, base + i + 1, base + i + 2])
	else:
		var ii: PackedInt32Array = ix
		for i in range(0, ii.size(), 3):
			if flip:
				p[3].append_array([base + ii[i], base + ii[i + 2], base + ii[i + 1]])
			else:
				p[3].append_array([base + ii[i], base + ii[i + 1], base + ii[i + 2]])


static func _cached(key: String, make: Callable) -> Mesh:
	if not _cache.has(key):
		_cache[key] = make.call()
	return _cache[key]


## Pavé (arêtes arrondies de rayon `r` si r > 0) centré en `pos`
func box(key: String, m: Material, size: Vector3, pos: Vector3, b := Basis(), r := 0.0) -> void:
	if r <= 0.0:
		var unit := _cached("box", func():
			var bm := BoxMesh.new()
			bm.size = Vector3.ONE
			return bm)
		add_mesh(key, m, unit, Transform3D(b * Basis.from_scale(size), pos))
	else:
		var rk := "rb%.3f_%.3f_%.3f_%.3f" % [size.x, size.y, size.z, r]
		var rm := _cached(rk, func(): return MeshKit.rbox(size, r, 1))
		add_mesh(key, m, rm, Transform3D(b, pos))


## Cylindre d'axe Y (rayon haut / bas), centré en `pos`
func cyl(key: String, m: Material, r_top: float, r_bot: float, h: float, pos: Vector3, b := Basis(), segs := 12) -> void:
	var ck := "cy%.3f_%.3f_%d" % [r_top / maxf(r_bot, 0.001), 1.0, segs]
	var cm := _cached(ck, func():
		var c := CylinderMesh.new()
		c.top_radius = 0.5 * r_top / maxf(r_bot, 0.001)
		c.bottom_radius = 0.5
		c.height = 1.0
		c.radial_segments = segs
		c.rings = 1
		return c)
	add_mesh(key, m, cm, Transform3D(b * Basis.from_scale(Vector3(r_bot * 2.0, h, r_bot * 2.0)), pos))


## Polygone plan convexe (sommets dans l'ordre) ; `two_sided` duplique la face au dos
func poly(key: String, m: Material, pts: PackedVector3Array, two_sided := false, uvs := PackedVector2Array()) -> void:
	if pts.size() < 3:
		return
	var p := _part(key, m)
	var n := (pts[1] - pts[0]).cross(pts[2] - pts[0])
	if n.length() < 1e-9 and pts.size() > 3:
		n = (pts[2] - pts[0]).cross(pts[3] - pts[0])
	n = n.normalized()
	for side in (2 if two_sided else 1):
		var sg := 1.0 if side == 0 else -1.0
		var base: int = (p[0] as PackedVector3Array).size()
		for i in pts.size():
			p[0].append(pts[i])
			p[1].append(-n * sg)          # Godot : face avant = sens horaire vu de face
			p[2].append(uvs[i] if i < uvs.size() else Vector2(0, 0))
		for i in range(1, pts.size() - 1):
			if side == 0:
				p[3].append_array([base, base + i, base + i + 1])
			else:
				p[3].append_array([base, base + i + 1, base + i])


## Quadrilatère plan a-b-c-d (même convention que `poly`)
func quad(key: String, m: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, two_sided := false, uvs := PackedVector2Array()) -> void:
	poly(key, m, PackedVector3Array([a, b, c, d]), two_sided, uvs)


## Polygone orienté vers `facing` (la normale de face est retournée si besoin)
func poly_facing(key: String, m: Material, pts: PackedVector3Array, facing: Vector3, uvs := PackedVector2Array()) -> void:
	if pts.size() < 3:
		return
	var n := (pts[1] - pts[0]).cross(pts[2] - pts[0])
	if -n.dot(facing) < 0.0:
		var r := PackedVector3Array()
		var ru := PackedVector2Array()
		for i in range(pts.size() - 1, -1, -1):
			r.append(pts[i])
			if i < uvs.size():
				ru.append(uvs[i])
		poly(key, m, r, false, ru)
	else:
		poly(key, m, pts, false, uvs)


## Surface lissée en grille (rangées de même nombre de points), faces tournées du côté de `up`
func grid(key: String, m: Material, rows: Array, up: Vector3) -> void:
	var p := _part(key, m)
	var nr := rows.size()
	var nc: int = (rows[0] as PackedVector3Array).size()
	var base: int = (p[0] as PackedVector3Array).size()
	for i in nr:
		for j in nc:
			var r0: PackedVector3Array = rows[i]
			var ra: PackedVector3Array = rows[maxi(i - 1, 0)]
			var rb: PackedVector3Array = rows[mini(i + 1, nr - 1)]
			var du := r0[mini(j + 1, nc - 1)] - r0[maxi(j - 1, 0)]
			var dv := rb[j] - ra[j]
			var n := du.cross(dv).normalized()
			if n.dot(up) < 0.0:
				n = -n
			p[0].append(r0[j])
			p[1].append(n)
			p[2].append(Vector2(float(j) / (nc - 1), float(i) / (nr - 1)))
	for i in nr - 1:
		for j in nc - 1:
			var a := base + i * nc + j
			var b := a + 1
			var c := a + nc
			var d := c + 1
			var va: Vector3 = p[0][a]
			var fn: Vector3 = ((p[0][b] as Vector3) - va).cross((p[0][c] as Vector3) - va)
			# face avant (sens horaire) du côté de `up`
			if -fn.dot(up) >= 0.0:
				p[3].append_array([a, b, c, b, d, c])
			else:
				p[3].append_array([a, c, b, b, c, d])


## ArrayMesh des clés demandées (toutes si vide) : une surface par matériau
func build(keys: Array = []) -> ArrayMesh:
	var am := ArrayMesh.new()
	for k in _order:
		if not keys.is_empty() and not keys.has(k):
			continue
		var p: Array = _parts[k]
		if (p[3] as PackedInt32Array).is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = p[0]
		arr[Mesh.ARRAY_NORMAL] = p[1]
		arr[Mesh.ARRAY_TEX_UV] = p[2]
		arr[Mesh.ARRAY_INDEX] = p[3]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(am.get_surface_count() - 1, _mats[k])
	return am


## Nombre de triangles accumulés (statistiques)
func tri_count(keys: Array = []) -> int:
	var t := 0
	for k in _order:
		if keys.is_empty() or keys.has(k):
			t += (_parts[k][3] as PackedInt32Array).size() / 3
	return t


static func instance(mesh: Mesh, parent: Node, shadow := true, vis_end := 0.0, mat_override: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if mat_override:
		mi.material_override = mat_override
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis_end > 0.0:
		mi.visibility_range_end = vis_end
		mi.visibility_range_end_margin = vis_end * 0.08
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(mi)
	return mi
