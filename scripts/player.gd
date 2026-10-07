class_name Player
extends CharacterBody3D
## Joueur : déplacement, caméra 1re/3e personne, inventaire (1 mortier, 2 pierres), coup de pied.

signal view_changed(first_person: bool)
signal item_changed(index: int)         # 0 = mains libres, 1 = mortier, 2 = pierres
signal ammo_changed(count: int, maximum: int)
signal message(text: String)
signal stage_changed(label: String, progress: float)
signal aim_changed(on: bool)
signal near_breakable_changed(near: bool)

const WALK_SPEED := 1.75
const RUN_SPEED := 5.2
const JUMP_VELOCITY := 5.0
const GRAVITY := 14.0
const MOUSE_SENS := 0.0025
const EYE_HEIGHT := 1.70

var human: Human
var mortar: Mortar
var thrower: Thrower
var cam_yaw: Node3D
var cam_pitch: Node3D
var spring: SpringArm3D
var camera: Camera3D
var first_person := false
var current_item := 0
var aiming := false
var _fp_blend := 0.0
var _yaw := 0.0
var _pitch := -0.12
var _run_t := 0.0
var _shake := 0.0
var _kick_yaw := 0.0
var _near := false
var _land_dip := 0.0
var _steps: Array[AudioStreamPlayer3D] = []
var _step_i := 0
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
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(50.0)

	human = Human.new()
	add_child(human)

	mortar = Mortar.new()
	mortar.attach_to(human)
	mortar.ammo_changed.connect(func(c, m): ammo_changed.emit(c, m))
	mortar.stage_changed.connect(func(l, p): stage_changed.emit(l, p))
	mortar.message.connect(func(t): message.emit(t))
	mortar.fired.connect(func(): _shake = 1.0)
	mortar.aim_point_provider = Callable(self, "_aim_point")

	thrower = Thrower.new()
	thrower.attach_to(human)
	thrower.aim_target_provider = Callable(self, "_aim_target")
	thrower.exclude_rid = get_rid()
	thrower.thrown.connect(func(): _shake = 0.25)

	human.kick_impact.connect(_on_kick_impact)
	human.footstep.connect(_on_footstep)
	human.landed.connect(_on_landed)
	for i in 2:
		var a := AudioStreamPlayer3D.new()
		a.unit_size = 6.0
		add_child(a)
		_steps.append(a)

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

	select_item(1)


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
		"slot_2": [KEY_2, KEY_KP_2],
		"reload_cheat": [KEY_R],
		"kick": [KEY_F],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k # touches physiques : ZQSD (AZERTY) ou WASD
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("aim"):
		InputMap.add_action("aim")
		var rb := InputEventMouseButton.new()
		rb.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("aim", rb)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", mb)


func _active() -> Node:
	match current_item:
		1: return mortar
		2: return thrower
	return null


func _busy() -> bool:
	return mortar.busy or thrower.busy or human.kick_t >= 0.0


## 0 = mains libres, 1 = mortier, 2 = pierres
func select_item(i: int) -> void:
	if mortar.busy or thrower.busy or i == current_item:
		return
	mortar.set_equipped(i == 1)
	thrower.set_equipped(i == 2)
	if i == 1:
		thrower.hide_now()
		human.hand_provider = Callable(mortar, "_hand_targets")
	elif i == 2:
		mortar.hide_now()
		thrower.claim_hands()
	current_item = i
	if aiming:
		aiming = false
		aim_changed.emit(false)
	item_changed.emit(i)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, deg_to_rad(-80.0), deg_to_rad(85.0))
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var dirn := 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
		select_item(posmod(current_item + dirn, 3))
	elif event.is_action_pressed("toggle_view"):
		first_person = not first_person
		view_changed.emit(first_person)
	elif event.is_action_pressed("slot_1"):
		select_item(0 if current_item == 1 else 1)
	elif event.is_action_pressed("slot_2"):
		select_item(0 if current_item == 2 else 2)
	elif event.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if current_item == 1:
			mortar.try_fire()
		elif current_item == 2:
			thrower.throw_stone()
	elif event.is_action_pressed("kick") and not aiming and not _busy() and is_on_floor():
		_kick_yaw = _yaw
		human.start_kick()
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
	if mortar.busy or thrower.busy or aiming:
		target_speed = minf(target_speed, WALK_SPEED * 0.55)
		_run_t = 0.0
	var kicking := human.kick_t >= 0.0
	if kicking:
		target_speed = 0.0
		_run_t = 0.0

	var want_aim := current_item != 0 and Input.is_action_pressed("aim") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not kicking
	if want_aim != aiming:
		aiming = want_aim
		aim_changed.emit(aiming)
		mortar.set_aim(aiming and current_item == 1)
		thrower.set_aim(aiming and current_item == 2)
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
		if Input.is_action_just_pressed("jump") and not kicking:
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	# --- orientation du corps
	var face_cam := first_person or current_item != 0
	var target_yaw := human.rotation.y
	if kicking:
		target_yaw = _kick_yaw
	elif face_cam:
		target_yaw = _yaw
	elif wish.length() > 0.1:
		target_yaw = atan2(-wish.x, -wish.z)
	human.rotation.y = lerp_angle(human.rotation.y, target_yaw, minf(1.0, delta * (16.0 if (face_cam or kicking) else 10.0)))

	# --- objets cassables à proximité (invite « F »)
	var near := false
	for n in get_tree().get_nodes_in_group("breakable"):
		if (n as Node3D).global_position.distance_to(global_position) < 4.6:
			near = true
	if near != _near:
		_near = near
		near_breakable_changed.emit(near)

	# --- animation
	mortar.step(delta)
	thrower.step(delta)
	var speed := Vector3(velocity.x, 0, velocity.z).length()
	var run_blend := clampf((speed - WALK_SPEED) / (RUN_SPEED - WALK_SPEED), 0.0, 1.0)
	human.animate(delta, speed, run_blend, is_on_floor(), velocity.y, _pitch)
	_update_camera(delta, speed)


func _on_footstep(speed: float) -> void:
	var a := _steps[_step_i]
	_step_i = (_step_i + 1) % _steps.size()
	a.stream = Sfx.get_stream(&"footstep_a" if _rng.randf() < 0.5 else &"footstep_b")
	a.volume_db = lerpf(-20.0, -7.0, clampf(speed / RUN_SPEED, 0.0, 1.0))
	a.pitch_scale = _rng.randf_range(0.9, 1.12)
	a.global_position = global_position
	a.play()


func _on_landed(vy: float) -> void:
	_land_dip = clampf(vy * 0.012, 0.0, 0.1)
	_on_footstep(RUN_SPEED * clampf(vy / 8.0, 0.2, 1.0))


func _on_kick_impact(point: Vector3) -> void:
	var fwd := Basis(Vector3.UP, human.rotation.y) * Vector3(0, 0, -1)
	var hit := false
	for n in get_tree().get_nodes_in_group("breakable"):
		if n.has_method("kick") and n.kick(point + fwd * 0.12, fwd):
			hit = true
	if hit:
		_shake = 0.7


func _aim_point() -> Vector3:
	return camera.global_position + (-camera.global_basis.z) * 60.0


## Point visé par le réticule (rayon caméra) : [position, touche quelque chose]
func _aim_target() -> Array:
	var from := camera.global_position
	var fwd := -camera.global_basis.z
	var to := from + fwd * 45.0
	var q := PhysicsRayQueryParameters3D.create(from + fwd * 0.6, to, 1)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r:
		return [r["position"], true]
	return [to, false]


func _update_camera(delta: float, speed: float) -> void:
	_fp_blend = move_toward(_fp_blend, 1.0 if first_person else 0.0, delta * 6.0)
	var e := _fp_blend * _fp_blend * (3.0 - 2.0 * _fp_blend)
	var k := clampf(maxf(mortar.aim_t, thrower.aim_t), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	cam_pitch.rotation.x = _pitch
	spring.spring_length = lerpf(lerpf(3.1, 1.75, k), 0.0, e)
	spring.position.x = lerpf(lerpf(0.55, 0.62, k), 0.0, e)
	cam_pitch.position.z = lerpf(0.0, -0.10, e)
	# balancement de la tête en 1re personne + amorti à la réception
	_land_dip = move_toward(_land_dip, 0.0, delta * 0.35)
	var sp := clampf(speed / RUN_SPEED, 0.0, 1.0) * human._walk_w
	var bob_y := sin(human.phase * TAU * 2.0) * (0.010 + 0.018 * _run_t) * sp * e
	var bob_x := sin(human.phase * TAU) * (0.006 + 0.01 * _run_t) * sp * e
	cam_yaw.position.y = EYE_HEIGHT + bob_y - _land_dip
	cam_pitch.position.x = bob_x
	# champ de vision : s'ouvre en courant, se resserre en visant
	var fov_target := lerpf(72.0 + 8.0 * _run_t, 46.0, k)
	camera.fov = lerpf(camera.fov, fov_target, minf(1.0, delta * 7.0))
	camera.cull_mask = 1 if e > 0.5 else 0xFFFFF

	# tremblement de la visée à la main (très léger) : respiration + tremor
	var t := Time.get_ticks_msec() / 1000.0
	var sway := Vector3(
		sin(t * 1.7) * 0.0016 + sin(t * 4.3 + 1.0) * 0.0009 + sin(t * 13.0) * 0.0004,
		sin(t * 1.3 + 2.0) * 0.0019 + sin(t * 3.7) * 0.0009 + sin(t * 11.0 + 1.0) * 0.0004,
		sin(t * 0.9) * 0.0011) * k
	# léger roulis pendant la course
	sway.z += sin(human.phase * TAU) * 0.004 * sp * _run_t * e
	camera.rotation = sway

	_shake = move_toward(_shake, 0.0, delta * 3.5)
	var s := _shake * _shake * 0.02
	camera.h_offset = _rng.randf_range(-s, s)
	camera.v_offset = _rng.randf_range(-s, s)
