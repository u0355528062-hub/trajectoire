class_name FireworkShell
extends Node3D
## Obus d'artifice : montée avec traînée d'étincelles, puis bouquet.

const GRAVITY := 9.8

var velocity := Vector3.ZERO
var fuse := 3.0
var age := 0.0
var color := Color.WHITE
var style := 0
var _sparks: GPUParticles3D
var _done := false

static var _soft_tex: GradientTexture2D


static func soft_texture() -> GradientTexture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
		_soft_tex = GradientTexture2D.new()
		_soft_tex.gradient = g
		_soft_tex.fill = GradientTexture2D.FILL_RADIAL
		_soft_tex.fill_from = Vector2(0.5, 0.5)
		_soft_tex.fill_to = Vector2(1.0, 0.5)
		_soft_tex.width = 64
		_soft_tex.height = 64
	return _soft_tex


static func spark_material(tint := Color.WHITE, hdr := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_texture()
	m.albedo_color = Color(tint.r * hdr, tint.g * hdr, tint.b * hdr, 1.0)
	m.disable_receive_shadows = true
	return m


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	fuse = rng.randf_range(2.9, 3.4)
	var palette := [
		Color(1.0, 0.25, 0.2), Color(1.0, 0.75, 0.2), Color(0.3, 0.6, 1.0),
		Color(0.35, 1.0, 0.45), Color(0.9, 0.3, 1.0), Color(1.0, 0.55, 0.15), Color(0.4, 1.0, 0.95)]
	color = palette[rng.randi() % palette.size()]
	style = rng.randi() % 3

	# corps de l'obus
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.026
	cm.bottom_radius = 0.026
	cm.height = 0.07
	body.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.15, 0.2, 0.55)
	bm.roughness = 0.6
	body.material_override = bm
	add_child(body)

	# traînée d'étincelles dorées
	_sparks = GPUParticles3D.new()
	_sparks.amount = 140
	_sparks.lifetime = 0.9
	_sparks.local_coords = false
	_sparks.draw_order = GPUParticles3D.DRAW_ORDER_LIFETIME
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 28.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, -6.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.scale_curve = _curve([1.0, 0.0])
	pm.color_ramp = _ramp([Color(1, 0.95, 0.7, 1), Color(1, 0.55, 0.12, 0.9), Color(0.6, 0.15, 0.02, 0)])
	_sparks.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	q.material = spark_material(Color(1, 0.8, 0.5), 2.5)
	_sparks.draw_pass_1 = q
	add_child(_sparks)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.3)
	light.light_energy = 2.0
	light.omni_range = 9.0
	add_child(light)

	var whistle := AudioStreamPlayer3D.new()
	whistle.stream = Sfx.get_stream(&"whistle")
	whistle.volume_db = -8.0
	whistle.unit_size = 25.0
	add_child(whistle)
	whistle.play()


func _physics_process(delta: float) -> void:
	if _done:
		return
	age += delta
	# propulseur : gravité réduite au début pour que les tirs obliques aillent loin
	var g := GRAVITY * (0.25 if age < 1.6 else 1.0)
	velocity.y -= g * delta
	velocity *= 1.0 - 0.12 * delta
	global_position += velocity * delta
	if age >= fuse or (age > 0.4 and global_position.y < 1.0):
		_burst()


func _curve(vals: Array) -> CurveTexture:
	var c := Curve.new()
	for i in vals.size():
		c.add_point(Vector2(float(i) / (vals.size() - 1), vals[i]))
	var t := CurveTexture.new()
	t.curve = c
	return t


func _ramp(cols: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cc := PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / (cols.size() - 1))
		cc.append(cols[i])
	g.offsets = offs
	g.colors = cc
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _burst() -> void:
	_done = true
	var scene := get_tree().current_scene
	var pos := global_position
	get_tree().call_group("crowd", "on_event", "burst", {"pos": pos})
	var root := Node3D.new()
	scene.add_child(root)
	root.global_position = pos

	var willow := style == 2
	var ring := style == 1
	var life := 3.4 if willow else 2.6
	var c := color
	var white_hot := Color(1, 1, 0.9, 1)

	var stars := GPUParticles3D.new()
	stars.amount = 520
	stars.lifetime = life
	stars.one_shot = true
	stars.explosiveness = 1.0
	stars.local_coords = false
	stars.draw_order = GPUParticles3D.DRAW_ORDER_LIFETIME
	stars.visibility_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	pm.emission_sphere_radius = 0.3
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 21.0 if not ring else 24.0
	pm.initial_velocity_max = 24.0
	pm.damping_min = 5.5 if not willow else 7.0
	pm.damping_max = 6.5 if not willow else 8.0
	pm.gravity = Vector3(0, -3.0 if not willow else -7.0, 0)
	pm.scale_min = 1.0
	pm.scale_max = 1.6
	pm.scale_curve = _curve([1.0, 0.8, 0.0])
	if willow:
		pm.color_ramp = _ramp([white_hot, Color(1.0, 0.7, 0.25, 1), Color(0.9, 0.35, 0.05, 0.7), Color(0.4, 0.1, 0.0, 0)])
	else:
		pm.color_ramp = _ramp([white_hot, c, c.darkened(0.3), Color(c.r, c.g, c.b, 0)])
	if ring:
		# anneau : on aplatit la sphère en la faisant partir dans un plan incliné
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3(0, 1, 0)
		pm.emission_ring_height = 0.1
		pm.emission_ring_radius = 0.6
		pm.emission_ring_inner_radius = 0.5
		pm.direction = Vector3(1, 0, 0)
		pm.spread = 180.0
		pm.flatness = 0.9
	# traînées secondaires derrière chaque étoile
	pm.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_CONSTANT
	pm.sub_emitter_frequency = 14.0
	stars.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	q.material = spark_material(Color.WHITE, 2.2)
	stars.draw_pass_1 = q

	var trail := GPUParticles3D.new()
	trail.name = "Trail"
	trail.amount = 6000
	trail.lifetime = 0.8 if not willow else 1.4
	trail.local_coords = false
	trail.emitting = false
	trail.visibility_aabb = stars.visibility_aabb
	var tm := ParticleProcessMaterial.new()
	tm.gravity = Vector3(0, -2.0, 0)
	tm.initial_velocity_min = 0.0
	tm.initial_velocity_max = 0.6
	tm.direction = Vector3(0, -1, 0)
	tm.spread = 180.0
	tm.scale_min = 0.4
	tm.scale_max = 0.7
	tm.scale_curve = _curve([1.0, 0.0])
	tm.color_ramp = _ramp([c.lightened(0.4), c, Color(c.r, c.g, c.b, 0)]) if not willow else \
			_ramp([Color(1, 0.8, 0.4, 1), Color(1, 0.5, 0.1, 0.8), Color(0.5, 0.1, 0, 0)])
	trail.process_material = tm
	var tq := QuadMesh.new()
	tq.size = Vector2(0.5, 0.5)
	tq.material = spark_material(Color.WHITE, 1.6)
	trail.draw_pass_1 = tq
	root.add_child(trail)
	root.add_child(stars)
	stars.sub_emitter = stars.get_path_to(trail)
	stars.emitting = true

	# flash central
	var flash := GPUParticles3D.new()
	flash.amount = 1
	flash.lifetime = 0.5
	flash.one_shot = true
	flash.explosiveness = 1.0
	var fm := ParticleProcessMaterial.new()
	fm.gravity = Vector3.ZERO
	fm.scale_min = 7.0
	fm.scale_max = 7.0
	fm.scale_curve = _curve([0.3, 1.0, 0.0])
	fm.color_ramp = _ramp([c.lightened(0.5), Color(c.r, c.g, c.b, 0.3), Color(c.r, c.g, c.b, 0)])
	flash.process_material = fm
	var fq := QuadMesh.new()
	fq.size = Vector2(1, 1)
	fq.material = spark_material(c.lightened(0.5), 3.0)
	flash.draw_pass_1 = fq
	root.add_child(flash)
	flash.emitting = true

	# lumière du bouquet : éclaire le sol et le joueur
	var light := OmniLight3D.new()
	light.light_color = c.lightened(0.25)
	light.light_energy = 14.0
	light.omni_range = 220.0
	light.omni_attenuation = 1.4
	root.add_child(light)
	var tw := root.create_tween()
	tw.tween_property(light, "light_energy", 0.0, life * 0.9).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# son (retardé selon la distance)
	var cam := get_viewport().get_camera_3d()
	var dist := 60.0
	if cam:
		dist = cam.global_position.distance_to(pos)
	var boom := AudioStreamPlayer3D.new()
	boom.stream = Sfx.get_stream(&"boom")
	boom.unit_size = 70.0
	boom.volume_db = 2.0
	boom.max_distance = 0.0
	root.add_child(boom)
	get_tree().create_timer(minf(dist / 343.0, 1.2)).timeout.connect(boom.play)

	get_tree().create_timer(life + 2.5).timeout.connect(root.queue_free)
	queue_free()
