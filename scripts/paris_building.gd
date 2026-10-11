class_name ParisBuilding
extends Node3D
## Immeuble parisien procédural, en cinq familles :
##   haussmann    pierre de taille, rez-de-chaussée à refends, balcons filants au 2e et au 5e, comble mansardé
##   belle_epoque pierre, bow-window en encorbellement, consoles et modillons, ardoise
##   faubourg     immeuble ancien enduit (ocre, rose, crème…), volets battants peints, garde-corps aux fenêtres
##   brique       brique rouge et pierre blanche (chaînes d'angle, linteaux à clé), balcons, toit-terrasse
##   deco         années 30 : enduit lisse clair, avancée centrale, menuiseries sombres, attique en retrait
## Repère local : façade principale dans le plan z = 0 (rue côté +Z), le volume s'étend vers -Z ; x de 0 à `width`.
## Façades d'angle (corner_l / corner_r) et pignons aveugles au-dessus des voisins plus bas sont générés aussi.
## Géométrie fusionnée en deux maillages : la masse (toujours visible) et les détails (moulures, menuiseries,
## fleurs…, masqués au-delà de DETAIL_RANGE). Teintes par sommet : une palette par immeuble, matériaux partagés.

const SHOP_DEPTH := 6.2
const WALL := 0.5
const DETAIL_RANGE := 70.0
const STYLES := ["haussmann", "belle_epoque", "faubourg", "brique", "deco"]

# --- paramètres (posés par ParisStreet avant l'ajout à l'arbre)
var style := "haussmann"
var width := 16.0
var depth := 12.0
var floors := 5
var fh := 3.1                # hauteur d'étage
var h0 := 4.6                # rez-de-chaussée
var roof := "zinc"           # zinc | slate | tiles | flat
var seed_v := 1
var shops := 0               # boutiques envahissables au rez-de-chaussée
var shop_ok := true          # rez-de-chaussée commerçant (sinon portes et fenêtres)
var crowd: Crowd
var lod_far := false
var corner_l := false        # côté x = 0 sur rue : vraie façade
var corner_r := false        # côté x = width sur rue
var left_h := 0.0            # hauteur du voisin de gauche (0 : aucun) → pignon aveugle au-dessus
var right_h := 0.0
var street_name := ""        # plaque de rue (immeubles d'angle)
var number := 0              # numéro sur la porte

var shop_nodes: Array = []   # Shop
## Places pour les habitants (balcons, fenêtres) en repère local : [{"local": Transform3D, "kind", "floor"}] ;
## voir spots_world(). Contrat stable : les immeubles sont dans le groupe « paris_buildings ».
var resident_spots: Array = []

class Acc:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()

var _rng := RandomNumberGenerator.new()
var _base := {}              # matériau -> Acc (masse)
var _det := {}               # matériau -> Acc (détails)
var _detail := false
var _xf := Transform3D()     # repère de la façade en cours (façade -> immeuble)
var _body: StaticBody3D
var _main_face := true

# palette
var c_wall := Color(1, 1, 1)
var c_trim := Color(1, 1, 1)
var c_base := Color(1, 1, 1)
var c_frame := Color(0.92, 0.91, 0.88)
var c_door := Color(0.1, 0.2, 0.15)
var c_shut := Color(0.6, 0.65, 0.7)
var m_wall := "stone"
var rail_motif := 0
var _dirt := 1.0

static var _mats := {}
static var _font_serif: Font
static var _font_sans: Font

const TILE := {"stone": 2.0, "plaster": 2.0, "brick": 1.76, "slate": 1.2, "zinc": 1.5, "tiles": 1.2}
const STONE_TINTS := [Color(0.84, 0.78, 0.67), Color(0.82, 0.73, 0.57), Color(0.74, 0.72, 0.68), Color(0.86, 0.82, 0.75),
	Color(0.82, 0.74, 0.68), Color(0.68, 0.64, 0.56), Color(0.79, 0.75, 0.63)]
const PLASTER_TINTS := [Color(0.82, 0.62, 0.38), Color(0.88, 0.78, 0.52), Color(0.84, 0.64, 0.58), Color(0.82, 0.56, 0.43),
	Color(0.76, 0.76, 0.74), Color(0.7, 0.77, 0.64), Color(0.86, 0.81, 0.7), Color(0.64, 0.7, 0.75), Color(0.74, 0.52, 0.42)]
const DECO_TINTS := [Color(0.86, 0.84, 0.79), Color(0.78, 0.78, 0.76), Color(0.84, 0.79, 0.7), Color(0.8, 0.8, 0.74)]
const SHUT_COLS := [Color(0.5, 0.58, 0.66), Color(0.55, 0.65, 0.55), Color(0.93, 0.93, 0.91), Color(0.42, 0.11, 0.13),
	Color(0.14, 0.3, 0.22), Color(0.74, 0.74, 0.73), Color(0.16, 0.22, 0.34), Color(0.62, 0.48, 0.3)]
const DOOR_COLS := [Color(0.07, 0.2, 0.14), Color(0.3, 0.06, 0.08), Color(0.07, 0.1, 0.2), Color(0.05, 0.05, 0.055),
	Color(0.36, 0.22, 0.12), Color(0.3, 0.38, 0.45), Color(0.16, 0.12, 0.09)]


## Tire au hasard les dimensions d'un immeuble d'un style donné
static func spec(st: String, rng: RandomNumberGenerator) -> Dictionary:
	match st:
		"belle_epoque":
			return {"width": rng.randf_range(14.0, 18.0), "floors": 6, "fh": 3.0, "h0": 4.6, "roof": "slate"}
		"faubourg":
			return {"width": rng.randf_range(7.5, 12.0), "floors": rng.randi_range(3, 5), "fh": 2.85, "h0": 3.6,
				"roof": "tiles" if rng.randf() < 0.55 else "zinc"}
		"brique":
			return {"width": rng.randf_range(12.0, 16.0), "floors": rng.randi_range(5, 6), "fh": 2.95, "h0": 4.0, "roof": "flat"}
		"deco":
			return {"width": rng.randf_range(12.0, 17.0), "floors": rng.randi_range(6, 7), "fh": 2.9, "h0": 4.2, "roof": "flat"}
		_:
			return {"width": rng.randf_range(14.0, 20.0), "floors": 5, "fh": 3.15, "h0": 4.6, "roof": "zinc" if rng.randf() < 0.8 else "slate"}


## Hauteur de la façade (corniche comprise) et du sommet du toit, pour un jeu de dimensions
static func facade_h(sp: Dictionary) -> float:
	return float(sp["h0"]) + float(sp["floors"]) * float(sp["fh"]) + 0.7


static func top_h(sp: Dictionary) -> float:
	return facade_h(sp) + (1.0 if sp["roof"] == "flat" else 3.0)


func apply_spec(sp: Dictionary) -> void:
	width = sp["width"]
	floors = sp["floors"]
	fh = sp["fh"]
	h0 = sp["h0"]
	roof = sp["roof"]


func height() -> float:
	return h0 + float(floors) * fh + 0.7


# =================================================================== matériaux partagés
static func mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	match key:
		"stone", "plaster", "brick", "slate", "zinc", "tiles":
			var tex: String = {"stone": "stone", "plaster": "plaster", "brick": "brick", "slate": "slate", "zinc": "zinc", "tiles": "slate"}[key]
			m.albedo_texture = load("res://assets/paris/%s_a.png" % tex)
			m.normal_enabled = true
			m.normal_texture = load("res://assets/paris/%s_n.png" % tex)
			m.normal_scale = {"stone": 0.9, "plaster": 0.6, "brick": 1.0, "slate": 0.8, "zinc": 1.0, "tiles": 0.8}[key]
			m.roughness = {"stone": 0.86, "plaster": 0.92, "brick": 0.9, "slate": 0.62, "zinc": 0.4, "tiles": 0.75}[key]
			if key == "zinc":
				m.metallic = 0.55
			if key == "tiles":
				m.albedo_color = Color(2.3, 1.3, 0.95)      # ardoise teintée en tuile mécanique brun-rouge
		"paint":
			m.roughness = 0.5
		"metal":
			m.roughness = 0.38
			m.metallic = 0.7
		"glass", "glass_lit", "glass_dim":
			m.albedo_texture = load("res://assets/paris/win_atlas.png")
			m.roughness = 0.05
			m.metallic_specular = 1.0
			if key == "glass":
				m.albedo_color = Color(0.3, 0.31, 0.33)
				m.metallic = 0.5
			else:
				m.albedo_color = Color(0.45, 0.45, 0.45)
				m.emission_enabled = true
				m.emission_texture = load("res://assets/paris/win_atlas.png")
				m.emission = Color(1.0, 0.82, 0.6)
				m.emission_energy_multiplier = 1.2 if key == "glass_lit" else 0.45
		"railing":
			m.albedo_texture = load("res://assets/paris/railing_a.png")
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.45
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.metallic = 0.6
			m.roughness = 0.45
		"shutter":
			m.albedo_texture = load("res://assets/paris/shutter_a.png")
			m.roughness = 0.6
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"rideau":
			m.albedo_texture = load("res://assets/paris/rideau_a.png")
			m.metallic = 0.4
			m.roughness = 0.55
		"leaf":
			m.roughness = 0.85
		"glow":
			m.emission_enabled = true
			m.emission = Color(1, 1, 1)
			m.emission_energy_multiplier = 0.9
			m.roughness = 0.4
		"cloth":
			m.roughness = 0.95
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_:
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color(0.5, 0.5, 0.5)
	_mats[key] = m
	return m


static func serif() -> Font:
	if _font_serif == null:
		_font_serif = load("res://assets/fonts/LiberationSerif-Bold.ttf")
	return _font_serif


static func sans() -> Font:
	if _font_sans == null:
		_font_sans = load("res://assets/fonts/Inter-Bold.otf")
	return _font_sans


# =================================================================== géométrie
const _FN := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
const _FU := [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(-1, 0, 0)]
const _FV := [Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(0, 1, 0)]
const NO_BACK := 32
const NO_TOP := 4
const NO_BOTTOM := 8
const NO_FRONT := 16


func _acc(key: String) -> Acc:
	var d := _det if _detail else _base
	if not d.has(key):
		d[key] = Acc.new()
	return d[key]


func _grime(y: float) -> float:
	# encrassement : pied de façade plus sombre
	return _dirt * (1.0 - 0.2 * exp(-y / 0.9) - 0.05 * exp(-y / 3.0))


func _puv(p: Vector3, n: Vector3, t: float) -> Vector2:
	if absf(n.y) > 0.7:
		return Vector2(p.x, p.z) / t
	if absf(n.x) > absf(n.z):
		return Vector2(p.z, -p.y) / t
	return Vector2(p.x, -p.y) / t


## Quadrilatère p0 (bas gauche), p1 (bas droite), p2 (haut droite), p3 (haut gauche), vu de face
func _face(a: Acc, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3, col: Color, t: float, uvs: Array = []) -> void:
	var base := a.v.size()
	var pts := [p0, p1, p2, p3]
	for k in 4:
		var p: Vector3 = pts[k]
		a.v.append(p)
		a.n.append(n)
		var g := _grime(p.y)
		a.c.append(Color(col.r * g, col.g * g, col.b * g, col.a))
		a.uv.append(_puv(p, n, t) if uvs.is_empty() else uvs[k])
	a.idx.append(base)
	a.idx.append(base + 2)
	a.idx.append(base + 1)
	a.idx.append(base)
	a.idx.append(base + 3)
	a.idx.append(base + 2)


## Pavé de taille `size` centré en `c` (repère de la façade courante), tourné de `b`. `skip` : faces à omettre
## (bits : 1 +X, 2 -X, 4 +Y, 8 -Y, 16 +Z, 32 -Z ; par défaut la face arrière, contre le mur)
func box(key: String, size: Vector3, c: Vector3, col := Color(1, 1, 1), b := Basis(), skip := NO_BACK) -> void:
	var a := _acc(key)
	var t: float = TILE.get(key, 1.0)
	var xf := _xf * Transform3D(b, c)
	var h := size * 0.5
	for fi in 6:
		if skip & (1 << fi):
			continue
		var n: Vector3 = _FN[fi]
		var u: Vector3 = _FU[fi] * h
		var v: Vector3 = _FV[fi] * h
		var cn := n * h
		_face(a, xf * (cn - u - v), xf * (cn + u - v), xf * (cn + u + v), xf * (cn - u + v), (xf.basis * n).normalized(), col, t)


## Quadrilatère vertical face à +Z (dans le repère `b` de la façade), UV explicites (haut de l'image en haut)
func quad(key: String, c: Vector3, w: float, h: float, uv: Rect2, col := Color(1, 1, 1), b := Basis()) -> void:
	var xf := _xf * Transform3D(b, c)
	var uvs := [Vector2(uv.position.x, uv.end.y), Vector2(uv.end.x, uv.end.y), Vector2(uv.end.x, uv.position.y), uv.position]
	_face(_acc(key), xf * Vector3(-w * 0.5, -h * 0.5, 0), xf * Vector3(w * 0.5, -h * 0.5, 0), xf * Vector3(w * 0.5, h * 0.5, 0),
		xf * Vector3(-w * 0.5, h * 0.5, 0), (xf.basis * Vector3(0, 0, 1)).normalized(), col, 1.0, uvs)


## Cylindre vertical (section à `seg` côtés) centré en `c`
func cyl(key: String, r: float, h: float, c: Vector3, col := Color(1, 1, 1), seg := 8, cap := true) -> void:
	var a := _acc(key)
	var t: float = TILE.get(key, 1.0)
	var top := _xf * (c + Vector3(0, h * 0.5, 0))
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var d0 := Vector3(cos(a0), 0, -sin(a0)) * r
		var d1 := Vector3(cos(a1), 0, -sin(a1)) * r
		var hh := Vector3(0, h * 0.5, 0)
		var n := (_xf.basis * (d0 + d1)).normalized()
		_face(a, _xf * (c + d0 - hh), _xf * (c + d1 - hh), _xf * (c + d1 + hh), _xf * (c + d0 + hh), n, col, t)
		if cap:
			_face(a, _xf * (c + d0 + hh), _xf * (c + d1 + hh), top, top, (_xf.basis * Vector3.UP), col, t)


func collider(size: Vector3, c: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = c
	_body.add_child(cs)


func _commit() -> void:
	for layer in 2:
		var d: Dictionary = _base if layer == 0 else _det
		if d.is_empty():
			continue
		var am := ArrayMesh.new()
		for key in d:
			var a: Acc = d[key]
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = a.v
			arr[Mesh.ARRAY_NORMAL] = a.n
			arr[Mesh.ARRAY_COLOR] = a.c
			arr[Mesh.ARRAY_TEX_UV] = a.uv
			arr[Mesh.ARRAY_INDEX] = a.idx
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			am.surface_set_material(am.get_surface_count() - 1, mat(key))
		var mi := MeshInstance3D.new()
		mi.mesh = am
		if layer == 1:
			mi.visibility_range_end = DETAIL_RANGE
			mi.visibility_range_end_margin = 8.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_base.clear()
	_det.clear()


## Nombre de triangles (diagnostic)
func tri_count() -> int:
	var n := 0
	for ch in get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh is ArrayMesh:
			var am := (ch as MeshInstance3D).mesh as ArrayMesh
			for s in am.get_surface_count():
				n += am.surface_get_array_index_len(s) / 3
	return n


# =================================================================== construction
func _ready() -> void:
	_rng.seed = seed_v
	_body = StaticBody3D.new()
	add_child(_body)
	_palette()
	_xf = Transform3D()
	_main_face = true
	_facade(width, true)
	_main_face = false
	if corner_r:
		_xf = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(width, 0, 0))
		_facade(depth, false)
	if corner_l:
		_xf = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 0, -depth))
		_facade(depth, false)
	_xf = Transform3D()
	_pignons()
	_build_roof()
	_plates()
	_commit()
	# collisions : tout le volume sauf l'intérieur des boutiques ouvertes
	var top := height() + 3.0
	if shop_nodes.is_empty():
		collider(Vector3(width, top, depth), Vector3(width * 0.5, top * 0.5, -depth * 0.5))
	else:
		_ground_colliders()
		collider(Vector3(width, top - h0, depth), Vector3(width * 0.5, h0 + (top - h0) * 0.5, -depth * 0.5))
	add_to_group("paris_buildings")


func _palette() -> void:
	_dirt = _rng.randf_range(0.86, 1.0)
	rail_motif = _rng.randi() % 3
	c_door = DOOR_COLS[_rng.randi() % DOOR_COLS.size()]
	c_shut = SHUT_COLS[_rng.randi() % SHUT_COLS.size()]
	c_frame = [Color(0.93, 0.92, 0.89), Color(0.9, 0.88, 0.82), Color(0.8, 0.8, 0.79), Color(0.95, 0.95, 0.94)][_rng.randi() % 4]
	match style:
		"faubourg":
			m_wall = "plaster"
			c_wall = PLASTER_TINTS[_rng.randi() % PLASTER_TINTS.size()]
			c_trim = c_wall.lightened(0.3)
			c_base = c_wall.darkened(0.15)
		"brique":
			m_wall = "brick"
			c_wall = Color(1, 1, 1).darkened(_rng.randf_range(0.0, 0.15))
			c_trim = STONE_TINTS[3]
			c_base = STONE_TINTS[_rng.randi() % 3].darkened(0.05)
		"deco":
			m_wall = "plaster"
			c_wall = DECO_TINTS[_rng.randi() % DECO_TINTS.size()]
			c_trim = c_wall.lightened(0.12)
			c_base = c_wall.darkened(0.12)
			c_frame = [Color(0.12, 0.13, 0.14), Color(0.9, 0.9, 0.88), Color(0.35, 0.38, 0.4)][_rng.randi() % 3]
		_:
			m_wall = "stone"
			c_wall = STONE_TINTS[_rng.randi() % STONE_TINTS.size()]
			c_trim = c_wall.lightened(0.07)
			c_base = c_wall.darkened(0.06)


func _bays(len: float, bay_w: float, margin: float) -> Array[float]:
	var n := maxi(int((len - margin * 2.0) / bay_w), 1)
	var out: Array[float] = []
	var step := (len - margin * 2.0) / float(n)
	for i in n:
		out.append(margin + step * (float(i) + 0.5))
	return out


func _bay_w() -> float:
	return {"faubourg": 2.3, "deco": 2.9, "brique": 2.7}.get(style, 2.65)


func _margin() -> float:
	return 0.7 if style == "faubourg" else 0.9


func _win_size() -> Vector2:
	return {"faubourg": Vector2(1.0, 1.75), "deco": Vector2(1.5, 1.85), "brique": Vector2(1.15, 1.95)}.get(style, Vector2(1.18, 2.15))


func _wall_trim_key() -> String:
	return "plaster" if m_wall == "plaster" else "stone"


# ------------------------------------------------------------------ une façade complète
func _facade(len: float, main: bool) -> void:
	var bays := _bays(len, _bay_w(), _margin())
	_ground_floor(len, bays, main)
	_upper_floors(len, bays)
	_cornice(len)
	# chaînes d'angle en pierre sur les immeubles enduits ou en brique
	if style in ["faubourg", "brique"]:
		var top := height() - 0.7
		var y := h0
		var i := 0
		while y < top - 0.05:
			var hh := minf(0.32, top - y)
			var w := 0.55 if i % 2 == 0 else 0.35
			box("stone", Vector3(w, hh - 0.02, 0.06), Vector3(w * 0.5, y + hh * 0.5, 0.03), c_trim)
			box("stone", Vector3(w, hh - 0.02, 0.06), Vector3(len - w * 0.5, y + hh * 0.5, 0.03), c_trim)
			y += hh
			i += 1
	# descente d'eau pluviale
	if main:
		_detail = true
		cyl("metal", 0.055, height() - 0.3, Vector3(len - 0.12, (height() - 0.3) * 0.5, 0.1), Color(0.55, 0.57, 0.6), 6, false)
		_detail = false


# ------------------------------------------------------------------ rez-de-chaussée
func _ground_floor(len: float, bays: Array[float], main: bool) -> void:
	var step: float = bays[1] - bays[0] if bays.size() > 1 else len - 1.8
	var openings: Array = []          # [x0, x1, haut, type, centre]
	var shop_slots: Array[int] = []
	if main and shops > 0:
		var nb := bays.size()
		var first := 0 if nb <= 3 else _rng.randi_range(0, 1)
		for k in shops:
			var idx := first + k * 2
			if idx < nb:
				shop_slots.append(idx)
	var door_done := false
	var oh := h0 - (0.95 if style in ["haussmann", "belle_epoque"] else 0.7)
	var door_at := -1
	if main:
		for k in bays.size():
			var cand := (bays.size() / 2 + k) % bays.size()
			if not shop_slots.has(cand):
				door_at = cand
				break
	for k in bays.size():
		var cx := bays[k]
		if shop_slots.has(k):
			var w := minf(step * 1.5, 5.0) if (k + 1 < bays.size() and not shop_slots.has(k + 1)) else step - 0.7
			var c2 := cx + (w - (step - 0.7)) * 0.5
			openings.append([c2 - w * 0.5, c2 + w * 0.5, oh, "shop", c2])
		elif k == door_at and not door_done:
			door_done = true
			var dw := 1.3 if style == "faubourg" else 1.4
			openings.append([cx - dw, cx + dw, minf(oh, 3.9), "door", cx])
		else:
			var r := _rng.randf()
			var t := "closed" if r < 0.3 else "fake"
			if not shop_ok:
				t = "window" if r < 0.65 else "closed"
			var top_o: float = oh if t != "window" else h0 - 1.0
			openings.append([cx - (step - 0.7) * 0.5, cx + (step - 0.7) * 0.5, top_o, t, cx])
	openings.sort_custom(func(a, b): return a[0] < b[0])
	var clean: Array = []
	for o in openings:
		if not clean.is_empty() and o[0] < clean[clean.size() - 1][1] + 0.5:
			continue
		clean.append(o)
	openings = clean
	# maçonnerie : trumeaux pleine hauteur, impostes au-dessus des ouvertures
	var x0 := 0.0
	for o in openings:
		_ground_wall(x0, o[0], 0.0, h0)
		_ground_wall(o[0], o[1], o[2], h0)
		if o[3] == "window":
			_ground_wall(o[0], o[1], 0.0, 1.0)
		x0 = o[1]
	_ground_wall(x0, len, 0.0, h0)
	box(_wall_trim_key(), Vector3(len, 0.2, 0.22), Vector3(len * 0.5, h0 - 0.1, 0.11), c_trim, Basis(), 0)    # cordon
	for o in openings:
		match o[3]:
			"shop":
				_shop_opening(o[4], o[1] - o[0], o[2])
			"door":
				_door(o[4], o[1] - o[0], o[2])
			"fake":
				_fake_shop(o[4], o[1] - o[0], o[2])
			"window":
				var ws := _win_size()
				_window(o[4], 1.0, ws.x, minf(ws.y, o[2] - 1.1), -1)
			_:
				_closed_shop(o[4], o[1] - o[0], o[2])


## Mur du rez-de-chaussée : refends (pierre), soubassement (enduit, brique)
func _ground_wall(x0: float, x1: float, y0: float, y1: float) -> void:
	var w := x1 - x0
	if w < 0.02 or y1 - y0 < 0.02:
		return
	var cx := (x0 + x1) * 0.5
	if m_wall == "stone":
		var y := y0
		var i := 0
		while y < y1 - 0.02:
			var hh := minf(0.45, y1 - y)
			box("stone", Vector3(w, maxf(hh - 0.035, 0.01), 0.06), Vector3(cx, y + hh * 0.5 + 0.0175, 0.0), c_base.darkened(0.03 * float(i % 2)), Basis(), NO_BACK)
			y += hh
			i += 1
		box("stone", Vector3(w, y1 - y0, WALL), Vector3(cx, (y0 + y1) * 0.5, -WALL * 0.5 - 0.03), c_base.darkened(0.3), Basis(), NO_BACK | NO_TOP | NO_BOTTOM)
	else:
		var key := "stone" if style == "brique" else m_wall
		var col := c_base if style == "brique" else c_wall.darkened(0.08)
		box(key, Vector3(w, y1 - y0, WALL), Vector3(cx, (y0 + y1) * 0.5, -WALL * 0.5 + 0.02), col, Basis(), NO_BACK | NO_TOP)
	if y0 < 0.01:
		box("stone", Vector3(w, 0.32, 0.1), Vector3(cx, 0.16, 0.06), c_base.darkened(0.18), Basis(), NO_BACK | NO_BOTTOM)     # soubassement


# ------------------------------------------------------------------ étages
func _upper_floors(len: float, bays: Array[float]) -> void:
	var ws := _win_size()
	var bow: Array[int] = []
	if style == "belle_epoque" and bays.size() >= 5:
		bow = [bays.size() / 2]
	if style == "deco" and bays.size() >= 4:
		bow = [bays.size() / 2]
	for f in floors:
		var y0 := h0 + float(f) * fh
		var top_floor := f == floors - 1
		var sill := 0.85 if style != "faubourg" else 0.9
		var wh := ws.y
		if top_floor and style in ["haussmann", "deco"]:
			wh -= 0.2
		var top := y0 + sill + wh
		var ww := ws.x
		# bandeau d'étage
		if style != "faubourg" or f == 0:
			box(_wall_trim_key(), Vector3(len, 0.16 if style != "deco" else 0.1, 0.12), Vector3(len * 0.5, y0 + 0.08, 0.06), c_trim, Basis(), NO_BACK | NO_BOTTOM)
		# allège, linteau, trumeaux
		box(m_wall, Vector3(len, sill, WALL), Vector3(len * 0.5, y0 + sill * 0.5, -WALL * 0.5), c_wall, Basis(), NO_BACK | NO_BOTTOM | 3)
		box(m_wall, Vector3(len, y0 + fh - top, WALL), Vector3(len * 0.5, (top + y0 + fh) * 0.5, -WALL * 0.5), c_wall, Basis(), NO_BACK | NO_TOP | 3)
		var xs: Array[float] = [0.0]
		for c in bays:
			xs.append(c - ww * 0.5)
			xs.append(c + ww * 0.5)
		xs.append(len)
		for k in range(0, xs.size(), 2):
			var a: float = xs[k]
			var b: float = xs[k + 1]
			if b - a > 0.01:
				var sk := NO_BACK | NO_TOP | NO_BOTTOM
				if k == 0:
					sk |= 2
				if k == xs.size() - 2:
					sk |= 1
				box(m_wall, Vector3(b - a, wh, WALL), Vector3((a + b) * 0.5, y0 + sill + wh * 0.5, -WALL * 0.5), c_wall, Basis(), sk)
		for bi in bays.size():
			var c := bays[bi]
			if bow.has(bi) and f >= 1 and f <= floors - 2:
				_bow_window(c, y0, ww, sill, wh, f)
			else:
				_window(c, y0 + sill, ww, wh, f)
				if f >= 1:
					_spot(Vector3(c, y0 + 0.02, -0.75), "window", f)
		# balcons
		match style:
			"haussmann", "belle_epoque":
				var b5 := floors - 1 if style == "haussmann" else floors - 2
				if f == 1 or f == b5:
					_balcony(0.2, len - 0.2, y0 + sill - 0.06, 0.9 if f == 1 else 0.75, bow, bays)
					for bi in bays.size():
						if not bow.has(bi):
							_spot(Vector3(bays[bi], y0 + sill + 0.02, 0.45), "balcony", f)
				elif f > 0:
					for bi in bays.size():
						if not bow.has(bi):
							_railing(bays[bi] - ww * 0.5 - 0.06, bays[bi] + ww * 0.5 + 0.06, y0 + sill - 0.02, 0.08, 0.9)
			"brique":
				if f == 1 or f == floors - 1:
					for c in bays:
						_small_balcony(c, ww, y0 + sill - 0.05)
						_spot(Vector3(c, y0 + sill + 0.02, 0.45), "balcony", f)
			"deco":
				if f >= 1 and not top_floor:
					for bi in bays.size():
						if not bow.has(bi):
							_railing(bays[bi] - ww * 0.5, bays[bi] + ww * 0.5, y0 + sill - 0.02, 0.05, 0.85, 2)
			"faubourg":
				if f >= 1:
					for c in bays:
						_railing(c - ww * 0.5 - 0.02, c + ww * 0.5 + 0.02, y0 + sill - 0.02, 0.06, 0.75)


## Fenêtre : embrasure, vitrage (intérieur tiré dans l'atlas, allumé ou non), menuiseries, volets, encadrement
func _window(cx: float, y: float, ww: float, wh: float, f: int) -> void:
	var recess := 0.28
	var cell := _rng.randi() % 16
	var uv := Rect2(float(cell % 8) / 8.0, float(cell / 8) / 2.0, 1.0 / 8.0, 0.5)
	var lit := _rng.randf() < (0.32 if f >= 0 else 0.15)
	quad("glass_lit" if lit else "glass", Vector3(cx, y + wh * 0.5, -recess), ww, wh, uv)
	# embrasure (tableaux, appui intérieur, linteau)
	box(m_wall, Vector3(ww, 0.04, recess), Vector3(cx, y + wh - 0.02, -recess * 0.5), c_wall.darkened(0.25), Basis(), NO_BACK | NO_FRONT | NO_TOP | 3)
	box(m_wall, Vector3(ww, 0.04, recess), Vector3(cx, y + 0.02, -recess * 0.5), c_wall.darkened(0.1), Basis(), NO_BACK | NO_FRONT | NO_BOTTOM | 3)
	# appui saillant
	box(_wall_trim_key(), Vector3(ww + 0.32, 0.08, 0.2), Vector3(cx, y - 0.03, 0.06), c_trim, Basis(), NO_BACK | NO_BOTTOM)
	# volets
	var shut := _rng.randf()
	if style == "faubourg":
		if shut < 0.68:
			for s: float in [-1.0, 1.0]:
				quad("shutter", Vector3(cx + s * (ww * 0.75 + 0.06), y + wh * 0.5, 0.045), ww * 0.5, wh, Rect2(0, 0, 1, 1), c_shut)
		elif shut < 0.82:
			quad("shutter", Vector3(cx, y + wh * 0.5, -0.06), ww, wh, Rect2(0, 0, 2, 1), c_shut)
	elif style in ["haussmann", "belle_epoque"] and shut < 0.2:
		# persiennes métalliques à demi dépliées dans l'embrasure
		var k := _rng.randf_range(0.3, 1.0)
		quad("shutter", Vector3(cx, y + wh * (1.0 - k * 0.5), -recess + 0.06), ww, wh * k, Rect2(0, 0, 2, k), Color(0.58, 0.58, 0.57))
	# encadrement
	match style:
		"haussmann", "belle_epoque":
			box("stone", Vector3(0.14, wh, 0.07), Vector3(cx - ww * 0.5 - 0.07, y + wh * 0.5, 0.035), c_trim, Basis(), NO_BACK | NO_TOP | NO_BOTTOM)
			box("stone", Vector3(0.14, wh, 0.07), Vector3(cx + ww * 0.5 + 0.07, y + wh * 0.5, 0.035), c_trim, Basis(), NO_BACK | NO_TOP | NO_BOTTOM)
			box("stone", Vector3(ww + 0.28, 0.16, 0.07), Vector3(cx, y + wh + 0.08, 0.035), c_trim)
		"brique":
			box("stone", Vector3(ww + 0.34, 0.26, 0.05), Vector3(cx, y + wh + 0.13, 0.025), c_trim)
			box("stone", Vector3(0.14, 0.16, 0.07), Vector3(cx, y + wh + 0.17, 0.05), c_trim.darkened(0.06))
		"faubourg":
			box("plaster", Vector3(0.12, wh + 0.12, 0.03), Vector3(cx - ww * 0.5 - 0.06, y + wh * 0.5, 0.015), c_trim)
			box("plaster", Vector3(0.12, wh + 0.12, 0.03), Vector3(cx + ww * 0.5 + 0.06, y + wh * 0.5, 0.015), c_trim)
			box("plaster", Vector3(ww + 0.24, 0.12, 0.03), Vector3(cx, y + wh + 0.06, 0.015), c_trim)
		"deco":
			box("plaster", Vector3(ww + 0.1, 0.06, 0.06), Vector3(cx, y + wh + 0.03, 0.03), c_trim)
	# --- détails (masqués de loin)
	if lod_far:
		return
	_detail = true
	var fz := -recess + 0.035
	box("paint", Vector3(ww, 0.06, 0.06), Vector3(cx, y + wh - 0.03, fz), c_frame)
	box("paint", Vector3(ww, 0.07, 0.07), Vector3(cx, y + 0.035, fz), c_frame)
	box("paint", Vector3(0.06, wh, 0.06), Vector3(cx - ww * 0.5 + 0.03, y + wh * 0.5, fz), c_frame)
	box("paint", Vector3(0.06, wh, 0.06), Vector3(cx + ww * 0.5 - 0.03, y + wh * 0.5, fz), c_frame)
	if style == "deco":
		for j: float in [0.33, 0.66]:
			box("paint", Vector3(ww, 0.03, 0.04), Vector3(cx, y + wh * j, fz), c_frame)
		box("paint", Vector3(0.04, wh, 0.04), Vector3(cx - ww * 0.17, y + wh * 0.5, fz), c_frame)
		box("paint", Vector3(0.04, wh, 0.04), Vector3(cx + ww * 0.17, y + wh * 0.5, fz), c_frame)
	else:
		box("paint", Vector3(0.05, wh, 0.05), Vector3(cx, y + wh * 0.5, fz), c_frame)
		box("paint", Vector3(ww, 0.04, 0.045), Vector3(cx, y + wh * 0.8, fz), c_frame)
		if style == "faubourg":
			for j: float in [0.27, 0.53]:
				box("paint", Vector3(ww, 0.025, 0.03), Vector3(cx, y + wh * j, fz), c_frame)
	if style == "faubourg" and shut < 0.68:
		for s: float in [-1.0, 1.0]:
			box("paint", Vector3(0.025, wh, 0.03), Vector3(cx + s * (ww + 0.065), y + wh * 0.5, 0.05), c_shut.darkened(0.25))
	# ornements haussmanniens
	if style in ["haussmann", "belle_epoque"] and f >= 0:
		if f == 1:
			if seed_v % 2 == 0:
				var ang := 0.3
				var half := (ww + 0.5) * 0.5
				var ln := half / cos(ang)
				box("stone", Vector3(ln, 0.12, 0.2), Vector3(cx - half * 0.5, y + wh + 0.38 + half * tan(ang) * 0.5, 0.09), c_trim, Basis(Vector3.BACK, ang), 0)
				box("stone", Vector3(ln, 0.12, 0.2), Vector3(cx + half * 0.5, y + wh + 0.38 + half * tan(ang) * 0.5, 0.09), c_trim, Basis(Vector3.BACK, -ang), 0)
				box("stone", Vector3(ww + 0.55, 0.1, 0.24), Vector3(cx, y + wh + 0.3, 0.1), c_trim, Basis(), 0)
			else:
				box("stone", Vector3(ww + 0.6, 0.12, 0.26), Vector3(cx, y + wh + 0.32, 0.11), c_trim, Basis(), 0)
				box("stone", Vector3(ww + 0.3, 0.2, 0.12), Vector3(cx, y + wh + 0.48, 0.05), c_trim)
				box("stone", Vector3(ww * 0.6, 0.1, 0.1), Vector3(cx, y + wh + 0.62, 0.05), c_trim)
			for s: float in [-1.0, 1.0]:
				_console(cx + s * (ww * 0.5 + 0.17), y + wh + 0.26, 0.3, 0.2)
		elif f == 2 or f == 3:
			box("stone", Vector3(ww + 0.42, 0.1, 0.18), Vector3(cx, y + wh + 0.22, 0.08), c_trim, Basis(), 0)
			box("stone", Vector3(0.18, 0.24, 0.1), Vector3(cx, y + wh + 0.08, 0.06), c_trim)
		else:
			box("stone", Vector3(0.16, 0.2, 0.08), Vector3(cx, y + wh + 0.06, 0.05), c_trim)
		if f >= 1 and style == "belle_epoque":
			box("stone", Vector3(ww * 0.8, 0.4, 0.03), Vector3(cx, y - 0.45, 0.015), c_trim.darkened(0.06))
	if f >= 1 and _rng.randf() < (0.16 if style == "faubourg" else 0.08):
		_flower_box(cx, y + 0.02, ww)
	_detail = false


func _flower_box(cx: float, y: float, ww: float) -> void:
	box("paint", Vector3(ww * 0.9, 0.18, 0.2), Vector3(cx, y + 0.09, 0.2), [Color(0.55, 0.3, 0.2), Color(0.3, 0.32, 0.3), Color(0.85, 0.85, 0.82)][_rng.randi() % 3], Basis(), 0)
	var fc: Color = [Color(0.85, 0.1, 0.12), Color(0.95, 0.45, 0.6), Color(0.96, 0.95, 0.92), Color(0.6, 0.2, 0.6), Color(0.95, 0.6, 0.1)][_rng.randi() % 5]
	var n := maxi(int(ww / 0.13), 2)
	for i in n:
		var px := cx - ww * 0.4 + float(i) * ww * 0.8 / float(n - 1)
		box("leaf", Vector3(0.15, 0.14, 0.17), Vector3(px, y + 0.22, 0.2 + _rng.randf_range(-0.03, 0.04)), Color(0.2, 0.4, 0.15).darkened(_rng.randf() * 0.3), Basis(Vector3.UP, _rng.randf() * 1.5), 0)
		if _rng.randf() < 0.75:
			box("leaf", Vector3(0.08, 0.07, 0.08), Vector3(px + _rng.randf_range(-0.04, 0.04), y + 0.31, 0.22), fc, Basis(Vector3.UP, _rng.randf()), 0)


## Console (corbeau à volute simplifiée) : trois pavés en encorbellement
func _console(x: float, y: float, h: float, d: float) -> void:
	box("stone", Vector3(0.14, h, d * 0.45), Vector3(x, y - h * 0.5, d * 0.22), c_trim, Basis(), NO_BACK)
	box("stone", Vector3(0.15, h * 0.4, d * 0.75), Vector3(x, y - h * 0.2, d * 0.38), c_trim, Basis(), NO_BACK)
	box("stone", Vector3(0.16, h * 0.18, d), Vector3(x, y - 0.03, d * 0.5), c_trim, Basis(), NO_BACK)


## Bow-window (avancée en encorbellement) : allège, linteau, trumeaux d'angle et vitrage en avant de la façade
func _bow_window(cx: float, y0: float, ww: float, sill: float, wh: float, f: int) -> void:
	var w := ww + 0.9
	var d := 0.6
	var key := m_wall
	var tk := _wall_trim_key()
	box(tk, Vector3(w + 0.2, 0.22, d + 0.15), Vector3(cx, y0 + 0.11, d * 0.5), c_trim, Basis(), 0)
	box(key, Vector3(w, sill - 0.11, d), Vector3(cx, y0 + 0.22 + (sill - 0.11) * 0.5, d * 0.5), c_wall, Basis(), NO_BACK | NO_BOTTOM)
	var ytop := y0 + sill + 0.11 + wh
	box(key, Vector3(w, y0 + fh - ytop, d), Vector3(cx, (ytop + y0 + fh) * 0.5, d * 0.5), c_wall, Basis(), NO_BACK)
	box(key, Vector3(0.45, wh, d), Vector3(cx - w * 0.5 + 0.225, y0 + sill + 0.11 + wh * 0.5, d * 0.5), c_wall, Basis(), NO_BACK | NO_TOP | NO_BOTTOM)
	box(key, Vector3(0.45, wh, d), Vector3(cx + w * 0.5 - 0.225, y0 + sill + 0.11 + wh * 0.5, d * 0.5), c_wall, Basis(), NO_BACK | NO_TOP | NO_BOTTOM)
	var saved := _xf
	_xf = _xf * Transform3D(Basis(), Vector3(0, 0.11, d))
	_window(cx, y0 + sill, ww, wh, f)
	_xf = saved
	# le mur derrière l'avancée (fond de la baie)
	box(key, Vector3(ww, wh, 0.05), Vector3(cx, y0 + sill + wh * 0.5, -WALL + 0.05), c_wall.darkened(0.3), Basis(), NO_BACK)
	if f == 1 and not lod_far:
		_detail = true
		_console(cx - w * 0.5 + 0.25, y0, 0.7, d)
		_console(cx + w * 0.5 - 0.25, y0, 0.7, d)
		_detail = false


## Balcon filant : dalle sur consoles, garde-corps en fer forgé, et la vie du balcon (pots, chaises…)
func _balcony(x0: float, x1: float, y: float, d: float, skip_bays: Array[int] = [], bays: Array[float] = []) -> void:
	var w := x1 - x0
	box("stone", Vector3(w, 0.16, d), Vector3((x0 + x1) * 0.5, y, d * 0.5), c_trim, Basis(), NO_BACK)
	box("stone", Vector3(w + 0.08, 0.06, d + 0.06), Vector3((x0 + x1) * 0.5, y + 0.09, d * 0.5), c_trim, Basis(), NO_BACK | NO_BOTTOM)
	if not lod_far:
		_detail = true
		var x := x0 + 0.45
		while x < x1 - 0.3:
			_console(x, y - 0.06, 0.38, d * 0.85)
			x += 1.3
		_detail = false
	_railing(x0, x1, y + 0.12, d - 0.05, 1.0)
	_railing_side(x0 + 0.02, y + 0.12, d - 0.05, 1.0)
	_railing_side(x1 - 0.02, y + 0.12, d - 0.05, 1.0)
	if lod_far:
		return
	_detail = true
	var px := x0 + _rng.randf_range(0.5, 2.0)
	while px < x1 - 0.5:
		var r := _rng.randf()
		if r < 0.35:
			cyl("paint", 0.14, 0.3, Vector3(px, y + 0.24, d * 0.5), Color(0.62, 0.34, 0.22), 8)
			box("leaf", Vector3(0.36, 0.42, 0.36), Vector3(px, y + 0.58, d * 0.5), Color(0.2, 0.42, 0.18).darkened(_rng.randf() * 0.3), Basis(Vector3.UP, _rng.randf()), 0)
		elif r < 0.45:
			box("paint", Vector3(0.42, 0.04, 0.4), Vector3(px, y + 0.52, d * 0.45), Color(0.15, 0.16, 0.17), Basis(), 0)    # chaise de bistrot
			box("paint", Vector3(0.42, 0.42, 0.03), Vector3(px, y + 0.74, d * 0.45 - 0.19), Color(0.15, 0.16, 0.17), Basis(), 0)
			for s: float in [-1.0, 1.0]:
				box("paint", Vector3(0.03, 0.45, 0.03), Vector3(px + s * 0.18, y + 0.3, d * 0.45), Color(0.15, 0.16, 0.17), Basis(), 0)
		elif r < 0.5:
			box("metal", Vector3(0.8, 0.55, 0.42), Vector3(px, y + 0.36, d * 0.42), Color(0.82, 0.82, 0.8), Basis(), 0)     # climatiseur
		px += _rng.randf_range(1.2, 3.5)
	_detail = false


func _small_balcony(cx: float, ww: float, y: float) -> void:
	var w := ww + 0.6
	box("stone", Vector3(w, 0.14, 0.6), Vector3(cx, y, 0.3), c_trim, Basis(), NO_BACK)
	_railing(cx - w * 0.5, cx + w * 0.5, y + 0.07, 0.56, 0.95)
	_railing_side(cx - w * 0.5 + 0.02, y + 0.07, 0.56, 0.95)
	_railing_side(cx + w * 0.5 - 0.02, y + 0.07, 0.56, 0.95)


## Garde-corps : un panneau ajouré (texture alpha) et une main courante
func _railing(x0: float, x1: float, y: float, z: float, h: float, motif := -1) -> void:
	var w := x1 - x0
	var m := rail_motif if motif < 0 else motif
	quad("railing", Vector3((x0 + x1) * 0.5, y + h * 0.5, z), w, h, Rect2(0, float(m) / 3.0, w, 1.0 / 3.0))
	box("metal", Vector3(w, 0.05, 0.07), Vector3((x0 + x1) * 0.5, y + h, z), Color(0.06, 0.06, 0.065), Basis(), 0)


func _railing_side(x: float, y: float, d: float, h: float) -> void:
	quad("railing", Vector3(x, y + h * 0.5, d * 0.5), d, h, Rect2(0, float(rail_motif) / 3.0, d, 1.0 / 3.0), Color(1, 1, 1), Basis(Vector3.UP, PI * 0.5))
	box("metal", Vector3(0.05, 0.05, d), Vector3(x, y + h, d * 0.5), Color(0.06, 0.06, 0.065), Basis(), 0)


# ------------------------------------------------------------------ corniche, pignons, toit
func _cornice(len: float) -> void:
	var y := h0 + float(floors) * fh
	var key := _wall_trim_key()
	box(m_wall, Vector3(len, 0.7, WALL), Vector3(len * 0.5, y + 0.35, -WALL * 0.5), c_wall, Basis(), NO_BACK | NO_BOTTOM)
	match style:
		"deco":
			box(key, Vector3(len + 0.04, 0.12, 0.3), Vector3(len * 0.5, y + 0.06, 0.15), c_trim, Basis(), 0)
		"faubourg":
			box(key, Vector3(len + 0.02, 0.18, 0.3), Vector3(len * 0.5, y + 0.55, 0.15), c_trim, Basis(), 0)
			box(key, Vector3(len + 0.02, 0.1, 0.18), Vector3(len * 0.5, y + 0.4, 0.09), c_trim, Basis(), 0)
		_:
			box(key, Vector3(len, 0.2, 0.2), Vector3(len * 0.5, y + 0.1, 0.1), c_trim, Basis(), NO_BACK)
			box(key, Vector3(len, 0.18, 0.4), Vector3(len * 0.5, y + 0.3, 0.2), c_trim, Basis(), NO_BACK)
			box(key, Vector3(len + 0.02, 0.14, 0.58), Vector3(len * 0.5, y + 0.48, 0.29), c_trim, Basis(), NO_BACK)
			if not lod_far:
				_detail = true
				var x := 0.12
				var step := 0.18 if style == "haussmann" else 0.55
				while x < len - 0.05:
					if style == "haussmann":
						box(key, Vector3(0.07, 0.1, 0.12), Vector3(x, y + 0.26, 0.4), c_trim)   # denticules
					else:
						_console(x, y + 0.42, 0.22, 0.5)                                     # modillons
					x += step
				_detail = false


## Pignons aveugles : la partie du mur latéral qui dépasse du voisin (ou tout le mur s'il n'y a personne)
func _pignons() -> void:
	var top := height() + (0.0 if roof == "flat" else 2.6)
	for side in [0, 1]:
		var corner: bool = corner_l if side == 0 else corner_r
		if corner:
			continue
		var nh: float = left_h if side == 0 else right_h
		if nh >= top - 0.05:
			continue
		var y0 := maxf(nh - 0.2, 0.0)
		var x := 0.0 if side == 0 else width
		var sgn := -1.0 if side == 0 else 1.0
		var col := c_wall.darkened(0.08) if m_wall == "plaster" else Color(0.84, 0.81, 0.76)
		box("plaster", Vector3(0.2, top - y0, depth), Vector3(x - sgn * 0.1, (y0 + top) * 0.5, -depth * 0.5), col, Basis(), NO_BOTTOM)
		if top - y0 > 4.0:
			for k in 2:
				var zc := -depth * (0.3 + 0.4 * float(k))
				box("plaster", Vector3(0.25, top - y0 + 1.2, 0.7), Vector3(x + sgn * 0.12, (y0 + top + 1.2) * 0.5, zc), col.darkened(0.05), Basis(), NO_BOTTOM)
		if top - y0 > 9.0 and _rng.randf() < 0.4 and not lod_far:
			var lab := Label3D.new()
			lab.text = ["SAVON DE LUTÈCE", "CHOCOLAT DU PONT-NEUF", "GRANDS MAGASINS DU MARAIS", "QUINQUINA SAINT-MARTIN"][_rng.randi() % 4]
			lab.font = serif()
			lab.font_size = 128
			lab.pixel_size = 0.011
			lab.autowrap_mode = TextServer.AUTOWRAP_WORD
			lab.width = 1000.0
			lab.modulate = Color(0.93, 0.88, 0.75, 0.5)
			lab.outline_size = 0
			lab.shaded = true
			lab.double_sided = false
			lab.position = Vector3(x + sgn * 0.22, y0 + (top - y0) * 0.62, -depth * 0.5)
			lab.rotation.y = sgn * PI * 0.5
			add_child(lab)


func _build_roof() -> void:
	if roof == "flat":
		_flat_roof(height())
	else:
		_mansard(height())


## Comble mansardé : brisis raide (zinc, ardoise ou tuile), terrasson, lucarnes, cheminées, antennes
func _mansard(y: float) -> void:
	var h := 3.0
	var run := 1.2
	var key := "zinc" if roof == "zinc" else ("slate" if roof == "slate" else "tiles")
	var ang := atan2(run, h)
	var slen := sqrt(h * h + run * run)
	var faces: Array = [[Transform3D(), width]]
	if corner_r:
		faces.append([Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(width, 0, 0)), depth])
	if corner_l:
		faces.append([Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 0, -depth)), depth])
	var lk := (seed_v / 3) % 3
	for fc in faces:
		_xf = fc[0]
		var len: float = fc[1]
		box(key, Vector3(len, slen, 0.1), Vector3(len * 0.5, y + h * 0.5, -0.25 - run * 0.5), Color(1, 1, 1), Basis(Vector3.RIGHT, -ang), NO_BACK | NO_BOTTOM)
		box("metal", Vector3(len, 0.14, 0.18), Vector3(len * 0.5, y + 0.05, 0.02), Color(0.5, 0.52, 0.55), Basis(), NO_BACK)     # chéneau
		var bays := _bays(len, _bay_w(), _margin())
		for bi in bays.size():
			if style == "faubourg" and bi % 2 == 1:
				continue
			var c := bays[bi]
			var dz := -0.25 - run * 0.42
			var dy := y + h * 0.4
			var lw := 1.05
			box(_wall_trim_key(), Vector3(lw, 1.7, 1.0), Vector3(c, dy + 0.45, dz - 0.2), c_trim, Basis(), NO_BACK | NO_BOTTOM)
			var cell := _rng.randi() % 16
			quad("glass_lit" if _rng.randf() < 0.25 else "glass", Vector3(c, dy + 0.42, dz + 0.31), 0.7, 1.1, Rect2(float(cell % 8) / 8.0, float(cell / 8) / 2.0, 1.0 / 8.0, 0.45))
			if lk == 0:
				box("zinc", Vector3(lw + 0.2, 0.14, 1.2), Vector3(c, dy + 1.36, dz - 0.15), Color(1, 1, 1), Basis(), NO_BACK)
				box("zinc", Vector3(lw * 0.75, 0.14, 1.15), Vector3(c, dy + 1.48, dz - 0.15), Color(1, 1, 1), Basis(), NO_BACK)
				box("zinc", Vector3(lw * 0.4, 0.1, 1.1), Vector3(c, dy + 1.58, dz - 0.15), Color(1, 1, 1), Basis(), NO_BACK)
			elif lk == 1:
				for s: float in [-1.0, 1.0]:
					box("stone", Vector3(0.75, 0.1, 0.3), Vector3(c + s * 0.3, dy + 1.42, dz + 0.22), c_trim, Basis(Vector3.BACK, -s * 0.5), 0)
				box("zinc", Vector3(lw + 0.1, 0.1, 1.15), Vector3(c, dy + 1.32, dz - 0.18), Color(1, 1, 1), Basis(), NO_BACK)
			else:
				box("zinc", Vector3(lw + 0.2, 0.12, 1.25), Vector3(c, dy + 1.34, dz - 0.15), Color(1, 1, 1), Basis(Vector3.RIGHT, 0.12), NO_BACK)
			if not lod_far:
				_detail = true
				box("paint", Vector3(0.05, 1.1, 0.05), Vector3(c, dy + 0.42, dz + 0.33), c_frame)
				box("paint", Vector3(0.7, 0.05, 0.05), Vector3(c, dy + 0.72, dz + 0.33), c_frame)
				_detail = false
	_xf = Transform3D()
	# terrasson : couvre le reste du volume
	box("zinc", Vector3(width, 0.1, depth - run - 0.3), Vector3(width * 0.5, y + h + 0.05, -run - 0.25 - (depth - run - 0.3) * 0.5), Color(0.9, 0.92, 0.95), Basis(), NO_BOTTOM)
	# souches de cheminée
	var n := 2 + _rng.randi() % 3
	for i in n:
		var cx := width * (float(i) + 0.5) / float(n) + _rng.randf_range(-0.8, 0.8)
		var cz := -run - 1.5 - _rng.randf() * maxf(depth - run - 3.5, 0.5)
		var ch := _rng.randf_range(1.4, 2.4)
		var cw := _rng.randf_range(0.8, 1.6)
		var brickc := _rng.randf() < 0.6
		box("brick" if brickc else "plaster", Vector3(cw, ch, 0.6), Vector3(cx, y + h + ch * 0.5, cz), Color(1, 1, 1) if brickc else c_wall, Basis(), NO_BOTTOM)
		box("stone", Vector3(cw + 0.1, 0.1, 0.7), Vector3(cx, y + h + ch, cz), Color(0.8, 0.78, 0.74), Basis(), 0)
		var pots := maxi(int(cw / 0.28), 1)
		for p in pots:
			cyl("paint", 0.075, 0.42, Vector3(cx - cw * 0.5 + 0.14 + float(p) * (cw - 0.28) / float(maxi(pots - 1, 1)), y + h + ch + 0.26, cz), Color(0.66, 0.38, 0.26), 6)
	if not lod_far:
		_detail = true
		for i in _rng.randi_range(0, 2):
			var ax := _rng.randf_range(1.0, width - 1.0)
			cyl("metal", 0.025, 2.2, Vector3(ax, y + h + 1.1, -depth * 0.5), Color(0.5, 0.5, 0.52), 4, false)
			box("metal", Vector3(1.2, 0.03, 0.03), Vector3(ax, y + h + 1.9, -depth * 0.5), Color(0.5, 0.5, 0.52), Basis(Vector3.UP, _rng.randf()), 0)
		if _rng.randf() < 0.5:
			cyl("paint", 0.35, 0.06, Vector3(_rng.randf_range(1.0, width - 1.0), y + h + 0.4, -run - 0.9), Color(0.88, 0.88, 0.86), 10)
		_detail = false


## Toit-terrasse : acrotère, édicules, climatiseurs ; attique en retrait avec terrasse plantée (deco)
func _flat_roof(y: float) -> void:
	var tk := _wall_trim_key()
	var faces: Array = [[Transform3D(), width]]
	if corner_r:
		faces.append([Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(width, 0, 0)), depth])
	if corner_l:
		faces.append([Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 0, -depth)), depth])
	for fc in faces:
		_xf = fc[0]
		var len: float = fc[1]
		box(tk, Vector3(len, 0.9, 0.3), Vector3(len * 0.5, y + 0.45, -0.15), c_trim, Basis(), NO_BOTTOM)
	_xf = Transform3D()
	box("zinc", Vector3(width, 0.1, depth), Vector3(width * 0.5, y + 0.05, -depth * 0.5), Color(0.5, 0.5, 0.5), Basis(), NO_BOTTOM)
	if style == "deco":
		var ah := 2.8
		box("plaster", Vector3(width - 2.0, ah, depth - 3.0), Vector3(width * 0.5, y + ah * 0.5, -1.8 - (depth - 3.0) * 0.5), c_wall, Basis(), NO_BOTTOM)
		for c in _bays(width - 2.0, 2.9, 0.6):
			var cell := _rng.randi() % 16
			quad("glass_lit" if _rng.randf() < 0.35 else "glass", Vector3(1.0 + c, y + 1.3, -1.78), 1.8, 1.9, Rect2(float(cell % 8) / 8.0, float(cell / 8) / 2.0, 1.0 / 8.0, 0.5))
		box("plaster", Vector3(width - 1.6, 0.14, depth - 2.6), Vector3(width * 0.5, y + ah + 0.07, -1.8 - (depth - 3.0) * 0.5), c_trim, Basis(), 0)
		_railing(0.3, width - 0.3, y + 0.9, -0.15, 0.6, 2)
		if not lod_far:
			_detail = true
			var px := 1.0
			while px < width - 1.0:
				box("paint", Vector3(0.9, 0.45, 0.45), Vector3(px, y + 0.32, -0.8), Color(0.45, 0.42, 0.38), Basis(), NO_BOTTOM)
				box("leaf", Vector3(0.85, 0.5, 0.42), Vector3(px, y + 0.75, -0.8), Color(0.22, 0.42, 0.2).darkened(_rng.randf() * 0.25), Basis(Vector3.UP, _rng.randf() * 0.3), NO_BOTTOM)
				px += _rng.randf_range(1.8, 3.2)
			_detail = false
	box("plaster", Vector3(2.2, 2.4, 2.6), Vector3(width * _rng.randf_range(0.3, 0.7), y + 1.2, -depth * 0.6), c_wall.darkened(0.1), Basis(), NO_BOTTOM)
	for i in _rng.randi_range(1, 3):
		box("metal", Vector3(0.9, 0.6, 0.6), Vector3(_rng.randf_range(1.0, width - 1.0), y + 0.4, -depth * _rng.randf_range(0.45, 0.85)), Color(0.75, 0.76, 0.75), Basis(), NO_BOTTOM)
	for i in 2:
		box("brick", Vector3(0.8, 1.6, 0.6), Vector3(_rng.randf_range(1.0, width - 1.0), y + 0.8, -depth * 0.85), Color(1, 1, 1), Basis(), NO_BOTTOM)


# ------------------------------------------------------------------ ouvertures du rez-de-chaussée
func _shop_opening(cx: float, w: float, oh: float) -> void:
	var shop := Shop.new()
	shop.kind = Shop.pick_kind(_rng)
	shop.width = w
	shop.depth = SHOP_DEPTH
	shop.height = oh
	shop.crowd = crowd
	shop.building = self
	shop.position = _xf * Vector3(cx, 0.0, 0.0)
	shop.seed_v = _rng.randi()
	shop.lit = absf(global_position.x) < 120.0
	shop.frontage = _frontage(cx, w, oh, shop.kind, shop.seed_v)
	add_child(shop)
	shop_nodes.append(shop)


## Devanture : boiserie peinte (classique), moderne (cadre alu, caisson lumineux) ou pierre (banque)
func _frontage(cx: float, w: float, oh: float, kind: String, sv: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = sv
	var st := Shop.frontage_style(kind, r)
	var col: Color = Shop.frontage_color(kind, st, r)
	var fr := {"style": st, "color": col, "sign_y": oh + 0.3, "sign_z": 0.22, "sign_w": w + 0.3, "awning": false, "lit": false}
	match st:
		"boiserie":
			for s: float in [-1.0, 1.0]:
				box("paint", Vector3(0.3, oh, 0.2), Vector3(cx + s * (w * 0.5 + 0.12), oh * 0.5, 0.06), col, Basis(), NO_BACK)
				box("paint", Vector3(0.38, 0.14, 0.26), Vector3(cx + s * (w * 0.5 + 0.12), oh - 0.05, 0.08), col.lightened(0.1), Basis(), NO_BACK)
				box("paint", Vector3(0.36, 0.32, 0.24), Vector3(cx + s * (w * 0.5 + 0.12), 0.16, 0.08), col.darkened(0.2), Basis(), NO_BACK)
			box("paint", Vector3(w + 0.7, 0.62, 0.24), Vector3(cx, oh + 0.31, 0.09), col, Basis(), NO_BACK)
			box("paint", Vector3(w + 0.82, 0.08, 0.34), Vector3(cx, oh + 0.66, 0.12), col.lightened(0.12), Basis(), NO_BACK)
			box("paint", Vector3(w + 0.7, 0.04, 0.26), Vector3(cx, oh + 0.02, 0.1), Color(0.78, 0.62, 0.26), Basis(), NO_BACK)
			box("paint", Vector3(w, 0.42, 0.14), Vector3(cx, 0.21, 0.0), col, Basis(), NO_BACK)
			if not lod_far:
				_detail = true
				box("paint", Vector3(w - 0.3, 0.24, 0.03), Vector3(cx, 0.21, 0.08), col.lightened(0.14))
				box("paint", Vector3(w + 0.5, 0.42, 0.03), Vector3(cx, oh + 0.31, 0.22), col.darkened(0.12))
				_detail = false
			fr["sign_z"] = 0.25
			fr["awning"] = r.randf() < 0.55
		"pierre":
			for s: float in [-1.0, 1.0]:
				box("stone", Vector3(0.45, oh + 0.6, 0.18), Vector3(cx + s * (w * 0.5 + 0.2), (oh + 0.6) * 0.5, 0.06), Color(0.92, 0.9, 0.86), Basis(), NO_BACK)
			box("stone", Vector3(w + 0.85, 0.6, 0.2), Vector3(cx, oh + 0.3, 0.07), Color(0.9, 0.88, 0.84), Basis(), NO_BACK)
			box("metal", Vector3(w, 0.42, 0.1), Vector3(cx, 0.21, 0.0), Color(0.2, 0.22, 0.25), Basis(), NO_BACK)
			fr["sign_z"] = 0.18
		_:
			box("metal", Vector3(0.1, oh, 0.14), Vector3(cx - w * 0.5 - 0.02, oh * 0.5, 0.0), Color(0.22, 0.23, 0.25), Basis(), NO_BACK)
			box("metal", Vector3(0.1, oh, 0.14), Vector3(cx + w * 0.5 + 0.02, oh * 0.5, 0.0), Color(0.22, 0.23, 0.25), Basis(), NO_BACK)
			box("glow", Vector3(w + 0.3, 0.55, 0.22), Vector3(cx, oh + 0.3, 0.1), col, Basis(), NO_BACK)
			box("metal", Vector3(w, 0.42, 0.1), Vector3(cx, 0.21, 0.0), Color(0.18, 0.19, 0.2), Basis(), NO_BACK)
			fr["sign_z"] = 0.215
			fr["lit"] = true
	# store banne : le nom est imprimé sur le lambrequin (par la boutique)
	if fr["awning"]:
		var ac: Color = [Color(0.55, 0.08, 0.08), Color(0.08, 0.32, 0.18), Color(0.08, 0.16, 0.38), Color(0.72, 0.56, 0.18), Color(0.2, 0.2, 0.22)][r.randi() % 5]
		var drop := 1.6
		var ay := oh - 0.05
		box("cloth", Vector3(w + 0.4, 0.04, drop), Vector3(cx, ay - drop * 0.22, drop * 0.45 + 0.2), ac, Basis(Vector3.RIGHT, 0.45), 0)
		box("cloth", Vector3(w + 0.4, 0.3, 0.02), Vector3(cx, ay - drop * 0.43 - 0.15, drop * 0.9 + 0.2), ac.darkened(0.08), Basis(), 0)
		fr["awning_y"] = ay - drop * 0.43 - 0.15
		fr["awning_z"] = drop * 0.9 + 0.22
	fr["xf"] = _xf
	return fr


## Boutique décorative (non envahissable) : devanture et vitrine éclairée
func _fake_shop(cx: float, w: float, oh: float) -> void:
	var kind := Shop.pick_kind(_rng)
	var sv := _rng.randi()
	var fr := _frontage(cx, w, oh, kind, sv)
	var cell := _rng.randi() % 16
	quad("glass_dim" if _rng.randf() < 0.7 else "glass", Vector3(cx, 0.42 + (oh - 0.42) * 0.5, -0.3), w - 0.1, oh - 0.42, Rect2(float(cell % 8) / 8.0, float(cell / 8) / 2.0, 1.0 / 8.0, 0.5), Color(0.8, 0.75, 0.7))
	Shop.make_sign(self, kind, sv, fr, _xf * Vector3(cx, 0, 0))


func _closed_shop(cx: float, w: float, oh: float) -> void:
	var kind := Shop.pick_kind(_rng)
	var sv := _rng.randi()
	var fr := _frontage(cx, w, oh, kind, sv)
	var v := _rng.randi() % 4
	quad("rideau", Vector3(cx, (oh - 0.42) * 0.5 + 0.42, -0.1), w, oh - 0.42, Rect2(float(v) / 4.0, 0, 0.25, 1.0))
	box("metal", Vector3(w, 0.35, 0.3), Vector3(cx, oh - 0.17, -0.02), Color(0.4, 0.41, 0.42), Basis(), NO_BACK)
	Shop.make_sign(self, kind, sv, fr, _xf * Vector3(cx, 0, 0))


func _door(cx: float, w: float, h: float) -> void:
	var dh := h - 0.55
	var tk := _wall_trim_key()
	box(tk, Vector3(w + 0.5, 0.3, 0.12), Vector3(cx, h + 0.1, 0.06), c_trim, Basis(), NO_BACK)
	box(tk, Vector3(0.25, h, 0.08), Vector3(cx - w * 0.5 - 0.12, h * 0.5, 0.04), c_trim, Basis(), NO_BACK)
	box(tk, Vector3(0.25, h, 0.08), Vector3(cx + w * 0.5 + 0.12, h * 0.5, 0.04), c_trim, Basis(), NO_BACK)
	box("paint", Vector3(w, dh, 0.1), Vector3(cx, dh * 0.5, -0.22), c_door, Basis(), NO_BACK)
	quad("glass", Vector3(cx, dh + (h - dh) * 0.5, -0.24), w, h - dh, Rect2(0.0, 0.0, 0.125, 0.15))
	quad("railing", Vector3(cx, dh + (h - dh) * 0.5, -0.2), w, h - dh, Rect2(0, float(rail_motif) / 3.0, w * 0.5, 1.0 / 3.0))
	box("paint", Vector3(w, 0.08, 0.12), Vector3(cx, dh, -0.2), c_door.darkened(0.1), Basis(), NO_BACK)
	# embrasure de la porte
	box(m_wall if m_wall != "brick" else "stone", Vector3(w, 0.04, 0.3), Vector3(cx, h - 0.02, -0.12), c_base.darkened(0.3), Basis(), NO_BACK | NO_FRONT | NO_TOP)
	if not lod_far:
		_detail = true
		for s: float in [-1.0, 1.0]:
			var vx := cx + s * w * 0.25
			box("paint", Vector3(w * 0.5 - 0.2, dh * 0.36, 0.04), Vector3(vx, dh * 0.26, -0.15), c_door.lightened(0.07))
			box("paint", Vector3(w * 0.5 - 0.2, dh * 0.42, 0.04), Vector3(vx, dh * 0.71, -0.15), c_door.lightened(0.07))
			box("metal", Vector3(0.05, 0.05, 0.12), Vector3(cx + s * 0.12, dh * 0.5, -0.12), Color(0.78, 0.62, 0.26))
		box("paint", Vector3(0.06, dh, 0.06), Vector3(cx, dh * 0.5, -0.15), c_door.darkened(0.15))
		box("metal", Vector3(0.14, 0.24, 0.04), Vector3(cx + w * 0.5 + 0.12, 1.4, 0.1), Color(0.6, 0.62, 0.62))   # interphone
		_detail = false
	if number > 0 and _main_face:
		_number_plate(cx + w * 0.5 + 0.12, h - 0.45)


func _number_plate(x: float, y: float) -> void:
	box("paint", Vector3(0.3, 0.24, 0.02), Vector3(x, y, 0.13), Color(0.05, 0.12, 0.4), Basis(), NO_BACK)
	var lab := Label3D.new()
	lab.text = str(number)
	lab.font = sans()
	lab.font_size = 64
	lab.pixel_size = 0.0025
	lab.modulate = Color(0.95, 0.95, 0.95)
	lab.outline_size = 0
	lab.shaded = true
	lab.double_sided = false
	lab.position = Vector3(x, y, 0.145)
	lab.visibility_range_end = 35.0
	add_child(lab)


## Plaques de rue aux angles (émail bleu, liseré vert)
func _plates() -> void:
	if street_name == "":
		return
	for side in [0, 1]:
		if not (corner_l if side == 0 else corner_r):
			continue
		var x := 0.75 if side == 0 else width - 0.75
		var y := h0 + 0.55
		box("paint", Vector3(1.15, 0.38, 0.03), Vector3(x, y, 0.14), Color(0.1, 0.42, 0.25), Basis(), NO_BACK)
		box("paint", Vector3(1.09, 0.32, 0.035), Vector3(x, y, 0.145), Color(0.05, 0.12, 0.42), Basis(), NO_BACK)
		var lab := Label3D.new()
		lab.text = street_name
		lab.font = sans()
		lab.font_size = 48
		lab.pixel_size = minf(0.0028, 1.0 / maxf(float(street_name.length()) * 30.0, 1.0))
		lab.modulate = Color(0.95, 0.95, 0.95)
		lab.outline_size = 0
		lab.shaded = true
		lab.double_sided = false
		lab.position = Vector3(x, y, 0.165)
		lab.visibility_range_end = 40.0
		add_child(lab)


## Murs du rez-de-chaussée autour des boutiques : la façade entre les ouvertures, les cloisons, le fond
func _ground_colliders() -> void:
	var xs: Array = []
	for s in shop_nodes:
		var sh := s as Shop
		xs.append([sh.position.x - sh.width * 0.5, sh.position.x + sh.width * 0.5, sh.height])
	xs.sort_custom(func(a, b): return a[0] < b[0])
	var x0 := 0.0
	for r in xs:
		if r[0] - x0 > 0.05:
			collider(Vector3(r[0] - x0, h0, depth), Vector3((x0 + r[0]) * 0.5, h0 * 0.5, -depth * 0.5))
		collider(Vector3(r[1] - r[0], h0, depth - SHOP_DEPTH), Vector3((r[0] + r[1]) * 0.5, h0 * 0.5, -SHOP_DEPTH - (depth - SHOP_DEPTH) * 0.5))
		var lintel: float = h0 - r[2]
		collider(Vector3(r[1] - r[0], lintel, WALL), Vector3((r[0] + r[1]) * 0.5, h0 - lintel * 0.5, -WALL * 0.5))
		x0 = r[1]
	if width - x0 > 0.05:
		collider(Vector3(width - x0, h0, depth), Vector3((x0 + width) * 0.5, h0 * 0.5, -depth * 0.5))


# =================================================================== habitants
## Place d'habitant : pieds en `p` (repère de la façade), regard vers la rue. Le Transform3D stocké a son
## axe -Z (l'« avant » Godot) tourné vers la rue.
func _spot(p: Vector3, kind: String, f: int) -> void:
	if not _main_face:
		return
	resident_spots.append({"local": _xf * Transform3D(Basis(Vector3.UP, PI), p), "kind": kind, "floor": f})


## Places d'habitants en repère monde : [{"xf": Transform3D, "kind": "balcony" | "window", "floor": int}]
func spots_world() -> Array:
	var out: Array = []
	for s in resident_spots:
		out.append({"xf": global_transform * (s["local"] as Transform3D), "kind": s["kind"], "floor": s["floor"]})
	return out


# =================================================================== interactions
## Coups de pied (joueur, manifestants) : transmis à la vitrine la plus proche
func kick(point: Vector3, dir: Vector3, power := 1.0) -> bool:
	for s in shop_nodes:
		if (s as Shop).kick(point, dir, power):
			return true
	return false
