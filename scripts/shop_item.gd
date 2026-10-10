class_name ShopItem
extends Node3D
## Meuble de boutique cassable (guichet, rayonnage, comptoir, présentoir...) : au premier coup il vacille, au
## suivant il se renverse et sa marchandise s'éparpille (quelques objets physiques). Repère : posé au sol, centré.

var size := Vector3(1.0, 1.0, 0.5)
var color := Color(0.7, 0.7, 0.7)
var goods: Array = []
var heavy := false
var shop: Shop
var smashed := false
var hp := 1
var _pivot: Node3D


func _ready() -> void:
	add_to_group("kickable")
	hp = 2 if heavy else 1
	_pivot = Node3D.new()
	add_child(_pivot)
	var body := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	body.mesh = b
	body.material_override = Shop.col_mat(color, 0.6)
	body.position = Vector3(0, size.y * 0.5, 0)
	_pivot.add_child(body)
	# marchandise visible sur le meuble : petites boîtes colorées en rangées
	if not goods.is_empty():
		var rows := maxi(int(size.y / 0.45), 1)
		for r in rows:
			var y := 0.25 + float(r) * 0.42
			if y > size.y - 0.05:
				break
			var n := maxi(int(size.x / 0.22), 1)
			for i in n:
				var g := MeshInstance3D.new()
				var gb := BoxMesh.new()
				gb.size = Vector3(0.16, 0.2, 0.12)
				g.mesh = gb
				g.material_override = Shop.col_mat(goods[(i + r) % goods.size()], 0.5)
				g.position = Vector3(-size.x * 0.5 + 0.14 + float(i) * 0.22, y + 0.1, size.z * 0.5 + 0.02)
				_pivot.add_child(g)


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
