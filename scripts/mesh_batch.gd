class_name MeshBatch
extends RefCounted
## Accumulateur de géométrie statique par matériau : tout ce qui partage un matériau finit dans une seule
## surface d'un seul maillage (quelques appels de rendu pour des centaines de pièces).

var _st := {}          # clé -> SurfaceTool
var _mats := {}        # clé -> Material
var _tan := {}         # clé -> calculer les tangentes (cartes de normales)
static var _unit_box: BoxMesh
static var _unit_cyl := {}


func _get_st(key: String, m: Material, tangents := false) -> SurfaceTool:
	if not _st.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[key] = st
		_mats[key] = m
		_tan[key] = tangents
	return _st[key]


func is_empty() -> bool:
	return _st.is_empty()


## Ajoute un maillage existant (surface `surface`) transformé par `xf`
func add(key: String, m: Material, mesh: Mesh, xf: Transform3D, surface := 0, tangents := false) -> void:
	_get_st(key, m, tangents).append_from(mesh, surface, xf)


func box(key: String, m: Material, size: Vector3, c: Vector3, b := Basis()) -> void:
	if _unit_box == null:
		_unit_box = BoxMesh.new()
		_unit_box.size = Vector3.ONE
	add(key, m, _unit_box, Transform3D(b * Basis.from_scale(size), c))


func cyl(key: String, m: Material, r_top: float, r_bot: float, h: float, c: Vector3, b := Basis(), segs := 12) -> void:
	var k := "%d_%.3f" % [segs, r_top / maxf(r_bot, 0.0001)]
	if not _unit_cyl.has(k):
		var cm := CylinderMesh.new()
		cm.top_radius = 0.5 * r_top / maxf(r_bot, 0.0001)
		cm.bottom_radius = 0.5
		cm.height = 1.0
		cm.radial_segments = segs
		cm.rings = 1
		_unit_cyl[k] = cm
	add(key, m, _unit_cyl[k], Transform3D(b * Basis.from_scale(Vector3(r_bot * 2.0, h, r_bot * 2.0)), c))


## Quadrilatère horizontal (décor posé au sol) : centre, taille (x, z), rotation autour de Y, rectangle d'UV
func ground_quad(key: String, m: Material, c: Vector3, size: Vector2, yaw := 0.0, uv := Rect2(0, 0, 1, 1), tangents := false) -> void:
	var st := _get_st(key, m, tangents)
	var b := Basis(Vector3.UP, yaw)
	var hx := b.x * size.x * 0.5
	var hz := b.z * size.y * 0.5
	var p := [c - hx - hz, c + hx - hz, c + hx + hz, c - hx + hz]
	var t := [uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(t[i])
		st.add_vertex(p[i])


## Quadrilatère quelconque (4 coins dans l'ordre, face avant selon `n`)
func quad(key: String, m: Material, p: Array, n: Vector3, uv := Rect2(0, 0, 1, 1), tangents := false) -> void:
	var st := _get_st(key, m, tangents)
	var t := [uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)]
	var cr: Vector3 = ((p[1] as Vector3) - (p[0] as Vector3)).cross((p[2] as Vector3) - (p[0] as Vector3))
	var order := [0, 2, 1, 0, 3, 2] if cr.dot(n) > 0.0 else [0, 1, 2, 0, 2, 3]
	for i in order:
		st.set_normal(n)
		st.set_uv(t[i])
		st.add_vertex(p[i])


## Triangles bruts (sommets, normales, uv, indices) : pour les profils extrudés
func arrays(key: String, m: Material, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array, tangents := false) -> void:
	var st := _get_st(key, m, tangents)
	for i in idx:
		st.set_normal(norms[i])
		st.set_uv(uvs[i])
		st.add_vertex(verts[i])


## Construit le maillage (une surface par matériau) et l'ajoute à `parent`
func commit(parent: Node, shadows := true, vis_end := 0.0, node_name := "") -> MeshInstance3D:
	if _st.is_empty():
		return null
	var am := ArrayMesh.new()
	for key in _st:
		var st: SurfaceTool = _st[key]
		if _tan[key]:
			st.generate_tangents()
		st.commit(am)
		am.surface_set_material(am.get_surface_count() - 1, _mats[key])
	var mi := MeshInstance3D.new()
	mi.mesh = am
	if node_name != "":
		mi.name = node_name
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis_end > 0.0:
		mi.visibility_range_end = vis_end
		mi.visibility_range_end_margin = vis_end * 0.1
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(mi)
	_st.clear()
	_mats.clear()
	_tan.clear()
	return mi
