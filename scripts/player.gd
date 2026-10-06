class_name Player
extends CharacterBody3D
## Joueur : déplacement, caméra 1re/3e personne, inventaire (mortier).

signal view_changed(first_person: bool)
signal equipped_changed(on: bool)
signal ammo_changed(count: int, maximum: int)
signal message(text: String)
signal stage_changed(label: String, progress: float)

const WALK_SPEED := 1.75
const RUN_SPEED := 5.2
const JUMP_VELOCITY := 5.0
const GRAVITY := 14.0
const MOUSE_SENS := 0.0025
const EYE_HEIGHT := 1.70

var human: Human
var mortar: Mortar
var cam_yaw: Node3D
var cam_pitch: Node3D
var spring: SpringArm3D
var camera: Camera3D
var first_person := false
var _fp_blend := 0.0
var _yaw := 0.0
var _pitch := -0.12
var _run_t := 0.0
var _shake := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_register_inputs()

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.76
	col.shape = cap
	col.position.y = 0.88
	add_child(col)

	human = Human.new()
	add_child(human)

	mortar = Mortar.new()
	mortar.attach_to(human)
	mortar.ammo_changed.connect(func(c, m): ammo_changed.emit(c, m))
	mortar.stage_changed.connect(func(l, p): stage_changed.emit(l, p))
	mortar.message.connect(func(t): message.emit(t))
	mortar.fired.connect(func(): _shake = 1.0)

	cam_yaw = Node3D.new()
	cam_yaw.position.y = EYE_HEIGHT
	add_child(cam_yaw)
	cam_pitch = Node3D.new()
	cam_yaw.add_child(cam_pitch)
	spring = SpringArm3D.new()
	spring.spring_length = 3.2
	spring.margin = 0.25
	spring.shape = SphereShape3D.new()
	(spring.shape as SphereShape3D).radius = 0.2
	spring.add_excluded_object(get_rid())
	cam_pitch.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.04
	camera.far = 4000.0
	camera.current = true
	spring.add_child(camera)

	equip(true)


func _register_inputs() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"run": [KEY_SHIFT],
		"jump": [KEY_SPACE],
		"toggle_view": [KEY_V],
		"slot_1": [KEY_1, KEY_KP_1],
		"reload_cheat": [KEY_R],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k # touches physiques : ZQSD (AZERTY) ou WASD
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", mb)


func equip(on: bool) -> void:
	if mortar.busy:
		return
	mortar.set_equipped(on)
	equipped_changed.emit(on)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, deg_to_rad(-80.0), deg_to_rad(85.0))
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_view"):
		first_person = not first_person
		view_changed.emit(first_person)
	elif event.is_action_pressed("slot_1"):
		equip(not mortar.equipped)
	elif event.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mortar.try_fire()
	elif event.is_action_pressed("reload_cheat"):
		mortar.reload_all()
		message.emit("Obus rechargés")
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	# --- entrée
	var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wants_run := Input.is_action_pressed("run") and iv.y <= 0.3 and iv.length() > 0.1
	_run_t = move_toward(_run_t, 1.0 if wants_run else 0.0, delta * 4.0)
	var target_speed := lerpf(WALK_SPEED, RUN_SPEED, _run_t)
	if mortar.busy:
		target_speed = minf(target_speed, WALK_SPEED * 0.6)

	cam_yaw.rotation.y = _yaw
	var basis_yaw := Basis(Vector3.UP, _yaw)
	var wish := basis_yaw * Vector3(iv.x, 0.0, iv.y)

	var horiz := Vector3(velocity.x, 0, velocity.z)
	var accel := 28.0 if is_on_floor() else 7.0
	horiz = horiz.move_toward(wish * target_speed, accel * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z

	if is_on_floor():
		velocity.y = 0.0
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	# --- orientation du corps
	var face_cam := first_person or mortar.equipped
	var target_yaw := human.rotation.y
	if face_cam:
		target_yaw = _yaw
	elif wish.length() > 0.1:
		target_yaw = atan2(-wish.x, -wish.z)
	human.rotation.y = lerp_angle(human.rotation.y, target_yaw, minf(1.0, delta * (14.0 if face_cam else 10.0)))

	# --- animation
	mortar.step(delta)
	var speed := Vector3(velocity.x, 0, velocity.z).length()
	var run_blend := clampf((speed - WALK_SPEED) / (RUN_SPEED - WALK_SPEED), 0.0, 1.0)
	human.animate(delta, speed, run_blend, is_on_floor(), velocity.y, _pitch)
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	_fp_blend = move_toward(_fp_blend, 1.0 if first_person else 0.0, delta * 6.0)
	var e := _fp_blend * _fp_blend * (3.0 - 2.0 * _fp_blend)
	cam_pitch.rotation.x = _pitch
	spring.spring_length = lerpf(3.1, 0.0, e)
	spring.position.x = lerpf(0.55, 0.0, e)
	cam_pitch.position.z = lerpf(0.0, -0.10, e)
	cam_yaw.position.y = EYE_HEIGHT + 0.0 * e
	# le champ de vision s'ouvre un peu en courant
	camera.fov = lerpf(camera.fov, 72.0 + 8.0 * _run_t, minf(1.0, delta * 5.0))
	# la tête n'est visible que depuis l'extérieur
	camera.cull_mask = 1 if e > 0.5 else 0xFFFFF

	_shake = move_toward(_shake, 0.0, delta * 3.5)
	var s := _shake * _shake * 0.02
	camera.h_offset = _rng.randf_range(-s, s)
	camera.v_offset = _rng.randf_range(-s, s)
