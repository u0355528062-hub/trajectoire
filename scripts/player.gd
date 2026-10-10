class_name Player
extends CharacterBody3D
## Joueur : déplacement, caméra 1re/3e personne, inventaire (1 mortier, 2 pierres,
## 3 briquet + journal, 4 fumigène, 5 petits pétards, 6 pétards moyens), coup de pied, poubelles (E),
## appel à la foule (G).

signal view_changed(first_person: bool)
signal item_changed(index: int)         # 0 = mains libres, 1 mortier, 2 pierres, 3 briquet, 4 fumigène, 5-6 pétards
signal ammo_changed(count: int, maximum: int)
signal message(text: String)
signal stage_changed(label: String, progress: float)
signal aim_changed(on: bool)
signal near_breakable_changed(near: bool)
signal flares_changed(count: int, maximum: int)
signal petards_changed(small: int, small_max: int, medium: int, medium_max: int)
signal arrested                       # menotté : fin de partie
signal hurt(kind: String)

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
var petard_tool: PetardTool
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
var near_lift: Node3D            # barrière (ou autre) à terre qu'on peut redresser
var _e_lift: Node3D
var near_car: PoliceVehicle      # voiture dont on peut escalader le capot
var _e_car: PoliceVehicle
var _mantle_t := -1.0            # escalade du capot en cours
var _mantle_car: PoliceVehicle
var _mantle_from := Vector3.ZERO
var _mantle_local := Vector3.ZERO
var _mantle_yaw := 0.0
var _mantle_mask := 0
const MANTLE_DUR := 1.3
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
# --- état physique (mise à jour police)
var gas_level := 0.0              # lacrymo respiré (0..1) : flou, toux, ralentissement
var pepper_level := 0.0           # gazeuse reçue : yeux fermés, flou rouge
var hit_flash := 0.0              # flash rouge après un coup
var eye_close := 0.0              # paupières (0 ouvert .. 1 fermé)
var injured_t := 0.0              # blessé : ralenti
var down_t := 0.0                 # à terre
var arrest_phase := ""            # "", "grabbed" (agrippé), "cuffed" (menotté)
var struggle := 0.0               # jauge de lutte
var rescue_hold := 0.0            # des manifestants accourent : le compte à rebours des menottes ralentit
var arrest_cops: Array = []
var invuln_t := 0.0               # après s'être libéré : pas de nouvelle prise tout de suite
var wanted := 0.0                 # recherché (0..1) : les policiers le prennent pour cible
var _gas_in := 0.0
var _cough_t := 0.0
var _hit_chain := 0.0
var _arrest_t := 0.0
var _cuff_t := 0.0
var _down_e := 0.0
var _cuffs: Node3D
var _fall_dir := 0.0
var _over_sent := false
# --- animations du joueur
var crouching := false
var _crouch_e := 0.0
var _emote := ""
var _emote_w := 0.0
var _emote_t := 0.0
var _emote_evt := 0.0
var _still_t := 0.0
var _fidget := ""
var _fidget_t := 0.0
var _fidget_w := 0.0
var _fidget_cd := 8.0
var _phone: Node3D
var _fidget_forced := ""          # (mise au point)
var ring_t := 0.0                 # acouphène après une détonation toute proche
var _ring_snd: AudioStreamPlayer
var _cap: CapsuleShape3D
var _cap_node: CollisionShape3D
var _aim_evt := 0.0
var _voice: AudioStreamPlayer3D


func _ready() -> void:
	_rng.randomize()
	add_to_group("player")
	_register_inputs()

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.76
	col.shape = cap
	col.position.y = 0.88
	add_child(col)
	_cap = cap
	_cap_node = col
	collision_mask = 1 | 16 | 32 | 64
	floor_snap_length = 0.25
	platform_floor_layers = 0     # ne jamais « hériter » la vitesse d'un corps sous les pieds (policier, PNJ)
	platform_wall_layers = 0
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
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
	petard_tool = PetardTool.new()
	petard_tool.attach_to(human)
	petard_tool.aim_target_provider = Callable(self, "_aim_target")
	petard_tool.exclude_rid = get_rid()
	petard_tool.speed = 13.0
	petard_tool.message.connect(func(t): message.emit(t))
	petard_tool.thrown.connect(func(): _shake = 0.2)
	petard_tool.counts_changed.connect(func(a, b, c, d): petards_changed.emit(a, b, c, d))
	petard_tool.blown_in_hand.connect(func(sz, pos): on_blast(0.0, pos, sz))
	human.hand_provider = Callable(self, "_hands")
	_tool_hands = Callable(mortar, "_hand_targets")
	_voice = AudioStreamPlayer3D.new()
	_voice.bus = &"Voix"
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
		"slot_5": [KEY_5, KEY_KP_5],
		"slot_6": [KEY_6, KEY_KP_6],
		"interact": [KEY_E],
		"call_crowd": [KEY_G],
		"reload_cheat": [KEY_R],
		"kick": [KEY_F],
		"crouch": [KEY_C],
		"emote_fist": [KEY_B],
		"emote_clap": [KEY_N],
		"emote_hands": [KEY_X],
		"emote_finger": [KEY_T],
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
	return mortar.busy or thrower.busy or igniter.busy or flare_tool.busy or petard_tool.busy


func _busy() -> bool:
	return _tools_busy() or human.kick_t >= 0.0 or _grab_bin != null or _lift_t >= 0.0


## 0 = mains libres, 1 = mortier, 2 = pierres, 3 = briquet + journal, 4 = fumigène, 5-6 = pétards (petit, moyen)
func select_item(i: int) -> void:
	if _tools_busy() or i == current_item or _lift_t >= 0.0:
		return
	mortar.set_equipped(i == 1)
	thrower.set_equipped(i == 2)
	igniter.set_equipped(i == 3)
	if i == 5 or i == 6:
		petard_tool.select_size(1 if i == 5 else 2)
		petard_tool.set_equipped(true)
	else:
		petard_tool.set_equipped(false)
	if i == 4:
		flare_tool.set_equipped(true)
	elif i == 0 and flare_tool.is_lit():
		flare_tool.set_equipped(false, true)     # mains libres : le fumigène allumé reste dans la main
	else:
		flare_tool.set_equipped(false)
	if i != 1 and i != 0:
		mortar.hide_now()
	if i != 2 and i != 0:
		thrower.hide_now()
	if i != 3:
		igniter.hide_now()
	if i != 5 and i != 6:
		petard_tool.hide_now()
	if i != 4 and not flare_tool.carrying:
		flare_tool.hide_now()
	match i:
		0: _tool_hands = Callable(flare_tool, "_hand_targets") if flare_tool.carrying else Callable()
		1: _tool_hands = Callable(mortar, "_hand_targets")
		2: _tool_hands = Callable(thrower, "_hand_targets")
		3: _tool_hands = Callable(igniter, "_hand_targets")
		4: _tool_hands = Callable(flare_tool, "_hand_targets")
		5, 6: _tool_hands = Callable(petard_tool, "_hand_targets")
	current_item = i
	if aiming:
		aiming = false
		aim_changed.emit(false)
	item_changed.emit(i)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = MOUSE_SENS * float(Settings.d["sensitivity"])
		_yaw -= event.relative.x * sens
		_pitch = clampf(_pitch - event.relative.y * sens * (-1.0 if Settings.d["invert_y"] else 1.0), deg_to_rad(-80.0), deg_to_rad(85.0))
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var dirn := 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
		if _grab_bin == null:
			select_item(posmod(current_item + dirn, 7))
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
	elif _grab_bin == null and event.is_action_pressed("slot_5"):
		select_item(0 if current_item == 5 else 5)
	elif _grab_bin == null and event.is_action_pressed("slot_6"):
		select_item(0 if current_item == 6 else 6)
	elif event.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _grab_bin == null:
		match current_item:
			1: mortar.try_fire()
			2: thrower.throw_stone()
			3: igniter.use()
			4: flare_tool.use()
			5, 6: petard_tool.use()
			0:
				if flare_tool.carrying:
					flare_tool.use()
	elif event.is_action_pressed("crouch") and arrest_phase == "" and down_t <= 0.0 and not _busy():
		crouching = not crouching
	elif event.is_action_pressed("kick") and not aiming and not _busy() and is_on_floor():
		_kick_yaw = _yaw
		human.start_kick()
	elif event.is_action_pressed("call_crowd"):
		call_crowd()
	elif event.is_action_pressed("reload_cheat"):
		mortar.reload_all()
		flare_tool.reload_all()
		petard_tool.reload_all()
		message.emit("Obus, fumigènes et pétards rechargés")
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and false:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	# --- entrée
	var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wants_run := Input.is_action_pressed("run") and iv.y <= 0.3 and iv.length() > 0.1 and not crouching
	_run_t = move_toward(_run_t, 1.0 if wants_run else 0.0, delta * 4.0)
	var target_speed := lerpf(WALK_SPEED, RUN_SPEED, _run_t)
	if _tools_busy() or (aiming and current_item != 4):
		target_speed = minf(target_speed, WALK_SPEED * 0.55)
		_run_t = 0.0
	if _grab_bin != null:
		target_speed = minf(target_speed, WALK_SPEED * 0.9)
		_run_t = 0.0
	if igniter.busy or _lift_t >= 0.0 or _mantle_t >= 0.0 or arrest_phase != "" or down_t > 0.0:
		target_speed = 0.0   # les deux pieds au sol pendant qu'on dépose / allume / redresse / est maîtrisé
		_run_t = 0.0
	target_speed *= _status_speed() * lerpf(1.0, 0.55, _crouch_e)
	var kicking := human.kick_t >= 0.0
	if kicking:
		target_speed = 0.0
		_run_t = 0.0

	if current_item == 0 and _tool_hands.is_valid() and not flare_tool.carrying:
		_tool_hands = Callable()
	var want_aim := (current_item != 0 or flare_tool.carrying) and Input.is_action_pressed("aim") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not kicking and _grab_bin == null
	if want_aim != aiming:
		aiming = want_aim
		aim_changed.emit(aiming and current_item in [1, 2, 5, 6])
		mortar.set_aim(aiming and current_item == 1)
		thrower.set_aim(aiming and current_item == 2)
		igniter.set_aim(aiming and current_item == 3)
		flare_tool.set_aim(aiming and (current_item == 4 or flare_tool.carrying))
		petard_tool.set_aim(aiming and (current_item == 5 or current_item == 6))
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
		if Input.is_action_just_pressed("jump") and not kicking and _grab_bin == null and arrest_phase == "" and down_t <= 0.0:
			if crouching:
				crouching = false            # se relever d'abord
			else:
				velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= GRAVITY * delta
	if _mantle_t >= 0.0:
		_step_mantle(delta)
	else:
		move_and_slide()
		_push_bodies()

	# --- orientation du corps
	var face_cam := first_person or current_item != 0 or _grab_bin != null
	var target_yaw := human.rotation.y
	if kicking:
		target_yaw = _kick_yaw
	elif igniter.busy and not is_nan(igniter.lock_yaw):
		target_yaw = igniter.lock_yaw
	elif _mantle_t >= 0.0:
		target_yaw = _mantle_yaw
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
	_update_status(delta)
	_update_gestures(delta, iv)
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
	petard_tool.step(delta)
	var speed := Vector3(velocity.x, 0, velocity.z).length()
	var run_blend := clampf((speed - WALK_SPEED) / (RUN_SPEED - WALK_SPEED), 0.0, 1.0)
	human.animate(delta, speed, run_blend, is_on_floor() and _mantle_t < 0.0, velocity.y if _mantle_t < 0.0 else 1.6, _pitch)
	_update_camera(delta, speed)


# =================================================================== accroupi, gestes, petits gestes d'attente
func _update_gestures(delta: float, iv: Vector2) -> void:
	if arrest_phase != "" or down_t > 0.0:
		crouching = false
	_crouch_e = move_toward(_crouch_e, 1.0 if crouching else 0.0, delta * 5.0)
	var ce := _crouch_e * _crouch_e * (3.0 - 2.0 * _crouch_e)
	human.crouch_user = 0.8 * ce
	# gestes (maintenir la touche)
	var want := ""
	if arrest_phase == "" and down_t <= 0.0 and _lift_t < 0.0 and not _grab_bin and not igniter.busy and human.kick_t < 0.0:
		if Input.is_action_pressed("emote_fist"):
			want = "fist"
		elif Input.is_action_pressed("emote_clap"):
			want = "clap"
		elif Input.is_action_pressed("emote_hands"):
			want = "hands"
		elif Input.is_action_pressed("emote_finger"):
			want = "finger"
	if want != "" and current_item != 0 and not _tools_busy():
		select_item(0)
	if want != "" and (current_item != 0 or _tools_busy()):
		want = ""
	if want != _emote:
		_emote_t = 0.0
		if want != "":
			_emote = want
	if want == "" and _emote_w <= 0.01:
		_emote = ""
	_emote_w = move_toward(_emote_w, 1.0 if want != "" else 0.0, delta * 6.0)
	if want != "":
		_emote_t += delta
		_emote_evt -= delta
		if _emote_evt <= 0.0 and _emote_t > 0.6:
			_emote_evt = 2.5
			get_tree().call_group("crowd", "on_event", "player_gesture", {"kind": want, "pos": global_position, "dir": -cam_yaw.global_basis.z})
		if want == "hands":
			wanted = maxf(wanted - delta * 0.08, 0.0)       # les mains en l'air apaisent la police
		elif want == "finger" and _emote_t > 0.4:
			wanted = minf(wanted + delta * 0.05, 1.0)       # provocation : les CRS ne l'oublient pas
	# petits gestes d'attente : on regarde autour, on frotte les mains, on sort le téléphone
	var idle := iv.length() < 0.1 and is_on_floor() and _busy() == false and aiming == false and want == "" and arrest_phase == "" and down_t <= 0.0 and gas_level < 0.2
	if idle and current_item == 0:
		_still_t += delta
	else:
		_still_t = 0.0
		if _fidget != "":
			_fidget = ""
			_fidget_t = 0.0
	if _fidget == "" and _still_t > _fidget_cd and not first_person:
		_fidget = ["look", "rub", "phone", "look", "stretch"][_rng.randi() % 5]
		if _fidget_forced != "":
			_fidget = _fidget_forced
			_fidget_forced = ""
		_fidget_t = 0.0
		_fidget_cd = _rng.randf_range(6.0, 12.0)
	if _fidget != "":
		_fidget_t += delta
		var dur: float = {"look": 5.2, "rub": 4.0, "phone": 6.5, "stretch": 3.2}.get(_fidget, 4.0)
		if _fidget_t > dur:
			_fidget = ""
			_still_t = 0.0
	_fidget_w = move_toward(_fidget_w, 1.0 if (_fidget != "" and _fidget in ["rub", "phone", "stretch"]) else 0.0, delta * 4.0)
	# regard qui se promène
	if _fidget == "look":
		var yaw_off := sin(_fidget_t * 1.3) * 1.0 + sin(_fidget_t * 0.6) * 0.5
		var yb := Basis(Vector3.UP, human.rotation.y + yaw_off)
		human.look_target = human.head_world() + yb * Vector3(0, 0.05, -4.0)
		human.look_w = lerpf(human.look_w, 1.0, minf(1.0, delta * 4.0))
	else:
		human.look_w = lerpf(human.look_w, 0.0, minf(1.0, delta * 5.0))
	# le téléphone sorti pendant « phone »
	if _fidget == "phone" and _phone == null:
		_phone = Props.phone("feed")
		_phone.top_level = true
		add_child(_phone)
	if _phone != null:
		_phone.visible = _fidget == "phone" and _fidget_w > 0.3
		if _phone.visible:
			var pr := human.palm("R")
			var f: Vector3 = pr["f"]
			var p: Vector3 = pr["p"]
			_phone.global_transform = Transform3D(Props.basis_up(f, p), (pr["pos"] as Vector3) + p * 0.018 + f * 0.012)


func _bdir(v: Vector3) -> Vector3:
	var yb := Basis(Vector3.UP, human.rotation.y)
	return yb * Vector3(v.x, v.y, -v.z)


## Mains pour les gestes volontaires et les petits gestes d'attente (repère corps : x droite, y haut, z devant)
func _gesture_hands() -> Array:
	var yb := Basis(Vector3.UP, human.rotation.y)
	var k := human.arm_length() / 0.58
	var shr := human.shoulder_world("R")
	var shl := human.shoulder_world("L")
	var t := Time.get_ticks_msec() / 1000.0
	var mid := (shr + shl) * 0.5
	var r: Variant = null
	var l: Variant = null
	var w := _emote_w if _emote != "" and _emote_w > 0.01 else _fidget_w
	var kind := _emote if (_emote != "" and _emote_w > 0.01) else _fidget
	match kind:
		"fist":
			var pump := sin(_emote_t * 5.6)
			r = {"pos": shr + _bdir(Vector3(0.04, 0.5 + 0.05 * pump, 0.08) * k), "f": _bdir(Vector3(0, 1, 0.15)), "p": _bdir(Vector3(-1, 0, 0)), "curl": 1.0, "w": w}
			l = {"pos": shl + _bdir(Vector3(-0.06, -0.42, -0.02) * k), "f": _bdir(Vector3(0.3, -0.75, 0.55)), "p": _bdir(Vector3(1, 0, 0)), "curl": 0.2, "w": w}
		"clap":
			var gap := 0.035 + 0.11 * (0.5 + 0.5 * sin(_emote_t * 17.0))
			var c := mid + _bdir(Vector3(0, -0.22, 0.34) * k)
			r = {"pos": c + _bdir(Vector3(gap, 0, 0)), "f": _bdir(Vector3(0, 0.35, 0.9)), "p": _bdir(Vector3(-1, 0, 0)), "curl": 0.12, "w": w}
			l = {"pos": c - _bdir(Vector3(gap, 0, 0)), "f": _bdir(Vector3(0, 0.35, 0.9)), "p": _bdir(Vector3(1, 0, 0)), "curl": 0.12, "w": w}
		"finger":
			# bras tendu vers l'avant, dos de la main vers la cible, majeur dressé
			var jab := 0.04 * maxf(sin(_emote_t * 7.0), 0.0)
			r = {"pos": shr + _bdir(Vector3(0.02, 0.14 + jab * 0.5, 0.62 + jab) * k), "f": _bdir(Vector3(0, 1, 0.2)), "p": _bdir(Vector3(0, -0.15, -1)), "curl": 1.0, "middle": 1.0, "thumb": 1.0, "w": w}
			l = {"pos": shl + _bdir(Vector3(-0.04, -0.42, 0.0) * k), "f": _bdir(Vector3(0.2, -0.8, 0.5)), "p": _bdir(Vector3(1, 0, 0)), "curl": 0.5, "w": w}
		"hands":
			var sway := sin(t * 3.0) * 0.012
			r = {"pos": shr + _bdir(Vector3(0.12, 0.4 + sway, 0.12) * k), "f": _bdir(Vector3(0.1, 1, 0.2)), "p": _bdir(Vector3(0, 0, 1)), "curl": 0.05, "w": w}
			l = {"pos": shl + _bdir(Vector3(-0.12, 0.4 - sway, 0.12) * k), "f": _bdir(Vector3(-0.1, 1, 0.2)), "p": _bdir(Vector3(0, 0, 1)), "curl": 0.05, "w": w}
		"rub":
			var rub := sin(_fidget_t * 9.0)
			var c2 := mid + _bdir(Vector3(0, -0.24, 0.36) * k)
			r = {"pos": c2 + _bdir(Vector3(0.03 + 0.02 * rub, 0.0, 0.0)), "f": _bdir(Vector3(0, 0.3, 1)), "p": _bdir(Vector3(-1, 0, 0)), "curl": 0.3, "w": w}
			l = {"pos": c2 - _bdir(Vector3(0.03 - 0.02 * rub, 0.0, 0.0)), "f": _bdir(Vector3(0, 0.3, 1)), "p": _bdir(Vector3(1, 0, 0)), "curl": 0.3, "w": w}
		"phone":
			var u := clampf(_fidget_t / 0.6, 0.0, 1.0) * clampf((6.5 - _fidget_t) / 0.6, 0.0, 1.0)
			r = {"pos": shr + _bdir(Vector3(-0.1, -0.3 + 0.0, 0.3) * k) + Vector3(0, sin(t * 0.7) * 0.01, 0), "f": _bdir(Vector3(0, 0.6, 0.8)), "p": _bdir(Vector3(0, 0.8, -0.6)), "curl": 0.55, "w": w * u}
		"stretch":
			var u2 := clampf(_fidget_t / 0.5, 0.0, 1.0) * clampf((3.2 - _fidget_t) / 0.5, 0.0, 1.0)
			var hd := human.head_world()
			r = {"pos": hd + _bdir(Vector3(-0.11, -0.1, -0.1)), "f": _bdir(Vector3(0.5, 0.8, 0.2)), "p": _bdir(Vector3(-0.3, -0.3, 1)), "curl": 0.5, "w": w * u2}
			l = {"pos": hd + _bdir(Vector3(0.11, -0.1, -0.1)), "f": _bdir(Vector3(-0.5, 0.8, 0.2)), "p": _bdir(Vector3(0.3, -0.3, 1)), "curl": 0.5, "w": w * u2}
	return [r, l]


# =================================================================== état physique : gaz, coups, arrestation
func _status_speed() -> float:
	var k := 1.0
	if injured_t > 0.0:
		k *= 0.72
	k *= 1.0 - 0.35 * gas_level
	if pepper_level > 0.2:
		k *= 0.6
	return k


## Appelé à chaque image par les nuages de gaz (densité 0..1 à la position du joueur)
## Un secouriste soigne le joueur : yeux rincés, souffle repris, remis sur pied plus vite
## Geste en cours ("" si aucun) : "fist", "clap", "hands", "finger"
func gesture() -> String:
	return _emote if _emote_w > 0.5 else ""


func receive_aid(dt: float) -> void:
	pepper_level = maxf(pepper_level - dt * 0.4, 0.0)
	gas_level = maxf(gas_level - dt * 0.3, 0.0)
	if down_t > 0.0:
		down_t = maxf(down_t - dt * 1.2, 0.0)


func apply_gas(density: float) -> void:
	_gas_in = maxf(_gas_in, density)


func apply_pepper(amount := 1.0) -> void:
	if arrest_phase == "cuffed":
		return
	pepper_level = maxf(pepper_level, amount)
	hit_flash = maxf(hit_flash, 0.3)
	_shake = maxf(_shake, 0.4)
	_voice_say("pain")
	hurt.emit("pepper")


func _voice_say(cat: String) -> void:
	if _voice.playing:
		return
	var nm := AudioLib.pick("m1", cat)
	if nm == "":
		return
	_voice.stream = AudioLib.stream(nm)
	_voice.volume_db = 2.0
	_voice.play()


## Coup reçu (matraque, LBD, bousculade, projectile) ; `dir` : sens du choc
func take_hit(kind: String, dir: Vector3, power := 1.0) -> void:
	if arrest_phase == "cuffed" or invuln_t > 0.0 and kind == "shove":
		return
	var d := Vector3(dir.x, 0.0, dir.z)
	d = d.normalized() if d.length() > 0.01 else Vector3.ZERO
	hit_flash = 1.0 if kind in ["baton", "lbd"] else 0.45
	_shake = 1.0
	hurt.emit(kind)
	match kind:
		"baton":
			velocity += d * 3.5 * power
			injured_t = maxf(injured_t, 6.0)
			_hit_chain += 1.0
			AudioLib.play_at(self, "baton_hit_%d" % _rng.randi_range(0, 1), global_position + Vector3.UP, 0.0, 6.0)
			_voice_say("pain")
		"lbd":
			velocity += d * 2.2 * power
			injured_t = maxf(injured_t, 9.0)
			_hit_chain += 0.9
			AudioLib.play_at(self, "lbd_hit", global_position + Vector3.UP, 0.0, 6.0)
			_voice_say("pain")
		"shove":
			velocity += d * 5.0 * power
			_hit_chain += 0.5
		_:
			pass
	human.kick_back(1.0)
	if kind in ["baton", "lbd", "shove"] and (_hit_chain >= 1.9 or kind == "shove" and power > 1.2):
		knock_down(d, 1.8)


func knock_down(d: Vector3, dur := 1.6) -> void:
	if down_t > 0.0 or arrest_phase != "":
		return
	down_t = dur
	_hit_chain = 0.0
	if _tools_busy():
		pass
	var dl := Basis(Vector3.UP, human.rotation.y).inverse() * (d if d.length() > 0.01 else -Basis(Vector3.UP, human.rotation.y).z)
	_fall_dir = atan2(dl.x, dl.z)
	AudioLib.play_at(self, "body_fall", global_position, -2.0, 6.0)


## Un policier agrippe le joueur : séquence d'arrestation (lutte, puis menottes)
func begin_arrest(cop: Node3D) -> bool:
	if arrest_phase == "cuffed" or invuln_t > 0.0:
		return false
	if cop != null and not arrest_cops.has(cop):
		arrest_cops.append(cop)
	if arrest_phase == "":
		arrest_phase = "grabbed"
		struggle = 0.18
		_arrest_t = 0.0
		if current_item != 0:
			_lift_prev = 0
			if not _tools_busy():
				select_item(0)
		aiming = false
		message.emit("Interpellation ! Débats-toi avec ESPACE")
		_voice_say("arrested")
		_shake = 0.8
		# la foule voit la scène : certains foncent pour te libérer
		get_tree().call_group("crowd", "on_event", "grab", {"pos": global_position, "who": self, "cop": cop})
	return true


func release_cop(cop: Node3D) -> void:
	arrest_cops.erase(cop)


func break_free() -> void:
	if arrest_phase != "grabbed":
		return
	arrest_phase = ""
	struggle = 0.0
	invuln_t = 5.0
	wanted = maxf(wanted, 0.5)
	message.emit("Tu t'es libéré !")
	_shake = 1.0
	for c in arrest_cops:
		if is_instance_valid(c) and c.has_method("on_player_broke_free"):
			c.on_player_broke_free(global_position)
	arrest_cops.clear()
	velocity += -Basis(Vector3.UP, human.rotation.y).z * 2.0


## Souffle d'un pétard (ou d'un obus) tout près : secousse, acouphène, parfois à terre.
## k : distance normalisée (0 = dans la main, 1 = limite de portée)
func on_blast(k: float, from: Vector3, size: int) -> void:
	k = clampf(k, 0.0, 1.0)
	var d := global_position - from
	d.y = 0.0
	var power := (1.0 - k) * (1.0 if size >= 2 else 0.35)
	if d.length() > 0.05:
		velocity += d.normalized() * 3.6 * power
	ring_t = maxf(ring_t, (5.5 if size >= 2 else 1.8) * (0.4 + 0.6 * (1.0 - k)))
	hit_flash = maxf(hit_flash, 0.55 * power)
	_shake = maxf(_shake, 0.6 * power + 0.2)
	human.kick_back(0.8 * power + 0.2)
	if size >= 2 and k < 0.3 and down_t <= 0.0 and arrest_phase == "":
		injured_t = maxf(injured_t, 4.0)
		knock_down(d if d.length() > 0.05 else Vector3.BACK, 1.5)
		_voice_say("pain")


func _update_ring(delta: float) -> void:
	ring_t = maxf(ring_t - delta, 0.0)
	var rk := clampf(ring_t / 2.5, 0.0, 1.0)
	Settings.set_ring(rk)
	if _ring_snd == null:
		_ring_snd = AudioStreamPlayer.new()
		_ring_snd.stream = Sfx.get_stream(&"tinnitus")
		_ring_snd.volume_db = -80.0
		add_child(_ring_snd)
	if rk > 0.01:
		if not _ring_snd.playing:
			_ring_snd.play()
		_ring_snd.volume_db = lerpf(-46.0, -17.0, rk)
	elif _ring_snd.playing:
		_ring_snd.stop()


func _update_status(delta: float) -> void:
	_update_ring(delta)
	invuln_t = maxf(invuln_t - delta, 0.0)
	injured_t = maxf(injured_t - delta, 0.0)
	_hit_chain = maxf(_hit_chain - delta * 0.35, 0.0)
	hit_flash = move_toward(hit_flash, 0.0, delta * 2.2)
	pepper_level = move_toward(pepper_level, 0.0, delta * 0.11)
	# gaz : monte vite, redescend lentement
	var target := clampf(_gas_in, 0.0, 1.0)
	gas_level = move_toward(gas_level, target, delta * (0.45 if target > gas_level else 0.11))
	_gas_in = 0.0
	var t := Time.get_ticks_msec() / 1000.0
	var eyes := gas_level * (0.32 + 0.22 * sin(t * 2.7)) + pepper_level * 0.72
	if arrest_phase == "cuffed":
		eyes = maxf(eyes, 0.0)
	eye_close = move_toward(eye_close, clampf(eyes, 0.0, 0.92), delta * 3.0)
	# toux
	_cough_t -= delta
	if (gas_level > 0.3 or pepper_level > 0.4) and _cough_t <= 0.0 and down_t <= 0.0:
		_cough_t = _rng.randf_range(1.2, 2.4)
		AudioLib.play_at(self, "cough_m_%d" % _rng.randi_range(0, 2), global_position + Vector3.UP * 1.5, 0.0, 5.0)
		human.kick_back(0.6)
		human.hunch = 0.7
	human.hunch = move_toward(human.hunch, 0.35 * maxf(gas_level, pepper_level) if gas_level > 0.3 or pepper_level > 0.3 else 0.0, delta * 1.5)
	# à terre
	if down_t > 0.0:
		down_t -= delta
	var fall_target := 1.0 if (down_t > 0.5 or arrest_phase == "cuffed" and false) else 0.0
	_down_e = move_toward(_down_e, fall_target, delta * (4.0 if fall_target > _down_e else 1.4))
	if _down_e > 0.001 or human.fall > 0.001:
		human.fall = _down_e
		human.fall_dir = _fall_dir
	# arrestation
	if arrest_phase == "grabbed":
		_arrest_t += delta
		if rescue_hold > 0.0:
			rescue_hold -= delta
			_arrest_t -= delta * 0.75
		if Input.is_action_just_pressed("jump"):
			struggle += 0.15 + _rng.randf() * 0.05
			_shake = maxf(_shake, 0.35)
			human.kick_back(0.7)
		struggle = maxf(struggle - delta * (0.14 + 0.1 * arrest_cops.size()), 0.0)
		arrest_cops = arrest_cops.filter(func(c): return is_instance_valid(c))
		if struggle >= 1.0:
			break_free()
		elif _arrest_t > 4.2 + (0.0 if arrest_cops.size() > 0 else 99.0):
			arrest_phase = "cuffed"
			_cuff_t = 0.0
			AudioLib.play_at(self, "cuff_click", global_position + Vector3.UP, 0.0, 4.0)
			message.emit("Menotté.")
		elif arrest_cops.is_empty() and _arrest_t > 0.6:
			arrest_phase = ""           # plus personne ne te tient
			struggle = 0.0
	elif arrest_phase == "cuffed":
		_cuff_t += delta
		human.kneel = move_toward(human.kneel, 1.0, delta * 1.1)
		if _cuff_t > 2.2 and not _over_sent:
			_over_sent = true
			arrested.emit()
	else:
		human.kneel = move_toward(human.kneel, 0.0, delta * 2.0)


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
	# barrière à terre devant soi
	near_lift = null
	if _grab_bin == null and not _tools_busy() and human.kick_t < 0.0:
		var best2 := 1.9
		var fwd3 := -cam_yaw.global_basis.z
		for o in get_tree().get_nodes_in_group("liftables"):
			if not o.has_method("is_down") or not o.is_down():
				continue
			var d3 := (o as Node3D).global_position - global_position
			d3.y = 0.0
			var l3 := d3.length()
			if l3 < best2 and (l3 < 1.0 or fwd3.dot(d3 / maxf(l3, 0.01)) > 0.2):
				best2 = l3
				near_lift = o
		if near_lift != null and near_bin != null:
			var d4 := (near_bin.global_position - global_position) * Vector3(1, 0, 1)
			if d4.length() < best2:
				near_lift = null
	# voiture garée à escalader (capot)
	near_car = null
	if _grab_bin == null and _mantle_t < 0.0 and not _tools_busy() and human.kick_t < 0.0 and is_on_floor() and arrest_phase == "" and down_t <= 0.0:
		for v in get_tree().get_nodes_in_group("vehicles"):
			var car := v as PoliceVehicle
			if car == null or car.kind != "car" or not car.is_parked() or car.burning:
				continue
			var lc := car.to_local(global_position)
			# devant le pare-chocs ou sur le côté, à portée de main du capot
			var front := lc.z < -2.1 and lc.z > -3.5 and absf(lc.x) < 1.2
			var side := absf(lc.x) > 0.95 and absf(lc.x) < 2.1 and lc.z < -0.7 and lc.z > -2.1
			if front or side:
				var tgt_w := car.to_global(Vector3(clampf(lc.x, -0.4, 0.4) * 0.5, 0.98, -1.5))
				var dd := tgt_w - global_position
				dd.y = 0.0
				if (-cam_yaw.global_basis.z).dot(dd.normalized()) > 0.3:
					near_car = car
					break
		if near_car != null and (near_bin != null or igniter.find_pickable() != null):
			near_car = null
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
		_e_lift = near_lift
		_e_car = near_car
	if _e_t >= 0.0:
		if Input.is_action_pressed("interact"):
			_e_t += delta
			if _e_t > 0.32 and _grab_bin == null and _e_bin != null and is_instance_valid(_e_bin) and not _e_bin.tipped and not _tools_busy() and human.kick_t < 0.0:
				_start_grab(_e_bin)
		else:
			if _grab_bin != null:
				_end_grab()
			elif _e_car != null and is_instance_valid(_e_car) and _e_t <= 0.5:
				start_mantle(_e_car)
			elif _e_lift != null and is_instance_valid(_e_lift) and _e_lift.has_method("is_down") and _e_lift.is_down() and _e_t <= 0.6:
				var lob := _e_lift
				var yaw_l := human.rotation.y
				start_lift(lob, func(): if is_instance_valid(lob): lob.right_up(yaw_l, 0.85), 1.5)
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
			_e_lift = null
			_e_car = null
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
	if _tool_hands.is_valid() and arrest_phase == "" and down_t <= 0.0:
		out = _tool_hands.call()
	if arrest_phase == "" and down_t <= 0.0 and ((_emote != "" and _emote_w > 0.01) or _fidget_w > 0.01) and gas_level < 0.4 and pepper_level < 0.35 and _lift_t < 0.0:
		var gh := _gesture_hands()
		for i in 2:
			if gh[i] != null:
				out[i] = gh[i]
		return out
	if arrest_phase != "" or down_t > 0.0 or gas_level > 0.4 or pepper_level > 0.35:
		return _status_hands(out)
	if _grab_bin != null:
		var fwd := Basis(Vector3.UP, human.rotation.y) * Vector3(0, 0, -1)
		out = [{"pos": _grab_bin.handle_world(0.13) + Vector3.UP * 0.03, "f": fwd, "p": Vector3.DOWN, "curl": 0.95, "w": 1.0},
			{"pos": _grab_bin.handle_world(-0.13) + Vector3.UP * 0.03, "f": fwd, "p": Vector3.DOWN, "curl": 0.95, "w": 1.0}]
	elif _mantle_t >= 0.0 and _mantle_car != null and is_instance_valid(_mantle_car):
		var ym := Basis(Vector3.UP, human.rotation.y)
		var fwm: Vector3 = ym * Vector3(0, 0, -1)
		var rgm: Vector3 = ym * Vector3(1, 0, 0)
		var um := _mantle_t / MANTLE_DUR
		var wm := _smooth(um / 0.2) * (1.0 - _smooth((um - 0.7) / 0.25))
		var hood := _mantle_car.to_global(_mantle_local)
		var hp := Vector3(hood.x, hood.y + 0.03, hood.z) - fwm * 0.35 + fwm * (0.25 * _smooth(um / 0.7))
		out = [{"pos": hp + rgm * 0.22, "f": fwm, "p": Vector3.DOWN, "curl": 0.35, "w": wm},
			{"pos": hp - rgm * 0.22, "f": fwm, "p": Vector3.DOWN, "curl": 0.35, "w": wm}]
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


## Mains forcées par l'état : mains derrière le dos (arrêté), bras levés (au sol), mains sur le visage (gaz, gazeuse)
func _status_hands(out: Array) -> Array:
	var yb := Basis(Vector3.UP, human.rotation.y)
	var fwd: Vector3 = yb * Vector3(0, 0, -1)
	var rgt: Vector3 = yb * Vector3(1, 0, 0)
	var up := Vector3.UP
	var k := human.arm_length() / 0.58
	if arrest_phase != "":
		var shr := human.shoulder_world("R")
		var shl := human.shoulder_world("L")
		var back_r := shr - fwd * 0.12 * k - up * 0.5 * k - rgt * 0.02
		var back_l := shl - fwd * 0.12 * k - up * 0.5 * k + rgt * 0.02
		if arrest_phase == "cuffed":
			back_r = (shr + shl) * 0.5 - fwd * 0.16 * k - up * 0.55 * k - rgt * 0.045
			back_l = (shr + shl) * 0.5 - fwd * 0.16 * k - up * 0.55 * k + rgt * 0.045
		var w := 1.0
		var hr := {"pos": back_r, "f": -up * 0.7 - fwd * 0.2, "p": -rgt, "curl": 0.5, "w": w}
		var hl := {"pos": back_l, "f": -up * 0.7 - fwd * 0.2, "p": rgt, "curl": 0.5, "w": w}
		if arrest_phase == "grabbed":
			# le bras droit se débat devant, le gauche est tiré en arrière
			var tt := Time.get_ticks_msec() / 1000.0
			hr = {"pos": shr + fwd * 0.28 * k - up * 0.1 * k + rgt * sin(tt * 13.0) * 0.09, "f": fwd * 0.5 + up * 0.3, "p": -rgt, "curl": 0.8, "w": 1.0}
		return [hr, hl]
	if down_t > 0.0:
		var shr2 := human.shoulder_world("R")
		var shl2 := human.shoulder_world("L")
		return [{"pos": shr2 + fwd * 0.18 * k + up * 0.3 * k, "f": fwd * 0.3 + up * 0.8, "p": -rgt, "curl": 0.5, "w": 1.0},
			{"pos": shl2 + fwd * 0.2 * k + up * 0.25 * k, "f": fwd * 0.3 + up * 0.8, "p": rgt, "curl": 0.5, "w": 1.0}]
	# mains sur le visage
	var hd := human.head_world()
	var cw := clampf(maxf(gas_level - 0.3, pepper_level - 0.2) * 2.5, 0.0, 1.0)
	var wob := sin(Time.get_ticks_msec() / 1000.0 * 7.0) * 0.012
	var hr3 := {"pos": hd + fwd * 0.11 + rgt * 0.06 + up * (-0.02 + wob), "f": up * 0.8 - rgt * 0.3, "p": -fwd, "curl": 0.35, "w": cw}
	var hl3 := {"pos": hd + fwd * 0.11 - rgt * 0.06 + up * (-0.02 - wob), "f": up * 0.8 + rgt * 0.3, "p": -fwd, "curl": 0.35, "w": cw}
	if out[0] != null and cw < 0.6:
		return out
	return [hr3, hl3]


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
		5, 6:
			if not petard_tool.has_item():
				return [["R"], "Plus de pétards de ce type"]
			if not petard_tool.lit:
				return [["CLIC GAUCHE"], "Allumer la mèche"]
			return [["CLIC DROIT", "CLIC GAUCHE"], "Viser · Lancer (vite !)"]
		0:
			if flare_tool.carrying:
				return [["CLIC DROIT", "CLIC GAUCHE"], "Fumigène en main : brandir · lancer"]
	return []


func interact_prompt() -> String:
	if _grab_bin != null or igniter.busy:
		return ""
	if near_car != null and near_pick == null:
		return "Monter sur le capot"
	if near_lift != null and near_pick == null:
		return "Redresser " + str(near_lift.get("lift_label"))
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
	var k := clampf(maxf(maxf(mortar.aim_t, maxf(thrower.aim_t, petard_tool.aim_t)), igniter.aim_t), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	cam_pitch.rotation.x = _pitch
	spring.spring_length = lerpf(lerpf(3.1, 1.75, k), 0.0, e)
	spring.position.x = lerpf(lerpf(0.55, 0.62, k), 0.0, e)
	cam_pitch.position.z = lerpf(0.0, -0.10, e)
	# balancement de la tête en 1re personne + amorti à la réception
	_land_dip = move_toward(_land_dip, 0.0, delta * 0.35)
	var sp := clampf(speed / RUN_SPEED, 0.0, 1.0) * human._walk_w
	var bob_k := 1.0 if Settings.d["head_bob"] else 0.0
	var bob_y := sin(human.phase * TAU * 2.0) * (0.010 + 0.018 * _run_t) * sp * e * bob_k
	var bob_x := sin(human.phase * TAU) * (0.006 + 0.01 * _run_t) * sp * e * bob_k
	cam_yaw.position.y = EYE_HEIGHT + bob_y - _land_dip - 1.15 * _down_e - 0.62 * human.kneel - 0.5 * _crouch_e * _crouch_e * (3.0 - 2.0 * _crouch_e)
	cam_pitch.position.x = bob_x
	# champ de vision : s'ouvre en courant, se resserre en visant
	var fov_target := lerpf(float(Settings.d["fov"]) + 8.0 * _run_t, 46.0, k)
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
	var s := _shake * _shake * 0.02 * float(Settings.d["screen_shake"])
	camera.h_offset = _rng.randf_range(-s, s)
	camera.v_offset = _rng.randf_range(-s, s)


## Escalade du capot d'une voiture garée : mains sur la tôle, on se hisse, on se redresse debout dessus
func start_mantle(car: PoliceVehicle) -> void:
	if _mantle_t >= 0.0 or car == null or not car.is_parked():
		return
	_mantle_car = car
	_mantle_from = global_position
	var lc := car.to_local(global_position)
	_mantle_local = Vector3(clampf(lc.x, -0.45, 0.45) * 0.4, 0.98, -1.55)
	var tgt := car.to_global(_mantle_local)
	var d := tgt - global_position
	d.y = 0.0
	_mantle_yaw = atan2(-d.x, -d.z)
	_mantle_t = 0.0
	_mantle_mask = collision_mask
	collision_mask = 0
	_mantle_prev_item = current_item
	if current_item != 0:
		select_item(0)
	AudioLib.play_at(car, "sfx:car_creak", car.global_position + Vector3(0, 1.0, -1.4), -4.0, 8.0)
	get_tree().call_group("crowd", "on_event", "car_vandal", {"pos": tgt, "car": car, "amount": 0.015, "player": true})
	get_tree().call_group("crowd", "on_event", "player_mantle", {"pos": tgt, "car": car})


var _mantle_prev_item := 0


func _step_mantle(delta: float) -> void:
	_mantle_t += delta
	velocity = Vector3.ZERO
	if _mantle_car == null or not is_instance_valid(_mantle_car) or arrest_phase != "" or down_t > 0.0:
		_end_mantle(false)
		return
	var u := clampf(_mantle_t / MANTLE_DUR, 0.0, 1.0)
	var to := _mantle_car.to_global(_mantle_local)
	var up_k := _smooth(u / 0.55)
	var fw_k := _smooth((u - 0.28) / 0.72)
	var y := lerpf(_mantle_from.y, to.y + 0.1, up_k) - 0.1 * _smooth((u - 0.6) / 0.4)
	global_position = Vector3(lerpf(_mantle_from.x, to.x, fw_k), y, lerpf(_mantle_from.z, to.z, fw_k))
	if u >= 1.0:
		_end_mantle(true)


func _end_mantle(ok: bool) -> void:
	if _mantle_t < 0.0:
		return
	if ok and _mantle_car != null and is_instance_valid(_mantle_car):
		global_position = _mantle_car.to_global(_mantle_local) + Vector3.UP * 0.02
	collision_mask = _mantle_mask
	velocity = Vector3.ZERO
	_mantle_t = -1.0
	_mantle_car = null
	if _mantle_prev_item != 0 and ok:
		select_item(_mantle_prev_item)
	_mantle_prev_item = 0
