class_name Barrier
extends RigidBody3D
## Barrière métallique (type Vauban) : on peut la pousser, la renverser d'un coup de pied (ou de plusieurs),
## la traverser quand elle est à terre, et la remettre debout (E). Les PNJ la contournent tant qu'elle est debout.

const W := 2.0
const H := 1.06
const MASS := 17.0

var crowd: Crowd
var lift_label := "la barrière"
var _model: MeshInstance3D
var _righting := false
var _down := false
var _nav_in := false
var _last_hit := 0.0
var _last_fall := 0.0
var _settle_t := 0.0
var _state_t := 0.0

static var _mesh: ArrayMesh
static var _mat: StandardMaterial3D


static func model_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var parts: Array = []
	var r := 0.0155
	# traverses haute et basse
	for y in [H - 0.02, 0.17]:
		parts.append([MeshKit.tube(PackedVector3Array([Vector3(-W * 0.5 + 0.03, y, 0), Vector3(W * 0.5 - 0.03, y, 0)]), r, 8, true), Transform3D.IDENTITY])
	# montants d'extrémité, légèrement débordants
	for sx in [-1.0, 1.0]:
		var x: float = sx * (W * 0.5 - 0.03)
		parts.append([MeshKit.tube(PackedVector3Array([Vector3(x, 0.03, 0), Vector3(x, H, 0)]), r * 1.1, 8, true), Transform3D.IDENTITY])
		# pied : tube posé au sol, perpendiculaire à la barrière, relié au montant
		parts.append([MeshKit.tube(PackedVector3Array([Vector3(x, 0.025, -0.3), Vector3(x, 0.025, 0.3)]), 0.0165, 8, true), Transform3D.IDENTITY])
		# petite jambe oblique entre le pied et la traverse basse
		parts.append([MeshKit.tube(PackedVector3Array([Vector3(x, 0.03, 0.0), Vector3(x, 0.17, 0.0)]), r, 8, true), Transform3D.IDENTITY])
	# barreaux verticaux
	var n := 15
	for i in n:
		var x2 := -W * 0.5 + 0.1 + float(i) * (W - 0.2) / float(n - 1)
		parts.append([MeshKit.tube(PackedVector3Array([Vector3(x2, 0.17, 0), Vector3(x2, H - 0.02, 0)]), 0.0075, 6, false), Transform3D.IDENTITY])
	# crochets d'assemblage (petits anneaux aux extrémités hautes)
	for sx in [-1.0, 1.0]:
		var x3: float = sx * (W * 0.5 + 0.005)
		parts.append([MeshKit.tube(PackedVector3Array([Vector3(x3, H - 0.1, 0), Vector3(x3 + sx * 0.04, H - 0.06, 0), Vector3(x3 + sx * 0.06, H - 0.1, 0)]), 0.008, 6, true), Transform3D.IDENTITY])
	_mesh = MeshKit.merge(parts)
	return _mesh


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color(0.7, 0.72, 0.75)
		_mat.metallic = 0.85
		_mat.roughness = 0.38
		_mat.metallic_specular = 0.6
	return _mat


func _ready() -> void:
	add_to_group("kickable")
	add_to_group("liftables")
	add_to_group("barriers")
	collision_layer = 32
	collision_mask = 1 | 32 | 64
	mass = MASS
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	linear_damp = 0.9
	angular_damp = 1.2
	var pm := PhysicsMaterial.new()
	pm.friction = 0.85
	pm.bounce = 0.1
	physics_material_override = pm
	_model = MeshInstance3D.new()
	_model.mesh = model_mesh()
	_model.material_override = material()
	add_child(_model)
	# panneau plein (collision) + pieds
	var panel := CollisionShape3D.new()
	var pb := BoxShape3D.new()
	pb.size = Vector3(W, H - 0.1, 0.05)
	panel.shape = pb
	panel.position = Vector3(0, 0.1 + (H - 0.1) * 0.5, 0)
	add_child(panel)
	for sx in [-1.0, 1.0]:
		var foot := CollisionShape3D.new()
		var fb := BoxShape3D.new()
		fb.size = Vector3(0.05, 0.05, 0.62)
		foot.shape = fb
		foot.position = Vector3(sx * (W * 0.5 - 0.03), 0.025, 0)
		add_child(foot)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.45, 0)
	body_entered.connect(_on_body)
	if crowd != null:
		_register_nav()


func is_down() -> bool:
	return _down


func _register_nav() -> void:
	if crowd == null or _nav_in:
		return
	crowd.add_obstacle(self, Vector2(W * 0.5 + 0.1, 0.22), Vector2.ZERO, false, true)
	_nav_in = true


func _unregister_nav() -> void:
	if crowd == null or not _nav_in:
		return
	crowd.remove_obstacle(self)
	_nav_in = false


func _physics_process(delta: float) -> void:
	_state_t += delta
	# debout ou à terre ? (axe vertical du modèle par rapport à la verticale)
	var up_dot := global_basis.y.dot(Vector3.UP)
	var settled := linear_velocity.length() < 0.35 and angular_velocity.length() < 0.6
	if settled:
		_settle_t += delta
	else:
		_settle_t = 0.0
	if not _down and up_dot < 0.6 and _settle_t > 0.3:
		_down = true
		_unregister_nav()
		if crowd:
			crowd.nav_dirty()
	elif _down and up_dot > 0.93 and _settle_t > 0.3 and not _righting:
		_down = false
		_register_nav()
		if crowd:
			crowd.nav_dirty()


func _on_body(body: Node) -> void:
	var sp := linear_velocity.length()
	var now := Time.get_ticks_msec() / 1000.0
	if sp > 1.0 and now - _last_hit > 0.12:
		_last_hit = now
		AudioLib.play_at(self, "barrier_hit", global_position + Vector3.UP * 0.4, clampf(-14.0 + sp * 2.5, -14.0, 0.0), 8.0, randf_range(0.9, 1.15))
	if angular_velocity.length() > 2.5 and body is StaticBody3D and now - _last_fall > 0.6 and global_basis.y.dot(Vector3.UP) < 0.8:
		_last_fall = now
		AudioLib.play_at(self, "barrier_fall", global_position + Vector3.UP * 0.3, -2.0, 10.0, randf_range(0.92, 1.08))
		get_tree().call_group("crowd", "on_event", "barrier_fall", {"pos": global_position})


## Coup de pied (joueur ou PNJ) : plus la puissance est grande, plus elle bascule facilement
func kick(point: Vector3, dir: Vector3, power := 1.0) -> bool:
	if _righting:
		return false
	var l := to_local(point)
	if absf(l.x) > W * 0.5 + 0.35 or absf(l.z) > 0.7 or l.y > H + 0.3:
		return false
	var d := Vector3(dir.x, 0, dir.z).normalized()
	var imp := d * MASS * 2.4 * power
	apply_impulse(imp, point - global_position)
	AudioLib.play_at(self, "barrier_hit", point, -3.0, 8.0, randf_range(0.9, 1.1))
	return true


## Pas de course contre la barrière : elle glisse un peu
func push(dir: Vector3, speed: float) -> void:
	var d := Vector3(dir.x, 0, dir.z)
	if d.length() < 0.01:
		return
	apply_central_impulse(d.normalized() * MASS * clampf(speed, 0.0, 6.0) * 0.18)


## La remettre debout devant celui qui la relève (joueur ou PNJ), face à `yaw`
func right_up(yaw: float, duration := 0.9) -> void:
	if _righting or not _down:
		return
	_righting = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	var q0 := global_transform.basis.get_rotation_quaternion()
	var p0 := global_position
	var q1 := Quaternion(Vector3.UP, yaw)
	var tw := create_tween()
	tw.tween_method(func(u: float):
		var e := u * u * (3.0 - 2.0 * u)
		global_transform = Transform3D(Basis(q0.slerp(q1, e)), p0.lerp(Vector3(p0.x, 0.0, p0.z), e) + Vector3(0, sin(PI * e) * 0.18, 0)), 0.0, 1.0, duration)
	tw.tween_callback(func():
		_righting = false
		_down = false
		freeze = false
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		_settle_t = 0.0
		_register_nav()
		if crowd:
			crowd.nav_dirty()
		AudioLib.play_at(self, "barrier_up", global_position + Vector3.UP * 0.3, -4.0, 8.0, 1.0))
