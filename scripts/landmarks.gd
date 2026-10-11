class_name Landmarks
extends RefCounted
## Mobilier parisien emblématique, construit en géométrie fusionnée par matériau : édicule de métro Guimard
## (rambarde de fonte, lampadaires-tiges aux globes orangés, enseigne METROPOLITAIN, escalier qui s'enfonce,
## grille fermée), colonne Morris, kiosque à journaux, fontaine Wallace, bancs, arceaux à vélos, jardinières.
## Chaque élément est un StaticBody3D (collision pour le joueur) déclaré comme obstacle à la foule.

const GUIMARD_GREEN := Color(0.17, 0.29, 0.22)
const DARK_GREEN := Color(0.07, 0.19, 0.13)
static var _m := {}


static func m(key: String) -> Material:
	if _m.is_empty():
		_m["guimard"] = MeshKit.std_mat(GUIMARD_GREEN, 0.42, 0.35, 0.6)
		_m["vert"] = MeshKit.std_mat(DARK_GREEN, 0.45, 0.3, 0.6)
		_m["vert_mat"] = MeshKit.std_mat(DARK_GREEN.darkened(0.15), 0.7, 0.1)
		_m["pierre"] = Streetscape.tmat("pierre_q", "bordure_a.png", "bordure_n.png", Vector3(2, 2, 2), 0.75, Color(1, 1, 1), true)
		_m["carrelage"] = Streetscape.tmat("carrelage", "carrelage_a.png", "carrelage_n.png", Vector3(1.67, 1.67, 1.67), 0.18, Color(1, 1, 1), true)
		_m["marche"] = Streetscape.tmat("marche", "bordure_a.png", "bordure_n.png", Vector3(1.5, 1.5, 1.5), 0.6, Color(0.82, 0.8, 0.78), true)
		var orange := StandardMaterial3D.new()
		orange.albedo_color = Color(1.0, 0.45, 0.12)
		orange.emission_enabled = true
		orange.emission = Color(1.0, 0.42, 0.1)
		orange.emission_energy_multiplier = 2.6
		orange.roughness = 0.25
		_m["globe"] = orange
		var sign := StandardMaterial3D.new()
		sign.albedo_texture = Streetscape.tex("metro_enseigne.png")
		sign.roughness = 0.35
		sign.metallic_specular = 0.7
		_m["enseigne"] = sign
		var rail := StandardMaterial3D.new()
		rail.albedo_texture = Streetscape.tex("guimard_a.png")
		rail.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		rail.alpha_scissor_threshold = 0.5
		rail.cull_mode = BaseMaterial3D.CULL_DISABLED
		rail.metallic = 0.35
		rail.roughness = 0.45
		_m["rambarde"] = rail
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(1.0, 0.93, 0.8)
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.9, 0.72)
		glow.emission_energy_multiplier = 1.6
		_m["neon"] = glow
		_m["noir"] = MeshKit.std_mat(Color(0.02, 0.02, 0.025), 0.9)
		_m["morris"] = Streetscape.tmat("morris", "morris_a.png", "", Vector3.ONE, 0.6)
		var k := Streetscape.tmat("kiosque", "kiosque_a.png", "", Vector3.ONE, 0.5)
		_m["kiosque"] = k
		_m["eau"] = _water()
		_m["bois"] = MeshKit.std_mat(Color(0.42, 0.27, 0.15), 0.62)
		_m["bois_vert"] = MeshKit.std_mat(Color(0.09, 0.24, 0.15), 0.5, 0.0)
		_m["fonte"] = MeshKit.std_mat(Color(0.06, 0.12, 0.09), 0.4, 0.5)
		_m["galva"] = MeshKit.std_mat(Color(0.6, 0.62, 0.64), 0.38, 0.8)
		_m["beton"] = Streetscape.tmat("beton_q", "trottoir_a.png", "trottoir_n.png", Vector3(1.2, 1.2, 1.2), 0.85, Color(1.25, 1.22, 1.15), true)
		_m["terre"] = MeshKit.std_mat(Color(0.14, 0.1, 0.07), 0.95)
		_m["haie"] = Streetscape.tmat("haie", "haie_a.png", "haie_n.png", Vector3(1.6, 1.6, 1.6), 0.8, Color(1, 1, 1), true)
		_m["fleurs"] = Streetscape.tmat("fleurs", "fleurs_a.png", "fleurs_n.png", Vector3(1.5, 1.5, 1.5), 0.8, Color(1, 1, 1), true)
	return _m[key]


static func _water() -> StandardMaterial3D:
	var w := StandardMaterial3D.new()
	w.albedo_color = Color(0.8, 0.9, 1.0, 0.35)
	w.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	w.roughness = 0.02
	w.metallic_specular = 1.0
	w.emission_enabled = true
	w.emission = Color(0.3, 0.35, 0.4)
	w.emission_energy_multiplier = 0.3
	return w


static func _body(name: String, pos: Vector3, yaw := 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = name
	b.position = pos
	b.rotation.y = yaw
	b.collision_layer = 1
	return b


static func _col_box(body: Node3D, size: Vector3, c: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = c
	body.add_child(cs)


static func _col_cyl(body: Node3D, r: float, h: float, c: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = r
	cy.height = h
	cs.shape = cy
	cs.position = c
	body.add_child(cs)


static func _tube(b: MeshBatch, key: String, mat: Material, pts: PackedVector3Array, r: float, sides := 8) -> void:
	b.add(key, mat, MeshKit.tube(pts, r, sides, true), Transform3D.IDENTITY)


static func _curve(a: Vector3, c: Vector3, e: Vector3, n := 10) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in n + 1:
		var t := float(i) / n
		out.append(a.lerp(c, t).lerp(c.lerp(e, t), t))
	return out


# ================================================================== métro Guimard
const HOLE_HX := 0.85         # demi-largeur de la trémie
const HOLE_Z0 := -2.3         # bord sud (entrée), relatif à METRO.z
const HOLE_Z1 := 2.5          # bord nord
const STEP_H := 0.17
const STEP_D := 0.3


## Rectangle (x, z) de la trémie, en coordonnées monde (le sol n'y est pas dessiné)
static func metro_hole() -> Rect2:
	return Rect2(Quartier.METRO.x - HOLE_HX, Quartier.METRO.z + HOLE_Z0, HOLE_HX * 2.0, HOLE_Z1 - HOLE_Z0)


static func metro(crowd: Crowd) -> StaticBody3D:
	var body := _body("MetroGuimard", Quartier.METRO)
	var b := MeshBatch.new()
	var hx := HOLE_HX
	var z0 := HOLE_Z0
	var z1 := HOLE_Z1
	var steps := int((z1 - z0) / STEP_D)
	var depth := steps * STEP_H
	# --- escalier qui s'enfonce vers le nord, murs carrelés, couloir sous le trottoir
	for i in steps:
		var y := -(i + 1) * STEP_H
		var zc := z0 + (i + 0.5) * STEP_D
		b.box("marche", m("marche"), Vector3(hx * 2.0, STEP_H, STEP_D), Vector3(0, y + STEP_H * 0.5, zc))
		b.box("noir", m("noir"), Vector3(hx * 2.0 - 0.02, 0.012, 0.03), Vector3(0, y + STEP_H - 0.004, zc - STEP_D * 0.5 + 0.02))   # nez de marche
	var cz1 := z1 + 3.2
	var cd := depth + 0.0
	for sx in [-1.0, 1.0]:
		b.box("carrelage", m("carrelage"), Vector3(0.1, cd + 0.4, cz1 - z0), Vector3(sx * (hx + 0.05), -cd * 0.5 + 0.17, (z0 + cz1) * 0.5))
		# main courante
		_tube(b, "vert", m("vert"), PackedVector3Array([Vector3(sx * (hx - 0.06), 0.85, z0 + 0.1), Vector3(sx * (hx - 0.06), 0.85 - depth, z1 - 0.1),
			Vector3(sx * (hx - 0.06), 0.85 - depth, z1 + 1.0)]), 0.025, 6)
	b.box("carrelage", m("carrelage"), Vector3(hx * 2.0 + 0.2, 0.62, 0.1), Vector3(0, -0.31 + 0.02, z1 + 0.05))      # linteau du couloir
	b.box("carrelage", m("carrelage"), Vector3(hx * 2.0, 0.1, cz1 - z1), Vector3(0, -0.6, (z1 + cz1) * 0.5))         # plafond
	b.box("marche", m("marche"), Vector3(hx * 2.0, 0.1, cz1 - z1 + 0.4), Vector3(0, -depth - 0.05, (z1 + cz1) * 0.5))
	b.box("neon", m("neon"), Vector3(hx * 2.0, depth - 0.7, 0.05), Vector3(0, -depth * 0.5 - 0.35, cz1))           # fond lumineux
	b.box("neon", m("neon"), Vector3(0.12, 0.03, cz1 - z1 - 0.4), Vector3(0, -0.66, (z1 + cz1) * 0.5))             # tube au plafond
	b.box("carrelage", m("carrelage"), Vector3(hx * 2.0 + 0.2, depth + 0.4, 0.1), Vector3(0, -depth * 0.5, z0 - 0.05))
	# --- margelle de granit autour de la trémie
	for sx in [-1.0, 1.0]:
		b.box("pierre", m("pierre"), Vector3(0.3, 0.1, z1 - z0 + 0.6), Vector3(sx * (hx + 0.15), 0.04, (z0 + z1) * 0.5))
	b.box("pierre", m("pierre"), Vector3(hx * 2.0 + 0.6, 0.1, 0.3), Vector3(0, 0.04, z1 + 0.15))
	# --- rambarde de fonte (côtés et fond) : poteaux, lisses, panneaux ajourés
	var rail_y := 0.09
	var rh := 0.88
	var sides := [[Vector3(-hx - 0.15, 0, z0 + 0.1), Vector3(-hx - 0.15, 0, z1 + 0.15)], [Vector3(hx + 0.15, 0, z0 + 0.1), Vector3(hx + 0.15, 0, z1 + 0.15)],
		[Vector3(-hx - 0.15, 0, z1 + 0.15), Vector3(hx + 0.15, 0, z1 + 0.15)]]
	for sd in sides:
		var a: Vector3 = sd[0]
		var e: Vector3 = sd[1]
		var L := a.distance_to(e)
		var n := maxi(1, int(round(L / 1.15)))
		var dir := (e - a) / L
		var nrm := dir.cross(Vector3.UP)
		for i in n + 1:
			var p := a + dir * (L * i / n)
			b.box("guimard", m("guimard"), Vector3(0.07, rh + 0.05, 0.07), p + Vector3(0, rail_y + (rh + 0.05) * 0.5, 0))
			b.add("guimard", m("guimard"), _finial(), Transform3D(Basis(), p + Vector3(0, rail_y + rh + 0.05, 0)))
			if i < n:
				var c := a + dir * (L * (i + 0.5) / n) + Vector3(0, rail_y + rh * 0.48, 0)
				var hw := dir * (L / n * 0.5 - 0.04)
				var hh := Vector3(0, rh * 0.42, 0)
				b.quad("rambarde", m("rambarde"), [c - hw + hh, c + hw + hh, c + hw - hh, c - hw - hh], nrm)
		_tube(b, "guimard", m("guimard"), PackedVector3Array([a + Vector3(0, rail_y + rh, 0), e + Vector3(0, rail_y + rh, 0)]), 0.032, 8)
		_tube(b, "guimard", m("guimard"), PackedVector3Array([a + Vector3(0, rail_y + 0.06, 0), e + Vector3(0, rail_y + 0.06, 0)]), 0.022, 6)
	# --- lampadaires-tiges et enseigne à l'entrée (sud)
	var zs := z0 - 0.05
	for sx in [-1.0, 1.0]:
		var foot := Vector3(sx * (hx + 0.2), 0.0, zs)
		b.add("guimard", m("guimard"), MeshKit.lathe(PackedVector2Array([Vector2(0.16, 0.0), Vector2(0.15, 0.08), Vector2(0.07, 0.3), Vector2(0.055, 0.6), Vector2(0.0, 0.62)]), 10), Transform3D(Basis(), foot))
		var stem := _curve(foot + Vector3(0, 0.5, 0), foot + Vector3(0, 2.6, 0), foot + Vector3(-sx * 0.35, 3.25, 0), 14)
		_tube(b, "guimard", m("guimard"), stem, 0.05, 8)
		# deuxième tige plus fine qui s'enroule (motif végétal)
		_tube(b, "guimard", m("guimard"), _curve(foot + Vector3(0, 1.4, 0), foot + Vector3(sx * 0.25, 2.3, 0), foot + Vector3(0, 2.75, 0), 10), 0.022, 6)
		# globe orangé en bouton de fleur, tenu par un calice
		var g := foot + Vector3(-sx * 0.42, 3.12, 0)
		b.add("guimard", m("guimard"), MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.05), Vector2(0.09, 0.0), Vector2(0.12, 0.08), Vector2(0.1, 0.1)]), 10), Transform3D(Basis(Vector3.FORWARD, PI), g + Vector3(0, 0.1, 0)))
		b.add("globe", m("globe"), MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.07, 0.03), Vector2(0.1, 0.12), Vector2(0.09, 0.24), Vector2(0.05, 0.3), Vector2(0.0, 0.32)]), 14, 60.0), Transform3D(Basis(Vector3.FORWARD, PI), g + Vector3(0, 0.05, 0)))
	# enseigne entre les deux tiges
	var sy := 2.55
	b.box("guimard", m("guimard"), Vector3(hx * 2.0 + 0.3, 0.42, 0.05), Vector3(0, sy, zs))
	var hw2 := hx + 0.08
	for face in [-1.0, 1.0]:
		var zf: float = zs + face * 0.03
		b.quad("enseigne", m("enseigne"), [Vector3(-hw2 * face, sy + 0.17, zf), Vector3(hw2 * face, sy + 0.17, zf), Vector3(hw2 * face, sy - 0.17, zf), Vector3(-hw2 * face, sy - 0.17, zf)], Vector3(0, 0, face))
	_tube(b, "guimard", m("guimard"), _curve(Vector3(-hx - 0.2, sy + 0.21, zs), Vector3(0, sy + 0.5, zs), Vector3(hx + 0.2, sy + 0.21, zs), 12), 0.03, 6)
	# --- grille fermée en haut des marches (station fermée pendant la manifestation)
	var gz := z0 + 0.06
	for i in 15:
		var x := -hx + 0.06 + i * (hx * 2.0 - 0.12) / 14.0
		b.box("fonte", m("fonte"), Vector3(0.022, 1.02, 0.022), Vector3(x, 0.55, gz))
	for i in 7:
		var x0 := -hx + 0.06 + i * (hx * 2.0 - 0.12) / 7.0
		var x1 := x0 + (hx * 2.0 - 0.12) / 7.0
		_tube(b, "fonte", m("fonte"), PackedVector3Array([Vector3(x0, 0.12, gz + 0.02), Vector3(x1, 1.0, gz + 0.02)]), 0.01, 4)
		_tube(b, "fonte", m("fonte"), PackedVector3Array([Vector3(x1, 0.12, gz + 0.02), Vector3(x0, 1.0, gz + 0.02)]), 0.01, 4)
	b.box("fonte", m("fonte"), Vector3(hx * 2.0, 0.05, 0.05), Vector3(0, 1.06, gz))
	b.box("fonte", m("fonte"), Vector3(hx * 2.0, 0.04, 0.05), Vector3(0, 0.1, gz))
	var mi := b.commit(body, true)
	mi.name = "Edicule"
	# lumière chaude qui monte de l'escalier
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.88, 0.7)
	l.light_energy = 1.4
	l.omni_range = 4.5
	l.shadow_enabled = false
	l.position = Vector3(0, -depth + 0.9, z1 + 1.2)
	body.add_child(l)
	# collisions : bloc autour de la trémie (le sol physique reste plat), tiges
	_col_box(body, Vector3(hx * 2.0 + 0.45, 1.1, z1 - z0 + 0.4), Vector3(0, 0.55, (z0 + z1) * 0.5 + 0.05))
	for sx in [-1.0, 1.0]:
		_col_cyl(body, 0.08, 3.2, Vector3(sx * (hx + 0.2), 1.6, zs))
	if crowd != null:
		crowd.add_obstacle(body, Vector2(hx + 0.35, (z1 - z0) * 0.5 + 0.3), Vector2(0.0, (z0 + z1) * 0.5), false, true)
	return body


static func _finial() -> ArrayMesh:
	if not _m.has("_finial"):
		_m["_finial"] = MeshKit.lathe(PackedVector2Array([Vector2(0.045, 0.0), Vector2(0.05, 0.03), Vector2(0.02, 0.06), Vector2(0.035, 0.1), Vector2(0.0, 0.15)]), 8)
	return _m["_finial"]


# ================================================================== colonne Morris
static func morris(crowd: Crowd) -> StaticBody3D:
	var body := _body("ColonneMorris", Quartier.MORRIS, 0.6)
	var b := MeshBatch.new()
	var v := m("vert")
	b.add("vert", v, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.76, 0.0), Vector2(0.76, 0.1), Vector2(0.7, 0.14),
		Vector2(0.68, 0.3), Vector2(0.64, 0.34), Vector2(0.64, 0.4)]), 32), Transform3D.IDENTITY)
	# fût couvert d'affiches
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.62
	shaft.bottom_radius = 0.62
	shaft.height = 2.3
	shaft.radial_segments = 40
	shaft.rings = 1
	shaft.cap_top = false
	shaft.cap_bottom = false
	b.add("morris", m("morris"), shaft, Transform3D(Basis(), Vector3(0, 0.4 + 1.15, 0)))
	# corniche, frise, dôme écaillé, couronne
	b.add("vert", v, MeshKit.lathe(PackedVector2Array([Vector2(0.62, 2.7), Vector2(0.7, 2.74), Vector2(0.72, 2.82), Vector2(0.66, 2.86),
		Vector2(0.66, 3.2), Vector2(0.75, 3.25), Vector2(0.78, 3.32), Vector2(0.72, 3.36), Vector2(0.62, 3.5),
		Vector2(0.5, 3.72), Vector2(0.34, 3.88), Vector2(0.18, 3.98), Vector2(0.12, 4.02), Vector2(0.1, 4.12),
		Vector2(0.16, 4.18), Vector2(0.06, 4.3), Vector2(0.08, 4.4), Vector2(0.0, 4.48)]), 32, 30.0), Transform3D.IDENTITY)
	# consoles sous la corniche et côtes du dôme
	for i in 16:
		var a := TAU * i / 16.0
		var d := Vector3(cos(a), 0, sin(a))
		b.box("vert", v, Vector3(0.06, 0.24, 0.1), d * 0.69 + Vector3(0, 3.06, 0), Basis(Vector3.UP, -a))
		_tube(b, "vert", v, PackedVector3Array([d * 0.73 + Vector3(0, 3.36, 0), d * 0.6 + Vector3(0, 3.55, 0), d * 0.42 + Vector3(0, 3.8, 0), d * 0.16 + Vector3(0, 4.0, 0)]), 0.018, 5)
	# bandeau sombre de la frise
	var fr := CylinderMesh.new()
	fr.top_radius = 0.665
	fr.bottom_radius = 0.665
	fr.height = 0.26
	fr.radial_segments = 32
	b.add("vert_mat", m("vert_mat"), fr, Transform3D(Basis(), Vector3(0, 3.0, 0)))
	b.commit(body, true)
	_col_cyl(body, 0.72, 4.2, Vector3(0, 2.1, 0))
	if crowd != null:
		crowd.add_obstacle(body, Vector2(0.8, 0.0), Vector2.ZERO, true, true)
	return body


# ================================================================== kiosque à journaux
static func kiosk(crowd: Crowd) -> StaticBody3D:
	var body := _body("Kiosque", Quartier.KIOSK)
	var b := MeshBatch.new()
	var v := m("vert")
	var R := 1.18
	var rot := Basis(Vector3.UP, deg_to_rad(22.5))
	b.add("vert", v, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(R + 0.06, 0.0), Vector2(R + 0.06, 0.14), Vector2(R, 0.18),
		Vector2(R, 2.2), Vector2(R + 0.1, 2.26), Vector2(R + 0.12, 2.34), Vector2(R + 0.06, 2.38), Vector2(R + 0.06, 2.72),
		Vector2(R + 0.2, 2.78), Vector2(R + 0.22, 2.86), Vector2(R + 0.12, 2.9), Vector2(R - 0.1, 3.06), Vector2(0.75, 3.28),
		Vector2(0.42, 3.5), Vector2(0.2, 3.72), Vector2(0.11, 3.86), Vector2(0.09, 3.98), Vector2(0.15, 4.04),
		Vector2(0.06, 4.16), Vector2(0.0, 4.3)]), 8, 20.0), Transform3D(rot, Vector3.ZERO))
	var ap := R * cos(PI / 8.0)
	var fw := 2.0 * R * sin(PI / 8.0)
	var ap2 := (R + 0.06) * cos(PI / 8.0)
	var fw2 := 2.0 * (R + 0.06) * sin(PI / 8.0)
	var A := 1.0 / 1024.0
	for k in 8:
		var th := deg_to_rad(270.0 + 45.0 * k)
		var d := Vector3(cos(th), 0, sin(th))
		var t := Vector3(-d.z, 0, d.x)
		# fronton : JOURNAUX / PRESSE en alternance
		var c := d * (ap2 + 0.012) + Vector3(0, 2.55, 0)
		var uv := Rect2(0, 512 * A, 0.5, 150 * A) if k % 2 == 0 else Rect2(0, 662 * A, 0.5, 150 * A)
		_panel(b, "kiosque", m("kiosque"), c, t * fw2 * 0.47, Vector3(0, 0.16, 0), d, uv)
		c = d * (ap + 0.012)
		match k:
			0:
				# guichet : vitrine sombre, tablette de journaux, magazines suspendus
				b.box("noir", m("noir"), Vector3(fw * 0.86, 0.95, 0.02), c + Vector3(0, 1.62, 0), Basis(Vector3.UP, -th - PI * 0.5))
				_panel(b, "kiosque", m("kiosque"), c + d * 0.005 + Vector3(0, 1.88, 0), t * fw * 0.42, Vector3(0, 0.2, 0), d, Rect2(0.25, 0.0, 0.25, 0.25))
				b.box("vert", v, Vector3(fw * 0.95, 0.05, 0.36), c + d * 0.16 + Vector3(0, 1.12, 0), Basis(Vector3.UP, -th - PI * 0.5))
				for j in 6:
					var col: Color = [Color(0.92, 0.9, 0.85), Color(0.85, 0.82, 0.75), Color(0.95, 0.94, 0.9)][j % 3]
					b.box("journal%d" % (j % 3), MeshKit.std_mat(col, 0.9), Vector3(0.12, 0.03 + (j % 2) * 0.03, 0.2), c + d * 0.15 + t * (-0.24 + j * 0.095) + Vector3(0, 1.16 + (j % 2) * 0.015, 0), Basis(Vector3.UP, -th - PI * 0.5 + 0.1 * (j - 3)))
			1, 7:
				_panel(b, "kiosque", m("kiosque"), c + Vector3(0, 1.45, 0), t * fw * 0.45, Vector3(0, 0.7, 0), d, Rect2(0.0, 0.0, 0.5, 0.5) if k == 1 else Rect2(0.5, 0.0, 0.5, 0.5))
			2, 6:
				_panel(b, "kiosque", m("kiosque"), c + Vector3(0, 1.25, 0), t * fw * 0.42, Vector3(0, 0.84, 0), d, Rect2(0.5 if k == 2 else 0.75, 0.5, 0.25, 0.5))
			_:
				_panel(b, "kiosque", m("kiosque"), c + Vector3(0, 1.2, 0), t * fw * 0.44, Vector3(0, 0.9, 0), d, Rect2(0.02, 812 * A, 0.46, 200 * A))
	b.commit(body, true)
	_col_cyl(body, R + 0.08, 3.0, Vector3(0, 1.5, 0))
	if crowd != null:
		crowd.add_obstacle(body, Vector2(R + 0.15, 0.0), Vector2.ZERO, true, true)
	return body


## Panneau texturé posé contre une face (centre, demi-largeur, demi-hauteur, normale, région de l'atlas)
static func _panel(b: MeshBatch, key: String, mat: Material, c: Vector3, hw: Vector3, hh: Vector3, n: Vector3, uv: Rect2) -> void:
	b.quad(key, mat, [c - hw + hh, c + hw + hh, c + hw - hh, c - hw - hh], n, uv)


# ================================================================== fontaine Wallace
static func wallace(crowd: Crowd) -> StaticBody3D:
	var body := _body("FontaineWallace", Quartier.WALLACE, 0.3)
	var b := MeshBatch.new()
	var v := m("vert")
	b.add("vert", v, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.5, 0.0), Vector2(0.5, 0.08), Vector2(0.44, 0.12),
		Vector2(0.4, 0.16), Vector2(0.36, 0.5), Vector2(0.42, 0.56), Vector2(0.42, 0.64), Vector2(0.32, 0.7), Vector2(0.3, 0.86),
		Vector2(0.36, 0.9), Vector2(0.36, 0.96), Vector2(0.0, 0.97)]), 8, 25.0), Transform3D(Basis(Vector3.UP, PI / 8.0), Vector3.ZERO))
	# quatre cariatides (silhouettes drapées), bras levés vers le dôme
	var fig := MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.075, 0.0), Vector2(0.09, 0.1), Vector2(0.08, 0.35),
		Vector2(0.06, 0.52), Vector2(0.065, 0.6), Vector2(0.075, 0.67), Vector2(0.06, 0.74), Vector2(0.028, 0.78),
		Vector2(0.045, 0.82), Vector2(0.048, 0.88), Vector2(0.03, 0.93), Vector2(0.0, 0.95)]), 10, 50.0)
	for i in 4:
		var a := PI * 0.25 + i * PI * 0.5
		var d := Vector3(cos(a), 0, sin(a))
		var base := d * 0.2 + Vector3(0, 0.97, 0)
		b.add("vert", v, fig, Transform3D(Basis(), base))
		var t := Vector3(-d.z, 0, d.x)
		for s in [-1.0, 1.0]:
			_tube(b, "vert", v, PackedVector3Array([base + Vector3(0, 0.7, 0) + t * s * 0.06, base + Vector3(0, 0.9, 0) + t * s * 0.09 + d * 0.03,
				base + Vector3(0, 1.04, 0) + t * s * 0.07 + d * 0.05]), 0.016, 5)
	# dôme à lambrequins
	b.add("vert", v, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 1.98), Vector2(0.44, 1.98), Vector2(0.46, 2.04), Vector2(0.42, 2.1),
		Vector2(0.36, 2.2), Vector2(0.26, 2.34), Vector2(0.14, 2.45), Vector2(0.08, 2.5), Vector2(0.06, 2.56), Vector2(0.09, 2.6),
		Vector2(0.04, 2.7), Vector2(0.0, 2.74)]), 24, 30.0), Transform3D.IDENTITY)
	for i in 24:
		var a := TAU * i / 24.0
		b.box("vert", v, Vector3(0.1, 0.09, 0.015), Vector3(cos(a) * 0.445, 1.94, sin(a) * 0.445), Basis(Vector3.UP, -a + PI * 0.5))
	# filet d'eau qui tombe au centre, sur la grille
	var w := CylinderMesh.new()
	w.top_radius = 0.008
	w.bottom_radius = 0.012
	w.height = 0.98
	w.radial_segments = 6
	b.add("eau", m("eau"), w, Transform3D(Basis(), Vector3(0, 1.47, 0)))
	b.cyl("noir", m("noir"), 0.12, 0.12, 0.01, Vector3(0, 0.975, 0), Basis(), 12)
	b.commit(body, true)
	_col_cyl(body, 0.48, 2.7, Vector3(0, 1.35, 0))
	if crowd != null:
		crowd.add_obstacle(body, Vector2(0.55, 0.0), Vector2.ZERO, true, true)
	return body


# ================================================================== bancs
## Banc parisien : pieds de fonte, lattes de bois (vertes ou naturelles) ; `double` : dos à dos (Davioud)
static func bench(pos: Vector3, yaw: float, double := false, crowd: Crowd = null) -> StaticBody3D:
	var body := _body("Banc", pos, yaw)
	var b := MeshBatch.new()
	var wood := m("bois_vert") if (int(absf(pos.x) * 7.0 + absf(pos.z) * 3.0) % 3) != 0 else m("bois")
	var key := "bv" if wood == m("bois_vert") else "bn"
	var iron := m("fonte")
	var L := 1.9
	for side in ([1.0, -1.0] if double else [1.0]):
		var s: float = side
		var off := Vector3(0, 0, s * (0.3 if double else 0.0))
		# assise : 4 lattes ; dossier : 3 lattes inclinées
		for i in 4:
			b.box(key, wood, Vector3(L, 0.035, 0.075), off + Vector3(0, 0.44, s * (0.04 + i * 0.09)))
		for i in 3:
			var y := 0.58 + i * 0.12
			b.box(key, wood, Vector3(L, 0.075, 0.03), off + Vector3(0, y, s * (-0.03 - (y - 0.5) * 0.25)), Basis(Vector3.RIGHT, s * 0.25))
		for x in [-L * 0.42, L * 0.42]:
			var px := float(x)
			b.box("fonte", iron, Vector3(0.05, 0.44, 0.05), off + Vector3(px, 0.22, s * 0.3))
			b.box("fonte", iron, Vector3(0.05, 0.05, 0.42), off + Vector3(px, 0.42, s * 0.16))
			_tube(b, "fonte", iron, PackedVector3Array([off + Vector3(px, 0.0, s * -0.02), off + Vector3(px, 0.42, s * 0.0), off + Vector3(px, 0.9, s * -0.12)]), 0.025, 5)
			# accoudoir en volute
			_tube(b, "fonte", iron, _curve(off + Vector3(px * 1.04, 0.42, s * 0.36), off + Vector3(px * 1.06, 0.66, s * 0.38), off + Vector3(px * 1.04, 0.62, s * 0.02), 8), 0.02, 5)
	b.commit(body, true)
	var depth := 1.2 if double else 0.6
	_col_box(body, Vector3(L, 0.5, depth), Vector3(0, 0.25, 0.0 if double else 0.12))
	if crowd != null:
		crowd.add_obstacle(body, Vector2(L * 0.5 + 0.05, depth * 0.5), Vector2(0, 0.0 if double else 0.12), false, true)
	return body


# ================================================================== arceaux à vélos
static func bike_racks(pos: Vector3, n: int, yaw: float, crowd: Crowd = null) -> StaticBody3D:
	var body := _body("ArceauxVelos", pos, yaw)
	var b := MeshBatch.new()
	var w := (n - 1) * 0.85
	for i in n:
		var x := -w * 0.5 + i * 0.85
		var pts := PackedVector3Array([Vector3(x, 0.0, -0.36), Vector3(x, 0.55, -0.36)])
		for k in 9:
			var a := PI * float(k) / 8.0
			pts.append(Vector3(x, 0.55 + sin(a) * 0.2, -cos(a) * 0.36))
		pts.append(Vector3(x, 0.55, 0.36))
		pts.append(Vector3(x, 0.0, 0.36))
		_tube(b, "galva", m("galva"), pts, 0.025, 8)
		_col_box(body, Vector3(0.06, 0.78, 0.76), Vector3(x, 0.39, 0))
	b.commit(body, false)
	if crowd != null:
		crowd.add_obstacle(body, Vector2(w * 0.5 + 0.12, 0.42), Vector2.ZERO, false, true)
	return body


# ================================================================== jardinières
## Bac planté (bois ou béton) : arbustes taillés et fleurs
static func planter_box(pos: Vector3, yaw: float, sd: int, crowd: Crowd = null) -> StaticBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var body := _body("Jardiniere", pos, yaw)
	var b := MeshBatch.new()
	var L := rng.randf_range(1.5, 2.0)
	var D := 0.62
	var H := 0.62
	if rng.randf() < 0.5:
		# bois : lattes horizontales
		for i in 5:
			b.box("bois", m("bois"), Vector3(L, H / 5.0 - 0.012, D), Vector3(0, H / 10.0 + i * H / 5.0, 0))
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				b.box("fonte", m("fonte"), Vector3(0.07, H + 0.04, 0.07), Vector3(sx * (L * 0.5 - 0.02), (H + 0.04) * 0.5, sz * (D * 0.5 - 0.02)))
	else:
		b.box("beton", m("beton"), Vector3(L, H, D), Vector3(0, H * 0.5, 0))
		b.box("beton", m("beton"), Vector3(L + 0.06, 0.06, D + 0.06), Vector3(0, H, 0))
	b.box("terre", m("terre"), Vector3(L - 0.1, 0.02, D - 0.1), Vector3(0, H + 0.02, 0))
	var bush := SphereMesh.new()
	bush.radius = 0.5
	bush.height = 1.0
	bush.radial_segments = 14
	bush.rings = 8
	var nb := 2 + rng.randi() % 2
	for i in nb:
		var x := -L * 0.5 + (i + 0.5) * L / nb
		var s := Vector3(rng.randf_range(0.5, 0.62), rng.randf_range(0.45, 0.7), 0.5)
		b.add("haie", m("haie"), bush, Transform3D(Basis.from_scale(s), Vector3(x, H + s.y * 0.42, 0)))
	if rng.randf() < 0.7:
		for i in 2:
			b.add("fleurs", m("fleurs"), bush, Transform3D(Basis.from_scale(Vector3(0.35, 0.18, 0.3)), Vector3(-L * 0.25 + i * L * 0.5, H + 0.06, D * 0.22)))
	b.commit(body, true)
	_col_box(body, Vector3(L, H, D), Vector3(0, H * 0.5, 0))
	if crowd != null:
		crowd.add_obstacle(body, Vector2(L * 0.5 + 0.05, D * 0.5 + 0.05), Vector2.ZERO, false, true)
	return body
