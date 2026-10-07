class_name Firecracker
extends RigidBody3D
## Pétard lancé : mèche qui crépite (étincelles, sifflement), rebonds, puis explosion — éclair, claquement,
## fumée, onde de choc sur les objets légers, vitres fêlées, foule et policiers qui réagissent.
## size : 1 petit (claquement sec), 2 moyen (détonation, secoue les poubelles, fait craquer les vitres).

const FUSE_TIME := [0.0, 2.6, 3.4]
const REACH := [0.0, 14.0, 30.0]       # rayon d'effet sur la foule (m)

var size := 1
var fuse := 2.6
var lit := true
var by_player := false
var thrower: Node3D
var in_hand := false                    # tenu : pas de physique, géré par l'outil

var _age := 0.0
var _gone := false
var _vis: Node3D
var _embers: GPUParticles3D
var _glow: OmniLight3D
var _hiss: AudioStreamPlayer3D
var _tip_n: Node3D
var _seed := 0.0
var _last_snd := 0.0


static func make(sz: int, by_pl: bool, who: Node3D = null) -> Firecracker:
	var f := Firecracker.new()
	f.size = sz
	f.fuse = FUSE_TIME[clampi(sz, 1, 2)]
	f.by_player = by_pl
	f.thrower = who
	return f


func _ready() -> void:
	_seed = randf() * 40.0
	var big := size >= 2
	collision_layer = 8
	collision_mask = 1 | 16 | 32 | 64
	contact_monitor = true
	max_contacts_reported = 3
	continuous_cd = true
	mass = 0.07 if big else 0.03
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.8
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce = 0.32
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.011 if big else 0.0065
	cap.height = 0.075 if big else 0.042
	cs.shape = cap
	add_child(cs)
	_vis = Props.petard(size)
	add_child(_vis)
	_tip_n = Node3D.new()
	_tip_n.position = _vis.get_meta("tip", Vector3(0, 0.04, 0))
	add_child(_tip_n)
	if lit:
		_light_fx()


## Allume la mèche (étincelles + sifflement + petite lueur)
func _light_fx() -> void:
	if _embers != null:
		return
	_embers = Fx.embers(14, Vector3(0.002, 0.002, 0.002), Color(0.8, 0.5, 0.25), 0.9)
	_embers.lifetime = 0.5
	var pmat := _embers.process_material as ParticleProcessMaterial
	pmat.spread = 70.0
	pmat.initial_velocity_min = 0.6
	pmat.initial_velocity_max = 2.2
	pmat.gravity = Vector3(0, -3.0, 0)
	_tip_n.add_child(_embers)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.62, 0.25)
	_glow.omni_range = 1.4
	_glow.light_energy = 0.3
	_tip_n.add_child(_glow)
	_hiss = AudioStreamPlayer3D.new()
	_hiss.stream = Sfx.get_stream(&"fuse")
	_hiss.bus = &"Effets"
	_hiss.volume_db = -14.0
	_hiss.unit_size = 2.5
	add_child(_hiss)
	_hiss.play(maxf(0.0, 3.6 - fuse - 0.1) if fuse < 3.4 else 0.0)
	if is_inside_tree():
		get_tree().call_group("crowd", "on_event", "petard_lit", {"pos": global_position, "size": size, "player": by_player})


func ignite() -> void:
	lit = true
	_light_fx()


func _physics_process(delta: float) -> void:
	_age += delta
	if _gone or in_hand:
		return
	if lit:
		fuse -= delta
		if _glow:
			_glow.light_energy = 0.15 + 0.15 * Fx.flicker(_age * 3.0, _seed)
		# la mèche raccourcit : le tube reste intact, seules les braises le montrent
		if fuse <= 0.0:
			explode()
			return
	if _age > 30.0:
		queue_free()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# claquements de rebond
	if state.get_contact_count() > 0 and state.linear_velocity.length() > 1.6 and _age - _last_snd > 0.12:
		_last_snd = _age
		AudioLib.play_at(self, "sfx:stone_thud", global_position, -22.0, 3.0, randf_range(1.9, 2.5))


## Explosion à la position courante (ou en main : `at` fourni)
func explode(at := Vector3.INF) -> void:
	if _gone:
		return
	_gone = true
	var big := size >= 2
	var scene := get_tree().current_scene
	var pos := (global_position if at == Vector3.INF else at) + Vector3(0, 0.025, 0)
	# --- son : claquement, écho de façades
	AudioLib.play_at(self, "sfx:petard_m" if big else "sfx:petard_s", pos, 5.0 if big else 1.0, 20.0 if big else 10.0, randf_range(0.95, 1.05))
	# --- éclair : lueur brève + halo doux (sprite orienté vers la caméra)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.82, 0.55)
	flash.light_energy = 4.0 if big else 1.6
	flash.omni_range = 7.0 if big else 3.5
	flash.shadow_enabled = false
	scene.add_child(flash)
	flash.global_position = pos + Vector3.UP * 0.1
	var tw := flash.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.2 if big else 0.1)
	tw.tween_callback(flash.queue_free)
	var ball := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	ball.mesh = qm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bm.albedo_texture = _halo_tex()
	bm.albedo_color = Color(1.0, 0.72, 0.38, 0.6)
	bm.no_depth_test = false
	ball.material_override = bm
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(ball)
	ball.global_position = pos + Vector3.UP * 0.05
	var r := 0.9 if big else 0.4
	ball.scale = Vector3.ONE * r * 0.35
	var tb := ball.create_tween().set_parallel(true)
	tb.tween_property(ball, "scale", Vector3.ONE * r, 0.1)
	tb.tween_property(bm, "albedo_color:a", 0.0, 0.16)
	tb.chain().tween_callback(ball.queue_free)
	# --- étincelles + fumée
	var sp := Fx.embers(36 if big else 16, Vector3(0.01, 0.01, 0.01), Color(1.0, 0.7, 0.35), 1.0)
	sp.one_shot = true
	sp.explosiveness = 1.0
	sp.lifetime = 0.7
	var spm := sp.process_material as ParticleProcessMaterial
	spm.spread = 180.0
	spm.initial_velocity_min = 2.0
	spm.initial_velocity_max = 8.0 if big else 4.5
	spm.gravity = Vector3(0, -9.0, 0)
	spm.damping_min = 0.5
	spm.damping_max = 1.5
	scene.add_child(sp)
	sp.global_position = pos
	sp.emitting = true
	var sk := Fx.smoke(Color(0.62, 0.6, 0.58, 0.5 if big else 0.34), 14 if big else 7, 2.2 if big else 1.4, 0.7 if big else 0.4, true, 0.5, 3.0)
	sk.one_shot = true
	sk.explosiveness = 0.95
	scene.add_child(sk)
	sk.global_position = pos
	sk.emitting = true
	for n in [sp, sk]:
		var host: Node = n
		get_tree().create_timer(3.2).timeout.connect(func():
			if is_instance_valid(host):
				host.queue_free())
	# --- marque de brûlure
	_scorch(scene, pos)
	# --- effets physiques et événements
	_shockwave(pos, big)
	var ev := {"pos": pos, "size": size, "player": by_player, "who": thrower}
	get_tree().call_group("crowd", "on_event", "petard", ev)
	get_tree().call_group("crowd", "on_event", "petard_boom", ev)
	queue_free()


func _scorch(scene: Node, pos: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.2, pos + Vector3.DOWN * 0.5, 1)
	var r := space.intersect_ray(q)
	if r.is_empty():
		return
	var d := MeshInstance3D.new()
	var qm := QuadMesh.new()
	var s := 0.55 if size >= 2 else 0.3
	qm.size = Vector2(s, s)
	d.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.04, 0.035, 0.03, 0.55)
	m.albedo_texture = _scorch_tex()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	d.material_override = m
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(d)
	var n: Vector3 = r["normal"]
	d.global_position = (r["position"] as Vector3) + n * 0.006
	d.global_basis = Basis(Quaternion(Vector3.BACK, n)) * Basis(Vector3.BACK, randf() * TAU)
	var tw := d.create_tween()
	tw.tween_interval(40.0)
	tw.tween_property(m, "albedo_color:a", 0.0, 6.0)
	tw.tween_callback(d.queue_free)


static var _stex: Texture2D
static var _htex: Texture2D


static func _halo_tex() -> Texture2D:
	if _htex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 0.9, 0.7, 0.55), Color(1, 0.6, 0.3, 0.12), Color(1, 0.5, 0.2, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_htex = t
	return _htex


static func _scorch_tex() -> Texture2D:
	if _stex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_stex = t
	return _stex


## Onde de choc : objets légers repoussés, vitres fêlées, personnage proche secoué
func _shockwave(pos: Vector3, big: bool) -> void:
	var reach := 3.4 if big else 1.7
	var space := get_world_3d().direct_space_state
	var qp := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = reach
	qp.shape = sph
	qp.transform = Transform3D(Basis.IDENTITY, pos)
	qp.collision_mask = 4 | 8 | 32 | 64
	qp.exclude = [get_rid()]
	for h in space.intersect_shape(qp, 48):
		var c: Object = h["collider"]
		if c is RigidBody3D:
			var rb := c as RigidBody3D
			if rb.freeze:
				continue
			var d := rb.global_position - pos
			var k := clampf(1.0 - d.length() / reach, 0.0, 1.0)
			var dir := (d + Vector3.UP * 0.5).normalized()
			rb.apply_central_impulse(dir * k * (7.0 if big else 3.0) * minf(rb.mass, 4.0))
			rb.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * k * minf(rb.mass, 2.0))
	for n in get_tree().get_nodes_in_group("glass"):
		var gp := n as GlassPane
		if gp != null and gp.alive():
			var dist := gp.contains(pos, 1.2 if big else 0.55, Vector2(0.05, 0.05))
			if dist >= 0.0:
				gp.hit(pos, (48.0 if big else 16.0) * (1.0 - dist * 0.6), (gp.global_position - pos).normalized())
	for p in get_tree().get_nodes_in_group("player"):
		var pl := p as Player
		if pl:
			var dd := pl.global_position + Vector3.UP * 0.9 - pos
			var lim := 4.5 if big else 1.6
			if dd.length() < lim:
				pl.on_blast(dd.length() / lim, pos, size)
