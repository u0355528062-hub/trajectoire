class_name Mortar
extends Node3D
## Mortier d'artifice (tube fin, une main).
## Au repos : tenu le long du corps. Clic droit : bras tendu, on vise. Clic gauche (en visant) :
## on ramène le tube, on l'allume au briquet de l'autre main, on le tend et il part.

signal ammo_changed(count: int, maximum: int)
signal message(text: String)
signal fired
signal stage_changed(label: String, progress: float)

const MAX_AMMO := 6
const TUBE_LEN := MortarModel.TUBE_LEN
const TUBE_R := MortarModel.TUBE_R
const LAUNCH_SPEED := 36.0
const HAND_ON_TUBE := 0.075 # distance base du tube -> centre de la paume

# séquence de tir (s)
const T_PULL := 0.40        # on ramène le tube vers la poitrine
const T_LIGHT := 1.15       # le briquet approche, la mèche s'allume
const T_PUSH := 0.40        # on retend le bras
const T_RECOIL := 0.60
const T_LAUNCH := T_PULL + T_LIGHT + T_PUSH

var ammo := MAX_AMMO
var equipped := false
var busy := false
var human: Human
var model: Node3D
var aim_point_provider := Callable() # -> Vector3 (point visé dans le monde)
var aim_t := 0.0
var equip_t := 0.0
var _aim_input := false
var _t := -1.0
var _launched := false
var _recoil := 0.0
var _fuse: Node3D
var _fuse_tip: MeshInstance3D
var _fuse_sparks: GPUParticles3D
var _fuse_light: OmniLight3D
var _lighter: Node3D
var _flame: MeshInstance3D
var _flame_light: OmniLight3D
var _sfx_ignite: AudioStreamPlayer3D
var _sfx_hiss: AudioStreamPlayer3D
var _sfx_thump: AudioStreamPlayer3D
var _sfx_click: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()
var _last_stage := ""
var _aim_dir := Vector3.FORWARD


func _ready() -> void:
	_rng.randomize()
	model = MortarModel.build()
	add_child(model)
	_build_fuse()
	_build_lighter()
	_sfx_ignite = _player(&"ignite", -4.0)
	_sfx_hiss = _player(&"hiss", -9.0)
	_sfx_thump = _player(&"thump", 4.0)
	_sfx_thump.unit_size = 30.0
	_sfx_click = _player(&"click", -6.0)
	visible = false


func _player(sound: StringName, vol: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = Sfx.get_stream(sound)
	p.volume_db = vol
	p.unit_size = 8.0
	add_child(p)
	return p


func _build_fuse() -> void:
	_fuse = Node3D.new()
	_fuse.position.y = TUBE_LEN
	_fuse.visible = false
	model.add_child(_fuse)
	var st := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0025
	cm.bottom_radius = 0.0025
	cm.height = 0.045
	st.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.55, 0.3)
	st.material_override = m
	st.position.y = 0.02
	_fuse.add_child(st)
	_fuse_tip = MeshInstance3D.new()
	var tip := SphereMesh.new()
	tip.radius = 0.0055
	tip.height = 0.011
	_fuse_tip.mesh = tip
	var tipm := StandardMaterial3D.new()
	tipm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tipm.albedo_color = Color(1.0, 0.7, 0.3) * 4.0
	_fuse_tip.material_override = tipm
	_fuse_tip.position.y = 0.045
	_fuse_tip.visible = false
	_fuse.add_child(_fuse_tip)
	_fuse_sparks = GPUParticles3D.new()
	_fuse_sparks.amount = 40
	_fuse_sparks.lifetime = 0.35
	_fuse_sparks.emitting = false
	_fuse_sparks.local_coords = false
	_fuse_sparks.position.y = 0.045
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0, -3, 0)
	pm.scale_min = 0.4
	pm.scale_max = 0.9
	pm.color_ramp = _ramp([Color(1, 0.95, 0.6, 1), Color(1, 0.5, 0.1, 0.8), Color(0.6, 0.1, 0, 0)])
	_fuse_sparks.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.02, 0.02)
	q.material = FireworkShell.spark_material(Color(1, 0.8, 0.5), 3.0)
	_fuse_sparks.draw_pass_1 = q
	_fuse.add_child(_fuse_sparks)
	_fuse_light = OmniLight3D.new()
	_fuse_light.light_color = Color(1.0, 0.6, 0.25)
	_fuse_light.light_energy = 0.0
	_fuse_light.omni_range = 2.5
	_fuse_light.position.y = 0.05
	_fuse.add_child(_fuse_light)


func _build_lighter() -> void:
	_lighter = Node3D.new()
	_lighter.visible = false
	add_child(_lighter)
	_lighter.top_level = true
	var body := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.022, 0.058, 0.013)
	body.mesh = bx
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.76, 0.8)
	m.metallic = 1.0
	m.roughness = 0.25
	body.material_override = m
	_lighter.add_child(body)
	_flame = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.008
	sm.height = 0.04
	_flame.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.65, 0.2) * 2.5
	_flame.material_override = fm
	_flame.position.y = 0.05
	_flame.visible = false
	_lighter.add_child(_flame)
	_flame_light = OmniLight3D.new()
	_flame_light.light_color = Color(1.0, 0.6, 0.25)
	_flame_light.light_energy = 0.0
	_flame_light.omni_range = 4.0
	_flame_light.position.y = 0.055
	_lighter.add_child(_flame_light)


func _ramp(cols: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cc := PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / (cols.size() - 1))
		cc.append(cols[i])
	g.offsets = offs
	g.colors = cc
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


# ------------------------------------------------------------------- equipment



# ------------------------------------------------------------------- équipement

func attach_to(h: Human) -> void:
	human = h
	h.add_child(self)
	h.hand_provider = Callable(self, "_hand_targets")


func set_equipped(on: bool) -> void:
	if busy:
		return
	equipped = on
	if on:
		visible = true


func hide_now() -> void:
	equipped = false
	equip_t = 0.0
	visible = false
	_aim_input = false
	aim_t = 0.0


func set_aim(on: bool) -> void:
	_aim_input = on and equipped


func is_aiming() -> bool:
	return aim_t > 0.85


func axis_world() -> Vector3:
	return (global_basis * model.basis * Vector3.UP).normalized()


func mouth_world() -> Vector3:
	return (global_transform * model.transform) * Vector3(0, TUBE_LEN, 0)


# ------------------------------------------------------------------- séquence

func try_fire() -> void:
	if not equipped or busy:
		return
	if aim_t < 0.8:
		message.emit("Clic droit pour viser")
		return
	if ammo <= 0:
		_sfx_click.play()
		message.emit("Plus d'obus")
		return
	busy = true
	_t = 0.0
	_launched = false
	ammo -= 1
	ammo_changed.emit(ammo, MAX_AMMO)
	_fuse.visible = true
	_fuse_tip.visible = false


func reload_all() -> void:
	ammo = MAX_AMMO
	ammo_changed.emit(ammo, MAX_AMMO)


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _stage(label: String, prog: float) -> void:
	_last_stage = label
	stage_changed.emit(label, prog)


func step(delta: float) -> void:
	aim_t = move_toward(aim_t, 1.0 if (_aim_input or busy) else 0.0, delta * 3.2)
	equip_t = move_toward(equip_t, 1.0 if equipped else 0.0, delta * 3.0)
	if not equipped and equip_t <= 0.0:
		visible = false
	_recoil = move_toward(_recoil, 0.0, delta / T_RECOIL)
	var r := _recoil * _recoil
	model.position = Vector3(0, 0.0, 0.05 * r)
	model.rotation = Vector3(-0.28 * r, 0, 0)
	_fuse_light.light_energy = 0.0
	_flame_light.light_energy = 0.0

	if _t < 0.0:
		if _last_stage != "":
			_last_stage = ""
			stage_changed.emit("", 0.0)
		return
	_t += delta
	var total := T_LAUNCH + T_RECOIL
	if _t < T_PULL + 0.35:
		_stage("PRÉPARATION", _t / total)
	elif _t < T_PULL + T_LIGHT:
		_stage("ALLUMAGE", _t / total)
	else:
		_stage("TIR", _t / total)

	var lit_from := T_PULL + 0.6
	var lit := _t >= lit_from and not _launched
	_fuse_tip.visible = lit
	_fuse_sparks.emitting = lit
	if lit:
		_fuse_light.light_energy = 0.8 + _rng.randf() * 0.7
	if not _launched and _t >= T_LAUNCH:
		_launched = true
		_fuse.visible = false
		_launch()
	if _t >= T_LAUNCH + T_RECOIL:
		_t = -1.0
		busy = false

	var ign_a := T_PULL + 0.25
	var ign_b := T_PULL + T_LIGHT - 0.15
	_lighter.visible = _t > T_PULL * 0.4 and _t < T_PULL + T_LIGHT
	var flame_on := _t > ign_a + 0.2 and _t < ign_b
	_flame.visible = flame_on
	if flame_on:
		_flame_light.light_energy = 0.9 + _rng.randf() * 0.5
		_flame.scale = Vector3(1, 0.8 + _rng.randf() * 0.5, 1)
	if _t >= ign_a + 0.25 and _t - delta < ign_a + 0.25:
		_sfx_ignite.play()
	if _t >= ign_a + 0.55 and _t - delta < ign_a + 0.55:
		_sfx_hiss.play()


# ---------------------------------------------------------- mains (monde)

func _chest(p_rest: Vector3, cx: Transform3D) -> Vector3:
	return cx * (p_rest - human.rest["spine02"])


func _pose_blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	return {
		"palm": (a["palm"] as Vector3).lerp(b["palm"], k),
		"axis": (a["axis"] as Vector3).slerp(b["axis"], k).normalized(),
		"f": (a["f"] as Vector3).slerp(b["f"], k).normalized(),
		"p": (a["p"] as Vector3).slerp(b["p"], k).normalized(),
	}


func _hand_targets() -> Array:
	if equip_t <= 0.0:
		return [null, null]
	var cx := human.chest_xf()
	var up := (cx.basis * Vector3(0, 1, 0)).normalized()
	var fwd := (cx.basis * Vector3(0, 0, 1)).normalized()
	var left := (cx.basis * Vector3(1, 0, 0)).normalized()

	# --- pose « prêt » : tube tenu devant la hanche, incliné vers l'avant, coude plié ;
	# la main suit un léger balancement de marche
	var sway := Vector3.ZERO
	if human._walk_w > 0.01:
		var ph := human.phase * TAU
		sway = up * sin(ph * 2.0) * 0.012 * human._walk_w + fwd * sin(ph) * 0.02 * human._walk_w
	var carry := {
		"palm": _chest(Vector3(-0.215, 1.02, 0.235), cx) + sway,
		"axis": (up * cos(0.78) + fwd * sin(0.78)).normalized(),
		"f": (fwd * cos(0.3) - up * sin(0.3)).normalized(), "p": left,
	}
	# --- pose « visée » : bras tendu vers le point visé
	var sh := human.shoulder_world("R")
	var target := sh + (-human.global_basis.z) * 30.0
	if aim_point_provider.is_valid():
		target = aim_point_provider.call()
	var a_dir := (target - (sh + Vector3.UP * 0.0)).normalized()
	var flat := Vector3(a_dir.x, 0, a_dir.z)
	var pit := asin(clampf(a_dir.y, -1.0, 1.0))
	pit = clampf(pit, -0.5, 1.25)
	var fl := flat.normalized() if flat.length() > 0.001 else (-human.global_basis.z)
	a_dir = (fl * cos(pit) + Vector3.UP * sin(pit)).normalized()
	_aim_dir = a_dir
	var left_h := Vector3.UP.cross(a_dir).normalized()
	var aim := {
		"palm": sh + a_dir * 0.36 + Vector3.DOWN * 0.035 - left_h * 0.0,
		"axis": a_dir,
		"f": (a_dir + Vector3.UP).normalized(),
		"p": left_h,
	}
	# --- pose « allumage » : tube ramené devant la poitrine, embouchure vers le haut
	var light := {
		"palm": _chest(Vector3(-0.115, 1.14, 0.255), cx),
		"axis": (up * cos(0.55) + fwd * sin(0.55)).normalized(),
		"f": fwd, "p": left,
	}
	var pose := _pose_blend(carry, aim, _ease(aim_t))
	var pull := 0.0
	if _t >= 0.0:
		if _t < T_PULL:
			pull = _ease(_t / T_PULL)
		elif _t < T_PULL + T_LIGHT:
			pull = 1.0
		elif _t < T_LAUNCH:
			pull = 1.0 - _ease((_t - T_PULL - T_LIGHT) / T_PUSH)
	pose = _pose_blend(pose, light, pull)

	# le tube est tenu : sa base sort de la main
	var axis: Vector3 = pose["axis"]
	var pp: Vector3 = pose["p"]
	var palm: Vector3 = pose["palm"]
	var origin := palm - axis * HAND_ON_TUBE + pp * (TUBE_R + 0.008)
	var q := Quaternion(Vector3.UP, axis)
	global_transform = Transform3D(Basis(q), origin)

	var r_curl := 1.1
	var r_dict := {"pos": palm, "f": pose["f"], "p": pp, "curl": r_curl, "w": _ease(equip_t)}

	# --- main gauche : uniquement pendant l'allumage (briquet)
	var l_dict = null
	if _t >= 0.0 and _t < T_LAUNCH:
		var w := 1.0
		if _t < 0.3:
			w = _ease(_t / 0.3)
		elif _t > T_PULL + T_LIGHT - 0.1:
			w = 1.0 - _ease((_t - (T_PULL + T_LIGHT - 0.1)) / 0.3)
		var rest_l := _chest(Vector3(0.30, 0.93, 0.10), cx)
		var chest_l := _chest(Vector3(0.08, 1.12, 0.22), cx)
		var mouth := mouth_world()
		# paume gauche : le briquet (à +p*0.05, flamme à +0.05 au-dessus) touche la mèche
		var pl := -left
		var tip := mouth + axis * 0.04
		var at_tip := tip - axis * 0.05 - pl * 0.05
		var lp := rest_l
		var ign_t := T_PULL + 0.12
		if _t < ign_t:
			lp = rest_l.lerp(chest_l, _ease(_t / ign_t))
		elif _t < ign_t + 0.3:
			lp = chest_l.lerp(at_tip, _ease((_t - ign_t) / 0.3))
		elif _t < T_PULL + T_LIGHT - 0.15:
			lp = at_tip
		else:
			lp = at_tip.lerp(rest_l, _ease((_t - (T_PULL + T_LIGHT - 0.15)) / 0.3))
		l_dict = {"pos": lp, "f": fwd, "p": pl, "curl": 0.85, "w": w}
		if _lighter.visible:
			_lighter.global_position = lp + pl * 0.05
			_lighter.global_basis = Basis(Quaternion(Vector3.UP, (axis * 0.5 + up * 0.5).normalized()))
	return [r_dict, l_dict]


func _launch() -> void:
	var scene := get_tree().current_scene
	var pos := mouth_world()
	var axis := axis_world()
	var s := FireworkShell.new()
	scene.add_child(s)
	s.global_position = pos
	var jitter := Vector3(_rng.randf_range(-0.03, 0.03), 0.0, _rng.randf_range(-0.03, 0.03))
	s.velocity = (axis + jitter).normalized() * LAUNCH_SPEED
	_recoil = 1.0
	if human:
		human.kick_back(1.0)
	_sfx_thump.global_position = pos
	_sfx_thump.play()
	_muzzle_fx(pos, axis)
	fired.emit()


func _muzzle_fx(pos: Vector3, axis: Vector3) -> void:
	var scene := get_tree().current_scene
	var root := Node3D.new()
	scene.add_child(root)
	root.global_position = pos
	root.look_at_from_position(pos, pos + axis, Vector3.RIGHT if absf(axis.y) > 0.95 else Vector3.UP)
	# look_at oriente -Z vers la cible ; on veut l'axe local -Z = axe du tube
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 0.7
	light.omni_range = 6.0
	root.add_child(light)
	var tw := root.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.12).set_ease(Tween.EASE_OUT)

	# étincelles de sortie
	var sp := GPUParticles3D.new()
	sp.amount = 22
	sp.lifetime = 0.7
	sp.one_shot = true
	sp.explosiveness = 1.0
	sp.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 22.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 13.0
	pm.gravity = Vector3(0, -7, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	pm.scale_curve = _curve2([1.0, 0.0])
	pm.color_ramp = _ramp([Color(1, 0.95, 0.7, 1), Color(1, 0.5, 0.1, 0.9), Color(0.5, 0.1, 0, 0)])
	sp.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	q.material = FireworkShell.spark_material(Color(1, 0.8, 0.5), 1.3)
	sp.draw_pass_1 = q
	root.add_child(sp)
	sp.emitting = true

	# fumée
	var sm := GPUParticles3D.new()
	sm.amount = 22
	sm.lifetime = 2.6
	sm.one_shot = true
	sm.explosiveness = 0.9
	sm.local_coords = false
	var smm := ParticleProcessMaterial.new()
	smm.direction = Vector3(0, 0, -1)
	smm.spread = 35.0
	smm.initial_velocity_min = 0.5
	smm.initial_velocity_max = 3.0
	smm.damping_min = 1.0
	smm.damping_max = 2.0
	smm.gravity = Vector3(0, 0.35, 0)
	smm.scale_min = 0.8
	smm.scale_max = 1.6
	smm.scale_curve = _curve2([0.3, 1.0, 1.6])
	smm.color_ramp = _ramp([Color(0.62, 0.6, 0.58, 0.22), Color(0.45, 0.45, 0.48, 0.14), Color(0.35, 0.35, 0.4, 0)])
	sm.process_material = smm
	var sq := QuadMesh.new()
	sq.size = Vector2(0.4, 0.4)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.vertex_color_use_as_albedo = true
	smat.albedo_texture = FireworkShell.soft_texture()
	sq.material = smat
	sm.draw_pass_1 = sq
	root.add_child(sm)
	sm.emitting = true
	get_tree().create_timer(4.0).timeout.connect(root.queue_free)


func _curve2(vals: Array) -> CurveTexture:
	var c := Curve.new()
	for i in vals.size():
		c.add_point(Vector2(float(i) / (vals.size() - 1), vals[i]))
	var t := CurveTexture.new()
	t.curve = c
	return t
