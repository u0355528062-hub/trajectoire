class_name FlareTool
extends Node3D
## Fumigène du joueur : clic gauche = dégoupiller (on dévisse le capuchon et on frotte),
## clic droit (maintenu) = le brandir au-dessus de la tête, clic gauche = le lancer.

signal message(text: String)
signal count_changed(count: int, maximum: int)

const MAX := 5
const SPEED := 12.0
const T_LIGHT := 1.0
const T_WIND := 0.24
const T_WHIP := 0.14
const T_FOLLOW := 0.45

var human: Human
var equipped := false
var carrying := false     # fumigène allumé gardé en main quand on range l'outil (mains libres)
var busy := false
var aim_t := 0.0       # = « brandir »
var equip_t := 0.0
var count := MAX
var flare: Flare
var aim_target_provider := Callable()

var _aim_input := false
var _t := -1.0
var _tt := -1.0
var _released := false
var _raise_sent := 0.0
var _rng := RandomNumberGenerator.new()
var _fresh := 1.0


func _ready() -> void:
	_rng.randomize()


func attach_to(h: Human) -> void:
	human = h
	h.add_child(self)


func _ensure_flare() -> void:
	if flare == null and count > 0:
		flare = Flare.new()
		flare.held = true
		flare.by_player = true
		flare.cast_shadows = true
		flare.burn_time = 50.0
		add_child(flare)
		flare.top_level = true
		flare.burnt_out.connect(_on_burnt_out)


func active() -> bool:
	return equipped or carrying


## on=false avec carry : on range l'outil mais le fumigène allumé reste dans la main
func set_equipped(on: bool, carry := false) -> void:
	if busy and not on:
		return
	if not on and carry and is_lit() and flare != null and flare.held:
		equipped = false
		carrying = true
		return
	carrying = false
	equipped = on
	if on:
		_ensure_flare()


func hide_now() -> void:
	equipped = false
	carrying = false
	equip_t = 0.0
	_t = -1.0
	_tt = -1.0
	busy = false
	if flare and flare.lit:
		_drop_current()
	if flare:
		flare.visible = false


func set_aim(on: bool) -> void:
	_aim_input = on and active()


func reload_all() -> void:
	count = MAX
	count_changed.emit(count, MAX)
	if active():
		_ensure_flare()


func is_lit() -> bool:
	return flare != null and flare.lit


func use() -> void:
	if not active() or busy or equip_t < 0.6:
		return
	if flare == null:
		message.emit("Plus de fumigènes (R pour recharger)")
		return
	busy = true
	if not flare.lit:
		_t = 0.0
	else:
		_tt = 0.0
		_released = false


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func step(delta: float) -> void:
	equip_t = move_toward(equip_t, 1.0 if active() else 0.0, delta * 3.0)
	var raise := _aim_input and is_lit() and _t < 0.0 and _tt < 0.0
	aim_t = move_toward(aim_t, 1.0 if raise else 0.0, delta * 2.8)
	_fresh = move_toward(_fresh, 1.0, delta * 2.0)
	if aim_t > 0.8 and Time.get_ticks_msec() / 1000.0 - _raise_sent > 3.0 and flare:
		_raise_sent = Time.get_ticks_msec() / 1000.0
		get_tree().call_group("crowd", "on_event", "flare_raise", {"pos": flare.global_position})
	if _t >= 0.0:
		_t += delta
		if _t >= 0.72 and flare and not flare.lit:
			flare.ignite()
		if _t >= T_LIGHT:
			_t = -1.0
			busy = false
	if _tt >= 0.0:
		_tt += delta
		if not _released and _tt >= T_WIND + T_WHIP:
			_released = true
			_release()
		if _tt >= T_WIND + T_WHIP + T_FOLLOW:
			_tt = -1.0
			busy = false
			_fresh = 0.0
			carrying = false
			if equipped:
				_ensure_flare()
	if flare:
		flare.visible = equip_t > 0.05 and _fresh > 0.05


func _on_burnt_out() -> void:
	if flare and flare.held:
		_drop_current.call_deferred()


func _drop_current() -> void:
	if flare == null:
		return
	var f := flare
	flare = null
	count = maxi(count - 1, 0)
	count_changed.emit(count, MAX)
	f.reparent(get_tree().current_scene, true)
	f.release(Vector3.UP * 0.5 + (-human.global_basis.z) * 0.8, Vector3(2, 0, 1))
	_fresh = 0.0
	carrying = false
	if equipped:
		_ensure_flare()


func _chest(p_rest: Vector3, cx: Transform3D) -> Vector3:
	return cx * (p_rest - human.rest["spine02"])


func _target() -> Array:
	var t: Array = [global_position + (-human.global_basis.z) * 12.0, false]
	if aim_target_provider.is_valid():
		t = aim_target_provider.call()
	# visée d'une poubelle ouverte : on vise son ouverture
	var p: Vector3 = t[0]
	for b in get_tree().get_nodes_in_group("bins"):
		var bin := b as TrashBin
		var c := bin.top_center()
		if bin.is_open() and Vector2(p.x - c.x, p.z - c.z).length() < 0.8 and p.y < c.y + 0.6:
			return [c + Vector3.DOWN * 0.15, true]
	return t


func _blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	return {
		"palm": (a["palm"] as Vector3).lerp(b["palm"], k),
		"f": Fx.vslerp(a["f"], b["f"], k).normalized(),
		"p": Fx.vslerp(a["p"], b["p"], k).normalized(),
		"curl": lerpf(a["curl"], b["curl"], k),
	}


func _hand_targets() -> Array:
	if equip_t <= 0.0 or human == null:
		return [null, null]
	var cx := human.chest_xf()
	var up := (cx.basis * Vector3(0, 1, 0)).normalized()
	var fwd := (cx.basis * Vector3(0, 0, 1)).normalized()
	var left := (cx.basis * Vector3(1, 0, 0)).normalized()
	var right := -left
	var sh := human.shoulder_world("R")
	var t := Time.get_ticks_msec() / 1000.0
	var drop := (1.0 - _ease(_fresh)) * 0.25
	var carry := {"palm": _chest(Vector3(-0.21, 0.99 - drop, 0.23), cx), "f": fwd, "p": left, "curl": 0.95}
	var held := {"palm": _chest(Vector3(-0.27, 1.05, 0.33), cx), "f": (fwd + up * 0.15).normalized(), "p": left, "curl": 0.95}
	var lighting := {"palm": _chest(Vector3(-0.09, 1.1, 0.3), cx), "f": fwd, "p": left, "curl": 0.95}
	var sway := right * sin(t * 2.3) * 0.07 + up * sin(t * 4.6) * 0.02
	var raised := {"palm": sh + up * 0.5 + fwd * 0.13 + right * 0.03 + sway, "f": (fwd + up * 0.3).normalized(), "p": left, "curl": 0.95}
	var tgt: Array = _target()
	var aim_dir := ArcPreview.solve(sh + up * 0.1, tgt[0], SPEED).normalized()
	# armé : la torche reste dressée (pouce vers le haut, légèrement penchée en arrière)
	var cocked := {"palm": sh + up * 0.17 - fwd * 0.11 + right * 0.07, "f": (fwd * 0.9 + up * 0.44).normalized(), "p": left, "curl": 0.95}
	var rel := {"palm": sh + aim_dir * 0.5 + up * 0.04, "f": aim_dir, "p": left, "curl": 0.5}
	var pose := held if is_lit() else carry
	if _t >= 0.0:
		var k := _ease(_t / 0.3) * (1.0 - _ease((_t - (T_LIGHT - 0.25)) / 0.25))
		pose = _blend(carry, lighting, k)
		if _t > T_LIGHT - 0.25:
			pose = _blend(lighting, held, _ease((_t - (T_LIGHT - 0.25)) / 0.25))
	pose = _blend(pose, raised, _ease(aim_t))
	if _tt >= 0.0:
		var base := pose
		if _tt < T_WIND:
			pose = _blend(base, cocked, _ease(_tt / T_WIND))
		elif _tt < T_WIND + T_WHIP:
			var u := _ease((_tt - T_WIND) / T_WHIP)
			pose = _blend(cocked, rel, u)
		else:
			pose = _blend(rel, carry, _ease((_tt - T_WIND - T_WHIP) / T_FOLLOW))
	var palm: Vector3 = pose["palm"]
	var r_dict := {"pos": palm, "f": pose["f"], "p": pose["p"], "curl": pose["curl"], "w": _ease(equip_t)}
	# main gauche : dévisse le capuchon puis l'arrache
	var l_dict: Variant = null
	if _t >= 0.0 and _t < T_LIGHT:
		var thumb := (fwd as Vector3).cross(left).normalized()
		var top := palm + left * 0.03 + thumb * 0.22
		var w := _ease(_t / 0.25) * (1.0 - _ease((_t - 0.8) / 0.2))
		var lp := top + up * 0.02 + right * sin(_t * 30.0) * 0.006
		if _t > 0.62:
			lp += up * 0.12 * _ease((_t - 0.62) / 0.12) + left * 0.06 * _ease((_t - 0.62) / 0.12)
		l_dict = {"pos": lp, "f": fwd, "p": -up, "curl": 0.7, "w": w}
	# le fumigène suit la vraie main
	if flare and flare.held and (_tt < 0.0 or _tt < T_WIND + T_WHIP):
		var pr := human.palm("R")
		var th: Vector3 = pr["thumb"]
		var g: Vector3 = (pr["pos"] as Vector3) + (pr["p"] as Vector3) * 0.03
		flare.hold(Transform3D(Props.basis_up(th, fwd), g + th * 0.06))
	return [r_dict, l_dict]


func _release() -> void:
	if flare == null:
		return
	var cx := human.chest_xf()
	var up := (cx.basis * Vector3(0, 1, 0)).normalized()
	var sh := human.shoulder_world("R")
	var tgt: Array = _target()
	var origin := sh + ArcPreview.solve(sh + up * 0.1, tgt[0], SPEED).normalized() * 0.5 + up * 0.04
	var v := ArcPreview.solve(origin, tgt[0], SPEED) * _rng.randf_range(0.96, 1.04)
	var f := flare
	flare = null
	count = maxi(count - 1, 0)
	count_changed.emit(count, MAX)
	f.reparent(get_tree().current_scene, true)
	f.global_position = origin
	if human.get_parent() is PhysicsBody3D:
		f.add_collision_exception_with(human.get_parent())
	f.release(v, Vector3(_rng.randf_range(-9, 9), _rng.randf_range(-3, 3), _rng.randf_range(-9, 9)))
	AudioLib.play_at(self, "sfx:throw", origin, -6.0, 5.0)
	if count == 0:
		message.emit("Dernier fumigène lancé")
