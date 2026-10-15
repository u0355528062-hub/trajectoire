class_name Streetscape
extends Node3D
## Le quartier vivant : sols (bordures de granit, caniveaux pavés, avaloirs, plaques d'égout, passages piétons,
## bandes podotactiles), platanes en alignement avec grilles d'arbre, square, mobilier parisien (métro Guimard,
## colonne Morris, kiosque, fontaine Wallace, bancs, corbeilles, potelets, arceaux à vélos, panneaux,
## lampadaires, jardinières, poubelles) et feux tricolores. Tout ce qui est solide est déclaré à la foule.
## Le plan vient de `Quartier` ; `build` construit tout et l'ajoute au monde.

const DIR := "res://assets/quartier/"
const CORRIDOR := 4.0           # demi-largeur laissée libre autour du parcours du cortège
const CURB_W := 0.22            # largeur de la bordure de granit
const GUTTER_W := 0.4           # caniveau pavé côté chaussée
const ROAD_TOP := 0.02          # dessus de la chaussée du boulevard (abribus)
const TREE_STEP := 9.0

var crowd: Crowd
var trees: Array[Node3D] = []
var placed := {}                 # type d'objet -> nombre (pour les tests)
var traffic: Array = []          # feux (TrafficLight)
var crossings: Array[float] = [] # abscisses des passages piétons du boulevard (après recalage)
var _taken: Array = []           # [Vector2, rayon] : emplacements déjà occupés
var _route: PackedVector2Array = PackedVector2Array()
var _lowered: Array[Rect2] = []  # bateaux : bordure abaissée
var _rng := RandomNumberGenerator.new()
static var _mats := {}


## Construit tout le quartier sous `world` (une seule ligne dans main.gd)
static func build(world: Node3D, crowd_ref: Crowd) -> Streetscape:
	var s := Streetscape.new()
	s.name = "Streetscape"
	s.crowd = crowd_ref
	world.add_child(s)
	s._build_all()
	return s


# ------------------------------------------------------------------ matériaux partagés
static func tex(f: String) -> Texture2D:
	return ParisBuilding.mip_tex(DIR + f, f.ends_with("_n.png"))


static func tmat(key: String, albedo: String, normal := "", uv_scale := Vector3.ONE, rough := 0.8, tint := Color(1, 1, 1), triplanar := false) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex(albedo)
		m.albedo_color = tint
		if normal != "":
			m.normal_enabled = true
			m.normal_texture = tex(normal)
		m.uv1_scale = uv_scale
		m.uv1_triplanar = triplanar
		m.roughness = rough
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_mats[key] = m
	return _mats[key]


## Matériau du sol (baseplate) : zones de trottoir, pavés, chaussées des rues adjacentes, stabilisé, trémie du métro
static func ground_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/baseplate.gdshader")
	for k in ["trottoir", "paves"]:
		m.set_shader_parameter(k + "_a", tex(k + "_a.png"))
		m.set_shader_parameter(k + "_n", tex(k + "_n.png"))
	m.set_shader_parameter("route_a", tex("paves_route_a.png"))
	m.set_shader_parameter("route_n", tex("paves_route_n.png"))
	m.set_shader_parameter("stab_a", tex("stabilise_a.png"))
	m.set_shader_parameter("stab_n", tex("stabilise_n.png"))
	var roads := [side_road(Quartier.SIDE_NORTH, true), side_road(Quartier.SIDE_SOUTH, false)]
	m.set_shader_parameter("roads", roads.map(func(r): return _rect4(r)))
	m.set_shader_parameter("road_count", roads.size())
	# pavés : abords du métro, parvis du kiosque, entrée du square
	var paved := [Rect2(Quartier.METRO.x - 4.0, 9.6, 8.0, 7.6), Rect2(Quartier.KIOSK.x - 3.2, 10.6, 6.4, 5.4), Rect2(Quartier.SQUARE.position.x - 2.6, 12.6, 2.6, 2.8),
		Rect2(Quartier.BLVD_END - 9.0, Quartier.MAIRIE_Z0 + 2.0, 9.0, Quartier.NORTH_Z - Quartier.MAIRIE_Z0 - 2.0)]   # parvis de la mairie
	m.set_shader_parameter("paved", paved.map(func(r): return _rect4(r)))
	m.set_shader_parameter("paved_count", paved.size())
	m.set_shader_parameter("stab", [_rect4(Quartier.SQUARE)])
	m.set_shader_parameter("stab_count", 1)
	m.set_shader_parameter("hole", _rect4(Landmarks.metro_hole()))
	m.set_shader_parameter("facades", Vector2(Quartier.SOUTH_Z, Quartier.NORTH_Z))
	return m


static func _rect4(r: Rect2) -> Vector4:
	return Vector4(r.position.x, r.position.y, r.end.x, r.end.y)


## Chaussée d'une rue adjacente (rectangle x/z), raccordée à celle du boulevard
static func side_road(sr: Array, north: bool) -> Rect2:
	var mid := (float(sr[0]) + float(sr[1])) * 0.5
	var h := Quartier.SIDE_ROAD_W * 0.5
	if north:
		return Rect2(mid - h, Quartier.ROAD_Z1, Quartier.SIDE_ROAD_W, float(sr[2]) - Quartier.ROAD_Z1)
	return Rect2(mid - h, float(sr[2]), Quartier.SIDE_ROAD_W, Quartier.ROAD_Z0 - float(sr[2]))


## Abscisses des passages piétons du boulevard : un passage qui tomberait dans l'embouchure d'une rue adjacente
## est décalé juste à côté (on ne traverse pas pour arriver sur une chaussée).
static func crosswalk_xs() -> Array[float]:
	var out: Array[float] = []
	var nr := side_road(Quartier.SIDE_NORTH, true)
	var sr := side_road(Quartier.SIDE_SOUTH, false)
	for c in Quartier.CROSSWALKS:
		var x := float(c)
		for r in [nr, sr]:
			if x + 2.6 > (r as Rect2).position.x and x - 2.6 < (r as Rect2).end.x:
				x = (r as Rect2).position.x - 4.6
		out.append(x)
	return out


# ------------------------------------------------------------------ construction
func _build_all() -> void:
	_rng.seed = 75011
	crossings = crosswalk_xs()
	_sample_route()
	_reserve_existing()
	_reserve_story()
	_build_lowered()
	_build_curbs()
	_build_markings()
	_build_covers()
	_build_landmarks()
	ParisSquare.build(self, crowd)
	_build_trees()
	_build_traffic_lights()
	_build_bollards()
	_build_furniture()
	MapStory.build_boards(self, crowd, find_spot)
	_build_night_lights()


## Lieux de l'histoire : on n'y pose pas de mobilier (terrasse du Zinc, étal de la supérette, chaque lieu nommé)
func _reserve_story() -> void:
	take(Vector2(-10.8, 17.4), 5.2)
	take(Vector2(40.0, -24.4), 3.0)
	for id: String in Quartier.SPOTS:
		var p: Vector3 = Quartier.SPOTS[id]
		if p.z < Quartier.ROAD_Z0 or p.z > Quartier.ROAD_Z1:
			take(Vector2(p.x, p.z), 1.2)


## Éclairage public de nuit : deux alignements en quinconce le long des bordures du boulevard et des deux côtés
## des rues adjacentes (en plus des lampadaires existants : on ne double pas un lampadaire à moins de 9 m).
## Lumières sans ombre, estompées au loin (coût limité).
func _build_night_lights() -> void:
	var have: Array[Vector2] = []
	for n in get_parent().get_children() + get_children():
		if n is LampPost:
			have.append(Vector2((n as Node3D).position.x, (n as Node3D).position.z))
	var want: Array = []
	var x := -96.0
	while x <= 96.0:
		want.append([Vector2(x, Quartier.ROAD_Z1 + 0.6), PI])
		want.append([Vector2(x + 11.0, Quartier.ROAD_Z0 - 0.6), 0.0])
		x += 22.0
	var nr := side_road(Quartier.SIDE_NORTH, true)
	var sr := side_road(Quartier.SIDE_SOUTH, false)
	for z in [27.0, 43.0, 59.0, 71.0]:
		want.append([Vector2(nr.position.x - 0.6, z), PI * 0.5])
		want.append([Vector2(nr.end.x + 0.6, z + 8.0), -PI * 0.5])
	for z in [-33.0, -49.0, -65.0, -77.0]:
		want.append([Vector2(sr.position.x - 0.6, z - 8.0), PI * 0.5])
		want.append([Vector2(sr.end.x + 0.6, z), -PI * 0.5])
	for lp in want:
		var p0: Vector2 = lp[0]
		var near := false
		for h in have:
			if h.distance_to(p0) < 9.0:
				near = true
				break
		if near:
			continue
		var sp: Variant = find_spot(p0, 0.3, true)
		if sp == null:
			continue
		var p: Vector2 = sp
		var lamp := LampPost.new()
		lamp.crowd = crowd
		lamp.position = Vector3(p.x, 0, p.y)
		lamp.rotation.y = lp[1]
		add_child(lamp)
		var l: OmniLight3D = lamp._light
		l.distance_fade_enabled = true
		l.distance_fade_begin = 55.0
		l.distance_fade_length = 20.0
		take(p, 0.4)
		have.append(p)
		count("lampadaire")


func count(kind: String, n := 1) -> void:
	placed[kind] = int(placed.get(kind, 0)) + n


## Parcours du cortège (pour le laisser libre)
func _sample_route() -> void:
	if crowd == null or crowd._route_total <= 1.0:
		return
	var s := 0.0
	while s < crowd._route_total:
		var p: Vector3 = crowd.route_at(s)[0]
		_route.append(Vector2(p.x, p.z))
		s += 0.8


func route_dist(p: Vector2) -> float:
	var best := INF
	for q in _route:
		best = minf(best, q.distance_squared_to(p))
	return sqrt(best)


## Emplacements déjà pris par le mobilier existant (Furniture, main.gd, abribus) et les repères du plan
func _reserve_existing() -> void:
	var pts := [
		[Vector2(9.5, -3.1), 1.1], [Vector2(11.5, -3.1), 1.1], [Vector2(-9.0, -4.2), 1.1],
		[Vector2(3.8, -3.3), 0.4], [Vector2(-5.2, -2.6), 0.4], [Vector2(22.5, -3.3), 0.4], [Vector2(-17.0, -3.3), 0.4],
		[Vector2(36.0, -11.5), 0.4], [Vector2(-8.6, -14.6), 0.5], [Vector2(8.8, -14.4), 0.5],
		[Vector2(2.55, -12.45), 0.4], [Vector2(13.0, -3.1), 0.4], [Vector2(-18.0, -3.1), 0.4],
		[Vector2(-7.4, -11.9), 0.4], [Vector2(7.6, -11.9), 0.4], [Vector2(-13.0, -12.3), 0.4], [Vector2(13.5, -12.1), 0.4],
		[Vector2(1.3, -3.0), 0.4], [Vector2(-20.0, -3.2), 0.4], [Vector2(15.0, -3.2), 0.4], [Vector2(31.0, -3.2), 0.4],
		[Vector2(-12.2, -12.8), 0.9], [Vector2(3.4, -2.3), 0.6], [Vector2(-7.2, -12.5), 0.6],
		[Vector2(5.6, -0.6), 1.0], [Vector2(-9.0, -13.4), 1.0], [Vector2(-3.0, 3.5), 0.8], [Vector2(10.5, -4.0), 0.8],
		[Vector2(0.0, -12.9), 3.0], [Vector2(-4.8, -11.3), 0.4], [Vector2(3.55, -13.3), 0.7],
		[Vector2(0.0, 0.0), 1.5],     # apparition du joueur
		[Vector2(-4.6, -1.4), 1.6], [Vector2(7.6, 2.6), 1.6], [Vector2(-9.0, 4.0), 1.6],   # groupes qui discutent
	]
	for p in pts:
		_taken.append(p)


func take(p: Vector2, r: float) -> void:
	_taken.append([p, r])


## L'emplacement est-il libre pour un objet solide de rayon r ?
func is_free(p: Vector2, r: float, allow_route := false) -> bool:
	if p.y > Quartier.ROAD_Z0 - 0.25 and p.y < Quartier.ROAD_Z1 + 0.25:
		return false
	for sr in [side_road(Quartier.SIDE_NORTH, true), side_road(Quartier.SIDE_SOUTH, false)]:
		if (sr as Rect2).grow(0.3).has_point(p):
			return false
	var zl := Quartier.z_limits(p.x)
	if p.y < zl.x + r or p.y > zl.y - r:
		return false
	if absf(p.x) > Quartier.BLVD_END - 1.0:
		return false
	if p.x > 37.0 and p.x < 61.0 and p.y > -14.5 and p.y < -0.8:
		return false                 # barrage de police
	var v := Vector3(p.x, 0, p.y)
	for rr in [Quartier.PARKING, Quartier.VELIB]:
		if (rr as Rect2).grow(0.6 + r).has_point(p):
			return false
	if Quartier.SQUARE.grow(0.3).has_point(p):
		return false
	for c in crossings:
		if absf(p.x - c) < 3.0 + r and p.y > -12.2 and p.y < -2.6:
			return false
	if not allow_route and route_dist(p) < CORRIDOR + r:
		return false
	for t in _taken:
		if (t[0] as Vector2).distance_to(p) < float(t[1]) + r:
			return false
	return true


## Cherche une place libre près de `p` (petits décalages, d'abord le long de la rue). Renvoie null si aucune.
func find_spot(p: Vector2, r: float, allow_route := false) -> Variant:
	for d in [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(2, 0), Vector2(-2, 0), Vector2(0, 0.6), Vector2(0, -0.6),
			Vector2(3, 0), Vector2(-3, 0), Vector2(4, 0), Vector2(-4, 0)]:
		if is_free(p + d, r, allow_route):
			return p + d
	return null


# ------------------------------------------------------------------ bordures et caniveaux
func _build_lowered() -> void:
	for c in crossings:
		_lowered.append(Rect2(c - 2.3, -11.6, 4.6, 8.4))
	# le cortège descend et remonte du trottoir nord : bordure abaissée (bateau) à ses deux passages
	_lowered.append(Rect2(31.0, -4.6, 8.0, 1.4))
	_lowered.append(Rect2(-39.0, -4.6, 8.0, 1.4))
	var nr := side_road(Quartier.SIDE_NORTH, true)
	var sr := side_road(Quartier.SIDE_SOUTH, false)
	_lowered.append(Rect2(nr.position.x - 0.6, -0.3, Quartier.SIDE_ROAD_W + 1.2, 4.6))
	_lowered.append(Rect2(sr.position.x - 0.6, -16.8, Quartier.SIDE_ROAD_W + 1.2, 4.6))


func _low_k(p: Vector2) -> float:
	var k := 0.0
	for r in _lowered:
		var dx := maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0)
		var dz := maxf(maxf(r.position.y - p.y, p.y - r.end.y), 0.0)
		k = maxf(k, clampf(1.0 - sqrt(dx * dx + dz * dz) / 0.7, 0.0, 1.0))
	return k


## Chemin d'une bordure : segments droits subdivisés et arcs de coin
static func _seg(out: PackedVector2Array, a: Vector2, b: Vector2, step := 0.5) -> void:
	var n := maxi(1, int(a.distance_to(b) / step))
	for i in n:
		out.append(a.lerp(b, float(i) / n))


static func _arc(out: PackedVector2Array, c: Vector2, r: float, a0: float, a1: float, steps := 8) -> void:
	for i in steps:
		var a := deg_to_rad(lerpf(a0, a1, float(i) / steps))
		out.append(c + Vector2(cos(a), sin(a)) * r)


func _build_curbs() -> void:
	var curb_m := tmat("bordure", "bordure_a.png", "bordure_n.png", Vector3.ONE, 0.7)
	var gut_m := tmat("caniveau", "paves_route_a.png", "paves_route_n.png", Vector3.ONE, 0.55, Color(0.72, 0.72, 0.74))
	var b := MeshBatch.new()
	var nr := side_road(Quartier.SIDE_NORTH, true)
	var sr := side_road(Quartier.SIDE_SOUTH, false)
	var R := 1.6
	var E := Quartier.BLVD_END
	var z1 := Quartier.ROAD_Z1
	var z0 := Quartier.ROAD_Z0
	# nord, à l'ouest de la rue adjacente (la chaussée est à gauche du sens de parcours)
	var p := PackedVector2Array()
	_seg(p, Vector2(-E, z1), Vector2(nr.position.x - R, z1))
	_arc(p, Vector2(nr.position.x - R, z1 + R), R, -90.0, 0.0)
	_seg(p, Vector2(nr.position.x, z1 + R), Vector2(nr.position.x, nr.end.y))
	p.append(Vector2(nr.position.x, nr.end.y))
	_extrude_curb(b, curb_m, gut_m, p, -1.0)
	p = PackedVector2Array()
	_seg(p, Vector2(nr.end.x, nr.end.y), Vector2(nr.end.x, z1 + R))
	_arc(p, Vector2(nr.end.x + R, z1 + R), R, 180.0, 270.0)
	_seg(p, Vector2(nr.end.x + R, z1), Vector2(E, z1))
	p.append(Vector2(E, z1))
	_extrude_curb(b, curb_m, gut_m, p, -1.0)
	# sud (la chaussée est à droite)
	p = PackedVector2Array()
	_seg(p, Vector2(-E, z0), Vector2(sr.position.x - R, z0))
	_arc(p, Vector2(sr.position.x - R, z0 - R), R, 90.0, 0.0)
	_seg(p, Vector2(sr.position.x, z0 - R), Vector2(sr.position.x, sr.position.y))
	p.append(Vector2(sr.position.x, sr.position.y))
	_extrude_curb(b, curb_m, gut_m, p, 1.0)
	p = PackedVector2Array()
	_seg(p, Vector2(sr.end.x, sr.position.y), Vector2(sr.end.x, z0 - R))
	_arc(p, Vector2(sr.end.x + R, z0 - R), R, 180.0, 90.0)
	_seg(p, Vector2(sr.end.x + R, z0), Vector2(E, z0))
	p.append(Vector2(E, z0))
	_extrude_curb(b, curb_m, gut_m, p, 1.0)
	b.commit(self, false, 0.0, "Bordures")
	_build_inlets()


## Extrude le profil de la bordure (face, chanfrein, dessus, dos) et le caniveau le long du chemin.
## road_side : +1 si la chaussée est à droite du sens de parcours, -1 si à gauche.
func _extrude_curb(b: MeshBatch, curb_m: Material, gut_m: Material, pts: PackedVector2Array, road_side: float) -> void:
	var n := pts.size()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var gv := PackedVector3Array()
	var gn := PackedVector3Array()
	var gu := PackedVector2Array()
	var gi := PackedInt32Array()
	var s := 0.0
	var NP := 10     # sommets par section (5 facettes à arêtes vives)
	for i in n:
		var a := pts[i]
		var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nr := Vector2(-t.y, t.x) * road_side          # vers la chaussée
		if i > 0:
			s += pts[i].distance_to(pts[i - 1])
		var on_blvd := absf(a.y - Quartier.ROAD_Z1) < 0.3 or absf(a.y - Quartier.ROAD_Z0) < 0.3
		var y_road := ROAD_TOP if on_blvd else 0.0
		var w := CURB_W
		var h := Quartier.CURB_H
		# quai de l'abribus : la bordure englobe celle de l'abribus (plus haute, plus large)
		if road_side > 0.0 and absf(a.y - Quartier.ROAD_Z0) < 0.05 and absf(a.x) < 30.15:
			w = 0.37
			h = 0.158
		else:
			h = lerpf(h, 0.035, _low_k(a))
		var N := Vector3(nr.x, 0, nr.y)
		var P := Vector3(a.x, 0, a.y)
		var prof := [[0.0, 0.0], [0.0, h - 0.018], [-0.018, h], [-w + 0.012, h], [-w, h - 0.012], [-w, 0.0]]
		var fn := [N, (N + Vector3.UP).normalized(), Vector3.UP, (Vector3.UP - N).normalized(), -N]
		var vcum := 0.0
		for f in 5:
			var p0: Array = prof[f]
			var p1: Array = prof[f + 1]
			var v0 := vcum
			vcum += Vector2(p1[0] - p0[0], p1[1] - p0[1]).length()
			for e in [p0, p1]:
				verts.append(P + N * float(e[0]) + Vector3.UP * float(e[1]))
				norms.append(fn[f])
			uvs.append(Vector2(s / 4.0, v0 / 0.5))
			uvs.append(Vector2(s / 4.0, vcum / 0.5))
		# caniveau : bande pavée côté chaussée
		var gy := y_road + 0.006
		gv.append(P + N * 0.002 + Vector3.UP * gy)
		gv.append(P + N * GUTTER_W + Vector3.UP * gy)
		gn.append(Vector3.UP)
		gn.append(Vector3.UP)
		gu.append(Vector2(s * 0.5, 0.0))
		gu.append(Vector2(s * 0.5, GUTTER_W * 0.5))
		if i > 0:
			var b0 := (i - 1) * NP
			var b1 := i * NP
			for f in 5:
				var a0 := b0 + f * 2
				var a1 := b1 + f * 2
				_quad_idx(idx, verts, a0, a0 + 1, a1, a1 + 1, fn[f])
			_quad_idx(gi, gv, (i - 1) * 2, (i - 1) * 2 + 1, i * 2, i * 2 + 1, Vector3.UP)
	b.arrays("curb", curb_m, verts, norms, uvs, idx, true)
	b.arrays("gutter", gut_m, gv, gn, gu, gi, true)


## Deux triangles (a0, a1 sur une section ; b0, b1 sur la suivante), face avant selon n
static func _quad_idx(idx: PackedInt32Array, v: PackedVector3Array, a0: int, a1: int, b0: int, b1: int, n: Vector3) -> void:
	for tri in [[a0, b0, a1], [a1, b0, b1]]:
		var cr := (v[tri[1]] - v[tri[0]]).cross(v[tri[2]] - v[tri[0]])
		if cr.dot(n) > 0.0:
			idx.append_array([tri[0], tri[2], tri[1]])
		else:
			idx.append_array([tri[0], tri[1], tri[2]])


## Avaloirs : grille dans le caniveau et bouche dans la face de la bordure, tous les ~24 m
func _build_inlets() -> void:
	var b := MeshBatch.new()
	var grate := _fonte_mat()
	var dark := Furniture.mat("avaloir_trou", Color(0.015, 0.015, 0.017), 0.95)
	for side in [1.0, -1.0]:
		var z := Quartier.ROAD_Z1 if side > 0.0 else Quartier.ROAD_Z0
		var nz: float = -side                                    # vers la chaussée
		var x := -96.0 + (0.0 if side > 0.0 else 12.0)
		while x < 100.0:
			var p := Vector2(x, z)
			var skip: bool = _low_k(p) > 0.0 or (side < 0.0 and absf(x) < 31.0)
			for r in [side_road(Quartier.SIDE_NORTH, true), side_road(Quartier.SIDE_SOUTH, false)]:
				if absf(x - (r as Rect2).get_center().x) < 6.0:
					skip = true
			if not skip:
				b.ground_quad("grate", grate, Vector3(x, ROAD_TOP + 0.009, z + nz * 0.2), Vector2(0.9, 0.36), 0.0, Rect2(0.03, 0.56, 0.44, 0.38))
				b.box("dark", dark, Vector3(1.0, 0.06, 0.02), Vector3(x, ROAD_TOP + 0.045, z + nz * 0.004))
				count("avaloir")
			x += 24.0
	b.commit(self, false, 120.0, "Avaloirs")


static func _fonte_mat() -> StandardMaterial3D:
	if not _mats.has("fonte"):
		var m := tmat("fonte", "fontes_a.png", "fontes_n.png", Vector3.ONE, 0.45)
		m.metallic = 0.55
		m.normal_scale = 1.4
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	return _mats["fonte"]


# ------------------------------------------------------------------ marquages au sol
func _build_markings() -> void:
	var paint := ShaderMaterial.new()
	paint.shader = load("res://shaders/marquage.gdshader")
	var b := MeshBatch.new()
	var y := ROAD_TOP + 0.009
	for c in crossings:
		# bandes parallèles à l'axe de la chaussée, 0,5 m de large, tous les mètres
		for i in 6:
			b.ground_quad("paint", paint, Vector3(c, y, Quartier.ROAD_Z + (i - 2.5)), Vector2(4.0, 0.5))
		# lignes d'arrêt des feux (chaque sens, en amont du passage)
		b.ground_quad("paint", paint, Vector3(c + 3.45, y, -9.0), Vector2(0.5, 3.0))
		b.ground_quad("paint", paint, Vector3(c - 3.45, y, -5.8), Vector2(0.5, 3.0))
		count("passage")
	# entrées des rues adjacentes : passages en travers de leur chaussée
	var nr := side_road(Quartier.SIDE_NORTH, true)
	var sr := side_road(Quartier.SIDE_SOUTH, false)
	for r in [[nr, 2.0, 1.0], [sr, -14.5, -1.0]]:
		var rc: Rect2 = r[0]
		var cz: float = r[1]
		for i in 5:
			b.ground_quad("paint", paint, Vector3(rc.get_center().x + (i - 2), 0.007, cz), Vector2(0.5, 4.0))
		# ligne d'arrêt (cédez le passage : pointillés) côté boulevard
		for i in 5:
			b.ground_quad("paint", paint, Vector3(rc.get_center().x - 1.5 + (i - 2) * 0.55, 0.007, cz + float(r[2]) * -3.0), Vector2(0.3, 0.5))
		count("passage")
	b.commit(self, false, 0.0, "Marquages")
	# bandes podotactiles au droit des passages
	var podo := tmat("podo", "podo_a.png", "podo_n.png", Vector3.ONE, 0.7)
	var pb := MeshBatch.new()
	for c in crossings:
		pb.ground_quad("podo", podo, Vector3(c, 0.006, Quartier.ROAD_Z1 + CURB_W + 0.22), Vector2(4.0, 0.4), 0.0, Rect2(0, 0, 10, 1), true)
		pb.ground_quad("podo", podo, Vector3(c, 0.006, Quartier.ROAD_Z0 - (0.4 if absf(c) < 30.2 else CURB_W) - 0.22), Vector2(4.0, 0.4), 0.0, Rect2(0, 0, 10, 1), true)
	for r in [[nr, 2.0], [sr, -14.5]]:
		var rc: Rect2 = r[0]
		for x in [rc.position.x - CURB_W - 0.22, rc.end.x + CURB_W + 0.22]:
			pb.ground_quad("podo", podo, Vector3(x, 0.006, r[1]), Vector2(0.4, 4.0), 0.0, Rect2(0, 0, 1, 10), true)
	pb.commit(self, false, 80.0, "Podotactile")


# ------------------------------------------------------------------ plaques d'égout, regards
func _build_covers() -> void:
	var b := MeshBatch.new()
	var m := _fonte_mat()
	var rounds := [Vector2(-14, 0.8), Vector2(6.5, 9.5), Vector2(24, 2.0), Vector2(-30, 8.6), Vector2(45, 12), Vector2(-70, 5),
		Vector2(70, 3), Vector2(90, 10), Vector2(-5.5, -17.5), Vector2(16, -20), Vector2(-45, -20), Vector2(50, -18),
		Vector2(75, -15), Vector2(-50, 25), Vector2(-50, 50), Vector2(-77, -35), Vector2(-77, -60),
		Vector2(-40, -6.0), Vector2(12, -8.8), Vector2(65, -6.2), Vector2(-84, -8.5), Vector2(26, -6.1)]
	for p in rounds:
		var on_road: bool = p.y > Quartier.ROAD_Z0 and p.y < Quartier.ROAD_Z1
		b.ground_quad("cover", m, Vector3(p.x, (ROAD_TOP + 0.008) if on_road else 0.006, p.y), Vector2(0.72, 0.72), _rng.randf() * TAU, Rect2(0, 0, 0.5, 0.5))
		count("egout")
	var squares := [Vector2(-2, 16.5), Vector2(33, -16), Vector2(-60, -20), Vector2(60, 16), Vector2(8, -24), Vector2(-20, 2.5),
		Vector2(-90, 14), Vector2(95, -22), Vector2(-48.5, 12)]
	for p in squares:
		var s := _rng.randf_range(0.45, 0.62)
		b.ground_quad("cover", m, Vector3(p.x, 0.006, p.y), Vector2(s, s), float(_rng.randi() % 4) * PI * 0.5 + 0.02, Rect2(0.5, 0.5, 0.5, 0.5))
		count("regard")
	b.commit(self, false, 90.0, "Plaques")


# ------------------------------------------------------------------ repères du plan
func _build_landmarks() -> void:
	add_child(Landmarks.metro(crowd))
	take(Vector2(Quartier.METRO.x, Quartier.METRO.z), 3.0)
	add_child(Landmarks.morris(crowd))
	take(Vector2(Quartier.MORRIS.x, Quartier.MORRIS.z), 1.4)
	add_child(Landmarks.kiosk(crowd))
	take(Vector2(Quartier.KIOSK.x, Quartier.KIOSK.z), 2.2)
	add_child(Landmarks.wallace(crowd))
	take(Vector2(Quartier.WALLACE.x, Quartier.WALLACE.z), 1.3)
	count("repere", 4)


# ------------------------------------------------------------------ platanes
func _build_trees() -> void:
	var grate := _fonte_mat()
	var gb := MeshBatch.new()
	for zi in Quartier.TREE_ROWS.size():
		var z: float = Quartier.TREE_ROWS[zi]
		var x := -99.0 + zi * 4.5
		while x <= 99.0:
			var ok := true
			for sk in Quartier.TREE_SKIP:
				if x > (sk as Vector2).x - 1.0 and x < (sk as Vector2).y + 1.0:
					ok = false
			if ok:
				# léger recalage si l'emplacement est encombré (alignement presque régulier)
				var found := false
				for dx in [0.0, 0.8, -0.8, 1.6, -1.6]:
					var p := Vector2(x + dx, z)
					if is_free(p, 1.2):
						_plant(p, gb, grate)
						found = true
						break
			x += TREE_STEP
	gb.commit(self, false, 0.0, "GrillesArbres")


func _plant(p: Vector2, gb: MeshBatch, grate: Material) -> void:
	var s := _rng.randf_range(1.12, 1.4)
	var tint := Color(_rng.randf_range(0.9, 1.08), _rng.randf_range(0.92, 1.06), _rng.randf_range(0.85, 1.0))
	var in_area := p.x > Crowd.AREA_MIN.x - 3.0 and p.x < Crowd.AREA_MAX.x + 3.0
	var t := PlaneTree.plant(self, Vector3(p.x, 0, p.y), _rng, s, tint, crowd if in_area else null)
	trees.append(t)
	take(p, 0.9)
	gb.ground_quad("grate", grate, Vector3(p.x, 0.007, p.y), Vector2(1.5, 1.5), float(_rng.randi() % 4) * PI * 0.5, Rect2(0.5, 0.0, 0.5, 0.5))
	count("arbre")


# ------------------------------------------------------------------ feux tricolores
func _build_traffic_lights() -> void:
	var ctrl := TrafficLight.Controller.new()
	ctrl.name = "Feux"
	add_child(ctrl)
	for i in crossings.size():
		var c: float = crossings[i]
		var off := i * 13.0
		# côté sud, en amont pour le sens -X : tête véhicules vers +X, bonhomme vers le nord
		var a := TrafficLight.new()
		a.position = Vector3(c + 2.8, 0, Quartier.ROAD_Z0 - (0.62 if absf(c) < 30.2 else 0.45))
		a.car_yaw = PI * 0.5
		a.ped_yaw = 0.0
		a.phase = off
		ctrl.add(a)
		var b := TrafficLight.new()
		b.position = Vector3(c - 2.8, 0, Quartier.ROAD_Z1 + 0.45)
		b.car_yaw = -PI * 0.5
		b.ped_yaw = PI
		b.phase = off
		ctrl.add(b)
		for l in [a, b]:
			take(Vector2(l.position.x, l.position.z), 0.4)
			if crowd != null:
				crowd.add_obstacle(l, Vector2(0.12, 0.0), Vector2.ZERO, true, false)
			traffic.append(l)
			count("feu")


# ------------------------------------------------------------------ potelets
func _build_bollards() -> void:
	var pts: Array[Vector2] = []
	var zn := Quartier.ROAD_Z1 + 0.5
	var zs := Quartier.ROAD_Z0 - 0.5
	# de part et d'autre des passages piétons
	for c in crossings:
		for d in [2.7, 3.9]:
			pts.append(Vector2(c - d, zn))
			pts.append(Vector2(c + d, zn))
			pts.append(Vector2(c - d, zs))
			pts.append(Vector2(c + d, zs))
	# le long des places de stationnement (on ne se gare pas sur le trottoir)
	for lane in Quartier.PARK_LANES:
		var z: float = zn if float(lane[2]) > Quartier.ROAD_Z else zs
		var x: float = float(lane[0]) + 1.0
		while x < float(lane[1]):
			pts.append(Vector2(x, z))
			x += 2.2
	# rues adjacentes : alignements serrés le long des bordures
	var nr := side_road(Quartier.SIDE_NORTH, true)
	var sr := side_road(Quartier.SIDE_SOUTH, false)
	for x in [nr.position.x - 0.45, nr.end.x + 0.45]:
		var z := Quartier.NORTH_Z + 1.0
		while z < Quartier.NORTH_Z + 26.0:
			pts.append(Vector2(x, z))
			z += 1.6
	for x in [sr.position.x - 0.45, sr.end.x + 0.45]:
		var z := Quartier.SOUTH_Z - 1.0
		while z > Quartier.SOUTH_Z - 28.0:
			pts.append(Vector2(x, z))
			z -= 1.6
	var mesh := MeshKit.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.06, 0), Vector2(0.06, 0.03), Vector2(0.045, 0.06),
		Vector2(0.045, 0.82), Vector2(0.055, 0.84), Vector2(0.055, 0.87), Vector2(0.045, 0.89), Vector2(0.05, 0.93),
		Vector2(0.035, 0.99), Vector2(0.0, 1.0)]), 12)
	var m := Furniture.mat("potelet", Color(0.19, 0.13, 0.09), 0.42, 0.55)
	var keep: Array[Vector2] = []
	for p in pts:
		# pas de potelet sur le parcours du cortège ni au barrage de police
		if p.x > 37.0 and p.x < 61.0 and p.y > -14.5 and p.y < -0.8:
			continue
		if route_dist(p) < CORRIDOR:
			continue
		if _low_k(p) > 0.0 and absf(p.y - zn) < 0.1 and p.x > 30.0 and p.x < 40.0:
			continue
		var blocked := false
		for t in _taken:
			if (t[0] as Vector2).distance_to(p) < float(t[1]) + 0.1:
				blocked = true
		if not blocked:
			keep.append(p)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = keep.size()
	var body := StaticBody3D.new()
	body.name = "Potelets"
	add_child(body)
	for i in keep.size():
		var p := keep[i]
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3(p.x, 0, p.y)))
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 0.06
		cy.height = 1.0
		cs.shape = cy
		cs.position = Vector3(p.x, 0.5, p.y)
		body.add_child(cs)
		if crowd != null and p.x > Crowd.AREA_MIN.x - 2.0 and p.x < Crowd.AREA_MAX.x + 2.0:
			var mk := Marker3D.new()
			body.add_child(mk)
			mk.position = Vector3(p.x, 0, p.y)
			crowd.add_obstacle(mk, Vector2(0.08, 0.0), Vector2.ZERO, true, false)
		take(p, 0.15)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mmi)
	count("potelet", keep.size())


# ------------------------------------------------------------------ mobilier
func _build_furniture() -> void:
	# bancs (doubles « Davioud » le long de la promenade, simples côté sud)
	for bp in [[Vector2(-23.5, -1.2), 0.0, true], [Vector2(21.0, -1.2), 0.0, true], [Vector2(-60.0, 1.0), 0.0, true],
			[Vector2(66.0, 1.2), 0.0, true], [Vector2(-25.0, -13.1), PI, false], [Vector2(24.0, -13.1), PI, false],
			[Vector2(9.3, -18.6), -PI * 0.5, false], [Vector2(-64.0, -13.2), PI, false], [Vector2(80.0, -13.2), PI, false],
			[Vector2(2.0, 17.6), PI, false], [Vector2(6.5, 17.6), PI, false]]:
		var sp: Variant = find_spot(bp[0], 0.9)
		if sp != null:
			var p: Vector2 = sp
			add_child(Landmarks.bench(Vector3(p.x, 0, p.y), bp[1], bp[2], crowd))
			take(p, 1.0)
			count("banc")
	# corbeilles « Vigipirate » (sac transparent sur cerceau vert) : renversables
	for p in [Vector2(-26.5, -3.3), Vector2(25.0, -3.3), Vector2(-22.0, -11.6), Vector2(18.5, -11.6), Vector2(17.6, 10.0),
			Vector2(-13.3, 12.0), Vector2(-60.0, -3.4), Vector2(64.0, -3.4), Vector2(-46.4, 22.0), Vector2(-71.6, -30.0),
			Vector2(30.2, 11.6), Vector2(-3.5, 15.4), Vector2(2.0, -21.5)]:
		var sp: Variant = find_spot(p, 0.35)
		if sp != null:
			_prop(BagBin.new(), sp, _rng.randf() * TAU)
			count("corbeille")
	# poubelles à roulettes au pied des immeubles (couvercles : vert ordures, jaune tri, blanc verre)
	for tb in [[Vector2(-37.0, 18.1), Color(0.11, 0.25, 0.16)], [Vector2(36.6, -25.0), Color(0.85, 0.68, 0.08)],
			[Vector2(-35.4, -25.1), Color(0.88, 0.88, 0.85)], [Vector2(-45.2, 30.0), Color(0.11, 0.25, 0.16)],
			[Vector2(-44.6, 30.8), Color(0.85, 0.68, 0.08)]]:
		var sp: Variant = find_spot(tb[0], 0.45, true)
		if sp != null:
			var p: Vector2 = sp
			var bin := TrashBin.new()
			bin.body_color = Color(0.11, 0.25, 0.16)
			bin.lid_color = tb[1]
			bin.position = Vector3(p.x, 0, p.y)
			bin.rotation.y = (PI if p.y > 0.0 else 0.0) + _rng.randf_range(-0.25, 0.25)
			add_child(bin)
			take(p, 0.5)
			count("poubelle")
	# arceaux à vélos (groupes)
	for g in [[Vector2(21.5, 16.6), 5, 0.0], [Vector2(-66.0, -21.0), 4, 0.0], [Vector2(70.0, 15.5), 4, 0.0]]:
		var sp: Variant = find_spot(g[0], 0.6 * g[1] * 0.5 + 0.4, true)
		if sp != null:
			var p: Vector2 = sp
			add_child(Landmarks.bike_racks(Vector3(p.x, 0, p.y), g[1], g[2], crowd))
			take(p, 0.45 * g[1] + 0.3)
			count("arceaux", g[1])
	# jardinières (bacs plantés)
	for j in [[Vector2(3.0, 12.8), 0.0], [Vector2(9.0, 12.6), 0.0], [Vector2(-10.5, 11.2), 0.0], [Vector2(36.0, 15.6), PI * 0.5],
			[Vector2(-40.0, 15.0), PI * 0.5], [Vector2(-30.0, -16.0), 0.0]]:
		var sp: Variant = find_spot(j[0], 1.0, true)
		if sp != null:
			var p: Vector2 = sp
			add_child(Landmarks.planter_box(Vector3(p.x, 0, p.y), j[1], _rng.randi(), crowd))
			take(p, 1.1)
			count("jardiniere")
	# panneaux : passage piéton, sens unique, zone 30
	var nr := side_road(Quartier.SIDE_NORTH, true)
	var sr := side_road(Quartier.SIDE_SOUTH, false)
	var signs := [[Vector2(crossings[1] - 4.6, Quartier.ROAD_Z1 + 0.5), "crossing", PI], [Vector2(crossings[1] + 4.6, Quartier.ROAD_Z0 - 0.62), "crossing", 0.0],
		[Vector2(crossings[0] + 4.6, Quartier.ROAD_Z1 + 0.5), "crossing", PI], [Vector2(crossings[2] - 4.8, Quartier.ROAD_Z1 + 0.5), "crossing", PI],
		[Vector2(nr.position.x - 0.5, Quartier.NORTH_Z + 1.2), "one_way", -PI * 0.5], [Vector2(nr.end.x + 0.5, Quartier.NORTH_Z + 1.4), "zone30", PI],
		[Vector2(sr.end.x + 0.5, Quartier.SOUTH_Z - 1.2), "zone30", 0.0], [Vector2(sr.position.x - 0.5, Quartier.SOUTH_Z - 1.4), "one_way", PI * 0.5]]
	for sg in signs:
		var sp: Variant = find_spot(sg[0], 0.25)
		if sp != null:
			var p: Vector2 = sp
			var rs := RoadSign.new()
			rs.kind = sg[1]
			_prop(rs, p, sg[2])
			count("panneau")
	# lampadaires supplémentaires (boulevard et rues adjacentes), lanterne tournée vers la chaussée
	for lp in [[Vector2(-64.0, Quartier.ROAD_Z1 + 0.6), PI], [Vector2(-88.0, Quartier.ROAD_Z1 + 0.6), PI], [Vector2(70.0, Quartier.ROAD_Z1 + 0.6), PI],
			[Vector2(92.0, Quartier.ROAD_Z1 + 0.6), PI], [Vector2(-28.0, Quartier.ROAD_Z0 - 0.6), 0.0], [Vector2(-58.0, Quartier.ROAD_Z0 - 0.6), 0.0],
			[Vector2(66.0, Quartier.ROAD_Z0 - 0.6), 0.0], [Vector2(90.0, Quartier.ROAD_Z0 - 0.6), 0.0], [Vector2(7.0, Quartier.ROAD_Z0 - 0.6), 0.0],
			[Vector2(nr.position.x - 0.6, 34.0), PI * 0.5], [Vector2(nr.end.x + 0.6, 52.0), -PI * 0.5],
			[Vector2(sr.position.x - 0.6, -40.0), PI * 0.5], [Vector2(sr.end.x + 0.6, -58.0), -PI * 0.5]]:
		var sp: Variant = find_spot(lp[0], 0.3)
		if sp != null:
			var p: Vector2 = sp
			var lamp := LampPost.new()
			lamp.crowd = crowd
			lamp.position = Vector3(p.x, 0, p.y)
			lamp.rotation.y = lp[1]
			add_child(lamp)
			take(p, 0.4)
			count("lampadaire")


func _prop(p: StreetProp, at: Vector2, yaw: float) -> StreetProp:
	p.crowd = crowd
	p.position = Vector3(at.x, 0, at.y)
	p.rotation.y = yaw
	add_child(p)
	take(at, 0.4)
	return p
