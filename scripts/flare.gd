class_name Flare
extends RigidBody3D
## Fumigène à main : tube rouge, flamme magenta aveuglante, épaisse fumée rouge qui dérive,
## lueur vacillante. Tenu (gelé, suit la main) ou lancé (physique), il brûle ~50 s.

signal burnt_out

const LEN := 0.30
const R := 0.019
var burn_time := 50.0
var lit := false
var spent := false
var held := true
var age := 0.0
var by_player := false
var cast_shadows := false

var _flame: GPUParticles3D
var _sparks: GPUParticles3D
var _smoke: GPUParticles3D
var _core: MeshInstance3D
var _light: OmniLight3D
var _loop: AudioStreamPlayer3D
var _tip: Node3D
var _cap: MeshInstance3D
var _tube: MeshInstance3D
var _seed := 0.0
var _land_sound := 0.0


func _ready() -> void:
	_seed = randf() * 100.0
	add_to_group("flares")
	mass = 0.3
	collision_layer = 0 if held else 64
	collision_mask = 0 if held else (1 | 32)
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 2
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce = 0.2
	physics_material_override = pm
	angular_damp = 1.5
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = R + 0.004
	cap.height = LEN
	cs.shape = cap
	add_child(cs)
	# tube
	var tube := CylinderMesh.new()
	tube.top_radius = R
	tube.bottom_radius = R
	tube.height = LEN * 0.78
	tube.radial_segments = 16
	_tube = MeshInstance3D.new()
	_tube.mesh = tube
	_tube.material_override = Props.flare_label_material()
	_tube.position.y = -LEN * 0.11
	add_child(_tube)
	var grip := CylinderMesh.new()
	grip.top_radius = R * 1.08
	grip.bottom_radius = R * 1.08
	grip.height = LEN * 0.22
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.08, 0.08, 0.09)
	gm.roughness = 0.7
	var g := MeshInstance3D.new()
	g.mesh = grip
	g.material_override = gm
	g.position.y = -LEN * 0.39
	add_child(g)
	_cap = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = R * 1.12
	cm.bottom_radius = R * 1.12
	cm.height = 0.035
	_cap.mesh = cm
	var capm := StandardMaterial3D.new()
	capm.albedo_color = Color(0.12, 0.12, 0.13)
	capm.roughness = 0.5
	_cap.material_override = capm
	_cap.position.y = LEN * 0.5 - 0.015
	add_child(_cap)
	_tip = Node3D.new()
	_tip.position.y = LEN * 0.5
	add_child(_tip)
	_core = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.013
	sm.height = 0.04
	_core.mesh = sm
	var coremat := StandardMaterial3D.new()
	coremat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	coremat.albedo_color = Color(1.0, 0.35, 0.42) * 3.2
	_core.material_override = coremat
	_core.position.y = 0.02
	_core.visible = false
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tip.add_child(_core)


func _build_fx() -> void:
	_flame = Fx.fire(0.09, 26, Vector3(0.008, 0.005, 0.008), 0.7)
	_flame.lifetime = 0.25
	var fpm := _flame.process_material as ParticleProcessMaterial
	fpm.initial_velocity_min = 1.0
	fpm.initial_velocity_max = 2.0
	fpm.color_ramp = Fx.ramp([Color(1, 1, 1, 0), Color(1, 0.9, 0.95, 1), Color(1, 0.35, 0.45, 0.8), Color(0.8, 0.1, 0.15, 0)], [0.0, 0.1, 0.5, 1.0])
	(_flame.draw_pass_1 as QuadMesh).material = Fx.flame_material(Color(1.0, 0.6, 0.75))
	_tip.add_child(_flame)
	_sparks = Fx.embers(30, Vector3(0.01, 0.01, 0.01), Color(1.0, 0.5, 0.45), 1.4)
	_sparks.lifetime = 0.6
	var spm := _sparks.process_material as ParticleProcessMaterial
	spm.spread = 60.0
	spm.gravity = Vector3(0, -2.0, 0)
	_tip.add_child(_sparks)
	_smoke = Fx.smoke(Color(0.85, 0.1, 0.12, 0.6), 70, 6.5, 0.32, false, 1.0, 9.0)
	var smm := _smoke.process_material as ParticleProcessMaterial
	smm.initial_velocity_min = 0.8
	smm.initial_velocity_max = 1.6
	smm.gravity = Vector3(0.45, 0.18, 0.15)
	smm.color_ramp = Fx.ramp([Color(0.95, 0.15, 0.15, 0.0), Color(0.9, 0.12, 0.14, 0.65), Color(0.78, 0.2, 0.24, 0.45), Color(0.62, 0.32, 0.36, 0.0)], [0.0, 0.06, 0.45, 1.0])
	_tip.add_child(_smoke)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.25, 0.22)
	_light.light_energy = 0.0
	_light.omni_range = 9.0
	_light.omni_attenuation = 1.3
	_light.shadow_enabled = cast_shadows
	_light.position.y = 0.08
	_tip.add_child(_light)
	_loop = AudioStreamPlayer3D.new()
	_loop.stream = AudioLib.stream("flare_loop", true)
	_loop.volume_db = -9.0
	_loop.unit_size = 5.0
	_tip.add_child(_loop)


func ignite() -> void:
	if lit or spent:
		return
	lit = true
	age = 0.0
	_cap.visible = false
	_build_fx()
	_core.visible = true
	_loop.play()
	AudioLib.play_at(self, "flare_ignite", _tip.global_position, -2.0, 6.0)
	get_tree().call_group("crowd", "on_event", "flare_lit", {"pos": global_position, "node": self, "player": by_player})


## Tenu en main : la position est imposée chaque image
func hold(xf: Transform3D) -> void:
	if not held:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = true
		held = true
	collision_layer = 0     # tenu en main : ne doit rien pousser (ni le porteur)
	collision_mask = 0
	global_transform = xf


func release(vel: Vector3, spin := Vector3.ZERO) -> void:
	held = false
	collision_layer = 64
	collision_mask = 1 | 32
	freeze = false
	linear_velocity = vel
	angular_velocity = spin


func tip_world() -> Vector3:
	return _tip.global_position


func _enter_tree() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = held


func _physics_process(delta: float) -> void:
	if not lit:
		return
	age += delta
	var t := Time.get_ticks_msec() / 1000.0
	var life := clampf(1.0 - age / burn_time, 0.0, 1.0)
	var k := clampf(age / 0.4, 0.0, 1.0) * (1.0 if life > 0.06 else life / 0.06)
	_light.light_energy = 3.2 * k * Fx.flicker(t * 1.6, _seed)
	_core.scale = Vector3.ONE * (0.6 + 0.4 * k * Fx.flicker(t * 2.0, _seed + 3.0))
	_flame.amount_ratio = k
	_sparks.amount_ratio = k
	_smoke.amount_ratio = clampf(k * 1.2, 0.0, 1.0)
	_loop.volume_db = linear_to_db(maxf(k, 0.001)) - 9.0
	if life <= 0.0 and not spent:
		spent = true
		lit = false
		_core.visible = false
		_flame.emitting = false
		_sparks.emitting = false
		_smoke.emitting = false
		_loop.stop()
		_light.light_energy = 0.0
		burnt_out.emit()
		var tm := StandardMaterial3D.new()
		tm.albedo_color = Color(0.1, 0.08, 0.08)
		tm.roughness = 1.0
		_tube.material_override = tm
		get_tree().create_timer(30.0).timeout.connect(func():
			if is_instance_valid(self) and not held:
				queue_free())
	# lancé dans une poubelle ouverte : il l'enflamme
	if not held and lit and linear_velocity.y < 0.5:
		for b in get_tree().get_nodes_in_group("bins"):
			if b.try_accept(self):
				break
	# petit bruit à l'atterrissage
	if not held and get_contact_count() > 0 and linear_velocity.length() > 2.0 and t - _land_sound > 0.2:
		_land_sound = t
		AudioLib.play_at(self, "sfx:stone_thud", global_position, -12.0, 5.0, randf_range(1.3, 1.6))
