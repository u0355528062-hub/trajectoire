class_name Player
extends CharacterBody3D
## Contrôleur première personne : déplacement, regard souris,
## balancement de tête et détection des objets interactifs.

signal focus_changed(target: Interactable)

const WALK_SPEED := 2.6
const SPRINT_SPEED := 4.2
const ACCEL := 12.0
const EYE_HEIGHT := 1.68

var input_enabled := true
var camera: Camera3D
var head: Node3D
var ray: RayCast3D
var focused: Interactable

var _yaw := 0.0
var _pitch := 0.0
var _bob_t := 0.0
var _focus_tween: Tween
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
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
	camera.far = 200.0
	head.add_child(camera)
	camera.current = true

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.4)
	ray.collision_mask = 1 | (1 << (Interactable.LAYER - 1))
	ray.collide_with_areas = true
	ray.collide_with_bodies = true
	ray.add_exception(self)
	camera.add_child(ray)

	Game.settings_changed.connect(_on_settings_changed)


func _on_settings_changed() -> void:
	if camera:
		camera.fov = float(Game.settings["fov"])


func set_look(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch
	rotation.y = _yaw
	head.rotation.x = _pitch


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = float(Game.settings["sensitivity"]) * 0.01
		_yaw -= event.relative.x * s
		_pitch = clampf(_pitch - event.relative.y * s, deg_to_rad(-85), deg_to_rad(85))
		rotation.y = _yaw
		head.rotation.x = _pitch
	elif event.is_action_pressed("interact") or event.is_action_pressed("interact_mouse"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and focused and focused.enabled:
			get_viewport().set_input_as_handled()
			focused.interact()


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	var sprint := false
	if input_enabled:
		var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = (transform.basis * Vector3(iv.x, 0, iv.y))
		dir.y = 0
		if dir.length_squared() > 1.0:
			dir = dir.normalized()
		sprint = Input.is_action_pressed("sprint")
	var speed := SPRINT_SPEED if sprint else WALK_SPEED
	var target := dir * speed
	velocity.x = lerpf(velocity.x, target.x, 1.0 - exp(-ACCEL * delta))
	velocity.z = lerpf(velocity.z, target.z, 1.0 - exp(-ACCEL * delta))
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = maxf(velocity.y, -0.1)
	move_and_slide()

	# Balancement de tête
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var bob_offset := Vector3.ZERO
	if Game.settings["head_bob"] and hspeed > 0.3 and is_on_floor():
		_bob_t += delta * hspeed * 2.6
		bob_offset = Vector3(cos(_bob_t * 0.5) * 0.018, absf(sin(_bob_t)) * 0.03, 0)
	else:
		_bob_t = 0.0
	camera.position = camera.position.lerp(bob_offset, 1.0 - exp(-10.0 * delta))

	_update_focus()


func _update_focus() -> void:
	var hit: Interactable = null
	if input_enabled and ray.is_colliding():
		var col := ray.get_collider()
		if col is Interactable and (col as Interactable).enabled:
			hit = col
	if hit != focused:
		focused = hit
		focus_changed.emit(focused)


## Oriente doucement la caméra vers un point (utilisé pendant la consultation).
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
