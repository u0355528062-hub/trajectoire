class_name TrashBin
extends RigidBody3D
## Poubelle à roulettes (240 L) : couvercle à charnière (s'ouvre / se ferme), se déplace
## (on la bascule sur ses roues et on la tire), et peut brûler. Le feu se nourrit de ce
## qu'on y jette, s'étouffe quand on referme le couvercle, noircit le plastique.

const BX0 := 0.25   # demi-largeur en bas
const BZ0 := 0.30
const BX1 := 0.29   # demi-largeur en haut
const BZ1 := 0.36
const Y0 := 0.04
const Y1 := 1.0
const TH := 0.022
const OPEN_ANGLE := 4.25   # le couvercle bascule et pend derrière, contre la poignée

var body_color := Color(0.12, 0.27, 0.17)
var lid_color := Color(0.12, 0.27, 0.17)
var contents := 1.0       # déchets dans la poubelle (combustible)
var heat := 0.0           # intensité du feu 0..1.4
var burning := false
var char_amt := 0.0
var lid_open := false
var grabbed_by: Node3D = null

var _lid_pivot: Node3D
var _lid_angle := 0.0
var _lid_vel := 0.0
var _lid_shape: CollisionShape3D
var _pivot: Node3D       # axe des roues (bascule)
var _model: Node3D
var _tilt := 0.0
var _mat: StandardMaterial3D
var _lid_mat: StandardMaterial3D
var _trash: Node3D
var _items: Array[Node3D] = []
var _fx: FireFx
var tipped := false
var _righting := false
var _tip_axis := Vector3.ZERO
var _tip_t := 0.0
var _snd_roll: AudioStreamPlayer3D
var _boost := 0.0
var _smother_t := 0.0
var _seed := 0.0
var _last_hit := 0.0
var _out_smoke := 0.0
var _floor_shape: CollisionShape3D
var _frame_i := 0


func _ready() -> void:
	_seed = randf() * 100.0
	add_to_group("bins")
	add_to_group("fire_sources")
	add_to_group("kickable")
	mass = 16.0
	collision_layer = 32
	collision_mask = 1 | 32
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	linear_damp = 2.2
	angular_damp = 5.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.3, 0)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce = 0.05
	physics_material_override = pm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = body_color
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 0.62
	_mat.metallic_specular = 0.42
	_lid_mat = _mat.duplicate()
	_lid_mat.albedo_color = lid_color
	_build_model()
	_build_collision()
	_build_fire()
	_snd_roll = AudioStreamPlayer3D.new()
	_snd_roll.stream = AudioLib.stream("bin_roll", true)
	_snd_roll.volume_db = -60.0
	_snd_roll.unit_size = 4.0
	add_child(_snd_roll)


# ------------------------------------------------------------------ modèle
func _half(y: float) -> Vector2:
	var k := clampf((y - Y0) / (Y1 - Y0), 0.0, 1.0)
	return Vector2(lerpf(BX0, BX1, k), lerpf(BZ0, BZ1, k))


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tmp := b
		b = c
		c = tmp
	for v in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col_lo: Color, col_hi: Color) -> void:
	# a,b en bas, c,d en haut : dégradé de salissure vers le bas
	var cols := {a: col_lo, b: col_lo, c: col_hi, d: col_hi}
	var tris := [[a, b, c], [a, c, d]]
	for t in tris:
		var p0: Vector3 = t[0]
		var p1: Vector3 = t[1]
		var p2: Vector3 = t[2]
		if (p1 - p0).cross(p2 - p0).dot(n) > 0.0:
			var tmp := p1
			p1 = p2
			p2 = tmp
		for v in [p0, p1, p2]:
			st.set_color(cols[v])
			st.set_normal(n)
			st.add_vertex(v)


func _build_model() -> void:
	_pivot = Node3D.new()
	_pivot.position = Vector3(0, 0.1, BZ0 + 0.05)
	add_child(_pivot)
	_model = Node3D.new()
	_model.position = -_pivot.position
	_pivot.add_child(_model)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dirt := Color(0.62, 0.6, 0.56)
	var clean := Color(1, 1, 1)
	var inside := Color(0.3, 0.3, 0.3)
	var ho0 := _half(Y0)
	var ho1 := _half(Y1)
	# 4 parois extérieures + intérieures
	var sides := [[Vector2(-1, -1), Vector2(1, -1)], [Vector2(1, -1), Vector2(1, 1)], [Vector2(1, 1), Vector2(-1, 1)], [Vector2(-1, 1), Vector2(-1, -1)]]
	for s in sides:
		var u: Vector2 = s[0]
		var w: Vector2 = s[1]
		var a := Vector3(u.x * ho0.x, Y0, u.y * ho0.y)
		var b := Vector3(w.x * ho0.x, Y0, w.y * ho0.y)
		var c := Vector3(w.x * ho1.x, Y1, w.y * ho1.y)
		var d := Vector3(u.x * ho1.x, Y1, u.y * ho1.y)
		var mid := (a + b + c + d) * 0.25
		var n := (b - a).cross(d - a).normalized()
		if n.dot(Vector3(mid.x, 0, mid.z)) < 0.0:
			n = -n
		_quad(st, a, b, c, d, n, dirt, clean)
		var ia := Vector3(u.x * (ho0.x - TH), Y0 + TH, u.y * (ho0.y - TH))
		var ib := Vector3(w.x * (ho0.x - TH), Y0 + TH, w.y * (ho0.y - TH))
		var ic := Vector3(w.x * (ho1.x - TH), Y1, w.y * (ho1.y - TH))
		var id_ := Vector3(u.x * (ho1.x - TH), Y1, u.y * (ho1.y - TH))
		_quad(st, ia, ib, ic, id_, -n, inside * 0.5, inside)
		# rebord supérieur
		_quad(st, id_, ic, c, d, Vector3.UP, clean, clean)
	# fond
	_quad(st, Vector3(-ho0.x, Y0, -ho0.y), Vector3(ho0.x, Y0, -ho0.y), Vector3(ho0.x, Y0, ho0.y), Vector3(-ho0.x, Y0, ho0.y), Vector3.DOWN, dirt, dirt)
	var fi := Vector2(ho0.x - TH, ho0.y - TH)
	_quad(st, Vector3(-fi.x, Y0 + TH, -fi.y), Vector3(fi.x, Y0 + TH, -fi.y), Vector3(fi.x, Y0 + TH, fi.y), Vector3(-fi.x, Y0 + TH, fi.y), Vector3.UP, inside * 0.4, inside * 0.4)
	var body := MeshInstance3D.new()
	body.mesh = st.commit()
	body.material_override = _mat
	_model.add_child(body)
	# lèvre du rebord, nervures, pieds, roues, poignée
	var rim_y := Y1 - 0.025
	var hr := _half(rim_y)
	var lip := [[Vector3(0, rim_y, -hr.y - 0.012), Vector3(hr.x * 2 + 0.05, 0.05, 0.025)], [Vector3(0, rim_y, hr.y + 0.012), Vector3(hr.x * 2 + 0.05, 0.05, 0.025)],
		[Vector3(-hr.x - 0.012, rim_y, 0), Vector3(0.025, 0.05, hr.y * 2 + 0.05)], [Vector3(hr.x + 0.012, rim_y, 0), Vector3(0.025, 0.05, hr.y * 2 + 0.05)]]
	for l in lip:
		_box(_model, l[1], l[0], _mat)
	var slope := atan((BZ1 - BZ0) / (Y1 - Y0))
	for x in [-0.15, 0.0, 0.15]:
		var y := 0.55
		var h := _half(y)
		_box(_model, Vector3(0.03, 0.62, 0.018), Vector3(x, y, -h.y - 0.006), _mat, Vector3(-slope, 0, 0))
	for sx in [-1.0, 1.0]:
		_box(_model, Vector3(0.07, 0.05, 0.08), Vector3(sx * (BX0 - 0.06), 0.025, -BZ0 + 0.07), _mat)
		var y := 0.55
		var h := _half(y)
		_box(_model, Vector3(0.02, 0.8, 0.05), Vector3(sx * (h.x + 0.004), y, h.y - 0.03), _mat, Vector3(0, 0, -sx * atan((BX1 - BX0) / (Y1 - Y0))))
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.04, 0.04, 0.045)
	rubber.roughness = 0.85
	var hub := StandardMaterial3D.new()
	hub.albedo_color = Color(0.25, 0.25, 0.27)
	hub.roughness = 0.5
	for sx in [-1.0, 1.0]:
		var wh := CylinderMesh.new()
		wh.top_radius = 0.1
		wh.bottom_radius = 0.1
		wh.height = 0.05
		wh.radial_segments = 24
		var w := MeshInstance3D.new()
		w.mesh = wh
		w.material_override = rubber
		w.position = Vector3(sx * (BX0 + 0.045), 0.1, BZ0 + 0.05)
		w.rotation.z = PI / 2
		_model.add_child(w)
		var hc := CylinderMesh.new()
		hc.top_radius = 0.05
		hc.bottom_radius = 0.05
		hc.height = 0.055
		var hm := MeshInstance3D.new()
		hm.mesh = hc
		hm.material_override = hub
		hm.position = w.position
		hm.rotation.z = PI / 2
		_model.add_child(hm)
	var axle := CylinderMesh.new()
	axle.top_radius = 0.012
	axle.bottom_radius = 0.012
	axle.height = BX0 * 2 + 0.1
	var ax := MeshInstance3D.new()
	ax.mesh = axle
	ax.material_override = hub
	ax.position = Vector3(0, 0.1, BZ0 + 0.05)
	ax.rotation.z = PI / 2
	_model.add_child(ax)
	_box(_model, Vector3(BX0 * 2 - 0.02, 0.16, 0.07), Vector3(0, 0.13, BZ0 + 0.0), _mat)
	var bar := CylinderMesh.new()
	bar.top_radius = 0.017
	bar.bottom_radius = 0.017
	bar.height = 0.46
	var hb := MeshInstance3D.new()
	hb.mesh = bar
	hb.material_override = _mat
	hb.position = Vector3(0, 0.965, BZ1 + 0.075)
	hb.rotation.z = PI / 2
	_model.add_child(hb)
	for sx in [-1.0, 1.0]:
		_box(_model, Vector3(0.035, 0.06, 0.09), Vector3(sx * 0.21, 0.965, BZ1 + 0.035), _mat)
	# déchets (sacs, papiers)
	_trash = Node3D.new()
	_model.add_child(_trash)
	var bag := StandardMaterial3D.new()
	bag.albedo_color = Color(0.03, 0.03, 0.035)
	bag.roughness = 0.35
	bag.metallic_specular = 0.6
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_seed * 1000.0)
	for i in 5:
		var sp := SphereMesh.new()
		sp.radius = 0.17
		sp.height = 0.26
		var m := MeshInstance3D.new()
		m.mesh = sp
		m.material_override = bag
		m.position = Vector3(rng.randf_range(-0.1, 0.1), 0.62 + rng.randf_range(-0.05, 0.05), rng.randf_range(-0.14, 0.14))
		m.scale = Vector3(rng.randf_range(0.8, 1.1), rng.randf_range(0.6, 0.9), rng.randf_range(0.8, 1.1))
		_trash.add_child(m)
	for i in 3:
		var pb := MeshInstance3D.new()
		pb.mesh = Props.paper_ball_mesh()
		pb.material_override = Props.paper_material()
		pb.position = Vector3(rng.randf_range(-0.15, 0.15), 0.8, rng.randf_range(-0.2, 0.2))
		pb.rotation = Vector3(rng.randf(), rng.randf(), rng.randf()) * 3.0
		_trash.add_child(pb)
	# couvercle (charnière à l'arrière)
	_lid_pivot = Node3D.new()
	_lid_pivot.position = Vector3(0, Y1 + 0.025, BZ1 + 0.03)
	_model.add_child(_lid_pivot)
	var lw := BX1 * 2 + 0.07
	var ld := BZ1 * 2 + 0.07
	_box(_lid_pivot, Vector3(lw, 0.03, ld), Vector3(0, 0.0, -ld * 0.5), _lid_mat)
	_box(_lid_pivot, Vector3(lw - 0.06, 0.02, ld - 0.08), Vector3(0, 0.022, -ld * 0.5 - 0.01), _lid_mat)
	_box(_lid_pivot, Vector3(lw, 0.06, 0.02), Vector3(0, -0.035, -ld + 0.008), _lid_mat)
	_box(_lid_pivot, Vector3(0.2, 0.025, 0.04), Vector3(0, -0.02, -ld - 0.012), _lid_mat)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	parent.add_child(m)
	return m


func _build_collision() -> void:
	var defs := [
		[Vector3(BX0 * 2, 0.06, BZ0 * 2 + 0.1), Vector3(0, 0.03, 0.03)],
		[Vector3(BX1 * 2 + 0.04, 0.96, 0.04), Vector3(0, 0.52, -(BZ0 + BZ1) * 0.5 - 0.01)],
		[Vector3(BX1 * 2 + 0.04, 0.96, 0.04), Vector3(0, 0.52, (BZ0 + BZ1) * 0.5 + 0.01)],
		[Vector3(0.04, 0.96, BZ1 * 2), Vector3(-(BX0 + BX1) * 0.5 - 0.01, 0.52, 0)],
		[Vector3(0.04, 0.96, BZ1 * 2), Vector3((BX0 + BX1) * 0.5 + 0.01, 0.52, 0)],
	]
	for d in defs:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = d[0]
		cs.shape = bs
		cs.position = d[1]
		add_child(cs)
	# fond intérieur au niveau des déchets (les objets jetés s'y posent)
	_floor_shape = CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(BX0 * 2, 0.05, BZ0 * 2)
	_floor_shape.shape = fb
	_floor_shape.position = Vector3(0, 0.66, 0)
	add_child(_floor_shape)
	_lid_shape = CollisionShape3D.new()
	var lb := BoxShape3D.new()
	lb.size = Vector3(BX1 * 2 + 0.07, 0.04, BZ1 * 2 + 0.07)
	_lid_shape.shape = lb
	_lid_shape.position = Vector3(0, Y1 + 0.03, 0)
	add_child(_lid_shape)


func _build_fire() -> void:
	_fx = FireFx.new()
	_fx.extent = Vector3(0.17, 0.03, 0.22)
	_fx.flame_size = 0.42
	_fx.light_y = 0.55
	_fx.light_range = 6.0
	_fx.light_energy = 3.2
	_fx.position = Vector3(0, 0.74, 0)
	_model.add_child(_fx)


# ------------------------------------------------------------------ interface
func is_open() -> bool:
	return _lid_angle > 1.2


func top_center() -> Vector3:
	return _model.to_global(Vector3(0, Y1, 0))


func fire_center() -> Vector3:
	return _model.to_global(Vector3(0, 0.95 + 0.4 * heat, 0))


# --- interface commune des foyers (poubelle / feu au sol) utilisée par les PNJ
func stand_pos(from: Vector3) -> Vector3:
	var c := global_position
	var d := Vector3(from.x - c.x, 0, from.z - c.z)
	d = d.normalized() if d.length() > 0.05 else Vector3(1, 0, 0)
	return c + d * 0.98


func hand_target() -> Vector3:
	return top_center() + Vector3.UP * 0.04


func can_take_items() -> bool:
	return not tipped and not _righting and is_open()


func feed_item(item: Node3D, from: Vector3) -> bool:
	return deposit(item, from)


func set_lid(open: bool) -> void:
	if open == lid_open:
		return
	lid_open = open
	_lid_vel = 0.0
	AudioLib.play_at(self, "bin_lid_open" if open else "bin_lid_close", top_center(), -4.0, 5.0, randf_range(0.95, 1.05))
	if open and burning:
		_boost = maxf(_boost, 0.45)   # l'air s'engouffre : la flamme repart d'un coup
		AudioLib.play_at(self, "fire_flare_up", top_center(), 0.0, 7.0)
	get_tree().call_group("crowd", "on_event", "lid", {"bin": self, "pos": top_center(), "open": open})


func toggle_lid() -> void:
	set_lid(not lid_open)


## Un objet (déchet, fumigène) entre-t-il par l'ouverture ?
func try_accept(item: Node3D) -> bool:
	if tipped or not is_open() or grabbed_by != null and _tilt > 0.2:
		return false
	var l := _model.to_local(item.global_position)
	var h := _half(clampf(l.y, Y0, Y1))
	if absf(l.x) > h.x - 0.02 or absf(l.z) > h.y - 0.02 or l.y > Y1 + 0.05 or l.y < 0.45:
		return false
	_accept(item)
	return true


func _accept(item: Node3D) -> void:
	var lit_item := false
	var fuel := 0.2
	if item is Burnable:
		var b := item as Burnable
		lit_item = b.lit
		fuel = b.bin_fuel * (1.0 - b.burn)
		b.in_bin = self
		b.set_held(true)
	elif item is Flare:
		var f := item as Flare
		lit_item = f.lit
		fuel = 0.1
		f.held = true
		f.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		f.freeze = true
	# l'objet devient un simple décor dans la poubelle : plus de collisions
	(item as CollisionObject3D).collision_layer = 0
	(item as CollisionObject3D).collision_mask = 0
	item.reparent.call_deferred(_model, true)
	_settle.call_deferred(item)
	_items.append(item)
	contents = minf(contents + fuel, 3.0)
	AudioLib.play_at(self, "cardboard_land", top_center(), -10.0, 5.0, randf_range(0.8, 1.0))
	if burning:
		_boost = maxf(_boost, 0.35 + fuel * 0.4)
		_fx.flare_up_burst(-2.0 + fuel * 4.0)
		get_tree().call_group("crowd", "on_event", "fire_flare", {"bin": self, "pos": top_center()})
		if item is Burnable and not (item as Burnable).lit:
			(item as Burnable).ignite.call_deferred()
	elif lit_item:
		ignite()


func _settle(item: Node3D) -> void:
	if not is_instance_valid(item) or item.get_parent() != _model:
		return
	var l := item.position
	var h := _half(0.75)
	var dest := Vector3(clampf(l.x, -h.x + 0.12, h.x - 0.12), 0.74 + randf() * 0.06, clampf(l.z, -h.y + 0.12, h.y - 0.12))
	var tw := item.create_tween()
	tw.tween_property(item, "position", dest, 0.25).set_ease(Tween.EASE_IN)
	if item is Burnable and (item as Burnable).kind == "plank":
		# trop longue pour tenir couchée : elle s'appuie en biais et dépasse du rebord
		var lean := Vector3(randf_range(-0.25, 0.25), randf() * TAU, (1.0 if randf() < 0.5 else -1.0) * randf_range(0.95, 1.2))
		tw.parallel().tween_property(item, "rotation", lean, 0.25)
		tw.parallel().tween_property(item, "position:y", 0.92, 0.25)


func ignite() -> void:
	if burning or contents < 0.05 or tipped:
		return
	burning = true
	_smother_t = 0.0
	heat = maxf(heat, 0.12)
	_boost = 0.5
	_fx.start()
	_fx.ignite_burst()
	for it in _items:
		if is_instance_valid(it) and it is Burnable:
			(it as Burnable).ignite()
	get_tree().call_group("crowd", "on_event", "fire_start", {"bin": self, "pos": top_center()})


func extinguish() -> void:
	if not burning:
		return
	burning = false
	_out_smoke = 6.0
	_fx.stop()
	get_tree().call_group("crowd", "on_event", "fire_out", {"bin": self, "pos": top_center()})


## Dépôt à la main (joueur ou PNJ) : l'objet est posé près du bord intérieur ; la poubelle doit être ouverte.
func deposit(item: Node3D, from_pos: Vector3) -> bool:
	if tipped or not is_open():
		return false
	var c := top_center()
	var d := Vector3(from_pos.x - c.x, 0, from_pos.z - c.z)
	d = d.normalized() * 0.14 if d.length() > 0.01 else Vector3.ZERO
	item.global_position = c + d + Vector3.UP * 0.03
	_accept(item)
	return true


## Renversée d'un coup de pied : bascule dans le sens `dir`, couvercle grand ouvert, contenu répandu.
func tip_over(dir: Vector3, power := 1.0) -> void:
	if tipped or _righting:
		return
	tipped = true
	axis_lock_angular_x = false
	axis_lock_angular_z = false
	linear_damp = 0.5
	angular_damp = 0.8
	center_of_mass = Vector3(0, 0.46, 0)
	lid_open = true
	_lid_vel = 0.0
	var d := Vector3(dir.x, 0, dir.z).normalized()
	var axis := Vector3.UP.cross(d)
	_tip_axis = axis
	_tip_t = 0.12 * clampf(power, 0.5, 1.2)       # le pied continue de pousser un instant
	apply_torque_impulse(axis * 12.0 * power)
	apply_central_impulse(d * mass * 1.0 * power + Vector3.UP * mass * 0.25)
	sleeping = false
	AudioLib.play_at(self, "bin_tip", global_position + Vector3.UP * 0.6, 0.0, 8.0)
	if burning:
		_boost = 0.8
	get_tree().create_timer(0.3).timeout.connect(_spill.bind(d))
	get_tree().call_group("crowd", "on_event", "vandal", {"pos": global_position, "kind": "bin", "amount": 0.8})


func _spill(d: Vector3) -> void:
	if not is_inside_tree():
		return
	var mouth := _model.to_global(Vector3(0, Y1 - 0.12, 0))
	var scene := get_tree().current_scene
	var was_burning := burning
	if burning:
		extinguish()
	# objets déjà dans la poubelle
	for it in _items.duplicate():
		if not is_instance_valid(it):
			continue
		if it is Burnable:
			var b := it as Burnable
			var lit_b := b.lit
			b.in_bin = null
			b.lit = false
			b.reparent(scene, true)
			b.set_held(false)
			b.global_position = mouth + Vector3(randf_range(-0.1, 0.1), randf_range(-0.05, 0.1), randf_range(-0.1, 0.1))
			b.linear_velocity = d * randf_range(0.8, 2.2) + Vector3(randf_range(-0.5, 0.5), randf_range(0.3, 1.2), randf_range(-0.5, 0.5))
			b.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
			if lit_b or was_burning:
				b.ignite()
		else:
			it.queue_free()
	_items.clear()
	# déchets de la poubelle qui se répandent
	var n := clampi(int(ceil(contents * 3.0)), 2, 6)
	for i in n:
		var b2 := Burnable.make("paper")
		scene.add_child(b2)
		b2.global_position = mouth + Vector3(randf_range(-0.12, 0.12), randf_range(0.0, 0.1), randf_range(-0.12, 0.12))
		b2.linear_velocity = d * randf_range(0.6, 2.4) + Vector3(randf_range(-0.7, 0.7), randf_range(0.2, 1.4), randf_range(-0.7, 0.7))
		b2.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		if was_burning and randf() < 0.7:
			b2.ignite()
	contents = 0.05
	_trash.visible = false
	_floor_shape.set_deferred("disabled", true)


## Se relève d'un mouvement (joueur ou PNJ) : la poubelle est redressée devant celui qui la remet debout.
func begin_right(yaw: float, duration := 1.0) -> void:
	if not tipped or _righting:
		return
	_righting = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	var q0 := global_transform.basis.get_rotation_quaternion()
	var p0 := global_position
	var q1 := Quaternion(Vector3.UP, yaw)
	var tw := create_tween()
	tw.tween_method(func(u: float):
		var e := u * u * (3.0 - 2.0 * u)
		global_transform = Transform3D(Basis(q0.slerp(q1, e)), p0.lerp(Vector3(p0.x, 0.012, p0.z), e) + Vector3(0, sin(PI * e) * 0.12, 0)), 0.0, 1.0, duration)
	tw.tween_callback(func():
		tipped = false
		_righting = false
		axis_lock_angular_x = true
		axis_lock_angular_z = true
		linear_damp = 2.2
		angular_damp = 5.0
		center_of_mass = Vector3(0, 0.3, 0)
		freeze = false
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		_floor_shape.set_deferred("disabled", false)
		AudioLib.play_at(self, "bin_hit", global_position + Vector3.UP * 0.4, -4.0, 6.0, 0.9))


func kick(point: Vector3, dir: Vector3, power := 1.0) -> bool:
	if grabbed_by != null or _righting:
		return false
	var l := to_local(point)
	if tipped:
		if absf(l.x) > 1.0 or absf(l.z) > 1.0 or l.y > 1.3:
			return false
		var d0 := Vector3(dir.x, 0, dir.z).normalized()
		apply_central_impulse(d0 * mass * 1.6 * power)
		_hit_sound(1.0)
		return true
	if absf(l.x) > BX1 + 0.45 or absf(l.z) > BZ1 + 0.45 or l.y > 1.3:
		return false
	var d := Vector3(dir.x, 0, dir.z).normalized()
	_hit_sound(1.0)
	if power >= 0.5:
		tip_over(d, power)
	else:
		apply_central_impulse(d * mass * 2.6)
		apply_torque_impulse(Vector3.UP * randf_range(-1.0, 1.0) * mass * 0.25)
		if burning:
			_boost = maxf(_boost, 0.25)
	return true


func push(dir: Vector3, speed: float) -> void:
	if grabbed_by != null:
		return
	var d := Vector3(dir.x, 0, dir.z)
	if d.length() < 0.01:
		return
	var v := linear_velocity
	var target := d.normalized() * speed * 0.85
	var hv := Vector3(v.x, 0, v.z).lerp(target, 0.35)
	linear_velocity = Vector3(hv.x, v.y, hv.z)
	sleeping = false


func _hit_sound(k: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_hit < 0.15:
		return
	_last_hit = now
	AudioLib.play_at(self, "bin_hit", global_position + Vector3.UP * 0.6, -6.0 + 6.0 * k, 6.0, randf_range(0.9, 1.1))


## Poignée (monde) : x = décalage latéral sur la barre
func handle_world(x := 0.0) -> Vector3:
	return _model.to_global(Vector3(x, 0.965, BZ1 + 0.075))


func grab(by: Node3D) -> void:
	if tipped:
		return
	grabbed_by = by
	if by is PhysicsBody3D:
		add_collision_exception_with(by)
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	AudioLib.play_at(self, "bin_hit", global_position + Vector3.UP * 0.5, -12.0, 5.0, 0.8)


func release() -> void:
	if grabbed_by == null:
		return
	if grabbed_by is PhysicsBody3D and is_instance_valid(grabbed_by):
		remove_collision_exception_with(grabbed_by)
	grabbed_by = null
	freeze = false
	sleeping = false
	linear_velocity = Vector3.ZERO


## Pendant qu'on la tire : position/orientation voulues (le corps reste vertical, le modèle bascule)
func drag_to(target: Vector3, yaw: float, delta: float) -> void:
	var xf := global_transform
	var want := Transform3D(Basis(Vector3.UP, yaw), target)
	var motion := want.origin - xf.origin
	motion.y = 0.0
	# évite de traverser l'abribus, le lampadaire, l'autre poubelle
	var lifted := Transform3D(want.basis, xf.origin + Vector3.UP * 0.1)
	var col := KinematicCollision3D.new()
	if test_move(lifted, motion, col, 0.01):
		var n := col.get_normal()
		n.y = 0.0
		if n.length() > 0.01:
			n = n.normalized()
			motion -= n * minf(motion.dot(n), 0.0)
		if test_move(lifted, motion, null, 0.01):
			motion = Vector3.ZERO
	var p := xf.origin + motion
	# hauteur du sol (trottoir de l'abribus)
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, p + Vector3.DOWN * 0.6, 1)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	p.y = (r["position"] as Vector3).y + 0.012 if r else 0.012
	global_transform = Transform3D(Basis(Vector3.UP, lerp_angle(rotation.y, yaw, minf(1.0, delta * 8.0))), p)


func _physics_process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if _tip_t > 0.0:
		_tip_t -= delta
		apply_torque(_tip_axis * 70.0)
	# --- couvercle : ressort amorti + petit rebond en butée
	var target := OPEN_ANGLE if lid_open else 0.0
	var acc := (target - _lid_angle) * 60.0 - _lid_vel * 9.0
	if not lid_open and _lid_angle > 0.3:
		acc -= 8.0   # le couvercle retombe sous son poids
	_lid_vel += acc * delta
	_lid_angle += _lid_vel * delta
	if _lid_angle < 0.0:
		_lid_angle = 0.0
		if _lid_vel < -1.5:
			_hit_sound(clampf(-_lid_vel / 8.0, 0.2, 0.8))
		_lid_vel = -_lid_vel * 0.25
	if _lid_angle > OPEN_ANGLE:
		_lid_angle = OPEN_ANGLE
		_lid_vel = -_lid_vel * 0.3
	_lid_pivot.rotation.x = _lid_angle
	_lid_shape.disabled = _lid_angle > 0.25

	# --- bascule sur les roues quand on la tire
	var tilt_t := 0.42 if grabbed_by != null else 0.0
	_tilt = lerpf(_tilt, tilt_t, minf(1.0, delta * 6.0))
	_pivot.rotation.x = _tilt

	# --- roulement
	var hs := Vector3(linear_velocity.x, 0, linear_velocity.z).length()
	if grabbed_by != null and grabbed_by is CharacterBody3D:
		var gv := (grabbed_by as CharacterBody3D).velocity
		hs = Vector3(gv.x, 0, gv.z).length()
	if hs > 0.15:
		if not _snd_roll.playing:
			_snd_roll.play(randf() * 1.5)
		_snd_roll.volume_db = linear_to_db(clampf(hs / 2.5, 0.02, 1.0)) - 8.0
	elif _snd_roll.playing:
		_snd_roll.stop()

	# --- feu
	var fuel_total := contents
	if burning:
		var oxygen := 1.0 if is_open() else 0.1
		var want := clampf(0.3 + 0.55 * sqrt(fuel_total), 0.0, 1.2) * oxygen
		var rate := 0.18 if want > heat else (0.55 if oxygen < 0.5 else 0.25)
		heat = move_toward(heat, want, rate * delta)
		contents = maxf(contents - heat * delta / 75.0, 0.0)
		_boost = move_toward(_boost, 0.0, delta * 0.35)
		char_amt = minf(char_amt + heat * delta / 140.0, 1.0)
		if oxygen < 0.5 and heat < 0.05:
			_smother_t += delta
			if _smother_t > 1.5:
				extinguish()
		else:
			_smother_t = 0.0
		if contents <= 0.01 and heat < 0.04:
			extinguish()
	else:
		heat = move_toward(heat, 0.0, delta * 0.4)
		_boost = 0.0
	var h := clampf(heat + _boost, 0.0, 1.6)
	var vis := 1.0 if _lid_angle > 0.5 and not tipped else 0.0   # couvercle fermé : les flammes restent dessous
	var choke := burning and not is_open() and heat > 0.01
	_out_smoke = maxf(_out_smoke - delta, 0.0)
	_fx.update(h, vis, burning, maxf(heat * 2.0 if choke else 0.0, _out_smoke / 6.0))
	# déchets qui se consument (le niveau baisse), plastique noirci
	_trash.position.y = -0.18 * (1.0 - clampf(contents, 0.0, 1.0)) * clampf(char_amt * 3.0, 0.0, 1.0)
	_floor_shape.position.y = 0.66 + _trash.position.y
	if burning and _frame_i % 10 == 0:
		for it in _items:
			if is_instance_valid(it) and it is Burnable:
				(it as Burnable).set_burn(clampf(char_amt * 2.2, 0.0, 1.0))
	var c := body_color.lerp(Color(0.035, 0.03, 0.03), char_amt * 0.85)
	_mat.albedo_color = c
	_mat.roughness = 0.62 + 0.3 * char_amt
	_lid_mat.albedo_color = lid_color.lerp(Color(0.04, 0.035, 0.03), char_amt * 0.7)
	if _frame_i % 30 == 0:
		_items.assign(_items.filter(func(x): return is_instance_valid(x)))
	_frame_i += 1
