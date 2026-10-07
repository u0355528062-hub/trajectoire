class_name Fx
extends RefCounted
## Effets partagés : flammes (atlas animé), fumées, braises, lueur vacillante.

const PROPS := "res://assets/props/"
static var _mats := {}


static func ramp(cols: Array, offsets: Array = []) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cc := PackedColorArray()
	for i in cols.size():
		offs.append(float(offsets[i]) if offsets.size() == cols.size() else float(i) / (cols.size() - 1))
		cc.append(cols[i])
	g.offsets = offs
	g.colors = cc
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func curve(vals: Array, max_v := 1.0) -> CurveTexture:
	var c := Curve.new()
	c.max_value = max_v
	for i in vals.size():
		c.add_point(Vector2(float(i) / (vals.size() - 1), vals[i]))
	var t := CurveTexture.new()
	t.curve = c
	return t


static func flame_material(tint := Color(1, 1, 1)) -> StandardMaterial3D:
	var key := "flame" + str(tint)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
		m.particles_anim_h_frames = 4
		m.particles_anim_v_frames = 4
		m.particles_anim_loop = true
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = load(PROPS + "flame_atlas.png")
		m.albedo_color = Color(1.2 * tint.r, 0.92 * tint.g, 0.72 * tint.b, 1.0)
		m.disable_receive_shadows = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


static func smoke_material(shaded: bool) -> StandardMaterial3D:
	var key := "smoke" + str(shaded)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if shaded else BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = load(PROPS + "smoke.png")
		m.particles_anim_h_frames = 2
		m.particles_anim_v_frames = 2
		m.particles_anim_loop = false
		m.disable_receive_shadows = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 1.0
		m.metallic_specular = 0.0
		_mats[key] = m
	return _mats[key]


static func spark_material(tint: Color, hdr := 3.0) -> StandardMaterial3D:
	var key := "spark" + str(tint) + str(hdr)
	if not _mats.has(key):
		_mats[key] = FireworkShell.spark_material(tint, hdr)
	return _mats[key]


## Flammes : `size` = largeur d'une langue de feu (m), émission dans une boîte `extent`.
static func fire(size: float, amount: int, extent: Vector3, rise := 1.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.75 * rise
	p.local_coords = false
	p.randomness = 0.4
	p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 5, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extent
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 10.0
	pm.initial_velocity_min = 0.35 * rise
	pm.initial_velocity_max = 0.9 * rise
	pm.gravity = Vector3(0, 1.8 * rise, 0)
	pm.damping_min = 0.3
	pm.damping_max = 1.0
	pm.scale_min = 0.65
	pm.scale_max = 1.25
	pm.scale_curve = curve([0.45, 1.0, 0.8, 0.15])
	pm.angle_min = -12.0
	pm.angle_max = 12.0
	pm.anim_speed_min = 0.6
	pm.anim_speed_max = 1.2
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 1.0
	pm.color_ramp = ramp([Color(1, 1, 1, 0.0), Color(1, 0.95, 0.88, 0.8), Color(1, 0.7, 0.5, 0.6), Color(0.75, 0.25, 0.1, 0.0)], [0.0, 0.12, 0.55, 1.0])
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 1.6
	pm.turbulence_influence_min = 0.02
	pm.turbulence_influence_max = 0.08
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size * 1.35)
	q.center_offset = Vector3(0, size * 0.45, 0)
	q.material = flame_material()
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Fumée : `col` couleur (alpha = densité max), `life` durée (s), `size` taille initiale.
static func smoke(col: Color, amount: int, life: float, size: float, shaded := true, rise := 1.0, grow := 3.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.randomness = 0.3
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.visibility_aabb = AABB(Vector3(-12, -2, -12), Vector3(24, 24, 24))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = size * 0.25
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 14.0
	pm.initial_velocity_min = 0.5 * rise
	pm.initial_velocity_max = 1.1 * rise
	pm.gravity = Vector3(0.32, 0.42 * rise, 0.1)
	pm.damping_min = 0.15
	pm.damping_max = 0.4
	pm.scale_min = 0.75
	pm.scale_max = 1.15
	pm.scale_curve = curve([0.3, 0.9 * grow / 3.0 + 0.1, grow * 0.75, grow], grow)
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -18.0
	pm.angular_velocity_max = 18.0
	pm.anim_speed_min = 0.0
	pm.anim_speed_max = 0.0
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 0.999
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	pm.turbulence_influence_min = 0.03
	pm.turbulence_influence_max = 0.09
	var c0 := Color(col.r, col.g, col.b, 0.0)
	var c1 := Color(col.r, col.g, col.b, col.a)
	var c2 := Color(lerpf(col.r, 0.55, 0.4), lerpf(col.g, 0.55, 0.4), lerpf(col.b, 0.58, 0.4), col.a * 0.55)
	var c3 := Color(c2.r, c2.g, c2.b, 0.0)
	pm.color_ramp = ramp([c0, c1, c2, c3], [0.0, 0.08, 0.5, 1.0])
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = smoke_material(shaded)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Braises / étincelles qui montent en tourbillonnant
static func embers(amount: int, extent: Vector3, tint := Color(1.0, 0.55, 0.2), speed := 1.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.8
	p.local_coords = false
	p.randomness = 0.6
	p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 9, 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extent
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.8 * speed
	pm.initial_velocity_max = 2.6 * speed
	pm.gravity = Vector3(0.25, 0.5, 0.0)
	pm.damping_min = 0.4
	pm.damping_max = 1.2
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	pm.scale_curve = curve([1.0, 0.7, 0.0])
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.0
	pm.turbulence_noise_scale = 1.2
	pm.turbulence_influence_min = 0.1
	pm.turbulence_influence_max = 0.3
	pm.color_ramp = ramp([Color(1, 0.9, 0.6, 1), Color(1, 0.5, 0.15, 1), Color(0.6, 0.12, 0.02, 0)])
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.025)
	q.material = spark_material(tint, 4.0)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Vacillement naturel d'une flamme (0.6 .. 1.25 environ)
static func flicker(t: float, seed_: float) -> float:
	return 0.92 + 0.12 * sin(t * 11.3 + seed_) + 0.08 * sin(t * 23.7 + seed_ * 2.1) + 0.06 * sin(t * 5.1 + seed_ * 0.7) + 0.05 * sin(t * 37.0 + seed_ * 3.3)


## Flash + étincelles + fumée à la bouche d'un mortier
static func muzzle(scene: Node, pos: Vector3, axis: Vector3) -> void:
	var root := Node3D.new()
	scene.add_child(root)
	root.global_position = pos
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 0.7
	light.omni_range = 6.0
	root.add_child(light)
	var tw := root.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.12)
	var sp := GPUParticles3D.new()
	sp.amount = 22
	sp.lifetime = 0.7
	sp.one_shot = true
	sp.explosiveness = 1.0
	sp.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = axis.normalized()
	pm.spread = 22.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 13.0
	pm.gravity = Vector3(0, -7, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	pm.scale_curve = curve([1.0, 0.0])
	pm.color_ramp = ramp([Color(1, 0.95, 0.7, 1), Color(1, 0.5, 0.1, 0.9), Color(0.5, 0.1, 0, 0)])
	sp.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	q.material = spark_material(Color(1, 0.8, 0.5), 1.3)
	sp.draw_pass_1 = q
	root.add_child(sp)
	sp.emitting = true
	var sm := smoke(Color(0.6, 0.58, 0.56, 0.22), 18, 2.6, 0.4, false, 0.6, 2.5)
	sm.one_shot = true
	sm.explosiveness = 0.9
	(sm.process_material as ParticleProcessMaterial).direction = axis.normalized()
	(sm.process_material as ParticleProcessMaterial).initial_velocity_max = 3.0
	root.add_child(sm)
	sm.emitting = true
	root.get_tree().create_timer(4.0).timeout.connect(root.queue_free)
