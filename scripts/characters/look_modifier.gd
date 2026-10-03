class_name LookModifier
extends SkeletonModifier3D
## Oriente le cou, la tête et les yeux d'un personnage vers une cible,
## par-dessus l'animation en cours, avec des limites anatomiques et un
## lissage pour un mouvement naturel.

var target: Node3D
var enabled_look := true
var max_yaw := deg_to_rad(65.0)
var max_pitch := deg_to_rad(30.0)
var eye_max := deg_to_rad(22.0)
## Décalage additionnel (en radians) appliqué au regard, ex. regarder ailleurs.
var gaze_offset := Vector2.ZERO

var _w := 0.0
var _dir_smooth := Vector3.ZERO
var _neck := -1
var _head := -1
var _spine := -1
var _eyes: Array[int] = []
var _fwd_head := Vector3.FORWARD
var _fwd_eye: Array[Vector3] = []
var _fwd_spine := Vector3.FORWARD
var _up_spine := Vector3.UP
var _ready_done := false


func _setup() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	_neck = sk.find_bone("Bip01 Neck")
	_head = sk.find_bone("Bip01 Head")
	_spine = sk.find_bone("Bip01 Spine2")
	_eyes.clear()
	_fwd_eye.clear()
	# L'avatar regarde vers +Z dans son propre repère (pose de repos).
	var model_fwd := Vector3(0, 0, 1)
	if _head >= 0:
		_fwd_head = (sk.get_bone_global_rest(_head).basis.inverse() * model_fwd).normalized()
	if _spine >= 0:
		var b := sk.get_bone_global_rest(_spine).basis.inverse()
		_fwd_spine = (b * model_fwd).normalized()
		_up_spine = (b * Vector3.UP).normalized()
	for n in ["Bip01 LEye", "Bip01 REye"]:
		var i := sk.find_bone(n)
		if i >= 0:
			_eyes.append(i)
			_fwd_eye.append((sk.get_bone_global_rest(i).basis.inverse() * model_fwd).normalized())
	_ready_done = _head >= 0 and _neck >= 0 and _spine >= 0


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if not _ready_done:
		_setup()
		if not _ready_done:
			return
	var dt := get_process_delta_time()
	var want := 1.0 if (enabled_look and target != null and is_instance_valid(target)) else 0.0
	var target_pos := Vector3.ZERO
	var spine_g := sk.get_bone_global_pose(_spine)
	var body_fwd := (spine_g.basis * _fwd_spine).normalized()
	var body_up := (spine_g.basis * _up_spine).normalized()
	var head_g := sk.get_bone_global_pose(_head)
	if want > 0.0:
		target_pos = sk.global_transform.affine_inverse() * target.global_position
		var to := target_pos - head_g.origin
		if to.length() < 0.05 or to.length() > 6.0:
			want = 0.0
	_w = move_toward(_w, want, dt * 2.2)
	if _w <= 0.001:
		_dir_smooth = Vector3.ZERO
		return

	# Direction voulue, limitée par rapport au buste.
	var desired := (target_pos - head_g.origin).normalized() if want > 0.0 else body_fwd
	var right := body_fwd.cross(body_up).normalized()
	var yaw := atan2(desired.dot(right), desired.dot(body_fwd))
	var pitch := asin(clampf(desired.dot(body_up), -1.0, 1.0))
	yaw = clampf(yaw + gaze_offset.x, -max_yaw, max_yaw)
	pitch = clampf(pitch + gaze_offset.y, -max_pitch, max_pitch)
	var limited := (body_fwd * cos(yaw) + right * sin(yaw)) * cos(pitch) + body_up * sin(pitch)
	limited = limited.normalized()
	if _dir_smooth == Vector3.ZERO:
		_dir_smooth = (head_g.basis * _fwd_head).normalized()
	_dir_smooth = _dir_smooth.slerp(limited, clampf(dt * 6.0, 0.0, 1.0)).normalized()

	_rotate_bone_towards(sk, _neck, _fwd_head, _dir_smooth, 0.4 * _w)
	_rotate_bone_towards(sk, _head, _fwd_head, _dir_smooth, 1.0 * _w)

	# Les yeux suivent précisément la cible (dans leurs limites).
	if want > 0.0:
		for k in _eyes.size():
			var e := _eyes[k]
			var eg := sk.get_bone_global_pose(e)
			var cur := (eg.basis * _fwd_eye[k]).normalized()
			var to_t := (target_pos - eg.origin).normalized()
			var ang := cur.angle_to(to_t)
			if ang > eye_max:
				to_t = cur.slerp(to_t, eye_max / ang)
			_rotate_bone_towards(sk, e, _fwd_eye[k], to_t, _w)


func _rotate_bone_towards(sk: Skeleton3D, bone: int, fwd_local: Vector3, dir: Vector3, weight: float) -> void:
	var g := sk.get_bone_global_pose(bone)
	var cur := (g.basis * fwd_local).normalized()
	if cur.is_equal_approx(dir) or weight <= 0.0:
		return
	var axis := cur.cross(dir)
	if axis.length_squared() < 1e-10:
		return
	var q := Quaternion(axis.normalized(), cur.angle_to(dir) * weight)
	var new_basis := Basis(q) * g.basis
	var parent := sk.get_bone_parent(bone)
	var parent_basis := sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
	var local := (parent_basis.inverse() * new_basis).orthonormalized()
	sk.set_bone_pose_rotation(bone, local.get_rotation_quaternion())
