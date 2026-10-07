class_name Player
extends CharacterBody3D
## Joueur : déplacement, caméra 1re/3e personne, inventaire (1 mortier, 2 pierres,
## 3 briquet + journal, 4 fumigène), coup de pied, poubelles (E), appel à la foule (G).

signal view_changed(first_person: bool)
signal item_changed(index: int)         # 0 = mains libres, 1 mortier, 2 pierres, 3 briquet, 4 fumigène
signal ammo_changed(count: int, maximum: int)
signal message(text: String)
signal stage_changed(label: String, progress: float)
signal aim_changed(on: bool)
signal near_breakable_changed(near: bool)
signal flares_changed(count: int, maximum: int)

const WALK_SPEED := 1.75
const RUN_SPEED := 5.2
const JUMP_VELOCITY := 5.0
const GRAVITY := 14.0
const MOUSE_SENS := 0.0025
const EYE_HEIGHT := 1.70

var human: Human
var mortar: Mortar
var thrower: Thrower
var igniter: Igniter
var flare_tool: FlareTool
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
var _tool_hands := Callable()
var _grab_bin: TrashBin
var _grab_prev := 0
var _e_t := -1.0
var _e_bin: TrashBin
var _e_pick: Burnable
var near_bin: TrashBin
var near_pick: Burnable
var _call_t := -1.0
var _call_cd := 0.0
var _lift_obj: Node3D            # objet qu'on redresse (poubelle couchée, barrière tombée)
var _lift_t := -1.0
var _lift_dur := 1.4
var _lift_cb := Callable()
var _lift_fired := false
var _lift_prev := 0
var _lift_yaw := 0.0
var _lift_grip := Vector3.ZERO
var _aim_evt := 0.0
var _voice: AudioStreamPlayer3D


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
	collision_mask = 1 | 16 | 32 | 64
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(50.0)

	human = Human.new()
	add_child(human)

	mortar = Mortar.new()
	mortar.attach_to(human)
	mortar.ammo_changed.connect(func(c, m): ammo_changed.emit(c, m))
	mortar.stage_changed.connect(func(l, p): stage_changed.emit(l, p))
	mortar.message.connect(func(t): message.emit(t))
	mortar.fired.connect(_on_mortar_fired)
	mortar.aim_point_provider = Callable(self, "_aim_point")

	thrower = Thrower.new()
	thrower.attach_to(human)
	thrower.aim_target_provider = Callable(self, "_aim_target")
	thrower.exclude_rid = get_rid()
	thrower.thrown.connect(func(): _shake = 0.25)

	igniter = Igniter.new()
	igniter.attach_to(human)
	igniter.message.connect(func(t): message.emit(t))

	flare_tool = FlareTool.new()
	flare_tool.attach_to(human)
	flare_tool.aim_target_provider = Callable(self, "_aim_target")
	flare_tool.message.connect(func(t): message.emit(t))
	flare_tool.count_changed.connect(func(c, m): flares_changed.emit(c, m))
	human.hand_provider = Callable(self, "_hands")
	_tool_hands = Callable(mortar, "_hand_targets")
	_voice = AudioStreamPlayer3D.new()
	_voice.position.y = 1.65
	_voice.unit_size = 8.0
	add_child(_voice)

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
		"slot_3": [KEY_3, KEY_KP_3],
		"slot_4": [KEY_4, KEY_KP_4],
		"interact": [KEY_E],
		"call_crowd": [KEY_G],
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


func _tools_busy() -> bool:
	return mortar.busy or thrower.busy or igniter.busy or flare_tool.busy


func _busy() -> bool:
	return _tools_busy() or human.kick_t >= 0.0 or _grab_bin != null or _lift_t >= 0.0


## 0 = mains libres, 1 = mortier, 2 = pierres, 3 = briquet + journal, 4 = fumigène
func select_item(i: int) -> void:
	if _tools_busy() or i == current_item or _lift_t >= 0.0:
		return
	mortar.set_equipped(i == 1)
	thrower.set_equipped(i == 2)
	igniter.set_equipped(i == 3)
	flare_tool.set_equipped(i == 4)
	if i != 1 and i != 0:
		mortar.hide_now()
	if i != 2 and i != 0:
		thrower.hide_now()
	if i != 3:
		igniter.hide_now()
	if i != 4:
		flare_tool.hide_now()
	match i:
		1: _tool_hands = Callable(mortar, "_hand_targets")
		2: _tool_hands = Callable(thrower, "_hand_targets")
		3: _tool_hands = Callable(igniter, "_hand_targets")
		4: _tool_hands = Callable(flare_tool, "_hand_targets")
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
		if _grab_bin == null:
			select_item(posmod(current_item + dirn, 5))
	elif event.is_action_pressed("toggle_view"):
		first_person = not first_person
		view_changed.emit(first_person)
	elif _grab_bin == null and event.is_action_pressed("slot_1"):
		select_item(0 if current_item == 1 else 1)
	elif _grab_bin == null and event.is_action_pressed("slot_2"):
		select_item(0 if current_item == 2 else 2)
	elif _grab_bin == null and event.is_action_pressed("slot_3"):
		select_item(0 if current_item == 3 else 3)
	elif _grab_bin == null and event.is_action_pressed("slot_4"):
		select_item(0 if current_item == 4 else 4)
	elif event.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _grab_bin == null:
		match current_item:
			1: mortar.try_fire()
			2: thrower.throw_stone()
			3: igniter.use()
			4: flare_tool.use()
	elif event.is_action_pressed("kick") and not aiming and not _busy() and is_on_floor():
		_kick_yaw = _yaw
		human.start_kick()
	elif event.is_action_pressed("call_crowd"):
		call_crowd()
	elif event.is_action_pressed("reload_cheat"):
		mortar.reload_all()
		flare_tool.reload_all()
		message.emit("Obus et fumigènes rechargés")
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	# --- entrée
	var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wants_run := Input.is_action_pressed("run") and iv.y <= 0.3 and iv.length() > 0.1
	_run_t = move_toward(_run_t, 1.0 if wants_run else 0.0, delta * 4.0)
	var target_speed := lerpf(WALK_SPEED, RUN_SPEED, _run_t)
	if _tools_busy() or (aiming and current_item != 4):
		target_speed = minf(target_speed, WALK_SPEED * 0.55)
		_run_t = 0.0
	if _grab_bin != null:
		target_speed = minf(target_speed, WALK_SPEED * 0.9)
		_run_t = 0.0
	if igniter.busy or _lift_t >= 0.0:
		target_speed = 0.0   # les deux pieds au sol pendant qu'on dépose / allume / redresse
		_run_t = 0.0
	var kicking := human.kick_t >= 0.0
	if kicking:
		target_speed = 0.0
		_run_t = 0.0

	var want_aim := current_item != 0 and Input.is_action_pressed("aim") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not kicking and _grab_bin == null
	if want_aim != aiming:
		aiming = want_aim
		aim_changed.emit(aiming and current_item in [1, 2])
		mortar.set_aim(aiming and current_item == 1)
		thrower.set_aim(aiming and current_item == 2)
		igniter.set_aim(aiming and current_item == 3)
		flare_tool.set_aim(aiming and current_item == 4)
	cam_yaw.rotation.y = _yaw
	var basis_yaw := Basis(Vector3.UP, _yaw)
	var wish := basis_yaw * Vector3(iv.x, 0.0, iv.y)
	if igniter.busy and igniter.approach_d > 0.0:
		# se rapproche de la poubelle pour atteindre l'intérieur
		var to := igniter.approach_pos - global_position
		to.y = 0.0
		if to.length() > igniter.approach_d + 0.02:
			wish = to.normalized()
			target_speed = 0.8

	var horiz := Vector3(velocity.x, 0, velocity.z)
	var accel := 28.0 if is_on_floor() else 7.0
	horiz = horiz.move_toward(wish * target_speed, accel * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z

	if is_on_floor():
		velocity.y = 0.0
		if Input.is_action_just_pressed("jump") and not kicking and _grab_bin == null:
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_push_bodies()

	# --- orientation du corps
	var face_cam := first_person or current_item != 0 or _grab_bin != null
	var target_yaw := human.rotation.y
	if kicking:
		target_yaw = _kick_yaw
	elif igniter.busy and not is_nan(igniter.lock_yaw):
		target_yaw = igniter.lock_yaw
	elif _lift_t >= 0.0:
		target_yaw = _lift_yaw
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

	# --- poubelles (E : ouvrir/fermer, maintenir : déplacer) ; appel à la foule
	_update_bins(delta)
	_update_lift(delta)
	_call_cd = maxf(_call_cd - delta, 0.0)
	if _call_t >= 0.0:
		_call_t += delta
		if _call_t > 1.7:
			_call_t = -1.0
	# la foule voit où l'on vise avec le mortier
	_aim_evt -= delta
	if current_item == 1 and mortar.aim_t > 0.6 and _aim_evt <= 0.0:
		_aim_evt = 0.3
		get_tree().call_group("crowd", "on_event", "mortar_aim", {"pos": mortar.mouth_world(), "dir": mortar.axis_world()})

	# --- animation
	mortar.step(delta)
	thrower.step(delta)
	igniter.step(delta)
	flare_tool.step(delta)
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
			get_tree().call_group("crowd", "on_event", "kick_bus", {"pos": point})
	for n in get_tree().get_nodes_in_group("kickable"):
		if n.has_method("kick") and n.kick(point + fwd * 0.12, fwd):
			hit = true
	if hit:
		_shake = 0.7


func _on_mortar_fired() -> void:
	_shake = 1.0
	get_tree().call_group("crowd", "on_event", "mortar_fire", {"pos": mortar.mouth_world(), "dir": mortar.axis_world(), "player": true})


## Pousser une poubelle ou un carton en marchant dedans
func _push_bodies() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		var n := -c.get_normal()
		n.y = 0.0
		if col is TrashBin and col != _grab_bin:
			(col as TrashBin).push(n, Vector3(velocity.x, 0, velocity.z).length() + 0.6)
		elif col is RigidBody3D and not (col as RigidBody3D).freeze:
			(col as RigidBody3D).apply_central_impulse(n * 0.6)


func _update_bins(delta: float) -> void:
	# poubelle la plus proche, devant le joueur
	near_bin = null
	if _grab_bin == null:
		var best := 1.9
		var fwd := -cam_yaw.global_basis.z
		for b in get_tree().get_nodes_in_group("bins"):
			var bin := b as TrashBin
			var d := bin.global_position - global_position
			d.y = 0.0
			var l := d.length()
			if l < best and (l < 0.9 or fwd.dot(d / maxf(l, 0.01)) > 0.2):
				best = l
				near_bin = bin
	# déchet à ramasser devant soi
	near_pick = null
	if _grab_bin == null and not _tools_busy() and human.kick_t < 0.0:
		near_pick = igniter.find_pickable()
		if near_pick != null and near_bin != null:
			var dp := (near_pick.global_position - global_position) * Vector3(1, 0, 1)
			var db := (near_bin.global_position - global_position) * Vector3(1, 0, 1)
			if db.length() < dp.length():
				near_pick = null
	if Input.is_action_just_pressed("interact") and _grab_bin == null:
		_e_t = 0.0
		_e_bin = near_bin
		_e_pick = near_pick
	if _e_t >= 0.0:
		if Input.is_action_pressed("interact"):
			_e_t += delta
			if _e_t > 0.32 and _grab_bin == null and _e_bin != null and is_instance_valid(_e_bin) and not _e_bin.tipped and not _tools_busy() and human.kick_t < 0.0:
				_start_grab(_e_bin)
		else:
			if _grab_bin != null:
				_end_grab()
			elif _e_bin != null and is_instance_valid(_e_bin) and _e_bin.tipped and _e_t <= 0.6:
				_lift_bin(_e_bin)
			elif _e_pick != null and is_instance_valid(_e_pick) and not _tools_busy():
				if current_item != 3:
					select_item(3)
				igniter.queue_pick(_e_pick)
			elif _e_t <= 0.32 and _e_bin != null and is_instance_valid(_e_bin):
				_e_bin.toggle_lid()
			elif _e_t <= 0.32 and igniter.held != null and not igniter.busy:
				igniter.put_down()
			_e_t = -1.0
			_e_pick = null
	if _grab_bin != null:
		var fwd2 := Basis(Vector3.UP, human.rotation.y) * Vector3(0, 0, -1)
		_grab_bin.drag_to(global_position + fwd2 * 1.22, human.rotation.y, delta)


## Redresser une poubelle couchée : le joueur s'accroupit, l'attrape et la remet debout devant lui
func _lift_bin(bin: TrashBin) -> void:
	if bin._righting or not bin.tipped:
		return
	var yaw_b := human.rotation.y + PI * 0.0
	start_lift(bin, func(): bin.begin_right(yaw_b, 0.85), 1.5)


## Geste « redresser » commun (poubelle, barrière) : on s'accroupit, on attrape, on relève ; `on_lift` part à l'instant de la prise
func start_lift(obj: Node3D, on_lift: Callable, dur := 1.4) -> void:
	if _lift_t >= 0.0 or _tools_busy() or human.kick_t >= 0.0 or _grab_bin != null or not is_on_floor():
		return
	_lift_prev = current_item
	if current_item != 0:
		select_item(0)
	_lift_obj = obj
	_lift_cb = on_lift
	_lift_dur = dur
	_lift_t = 0.0
	_lift_fired = false
	var d := obj.global_position - global_position
	d.y = 0.0
	_lift_yaw = atan2(-d.x, -d.z)
	_lift_grip = obj.global_position


func _update_lift(delta: float) -> void:
	if _lift_t < 0.0:
		return
	if _lift_obj == null or not is_instance_valid(_lift_obj):
		_end_lift()
		return
	_lift_t += delta
	var u := _lift_t / _lift_dur
	if not _lift_fired and u >= 0.3:
		_lift_fired = true
		_lift_grip = _lift_obj.global_position
		if _lift_cb.is_valid():
			_lift_cb.call()
	var bend := _smooth(u / 0.3) * (1.0 - _smooth((u - 0.45) / 0.4))
	human.crouch = 0.62 * bend
	human.lean_extra = 0.38 * bend
	if u >= 1.0:
		_end_lift()


func _end_lift() -> void:
	_lift_t = -1.0
	_lift_obj = null
	human.crouch = 0.0
	human.lean_extra = 0.0
	if _lift_prev != 0:
		select_item(_lift_prev)
	_lift_prev = 0


func _smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _start_grab(bin: TrashBin) -> void:
	_grab_prev = current_item
	if current_item != 0:
		select_item(0)
	_grab_bin = bin
	bin.grab(self)


func _end_grab() -> void:
	if _grab_bin == null:
		return
	_grab_bin.release()
	_grab_bin = null
	if _grab_prev != 0:
		select_item(_grab_prev)


func call_crowd() -> void:
	if _call_cd > 0.0:
		return
	_call_cd = 3.5
	_call_t = 0.0
	_voice.stream = AudioLib.stream("player_call_%d" % _rng.randi_range(0, 2))
	_voice.volume_db = 2.0
	_voice.play()
	var p := global_position
	get_tree().create_timer(0.35).timeout.connect(func():
		get_tree().call_group("crowd", "on_event", "call", {"pos": p, "dir": -cam_yaw.global_basis.z}))


## Mains : outil en cours, puis poubelle tenue ou geste d'appel par-dessus
func _hands() -> Array:
	var out: Array = [null, null]
	if _tool_hands.is_valid():
		out = _tool_hands.call()
	if _grab_bin != null:
		var fwd := Basis(Vector3.UP, human.rotation.y) * Vector3(0, 0, -1)
		out = [{"pos": _grab_bin.handle_world(0.13) + Vector3.UP * 0.03, "f": fwd, "p": Vector3.DOWN, "curl": 0.95, "w": 1.0},
			{"pos": _grab_bin.handle_world(-0.13) + Vector3.UP * 0.03, "f": fwd, "p": Vector3.DOWN, "curl": 0.95, "w": 1.0}]
	elif _lift_t >= 0.0 and _lift_obj != null and is_instance_valid(_lift_obj):
		var yb := Basis(Vector3.UP, human.rotation.y)
		var fwdl: Vector3 = yb * Vector3(0, 0, -1)
		var rgtl: Vector3 = yb * Vector3(1, 0, 0)
		var ul := _lift_t / _lift_dur
		var wl := _smooth(ul / 0.25) * (1.0 - _smooth((ul - 0.82) / 0.15))
		var base := _lift_obj.global_position - fwdl * 0.3
		var gp := base + Vector3.UP * lerpf(0.22, 0.8, _smooth((ul - 0.3) / 0.5))
		out = [{"pos": gp + rgtl * 0.2, "f": fwdl * 0.4 - Vector3.UP * 0.9, "p": -rgtl, "curl": 0.9, "w": wl},
			{"pos": gp - rgtl * 0.2, "f": fwdl * 0.4 - Vector3.UP * 0.9, "p": rgtl, "curl": 0.9, "w": wl}]
	elif _call_t >= 0.0:
		var cx := human.chest_xf()
		var up := (cx.basis * Vector3(0, 1, 0)).normalized()
		var fwd2 := (cx.basis * Vector3(0, 0, 1)).normalized()
		var left := (cx.basis * Vector3(1, 0, 0)).normalized()
		var sh := human.shoulder_world("L")
		var w := clampf(_call_t / 0.25, 0.0, 1.0) * clampf((1.7 - _call_t) / 0.3, 0.0, 1.0)
		var wave := sin(_call_t * 9.0)
		# bras levé vers l'avant, la main fait signe de venir
		var pos := sh + up * (0.36 + 0.08 * wave) + fwd2 * (0.32 - 0.1 * wave) + left * 0.08
		out[1] = {"pos": pos, "f": (up * (0.8 + 0.3 * wave) + fwd2 * (0.4 - 0.5 * wave)).normalized(), "p": -fwd2, "curl": 0.15 + 0.3 * maxf(wave, 0.0), "w": w}
	return out


## Invite contextuelle : [touches, texte] ou []
func context_prompt() -> Array:
	if _grab_bin != null:
		return [["E"], "Relâcher pour poser la poubelle"]
	match current_item:
		1:
			return [["CLIC GAUCHE"], "Tirer"] if aiming else [["CLIC DROIT"], "Maintenir pour viser"]
		2:
			return [["CLIC GAUCHE"], "Lancer"]
		3:
			return igniter.prompt()
		4:
			if flare_tool.flare == null:
				return [["R"], "Plus de fumigènes"]
			if not flare_tool.is_lit():
				return [["CLIC GAUCHE"], "Craquer le fumigène"]
			return [["CLIC DROIT", "CLIC GAUCHE"], "Brandir · Lancer"]
	return []


func interact_prompt() -> String:
	if _grab_bin != null or igniter.busy:
		return ""
	if near_pick != null:
		return "Ramasser " + Burnable.label_of(near_pick.kind)
	if near_bin != null and near_bin.tipped:
		return "Redresser la poubelle"
	if near_bin != null:
		return ("Fermer" if near_bin.lid_open else "Ouvrir") + " · maintenir : déplacer"
	if igniter.held != null:
		return "Poser " + igniter.held_label()
	return ""


func _aim_point() -> Vector3:
	return camera.global_position + (-camera.global_basis.z) * 60.0


## Point visé par le réticule (rayon caméra) : [position, touche quelque chose]
func _aim_target() -> Array:
	var from := camera.global_position
	var fwd := -camera.global_basis.z
	var to := from + fwd * 45.0
	var q := PhysicsRayQueryParameters3D.create(from + fwd * 0.6, to, 1 | 32)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r:
		return [r["position"], true]
	return [to, false]


func _update_camera(delta: float, speed: float) -> void:
	_fp_blend = move_toward(_fp_blend, 1.0 if first_person else 0.0, delta * 6.0)
	var e := _fp_blend * _fp_blend * (3.0 - 2.0 * _fp_blend)
	var k := clampf(maxf(maxf(mortar.aim_t, thrower.aim_t), igniter.aim_t), 0.0, 1.0)
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
