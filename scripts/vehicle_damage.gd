class_name VehicleDamage
extends Node3D
## Dégradations d'un véhicule de police : vitres cassables (pare-brise, vitres de portières), bosses sur la
## carrosserie (décalques à relief), incendie (flammes, fumée, lueur, foule qui regarde), carcasse calcinée et,
## bien plus tard, explosion. Les événements « car_vandal » / « car_burn » alimentent la tension.

signal pane_broken(pane: GlassPane)
signal ignited

const DENT_LAYER := 1 << 4          # couche visuelle des surfaces qui reçoivent les bosses
const MAX_DENTS := 18

var car: PoliceVehicle
var crowd: Crowd
var panes: Array[GlassPane] = []
var burning := false
var heat := 0.0
var charred := 0.0
var exploded := false
var interior_open := false
var windshield_broken := false
var dents := 0
var by_player := false               # c'est le joueur qui y a mis le feu

var _fires: Array[FireFx] = []
var _burn_t := 0.0
var _acc := 0.0
var _check_t := 0.0
var _decals: Array[Decal] = []
var _own_mats := false
var _pops := 0
var _last_evt := -99.0
var _mat_list: Array = []            # [MeshInstance3D, Material d'origine]
var _smoke_end: GPUParticles3D

static var _dent_tex_a: Texture2D
static var _dent_tex_n: Texture2D


func setup(c: PoliceVehicle) -> void:
	car = c
	crowd = c.crowd
	# surfaces qui reçoivent les bosses
	for m in car._body.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).layers |= DENT_LAYER
	if car.kind == "car":
		_pane("ws", Vector2(1.45, 0.86), Vector3(0, 1.195, -0.575), Vector3(deg_to_rad(61.3), 0, 0), 125.0, true)
		_pane("rear", Vector2(1.25, 0.5), Vector3(0, 1.21, 1.43), Vector3(deg_to_rad(-63.7), 0, 0), 110.0, false)
		# vitres latérales : posées contre l'habitacle, inclinées comme lui (le haut rentre de ~13°)
		var tilt := Vector3(deg_to_rad(-13.0), 0.0, 0.0)
		for sx in [-1.0, 1.0]:
			_pane("side", Vector2(0.78, 0.31), Vector3(sx * 0.742, 1.15, -0.38), tilt + Vector3(0, sx * PI * 0.5, 0), 80.0, false)
			_pane("side", Vector2(0.74, 0.30), Vector3(sx * 0.742, 1.14, 0.78), tilt + Vector3(0, sx * PI * 0.5, 0), 80.0, false)
		# l'habitacle devient mat : une fois les vitres parties, on voit l'intérieur sombre
		if car.glass_loft != null:
			car.glass_loft.material_override = PoliceVehicle.mat("dark")
	else:
		_pane("ws", Vector2(1.9, 0.8), Vector3(0, 1.91, -2.745), Vector3(deg_to_rad(24), 0, 0), 140.0, true)
		for sx in [-1.0, 1.0]:
			_pane("side", Vector2(1.0, 0.78), Vector3(sx * 1.098, 1.88, -2.0), Vector3(0, sx * PI * 0.5, 0), 90.0, false)
		for g in car.glass_meshes:
			(g as Node3D).visible = false


func _pane(role: String, size: Vector2, pos: Vector3, rot: Vector3, break_at: float, slowmo: bool) -> void:
	var p := GlassPane.new()
	p.size = size
	p.kind = "car"
	p.break_at = break_at
	p.slowmo = slowmo
	p.thick = 0.01
	p.glass_color = Color(0.05, 0.07, 0.1, 0.2)
	p.spec = 0.3
	p.use_rim = false
	p.position = pos
	p.rotation = rot
	p.set_meta("role", role)
	car._body.add_child(p)
	p.add_to_group("breakable")
	p.hit_event.connect(_on_pane_hit)
	p.broken_event.connect(func(pt: Vector3): _on_pane_broken(p, pt))
	panes.append(p)


func _on_pane_hit(point: Vector3, amount: float) -> void:
	_vandal_event(point, 0.006 + amount * 0.0002)


func _on_pane_broken(p: GlassPane, point: Vector3) -> void:
	var role: String = p.get_meta("role", "side")
	if role == "ws":
		windshield_broken = true
	interior_open = true
	_vandal_event(point, 0.03)
	pane_broken.emit(p)
	if is_inside_tree():
		get_tree().call_group("crowd", "on_event", "car_glass", {"pos": point, "car": car, "role": role})


func _vandal_event(point: Vector3, amount: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_evt < 1.0:
		return
	_last_evt = now
	get_tree().call_group("crowd", "on_event", "car_vandal", {"pos": point, "car": car, "amount": amount})


# =================================================================== bosses
## Coup sur la carrosserie : bosse + bruit de tôle + secousse. Renvoie false si le coup ne touche pas le véhicule.
func hit_body(point: Vector3, dir: Vector3, power := 1.0) -> bool:
	if car == null or burning and heat > 1.2:
		return false
	var d := dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var space := car.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(point - d * 0.45, point + d * 0.75, 1)
	q.collide_with_bodies = true
	var r := space.intersect_ray(q)
	if r.is_empty() or r["collider"] != car._static_body:
		return false
	var pos: Vector3 = r["position"]
	var n: Vector3 = r["normal"]
	if n.y > 0.8:
		# le dessus (capot, toit) : coup donné d'en haut
		pass
	_add_dent(pos, n, power)
	AudioLib.play_at(car, "car_dent_%d" % (randi() % 3), pos, 1.0 + 3.0 * minf(power, 1.2), 12.0, randf_range(0.9, 1.1))
	car.bump(0.5 * power, n)
	_vandal_event(pos, 0.004 + 0.006 * power)
	return true


func _add_dent(pos: Vector3, n: Vector3, power: float) -> void:
	_make_tex()
	var dc := Decal.new()
	var sz := 0.32 + randf() * 0.14 + 0.1 * power
	dc.size = Vector3(sz, 0.34, sz)
	dc.texture_albedo = _dent_tex_a
	dc.texture_normal = _dent_tex_n
	dc.normal_fade = 0.2
	dc.upper_fade = 0.25
	dc.lower_fade = 0.25
	dc.cull_mask = DENT_LAYER
	dc.modulate = Color(1, 1, 1, 0.9)
	car._body.add_child(dc)
	dc.global_position = pos + n * 0.03
	var x := n.cross(Vector3.UP)
	if x.length() < 0.2:
		x = n.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(n).normalized()
	dc.global_basis = Basis(n, randf() * TAU) * Basis(x, n, z)
	_decals.append(dc)
	dents += 1
	if _decals.size() > MAX_DENTS:
		var old: Decal = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()


static func _make_tex() -> void:
	if _dent_tex_a != null:
		return
	var n := 96
	var a := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var nm := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (float(x) + 0.5) / float(n) * 2.0 - 1.0
			var v := (float(y) + 0.5) / float(n) * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			# creux : h(r) = -(1 - r²)², bourrelet léger vers r = 0.9
			var hh := 0.0
			var dh_dr := 0.0
			if r < 1.0:
				var t := 1.0 - r * r
				hh = -t * t
				dh_dr = 4.0 * r * t
				# bourrelet
				dh_dr += -0.5 * exp(-pow((r - 0.86) / 0.1, 2.0)) * 2.0 * (r - 0.86) / 0.01 * 0.02
			var nx := 0.0
			var ny := 0.0
			if r > 0.001 and r < 1.0:
				nx = -dh_dr * (u / r) * 2.1
				ny = -dh_dr * (v / r) * 2.1
			var nz := 1.0
			var l := sqrt(nx * nx + ny * ny + nz * nz)
			nm.set_pixel(x, y, Color(nx / l * 0.5 + 0.5, ny / l * 0.5 + 0.5, nz / l * 0.5 + 0.5, 1.0 if r < 1.0 else 0.0))
			var al := 0.0
			if r < 1.0:
				al = pow(1.0 - r, 1.6) * 0.62 + (0.2 if r > 0.55 and r < 0.9 else 0.0)
			a.set_pixel(x, y, Color(0.09, 0.09, 0.1, clampf(al, 0.0, 0.6)))
	_dent_tex_a = ImageTexture.create_from_image(a)
	_dent_tex_n = ImageTexture.create_from_image(nm)


# =================================================================== feu
func _physics_process(delta: float) -> void:
	if car == null:
		return
	if not burning:
		_check_t += delta
		if _check_t >= 0.2:
			var dt := _check_t
			_check_t = 0.0
			_scan_ignition(dt)
			if _acc > 0.0:
				_acc = maxf(_acc - 0.05 * dt, 0.0)
		return
	_update_burn(delta)


## Point (monde) au contact de la caisse ?
func near_body(p: Vector3, margin := 0.35) -> bool:
	var l := car.to_local(p)
	var top := 1.7 if car.kind == "car" else 2.9
	return absf(l.x) < car.half.x + margin and absf(l.z) < car.half.y + margin and l.y > -0.1 and l.y < top + margin


func in_cabin(p: Vector3) -> bool:
	var l := car.to_local(p)
	if car.kind == "car":
		return absf(l.x) < 0.75 and l.z > -0.9 and l.z < 1.5 and l.y > 0.9 and l.y < 1.5
	return absf(l.x) < 1.0 and l.z > -2.9 and l.z < -1.0 and l.y > 1.0 and l.y < 2.4


func _scan_ignition(dt: float) -> void:
	for f in get_tree().get_nodes_in_group("flares"):
		var fl := f as Flare
		if fl == null or not fl.lit or fl.spent:
			continue
		var tip := fl.tip_world()
		if near_body(tip, 0.3):
			_acc += (0.6 + (0.5 if (interior_open and in_cabin(tip)) else 0.0)) * dt
			if fl.by_player:
				by_player = true
	for b in get_tree().get_nodes_in_group("burnables"):
		var bu := b as Burnable
		if bu == null or not bu.lit or bu.fire != null or bu.in_bin != null:
			continue
		if near_body(bu.global_position, 0.3):
			_acc += (0.22 + (0.3 if (interior_open and in_cabin(bu.global_position)) else 0.0)) * dt
	if _acc >= 1.0:
		ignite()


func ignite() -> void:
	if burning or exploded:
		return
	burning = true
	heat = 0.3
	_burn_t = 0.0
	car.add_to_group("fire_sources")
	# foyers : compartiment moteur (capot) et habitacle
	var specs: Array = []
	if car.kind == "car":
		specs = [[Vector3(0, 0.98, -1.45), Vector3(0.5, 0.05, 0.45), 0.62, 1.1], [Vector3(0, 1.0, 0.25), Vector3(0.4, 0.05, 0.8), 0.5, 0.9]]
	else:
		specs = [[Vector3(0, 1.4, -2.9), Vector3(0.7, 0.05, 0.3), 0.75, 1.3], [Vector3(0, 2.3, -2.0), Vector3(0.7, 0.05, 0.5), 0.6, 1.1]]
	var first := true
	for s in specs:
		var fx := FireFx.new()
		fx.extent = s[1]
		fx.flame_size = s[2]
		fx.smoke_size = s[3]
		fx.smoke_rise = 1.9
		fx.smoke_amount = 38
		fx.light_range = 11.0 if first else 7.0
		fx.light_energy = 6.0 if first else 3.5
		fx.light_y = 0.3
		fx.shadows = first
		fx.sound_unit = 9.0
		fx.sound_gain = 3.0 if first else -3.0
		fx.position = s[0]
		car._body.add_child(fx)
		fx.start()
		fx.ignite_burst()
		_fires.append(fx)
		first = false
	var p := car.global_position + Vector3.UP * 1.0
	get_tree().call_group("crowd", "on_event", "car_burn", {"pos": p, "car": car, "player": by_player})
	get_tree().call_group("crowd", "on_event", "fire_start", {"pos": p, "floor": false, "car": true, "bin": car})
	ignited.emit()


func _update_burn(delta: float) -> void:
	_burn_t += delta
	# montée en puissance puis lente extinction
	var target := clampf(0.3 + _burn_t / 38.0, 0.0, 1.4)
	if _burn_t > 150.0:
		target = maxf(1.4 - (_burn_t - 150.0) / 40.0, 0.0)
	heat = move_toward(heat, target, delta * 0.12)
	charred = clampf(_burn_t / 55.0, 0.0, 1.0)
	_apply_char()
	var t := Time.get_ticks_msec() / 1000.0
	for i in _fires.size():
		var k := 1.0 if i == 0 else 0.85
		_fires[i].update(heat * k * (0.9 + 0.1 * sin(t * 3.0 + float(i))))
	# les pneus éclatent l'un après l'autre : la caisse s'affaisse
	var pop_times := [18.0, 24.0, 31.0, 39.0]
	if _pops < pop_times.size() and _burn_t > float(pop_times[_pops]):
		_pops += 1
		AudioLib.play_at(car, "tire_pop", car.global_position + Vector3(randf_range(-0.8, 0.8), 0.3, randf_range(-1.5, 1.5)), 0.0, 12.0, randf_range(0.9, 1.1))
		car.sag += 0.018
		car.bump(0.6, Vector3.UP)
	# gyrophares et sirène : grillés au bout de quelques secondes
	if _burn_t > 9.0 and car.lights_on:
		car.set_lights(false, false)
	# explosion du réservoir
	if not exploded and _burn_t > 64.0 and heat > 1.05:
		explode()
	if _burn_t > 190.0 and burning and heat <= 0.01:
		_die_down()


func _apply_char() -> void:
	if not _own_mats:
		_own_mats = true
		for m in car._body.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var mo := mi.material_override
			var is_decal: bool = mo is StandardMaterial3D and (mo as StandardMaterial3D).albedo_texture != null and (mo as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
			if mo is StandardMaterial3D and (is_decal or mo == PoliceVehicle.mat("car_white") or mo == PoliceVehicle.mat("van_navy") or mo == PoliceVehicle.mat("glass")):
				_mat_list.append([mi, mo])
				mi.material_override = mo.duplicate()
	for e in _mat_list:
		var mi2: MeshInstance3D = e[0]
		if not is_instance_valid(mi2):
			continue
		var orig: StandardMaterial3D = e[1]
		var mm := mi2.material_override as StandardMaterial3D
		mm.albedo_color = orig.albedo_color.lerp(Color(0.025, 0.022, 0.02), charred)
		mm.roughness = lerpf(orig.roughness, 0.95, charred)
		mm.clearcoat_enabled = orig.clearcoat_enabled and charred < 0.4
		mm.metallic_specular = lerpf(orig.metallic_specular, 0.2, charred)


func explode() -> void:
	if exploded:
		return
	exploded = true
	var scene := get_tree().current_scene
	var pos := car.global_position + Vector3(0, 0.9, 0)
	AudioLib.play_at(car, "car_explosion", pos, 4.0, 60.0, 1.0)
	# boule de feu + éclair
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.7, 0.35)
	flash.light_energy = 22.0
	flash.omni_range = 26.0
	scene.add_child(flash)
	flash.global_position = pos + Vector3.UP * 0.8
	var tw := flash.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.7)
	tw.tween_callback(flash.queue_free)
	for fx in _fires:
		fx.flare_up_burst(4.0)
	_heat_burst(pos)
	# la porte avant et le capot sont projetés
	for i in 6:
		var sh := RigidBody3D.new()
		sh.collision_layer = 4
		sh.collision_mask = 1
		sh.mass = 3.0
		var bm := BoxMesh.new()
		var sz := Vector3(randf_range(0.25, 0.7), randf_range(0.02, 0.05), randf_range(0.25, 0.6))
		bm.size = sz
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = Furniture.mat("wreck", Color(0.07, 0.065, 0.06), 0.8, 0.6)
		sh.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = sz
		cs.shape = bs
		sh.add_child(cs)
		scene.add_child(sh)
		sh.global_position = pos + Vector3(randf_range(-0.8, 0.8), randf_range(0.2, 1.0), randf_range(-1.4, 1.4))
		sh.linear_velocity = Vector3(randf_range(-5, 5), randf_range(4, 9), randf_range(-5, 5))
		sh.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		get_tree().create_timer(randf_range(14.0, 24.0)).timeout.connect(func():
			if is_instance_valid(sh):
				Fx.shrink_and_free(sh, 1.0))
	car.bump(2.0, Vector3.UP)
	# panneaux de verre qui restent : tout part
	for p in panes:
		if is_instance_valid(p) and p.alive():
			p.hit(p.global_position, 400.0, Vector3.UP)
	get_tree().call_group("crowd", "on_event", "burst", {"pos": pos, "car": true})


## Souffle : joueur renversé s'il est tout près ; PNJ et policiers réagissent via l'événement « burst »
func _heat_burst(pos: Vector3) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		var pl := p as Player
		if pl:
			var dd := pl.global_position + Vector3.UP * 0.9 - pos
			if dd.length() < 7.0:
				pl.on_blast(dd.length() / 7.0, pos, 2)
				pl.hit_flash = 1.0


func _die_down() -> void:
	burning = false
	car.remove_from_group("fire_sources")
	for fx in _fires:
		fx.stop(true)
		fx.update(0.0, 0.0, true, 0.6)


# --- interface commune des foyers (utilisée par la foule)
func fire_center() -> Vector3:
	return car.global_position + Vector3(0, 1.0 + 0.5 * heat, 0)


func stand_pos(from: Vector3) -> Vector3:
	var c := car.global_position
	var d := Vector3(from.x - c.x, 0, from.z - c.z)
	d = d.normalized() if d.length() > 0.05 else Vector3(1, 0, 0)
	return c + d * (4.0 + 0.8 * heat)
