class_name Igniter
extends Node3D
## Briquet + journal roulé : clic gauche = allumer le journal (le briquet s'approche, clic,
## flamme, le papier prend), clic droit = viser (trajectoire), clic gauche = lancer la torche.
## Jeté dans une poubelle ouverte, il y met le feu.

signal message(text: String)
signal thrown

const SPEED := 11.0
const T_LIGHT := 1.35
const T_WIND := 0.24
const T_WHIP := 0.14
const T_FOLLOW := 0.45
const BURN_MAX := 16.0

var human: Human
var equipped := false
var busy := false
var aim_t := 0.0
var equip_t := 0.0
var lit := false
var aim_target_provider := Callable()
var exclude_rid := RID()

var _aim_input := false
var _t := -1.0          # allumage
var _tt := -1.0         # lancer
var _released := false
var _burn := 0.0
var _paper: Node3D
var _lighter: Node3D
var _fire: GPUParticles3D
var _smoke: GPUParticles3D
var _light: OmniLight3D
var _crackle: AudioStreamPlayer3D
var _preview: ArcPreview
var _rng := RandomNumberGenerator.new()
var _fresh := 1.0


func _ready() -> void:
	_rng.randomize()
	_paper = Props.newspaper_roll()
	_paper.top_level = true
	_paper.visible = false
	add_child(_paper)
	_lighter = Props.lighter(Color(0.85, 0.2, 0.1))
	_lighter.top_level = true
	_lighter.visible = false
	add_child(_lighter)
	_fire = Fx.fire(0.16, 22, Vector3(0.025, 0.02, 0.025), 0.75)
	_fire.top_level = true
	_fire.emitting = false
	add_child(_fire)
	_smoke = Fx.smoke(Color(0.25, 0.24, 0.23, 0.35), 14, 3.0, 0.15, true, 0.7, 5.0)
	_smoke.top_level = true
	_smoke.emitting = false
	add_child(_smoke)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.22)
	_light.light_energy = 0.0
	_light.omni_range = 5.0
	_light.shadow_enabled = true
	_light.top_level = true
	add_child(_light)
	_crackle = AudioStreamPlayer3D.new()
	_crackle.stream = AudioLib.stream("fire_loop", true)
	_crackle.volume_db = -18.0
	_crackle.unit_size = 3.0
	_crackle.pitch_scale = 1.25
	_crackle.top_level = true
	add_child(_crackle)
	_preview = ArcPreview.new()
	add_child(_preview)


func attach_to(h: Human) -> void:
	human = h
	h.add_child(self)


func set_equipped(on: bool) -> void:
	if busy and not on:
		return
	equipped = on
	if not on:
		_preview.hide_all()


func hide_now() -> void:
	if lit:
		_drop(false)
	equipped = false
	equip_t = 0.0
	_t = -1.0
	_tt = -1.0
	busy = false
	_paper.visible = false
	_lighter.visible = false
	_preview.hide_all()


func set_aim(on: bool) -> void:
	_aim_input = on and equipped


## Clic gauche : allumer, puis lancer
func use() -> void:
	if not equipped or busy or equip_t < 0.6:
		return
	if not lit:
		busy = true
		_t = 0.0
	else:
		busy = true
		_tt = 0.0
		_released = false


func state_label() -> String:
	return "lit" if lit else "unlit"


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func step(delta: float) -> void:
	var t_now := Time.get_ticks_msec() / 1000.0
	equip_t = move_toward(equip_t, 1.0 if equipped else 0.0, delta * 3.0)
	aim_t = move_toward(aim_t, 1.0 if ((_aim_input and lit and _t < 0.0 and _tt < 0.0) or (_tt >= 0.0 and _tt < T_WIND + T_WHIP + 0.05)) else 0.0, delta * 4.0)
	_fresh = move_toward(_fresh, 1.0, delta * 2.0)
	# --- allumage
	if _t >= 0.0:
		_t += delta
		var flame_on := _t > 0.55 and _t < T_LIGHT - 0.1
		Props.set_lighter_lit(_lighter, flame_on, t_now)
		if _t >= 0.55 and _t - delta < 0.55:
			AudioLib.play_at(self, "sfx:click", _lighter.global_position, -8.0, 3.0)
			AudioLib.play_at(self, "sfx:ignite", _lighter.global_position, -10.0, 3.0)
		if _t >= 0.95 and not lit:
			lit = true
			_burn = 0.0
			_fire.emitting = true
			_smoke.emitting = true
			_crackle.play()
			AudioLib.play_at(self, "paper_rustle", _paper.global_position, -6.0, 3.0)
		if _t >= T_LIGHT:
			_t = -1.0
			busy = false
	# --- lancer
	if _tt >= 0.0:
		_tt += delta
		if not _released and _tt >= T_WIND + T_WHIP:
			_released = true
			_release()
		if _tt >= T_WIND + T_WHIP + T_FOLLOW:
			_tt = -1.0
			busy = false
			_fresh = 0.0
	# --- torche qui brûle
	if lit:
		_burn += delta
		var k := clampf(_burn / 1.2, 0.15, 1.0) * clampf((BURN_MAX - _burn) / 2.5, 0.0, 1.0)
		_fire.amount_ratio = k
		_smoke.amount_ratio = 0.3 + 0.7 * k
		_light.light_energy = 1.6 * k * Fx.flicker(t_now, 2.0)
		_crackle.volume_db = linear_to_db(maxf(k, 0.001)) - 14.0
		if _burn >= BURN_MAX and _tt < 0.0:
			_drop(true)
			message.emit("Le journal s'est consumé")
	else:
		_light.light_energy = 0.0
	if human:
		var tw := 0.0
		if _tt >= 0.0:
			if _tt < T_WIND:
				tw = -0.4 * _ease(_tt / T_WIND)
			elif _tt < T_WIND + T_WHIP:
				tw = lerpf(-0.4, 0.38, _ease((_tt - T_WIND) / T_WHIP))
			else:
				tw = lerpf(0.38, 0.0, _ease((_tt - T_WIND - T_WHIP) / T_FOLLOW))
		else:
			tw = -0.12 * _ease(aim_t)
		human.twist = lerpf(human.twist, tw, minf(1.0, delta * 18.0))
	if equip_t <= 0.0 and not equipped:
		_paper.visible = false
		_lighter.visible = false
		_fire.emitting = false


func _drop(burning: bool) -> void:
	# la torche tombe (et finit de brûler par terre)
	if burning:
		var b := Burnable.make("paper")
		get_tree().current_scene.add_child(b)
		b.global_position = _paper.global_position
		b.linear_velocity = (-human.global_basis.z) * 1.0 + Vector3.UP
		b.ignite()
		b.burn = 0.5
	lit = false
	_fire.emitting = false
	_smoke.emitting = false
	_crackle.stop()
	_fresh = 0.0


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


## Lancer en cloche quand la cible est proche (pour tomber DANS une poubelle)
func _solve(origin: Vector3, target: Vector3) -> Vector3:
	var d := Vector2(target.x - origin.x, target.z - origin.z).length()
	if d < 6.0:
		return ArcPreview.solve(origin, target, clampf(4.2 + d * 0.9, 4.5, SPEED), true)
	return ArcPreview.solve(origin, target, SPEED)


func _blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	return {
		"palm": (a["palm"] as Vector3).lerp(b["palm"], k),
		"f": (a["f"] as Vector3).slerp(b["f"], k).normalized(),
		"p": (a["p"] as Vector3).slerp(b["p"], k).normalized(),
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
	var tgt: Array = _target()
	var v0 := _solve(sh + up * 0.1, tgt[0])
	var aim_dir := v0.normalized()
	var drop := (1.0 - _ease(_fresh)) * 0.25
	var carry := {"palm": _chest(Vector3(-0.21, 0.99 - drop, 0.21), cx), "f": fwd, "p": left, "curl": 0.95}
	var held_lit := {"palm": _chest(Vector3(-0.24, 1.08, 0.27), cx), "f": (fwd + up * 0.2).normalized(), "p": left, "curl": 0.95}
	var lighting := {"palm": _chest(Vector3(-0.1, 1.12, 0.3), cx), "f": fwd, "p": left, "curl": 0.95}
	# armé : la torche reste dressée (pouce vers le haut, légèrement penchée en arrière)
	var cocked := {"palm": sh + up * 0.17 - fwd * 0.11 + right * 0.07, "f": (fwd * 0.9 + up * 0.44).normalized(), "p": left, "curl": 0.95}
	var rel := {"palm": sh + aim_dir * 0.5 + up * 0.04, "f": aim_dir, "p": left, "curl": 0.5}
	var pose := held_lit if lit else carry
	if _t >= 0.0:
		var k := _ease(_t / 0.35) * (1.0 - _ease((_t - (T_LIGHT - 0.3)) / 0.3))
		pose = _blend(carry, lighting, k) if not lit else _blend(held_lit, lighting, k)
	pose = _blend(pose, cocked, _ease(aim_t) * 0.92)
	if _tt >= 0.0:
		if _tt < T_WIND:
			pose = _blend(pose, cocked, _ease(_tt / T_WIND))
		elif _tt < T_WIND + T_WHIP:
			var u := _ease((_tt - T_WIND) / T_WHIP)
			pose = _blend(cocked, rel, u)
			pose["palm"] = (pose["palm"] as Vector3) + up * sin(PI * u) * 0.08
		else:
			pose = _blend(rel, carry, _ease((_tt - T_WIND - T_WHIP) / T_FOLLOW))
	var palm: Vector3 = pose["palm"]
	var r_dict := {"pos": palm, "f": pose["f"], "p": pose["p"], "curl": pose["curl"], "w": _ease(equip_t)}
	# --- main gauche : briquet pendant l'allumage
	var l_dict: Variant = null
	_lighter.visible = _t >= 0.0 and _t < T_LIGHT - 0.05
	if _t >= 0.0 and _t < T_LIGHT:
		var w := _ease(_t / 0.3) * (1.0 - _ease((_t - (T_LIGHT - 0.3)) / 0.3))
		var thumb := fwd.cross(left).normalized()   # pouce de la main droite (vers le haut)
		var grip := palm + left * 0.03
		var tip := grip + thumb * 0.21
		var lp := tip - right * 0.06 - up * 0.07 + fwd * 0.01
		var rest_l := _chest(Vector3(0.28, 0.95, 0.12), cx)
		lp = rest_l.lerp(lp, _ease((_t - 0.1) / 0.35))
		l_dict = {"pos": lp, "f": fwd, "p": right, "curl": 0.85, "w": w}
	# --- placement du journal, du briquet et des flammes (repère réel de la main)
	var in_hand := (_tt < 0.0 or _tt < T_WIND + T_WHIP) and equip_t > 0.1
	_paper.visible = in_hand and _fresh > 0.05
	if _paper.visible:
		var pr := human.palm("R")
		var th: Vector3 = pr["thumb"]
		var g: Vector3 = (pr["pos"] as Vector3) + (pr["p"] as Vector3) * 0.03
		_paper.global_transform = Transform3D(Props.basis_up(th, fwd), g + th * 0.04)
		var tipw := g + th * 0.25
		_fire.global_position = tipw
		_smoke.global_position = tipw + Vector3.UP * 0.12
		_light.global_position = tipw + Vector3.UP * 0.1
		_crackle.global_position = tipw
	if _lighter.visible:
		var pl := human.palm("L")
		_lighter.global_position = (pl["pos"] as Vector3) + (pl["p"] as Vector3) * 0.04
		_lighter.global_basis = Basis(Quaternion(Vector3.UP, (pl["thumb"] as Vector3)))
	if aim_t > 0.5 and _tt < 0.0 and lit:
		_preview.exclude = [exclude_rid]
		var o := palm + up * 0.05
		_preview.show_arc(o, _solve(o, tgt[0]))
	else:
		_preview.hide_all()
	return [r_dict, l_dict]


func _release() -> void:
	var cx := human.chest_xf()
	var up := (cx.basis * Vector3(0, 1, 0)).normalized()
	var sh := human.shoulder_world("R")
	var tgt: Array = _target()
	var origin := sh + _solve(sh + up * 0.1, tgt[0]).normalized() * 0.5 + up * 0.04
	var v := _solve(origin, tgt[0]) * _rng.randf_range(0.985, 1.015)
	var b := Burnable.make("paper")
	get_tree().current_scene.add_child(b)
	if human.get_parent() is PhysicsBody3D:
		b.add_collision_exception_with(human.get_parent())
	b.global_position = origin
	b.linear_velocity = v
	b.angular_velocity = Vector3(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8), _rng.randf_range(-8, 8))
	b.ignite()
	b.burn = clampf(_burn / BURN_MAX * 0.5, 0.0, 0.4)
	AudioLib.play_at(self, "sfx:throw", origin, -6.0, 5.0)
	lit = false
	_fire.emitting = false
	_smoke.emitting = false
	_crackle.stop()
	_paper.visible = false
	_preview.hide_all()
	thrown.emit()
