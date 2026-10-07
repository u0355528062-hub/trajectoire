class_name StreetProp
extends RigidBody3D
## Mobilier de rue vandalisable : scellé au sol au départ ; chaque coup de pied l'ébranle (secousse, bruit),
## puis il bascule. Les accessoires dérivés construisent leur apparence (`_build`) et réagissent au renversement.

var crowd: Crowd
var damage_limit := 3.0
var top_y := 1.0                      # hauteur où s'applique la poussée qui le renverse
var reach := Vector3(0.5, 1.4, 0.5)   # zone frappable : demi-largeur, hauteur max, demi-profondeur
var nav_half := Vector2.ZERO          # empreinte pour la navigation des PNJ (0 = aucune)
var toppled := false
var vandal_amount := 0.35
var hit_sound := "barrier_hit"
var fall_sound := "barrier_fall"
var _dmg := 0.0
var _model: Node3D
var _wob_t := -1.0
var _perm := Vector3.ZERO          # déformation permanente (poteau tordu...)
var _wob_axis := Vector3.RIGHT
var _nav_in := false
var _last_snd := 0.0


func _ready() -> void:
	add_to_group("kickable")
	collision_layer = 32
	collision_mask = 1 | 32 | 64
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	linear_damp = 0.3
	angular_damp = 0.8
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.15
	physics_material_override = pm
	_model = Node3D.new()
	add_child(_model)
	_build()
	body_entered.connect(_on_body)
	if nav_half != Vector2.ZERO and crowd != null:
		crowd.add_obstacle(self, nav_half, Vector2.ZERO, false, true)
		_nav_in = true


## À surcharger : construit le modèle (enfants de `_model`), les formes de collision, règle masse et limites
func _build() -> void:
	pass


func _on_toppled(_dir: Vector3) -> void:
	pass


func _on_wobble(_k: float) -> void:
	pass


func is_wreck() -> bool:
	return toppled


## Coup de pied (joueur ou PNJ)
func kick(point: Vector3, dir: Vector3, power := 1.0) -> bool:
	var l := to_local(point)
	if absf(l.x) > reach.x + 0.3 or absf(l.z) > reach.z + 0.3 or l.y > reach.y or l.y < -0.2:
		return false
	var d := Vector3(dir.x, 0, dir.z)
	d = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	if toppled:
		apply_impulse(d * mass * 1.8 * power, point - global_position)
		_snd(hit_sound, point, -3.0)
		return true
	_dmg += 1.0 if power >= 0.9 else 0.6
	_snd(hit_sound, point, -2.0)
	if _dmg >= damage_limit:
		topple(d)
	else:
		_wob_t = 0.0
		_wob_axis = d.cross(Vector3.UP).normalized()
		_on_wobble(_dmg / damage_limit)
	return true


func topple(dir: Vector3) -> void:
	if toppled:
		return
	toppled = true
	freeze = false
	sleeping = false
	var d := Vector3(dir.x, 0, dir.z).normalized()
	apply_impulse(d * mass * 2.2, global_basis.y * top_y)
	_snd(fall_sound, global_position + Vector3.UP * 0.5, -1.0)
	if _nav_in and crowd != null:
		crowd.remove_obstacle(self)
		_nav_in = false
	get_tree().call_group("crowd", "on_event", "vandal", {"pos": global_position, "amount": vandal_amount})
	_on_toppled(d)


func _physics_process(delta: float) -> void:
	if _wob_t >= 0.0 and _model != null:
		_wob_t += delta
		var k := exp(-_wob_t * 4.5) * sin(_wob_t * 30.0)
		_model.rotation = _perm + _wob_axis * k * 0.07
		if _wob_t > 1.4:
			_wob_t = -1.0
			_model.rotation = _perm


func _on_body(_b: Node) -> void:
	var sp := linear_velocity.length()
	if toppled and sp > 1.2:
		_snd(hit_sound, global_position, clampf(-12.0 + sp * 2.0, -12.0, 0.0))


func _snd(snd: String, pos: Vector3, vol: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_snd < 0.12:
		return
	_last_snd = now
	AudioLib.play_at(self, snd, pos, vol, 8.0, randf_range(0.9, 1.12))
