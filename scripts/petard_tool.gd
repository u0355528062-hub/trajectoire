class_name PetardTool
extends Thrower
## Pétards (touche 5 : petits, touche 6 : moyens). Clic gauche : on sort le briquet et on allume la mèche ;
## clic droit : on vise (trajectoire en pointillés) ; clic gauche : on lance. Une mèche qui brûle trop longtemps
## explose dans la main.

signal counts_changed(small: int, small_max: int, medium: int, medium_max: int)
signal blown_in_hand(size: int, pos: Vector3)

const MAX_COUNT := [0, 12, 6]
const T_LIGHT := 1.05
const T_IGNITE := 0.62

var size := 1
var counts := [0, 12, 6]
var lit := false
var fuse := 0.0
var _lt := -1.0              # phase d'allumage
var _fresh := 1.0
var _lighter: Node3D
var _embers: GPUParticles3D
var _glow: OmniLight3D
var _hiss: AudioStreamPlayer3D
var _in_hand_item := true


func _ready() -> void:
	super._ready()
	if _vis:
		_vis.queue_free()
	_vis = Props.petard(size)
	_vis.top_level = true
	_vis.visible = false
	add_child(_vis)
	_lighter = Props.lighter(Color(0.12, 0.34, 0.78))
	_lighter.top_level = true
	_lighter.visible = false
	add_child(_lighter)
	_embers = Fx.embers(10, Vector3(0.002, 0.002, 0.002), Color(0.6, 0.38, 0.18), 0.8)
	_embers.lifetime = 0.45
	var pm := _embers.process_material as ParticleProcessMaterial
	pm.spread = 70.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, -3.0, 0)
	_embers.top_level = true
	_embers.emitting = false
	add_child(_embers)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.62, 0.25)
	_glow.omni_range = 1.5
	_glow.light_energy = 0.0
	_glow.top_level = true
	add_child(_glow)
	_hiss = AudioStreamPlayer3D.new()
	_hiss.stream = Sfx.get_stream(&"fuse")
	_hiss.bus = &"Effets"
	_hiss.volume_db = -12.0
	_hiss.unit_size = 2.5
	_hiss.top_level = true
	add_child(_hiss)


## Choisit le type de pétard tenu (1 petit, 2 moyen) ; refusé pendant une action
func select_size(sz: int) -> void:
	if busy or lit:
		return
	if sz != size:
		size = sz
		if _vis:
			_vis.queue_free()
		_vis = Props.petard(size)
		_vis.top_level = true
		_vis.visible = false
		add_child(_vis)
	_fresh = 0.0


func has_item() -> bool:
	return int(counts[size]) > 0


func reload_all() -> void:
	counts = [0, int(MAX_COUNT[1]), int(MAX_COUNT[2])]
	counts_changed.emit(counts[1], MAX_COUNT[1], counts[2], MAX_COUNT[2])


func _emit_counts() -> void:
	counts_changed.emit(counts[1], MAX_COUNT[1], counts[2], MAX_COUNT[2])


func set_equipped(on: bool) -> void:
	if busy and not on:
		return
	if not on and lit:
		_drop_lit()
	equipped = on
	if not on:
		_vis.visible = false
		_hide_preview()
		_lighter.visible = false
		_fx(false)


func hide_now() -> void:
	if lit:
		_drop_lit()
	equipped = false
	equip_t = 0.0
	_lt = -1.0
	_t = -1.0
	busy = false
	_vis.visible = false
	_lighter.visible = false
	_fx(false)
	_hide_preview()


func use() -> void:
	if not equipped or busy or equip_t < 0.6:
		return
	if not has_item():
		message.emit("Plus de pétards de ce type (R pour recharger)")
		return
	busy = true
	if not lit:
		_lt = 0.0
	else:
		_t = 0.0
		_released = false
		_seed = _rng.randi_range(1, 99999)


func set_aim(on: bool) -> void:
	_aim_input = on and equipped and lit


func _fx(on: bool) -> void:
	_embers.emitting = on
	_glow.light_energy = 0.0 if not on else _glow.light_energy
	if not on and _hiss.playing:
		_hiss.stop()


func _ignite() -> void:
	lit = true
	fuse = float(Firecracker.FUSE_TIME[size])
	_embers.emitting = true
	_hiss.play()
	get_tree().call_group("crowd", "on_event", "petard_lit", {"pos": _tip_world(), "size": size, "player": true})


func _tip_world() -> Vector3:
	var tip: Vector3 = _vis.get_meta("tip", Vector3(0, 0.04, 0))
	return _vis.global_transform * tip


func step(delta: float) -> void:
	equip_t = move_toward(equip_t, 1.0 if equipped else 0.0, delta * 3.0)
	_fresh = move_toward(_fresh, 1.0, delta * 2.0)
	var want := _aim_input and lit and _lt < 0.0
	aim_t = move_toward(aim_t, 1.0 if (want and not busy) or (_t >= 0.0 and _t < T_WIND + T_WHIP + 0.05) else 0.0, delta * 4.0)
	if _lt >= 0.0:
		_lt += delta
		if _lt >= T_IGNITE and not lit:
			_ignite()
		if _lt >= T_LIGHT:
			_lt = -1.0
			busy = false
	if _t >= 0.0:
		_t += delta
		if not _released and _t >= T_WIND + T_WHIP:
			_released = true
			_release()
		if _t >= T_WIND + T_WHIP + T_FOLLOW:
			_t = -1.0
			busy = false
			_fresh = 0.0
	# mèche
	if lit and _in_hand_item:
		fuse -= delta
		_glow.light_energy = 0.12 + 0.12 * Fx.flicker(Time.get_ticks_msec() / 1000.0 * 3.0, 3.0)
		if fuse <= 0.0:
			_blow_in_hand()
	if human:
		var tw := 0.0
		if _t >= 0.0:
			if _t < T_WIND:
				tw = -0.4 * _ease(_t / T_WIND)
			elif _t < T_WIND + T_WHIP:
				tw = lerpf(-0.4, 0.38, _ease((_t - T_WIND) / T_WHIP))
			else:
				tw = lerpf(0.38, 0.0, _ease((_t - T_WIND - T_WHIP) / T_FOLLOW))
		else:
			tw = -0.12 * _ease(aim_t)
		human.twist = lerpf(human.twist, tw, minf(1.0, delta * 18.0))
	if equip_t <= 0.0 and not equipped:
		_vis.visible = false
		_lighter.visible = false


func _hand_targets() -> Array:
	if equip_t <= 0.0:
		return [null, null]
	var cx := human.chest_xf()
	var up := (cx.basis * Vector3(0, 1, 0)).normalized()
	var fwd := (cx.basis * Vector3(0, 0, 1)).normalized()
	var left := (cx.basis * Vector3(1, 0, 0)).normalized()
	var right := -left
	var sh := human.shoulder_world("R")
	var tgt: Array = _target()
	var v0 := _solve(sh + up * 0.1, tgt[0])
	var aim_dir := v0.normalized()
	var drop := (1.0 - _ease(_fresh)) * 0.2
	var carry := {"palm": _chest(Vector3(-0.2, 1.0 - drop, 0.21), cx), "f": fwd, "p": up, "curl": 0.6}
	var lighting := {"palm": _chest(Vector3(-0.09, 1.16, 0.3), cx), "f": fwd, "p": up, "curl": 0.6}
	var cocked := {"palm": sh + up * 0.17 - fwd * 0.11 + right * 0.07, "f": (up * 0.9 - fwd * 0.2).normalized(), "p": fwd, "curl": 0.6}
	var rel := {"palm": sh + aim_dir * 0.5 + up * 0.04, "f": aim_dir, "p": -up, "curl": 0.15}
	var pose := _blend(carry, cocked, _ease(aim_t) * 0.92)
	var lt := _lt
	if lt >= 0.0:
		var k := _ease(lt / 0.3) * (1.0 - _ease((lt - (T_LIGHT - 0.25)) / 0.25))
		pose = _blend(carry, lighting, k)
	if _t >= 0.0:
		if _t < T_WIND:
			pose = _blend(pose, cocked, _ease(_t / T_WIND))
		elif _t < T_WIND + T_WHIP:
			var u := _ease((_t - T_WIND) / T_WHIP)
			pose = _blend(cocked, rel, u)
			pose["palm"] = (pose["palm"] as Vector3) + up * sin(PI * u) * 0.08
		else:
			pose = _blend(rel, carry, _ease((_t - T_WIND - T_WHIP) / T_FOLLOW))
	var palm: Vector3 = pose["palm"]
	var pp: Vector3 = pose["p"]
	var ff: Vector3 = pose["f"]
	# le pétard repose dans la paume (mèche vers le haut) puis part avec le bras
	var in_hand := (_t < 0.0 or _t < T_WIND + T_WHIP) and _in_hand_item and int(counts[size]) > 0 and _fresh > 0.05
	_vis.visible = in_hand and equip_t > 0.1
	var shaft := (up * 0.85 + ff.normalized() * 0.25).normalized() if _t < 0.0 or _t >= T_WIND else (-ff.normalized() * 0.2 + up).normalized()
	var base := palm + pp.normalized() * (0.026 if size >= 2 else 0.02) + ff.normalized() * 0.02
	_vis.global_transform = Transform3D(Props.basis_up(shaft, fwd), base + shaft * (0.034 if size >= 2 else 0.019) * 0.5)
	var tip := _tip_world()
	# l'étincelle suit la mèche
	if lit:
		_embers.global_position = tip
		_glow.global_position = tip
		_hiss.global_position = tip
	_update_preview(palm, tgt)
	# main gauche : le briquet vient lécher la mèche
	var l_dict: Variant = null
	if _lt >= 0.0:
		var w := _ease(_lt / 0.28) * (1.0 - _ease((_lt - (T_LIGHT - 0.22)) / 0.22))
		var thumb_up := (up + fwd * 0.15).normalized()
		var lp := tip - right * 0.04 - thumb_up * 0.058 - fwd * 0.012 + left * 0.01
		# la main arrive de plus bas, puis se retire vers la gauche
		var rest := _chest(Vector3(0.22, 0.95, 0.12), cx)
		var away := _ease((_lt - (T_LIGHT - 0.3)) / 0.3)
		lp = rest.lerp(lp, _ease(_lt / 0.3)).lerp(rest, away)
		l_dict = {"pos": lp, "f": (fwd + up * 0.2).normalized(), "p": right, "curl": 0.85, "w": w}
		_lighter.visible = w > 0.2
		var pl := human.palm("L")
		_lighter.global_position = (pl["pos"] as Vector3) + (pl["p"] as Vector3) * 0.04
		_lighter.global_basis = Basis(Quaternion(Vector3.UP, pl["thumb"] as Vector3))
		var flame_on := _lt > 0.38 and _lt < T_LIGHT - 0.28
		if flame_on and not _lighter.get_meta("on", false):
			AudioLib.play_at(self, "sfx:click", _lighter.global_position, -8.0, 3.0)
			AudioLib.play_at(self, "sfx:ignite", _lighter.global_position, -10.0, 3.0)
		_lighter.set_meta("on", flame_on)
		Props.set_lighter_lit(_lighter, flame_on, Time.get_ticks_msec() / 1000.0)
	else:
		_lighter.visible = false
		Props.set_lighter_lit(_lighter, false)
		_lighter.set_meta("on", false)
	return [{"pos": palm, "f": ff, "p": pp, "curl": pose["curl"], "w": _ease(equip_t)}, l_dict]


func _release() -> void:
	var cx := human.chest_xf()
	var up := (cx.basis * Vector3(0, 1, 0)).normalized()
	var sh := human.shoulder_world("R")
	var tgt: Array = _target()
	var origin := sh + up * 0.1
	var rel_pos := sh + (_solve(origin, tgt[0]).normalized()) * 0.5 + up * 0.04
	var v := _solve(rel_pos, tgt[0]) * _rng.randf_range(0.97, 1.03)
	var f := Firecracker.make(size, true, human.get_parent() as Node3D)
	f.fuse = maxf(fuse, 0.05)
	f.lit = true
	get_tree().current_scene.add_child(f)
	if human.get_parent() is PhysicsBody3D:
		f.add_collision_exception_with(human.get_parent())
	f.global_position = rel_pos
	f.linear_velocity = v
	f.angular_velocity = Vector3(_rng.randf_range(-14, 14), _rng.randf_range(-14, 14), _rng.randf_range(-14, 14))
	_consume()
	_throw_snd.global_position = rel_pos
	_throw_snd.play()
	_vis.visible = false
	thrown.emit()


## Le pétard allumé quitte la main sans être lancé (on change d'objet) : il tombe aux pieds
func _drop_lit() -> void:
	if not lit:
		return
	var f := Firecracker.make(size, true, human.get_parent() as Node3D)
	f.fuse = maxf(fuse, 0.05)
	f.lit = true
	get_tree().current_scene.add_child(f)
	f.global_position = _vis.global_position
	f.linear_velocity = Vector3(randf_range(-0.4, 0.4), 0.8, randf_range(-0.4, 0.4))
	_consume()


func _consume() -> void:
	counts[size] = maxi(int(counts[size]) - 1, 0)
	lit = false
	fuse = 0.0
	_fx(false)
	_emit_counts()
	_fresh = 0.0


## La mèche était trop courte : explose dans la main
func _blow_in_hand() -> void:
	var pos := _vis.global_position
	var f := Firecracker.make(size, true, human.get_parent() as Node3D)
	f.lit = false
	get_tree().current_scene.add_child(f)
	f.global_position = pos
	f.explode(pos)
	_consume()
	_t = -1.0
	_lt = -1.0
	busy = false
	_vis.visible = false
	blown_in_hand.emit(size, pos)
	message.emit("Trop tard ! Il t'a explosé dans la main")
