class_name Humanoid
extends Node3D
## Personnage procédural articulé : marche le long d'un chemin, s'assoit,
## respire, cligne des yeux, suit le joueur du regard et « parle ».
## Le modèle regarde vers -Z (convention Godot).

signal arrived

enum Pose { STAND, WALK, SIT, TYPING }

var look: Dictionary = {}
var height_scale := 1.0
var build := 1.0

var pose: Pose = Pose.STAND
var walk_speed := 1.15
var look_target: Node3D
var talk_timer := 0.0

var _path: Array[Vector3] = []
var _after_path_pose: Pose = Pose.STAND
var _after_path_facing := Vector3.ZERO
var _after_path_seat := 0.45
var _seat_height := 0.45
var _target_yaw := 0.0
var _phase := 0.0
var _t := 0.0
var _blink_timer := 2.0
var _blink := 0.0
var _rng := RandomNumberGenerator.new()

# Articulations
var pelvis: Node3D
var spine: Node3D
var neck: Node3D
var head: Node3D
var hip_l: Node3D
var hip_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var shoulder_l: Node3D
var shoulder_r: Node3D
var elbow_l: Node3D
var elbow_r: Node3D
var torso_mesh: MeshInstance3D
var mouth: MeshInstance3D
var eyes: Array[Node3D] = []

const HIP_Y := 0.93


func setup(look_data: Dictionary, seed_value: int = 0) -> void:
	look = look_data
	_rng.seed = seed_value if seed_value != 0 else randi()
	height_scale = float(look.get("height", 1.0))
	build = float(look.get("build", 1.0))
	walk_speed = 1.15 * lerpf(0.8, 1.0, clampf(height_scale, 0.6, 1.0))
	_blink_timer = _rng.randf_range(1.0, 4.0)
	_build_body()
	scale = Vector3.ONE * height_scale


# --- Construction du corps -----------------------------------------------------------

func _build_body() -> void:
	var skin := Art.skin_mat(int(look.get("skin", 0)))
	var top := Art.fabric_mat(look.get("top", Color(0.3, 0.4, 0.6)))
	var bottom := Art.fabric_mat(look.get("bottom", Color(0.2, 0.2, 0.25)))
	var hair := Art.hair_mat(look.get("hair_color", Color(0.2, 0.15, 0.1)))
	var b := build
	var child := height_scale < 0.8

	pelvis = _joint(self, Vector3(0, HIP_Y, 0))
	Art.add_mesh(pelvis, Art.rounded_box(Vector3(0.32 * b, 0.2, 0.2 * b), 0.08), bottom, Vector3(0, 0.02, 0))
	# Ceinture
	Art.add_mesh(pelvis, Art.rounded_box(Vector3(0.325 * b, 0.035, 0.205 * b), 0.015), Art.mat("black_plastic"), Vector3(0, 0.105, 0))

	spine = _joint(pelvis, Vector3(0, 0.1, 0))
	torso_mesh = Art.add_mesh(spine, Art.capsule(0.17 * b, 0.56), top, Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(1.05, 1.0, 0.66))
	# Épaules arrondies
	Art.add_mesh(spine, Art.capsule(0.075, 0.44 * b + 0.06), top, Vector3(0, 0.44, 0.005), Vector3(0, 0, 90), Vector3(1.0, 1.0, 0.9))
	# Col
	Art.add_mesh(spine, Art.torus(0.045, 0.07), top, Vector3(0, 0.515, 0), Vector3.ZERO, Vector3(1, 0.6, 1))

	neck = _joint(spine, Vector3(0, 0.52, 0))
	Art.add_mesh(neck, Art.cylinder(0.045, 0.052, 0.12, 20), skin, Vector3(0, 0.05, 0))

	head = _joint(neck, Vector3(0, 0.1, 0))
	if child:
		head.scale = Vector3.ONE * 1.32
	_build_head(skin, hair)

	shoulder_l = _joint(spine, Vector3(-0.2 * b - 0.02, 0.44, 0))
	shoulder_r = _joint(spine, Vector3(0.2 * b + 0.02, 0.44, 0))
	for s in [shoulder_l, shoulder_r]:
		Art.add_mesh(s, Art.capsule(0.055, 0.32), top, Vector3(0, -0.13, 0))
	elbow_l = _joint(shoulder_l, Vector3(0, -0.28, 0))
	elbow_r = _joint(shoulder_r, Vector3(0, -0.28, 0))
	for e in [elbow_l, elbow_r]:
		Art.add_mesh(e, Art.capsule(0.046, 0.26), top, Vector3(0, -0.1, 0))
		Art.add_mesh(e, Art.cylinder(0.036, 0.04, 0.05, 16), skin, Vector3(0, -0.225, 0))
		var hand := Art.add_mesh(e, Art.rounded_box(Vector3(0.075, 0.1, 0.03), 0.014), skin, Vector3(0, -0.29, 0))
		hand.rotation_degrees = Vector3(0, 90, 0)
		Art.add_mesh(e, Art.capsule(0.013, 0.07), skin, Vector3(0.0, -0.275, -0.032), Vector3(-30, 0, 0))

	hip_l = _joint(pelvis, Vector3(-0.09 * b, -0.02, 0))
	hip_r = _joint(pelvis, Vector3(0.09 * b, -0.02, 0))
	for h in [hip_l, hip_r]:
		Art.add_mesh(h, Art.capsule(0.078 * b, 0.48), bottom, Vector3(0, -0.21, 0))
	knee_l = _joint(hip_l, Vector3(0, -0.44, 0))
	knee_r = _joint(hip_r, Vector3(0, -0.44, 0))
	for k in [knee_l, knee_r]:
		Art.add_mesh(k, Art.capsule(0.06, 0.45), bottom, Vector3(0, -0.21, 0))
		Art.add_mesh(k, Art.rounded_box(Vector3(0.1, 0.075, 0.26), 0.03), Art.mat("shoe"), Vector3(0, -0.432, -0.055))
		Art.add_mesh(k, Art.rounded_box(Vector3(0.104, 0.018, 0.265), 0.006), Art.color_mat(Color(0.85, 0.84, 0.8), 0.7), Vector3(0, -0.466, -0.055))

	_target_yaw = rotation.y


func _build_head(skin: Material, hair: Material) -> void:
	Art.add_mesh(head, Art.sphere(0.105, 32), skin, Vector3(0, 0.115, 0), Vector3.ZERO, Vector3(0.9, 1.08, 1.0))
	# Mâchoire / menton
	Art.add_mesh(head, Art.sphere(0.08, 24), skin, Vector3(0, 0.055, -0.025), Vector3.ZERO, Vector3(0.95, 0.8, 1.0))
	# Nez
	Art.add_mesh(head, Art.capsule(0.015, 0.055), skin, Vector3(0, 0.1, -0.1), Vector3(-18, 0, 0))
	Art.add_mesh(head, Art.sphere(0.018, 12), skin, Vector3(0, 0.08, -0.108))
	# Oreilles
	for sx in [-1.0, 1.0]:
		Art.add_mesh(head, Art.sphere(0.026, 12), skin, Vector3(sx * 0.094, 0.11, 0.005), Vector3.ZERO, Vector3(0.45, 1.0, 0.75))
	# Yeux
	for sx in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(sx * 0.036, 0.128, -0.084)
		head.add_child(eye)
		Art.add_mesh(eye, Art.sphere(0.017, 16), Art.mat("eye_white"))
		Art.add_mesh(eye, Art.sphere(0.0095, 12), Art.mat("eye_iris"), Vector3(0, 0, -0.011))
		eyes.append(eye)
		# Sourcils
		Art.add_mesh(head, Art.rounded_box(Vector3(0.036, 0.0075, 0.012), 0.003), Art.hair_mat(look.get("hair_color", Color(0.2, 0.15, 0.1)).darkened(0.2)), Vector3(sx * 0.037, 0.158, -0.094), Vector3(0, 0, -sx * 6.0))
	mouth = Art.add_mesh(head, Art.rounded_box(Vector3(0.042, 0.009, 0.012), 0.004), Art.mat("lips"), Vector3(0, 0.058, -0.1))

	var style: String = look.get("hair", "short")
	if style != "bald":
		var cap := SphereMesh.new()
		cap.radius = 0.112
		cap.height = 0.112
		cap.is_hemisphere = true
		cap.radial_segments = 48
		cap.rings = 16
		Art.add_mesh(head, cap, hair, Vector3(0, 0.125, 0.008), Vector3(22, 0, 0), Vector3(0.96, 1.0, 1.04))
		Art.add_mesh(head, Art.sphere(0.1, 24), hair, Vector3(0, 0.1, 0.03), Vector3.ZERO, Vector3(0.98, 0.95, 0.85))
	else:
		Art.add_mesh(head, Art.sphere(0.1, 24), hair, Vector3(0, 0.085, 0.035), Vector3.ZERO, Vector3(0.97, 0.55, 0.8))
	match style:
		"long":
			Art.add_mesh(head, Art.capsule(0.1, 0.34), hair, Vector3(0, 0.0, 0.05), Vector3(8, 0, 0), Vector3(1.08, 1.0, 0.55))
		"bun":
			Art.add_mesh(head, Art.sphere(0.048, 16), hair, Vector3(0, 0.19, 0.085))
		"ponytail":
			Art.add_mesh(head, Art.sphere(0.03, 12), hair, Vector3(0, 0.15, 0.11))
			Art.add_mesh(head, Art.capsule(0.032, 0.22), hair, Vector3(0, 0.05, 0.135), Vector3(15, 0, 0))
	if look.get("beard", false):
		Art.add_mesh(head, Art.sphere(0.078, 20), hair, Vector3(0, 0.04, -0.035), Vector3.ZERO, Vector3(1.0, 0.68, 0.96))
		mouth.position = Vector3(0, 0.062, -0.112)
	if look.get("glasses", false):
		var frame := Art.mat("black_plastic")
		for sx in [-1.0, 1.0]:
			Art.add_mesh(head, Art.torus(0.019, 0.024), frame, Vector3(sx * 0.037, 0.128, -0.106), Vector3(90, 0, 0))
			Art.add_mesh(head, Art.cylinder(0.004, 0.004, 0.1, 6), frame, Vector3(sx * 0.07, 0.132, -0.055), Vector3(90, 0, 0))
		Art.add_mesh(head, Art.cylinder(0.004, 0.004, 0.026, 6), frame, Vector3(0, 0.132, -0.107), Vector3(0, 0, 90))


func _joint(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


# --- Contrôle ------------------------------------------------------------------------

## Fait marcher le personnage le long de `points`, puis adopte une pose finale.
func walk_path(points: Array[Vector3], final_pose: Pose = Pose.STAND, facing: Vector3 = Vector3.ZERO, seat_height: float = 0.45) -> void:
	_path = points.duplicate()
	_after_path_pose = final_pose
	_after_path_facing = facing
	_after_path_seat = seat_height
	if _path.is_empty():
		_finish_path()
	else:
		pose = Pose.WALK


func is_walking() -> bool:
	return pose == Pose.WALK


## Place instantanément le personnage assis.
func place_seated(pos: Vector3, facing: Vector3, seat_height: float, typing: bool = false) -> void:
	global_position = pos
	face(facing, true)
	_seat_height = seat_height
	pose = Pose.TYPING if typing else Pose.SIT
	_snap_pose()


func face(direction: Vector3, instant: bool = false) -> void:
	var d := Vector3(direction.x, 0, direction.z)
	if d.length_squared() < 0.0001:
		return
	_target_yaw = atan2(-d.x, -d.z)
	if instant:
		rotation.y = _target_yaw


func talk(duration: float = 2.5) -> void:
	talk_timer = maxf(talk_timer, duration)


func _finish_path() -> void:
	pose = _after_path_pose
	_seat_height = _after_path_seat
	if _after_path_facing != Vector3.ZERO:
		face(_after_path_facing)
	arrived.emit()


# --- Animation -----------------------------------------------------------------------

func _process(delta: float) -> void:
	if pelvis == null:
		return
	_t += delta
	if pose == Pose.WALK:
		_update_walk(delta)
	rotation.y = lerp_angle(rotation.y, _target_yaw, 1.0 - exp(-8.0 * delta))
	_animate(delta)


func _update_walk(delta: float) -> void:
	if _path.is_empty():
		_finish_path()
		return
	var target := _path[0]
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	var step := walk_speed * delta
	if dist <= step or dist < 0.01:
		global_position = Vector3(target.x, global_position.y, target.z)
		_path.remove_at(0)
		if _path.is_empty():
			_finish_path()
		return
	var dir := to / dist
	global_position += dir * step
	face(dir)
	_phase += delta * walk_speed * 5.6 / maxf(height_scale, 0.6)


func _animate(delta: float) -> void:
	var k := 1.0 - exp(-10.0 * delta)
	var breathe := sin(_t * 1.7) * 0.5 + 0.5

	var pelvis_pos := Vector3(0, HIP_Y, 0)
	var hip_a := 0.0
	var hip_b := 0.0
	var knee_a := 0.0
	var knee_b := 0.0
	var sh_a := 0.0
	var sh_b := 0.0
	var el_a := 0.12
	var el_b := 0.12
	var spine_x := 0.0
	var arm_out := 0.06

	match pose:
		Pose.STAND:
			pelvis_pos.y += sin(_t * 0.9) * 0.004
			pelvis_pos.x = sin(_t * 0.45) * 0.012
			spine_x = -0.02
		Pose.WALK:
			var s := sin(_phase)
			hip_a = s * 0.45
			hip_b = -s * 0.45
			knee_a = -maxf(0.0, -sin(_phase - 0.6)) * 0.85 - 0.05
			knee_b = -maxf(0.0, sin(_phase - 0.6)) * 0.85 - 0.05
			sh_a = -s * 0.32
			sh_b = s * 0.32
			el_a = 0.25 + maxf(0.0, -s) * 0.25
			el_b = 0.25 + maxf(0.0, s) * 0.25
			pelvis_pos.y = HIP_Y - 0.02 + absf(cos(_phase)) * 0.03
			spine_x = 0.05
		Pose.SIT, Pose.TYPING:
			var seat_local := _seat_height / maxf(height_scale, 0.01)
			pelvis_pos = Vector3(0, seat_local + 0.07, 0.1)
			hip_a = 1.5
			hip_b = 1.5
			knee_a = -1.45 if height_scale >= 0.8 or seat_local < 0.7 else -1.2
			knee_b = knee_a
			spine_x = -0.06
			if pose == Pose.TYPING:
				sh_a = 0.75 + sin(_t * 9.0) * 0.03
				sh_b = 0.75 + sin(_t * 8.0 + 1.0) * 0.03
				el_a = 0.85
				el_b = 0.85
				arm_out = 0.1
			else:
				sh_a = 0.4
				sh_b = 0.4
				el_a = 0.95
				el_b = 0.95
				arm_out = 0.12

	pelvis.position = pelvis.position.lerp(pelvis_pos, k)
	hip_l.rotation.x = lerpf(hip_l.rotation.x, hip_a, k)
	hip_r.rotation.x = lerpf(hip_r.rotation.x, hip_b, k)
	knee_l.rotation.x = lerpf(knee_l.rotation.x, knee_a, k)
	knee_r.rotation.x = lerpf(knee_r.rotation.x, knee_b, k)
	shoulder_l.rotation.x = lerpf(shoulder_l.rotation.x, sh_a, k)
	shoulder_r.rotation.x = lerpf(shoulder_r.rotation.x, sh_b, k)
	shoulder_l.rotation.z = lerpf(shoulder_l.rotation.z, -arm_out, k)
	shoulder_r.rotation.z = lerpf(shoulder_r.rotation.z, arm_out, k)
	elbow_l.rotation.x = lerpf(elbow_l.rotation.x, el_a, k)
	elbow_r.rotation.x = lerpf(elbow_r.rotation.x, el_b, k)
	spine.rotation.x = lerpf(spine.rotation.x, spine_x, k)
	torso_mesh.scale = Vector3(1.05 + breathe * 0.012, 1.0, 0.66 + breathe * 0.02)

	_animate_head(delta, k)


func _animate_head(delta: float, k: float) -> void:
	var yaw := 0.0
	var pitch := 0.0
	if pose == Pose.TYPING:
		pitch = 0.18
	if look_target and is_instance_valid(look_target) and pose != Pose.WALK:
		# Exprimé dans le repère du cou pour éviter la rétroaction de la rotation de la tête.
		var local := neck.global_transform.affine_inverse() * look_target.global_position
		var dist := local.length()
		if dist < 5.0 and local.z < 0.4:
			yaw = clampf(atan2(-local.x, -local.z), -1.0, 1.0)
			pitch = clampf(atan2(local.y - 0.1, Vector2(local.x, local.z).length()), -0.4, 0.4)
	if talk_timer > 0.0:
		talk_timer -= delta
		pitch += sin(_t * 5.0) * 0.03
		var open := absf(sin(_t * 13.0)) * 0.6 + absf(sin(_t * 7.3)) * 0.4
		mouth.scale = Vector3(1.0 - open * 0.15, 1.0 + open * 2.2, 1.0)
	else:
		mouth.scale = mouth.scale.lerp(Vector3.ONE, k)
	head.rotation.y = lerp_angle(head.rotation.y, yaw, 1.0 - exp(-5.0 * delta))
	head.rotation.x = lerpf(head.rotation.x, pitch, 1.0 - exp(-5.0 * delta))

	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 0.14
		_blink_timer = _rng.randf_range(2.0, 5.5)
	var eye_y := 1.0
	if _blink > 0.0:
		_blink -= delta
		eye_y = 0.1
	for e in eyes:
		e.scale.y = eye_y


func _snap_pose() -> void:
	for i in range(30):
		_animate(0.1)
	rotation.y = _target_yaw
