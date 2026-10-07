class_name Burnable
extends RigidBody3D
## Déchet inflammable : boule de papier, journal roulé, carton, planche. Il se ramasse (E), se dépose dans
## une poubelle ou par terre, et nourrit les feux : poubelles (TrashBin) et feux au sol (FloorFire).
## Allumé hors d'un foyer il brûle seul, puis forme un feu au sol dès qu'il est posé.

const KINDS := {
	"paper": {"fuel": 7.0, "time": 9.0, "mass": 0.08, "bin": 0.15},
	"news": {"fuel": 13.0, "time": 15.0, "mass": 0.15, "bin": 0.3},
	"box": {"fuel": 30.0, "time": 26.0, "mass": 0.5, "bin": 0.5},
	"plank": {"fuel": 48.0, "time": 38.0, "mass": 1.1, "bin": 0.45},
}

var kind := "box"
var fuel_s := 20.0           # secondes de combustion que l'objet apporte à un feu
var bin_fuel := 0.5          # combustible apporté à une poubelle
var burn := 0.0              # 0 intact -> 1 consumé
var burn_time := 20.0
var lit := false
var held := false
var in_bin: Node = null
var fire: Node = null        # FloorFire qui le consume
var reserved_by: Node = null
var size := Vector3.ONE
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _flame: GPUParticles3D
var _smoke: GPUParticles3D
var _light: OmniLight3D
var _crackle: AudioStreamPlayer3D
var _last_snd := 0.0
var _seed := 0.0
var _age := 0.0
var _dying := false
var _base_scale := Vector3.ONE
var _rest_t := 0.0


static func make(k: String) -> Burnable:
	var b := Burnable.new()
	b.kind = k
	return b


## Nom affiché (« le carton »...) pour les invites
static func label_of(k: String) -> String:
	match k:
		"paper":
			return "la boule de papier"
		"news":
			return "le journal"
		"plank":
			return "la planche"
	return "le carton"


## Ramassable à la main : posé, éteint, pas déjà dans un foyer ni porté
func can_pickup() -> bool:
	return not held and not lit and fire == null and in_bin == null and not _dying and (reserved_by == null or not is_instance_valid(reserved_by))


## Ramassable par `who` (qui l'a éventuellement déjà réservé)
func can_pickup_for(who: Node) -> bool:
	return not held and not lit and fire == null and in_bin == null and not _dying and (reserved_by == null or reserved_by == who or not is_instance_valid(reserved_by))


## Chute / vol court jusqu'à `dest` (objet lâché par une main) puis `then`. L'objet reste figé pendant le trajet.
func fly_to(dest: Vector3, dur := 0.25, then := Callable()) -> void:
	set_held(true)
	var p0 := global_position
	var spin := Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
	var r0 := rotation
	var tw := create_tween()
	tw.tween_method(func(u: float):
		var e := u * u
		global_position = Vector3(lerpf(p0.x, dest.x, u), lerpf(p0.y, dest.y, e), lerpf(p0.z, dest.z, u))
		rotation = r0 + spin * u * 0.5, 0.0, 1.0, dur)
	if then.is_valid():
		tw.tween_callback(then)


func _ready() -> void:
	_seed = randf() * 50.0
	var info: Dictionary = KINDS.get(kind, KINDS["box"])
	fuel_s = info["fuel"]
	burn_time = info["time"]
	mass = info["mass"]
	bin_fuel = info["bin"]
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
			size = Vector3(0.13, 0.13, 0.13)
		"news":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.034
			cm.bottom_radius = 0.026
			cm.height = 0.32
			cm.radial_segments = 12
			_mesh.mesh = cm
			_mesh.rotation.z = PI / 2.0
			_mat = (Props.paper_material() as StandardMaterial3D).duplicate()
			_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			var cap := CapsuleShape3D.new()
			cap.radius = 0.032
			cap.height = 0.32
			cs.shape = cap
			cs.rotation.z = PI / 2.0
			size = Vector3(0.32, 0.07, 0.07)
		"plank":
			var bm := BoxMesh.new()
			bm.size = Vector3(0.86, 0.026, 0.11)
			_mesh.mesh = bm
			_mat = (Props.wood() as StandardMaterial3D).duplicate()
			var bs := BoxShape3D.new()
			bs.size = bm.size
			cs.shape = bs
			size = bm.size
		_:
			var bm := BoxMesh.new()
			bm.size = Vector3(0.38, 0.27, 0.30)
			_mesh.mesh = bm
			_mat = (Props.box_material() as StandardMaterial3D).duplicate()
			var bs := BoxShape3D.new()
			bs.size = bm.size
			cs.shape = bs
			size = bm.size
	_mesh.material_override = _mat
	add_child(_mesh)
	add_child(cs)
	body_entered.connect(_on_body)
	if lit:
		var was := lit
		lit = false
		if was:
			ignite()


func _enter_tree() -> void:
	if held:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = true


## Allume l'objet. Dans une poubelle ou un feu au sol, c'est l'hôte qui gère flammes et combustion.
func ignite() -> void:
	if lit or _dying:
		return
	lit = true
	if in_bin != null or fire != null:
		return
	_start_flame()


func _start_flame() -> void:
	if _flame != null or not is_inside_tree():
		return
	var w := clampf(maxf(size.x, size.z), 0.1, 0.6)
	_flame = Fx.fire(0.16 + w * 0.5, 14 + int(w * 30.0), Vector3(size.x * 0.35, 0.02, size.z * 0.35), 0.7 + w * 0.6)
	add_child(_flame)
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


func _stop_flame() -> void:
	for n in [_flame, _smoke, _light, _crackle]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_flame = null
	_smoke = null
	_light = null
	_crackle = null


## L'objet est consumé par un foyer (feu au sol) : plus de flammes propres.
func join_fire(f: Node) -> void:
	fire = f
	_stop_flame()
	lit = true
	set_held(true)           # figé sur place, sans collision
	remove_from_group("kickable")


func set_held(on: bool) -> void:
	held = on
	if on:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = true
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = 64
		collision_mask = 1 | 32 | 64
		freeze = false


## Aspect de l'objet selon sa combustion (0..1) : noircit et s'affaisse.
func set_burn(b: float) -> void:
	burn = clampf(b, 0.0, 1.0)
	if _mat:
		_mat.albedo_color = Color(1, 1, 1).lerp(Color(0.09, 0.075, 0.07), clampf(burn * 1.5, 0.0, 1.0))
	if _mesh:
		var k := 1.0 - 0.55 * burn
		_mesh.scale = Vector3(1.0 - 0.1 * burn, k, 1.0 - 0.1 * burn)
		_mesh.position.y = -(1.0 - k) * size.y * 0.5


func _physics_process(delta: float) -> void:
	_age += delta
	if lit and fire == null and in_bin == null and not _dying:
		var life := clampf(1.0 - burn, 0.0, 1.0)
		burn += delta / burn_time
		set_burn(burn)
		var t := Time.get_ticks_msec() / 1000.0
		if _flame:
			var k := clampf(burn * 8.0, 0.0, 1.0) * clampf(life * 3.0, 0.0, 1.0)
			_flame.amount_ratio = k
			_smoke.amount_ratio = clampf(0.3 + k, 0.0, 1.0)
			_light.light_energy = 1.4 * k * Fx.flicker(t, _seed)
			_crackle.volume_db = linear_to_db(maxf(k, 0.001)) - 16.0
		if burn >= 1.0:
			_finish()
			return
		# posé au sol : il forme un feu avec ses voisins
		if not held and linear_velocity.length() < 0.7:
			_rest_t += delta
			if _rest_t > 0.35 and global_position.y < 0.45 + size.y:
				FloorFire.merge_or_create(self)
		else:
			_rest_t = 0.0
	if held or in_bin != null or fire != null or _dying:
		return
	# tombé dans une poubelle ouverte ?
	if linear_velocity.y < 0.5:
		for b in get_tree().get_nodes_in_group("bins"):
			if b.try_accept(self):
				return
	# ménage : un déchet éteint ne reste pas éternellement
	if _age > 300.0 and not lit and reserved_by == null:
		_finish()


func _finish() -> void:
	if _dying:
		return
	_dying = true
	lit = false
	_stop_flame()
	Fx.shrink_and_free(self, 1.8, Vector3(0.4, 0.05, 0.4))


func kick(point: Vector3, dir: Vector3, _power := 1.0) -> bool:
	if held or in_bin != null or fire != null:
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
