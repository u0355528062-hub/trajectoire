class_name Throwable
extends RigidBody3D
## Objet jeté sur la police : canette, sac à dos, crayon, pierre... Touche un policier (ou son bouclier).

var kind := "can"
var thrower: Node3D
var _age := 0.0
var _hit := false


static func make(k: String) -> Throwable:
	var t := Throwable.new()
	t.kind = k
	return t


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 16 | 32 | 64
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.5
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce = 0.35
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var vis: Node3D
	match kind:
		"can":
			vis = Props.can(Color(0.75, 0.1, 0.1) if randf() < 0.5 else Color(0.2, 0.45, 0.8))
			var c := CylinderShape3D.new()
			c.radius = 0.033
			c.height = 0.12
			cs.shape = c
			mass = 0.35
		"bag":
			vis = Props.backpack(Color(0.1, 0.12, 0.2) if randf() < 0.5 else Color(0.3, 0.08, 0.1))
			var b := BoxShape3D.new()
			b.size = Vector3(0.28, 0.4, 0.16)
			cs.shape = b
			mass = 1.2
		"pencil":
			vis = Props.pencil()
			var c2 := CapsuleShape3D.new()
			c2.radius = 0.006
			c2.height = 0.18
			cs.shape = c2
			mass = 0.02
		"bottle":
			vis = Props.bottle()
			var c3 := CapsuleShape3D.new()
			c3.radius = 0.04
			c3.height = 0.24
			cs.shape = c3
			mass = 0.5
		_:
			vis = MeshInstance3D.new()
			(vis as MeshInstance3D).mesh = Stone.make_mesh(7)
			(vis as MeshInstance3D).material_override = Stone.material()
			vis.scale = Vector3.ONE * 0.17
			var s := SphereShape3D.new()
			s.radius = 0.08
			cs.shape = s
			mass = 0.45
	add_child(vis)
	add_child(cs)
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > 14.0:
		queue_free()


func _on_body(body: Node) -> void:
	if _hit or _age < 0.04:
		return
	var sp := linear_velocity.length()
	if body is Cop and sp > 2.5:
		_hit = true
		var dir := linear_velocity.normalized()
		var power := clampf(mass * sp * 0.12, 0.3, 1.2)
		(body as Cop).on_hit(kind, dir, power, thrower)
		AudioLib.play_at(self, "can_clink" if kind == "can" else ("bag_drop" if kind == "bag" else "toss"), global_position, -2.0, 8.0)
	elif sp > 2.0:
		var snd := "can_clink" if kind == "can" else ("bag_drop" if kind == "bag" else "toss")
		AudioLib.play_at(self, snd, global_position, -8.0, 6.0, randf_range(0.9, 1.15))
