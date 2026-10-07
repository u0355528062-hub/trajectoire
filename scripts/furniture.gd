class_name Furniture
extends RefCounted
## Mobilier de rue vandalisable posé sur la baseplate : barrières métalliques, cônes, panneaux, boîtes à
## journaux, lampadaires à globe de verre, pots de fleurs, panneau publicitaire. `populate` place tout.

static var _mats := {}


static func mat(key: String, color: Color, rough := 0.6, metal := 0.0, emissive := 0.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		if emissive > 0.0:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = emissive
		_mats[key] = m
	return _mats[key]


static func add(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return add(parent, b, m, pos, rot)


static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, segs := 16) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = segs
	return add(parent, c, m, pos, rot)


static func col_box(parent: Node3D, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	cs.rotation = rot
	parent.add_child(cs)
	return cs


static func col_cyl(parent: Node3D, r: float, h: float, pos: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	cs.shape = c
	cs.position = pos
	parent.add_child(cs)
	return cs


## Pose tout le mobilier. `world` : racine de la scène ; `crowd` : pour que les PNJ contournent ce qui est debout.
static func populate(world: Node3D, crowd: Crowd) -> void:
	# --- barrières : barrage en travers de la chaussée devant le cordon, et quelques-unes près de l'abribus
	for z in [-10.3, -8.3, -6.3, -4.3]:
		_barrier(world, crowd, Vector3(46.5, 0.0, z), PI * 0.5 + 0.03)
	for pos in [Vector3(9.5, 0, -3.1), Vector3(11.5, 0, -3.1), Vector3(-9.0, 0, -4.2)]:
		_barrier(world, crowd, pos, 0.05)
	# deux barrières déjà à terre (un précédent cortège est passé par là)
	var fallen := _barrier(world, crowd, Vector3(-14.0, 0.06, -6.2), 0.6)
	fallen.rotation = Vector3(PI * 0.5, 0.6, 0.0)
	fallen = _barrier(world, crowd, Vector3(31.0, 0.06, -9.0), 2.4)
	fallen.rotation = Vector3(-PI * 0.5, 2.4, 0.0)
	# --- cônes de chantier
	var cone_pts: Array = []
	for i in 6:
		cone_pts.append(Vector3(16.0 + i * 2.6, 0.0, -4.5 - (i % 2) * 0.12))
	for i in 4:
		cone_pts.append(Vector3(-22.0 + i * 2.2, 0.0, -10.4))
	cone_pts.append_array([Vector3(3.8, 0, -3.3), Vector3(-5.2, 0, -2.6), Vector3(26.0, 0, -9.9)])
	for p in cone_pts:
		var c := Cone.new()
		c.position = p
		world.add_child(c)
	# --- panneaux de signalisation
	_prop(world, crowd, Signpost.new(), Vector3(22.5, 0, -3.3), 0.15, {"kind": "no_park"})
	_prop(world, crowd, Signpost.new(), Vector3(-17.0, 0, -3.3), -0.1, {"kind": "no_entry"})
	_prop(world, crowd, Signpost.new(), Vector3(36.0, 0, -11.5), PI + 0.1, {"kind": "stop"})
	# --- boîtes à journaux
	_prop(world, crowd, NewsBox.new(), Vector3(-8.6, 0, -14.6), 0.08, {})
	_prop(world, crowd, NewsBox.new(), Vector3(8.8, 0, -14.4), -0.12, {"stock": 5})
	# --- corbeilles de rue
	for bp in [Vector3(2.55, 0, -12.45), Vector3(13.0, 0, -3.1), Vector3(-18.0, 0, -3.1)]:
		_prop(world, crowd, PublicBin.new(), bp, randf() * TAU, {})
	# --- pots de fleurs
	for pp in [Vector3(-7.4, 0, -11.9), Vector3(7.6, 0, -11.9), Vector3(-13.0, 0, -12.3), Vector3(13.5, 0, -12.1), Vector3(1.3, 0, -3.0)]:
		_prop(world, crowd, Planter.new(), pp, randf() * TAU, {})
	# --- lampadaires à globe de verre
	for lx in [-20.0, 15.0, 31.0]:
		var lamp := LampPost.new()
		lamp.crowd = crowd
		lamp.position = Vector3(lx, 0, -3.2)
		world.add_child(lamp)
	# --- panneau publicitaire vitré
	var ad := AdPanel.new()
	ad.crowd = crowd
	ad.position = Vector3(-12.2, 0, -12.8)
	ad.rotation.y = 0.05
	world.add_child(ad)


static func _barrier(world: Node3D, crowd: Crowd, pos: Vector3, yaw: float) -> Barrier:
	var b := Barrier.new()
	b.crowd = crowd
	b.position = pos
	b.rotation.y = yaw
	world.add_child(b)
	return b


static func _prop(world: Node3D, crowd: Crowd, p: StreetProp, pos: Vector3, yaw: float, opts: Dictionary) -> StreetProp:
	p.crowd = crowd
	for k in opts:
		p.set(k, opts[k])
	p.position = pos
	p.rotation.y = yaw
	world.add_child(p)
	return p
