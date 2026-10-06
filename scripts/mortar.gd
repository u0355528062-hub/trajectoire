class_name Mortar
extends Node3D
## Mortier d'artifice tenu à deux mains. 6 tirs, séquence complète :
## prendre l'obus -> allumer la mèche -> le glisser dans le tube -> départ.

signal ammo_changed(count: int, maximum: int)
signal message(text: String)
signal fired

const MAX_AMMO := 6
const TUBE_LEN := 0.5
const TUBE_R := 0.045
const LAUNCH_SPEED := 36.0

# durées de la séquence (s)
const T_GRAB1 := 0.40   # main droite : tube -> poche
const T_GRAB2 := 0.45   # poche -> devant la poitrine
const T_IGNITE := 0.95  # briquet dans la main gauche
const T_LOAD := 0.50    # vers l'embouchure
const T_DROP := 0.28    # l'obus glisse dans le tube
const T_RET := 0.40     # la main revient
const T_LAUNCH_AFTER_DROP := 0.18
const T_RECOIL := 0.55

var ammo := MAX_AMMO
var equipped := false
var busy := false
var human: Human
var model: Node3D
var _t := -1.0
var _launched := false
var _recoil := 0.0
var _shell: Node3D
var _fuse_tip: MeshInstance3D
var _fuse_sparks: GPUParticles3D
var _fuse_light: OmniLight3D
var _lighter: Node3D
var _flame: MeshInstance3D
var _flame_light: OmniLight3D
var _glow: MeshInstance3D
var _sfx_ignite: AudioStreamPlayer3D
var _sfx_hiss: AudioStreamPlayer3D
var _sfx_thump: AudioStreamPlayer3D
var _sfx_click: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	model = Node3D.new()
	add_child(model)
	_build_tube()
	_build_shell()
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


# ---------------------------------------------------------------------- model

func _build_tube() -> void:
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.62, 0.10, 0.07)
	paper.roughness = 0.55
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	paper.clearcoat_enabled = true
	paper.clearcoat = 0.3
	var inner := StandardMaterial3D.new()
	inner.albedo_color = Color(0.02, 0.02, 0.02)
	inner.cull_mode = BaseMaterial3D.CULL_FRONT
	inner.roughness = 1.0
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.85, 0.62, 0.18)
	gold.metallic = 0.9
	gold.roughness = 0.3
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.06, 0.06, 0.07)
	dark.roughness = 0.5

	var tube := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = TUBE_R
	cm.bottom_radius = TUBE_R
	cm.height = TUBE_LEN
	cm.radial_segments = 40
	cm.rings = 1
	cm.cap_top = false
	tube.mesh = cm
	tube.material_override = paper
	tube.position.y = TUBE_LEN * 0.5
	model.add_child(tube)

	var bore := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = TUBE_R - 0.004
	bm.bottom_radius = TUBE_R - 0.004
	bm.height = TUBE_LEN - 0.01
	bm.radial_segments = 40
	bm.cap_top = false
	bore.mesh = bm
	bore.material_override = inner
	bore.position.y = TUBE_LEN * 0.5
	model.add_child(bore)

	for y in [0.07, 0.43]:
		var band := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = TUBE_R + 0.002
		bc.bottom_radius = TUBE_R + 0.002
		bc.height = 0.022
		bc.radial_segments = 40
		band.mesh = bc
		band.material_override = gold
		band.position.y = y
		model.add_child(band)

	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = TUBE_R - 0.004
	tm.outer_radius = TUBE_R + 0.008
	tm.rings = 40
	tm.ring_segments = 8
	rim.mesh = tm
	rim.material_override = dark
	rim.position.y = TUBE_LEN
	model.add_child(rim)

	var base := MeshInstance3D.new()
	var bc2 := CylinderMesh.new()
	bc2.top_radius = TUBE_R + 0.012
	bc2.bottom_radius = TUBE_R + 0.03
	bc2.height = 0.03
	bc2.radial_segments = 40
	base.mesh = bc2
	base.material_override = dark
	base.position.y = 0.0
	model.add_child(base)

	# lueur de la mèche au fond du tube
	_glow = MeshInstance3D.new()
	var gm := SphereMesh.new()
	gm.radius = 0.03
	gm.height = 0.06
	_glow.mesh = gm
	var glm := StandardMaterial3D.new()
	glm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glm.albedo_color = Color(1.0, 0.5, 0.15) * 1.2
	_glow.material_override = glm
	_glow.position.y = 0.2
	_glow.visible = false
	model.add_child(_glow)


func _build_shell() -> void:
	_shell = Node3D.new()
	_shell.visible = false
	add_child(_shell)
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.028
	cm.bottom_radius = 0.028
	cm.height = 0.075
	body.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.18, 0.55)
	m.roughness = 0.55
	body.material_override = m
	_shell.add_child(body)
	var cap := MeshInstance3D.new()
	var capm := CylinderMesh.new()
	capm.top_radius = 0.012
	capm.bottom_radius = 0.028
	capm.height = 0.02
	cap.mesh = capm
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.85, 0.62, 0.18)
	gold.metallic = 0.8
	gold.roughness = 0.35
	cap.material_override = gold
	cap.position.y = 0.0475
	_shell.add_child(cap)
	var fuse := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.003
	fm.bottom_radius = 0.003
	fm.height = 0.05
	fuse.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.7, 0.55, 0.3)
	fuse.material_override = fmat
	fuse.position.y = 0.083
	_shell.add_child(fuse)

	_fuse_tip = MeshInstance3D.new()
	var tip := SphereMesh.new()
	tip.radius = 0.006
	tip.height = 0.012
	_fuse_tip.mesh = tip
	var tipm := StandardMaterial3D.new()
	tipm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tipm.albedo_color = Color(1.0, 0.7, 0.3) * 4.0
	_fuse_tip.material_override = tipm
	_fuse_tip.position.y = 0.109
	_fuse_tip.visible = false
	_shell.add_child(_fuse_tip)

	_fuse_sparks = GPUParticles3D.new()
	_fuse_sparks.amount = 40
	_fuse_sparks.lifetime = 0.35
	_fuse_sparks.emitting = false
	_fuse_sparks.local_coords = false
	_fuse_sparks.position.y = 0.109
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
	q.size = Vector2(0.025, 0.025)
	q.material = FireworkShell.spark_material(Color(1, 0.8, 0.5), 3.0)
	_fuse_sparks.draw_pass_1 = q
	_shell.add_child(_fuse_sparks)

	_fuse_light = OmniLight3D.new()
	_fuse_light.light_color = Color(1.0, 0.6, 0.25)
	_fuse_light.light_energy = 0.0
	_fuse_light.omni_range = 3.0
	_fuse_light.position.y = 0.11
	_shell.add_child(_fuse_light)


func _build_lighter() -> void:
	_lighter = Node3D.new()
	_lighter.visible = false
	add_child(_lighter)
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

func attach_to(h: Human) -> void:
	human = h
	h.torso.add_child(self)
	_shell.reparent(h.torso, false)
	_lighter.reparent(h.torso, false)
	position = Vector3(0.12, -0.14, -0.34)
	rotation = Vector3(-0.22, 0.0, 0.0)
	h.hand_provider = Callable(self, "_hand_targets")


func set_equipped(on: bool) -> void:
	if busy:
		return
	equipped = on
	visible = on


func axis_world() -> Vector3:
	return (model.global_basis * Vector3.UP).normalized()


func mouth_world() -> Vector3:
	return model.to_global(Vector3(0, TUBE_LEN, 0))


# ------------------------------------------------------------------- sequence

func try_fire() -> void:
	if not equipped or busy:
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
	_shell.visible = false
	_fuse_tip.visible = false


func reload_all() -> void:
	ammo = MAX_AMMO
	ammo_changed.emit(ammo, MAX_AMMO)


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


# torso-local point from a tube-local point
func _tl(p: Vector3) -> Vector3:
	return (transform * model.transform) * p


func _times() -> Dictionary:
	var a := T_GRAB1
	var b := a + T_GRAB2
	var c := b + T_IGNITE
	var d := c + T_LOAD
	var e := d + T_DROP
	var f := e + T_RET
	return {"grab1": a, "grab2": b, "ignite": c, "load": d, "drop": e, "ret": f}


func step(delta: float) -> void:
	_recoil = move_toward(_recoil, 0.0, delta / T_RECOIL)
	var r := _recoil * _recoil
	model.position = Vector3(0, 0.0, 0.06 * r)
	model.rotation = Vector3(0.18 * r, 0, 0)
	_glow.visible = false
	_fuse_light.light_energy = 0.0
	_flame_light.light_energy = 0.0

	if _t < 0.0:
		return
	_t += delta
	var T := _times()

	# --- étincelles de la mèche : allumée après le contact du briquet
	var lit_from: float = float(T["grab2"]) + 0.45
	var lit := _t >= lit_from
	_fuse_tip.visible = lit and _shell.visible
	_fuse_sparks.emitting = lit and _shell.visible
	if lit and _shell.visible:
		_fuse_light.light_energy = 0.8 + _rng.randf() * 0.7
	if _t >= float(T["drop"]) and _t < float(T["drop"]) + T_LAUNCH_AFTER_DROP + 0.05:
		_glow.visible = true
		_glow.position.y = 0.06
		_flame_light.light_energy = 0.0

	# --- le lancement
	var launch_t: float = float(T["drop"]) + T_LAUNCH_AFTER_DROP
	if not _launched and _t >= launch_t:
		_launched = true
		_launch()
	if _t >= launch_t + T_RECOIL:
		_t = -1.0
		busy = false

	# visibilité de l'obus et du briquet
	var shell_vis := _t >= float(T["grab1"]) * 0.75 and _t < float(T["drop"])
	_shell.visible = shell_vis
	var ign_a: float = float(T["grab2"])
	var ign_b: float = float(T["ignite"])
	_lighter.visible = _t > ign_a - 0.1 and _t < ign_b + 0.05
	var flame_on := _t > ign_a + 0.25 and _t < ign_b - 0.15
	_flame.visible = flame_on
	if flame_on:
		_flame_light.light_energy = 0.9 + _rng.randf() * 0.5
		_flame.scale = Vector3(1, 0.8 + _rng.randf() * 0.5, 1)
	# sons
	if _t >= ign_a + 0.2 and _t - delta < ign_a + 0.2:
		_sfx_ignite.play()
	if _t >= ign_a + 0.55 and _t - delta < ign_a + 0.55:
		_sfx_hiss.play()


func _hand_pos_r() -> Vector3:
	var T := _times()
	var grip := _tl(Vector3(0.05, 0.16, 0.0))
	var pouch := Vector3(0.27, -0.12, -0.02)
	var chest := Vector3(0.16, 0.18, -0.30)
	var above := _tl(Vector3(0.0, TUBE_LEN + 0.12, 0.0))
	var inside := _tl(Vector3(0.0, TUBE_LEN + 0.02, 0.0))
	var t := _t
	if t < T["grab1"]:
		return grip.lerp(pouch, _ease(t / T["grab1"]))
	if t < T["grab2"]:
		return pouch.lerp(chest, _ease((t - T["grab1"]) / T_GRAB2))
	if t < T["ignite"]:
		var shake := Vector3(sin(t * 60.0), cos(t * 47.0), 0) * 0.002
		return chest + shake
	if t < T["load"]:
		return chest.lerp(above, _ease((t - T["ignite"]) / T_LOAD))
	if t < T["drop"]:
		return above.lerp(inside, _ease((t - T["load"]) / T_DROP))
	if t < T["ret"]:
		return inside.lerp(grip, _ease((t - T["drop"]) / T_RET))
	return grip


func _hand_pos_l() -> Vector3:
	var T := _times()
	var grip := _tl(Vector3(-0.05, 0.34, 0.0))
	var chest := Vector3(0.16, 0.18, -0.30)
	var tip := chest + Vector3(0.0, 0.11, 0.0) # bout de mèche
	var light_pos := tip + Vector3(-0.02, -0.075, -0.015)
	var t := _t
	var a: float = T["grab2"]
	var b: float = T["ignite"]
	if t < a - 0.05:
		return grip
	if t < a + 0.25:
		return grip.lerp(light_pos, _ease((t - (a - 0.05)) / 0.30))
	if t < b - 0.15:
		return light_pos
	if t < b + 0.15:
		return light_pos.lerp(grip, _ease((t - (b - 0.15)) / 0.30))
	return grip


func _hand_targets() -> Array:
	if not equipped:
		return [null, null]
	var tor := human.torso
	var r_local: Vector3
	var l_local: Vector3
	if _t < 0.0:
		r_local = _tl(Vector3(0.05, 0.16, 0.0))
		l_local = _tl(Vector3(-0.05, 0.34, 0.0))
	else:
		r_local = _hand_pos_r()
		l_local = _hand_pos_l()
	_update_props(r_local, l_local)
	return [tor.to_global(r_local), tor.to_global(l_local)]


func _update_props(r_local: Vector3, l_local: Vector3) -> void:
	if _t < 0.0:
		return
	var T := _times()
	if _shell.visible:
		var pos := r_local
		if _t >= float(T["load"]): # l'obus glisse dans le tube
			var k := _ease((_t - float(T["load"])) / T_DROP)
			pos = _tl(Vector3(0, lerpf(TUBE_LEN + 0.12, TUBE_LEN - 0.12, k), 0))
		_shell.position = pos
		_shell.basis = (transform * model.transform).basis
	if _lighter.visible:
		_lighter.position = l_local
		_lighter.basis = Basis(Vector3.BACK, 0.15)


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
	light.light_energy = 2.5
	light.omni_range = 9.0
	root.add_child(light)
	var tw := root.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.12).set_ease(Tween.EASE_OUT)

	# étincelles de sortie
	var sp := GPUParticles3D.new()
	sp.amount = 60
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
	q.size = Vector2(0.08, 0.08)
	q.material = FireworkShell.spark_material(Color(1, 0.8, 0.5), 3.0)
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
