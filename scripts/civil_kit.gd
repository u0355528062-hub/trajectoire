class_name CivilKit
extends RefCounted
## Garde-robe et accessoires des civils (passants, habitants) : tenues de ville, manteaux longs, écharpes,
## chapeaux, sacs à main, sacs de courses, baguette, canne, poussette, chien en laisse.
## Maillages et matériaux partagés (créés une fois) ; les accessoires portés sont collés aux os du Human,
## les objets tenus en main (sacs, canne) sont placés à chaque image par leur porteur.

static var _meshes := {}
static var _mats := {}

const COATS := [Color(0.62, 0.52, 0.38), Color(0.1, 0.12, 0.2), Color(0.2, 0.2, 0.22), Color(0.45, 0.31, 0.2),
	Color(0.05, 0.05, 0.06), Color(0.32, 0.34, 0.33), Color(0.36, 0.12, 0.14), Color(0.16, 0.24, 0.2),
	Color(0.55, 0.5, 0.44), Color(0.68, 0.63, 0.55)]
const BRIGHT := [Color(0.75, 0.2, 0.15), Color(0.85, 0.65, 0.2), Color(0.2, 0.35, 0.6), Color(0.85, 0.82, 0.75),
	Color(0.5, 0.15, 0.35), Color(0.25, 0.5, 0.4), Color(0.9, 0.45, 0.35)]
const HAIR := [Color(0.05, 0.035, 0.025), Color(0.12, 0.08, 0.05), Color(0.3, 0.2, 0.1), Color(0.02, 0.02, 0.02),
	Color(0.55, 0.4, 0.22), Color(0.42, 0.18, 0.08)]
const GREY_HAIR := [Color(0.55, 0.53, 0.5), Color(0.72, 0.7, 0.67), Color(0.85, 0.84, 0.82), Color(0.38, 0.36, 0.34)]


static func _mesh(key: String, maker: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = maker.call()
	return _meshes[key]


static func mat(key: String, col := Color.WHITE) -> Material:
	var k := key + str(col)
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	match key:
		"wool":
			# drap de laine mat : manteau long, écharpe (le pan du manteau est vu des deux côtés)
			m.roughness = 0.97
			m.normal_enabled = true
			m.normal_texture = load(Human.DIR + "knit_n.png")
			m.normal_scale = 0.18
			m.uv1_scale = Vector3(7, 7, 1)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"leather":
			m.roughness = 0.42
			m.metallic_specular = 0.6
		"paper":
			m.roughness = 0.92
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"plastic":
			m.roughness = 0.35
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"metal":
			m.roughness = 0.3
			m.metallic = 0.85
		"felt":
			m.roughness = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"fur":
			m.roughness = 0.95
			m.normal_enabled = true
			m.normal_texture = load(Human.DIR + "hair_n.png")
			m.normal_scale = 0.5
			m.uv1_scale = Vector3(3, 3, 1)
		_:
			m.roughness = 0.8
	_mats[k] = m
	return m


static func _mi(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	var mi := MeshKit.mesh_instance(mesh, m, pos, rot, parent)
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# =================================================================== tenues
## Tenue de ville pour Human + accessoires (clés supplémentaires lues par `dress`) :
## coat (manteau long), scarf, hat ("" | "fedora" | "beret"), handbag, age ("young" | "adult" | "elder").
static func outfit(rng: RandomNumberGenerator, female: bool, age: String) -> Dictionary:
	var coat_col: Color = COATS[rng.randi() % COATS.size()]
	var top := "jacket"
	var r := rng.randf()
	if age == "young":
		top = "hoodie" if r < 0.4 else ("tshirt" if r < 0.5 else "jacket")
	elif age == "adult" and r < 0.12:
		top = "hoodie"
	var o := {
		"top": top, "top_color": coat_col if top == "jacket" else BRIGHT[rng.randi() % BRIGHT.size()],
		"hood": false, "vest": false, "face": "",
		"pants_tex": rng.randf() < (0.6 if age == "young" else 0.3),
		"pants_color": [Color(0.07, 0.07, 0.08), Color(0.2, 0.2, 0.22), Color(0.3, 0.27, 0.22), Color(0.12, 0.14, 0.22), Color(0.45, 0.4, 0.32)][rng.randi() % 5],
		"shoe_color": [Color(0.06, 0.05, 0.05), Color(0.25, 0.15, 0.08), Color(0.85, 0.85, 0.83), Color(0.12, 0.12, 0.14)][rng.randi() % 4],
		"head": "", "head_color": COATS[rng.randi() % COATS.size()],
		"backpack": age == "young" and rng.randf() < 0.45,
		"bag_color": [Color(0.04, 0.04, 0.05), Color(0.1, 0.12, 0.2), Color(0.3, 0.08, 0.1), Color(0.25, 0.18, 0.12)][rng.randi() % 4],
		"hair_color": GREY_HAIR[rng.randi() % GREY_HAIR.size()] if age == "elder" else HAIR[rng.randi() % HAIR.size()],
		"age": age,
		"coat": top == "jacket" and rng.randf() < (0.75 if age == "elder" else 0.45),
		"scarf": rng.randf() < (0.55 if age != "young" else 0.25),
		"scarf_color": BRIGHT[rng.randi() % BRIGHT.size()] if rng.randf() < 0.6 else COATS[rng.randi() % COATS.size()],
		"hat": "",
		"handbag": female and age != "young" and rng.randf() < 0.65,
		"handbag_color": [Color(0.08, 0.05, 0.04), Color(0.38, 0.2, 0.1), Color(0.55, 0.12, 0.1), Color(0.75, 0.68, 0.55)][rng.randi() % 4],
	}
	if top == "jacket" and not o["coat"] and rng.randf() < 0.4:
		o["top_color"] = BRIGHT[rng.randi() % BRIGHT.size()]       # doudoune colorée
	if age == "elder":
		o["hat"] = ("beret" if female else "fedora") if rng.randf() < 0.55 else ""
		o["pants_tex"] = false
	elif age == "young" and rng.randf() < 0.25:
		o["head"] = "beanie" if rng.randf() < 0.6 else "cap"
	elif age == "adult" and rng.randf() < 0.12:
		o["hat"] = "beret" if female else "fedora"
	return o


## Habille un Human déjà prêt : drap de laine sur la veste, pan de manteau, écharpe, chapeau, sac à main
static func dress(h: Human, o: Dictionary) -> Dictionary:
	var out := {}
	var s := h.hscale()
	var top_col: Color = o.get("top_color", Color.GRAY)
	if o.get("coat", false):
		var jacket: Variant = h._mesh_by_name.get("Jacket")
		if jacket is MeshInstance3D:
			(jacket as MeshInstance3D).material_override = mat("wool", top_col)
		var skirt := MeshKit.mesh_instance(_mesh("coat_skirt", _coat_skirt), mat("wool", top_col))
		skirt.scale = Vector3(1.0, 1.0, 0.82) * s
		h.attach("root", skirt, Vector3(0, 0.08, -0.01) * s)
		out["skirt"] = skirt
	if o.get("scarf", false):
		var sc := Node3D.new()
		var m := mat("wool", o.get("scarf_color", Color.RED))
		_mi(sc, _mesh("scarf_ring", _scarf_ring), m, Vector3.ZERO, Vector3.ZERO, false)
		_mi(sc, _mesh("scarf_tail", func() -> Mesh: return MeshKit.rbox(Vector3(0.075, 0.24, 0.022), 0.01, 2)), m, Vector3(0.035, -0.12, 0.085), Vector3(0.12, 0, 0.08), false)
		sc.scale = Vector3.ONE * s
		h.attach("neck01", sc, Vector3(0, 0.0, 0.01) * s)
		out["scarf"] = sc
	match String(o.get("hat", "")):
		"fedora":
			var hat := MeshKit.mesh_instance(_mesh("fedora", _fedora), mat("felt", [Color(0.18, 0.16, 0.14), Color(0.3, 0.25, 0.2), Color(0.12, 0.12, 0.14)][int(absf(top_col.r * 100.0)) % 3]))
			hat.scale = Vector3.ONE * s
			h.attach("head", hat, Vector3(0, 0.085, 0.012) * s, Basis(Vector3.RIGHT, -0.08))
			hat.layers = Human.HEAD_LAYER
			out["hat"] = hat
		"beret":
			var be := MeshKit.mesh_instance(_mesh("beret", _beret), mat("felt", o.get("scarf_color", Color(0.1, 0.1, 0.12)).darkened(0.3)))
			be.scale = Vector3.ONE * s
			h.attach("head", be, Vector3(0.012, 0.105, 0.0) * s, Basis(Vector3.BACK, 0.18))
			be.layers = Human.HEAD_LAYER
			out["hat"] = be
	if o.get("handbag", false):
		var bag := handbag(o.get("handbag_color", Color(0.1, 0.06, 0.04)))
		bag.scale = Vector3.ONE * s
		# en bandoulière : le sac sur la hanche gauche, la sangle jusqu'à l'épaule
		h.attach("spine03", bag, Vector3(0.2, -0.16, -0.02) * s)
		out["handbag"] = bag
	return out


# =================================================================== maillages portés
static func _coat_skirt() -> Mesh:
	# pan de manteau évasé, de la taille jusqu'au-dessus du genou (ouvert en bas)
	return MeshKit.lathe(PackedVector2Array([Vector2(0.235, -0.5), Vector2(0.215, -0.3), Vector2(0.19, -0.1), Vector2(0.172, 0.0), Vector2(0.16, 0.06)]), 16, 60.0)


static func _scarf_ring() -> Mesh:
	return MeshKit.lathe(PackedVector2Array([Vector2(0.06, -0.035), Vector2(0.085, -0.04), Vector2(0.092, 0.0), Vector2(0.082, 0.04), Vector2(0.058, 0.035)]), 14, 70.0)


static func _fedora() -> Mesh:
	return MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.006), Vector2(0.16, -0.004), Vector2(0.165, 0.004), Vector2(0.1, 0.012), Vector2(0.098, 0.09), Vector2(0.07, 0.115), Vector2(0.0, 0.105)]), 18, 50.0)


static func _beret() -> Mesh:
	return MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.09, -0.002), Vector2(0.125, 0.015), Vector2(0.12, 0.04), Vector2(0.06, 0.06), Vector2(0.0, 0.062)]), 16, 70.0)


## Sac à main en bandoulière (origine : haut du sac)
static func handbag(col: Color) -> Node3D:
	var root := Node3D.new()
	var lm := mat("leather", col)
	_mi(root, _mesh("handbag", func() -> Mesh: return MeshKit.rbox(Vector3(0.07, 0.19, 0.26), 0.025, 2)), lm, Vector3(0, -0.1, 0))
	_mi(root, _mesh("handbag_strap", func() -> Mesh: return MeshKit.tube(PackedVector3Array([Vector3(0, 0, 0.1), Vector3(-0.02, 0.22, 0.06), Vector3(-0.05, 0.47, 0.0)]), 0.008, 5)), lm, Vector3.ZERO, Vector3.ZERO, false)
	_mi(root, _mesh("handbag_clasp", func() -> Mesh: return MeshKit.rbox(Vector3(0.075, 0.03, 0.04), 0.006, 1)), mat("metal", Color(0.8, 0.68, 0.35)), Vector3(0.0, -0.03, 0.0), Vector3.ZERO, false)
	return root


# =================================================================== objets tenus (placés par le porteur)
## Sac de courses (papier kraft ou plastique, parfois une baguette) : origine = poignée, pend vers -Y
static func shopping_bag(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var kraft := rng.randf() < 0.55
	var col: Color = Color(0.62, 0.47, 0.3) if kraft else [Color(0.9, 0.9, 0.88), Color(0.15, 0.4, 0.2), Color(0.75, 0.15, 0.12)][rng.randi() % 3]
	var m := mat("paper" if kraft else "plastic", col)
	_mi(root, _mesh("sbag_body", func() -> Mesh: return MeshKit.rbox(Vector3(0.28, 0.3, 0.13), 0.012, 1)), m, Vector3(0, -0.23, 0))
	_mi(root, _mesh("sbag_handle", func() -> Mesh: return MeshKit.tube(PackedVector3Array([Vector3(-0.05, -0.08, 0), Vector3(-0.03, 0.0, 0), Vector3(0.03, 0.0, 0), Vector3(0.05, -0.08, 0)]), 0.006, 4)), m, Vector3.ZERO, Vector3.ZERO, false)
	# poireaux ou baguette qui dépassent
	if rng.randf() < 0.55:
		_mi(root, _mesh("baguette", func() -> Mesh: return MeshKit.tube(PackedVector3Array([Vector3(0, -0.3, 0), Vector3(0, 0.0, 0), Vector3(0, 0.22, 0)]), 0.028, 8)), mat("x", Color(0.78, 0.56, 0.3)), Vector3(0.07, 0.0, 0.02), Vector3(0, 0, 0.18), false)
	elif rng.randf() < 0.5:
		_mi(root, _mesh("leeks", func() -> Mesh: return MeshKit.tube(PackedVector3Array([Vector3(0, -0.25, 0), Vector3(0, 0.12, 0)]), 0.02, 6)), mat("x", Color(0.35, 0.55, 0.25)), Vector3(-0.07, 0.0, 0.0), Vector3(0, 0, -0.12), false)
	return root


## Canne (origine en haut, axe -Y jusqu'au sol)
static func cane() -> Node3D:
	var root := Node3D.new()
	_mi(root, _mesh("cane", func() -> Mesh: return MeshKit.tube(PackedVector3Array([Vector3(-0.07, 0.0, 0), Vector3(-0.02, 0.03, 0), Vector3(0.0, 0.0, 0), Vector3(0.0, -1.0, 0)]), 0.011, 6)), mat("leather", Color(0.15, 0.09, 0.05)), Vector3.ZERO, Vector3.ZERO, false)
	return root


## Poussette (origine au sol, au centre ; poignée côté +Z à 1 m de haut, le pousseur derrière)
static func stroller(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var fab := mat("x", [Color(0.1, 0.12, 0.2), Color(0.25, 0.25, 0.27), Color(0.55, 0.48, 0.38), Color(0.35, 0.1, 0.12)][rng.randi() % 4])
	var frame := mat("metal", Color(0.12, 0.12, 0.13))
	_mi(root, _mesh("str_frame", func() -> Mesh:
		var parts := []
		for sx in [-0.21, 0.21]:
			parts.append([MeshKit.tube(PackedVector3Array([Vector3(sx, 1.0, 0.42), Vector3(sx, 0.55, 0.12), Vector3(sx, 0.14, -0.3)]), 0.012, 6), Transform3D()])
			parts.append([MeshKit.tube(PackedVector3Array([Vector3(sx, 0.55, 0.12), Vector3(sx, 0.14, 0.28)]), 0.011, 6), Transform3D()])
		parts.append([MeshKit.tube(PackedVector3Array([Vector3(-0.23, 1.0, 0.42), Vector3(0.23, 1.0, 0.42)]), 0.016, 8), Transform3D()])
		return MeshKit.merge(parts)), frame)
	_mi(root, _mesh("str_body", func() -> Mesh: return MeshKit.rbox(Vector3(0.38, 0.26, 0.62), 0.08, 2)), fab, Vector3(0, 0.55, -0.02))
	_mi(root, _mesh("str_hood", func() -> Mesh: return MeshKit.lathe(PackedVector2Array([Vector2(0.2, 0.0), Vector2(0.17, 0.12), Vector2(0.0, 0.16)]), 12, 60.0)), fab, Vector3(0, 0.66, 0.1), Vector3(-0.5, 0, 0))
	var wh := _mesh("str_wheel", func() -> Mesh:
		var c := CylinderMesh.new()
		c.top_radius = 0.1
		c.bottom_radius = 0.1
		c.height = 0.04
		c.radial_segments = 12
		return c)
	for p in [Vector3(-0.22, 0.1, -0.3), Vector3(0.22, 0.1, -0.3), Vector3(-0.22, 0.1, 0.28), Vector3(0.22, 0.1, 0.28)]:
		_mi(root, wh, mat("x", Color(0.04, 0.04, 0.045)), p, Vector3(0, 0, PI / 2), false)
	return root


## Chien (origine au sol entre les pattes, museau vers -Z). Nœuds animés : "Legs/0..3", "Head", "Tail".
static func dog(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var k := rng.randf_range(0.7, 1.15)         # taille (du teckel au labrador)
	var col: Color = [Color(0.08, 0.07, 0.06), Color(0.55, 0.4, 0.22), Color(0.8, 0.7, 0.5), Color(0.35, 0.25, 0.18), Color(0.9, 0.88, 0.84)][rng.randi() % 5]
	var fm := mat("fur", col)
	var body := Node3D.new()
	body.name = "Body"
	body.scale = Vector3.ONE * k
	root.add_child(body)
	_mi(body, _mesh("dog_torso", func() -> Mesh:
		var c := CapsuleMesh.new()
		c.radius = 0.1
		c.height = 0.46
		c.radial_segments = 10
		c.rings = 4
		return c), fm, Vector3(0, 0.36, 0), Vector3(PI / 2, 0, 0))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.46, -0.24)
	body.add_child(head)
	_mi(head, _mesh("dog_head", func() -> Mesh:
		var s := SphereMesh.new()
		s.radius = 0.075
		s.height = 0.14
		s.radial_segments = 10
		s.rings = 6
		return s), fm, Vector3(0, 0.02, -0.03))
	_mi(head, _mesh("dog_snout", func() -> Mesh: return MeshKit.rbox(Vector3(0.06, 0.055, 0.1), 0.02, 2)), fm, Vector3(0, -0.005, -0.11), Vector3.ZERO, false)
	_mi(head, _mesh("dog_nose", func() -> Mesh: return MeshKit.rbox(Vector3(0.03, 0.022, 0.02), 0.008, 1)), mat("x", Color(0.03, 0.03, 0.03)), Vector3(0, 0.012, -0.16), Vector3.ZERO, false)
	for sx in [-1.0, 1.0]:
		_mi(head, _mesh("dog_ear", func() -> Mesh: return MeshKit.rbox(Vector3(0.035, 0.07, 0.015), 0.008, 1)), fm, Vector3(sx * 0.05, 0.05, -0.0), Vector3(0, 0, sx * 0.5), false)
	var legs := Node3D.new()
	legs.name = "Legs"
	body.add_child(legs)
	var lm := _mesh("dog_leg", func() -> Mesh: return MeshKit.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, -0.29, 0)]), 0.022, 6))
	var li := 0
	for p in [Vector3(-0.06, 0.3, -0.17), Vector3(0.06, 0.3, -0.17), Vector3(-0.06, 0.3, 0.17), Vector3(0.06, 0.3, 0.17)]:
		var piv := Node3D.new()
		piv.name = str(li)
		piv.position = p
		legs.add_child(piv)
		_mi(piv, lm, fm, Vector3.ZERO, Vector3.ZERO, false)
		li += 1
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0.42, 0.25)
	body.add_child(tail)
	_mi(tail, _mesh("dog_tail", func() -> Mesh: return MeshKit.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0.06, 0.08), Vector3(0, 0.13, 0.12)]), 0.014, 5)), fm, Vector3.ZERO, Vector3.ZERO, false)
	root.set_meta("k", k)
	return root


## Laisse : cylindre unitaire (axe +Y, longueur 1) étiré entre la main et le collier
static func leash() -> MeshInstance3D:
	var mi := MeshKit.mesh_instance(_mesh("leash", func() -> Mesh:
		var c := CylinderMesh.new()
		c.top_radius = 0.005
		c.bottom_radius = 0.005
		c.height = 1.0
		c.radial_segments = 4
		c.rings = 1
		return c), mat("x", Color(0.6, 0.12, 0.1)))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Place un segment unitaire (axe +Y centré) entre deux points
static func span(n: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.01:
		n.visible = false
		return
	n.visible = true
	var bs := Props.basis_up(d / l, Vector3.FORWARD)
	bs.y *= l
	n.global_transform = Transform3D(bs, (a + b) * 0.5)
