class_name Player
extends CharacterBody3D
## Médecin à la première personne : déplacement, regard, interaction (E),
## outils d'examen (roue TAB, molette, clic droit pour ranger) et gestes
## d'examen sur les zones du corps (clic gauche maintenu).

signal focus_changed(target: Interactable)
signal spot_changed(spot: Hotspot, exam_id: String, ok: bool, reason: String)
signal exam_progress(ratio: float)
signal exam_performed(spot: Hotspot, exam_id: String)
signal tool_changed(tool_id: String)
signal wheel_toggled(open: bool)

const WALK_SPEED := 2.4
const SPRINT_SPEED := 4.0
const ACCEL := 12.0
const EYE_HEIGHT := 1.68
const REACH_INTERACT := 2.4
const REACH_EXAM := 1.7

var input_enabled := true
var camera: Camera3D
var head: Node3D
var ray: RayCast3D
var spot_ray: RayCast3D
var viewmodel: Viewmodel
var wheel: ToolWheel
var focused: Interactable
var focused_spot: Hotspot
var focused_exam := ""
var tool := "mains"
## Fonction (Hotspot) -> String : position du patient ("chair", "table", "lying", "standing")
var position_of: Callable
## Fonction (Hotspot) -> bool : la zone appartient-elle au patient en consultation ?
var spot_allowed: Callable

var _yaw := 0.0
var _pitch := 0.0
var _bob_t := 0.0
var _focus_tween: Tween
var _hold := 0.0
var _holding := false
var _hold_exam := ""
var _hold_spot: Hotspot
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _step_t := 0.0


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)

	head = Node3D.new()
	head.position.y = EYE_HEIGHT
	add_child(head)
	camera = Camera3D.new()
	camera.fov = float(Game.settings["fov"])
	camera.near = 0.03
	camera.far = 300.0
	head.add_child(camera)
	camera.current = true

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -REACH_INTERACT)
	ray.collision_mask = 1 | (1 << (Interactable.LAYER - 1))
	ray.collide_with_areas = true
	ray.add_exception(self)
	camera.add_child(ray)

	spot_ray = RayCast3D.new()
	spot_ray.target_position = Vector3(0, 0, -REACH_EXAM)
	spot_ray.collision_mask = 1 | (1 << (Hotspot.LAYER - 1))
	spot_ray.collide_with_areas = true
	spot_ray.add_exception(self)
	camera.add_child(spot_ray)

	viewmodel = Viewmodel.new()
	camera.add_child(viewmodel)
	Game.settings_changed.connect(_on_settings_changed)


func _on_settings_changed() -> void:
	if camera:
		camera.fov = float(Game.settings["fov"])


func set_look(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch
	rotation.y = _yaw
	head.rotation.x = _pitch


func equip(id: String) -> void:
	if id == tool:
		return
	tool = id
	_cancel_hold()
	viewmodel.equip(id)
	Sfx.ui("equip")
	tool_changed.emit(id)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if wheel and wheel.is_open():
		if event is InputEventMouseMotion:
			wheel.feed_motion(event.relative)
			get_viewport().set_input_as_handled()
		elif event.is_action_released("tool_wheel"):
			_close_wheel()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("tool_next"):
			wheel.step(1)
		elif event.is_action_pressed("tool_prev"):
			wheel.step(-1)
		return
	if event is InputEventMouseMotion and captured:
		var s: float = float(Game.settings["sensitivity"]) * 0.01
		var inv := -1.0 if Game.settings.get("invert_y", false) else 1.0
		_yaw -= event.relative.x * s
		_pitch = clampf(_pitch - event.relative.y * s * inv, deg_to_rad(-85), deg_to_rad(85))
		rotation.y = _yaw
		head.rotation.x = _pitch
		viewmodel.add_sway(event.relative)
	elif event.is_action_pressed("tool_wheel"):
		if wheel:
			_cancel_hold()
			wheel.open(tool)
			wheel_toggled.emit(true)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tool_next") and captured:
		equip(ExamDB.TOOLS[(ExamDB.tool_index(tool) + 1) % ExamDB.TOOLS.size()]["id"])
	elif event.is_action_pressed("tool_prev") and captured:
		equip(ExamDB.TOOLS[posmod(ExamDB.tool_index(tool) - 1, ExamDB.TOOLS.size())]["id"])
	elif event.is_action_pressed("holster") and captured:
		equip("mains")
	elif event.is_action_pressed("interact") and captured:
		if focused and focused.enabled:
			get_viewport().set_input_as_handled()
			focused.interact()
	elif event.is_action_pressed("use_tool") and captured:
		if focused_spot and focused_exam != "" and _spot_usable():
			_holding = true
			_hold = 0.0
			_hold_exam = focused_exam
			_hold_spot = focused_spot
			_start_tool_sound()
		elif focused and focused.enabled and tool == "mains":
			# Clic gauche sans outil = interaction.
			focused.interact()
	elif event.is_action_released("use_tool"):
		_cancel_hold()


func _close_wheel() -> void:
	var chosen := wheel.close()
	wheel_toggled.emit(false)
	if chosen != "":
		equip(chosen)


func close_wheel_if_open() -> void:
	if wheel and wheel.is_open():
		wheel.close()
		wheel_toggled.emit(false)


func _cancel_hold() -> void:
	if _holding:
		_holding = false
		_hold = 0.0
		exam_progress.emit(0.0)
		viewmodel.set_use(0.0)


func _spot_usable() -> bool:
	if focused_spot == null:
		return false
	if spot_allowed.is_valid() and not spot_allowed.call(focused_spot):
		return false
	var e: Dictionary = ExamDB.EXAMS.get(focused_exam, {})
	var pos: String = position_of.call(focused_spot) if position_of.is_valid() else "chair"
	return ExamDB.pos_ok(e.get("pos", "any"), pos)


func _start_tool_sound() -> void:
	match tool:
		"stethoscope":
			Sfx.ui("tool_steth", -4.0)
		"tensiometre":
			Sfx.ui("bp_start", -4.0)
		_:
			Sfx.ui("tool_use", -6.0)


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	var sprint := false
	var can_move := input_enabled and not (wheel and wheel.is_open())
	if can_move:
		var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = (transform.basis * Vector3(iv.x, 0, iv.y))
		dir.y = 0
		if dir.length_squared() > 1.0:
			dir = dir.normalized()
		sprint = Input.is_action_pressed("sprint")
	if _holding:
		dir *= 0.25
	var speed := SPRINT_SPEED if sprint else WALK_SPEED
	var target := dir * speed
	velocity.x = lerpf(velocity.x, target.x, 1.0 - exp(-ACCEL * delta))
	velocity.z = lerpf(velocity.z, target.z, 1.0 - exp(-ACCEL * delta))
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = maxf(velocity.y, -0.1)
	move_and_slide()

	var hspeed := Vector2(velocity.x, velocity.z).length()
	var bob_offset := Vector3.ZERO
	if Game.settings["head_bob"] and hspeed > 0.3 and is_on_floor():
		_bob_t += delta * hspeed * 2.6
		bob_offset = Vector3(cos(_bob_t * 0.5) * 0.016, absf(sin(_bob_t)) * 0.026, 0)
	else:
		_bob_t = 0.0
	camera.position = camera.position.lerp(bob_offset, 1.0 - exp(-10.0 * delta))
	viewmodel.set_moving(hspeed, delta)

	# Bruits de pas
	if hspeed > 0.6 and is_on_floor():
		_step_t += delta * hspeed
		if _step_t > 1.35:
			_step_t = 0.0
			_footstep()
	else:
		_step_t = 0.9

	_update_focus()
	_update_hold(delta)


func _footstep() -> void:
	var surface := "tile" if global_position.x < 0.0 and global_position.z < 6.0 else ("wood" if global_position.x >= 0.0 and global_position.z < 6.0 else "outside")
	var n := randi() % 4 + 1
	Sfx.play_at("steps/%s_%d" % [surface, n], global_position, get_parent(), -14.0, randf_range(0.94, 1.06))


func _update_focus() -> void:
	var hit: Interactable = null
	if input_enabled and ray.is_colliding():
		var col := ray.get_collider()
		if col is Interactable and (col as Interactable).enabled:
			hit = col
	if hit != focused:
		focused = hit
		focus_changed.emit(focused)

	var spot: Hotspot = null
	var exam := ""
	if input_enabled and spot_ray.is_colliding():
		var c2 := spot_ray.get_collider()
		if c2 is Hotspot and (c2 as Hotspot).active:
			spot = c2
	if spot:
		var pos: String = position_of.call(spot) if position_of.is_valid() else "chair"
		exam = ExamDB.exam_for(tool, spot.spot_id, pos)
	var ok := false
	var reason := ""
	if spot and exam != "":
		ok = true
		var pos2: String = position_of.call(spot) if position_of.is_valid() else "chair"
		var e: Dictionary = ExamDB.EXAMS[exam]
		if spot_allowed.is_valid() and not spot_allowed.call(spot):
			ok = false
			reason = "Ce patient n'est pas en consultation"
		elif not ExamDB.pos_ok(e["pos"], pos2):
			ok = false
			reason = ExamDB.pos_hint(e["pos"])
	if spot != focused_spot or exam != focused_exam:
		if _holding and (spot != _hold_spot or exam != _hold_exam):
			_cancel_hold()
		focused_spot = spot
		focused_exam = exam
		spot_changed.emit(spot, exam, ok, reason)


func _update_hold(delta: float) -> void:
	if not _holding:
		return
	if not Input.is_action_pressed("use_tool") or focused_spot != _hold_spot:
		_cancel_hold()
		return
	var e: Dictionary = ExamDB.EXAMS.get(_hold_exam, {})
	var dur: float = float(e.get("hold", 1.5))
	_hold += delta / maxf(0.2, dur)
	viewmodel.set_use(clampf(_hold * 1.6, 0.0, 1.0))
	exam_progress.emit(clampf(_hold, 0.0, 1.0))
	if _hold >= 1.0:
		var s := _hold_spot
		var ex := _hold_exam
		_holding = false
		_hold = 0.0
		exam_progress.emit(0.0)
		var tw := create_tween()
		tw.tween_interval(0.25)
		tw.tween_callback(viewmodel.set_use.bind(0.0))
		exam_performed.emit(s, ex)


## Oriente doucement la caméra vers un point.
func focus_on(point: Vector3, duration: float = 0.6) -> void:
	var to := point - head.global_position
	var target_yaw := atan2(-to.x, -to.z)
	var target_pitch := atan2(to.y, Vector2(to.x, to.z).length())
	target_yaw = _yaw + wrapf(target_yaw - _yaw, -PI, PI)
	if _focus_tween:
		_focus_tween.kill()
	_focus_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.tween_method(_apply_yaw, _yaw, target_yaw, duration)
	_focus_tween.tween_method(_apply_pitch, _pitch, target_pitch, duration)


func _apply_yaw(v: float) -> void:
	_yaw = v
	rotation.y = v


func _apply_pitch(v: float) -> void:
	_pitch = v
	head.rotation.x = v
