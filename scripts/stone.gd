class_name Stone
extends RigidBody3D
## Pierre lancée : maillage de roche irrégulier, collision convexe, dégâts aux vitres.

static var _mesh_cache := {}
static var _mat: StandardMaterial3D

var thrower: Node3D
var _prev_vel := Vector3.ZERO
var _hist: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _last_sound := 0.0
var _age := 0.0


static func make_mesh(seed_: int) -> ArrayMesh:
	if _mesh_cache.has(seed_):
		return _mesh_cache[seed_]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 14
	sm.rings = 9
	var arrays := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var sx := rng.randf_range(0.8, 1.15)
	var sy := rng.randf_range(0.6, 0.9)
	var sz := rng.randf_range(0.75, 1.1)
	var off := rng.randf() * 100.0
	for i in verts.size():
		var v := verts[i].normalized()
		var n := sin(v.x * 5.1 + off) * cos(v.y * 4.3 + off * 0.7) * 0.5 + sin(v.z * 6.7 + off * 1.3) * 0.5
		var k := 0.5 * (1.0 + 0.22 * n) * (1.0 + 0.1 * sin(v.x * 11.0 + v.y * 9.0 + off))
		verts[i] = Vector3(v.x * sx, v.y * sy, v.z * sz) * k
	arrays[Mesh.ARRAY_VERTEX] = verts
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.generate_normals()
	st.generate_tangents()
	var mesh := st.commit()
	_mesh_cache[seed_] = mesh
	return mesh


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_texture = load("res://assets/busstop/rock_a.png")
		_mat.normal_enabled = true
		_mat.normal_texture = load("res://assets/busstop/rock_n.png")
		_mat.normal_scale = 1.3
		_mat.roughness = 0.92
		_mat.uv1_triplanar = true
		_mat.uv1_scale = Vector3(7, 7, 7)
	return _mat


func setup(seed_: int, radius: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = make_mesh(seed_)
	mi.material_override = material()
	mi.scale = Vector3.ONE * radius * 2.0
	add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := make_mesh(seed_).create_convex_shape(true, true)
	cs.shape = shape
	cs.scale = Vector3.ONE * radius * 2.0
	add_child(cs)
	mass = 0.45
	collision_layer = 8
	collision_mask = 1
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.8
	pm.bounce = 0.28
	physics_material_override = pm
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE   # la pierre suit la trajectoire affichée
	linear_damp = 0.0
	angular_damp = 0.3
	body_entered.connect(_on_body)
	add_to_group("stones")


func _physics_process(delta: float) -> void:
	_hist.pop_front()
	_hist.append(linear_velocity)
	_prev_vel = Vector3.ZERO
	for v in _hist:  # vitesse la plus forte des 3 dernières images (avant le choc)
		if v.length() > _prev_vel.length():
			_prev_vel = v
	_age += delta


func _on_body(body: Node) -> void:
	var speed := _prev_vel.length()
	if body.has_meta("glass"):
		(body.get_meta("glass") as GlassPane).stone_hit(global_position, speed, _prev_vel.normalized())
		return
	if body is Npc and speed > 3.0 and _age < 3.0:
		(body as Npc).on_stone_hit(_prev_vel)
	elif body is Cop and speed > 3.0 and _age < 4.0:
		(body as Cop).on_hit("stone", _prev_vel.normalized(), clampf(speed / 14.0, 0.4, 1.3), thrower if is_instance_valid(thrower) else null)
	var now := Time.get_ticks_msec() / 1000.0
	if speed > 2.0 and now - _last_sound > 0.12:
		_last_sound = now
		var a := AudioStreamPlayer3D.new()
		a.stream = Sfx.get_stream(&"stone_thud")
		a.volume_db = clampf(-16.0 + speed * 1.2, -16.0, 2.0)
		a.pitch_scale = randf_range(0.85, 1.2)
		a.unit_size = 8.0
		get_tree().current_scene.add_child(a)
		a.global_position = global_position
		a.play()
		a.finished.connect(a.queue_free)
