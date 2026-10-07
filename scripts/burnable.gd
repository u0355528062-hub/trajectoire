class_name Burnable
extends RigidBody3D
## Déchet inflammable : boule de journal, carton, planche. Peut brûler, être ramassé
## par un PNJ et jeté dans une poubelle (il nourrit alors le feu).

var kind := "box"
var fuel := 0.5
var lit := false
var burn := 0.0
var burn_time := 20.0
var held := false
var in_bin: Node = null
var reserved_by: Node = null
var size := Vector3.ONE
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _fire: GPUParticles3D
var _smoke: GPUParticles3D
var _light: OmniLight3D
var _crackle: AudioStreamPlayer3D
var _last_snd := 0.0
var _seed := 0.0
var _age := 0.0
var _dying := false


static func make(k: String) -> Burnable:
	var b := Burnable.new()
	b.kind = k
	return b


func _ready() -> void:
	_seed = randf() * 50.0
	collision_layer = 0 if held else 64
	collision_mask = 0 if held else (1 | 32 | 64)
	contact_monitor = true
	max_contacts_reported = 3
	continuous_cd = true
	add_to_group("burnables")
	add_to_group("kickable")
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.12
	physics_material_override = pm
	angular_damp = 1.0
	# pas de frein « par défaut » du projet : la trajectoire suit l'aperçu en pointillés
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	_mesh = MeshInstance3D.new()
	var cs := CollisionShape3D.new()
	match kind:
		"paper":
			_mesh.mesh = Props.paper_ball_mesh()
			_mat = (Props.paper_material() as StandardMaterial3D).duplicate()
			var sp := SphereShape3D.new()
			sp.radius = 0.06
			cs.shape = sp
			mass = 0.08
			fuel = 0.15
			burn_time = 9.0
			size = Vector3(0.13, 0.13, 0.13)
		"plank":
			var bm := BoxMesh.new()
			bm.size = Vector3(0.86, 0.026, 0.11)
			_mesh.mesh = bm
			_mat = (Props.wood() as StandardMaterial3D).duplicate()
			var bs := BoxShape3D.new()
			bs.size = bm.size
			cs.shape = bs
			mass = 1.1
			fuel = 0.4
			burn_time = 30.0
			size = bm.size
		_:
			var bm := BoxMesh.new()
			bm.size = Vector3(0.38, 0.27, 0.30)
			_mesh.mesh = bm
			_mat = (Props.box_material() as StandardMaterial3D).duplicate()
			var bs := BoxShape3D.new()
			bs.size = bm.size
			cs.shape = bs
			mass = 0.5
			fuel = 0.5
			burn_time = 24.0
			size = bm.size
	_mesh.material_override = _mat
	add_child(_mesh)
	add_child(cs)
	body_entered.connect(_on_body)


func _enter_tree() -> void:
	if held:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true


func ignite() -> void:
	if lit or _dying:
		return
	lit = true
	var w := clampf(maxf(size.x, size.z), 0.1, 0.6)
	_fire = Fx.fire(0.16 + w * 0.5, 14 + int(w * 30.0), Vector3(size.x * 0.35, 0.02, size.z * 0.35), 0.7 + w * 0.6)
	add_child(_fire)
	_fire.top_level = false
	_smoke = Fx.smoke(Color(0.2, 0.19, 0.18, 0.4), 16, 4.0, 0.25 + w * 0.4, true, 0.8, 4.0)
	add_child(_smoke)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.22)
	_light.omni_range = 3.0 + w * 4.0
	_light.light_energy = 0.0
	_light.position.y = 0.2
	add_child(_light)
	_crackle = AudioStreamPlayer3D.new()
	_crackle.stream = AudioLib.stream("fire_loop", true)
	_crackle.volume_db = -22.0 + w * 12.0
	_crackle.unit_size = 3.0
	_crackle.pitch_scale = 1.2
	add_child(_crackle)
	_crackle.play(randf() * 6.0)


func set_held(on: bool) -> void:
	held = on
	if on:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = 64
		collision_mask = 1 | 32 | 64
		freeze = false


func _physics_process(delta: float) -> void:
	_age += delta
	if lit:
		burn += delta / burn_time
		var t := Time.get_ticks_msec() / 1000.0
		var life := clampf(1.0 - burn, 0.0, 1.0)
		var k := clampf(burn * 8.0, 0.0, 1.0) * clampf(life * 3.0, 0.0, 1.0)
		if _fire:
			_fire.amount_ratio = k
			_smoke.amount_ratio = clampf(0.3 + k, 0.0, 1.0)
			_light.light_energy = 1.4 * k * Fx.flicker(t, _seed)
			_crackle.volume_db = linear_to_db(maxf(k, 0.001)) - 16.0
		_mat.albedo_color = Color(1, 1, 1).lerp(Color(0.12, 0.1, 0.09), clampf(burn * 1.4, 0.0, 1.0))
		if burn >= 1.0:
			_finish()
	if held or in_bin != null or _dying:
		return
	# tombé dans une poubelle ouverte ?
	if linear_velocity.y < 0.5:
		for b in get_tree().get_nodes_in_group("bins"):
			if b.try_accept(self):
				return
	# ménage : un déchet éteint ne reste pas éternellement
	if _age > 240.0 and not lit and reserved_by == null:
		_finish()


func _finish() -> void:
	if _dying:
		return
	_dying = true
	lit = false
	if _fire:
		_fire.emitting = false
		_light.light_energy = 0.0
		_crackle.stop()
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", Vector3(0.6, 0.1, 0.6), 2.5)
	tw.tween_interval(2.0)
	tw.tween_callback(queue_free)


func kick(point: Vector3, dir: Vector3) -> bool:
	if held or in_bin != null:
		return false
	if global_position.distance_to(point) > 0.55 + maxf(size.x, size.z) * 0.5:
		return false
	apply_central_impulse((dir + Vector3.UP * 0.35).normalized() * mass * 6.0)
	apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * mass * 0.4)
	return true


func _on_body(_b: Node) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var sp := linear_velocity.length()
	if sp > 1.2 and now - _last_snd > 0.15:
		_last_snd = now
		var snd := "wood_land" if kind == "plank" else ("cardboard_land" if kind == "box" else "toss")
		AudioLib.play_at(self, snd, global_position, clampf(-20.0 + sp * 3.0, -20.0, -4.0), 5.0, randf_range(0.9, 1.1))
