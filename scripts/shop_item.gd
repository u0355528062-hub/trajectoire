class_name ShopItem
extends Node3D
## Meuble de boutique cassable (guichet, rayonnage, comptoir, présentoir...) : au premier coup il vacille, au
## suivant il se renverse et sa marchandise s'éparpille (quelques objets physiques). Repère : posé au sol, centré.

var size := Vector3(1.0, 1.0, 0.5)
var color := Color(0.7, 0.7, 0.7)
var goods: Array = []
var heavy := false
var outside := false          # sur le trottoir (terrasse, étal) : pas concerné par le pillage
var shop: Shop
var smashed := false
var hp := 1
var _pivot: Node3D


static var _mat: StandardMaterial3D
static var _unit_box: BoxMesh
static var _unit_cyl: CylinderMesh


func _ready() -> void:
	add_to_group("kickable")
	hp = 2 if heavy else 1
	_pivot = Node3D.new()
	add_child(_pivot)
	# meuble + étagères + marchandise fusionnés en un seul maillage (couleurs par sommet)
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.roughness = 0.6
		_unit_box = BoxMesh.new()
		_unit_box.size = Vector3.ONE
		_unit_cyl = CylinderMesh.new()
		_unit_cyl.top_radius = 0.5
		_unit_cyl.bottom_radius = 0.5
		_unit_cyl.height = 1.0
		_unit_cyl.radial_segments = 8
		_unit_cyl.rings = 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = hash(str(position) + str(size))
	var tall := size.y > 1.3 and not goods.is_empty()
	if tall:
		# rayonnage : montants, fond, tablettes
		_add(st, _unit_box, Vector3(size.x, size.y, 0.04), Vector3(0, size.y * 0.5, -size.z * 0.5 + 0.02), color.darkened(0.15))
		for sx in [-1.0, 1.0]:
			_add(st, _unit_box, Vector3(0.05, size.y, size.z), Vector3(sx * (size.x * 0.5 - 0.025), size.y * 0.5, 0), color)
		_add(st, _unit_box, Vector3(size.x, 0.05, size.z), Vector3(0, size.y - 0.025, 0), color)
		_add(st, _unit_box, Vector3(size.x, 0.12, size.z), Vector3(0, 0.06, 0), color.darkened(0.25))
	else:
		_add(st, _unit_box, size, Vector3(0, size.y * 0.5, 0), color)
		_add(st, _unit_box, Vector3(size.x + 0.04, 0.04, size.z + 0.04), Vector3(0, size.y + 0.02, 0), color.lightened(0.15))   # plateau
	if not goods.is_empty():
		var rows := maxi(int((size.y - 0.15) / 0.42), 1) if tall else 1
		for row in rows:
			var y := 0.12 + float(row) * 0.42 if tall else size.y + 0.04
			if tall and row > 0:
				_add(st, _unit_box, Vector3(size.x - 0.1, 0.025, size.z - 0.04), Vector3(0, y, 0), color.lightened(0.08))    # tablette
			var x := -size.x * 0.5 + 0.08
			while x < size.x * 0.5 - 0.08:
				var gc: Color = goods[r.randi() % goods.size()]
				gc = gc.darkened(r.randf() * 0.25)
				var kind := r.randi() % 4
				var gz := size.z * 0.5 - 0.1 if tall else r.randf_range(-size.z * 0.3, size.z * 0.3)
				if kind == 0:
					var hh := r.randf_range(0.2, 0.32)
					_add(st, _unit_cyl, Vector3(0.07, hh, 0.07), Vector3(x, y + hh * 0.5, gz), gc)          # bouteille
					_add(st, _unit_cyl, Vector3(0.03, 0.07, 0.03), Vector3(x, y + hh + 0.035, gz), gc.darkened(0.4))
					x += 0.09
				elif kind == 1:
					var bw := r.randf_range(0.12, 0.22)
					var bh := r.randf_range(0.14, 0.3)
					_add(st, _unit_box, Vector3(bw, bh, r.randf_range(0.1, 0.18)), Vector3(x + bw * 0.5, y + bh * 0.5, gz), gc)   # boîte
					x += bw + 0.02
				elif kind == 2:
					for k in 3:
						_add(st, _unit_cyl, Vector3(0.08, 0.11, 0.08), Vector3(x, y + 0.055 + float(k) * 0.11, gz), gc.lightened(0.05 * k))  # conserves
					x += 0.1
				else:
					x += r.randf_range(0.05, 0.2)                          # trou dans le rayon
	st.generate_normals()
	var body := MeshInstance3D.new()
	body.mesh = st.commit()
	body.material_override = _mat
	_pivot.add_child(body)


static var _cache := {}

func _add(st: SurfaceTool, m: Mesh, sz: Vector3, c: Vector3, col: Color) -> void:
	if not _cache.has(m):
		_cache[m] = m.surface_get_arrays(0)
	var arr: Array = _cache[m]
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	st.set_color(col)
	for i in idx:
		st.add_vertex(verts[i] * sz + c)


func contains(p: Vector3) -> bool:
	var l := to_local(p)
	return absf(l.x) <= size.x * 0.5 + 0.35 and l.y <= size.y + 0.3 and absf(l.z) <= size.z * 0.5 + 0.45


func kick(point: Vector3, dir: Vector3, _power := 1.0) -> bool:
	if smashed or not contains(point):
		return false
	hit(dir)
	return true


func hit(dir: Vector3) -> void:
	if smashed:
		return
	hp -= 1
	AudioLib.play_at(self, "bin_hit", global_position + Vector3.UP * 0.8, -2.0, 8.0, randf_range(0.7, 0.95))
	if hp > 0:
		var tw := create_tween()
		tw.tween_property(_pivot, "rotation:z", 0.08, 0.08)
		tw.tween_property(_pivot, "rotation:z", 0.0, 0.25)
		return
	smash(dir)


## Renversé : bascule vers l'arrière (ou sur le côté), marchandise qui vole, débris
func smash(dir: Vector3) -> void:
	if smashed:
		return
	smashed = true
	var ld := global_basis.inverse() * dir
	var tw := create_tween()
	tw.tween_property(_pivot, "rotation", Vector3(-signf(ld.z if absf(ld.z) > 0.1 else 1.0) * 1.35, 0.0, randf_range(-0.2, 0.2)), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_pivot, "position", Vector3(0, -size.y * 0.15, 0), 0.1)
	AudioLib.play_at(self, "barrier_fall", global_position + Vector3.UP * 0.5, 0.0, 10.0, randf_range(0.8, 1.0))
	var scene := get_tree().current_scene
	var n := 5 if goods.is_empty() else 9
	for i in n:
		var rb := RigidBody3D.new()
		rb.mass = 0.3
		rb.collision_layer = 4
		rb.collision_mask = 1 | 4
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(randf_range(0.1, 0.22), randf_range(0.1, 0.26), randf_range(0.08, 0.18))
		mi.mesh = bm
		mi.material_override = Shop.col_mat(goods[i % goods.size()] if not goods.is_empty() else color, 0.5)
		rb.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = bm.size
		cs.shape = bs
		rb.add_child(cs)
		scene.add_child(rb)
		rb.global_position = global_position + global_basis * Vector3(randf_range(-size.x * 0.4, size.x * 0.4), randf_range(0.4, size.y), 0)
		rb.linear_velocity = dir.normalized() * randf_range(1.0, 3.5) + Vector3(randf_range(-1.5, 1.5), randf_range(1.0, 3.0), randf_range(-1.5, 1.5))
		rb.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		get_tree().create_timer(randf_range(25.0, 40.0)).timeout.connect(func(): if is_instance_valid(rb): rb.queue_free())
	if shop:
		shop.on_item_smashed(self)
