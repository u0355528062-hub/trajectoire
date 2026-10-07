class_name GasGrenade
extends RigidBody3D
## Grenade lacrymogène tirée par un grenadier : retombe, rebondit, puis crache son nuage.
## On peut la renvoyer d'un coup de pied (F) vers les policiers.

var crowd: Crowd
var cloud: GasCloud
var _t := 0.0
var _active := false
var _vent: GPUParticles3D
var _last_snd := 0.0


func _ready() -> void:
	add_to_group("kickable")
	add_to_group("gas_grenades")
	collision_layer = 64
	collision_mask = 1 | 32 | 64
	mass = 0.4
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 3
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.15
	angular_damp = 1.5
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.35
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.033
	cap.height = 0.14
	cs.shape = cap
	add_child(cs)
	add_child(CopGear.grenade())
	body_entered.connect(_on_body)
	if crowd == null:
		crowd = _find_crowd()


func _find_crowd() -> Crowd:
	for n in get_tree().get_nodes_in_group("crowd"):
		if n is Crowd:
			return n
	return null


func launch_to(target: Vector3, speed: float) -> void:
	linear_velocity = ArcPreview.solve(global_position, target, speed, false)
	angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))


func _on_body(_b: Node) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if linear_velocity.length() > 1.5 and now - _last_snd > 0.15:
		_last_snd = now
		AudioLib.play_at(self, "gas_clink", global_position, -4.0, 12.0, randf_range(0.9, 1.1))
	if not _active and _t > 0.15:
		_activate()


func kick(point: Vector3, dir: Vector3, _power := 1.0) -> bool:
	if global_position.distance_to(point) > 0.9:
		return false
	var d := Vector3(dir.x, 0, dir.z).normalized()
	linear_velocity = d * 11.0 + Vector3.UP * 4.5
	angular_velocity = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
	sleeping = false
	if not _active:
		_activate()
	get_tree().call_group("crowd", "on_event", "vandal", {"pos": global_position, "kind": "grenade", "amount": 1.0})
	return true


func _activate() -> void:
	if _active:
		return
	_active = true
	cloud = GasCloud.new()
	cloud.crowd = crowd
	cloud.host = self
	get_tree().current_scene.add_child(cloud)
	cloud.global_position = Vector3(global_position.x, 0.0, global_position.z)
	_vent = Fx.smoke(Color(0.95, 0.96, 0.92, 0.7), 18, 2.2, 0.35, false, 0.7, 2.4)
	add_child(_vent)
	_vent.local_coords = false
	get_tree().call_group("crowd", "on_event", "gas_land", {"pos": global_position})


func _physics_process(delta: float) -> void:
	_t += delta
	if not _active and (_t > 2.2 or (_t > 0.5 and linear_velocity.length() < 0.8)):
		_activate()
	if _t > 50.0:
		queue_free()
