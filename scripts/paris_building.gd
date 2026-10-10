class_name ParisBuilding
extends Node3D
## Immeuble haussmannien procédural : rez-de-chaussée à refends (boutiques ou porte cochère), entresol,
## étage noble à balcon filant, deux étages à balconnets, cinquième à balcon filant, corniche à denticules,
## toit mansardé en zinc avec lucarnes et souches de cheminée.
## Repère local : façade dans le plan z = 0, rue côté +Z, l'immeuble s'étend vers -Z ; x de 0 à `width`.
## Toute la géométrie d'un immeuble est fusionnée en un seul maillage (une surface par matériau).

const H0 := 4.6            # rez-de-chaussée (avec entresol)
const FH := 3.15           # hauteur d'un étage courant
const FLOORS := 5
const WALL := 0.55         # épaisseur du mur de façade
const DEPTH := 12.0        # profondeur du bâtiment
const WIN_W := 1.18
const WIN_H := 2.15
const SHOP_DEPTH := 6.2

var width := 16.0
var seed_v := 1
var shops := 0              # nombre de boutiques envahissables au rez-de-chaussée (0 : porte cochère et rideaux fermés)
var crowd: Crowd
var lod_far := false        # bâtiment lointain : moins de détails (pas de balustres, pas de denticules)

var shop_nodes: Array = []  # Shop
## Places pour les habitants (balcons, fenêtres ouvertes) : [{"xf": Transform3D monde (pieds, -Z local = vers la rue
## est +Z de xf.basis... voir resident_spot()), "kind": "balcony" | "window", "floor": int}]
var resident_spots: Array = []
var _rng := RandomNumberGenerator.new()
var _acc := {}              # matériau -> SurfaceTool
var _body: StaticBody3D

static var _mats := {}


# =================================================================== matériaux partagés
static func mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"stone", "stone_l", "stone_d":
			m.albedo_texture = load("res://assets/paris/stone_a.png")
			m.normal_enabled = true
			m.normal_texture = load("res://assets/paris/stone_n.png")
			m.normal_scale = 0.8
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.5, 0.5, 0.5)
			m.roughness = 0.88
			# calcaire lutétien : crème chaud, jamais blanc
			m.albedo_color = {"stone": Color(0.86, 0.8, 0.7), "stone_l": Color(0.92, 0.87, 0.78), "stone_d": Color(0.74, 0.69, 0.61)}[key]
		"zinc":
			m.albedo_texture = load("res://assets/paris/zinc_a.png")
			m.normal_enabled = true
			m.normal_texture = load("res://assets/paris/zinc_n.png")
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.66, 0.66, 0.66)
			m.metallic = 0.55
			m.roughness = 0.42
		"iron":
			m.albedo_color = Color(0.045, 0.048, 0.055)
			m.metallic = 0.75
			m.roughness = 0.4
		"frame":
			m.albedo_color = Color(0.9, 0.88, 0.83)
			m.roughness = 0.45
		"glass":
			m.albedo_color = Color(0.05, 0.065, 0.085)
			m.metallic = 0.7
			m.roughness = 0.06
			m.metallic_specular = 1.0
		"glass_lit":
			m.albedo_color = Color(0.25, 0.2, 0.14)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.72, 0.42)
			m.emission_energy_multiplier = 1.3
			m.roughness = 0.1
		"glass_tv":
			m.albedo_color = Color(0.1, 0.12, 0.16)
			m.emission_enabled = true
			m.emission = Color(0.45, 0.6, 1.0)
			m.emission_energy_multiplier = 0.9
			m.roughness = 0.1
		"curtain":
			m.albedo_color = Color(0.82, 0.78, 0.7)
			m.roughness = 0.9
		"brick":
			m.albedo_color = Color(0.56, 0.3, 0.22)
			m.roughness = 0.9
		"pot":
			m.albedo_color = Color(0.62, 0.36, 0.24)
			m.roughness = 0.8
		"wood":
			m.albedo_color = Color(0.2, 0.12, 0.07)
			m.roughness = 0.55
		"shut":
			# rideau métallique de boutique fermée
			m.albedo_color = Color(0.5, 0.52, 0.55)
			m.metallic = 0.6
			m.roughness = 0.5
		"shop_green", "shop_red", "shop_blue", "shop_black", "shop_gold":
			m.albedo_color = {"shop_green": Color(0.06, 0.22, 0.16), "shop_red": Color(0.36, 0.05, 0.06),
				"shop_blue": Color(0.05, 0.1, 0.24), "shop_black": Color(0.04, 0.04, 0.045), "shop_gold": Color(0.55, 0.42, 0.16)}[key]
			m.roughness = 0.35
			m.metallic = 0.15 if key != "shop_gold" else 0.8
		"awning_red", "awning_green", "awning_blue":
			m.albedo_color = {"awning_red": Color(0.55, 0.08, 0.08), "awning_green": Color(0.08, 0.32, 0.18), "awning_blue": Color(0.08, 0.16, 0.38)}[key]
			m.roughness = 0.85
		_:
			m.albedo_color = Color(1, 0, 1)
	_mats[key] = m
	return m


# =================================================================== construction
func _ready() -> void:
	_rng.seed = seed_v
	_body = StaticBody3D.new()
	add_child(_body)
	_build_ground_floor()
	_build_floors()
	_build_cornice()
	_build_roof()
	_commit()
	add_to_group("paris_buildings")


func _st(key: String) -> SurfaceTool:
	if not _acc.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_acc[key] = st
	return _acc[key]


static var _unit_box: BoxMesh
static var _unit_cyl: CylinderMesh

## Pavé de taille `size` centré en `c` (repère du bâtiment), tourné de `b`
func box(key: String, size: Vector3, c: Vector3, b := Basis()) -> void:
	if _unit_box == null:
		_unit_box = BoxMesh.new()
		_unit_box.size = Vector3.ONE
	_st(key).append_from(_unit_box, 0, Transform3D(b * Basis.from_scale(size), c))


func cyl(key: String, r: float, h: float, c: Vector3, b := Basis()) -> void:
	if _unit_cyl == null:
		_unit_cyl = CylinderMesh.new()
		_unit_cyl.top_radius = 0.5
		_unit_cyl.bottom_radius = 0.5
		_unit_cyl.height = 1.0
		_unit_cyl.radial_segments = 10
		_unit_cyl.rings = 1
	_st(key).append_from(_unit_cyl, 0, Transform3D(b * Basis.from_scale(Vector3(r * 2.0, h, r * 2.0)), c))


func collider(size: Vector3, c: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = c
	_body.add_child(cs)


func _commit() -> void:
	var am := ArrayMesh.new()
	for key in _acc:
		var st: SurfaceTool = _acc[key]
		st.generate_normals()
		st.commit(am)
		am.surface_set_material(am.get_surface_count() - 1, mat(key))
	var mi := MeshInstance3D.new()
	mi.mesh = am
	add_child(mi)
	_acc.clear()


## Abscisses des travées (centres de fenêtres) sur la largeur
func _bays() -> Array[float]:
	var n := maxi(int((width - 1.6) / 2.6), 2)
	var out: Array[float] = []
	var step := (width - 1.6) / float(n)
	for i in n:
		out.append(0.8 + step * (float(i) + 0.5))
	return out


# ------------------------------------------------------------------ rez-de-chaussée
func _build_ground_floor() -> void:
	var bays := _bays()
	var step := bays[1] - bays[0]
	# 1) les ouvertures : boutiques envahissables, porte cochère, boutiques fermées (rideau baissé)
	var shop_slots: Array[int] = []
	if shops > 0:
		var nb := bays.size()
		var first := 0 if nb <= 3 else _rng.randi_range(0, 1)
		for k in shops:
			var idx := first + k * 2
			if idx < nb:
				shop_slots.append(idx)
	var openings: Array = []          # [x0, x1, haut, type, centre]
	var door_done := false
	for k in bays.size():
		var cx := bays[k]
		if shop_slots.has(k):
			var w := minf(step * 1.5, 5.0) if (k + 1 < bays.size() and not shop_slots.has(k + 1)) else step - 0.7
			var c2 := cx + (w - (step - 0.7)) * 0.5
			openings.append([c2 - w * 0.5, c2 + w * 0.5, H0 - 0.9, "shop", c2])
		elif not door_done and _rng.randf() < 0.55:
			door_done = true
			openings.append([cx - 1.45, cx + 1.45, 4.05, "door", cx])
		else:
			openings.append([cx - (step - 0.7) * 0.5, cx + (step - 0.7) * 0.5, H0 - 0.9, "closed", cx])
	# les boutiques élargies peuvent chevaucher la travée suivante : on retire ce qui se recouvre
	openings.sort_custom(func(a, b): return a[0] < b[0])
	var clean: Array = []
	for o in openings:
		if not clean.is_empty() and o[0] < clean[clean.size() - 1][1] + 0.5:
			continue
		clean.append(o)
	openings = clean
	# 2) la pierre à refends : trumeaux pleine hauteur et impostes au-dessus des ouvertures
	var x0 := 0.0
	for o in openings:
		_rustic(x0, o[0], 0.0, H0)
		_rustic(o[0], o[1], o[2], H0)
		x0 = o[1]
	_rustic(x0, width, 0.0, H0)
	box("stone_d", Vector3(width, 0.12, 0.2), Vector3(width * 0.5, H0 - 0.06, 0.1))     # cordon sous l'étage
	# 3) le contenu des ouvertures
	for o in openings:
		match o[3]:
			"shop":
				_shop_opening(o[4], o[1] - o[0])
			"door":
				_porte_cochere(o[4])
			_:
				_closed_shop(o[4], o[1] - o[0])
	# 4) collisions : tout le volume sauf l'intérieur des boutiques ouvertes
	if shop_nodes.is_empty():
		collider(Vector3(width, H0, DEPTH), Vector3(width * 0.5, H0 * 0.5, -DEPTH * 0.5))
	else:
		_ground_colliders()
	collider(Vector3(width, FH * FLOORS + 4.0, DEPTH), Vector3(width * 0.5, H0 + (FH * FLOORS + 4.0) * 0.5, -DEPTH * 0.5))


## Pierre à refends entre x0 et x1, de y0 à y1 : assises en saillie séparées par des rainures
func _rustic(x0: float, x1: float, y0: float, y1: float) -> void:
	var w := x1 - x0
	if w < 0.02 or y1 - y0 < 0.02:
		return
	var cx := (x0 + x1) * 0.5
	var y := y0
	var i := 0
	while y < y1 - 0.02:
		var hh := minf(0.42, y1 - y)
		box("stone_d" if i % 2 == 0 else "stone", Vector3(w, maxf(hh - 0.04, 0.01), WALL), Vector3(cx, y + hh * 0.5, -WALL * 0.5 + 0.03))
		box("stone_d", Vector3(w, 0.04, WALL - 0.04), Vector3(cx, y + hh - 0.02, -WALL * 0.5))
		y += hh
		i += 1
	if y0 < 0.01:
		box("stone_d", Vector3(w, 0.35, WALL + 0.06), Vector3(cx, 0.175, -WALL * 0.5 + 0.03))     # soubassement


## Murs du rez-de-chaussée autour des boutiques : la façade entre les ouvertures, les cloisons, le fond
func _ground_colliders() -> void:
	var xs: Array = []
	for s in shop_nodes:
		var sh := s as Shop
		xs.append([sh.position.x - sh.width * 0.5, sh.position.x + sh.width * 0.5])
	xs.sort_custom(func(a, b): return a[0] < b[0])
	var x0 := 0.0
	for r in xs:
		if r[0] - x0 > 0.05:
			collider(Vector3(r[0] - x0, H0, DEPTH), Vector3((x0 + r[0]) * 0.5, H0 * 0.5, -DEPTH * 0.5))
		# fond de la boutique et derrière
		collider(Vector3(r[1] - r[0], H0, DEPTH - SHOP_DEPTH), Vector3((r[0] + r[1]) * 0.5, H0 * 0.5, -SHOP_DEPTH - (DEPTH - SHOP_DEPTH) * 0.5))
		# imposte au-dessus de la vitrine (le haut de l'ouverture)
		collider(Vector3(r[1] - r[0], 0.9, WALL), Vector3((r[0] + r[1]) * 0.5, H0 - 0.45, -WALL * 0.5))
		x0 = r[1]
	if width - x0 > 0.05:
		collider(Vector3(width - x0, H0, DEPTH), Vector3((x0 + width) * 0.5, H0 * 0.5, -DEPTH * 0.5))


func _shop_opening(cx: float, w: float) -> void:
	var types := ["banque", "boulangerie", "pharmacie", "superette", "boutique", "cafe"]
	var t: String = types[_rng.randi() % types.size()]
	var colk: String = ["shop_green", "shop_red", "shop_blue", "shop_black"][_rng.randi() % 4]
	if t == "banque":
		colk = "shop_blue"
	elif t == "pharmacie":
		colk = "shop_green"
	# devanture en bois peint : piédroits, bandeau d'enseigne, soubassement
	box(colk, Vector3(0.22, H0 - 0.9, 0.16), Vector3(cx - w * 0.5 - 0.06, (H0 - 0.9) * 0.5, 0.02))
	box(colk, Vector3(0.22, H0 - 0.9, 0.16), Vector3(cx + w * 0.5 + 0.06, (H0 - 0.9) * 0.5, 0.02))
	box(colk, Vector3(w + 0.5, 0.62, 0.18), Vector3(cx, H0 - 1.2, 0.03))
	box("shop_gold", Vector3(w + 0.5, 0.04, 0.2), Vector3(cx, H0 - 0.88, 0.04))
	box("shop_gold", Vector3(w + 0.5, 0.04, 0.2), Vector3(cx, H0 - 1.52, 0.04))
	box(colk, Vector3(w, 0.42, 0.12), Vector3(cx, 0.21, 0.0))
	# store banne
	if _rng.randf() < 0.7 and t != "banque":
		var ak: String = ["awning_red", "awning_green", "awning_blue"][_rng.randi() % 3]
		box(ak, Vector3(w + 0.3, 0.04, 1.5), Vector3(cx, H0 - 1.75, 0.72), Basis(Vector3.RIGHT, 0.38))
		box(ak, Vector3(w + 0.3, 0.28, 0.03), Vector3(cx, H0 - 2.15, 1.42))
	var shop := Shop.new()
	shop.kind = t
	shop.width = w
	shop.depth = SHOP_DEPTH
	shop.height = H0 - 0.9
	shop.crowd = crowd
	shop.building = self
	shop.position = Vector3(cx, 0.0, 0.0)
	shop.sign_color = colk
	shop.lit = absf(global_position.x) < 120.0
	add_child(shop)
	shop_nodes.append(shop)


func _closed_shop(cx: float, w: float) -> void:
	# boutique fermée : rideau métallique baissé, enseigne
	var colk: String = ["shop_green", "shop_red", "shop_blue", "shop_black"][_rng.randi() % 4]
	box(colk, Vector3(w + 0.3, 0.55, 0.16), Vector3(cx, H0 - 1.15, 0.03))
	box("shut", Vector3(w, H0 - 1.5, 0.05), Vector3(cx, (H0 - 1.5) * 0.5, -0.12))
	for j in int((H0 - 1.5) / 0.09):
		box("stone_d", Vector3(w, 0.012, 0.02), Vector3(cx, 0.05 + float(j) * 0.09, -0.09))
	box(colk, Vector3(0.18, H0 - 1.4, 0.14), Vector3(cx - w * 0.5 - 0.05, (H0 - 1.4) * 0.5, 0.02))
	box(colk, Vector3(0.18, H0 - 1.4, 0.14), Vector3(cx + w * 0.5 + 0.05, (H0 - 1.4) * 0.5, 0.02))


func _porte_cochere(cx: float) -> void:
	var w := 2.6
	var h := 3.9
	box("stone_l", Vector3(w + 0.6, 0.35, 0.12), Vector3(cx, h + 0.15, 0.06))
	box("stone_l", Vector3(0.3, h, 0.1), Vector3(cx - w * 0.5 - 0.15, h * 0.5, 0.05))
	box("stone_l", Vector3(0.3, h, 0.1), Vector3(cx + w * 0.5 + 0.15, h * 0.5, 0.05))
	box("wood", Vector3(w, h, 0.1), Vector3(cx, h * 0.5, -0.2))
	for j in 4:
		box("wood", Vector3(w - 0.2, 0.06, 0.06), Vector3(cx, 0.6 + float(j) * 0.9, -0.12))
	box("wood", Vector3(0.06, h - 0.2, 0.06), Vector3(cx, h * 0.5, -0.12))
	box("shop_gold", Vector3(0.05, 0.05, 0.1), Vector3(cx - 0.18, 1.1, -0.1))
	box("shop_gold", Vector3(0.05, 0.05, 0.1), Vector3(cx + 0.18, 1.1, -0.1))


# ------------------------------------------------------------------ étages
func _build_floors() -> void:
	var bays := _bays()
	for f in FLOORS:
		var y0 := H0 + float(f) * FH
		var sill := 0.85
		var top := y0 + sill + WIN_H
		# bandeau d'étage
		box("stone_l", Vector3(width, 0.2, 0.14), Vector3(width * 0.5, y0 + 0.1, 0.07))
		# allège et linteau
		box("stone", Vector3(width, sill, WALL), Vector3(width * 0.5, y0 + sill * 0.5, -WALL * 0.5))
		box("stone", Vector3(width, y0 + FH - top, WALL), Vector3(width * 0.5, (top + y0 + FH) * 0.5, -WALL * 0.5))
		# trumeaux entre les fenêtres
		var xs: Array[float] = [0.0]
		for c in bays:
			xs.append(c - WIN_W * 0.5)
			xs.append(c + WIN_W * 0.5)
		xs.append(width)
		for k in range(0, xs.size(), 2):
			var a: float = xs[k]
			var b: float = xs[k + 1]
			if b - a > 0.01:
				box("stone", Vector3(b - a, WIN_H, WALL), Vector3((a + b) * 0.5, y0 + sill + WIN_H * 0.5, -WALL * 0.5))
		for c in bays:
			_window(c, y0 + sill, f)
		# balcons : filant au 2e (étage noble) et au 5e, balconnets ailleurs
		if f == 1 or f == 4:
			_balcony(0.15, width - 0.15, y0 + sill - 0.05, 0.85)
		elif f > 0:
			for c in bays:
				_railing(c - WIN_W * 0.5 - 0.05, c + WIN_W * 0.5 + 0.05, y0 + sill - 0.02, 0.06, 0.95)


func _window(cx: float, y: float, f: int) -> void:
	var recess := 0.3
	# encadrement en pierre, légèrement en saillie
	box("stone_l", Vector3(WIN_W + 0.3, 0.14, 0.08), Vector3(cx, y + WIN_H + 0.07, 0.04))
	box("stone_l", Vector3(0.15, WIN_H, 0.06), Vector3(cx - WIN_W * 0.5 - 0.075, y + WIN_H * 0.5, 0.03))
	box("stone_l", Vector3(0.15, WIN_H, 0.06), Vector3(cx + WIN_W * 0.5 + 0.075, y + WIN_H * 0.5, 0.03))
	# appui saillant
	box("stone_l", Vector3(WIN_W + 0.4, 0.08, 0.2), Vector3(cx, y - 0.03, 0.06))
	# étage noble : fronton cintré sur consoles
	if f == 1:
		box("stone_l", Vector3(WIN_W + 0.6, 0.12, 0.28), Vector3(cx, y + WIN_H + 0.3, 0.1))
		box("stone_l", Vector3(WIN_W + 0.3, 0.22, 0.16), Vector3(cx, y + WIN_H + 0.47, 0.05))
		for s in [-1.0, 1.0]:
			box("stone_l", Vector3(0.12, 0.34, 0.18), Vector3(cx + s * (WIN_W * 0.5 + 0.16), y + WIN_H + 0.12, 0.09))
	elif f == 2 or f == 3:
		box("stone_l", Vector3(WIN_W + 0.42, 0.1, 0.18), Vector3(cx, y + WIN_H + 0.2, 0.08))
	# vitrage : sombre, ou allumé (rideaux) chez certains
	var r := _rng.randf()
	var gk := "glass_lit" if r < 0.3 else ("glass_tv" if r < 0.34 else "glass")
	box(gk, Vector3(WIN_W, WIN_H, 0.03), Vector3(cx, y + WIN_H * 0.5, -recess))
	if gk != "glass" and _rng.randf() < 0.6:
		box("curtain", Vector3(0.32, WIN_H - 0.2, 0.03), Vector3(cx - WIN_W * 0.5 + 0.18, y + WIN_H * 0.5, -recess - 0.04))
	# châssis : deux vantaux à petits bois (porte-fenêtre)
	box("frame", Vector3(WIN_W, 0.06, 0.06), Vector3(cx, y + WIN_H - 0.03, -recess + 0.03))
	box("frame", Vector3(WIN_W, 0.06, 0.06), Vector3(cx, y + 0.03, -recess + 0.03))
	box("frame", Vector3(0.06, WIN_H, 0.06), Vector3(cx - WIN_W * 0.5 + 0.03, y + WIN_H * 0.5, -recess + 0.03))
	box("frame", Vector3(0.06, WIN_H, 0.06), Vector3(cx + WIN_W * 0.5 - 0.03, y + WIN_H * 0.5, -recess + 0.03))
	box("frame", Vector3(0.05, WIN_H, 0.05), Vector3(cx, y + WIN_H * 0.5, -recess + 0.03))
	if not lod_far:
		for j in [0.36, 0.62]:
			box("frame", Vector3(WIN_W, 0.03, 0.04), Vector3(cx, y + WIN_H * j, -recess + 0.03))
		box("frame", Vector3(WIN_W, 0.04, 0.04), Vector3(cx, y + WIN_H * 0.84, -recess + 0.03))
	# tableaux (côtés de l'embrasure)
	box("stone_d", Vector3(0.02, WIN_H, recess), Vector3(cx - WIN_W * 0.5, y + WIN_H * 0.5, -recess * 0.5))
	box("stone_d", Vector3(0.02, WIN_H, recess), Vector3(cx + WIN_W * 0.5, y + WIN_H * 0.5, -recess * 0.5))


## Balcon filant : dalle de pierre sur consoles + garde-corps en fer forgé
func _balcony(x0: float, x1: float, y: float, depth: float) -> void:
	var w := x1 - x0
	box("stone_l", Vector3(w, 0.16, depth), Vector3((x0 + x1) * 0.5, y, depth * 0.5))
	box("stone_l", Vector3(w + 0.08, 0.06, depth + 0.06), Vector3((x0 + x1) * 0.5, y + 0.09, depth * 0.5))
	var x := x0 + 0.4
	while x < x1 - 0.3:
		box("stone_l", Vector3(0.14, 0.32, depth * 0.8), Vector3(x, y - 0.22, depth * 0.4), Basis(Vector3.RIGHT, -0.15))
		x += 1.25
	_railing(x0, x1, y + 0.08, depth - 0.06, 1.0)


func _railing(x0: float, x1: float, y: float, z: float, h: float) -> void:
	var w := x1 - x0
	var cx := (x0 + x1) * 0.5
	box("iron", Vector3(w, 0.05, 0.06), Vector3(cx, y + h, z))         # main courante
	box("iron", Vector3(w, 0.025, 0.025), Vector3(cx, y + 0.08, z))
	box("iron", Vector3(w, 0.02, 0.02), Vector3(cx, y + h * 0.78, z))
	box("iron", Vector3(w, 0.02, 0.02), Vector3(cx, y + h * 0.22, z))
	if lod_far:
		box("iron", Vector3(w, h * 0.5, 0.01), Vector3(cx, y + h * 0.5, z))
		return
	# barreaux et motifs (losanges entre les lisses médianes)
	var x := x0 + 0.06
	var k := 0
	while x < x1 - 0.03:
		box("iron", Vector3(0.016, h, 0.016), Vector3(x, y + h * 0.5, z))
		if k % 3 == 1:
			box("iron", Vector3(0.012, h * 0.42, 0.012), Vector3(x + 0.05, y + h * 0.5, z), Basis(Vector3.BACK, 0.5))
			box("iron", Vector3(0.012, h * 0.42, 0.012), Vector3(x - 0.05, y + h * 0.5, z), Basis(Vector3.BACK, -0.5))
		x += 0.1
		k += 1
	# poteaux
	box("iron", Vector3(0.05, h, 0.05), Vector3(x0 + 0.02, y + h * 0.5, z))
	box("iron", Vector3(0.05, h, 0.05), Vector3(x1 - 0.02, y + h * 0.5, z))


# ------------------------------------------------------------------ corniche et toit
func _build_cornice() -> void:
	var y := H0 + FH * FLOORS
	box("stone_l", Vector3(width, 0.22, 0.22), Vector3(width * 0.5, y + 0.11, 0.11))
	box("stone_l", Vector3(width, 0.2, 0.42), Vector3(width * 0.5, y + 0.32, 0.21))
	box("stone_l", Vector3(width + 0.02, 0.12, 0.56), Vector3(width * 0.5, y + 0.48, 0.28))
	if not lod_far:
		var x := 0.1
		while x < width - 0.05:
			box("stone_l", Vector3(0.07, 0.09, 0.12), Vector3(x, y + 0.27, 0.27))     # denticules
			x += 0.17
	# mur porteur jusqu'à la corniche
	box("stone", Vector3(width, 0.6, WALL), Vector3(width * 0.5, y + 0.3, -WALL * 0.5))


func _build_roof() -> void:
	var y := H0 + FH * FLOORS + 0.54
	var h := 3.4
	var run := 1.3
	# brisis (pente raide en zinc) puis terrasson (pente douce)
	var ang := atan2(run, h)
	var slen := sqrt(h * h + run * run)
	box("zinc", Vector3(width, slen, 0.08), Vector3(width * 0.5, y + h * 0.5, -0.2 - run * 0.5), Basis(Vector3.RIGHT, -ang))
	box("zinc", Vector3(width, 0.08, DEPTH - 2.0 * run - 0.4), Vector3(width * 0.5, y + h + 0.25, -DEPTH * 0.5), Basis(Vector3.RIGHT, 0.0))
	# rive d'égout (gouttière) et faîtage
	box("iron", Vector3(width, 0.12, 0.14), Vector3(width * 0.5, y + 0.02, 0.0))
	box("zinc", Vector3(width, 0.1, 0.12), Vector3(width * 0.5, y + h, -0.2 - run))
	# lucarnes à chaque travée
	for c in _bays():
		var dz := -0.2 - run * 0.45
		var dy := y + h * 0.42
		box("stone_l", Vector3(1.1, 1.65, 0.9), Vector3(c, dy + 0.4, dz - 0.15))
		box("glass_lit" if _rng.randf() < 0.25 else "glass", Vector3(0.72, 1.15, 0.03), Vector3(c, dy + 0.35, dz + 0.31))
		box("frame", Vector3(0.05, 1.15, 0.05), Vector3(c, dy + 0.35, dz + 0.33))
		box("frame", Vector3(0.72, 0.05, 0.05), Vector3(c, dy + 0.62, dz + 0.33))
		# chapeau cintré en zinc
		box("zinc", Vector3(1.3, 0.12, 1.1), Vector3(c, dy + 1.27, dz - 0.1))
		box("stone_l", Vector3(1.3, 0.16, 0.12), Vector3(c, dy + 1.15, dz + 0.36))
	# souches de cheminée en briques, avec mitrons
	var n := 2 + _rng.randi() % 2
	for i in n:
		var cx := width * (float(i) + 0.5) / float(n) + _rng.randf_range(-0.8, 0.8)
		var cz := -run - 1.8 - _rng.randf() * 3.0
		box("brick", Vector3(0.95, 2.0, 0.6), Vector3(cx, y + h + 1.0, cz))
		box("stone_l", Vector3(1.05, 0.1, 0.7), Vector3(cx, y + h + 2.0, cz))
		for p in 3:
			cyl("pot", 0.075, 0.42, Vector3(cx - 0.28 + float(p) * 0.28, y + h + 2.25, cz))


# =================================================================== interactions
## Coups de pied (joueur, manifestants) : transmis à la vitrine la plus proche
func kick(point: Vector3, dir: Vector3, power := 1.0) -> bool:
	for s in shop_nodes:
		if (s as Shop).kick(point, dir, power):
			return true
	return false
