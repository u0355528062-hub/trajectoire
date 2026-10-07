class_name Thrower
extends Node3D
## Lancer de pierres : prise en main, armé (clic droit : trajectoire en pointillés),
## lancer par-dessus l'épaule (clic gauche) avec balayage du bras et torsion du buste.

signal message(text: String)
signal thrown

const SPEED := 17.0
const T_WIND := 0.24
const T_WHIP := 0.14
const T_FOLLOW := 0.42

var human: Human
var equipped := false
var busy := false
var aim_t := 0.0
var equip_t := 0.0
## -> Array [Vector3 point visé, bool touche quelque chose]
var aim_target_provider := Callable()
var exclude_rid := RID()

var _aim_input := false
var _t := -1.0
var _released := false
var _vis: MeshInstance3D
var _dots: Array[MeshInstance3D] = []
var _marker: MeshInstance3D
var _throw_snd: AudioStreamPlayer3D
var _seed := 1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_seed = _rng.randi_range(1, 99999)
	_vis = MeshInstance3D.new()
	_vis.mesh = Stone.make_mesh(3)
	_vis.material_override = Stone.material()
	_vis.scale = Vector3.ONE * 0.12
	_vis.visible = false
	_vis.top_level = true
	add_child(_vis)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(1.0, 0.95, 0.8, 0.9)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.no_depth_test = false
	for i in 26:
		var d := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.024
		sm.height = 0.048
		sm.radial_segments = 8
		sm.rings = 4
		d.mesh = sm
		d.material_override = dm
		d.top_level = true
		d.visible = false
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(d)
		_dots.append(d)
	_marker = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.1
	tm.outer_radius = 0.125
	_marker.mesh = tm
	_marker.material_override = dm
	_marker.top_level = true
	_marker.visible = false
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)
	_throw_snd = AudioStreamPlayer3D.new()
	_throw_snd.stream = Sfx.get_stream(&"throw")
	_throw_snd.volume_db = -4.0
	add_child(_throw_snd)
	visible = true


func attach_to(h: Human) -> void:
	human = h
	h.add_child(self)


func claim_hands() -> void:
	human.hand_provider = Callable(self, "_hand_targets")


func set_equipped(on: bool) -> void:
	if busy and not on:
		return
	equipped = on
	if not on:
		_vis.visible = false
		_hide_preview()


func hide_now() -> void:
	equipped = false
	equip_t = 0.0
	_vis.visible = false
	_hide_preview()


func set_aim(on: bool) -> void:
	_aim_input = on and equipped


func throw_stone() -> void:
	if not equipped or busy:
		return
	busy = true
	_t = 0.0
	_released = false
	_seed = _rng.randi_range(1, 99999)


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func step(delta: float) -> void:
	aim_t = move_toward(aim_t, 1.0 if (_aim_input and not busy) or (busy and _t < T_WIND + T_WHIP + 0.05) else 0.0, delta * 4.0)
	equip_t = move_toward(equip_t, 1.0 if equipped else 0.0, delta * 3.0)
	if _t >= 0.0:
		_t += delta
		if not _released and _t >= T_WIND + T_WHIP:
			_released = true
			_release()
		if _t >= T_WIND + T_WHIP + T_FOLLOW:
			_t = -1.0
			busy = false
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


func _chest(p_rest: Vector3, cx: Transform3D) -> Vector3:
	return cx * (p_rest - human.rest["spine02"])


## Direction + vitesse de lancer vers le point visé (solution balistique basse).
func _solve(origin: Vector3, target: Vector3) -> Vector3:
	var d := Vector3(target.x - origin.x, 0, target.z - origin.z)
	var dist := maxf(d.length(), 0.5)
	var h := target.y - origin.y
	var g := 9.8
	var v := SPEED
	var disc := v * v * v * v - g * (g * dist * dist + 2.0 * h * v * v)
	var tan_t := 0.7
	if disc >= 0.0:
		tan_t = (v * v - sqrt(disc)) / (g * dist)
	var ang := atan(tan_t)
	return (d.normalized() * cos(ang) + Vector3.UP * sin(ang)) * v


func _target() -> Array:
	if aim_target_provider.is_valid():
		return aim_target_provider.call()
	return [global_position + (-human.global_basis.z) * 20.0, false]


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

	var carry := {"palm": _chest(Vector3(-0.245, 1.0, 0.17), cx), "f": fwd, "p": up, "curl": 0.55}
	var cocked := {"palm": sh + up * 0.17 - fwd * 0.11 + right * 0.07, "f": (up * 0.9 - fwd * 0.2).normalized(), "p": fwd, "curl": 0.6}
	var rel := {"palm": sh + aim_dir * 0.5 + up * 0.04, "f": aim_dir, "p": -up, "curl": 0.15}
	var pose := carry
	var k := _ease(aim_t)
	pose = _blend(carry, cocked, k * 0.92)
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
	var in_hand := _t < 0.0 or _t < T_WIND + T_WHIP or _t >= T_WIND + T_WHIP + 0.25
	_vis.visible = in_hand and equip_t > 0.1
	_vis.global_position = palm + pp.normalized() * 0.03 + ff.normalized() * 0.03
	_vis.global_basis = Basis.looking_at(ff.normalized(), up) * Basis.from_scale(Vector3.ONE * 0.12)
	_update_preview(palm, tgt)
	return [{"pos": palm, "f": ff, "p": pp, "curl": pose["curl"], "w": _ease(equip_t)}, null]


func _blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	return {
		"palm": (a["palm"] as Vector3).lerp(b["palm"], k),
		"f": (a["f"] as Vector3).slerp(b["f"], k).normalized(),
		"p": (a["p"] as Vector3).slerp(b["p"], k).normalized(),
		"curl": lerpf(a["curl"], b["curl"], k),
	}


func _hide_preview() -> void:
	for d in _dots:
		d.visible = false
	_marker.visible = false


func _update_preview(palm: Vector3, tgt: Array) -> void:
	if aim_t < 0.5 or busy or human == null:
		_hide_preview()
		return
	var origin := palm + Vector3.UP * 0.05
	var v := _solve(origin, tgt[0])
	var space := get_world_3d().direct_space_state
	var p := origin
	var hit := false
	var hit_pos := Vector3.ZERO
	var hit_n := Vector3.UP
	var dt := 0.045
	for i in _dots.size():
		var vn := v + Vector3(0, -9.8 * dt, 0)
		var pn := p + (v + vn) * 0.5 * dt
		if not hit:
			var q := PhysicsRayQueryParameters3D.create(p, pn, 1 | 32)
			q.exclude = [exclude_rid]
			var r := space.intersect_ray(q)
			if r:
				hit = true
				hit_pos = r["position"]
				hit_n = r["normal"]
		_dots[i].visible = not hit and i % 1 == 0 and i > 1
		_dots[i].global_position = pn
		var fade := 1.0 - float(i) / _dots.size() * 0.6
		_dots[i].scale = Vector3.ONE * fade
		v = vn
		p = pn
	_marker.visible = hit
	if hit:
		_marker.global_position = hit_pos + hit_n * 0.015
		_marker.global_basis = Basis(Quaternion(Vector3.UP, hit_n)) * Basis.from_scale(Vector3(1, 0.15, 1))


func _release() -> void:
	var cx := human.chest_xf()
	var up := (cx.basis * Vector3(0, 1, 0)).normalized()
	var sh := human.shoulder_world("R")
	var tgt: Array = _target()
	var origin := sh + up * 0.1
	var rel_pos := sh + (_solve(origin, tgt[0]).normalized()) * 0.5 + up * 0.04
	var v := _solve(rel_pos, tgt[0]) * _rng.randf_range(0.97, 1.03)
	var s := Stone.new()
	get_tree().current_scene.add_child(s)
	s.setup(_seed, _rng.randf_range(0.04, 0.062))
	s.collision_mask = 1 | 16 | 32 | 64   # sol/abribus, manifestants, poubelles, cartons
	if human.get_parent() is PhysicsBody3D:
		s.add_collision_exception_with(human.get_parent())
	s.global_position = rel_pos
	s.linear_velocity = v
	s.angular_velocity = Vector3(_rng.randf_range(-12, 12), _rng.randf_range(-12, 12), _rng.randf_range(-12, 12))
	_throw_snd.global_position = rel_pos
	_throw_snd.play()
	_vis.visible = false
	# limite le nombre de pierres au sol
	var stones := get_tree().get_nodes_in_group("stones")
	while stones.size() > 28:
		var old: Node = stones.pop_front()
		old.queue_free()
	get_tree().create_timer(60.0).timeout.connect(func():
		if is_instance_valid(s):
			var tw := s.create_tween()
			tw.tween_property(s, "scale", Vector3.ONE * 0.01, 0.8)
			tw.tween_callback(s.queue_free))
	thrown.emit()
