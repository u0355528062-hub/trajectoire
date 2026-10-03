class_name Character
extends Node3D
## Personnage réaliste (avatar Rocketbox) : animations capturées (marche,
## s'asseoir, se lever, attentes, gestes), déplacement le long d'un chemin,
## regard vers le joueur, clignements, lèvres synchronisées sur la voix,
## expressions faciales.
##
## Convention : le nœud Character regarde vers -Z (comme Godot) ; l'avatar
## importé regarde vers +Z, il est donc tourné de 180° à l'intérieur.

signal arrived
signal action_done(action: String)
signal speech_finished

enum State { IDLE, WALK, TURN, SIT_DOWN, SITTING, STAND_UP, LYING }

const ANIMS := {
	"idle": "idle_neutral_01", "idle_look": "idle_look_around_01", "idle_cough": "idle_cough_01",
	"wait": "idle_waiting_01", "walk": "walk_neutral_01", "walk_slow": "walk_slow_01",
	"sit_down": "sit_down_chair_01", "stand_up": "sit_stand_up_chair_01",
	"sit_idle": "sit_chair_idle_neutral_01", "sit_breathe": "sit_chair_breathe_01",
	"sit_cough": "sit_chair_idle_cough", "sit_look": "sit_chair_idle_look_around",
	"sit_touch": "sit_chair_idle_touch_face", "sit_think": "sit_chair_gestic_thoughtful",
	"sit_shrug": "sit_chair_gestic_shrug_01", "talk": "gestic_talk_neutral_01",
	"listen": "gestic_listen_neutral_01", "wave": "wave_01", "docs": "documents_check",
}
const GENDER_ONLY := {
	"f": {"walk_injured": "f_walk_injured", "type": "f_work_table", "work": "f_work_mid", "walk_bruised": "f_walk_slow_01"},
	"m": {"walk_bruised": "m_walk_bruised", "walk_injured": "m_walk_bruised", "type": "m_documents_check", "work": "m_documents_check"},
}
const ADULT_HIP := {"m": 0.895, "f": 0.919}

static var _libraries: Dictionary = {}

var avatar_id := ""
var gender := "m"
var model: Node3D
var skeleton: Skeleton3D
var head_mesh: MeshInstance3D
var anim: AnimationPlayer
var look: LookModifier
var voice: AudioStreamPlayer3D
var state: State = State.IDLE
var walk_style := "walk"
var cough := false
var look_target: Node3D:
	set(v):
		look_target = v
		if look:
			look.target = v

var _lib: AnimationLibrary
var _path: Array[Vector3] = []
var _after: Dictionary = {}
var _yaw_target := 0.0
var _seat_offset := 0.0
var _current := ""
var _rng := RandomNumberGenerator.new()
var _variant_timer := 8.0
var _blink_t := 2.0
var _blink := 0.0
var _talk_time := 0.0
var _talk_env: PackedFloat32Array = PackedFloat32Array()
var _talk_env_rate := 30.0
var _talk_clock := 0.0
var _expr: Dictionary = {}
var _expr_target: Dictionary = {}
var _expr_timer := 0.0
var _shape_idx: Dictionary = {}
var _lying_tween: Tween
var _speed_scale := 1.0
var _hip_scale := 1.0
var _free_yaw := true
var _head_att: BoneAttachment3D


func setup(id: String, gender_code: String, seed_value: int = 0) -> void:
	avatar_id = id
	gender = gender_code
	_rng.seed = seed_value if seed_value != 0 else hash(id)
	var ps: PackedScene = load("res://assets/characters/%s/%s.scn" % [id, id])
	model = ps.instantiate()
	model.rotation.y = PI
	add_child(model)
	skeleton = model.get_node("Skeleton3D")
	head_mesh = skeleton.get_node_or_null("Head")
	if head_mesh and head_mesh.mesh:
		for i in head_mesh.mesh.get_blend_shape_count():
			_shape_idx[head_mesh.mesh.get_blend_shape_name(i)] = i
	var hip := skeleton.get_bone_global_rest(skeleton.find_bone("Bip01")).origin.y
	_hip_scale = clampf(hip / ADULT_HIP[gender], 0.5, 1.2)

	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	model.add_child(anim)
	anim.root_node = NodePath("..")
	_lib = _library()
	anim.add_animation_library("", _lib)
	anim.animation_finished.connect(_on_anim_finished)
	anim.playback_default_blend_time = 0.25

	look = LookModifier.new()
	look.name = "Look"
	skeleton.add_child(look)
	look.target = look_target

	var head_att := BoneAttachment3D.new()
	head_att.bone_name = "Bip01 Head"
	skeleton.add_child(head_att)
	_head_att = head_att
	voice = AudioStreamPlayer3D.new()
	voice.bus = "Voice"
	voice.unit_size = 3.0
	voice.max_distance = 25.0
	voice.attenuation_filter_cutoff_hz = 12000.0
	head_att.add_child(voice)
	voice.finished.connect(_on_voice_finished)

	_blink_t = _rng.randf_range(1.0, 4.0)
	_play("idle", 0.0)
	_yaw_target = rotation.y


func _library() -> AnimationLibrary:
	var key := "%s_%.2f" % [gender, _hip_scale]
	if _libraries.has(key):
		return _libraries[key]
	var lib := AnimationLibrary.new()
	var names := {}
	for k in ANIMS.keys():
		names[k] = "%s_%s" % [gender, ANIMS[k]]
	names.merge(GENDER_ONLY[gender], true)
	for k in names.keys():
		var path := "res://assets/animations/%s.res" % names[k]
		if not ResourceLoader.exists(path):
			continue
		var a: Animation = load(path)
		if absf(_hip_scale - 1.0) > 0.04:
			a = _scaled(a)
		lib.add_animation(k, a)
	_libraries[key] = lib
	return lib


## Adapte la hauteur du bassin aux personnages plus petits (enfant).
func _scaled(src: Animation) -> Animation:
	var a: Animation = src.duplicate(true)
	for t in a.get_track_count():
		if a.track_get_type(t) == Animation.TYPE_POSITION_3D:
			for k in a.track_get_key_count(t):
				var v: Vector3 = a.track_get_key_value(t, k)
				a.track_set_key_value(t, k, v * _hip_scale)
	for m in ["root_start", "root_end"]:
		if a.has_meta(m):
			a.set_meta(m, a.get_meta(m) * _hip_scale)
	a.set_meta("speed", float(a.get_meta("speed", 0.0)) * _hip_scale)
	return a


func has_anim(n: String) -> bool:
	return _lib.has_animation(n)


func _play(n: String, blend: float = -1.0) -> void:
	if not _lib.has_animation(n):
		return
	_current = n
	anim.play(n, blend)


# --- Déplacements ---------------------------------------------------------------------

## Marche le long de `points` puis exécute `after` :
## {"do": "idle" | "sit" | "lie", "face": Vector3, "seat": float, "head": Vector3}
func walk_to(points: Array[Vector3], after: Dictionary = {}) -> void:
	if state in [State.SITTING, State.SIT_DOWN, State.LYING]:
		# Se lever d'abord, puis repartir.
		_after = {"then_walk": points, "after": after}
		stand_up()
		return
	_path = points.duplicate()
	_after = after
	if _path.is_empty():
		_arrive()
		return
	state = State.WALK
	var a: Animation = _lib.get_animation(walk_style) if _lib.has_animation(walk_style) else _lib.get_animation("walk")
	_play(walk_style if _lib.has_animation(walk_style) else "walk", 0.3)
	var spd := float(a.get_meta("speed", 1.0))
	_speed_scale = 1.0
	anim.speed_scale = 1.0
	_walk_speed = maxf(0.4, spd)


var _walk_speed := 1.0


func is_busy() -> bool:
	return state in [State.WALK, State.TURN, State.SIT_DOWN, State.STAND_UP]


## Point où se placer avant de s'asseoir pour finir sur `seat` (face à `facing`).
func sit_approach_point(seat: Vector3, facing: Vector3) -> Vector3:
	var a := _lib.get_animation("sit_down")
	var s: Vector3 = a.get_meta("root_start", Vector3.ZERO)
	var e: Vector3 = a.get_meta("root_end", Vector3.ZERO)
	var back := absf(e.z - s.z)
	var f := Vector3(facing.x, 0, facing.z).normalized()
	return seat + f * back


func face(direction: Vector3, instant: bool = false) -> void:
	if not _free_yaw:
		return
	var d := Vector3(direction.x, 0, direction.z)
	if d.length_squared() < 0.0001:
		return
	_yaw_target = atan2(-d.x, -d.z)
	if instant:
		rotation.y = _yaw_target


func _process(delta: float) -> void:
	if model == null:
		return
	match state:
		State.WALK:
			_update_walk(delta)
		State.TURN:
			if absf(wrapf(_yaw_target - rotation.y, -PI, PI)) < 0.04:
				rotation.y = _yaw_target
				_after_turn()
		State.SITTING:
			_update_variants(delta, true)
		State.IDLE:
			_update_variants(delta, false)
	if _free_yaw:
		rotation.y = lerp_angle(rotation.y, _yaw_target, 1.0 - exp(-7.0 * delta))
	_update_face(delta)


func _update_walk(delta: float) -> void:
	if _path.is_empty():
		_arrive()
		return
	var target := _path[0]
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	var step := _walk_speed * delta
	if dist <= step or dist < 0.02:
		global_position = Vector3(target.x, global_position.y, target.z)
		_path.remove_at(0)
		if _path.is_empty():
			_arrive()
		return
	var dir := to / dist
	# Ralentit dans les virages serrés pour éviter de glisser.
	var turn := absf(wrapf(atan2(-dir.x, -dir.z) - rotation.y, -PI, PI))
	var k := clampf(1.0 - turn / PI, 0.35, 1.0)
	global_position += dir * step * k
	anim.speed_scale = k
	face(dir)


func _arrive() -> void:
	anim.speed_scale = 1.0
	var after := _after
	var what: String = after.get("do", "idle")
	if after.has("face"):
		face(after["face"])
	if what == "sit":
		state = State.TURN
		_play("idle", 0.25)
	elif what == "lie":
		state = State.TURN
		_play("idle", 0.25)
	else:
		state = State.IDLE
		_play("idle", 0.3)
		arrived.emit()
	if what == "idle" and not after.has("face"):
		_after = {}


func _after_turn() -> void:
	var what: String = _after.get("do", "idle")
	if what == "sit":
		_sit_down(float(_after.get("seat", 0.0)))
	elif what == "lie":
		_lie_down(_after)
	else:
		state = State.IDLE
		arrived.emit()


# --- Assis / debout -------------------------------------------------------------------

func _sit_down(seat_offset: float) -> void:
	state = State.SIT_DOWN
	_seat_offset = seat_offset
	_start_root_motion("sit_down")
	var a := _lib.get_animation("sit_down")
	if seat_offset != 0.0:
		var tw := create_tween()
		tw.tween_property(model, "position:y", seat_offset, a.length * 0.8).set_delay(a.length * 0.15)


func _start_root_motion(n: String) -> void:
	var a := _lib.get_animation(n)
	var s: Vector3 = a.get_meta("root_start", Vector3.ZERO)
	model.position = Vector3(s.x, model.position.y, s.z) # = rotation 180° de -S sur XZ
	_play(n, 0.0)


func _finish_root_motion(n: String) -> void:
	var a := _lib.get_animation(n)
	var s: Vector3 = a.get_meta("root_start", Vector3.ZERO)
	var e: Vector3 = a.get_meta("root_end", Vector3.ZERO)
	var d := Vector3(-(e.x - s.x), 0, -(e.z - s.z))
	global_position += global_transform.basis * d
	model.position = Vector3(0, model.position.y, 0)


func stand_up() -> void:
	if state == State.LYING:
		_get_up_from_lying()
		return
	if state != State.SITTING and state != State.SIT_DOWN:
		_continue_after_stand()
		return
	state = State.STAND_UP
	_start_root_motion("stand_up")
	var a := _lib.get_animation("stand_up")
	if _seat_offset != 0.0:
		var tw := create_tween()
		tw.tween_property(model, "position:y", 0.0, a.length * 0.7)
	_seat_offset = 0.0


func _on_anim_finished(n: StringName) -> void:
	match String(n):
		"sit_down":
			_finish_root_motion("sit_down")
			state = State.SITTING
			_play("sit_idle", 0.15)
			_variant_timer = _rng.randf_range(6.0, 14.0)
			action_done.emit("sit")
			arrived.emit()
		"stand_up":
			_finish_root_motion("stand_up")
			model.position.y = 0.0
			state = State.IDLE
			_play("idle", 0.15)
			action_done.emit("stand")
			_continue_after_stand()
		"wave":
			_play("sit_idle" if state == State.SITTING else "idle", 0.3)
		_:
			# Fin d'une variante jouée une fois : retour à l'attente.
			if state == State.SITTING and String(n).begins_with("sit_") and String(n) != "sit_idle":
				_play("sit_idle", 0.4)
			elif state == State.IDLE and String(n) in ["idle_look", "idle_cough"]:
				_play("idle", 0.4)


func _continue_after_stand() -> void:
	if _after.has("then_walk"):
		var pts: Array[Vector3] = []
		for p in _after["then_walk"]:
			pts.append(p)
		var after: Dictionary = _after.get("after", {})
		_after = {}
		walk_to(pts, after)


## Place le personnage directement assis (sans animation de transition).
func place_seated(pos: Vector3, facing: Vector3, seat_offset: float = 0.0, idle_anim: String = "sit_idle") -> void:
	global_position = pos
	face(facing, true)
	_seat_offset = seat_offset
	model.position = Vector3(0, seat_offset, 0)
	state = State.SITTING
	_play(idle_anim, 0.0)
	_variant_timer = _rng.randf_range(4.0, 12.0)


func place_standing(pos: Vector3, facing: Vector3) -> void:
	global_position = pos
	face(facing, true)
	model.position = Vector3.ZERO
	state = State.IDLE
	_play("idle", 0.0)


func play_loop(n: String) -> void:
	_play(n, 0.4)


func _update_variants(delta: float, seated: bool) -> void:
	if _talk_time > 0.0:
		return
	_variant_timer -= delta
	if _variant_timer > 0.0:
		return
	_variant_timer = _rng.randf_range(9.0, 20.0)
	if _current not in ["sit_idle", "idle", "sit_breathe"]:
		return
	var pool: Array[String] = []
	if seated:
		pool = ["sit_look", "sit_touch", "sit_breathe"]
		if cough:
			pool.append_array(["sit_cough", "sit_cough"])
	else:
		pool = ["idle_look"]
		if cough:
			pool.append("idle_cough")
	var pick := pool[_rng.randi() % pool.size()]
	if _lib.has_animation(pick):
		_lib.get_animation(pick).loop_mode = Animation.LOOP_NONE if pick != "sit_breathe" else Animation.LOOP_LINEAR
		_play(pick, 0.5)
		if pick in ["sit_cough", "idle_cough"]:
			action_done.emit("cough")


# --- Allongé sur la table d'examen ----------------------------------------------------

func _lie_down(info: Dictionary) -> void:
	state = State.LYING
	var head_dir: Vector3 = info.get("head", Vector3.FORWARD)
	var bed_pos: Vector3 = info.get("bed", global_position)
	var bed_h: float = float(info.get("bed_height", 0.72))
	_play("idle", 0.3)
	anim.pause()
	if _lying_tween:
		_lying_tween.kill()
	# Bascule du corps : la tête vers `head_dir`, le dos sur le matelas, visage vers le haut.
	head_dir = Vector3(head_dir.x, 0, head_dir.z).normalized()
	var start := global_transform
	var basis_end := Basis(Vector3.UP, atan2(head_dir.x, head_dir.z)) * Basis(Vector3.RIGHT, PI * 0.5)
	var hip: float = ADULT_HIP[gender] * _hip_scale
	var end_origin := bed_pos + Vector3.UP * (bed_h + 0.11) - head_dir * hip
	_free_yaw = false
	_lying_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var b0 := start.basis.orthonormalized()
	_lying_tween.tween_method(func(t: float):
		var b := b0.slerp(basis_end, t).orthonormalized()
		var o := start.origin.lerp(end_origin, t) + Vector3.UP * sin(t * PI) * 0.15
		global_transform = Transform3D(b, o), 0.0, 1.0, 1.4)
	_lying_tween.tween_callback(func():
		action_done.emit("lie")
		arrived.emit())
	set_meta("lying_from", start)


func _get_up_from_lying() -> void:
	if _lying_tween:
		_lying_tween.kill()
	state = State.STAND_UP
	var start := global_transform
	var end_t: Transform3D = get_meta("lying_from", Transform3D(Basis(), global_position))
	var yaw_end := end_t.basis.get_euler().y
	_lying_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var b1 := start.basis.orthonormalized()
	_lying_tween.tween_method(func(t: float):
		var b := b1.slerp(Basis(Vector3.UP, yaw_end), t).orthonormalized()
		global_transform = Transform3D(b, start.origin.lerp(end_t.origin, t) + Vector3.UP * sin(t * PI) * 0.15), 0.0, 1.0, 1.2)
	_lying_tween.tween_callback(func():
		rotation = Vector3(0, yaw_end, 0)
		_yaw_target = yaw_end
		_free_yaw = true
		state = State.IDLE
		anim.play()
		_play("idle", 0.2)
		action_done.emit("stand")
		_continue_after_stand())


func is_lying() -> bool:
	return state == State.LYING


func is_seated() -> bool:
	return state == State.SITTING


# --- Visage : clignements, parole, expressions ---------------------------------------

func _set_shape(n: String, v: float) -> void:
	if head_mesh and _shape_idx.has(n):
		head_mesh.set_blend_shape_value(_shape_idx[n], v)


## Fait parler le personnage. `envelope` : amplitude de la voix (30 valeurs/s).
func say(stream: AudioStream = null, duration: float = 2.5, envelope: PackedFloat32Array = PackedFloat32Array()) -> void:
	_talk_env = envelope
	_talk_clock = 0.0
	if stream:
		voice.stream = stream
		voice.play()
		duration = stream.get_length()
	_talk_time = duration
	if state == State.SITTING and _rng.randf() < 0.35 and _current == "sit_idle":
		var g := "sit_think" if _rng.randf() < 0.6 else "sit_shrug"
		if _lib.has_animation(g):
			_lib.get_animation(g).loop_mode = Animation.LOOP_NONE
			_play(g, 0.4)
	elif state == State.IDLE and _current == "idle" and duration > 2.0:
		_play("talk", 0.4)


func stop_talking() -> void:
	_talk_time = 0.0
	if voice.playing:
		voice.stop()


func is_talking() -> bool:
	return _talk_time > 0.0


func _on_voice_finished() -> void:
	_talk_time = 0.0
	speech_finished.emit()


## Expression temporaire : "pain", "smile", "worry", "neutral".
func express(kind: String, duration: float = 2.0) -> void:
	_expr_target.clear()
	match kind:
		"pain":
			_expr_target = {"brow_down_l": 0.8, "brow_down_r": 0.8, "squint_l": 0.7, "squint_r": 0.7, "frown_l": 0.5, "frown_r": 0.5, "sneer_l": 0.35, "sneer_r": 0.35, "jaw_open": 0.15}
		"smile":
			_expr_target = {"smile_l": 0.65, "smile_r": 0.65, "squint_l": 0.15, "squint_r": 0.15}
		"worry":
			_expr_target = {"brow_inner_up": 0.7, "frown_l": 0.25, "frown_r": 0.25}
		"open_mouth":
			_expr_target = {"jaw_open": 0.85, "v_aa": 0.6, "tongue_out": 0.25}
		"blow":
			_expr_target = {"cheek_puff": 0.8, "pucker": 0.6}
	_expr_timer = duration


## Expression de fond permanente (ex. patient inquiet ou souffrant).
var base_expression := ""


func _update_face(delta: float) -> void:
	if head_mesh == null:
		return
	# Clignements
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink = 0.16
		_blink_t = _rng.randf_range(2.0, 5.5)
		if _rng.randf() < 0.15:
			_blink_t = 0.25 # double clignement
	var bl := 0.0
	if _blink > 0.0:
		_blink -= delta
		bl = sin(clampf(1.0 - _blink / 0.16, 0.0, 1.0) * PI)

	# Expression
	if _expr_timer > 0.0:
		_expr_timer -= delta
		if _expr_timer <= 0.0:
			_expr_target.clear()
	var base := {}
	match base_expression:
		"pain":
			base = {"brow_down_l": 0.35, "brow_down_r": 0.35, "squint_l": 0.25, "squint_r": 0.25, "frown_l": 0.3, "frown_r": 0.3}
		"worry":
			base = {"brow_inner_up": 0.45, "frown_l": 0.15, "frown_r": 0.15}
		"tired":
			base = {"blink_l": 0.25, "blink_r": 0.25, "brow_inner_up": 0.2}
	var keys := ["brow_down_l", "brow_down_r", "squint_l", "squint_r", "frown_l", "frown_r", "sneer_l", "sneer_r",
		"smile_l", "smile_r", "brow_inner_up", "cheek_puff", "pucker", "tongue_out"]
	for k in keys:
		var want: float = maxf(float(_expr_target.get(k, 0.0)), float(base.get(k, 0.0)))
		var cur: float = _expr.get(k, 0.0)
		cur = lerpf(cur, want, 1.0 - exp(-8.0 * delta))
		_expr[k] = cur
		_set_shape(k, cur)

	# Parole : ouverture de la bouche et visèmes.
	var jaw := 0.0
	var vis_aa := 0.0
	var vis_o := 0.0
	var vis_e := 0.0
	var vis_pp := 0.0
	if _talk_time > 0.0:
		_talk_time -= delta
		_talk_clock += delta
		var amp := 0.0
		if not _talk_env.is_empty():
			var idx := int(_talk_clock * _talk_env_rate)
			amp = _talk_env[idx] if idx < _talk_env.size() else 0.0
		else:
			var t := _talk_clock
			amp = clampf(0.5 + 0.5 * sin(t * 11.0) * sin(t * 3.3 + 1.0) + 0.25 * sin(t * 23.0), 0.0, 1.0)
			if fmod(t, 1.7) > 1.45:
				amp *= 0.2
		var ph := _talk_clock * 7.0
		jaw = amp * 0.32
		vis_aa = amp * (0.55 + 0.45 * sin(ph))
		vis_o = amp * maxf(0.0, sin(ph * 0.73 + 1.3)) * 0.6
		vis_e = amp * maxf(0.0, sin(ph * 1.21 + 2.1)) * 0.5
		vis_pp = (1.0 - amp) * 0.25
	var jaw_expr: float = float(_expr_target.get("jaw_open", 0.0))
	var cur_jaw: float = _expr.get("jaw_open", 0.0)
	cur_jaw = lerpf(cur_jaw, maxf(jaw, jaw_expr), 1.0 - exp(-18.0 * delta))
	_expr["jaw_open"] = cur_jaw
	_set_shape("jaw_open", cur_jaw)
	for pair in [["v_aa", maxf(vis_aa, float(_expr_target.get("v_aa", 0.0)))], ["v_o", vis_o], ["v_e", vis_e], ["v_pp", vis_pp]]:
		var cur2: float = _expr.get(pair[0], 0.0)
		cur2 = lerpf(cur2, pair[1], 1.0 - exp(-18.0 * delta))
		_expr[pair[0]] = cur2
		_set_shape(pair[0], cur2)

	var base_blink: float = float(base.get("blink_l", 0.0))
	_set_shape("blink_l", maxf(bl, base_blink))
	_set_shape("blink_r", maxf(bl, base_blink))


## Teinte la peau (patient pâle, en sueur…).
func set_skin_look(kind: String) -> void:
	if head_mesh == null:
		return
	for s in head_mesh.mesh.get_surface_count():
		var m := head_mesh.mesh.surface_get_material(s) as StandardMaterial3D
		if m == null or not m.resource_name.ends_with("_head"):
			continue
		var mm := m.duplicate() as StandardMaterial3D
		match kind:
			"pale":
				mm.albedo_color = Color(0.93, 0.9, 0.9)
				mm.roughness = 0.55
				mm.metallic_specular = 0.7
			"flushed":
				mm.albedo_color = Color(1.0, 0.86, 0.84)
		head_mesh.set_surface_override_material(s, mm)


## Nœud qui suit la tête (cible de regard pour les autres personnages).
func head_bone_node() -> Node3D:
	return _head_att


## Position du haut de la tête (pour la caméra, les bulles…).
func head_position() -> Vector3:
	var i := skeleton.find_bone("Bip01 Head")
	if i < 0:
		return global_position + Vector3.UP * 1.6
	return skeleton.global_transform * skeleton.get_bone_global_pose(i).origin
