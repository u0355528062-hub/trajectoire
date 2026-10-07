class_name MeshKit
extends RefCounted
## Petits outils de modélisation procédurale : solides de révolution, boîtes arrondies,
## surfaces lissées, tubes, panneaux courbes. Les normales sont calculées proprement
## (arêtes vives ou lissées) pour que les objets aient de vrais reflets.


static func _finish(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Ajoute un triangle en garantissant que l'ordre des sommets (Godot : sens horaire = face avant)
## correspond à la normale demandée.
static func _tri_idx(idx: PackedInt32Array, verts: PackedVector3Array, a: int, b: int, c: int, n: Vector3) -> void:
	var cr := (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if cr.dot(n) > 0.0:
		idx.append_array([a, c, b])
	else:
		idx.append_array([a, b, c])


## Solide de révolution autour de Y. profile = [(rayon, y), ...] parcouru de bas en haut ;
## la normale extérieure est à droite du sens de parcours. Les angles vifs (> crease_deg) restent nets.
static func lathe(profile: PackedVector2Array, segs := 24, crease_deg := 38.0, flip := false) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var n := profile.size()
	if n < 2:
		return ArrayMesh.new()
	var seg_n: Array[Vector2] = []
	var total := 0.0
	var cum := PackedFloat32Array([0.0])
	for i in n - 1:
		var d := profile[i + 1] - profile[i]
		var nn := Vector2(d.y, -d.x)
		if nn.length() < 1e-9:
			nn = Vector2(1, 0)
		seg_n.append(nn.normalized() * (-1.0 if flip else 1.0))
		total += d.length()
		cum.append(total)
	var cr := cos(deg_to_rad(crease_deg))
	for s in n - 1:
		var base := verts.size()
		for end in 2:
			var pi := s + end
			var p := profile[pi]
			var nrm := seg_n[s]
			var other := -1
			if end == 0 and s > 0:
				other = s - 1
			elif end == 1 and s < n - 2:
				other = s + 1
			if other >= 0 and seg_n[other].dot(seg_n[s]) > cr:
				nrm = (seg_n[other] + seg_n[s]).normalized()
			for j in segs + 1:
				var a := TAU * float(j) / segs
				var ca := cos(a)
				var sa := sin(a)
				verts.append(Vector3(p.x * ca, p.y, p.x * sa))
				norms.append(Vector3(nrm.x * ca, nrm.y, nrm.x * sa))
				uvs.append(Vector2(float(j) / segs, cum[pi] / maxf(total, 1e-6)))
		var w := segs + 1
		for j in segs:
			var a0 := base + j
			var a1 := base + j + 1
			var b0 := base + w + j
			var b1 := base + w + j + 1
			var nm := norms[a0] + norms[b0] + norms[a1] + norms[b1]
			_tri_idx(idx, verts, a0, a1, b0, nm)
			_tri_idx(idx, verts, a1, b1, b0, nm)
	return _finish(verts, norms, uvs, idx)


## Boîte à bords arrondis (rayon r, `seg` subdivisions par coin).
static func rbox(size: Vector3, r: float, seg := 3) -> ArrayMesh:
	var h := size * 0.5
	r = minf(r, minf(h.x, minf(h.y, h.z)) * 0.999)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var axes: Array = []
	for ax in 3:
		var hh: float = [h.x, h.y, h.z][ax]
		var lst: Array[float] = []
		for k in seg + 1:
			lst.append(-hh + r * (1.0 - cos(float(k) / seg * PI * 0.5)))
		var tail: Array[float] = []
		for k in seg + 1:
			tail.append(hh - r * (1.0 - cos(float(k) / seg * PI * 0.5)))
		tail.reverse()
		lst.append_array(tail)
		axes.append(lst)
	var inner := Vector3(h.x - r, h.y - r, h.z - r)
	# 6 faces : axe normal, signe
	for face in 6:
		var ax := face / 2
		var sgn := 1.0 if face % 2 == 0 else -1.0
		var u_ax := (ax + 1) % 3
		var v_ax := (ax + 2) % 3
		var lu: Array = axes[u_ax]
		var lv: Array = axes[v_ax]
		var base := verts.size()
		for iu in lu.size():
			for iv in lv.size():
				var p := Vector3.ZERO
				p[ax] = sgn * [h.x, h.y, h.z][ax]
				p[u_ax] = lu[iu]
				p[v_ax] = lv[iv]
				var c := Vector3(clampf(p.x, -inner.x, inner.x), clampf(p.y, -inner.y, inner.y), clampf(p.z, -inner.z, inner.z))
				var off := p - c
				var nrm := off.normalized() if off.length() > 1e-9 else Vector3.ZERO
				if nrm == Vector3.ZERO:
					nrm = Vector3.ZERO
					nrm[ax] = sgn
				verts.append(c + nrm * r)
				norms.append(nrm)
				uvs.append(Vector2(float(iu) / (lu.size() - 1), float(iv) / (lv.size() - 1)))
		var wv := lv.size()
		for iu in lu.size() - 1:
			for iv in lv.size() - 1:
				var a := base + iu * wv + iv
				var b := a + 1
				var c2 := a + wv
				var d := c2 + 1
				var nf := Vector3.ZERO
				nf[ax] = sgn
				_tri_idx(idx, verts, a, b, c2, nf)
				_tri_idx(idx, verts, b, d, c2, nf)
	return _finish(verts, norms, uvs, idx)


## Surface lissée passant par des anneaux de points (même nombre de points par anneau).
## Les normales sont calculées par moyenne des faces ; `closed` referme l'anneau ; `outward` oriente
## les faces vers l'extérieur du centre de chaque anneau.
static func loft(rings: Array, closed := true, caps := true) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var nr := rings.size()
	var np: int = (rings[0] as PackedVector3Array).size()
	var cols := np + (1 if closed else 0)
	for i in nr:
		var ring: PackedVector3Array = rings[i]
		for j in cols:
			verts.append(ring[j % np])
			uvs.append(Vector2(float(j) / (cols - 1), float(i) / (nr - 1)))
			norms.append(Vector3.ZERO)
	var centers: Array[Vector3] = []
	for i in nr:
		var c := Vector3.ZERO
		for p in (rings[i] as PackedVector3Array):
			c += p
		centers.append(c / np)
	for i in nr - 1:
		for j in cols - 1:
			var a := i * cols + j
			var b := a + 1
			var c := a + cols
			var d := c + 1
			for tri in [[a, b, c], [b, d, c]]:
				var va := verts[tri[0]]
				var vb := verts[tri[1]]
				var vc := verts[tri[2]]
				var fn := (vb - va).cross(vc - va)
				var mid := (va + vb + vc) / 3.0
				var oc: Vector3 = centers[i]
				if fn.dot(mid - oc) < 0.0:
					fn = -fn
				for k in 3:
					norms[tri[k]] += fn
				_tri_idx(idx, verts, tri[0], tri[1], tri[2], fn)
	if closed:
		for i in nr:  # coutures : mêmes normales aux deux bords
			var n0 := norms[i * cols] + norms[i * cols + cols - 1]
			norms[i * cols] = n0
			norms[i * cols + cols - 1] = n0
	for k in norms.size():
		norms[k] = norms[k].normalized() if norms[k].length() > 1e-9 else Vector3.UP
	if caps:
		for end in 2:
			var ri := 0 if end == 0 else nr - 1
			var ring: PackedVector3Array = rings[ri]
			var c := centers[ri]
			var base := verts.size()
			verts.append(c)
			var nn := (centers[1] - centers[0]).normalized() * (-1.0 if end == 0 else 1.0)
			norms.append(nn)
			uvs.append(Vector2(0.5, 0.5))
			for j in np:
				verts.append(ring[j])
				norms.append(nn)
				uvs.append(Vector2(0.5, 0.5))
			for j in np:
				_tri_idx(idx, verts, base, base + 1 + j, base + 1 + (j + 1) % np, nn)
	return _finish(verts, norms, uvs, idx)


## Tube le long d'un chemin (section circulaire).
static func tube(points: PackedVector3Array, radius: float, sides := 10, caps := true) -> ArrayMesh:
	var rings: Array = []
	var n := points.size()
	var prev_up := Vector3.UP
	for i in n:
		var t := (points[min(i + 1, n - 1)] - points[max(i - 1, 0)]).normalized()
		var up := prev_up
		if absf(t.dot(up)) > 0.95:
			up = Vector3.RIGHT
		var rt := t.cross(up).normalized()
		up = rt.cross(t).normalized()
		prev_up = up
		var ring := PackedVector3Array()
		for k in sides:
			var a := TAU * float(k) / sides
			ring.append(points[i] + (rt * cos(a) + up * sin(a)) * radius)
		rings.append(ring)
	return loft(rings, true, caps)


## Panneau courbé (bouclier) : largeur w (x), hauteur h (y), flèche `bend` (z) au centre.
static func curved_panel(w: float, h: float, bend: float, nx := 12, ny := 4, thick := 0.0) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for sheet in (2 if thick > 0.0 else 1):
		var sgn := 1.0 if sheet == 0 else -1.0
		var base := verts.size()
		for iy in ny + 1:
			for ix in nx + 1:
				var u := float(ix) / nx
				var x := (u - 0.5) * w
				var t := (u - 0.5) * 2.0
				var z := -bend * t * t                      # centre vers l'avant, bords en retrait
				var dzdx := -2.0 * bend * t / (w * 0.5)
				var nrm := Vector3(-dzdx, 0, 1).normalized() * sgn
				verts.append(Vector3(x, (float(iy) / ny - 0.5) * h, z + thick * 0.5 * sgn))
				norms.append(nrm)
				uvs.append(Vector2(u, 1.0 - float(iy) / ny))
		for iy in ny:
			for ix in nx:
				var a := base + iy * (nx + 1) + ix
				var nf := Vector3(0, 0, sgn)
				_tri_idx(idx, verts, a, a + 1, a + nx + 1, nf)
				_tri_idx(idx, verts, a + 1, a + nx + 2, a + nx + 1, nf)
	return _finish(verts, norms, uvs, idx)


## Fusionne plusieurs maillages (un seul MeshInstance) : [[mesh, Transform3D], ...]
static func merge(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		var m: Mesh = p[0]
		var xf: Transform3D = p[1]
		st.append_from(m, 0, xf)
	return st.commit()


static func mesh_instance(mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	if parent:
		parent.add_child(mi)
	return mi


static func std_mat(color: Color, rough := 0.7, metal := 0.0, spec := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = spec
	return m
