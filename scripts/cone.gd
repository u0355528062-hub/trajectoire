class_name Cone
extends RigidBody3D
## Cône de chantier : léger, il décolle au coup de pied et rebondit en faisant « toc ».

var _last := 0.0

static var _body_mesh: ArrayMesh
static var _band_mesh: ArrayMesh
static var _base_mesh: ArrayMesh


static func _meshes() -> void:
	if _body_mesh != null:
		return
	_body_mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.03), Vector2(0.13, 0.03), Vector2(0.118, 0.12), Vector2(0.03, 0.66), Vector2(0.026, 0.7), Vector2(0.0, 0.705)]), 20)
	_band_mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.0975, 0.22), Vector2(0.0985, 0.22), Vector2(0.0775, 0.34), Vector2(0.0765, 0.34)]), 20)
	_base_mesh = MeshKit.rbox(Vector3(0.34, 0.03, 0.34), 0.012, 2)


func _ready() -> void:
	_meshes()
	add_to_group("kickable")
	collision_layer = 32
	collision_mask = 1 | 32 | 64
	mass = 1.3
	contact_monitor = true
	max_contacts_reported = 3
	linear_damp = 0.2
	angular_damp = 0.5
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce = 0.35
	physics_material_override = pm
	var orange := Furniture.mat("cone_orange", Color(0.96, 0.36, 0.06), 0.42)
	var white := Furniture.mat("cone_white", Color(0.92, 0.92, 0.9), 0.35, 0.0, 0.0)
	var blk := Furniture.mat("cone_base", Color(0.07, 0.07, 0.08), 0.8)
	Furniture.add(self, _body_mesh, orange)
	Furniture.add(self, _band_mesh, white, Vector3(0, 0.0, 0))
	var b2 := Furniture.add(self, _band_mesh, white, Vector3(0, 0.2, 0))
	b2.scale = Vector3(0.68, 1.0, 0.68)
	Furniture.add(self, _base_mesh, blk, Vector3(0, 0.015, 0))
	Furniture.col_box(self, Vector3(0.34, 0.03, 0.34), Vector3(0, 0.015, 0))
	Furniture.col_cyl(self, 0.075, 0.62, Vector3(0, 0.37, 0))
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.16, 0)
	body_entered.connect(_on_body)
	rotation.y = randf() * TAU


func kick(point: Vector3, dir: Vector3, power := 1.0) -> bool:
	var c := global_position + Vector3(0, 0.3, 0)
	if c.distance_to(point) > 0.7:
		return false
	var d := Vector3(dir.x, 0, dir.z).normalized()
	apply_impulse((d * 5.8 + Vector3.UP * (2.6 + randf() * 1.4)) * mass * power, point - global_position)
	apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.6 * mass)
	AudioLib.play_at(self, "cone_hit_%d" % (randi() % 2), point, -4.0, 6.0, randf_range(0.95, 1.2))
	get_tree().call_group("crowd", "on_event", "vandal", {"pos": global_position, "amount": 0.08})
	return true


func push(dir: Vector3, speed: float) -> void:
	apply_central_impulse(Vector3(dir.x, 0.0, dir.z).normalized() * mass * clampf(speed, 0.0, 6.0) * 0.5)


func _on_body(_b: Node) -> void:
	var sp := linear_velocity.length()
	var now := Time.get_ticks_msec() / 1000.0
	if sp > 1.3 and now - _last > 0.1:
		_last = now
		AudioLib.play_at(self, "cone_hit_%d" % (randi() % 2), global_position, clampf(-16.0 + sp * 2.0, -16.0, -2.0), 6.0, randf_range(0.9, 1.25))
