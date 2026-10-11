class_name CivilCar
extends PoliceVehicle
## Voiture civile garée : citadine, berline, break, SUV, ludospace utilitaire ou petite trois-portes, peinte au hasard
## (beaucoup de gris, noir et blanc, quelques couleurs vives), jantes variées, plaques françaises, vitres teintées et
## intérieur sombre (sièges, tableau de bord, volant).
## Elle réutilise tout le vandalisme des véhicules de police (bosses, vitres, feu, explosion) via `CivilDamage`,
## sans gyrophare, sirène ni radio, et n'est comptée ni dans `police.vehicles` ni dans le groupe « vehicles ».
## Frappée, elle déclenche son alarme : clignotants orange et sirène pendant ~20 s.
## Repère : l'avant est -Z, la largeur sur X, le sol à y = 0.

const PANE_COLOR := Color(0.03, 0.04, 0.05, 0.36)
const ALARM_TIME := 20.0

## Gabarits (m) : longueur, demi-largeur, empattement, porte-à-faux avant, roue (rayon, largeur), garde au sol,
## hauteur du capot, ligne de caisse, toit ; vitrage (pare-brise a0 -> a1, lunette c1 -> c0), pied milieu b,
## fin de porte arrière d, poupe (hatch / trunk / wagon / van).
const MODELS := {
	"citadine": {"L": 4.05, "hw": 0.87, "wb": 2.55, "foh": 0.82, "r": 0.31, "tw": 0.2, "clr": 0.25, "nose": 0.76, "belt": 0.98, "roof": 1.45,
		"a0": -0.78, "a1": -0.02, "c1": 1.22, "c0": 1.70, "deck": 0.99, "tail": "hatch", "gin": 0.12, "tum": 0.17, "b": 0.36, "d": 1.12,
		"doors": 4, "quarter": "glass"},
	"berline": {"L": 4.75, "hw": 0.915, "wb": 2.8, "foh": 0.95, "r": 0.33, "tw": 0.225, "clr": 0.22, "nose": 0.74, "belt": 0.97, "roof": 1.44,
		"a0": -0.85, "a1": -0.08, "c1": 1.02, "c0": 1.62, "deck": 1.02, "tail": "trunk", "gin": 0.13, "tum": 0.17, "b": 0.44, "d": 1.28,
		"doors": 4, "quarter": "paint"},
	"break": {"L": 4.62, "hw": 0.9, "wb": 2.72, "foh": 0.9, "r": 0.32, "tw": 0.215, "clr": 0.24, "nose": 0.76, "belt": 0.99, "roof": 1.48,
		"a0": -0.80, "a1": -0.05, "c1": 2.0, "c0": 2.18, "deck": 1.0, "tail": "wagon", "gin": 0.12, "tum": 0.15, "b": 0.42, "d": 1.25,
		"doors": 4, "quarter": "glass", "rails": true},
	"suv": {"L": 4.45, "hw": 0.92, "wb": 2.68, "foh": 0.88, "r": 0.36, "tw": 0.225, "clr": 0.3, "nose": 0.92, "belt": 1.12, "roof": 1.66,
		"a0": -0.68, "a1": 0.0, "c1": 1.62, "c0": 1.95, "deck": 1.12, "tail": "hatch", "gin": 0.12, "tum": 0.14, "b": 0.42, "d": 1.22,
		"doors": 4, "quarter": "glass", "rails": true, "clad": true},
	"ludospace": {"L": 4.35, "hw": 0.91, "wb": 2.72, "foh": 0.85, "r": 0.32, "tw": 0.21, "clr": 0.26, "nose": 0.95, "belt": 1.1, "roof": 1.86,
		"a0": -1.0, "a1": -0.22, "c1": 2.1, "c0": 2.14, "deck": 1.1, "tail": "van", "gin": 0.07, "tum": 0.08, "b": 0.2, "d": 1.0,
		"doors": 4, "quarter": "paint", "clad": true},
	"mini": {"L": 3.62, "hw": 0.83, "wb": 2.36, "foh": 0.68, "r": 0.29, "tw": 0.185, "clr": 0.24, "nose": 0.8, "belt": 1.0, "roof": 1.5,
		"a0": -0.85, "a1": -0.15, "c1": 0.98, "c0": 1.45, "deck": 1.0, "tail": "hatch", "gin": 0.11, "tum": 0.16, "b": 0.5, "d": 0.5,
		"doors": 2, "quarter": "glass"},
}

## Teintes (couleur, métallisée) : la rue parisienne est surtout grise, noire et blanche
const PAINTS := [
	[Color(0.42, 0.43, 0.45), true], [Color(0.42, 0.43, 0.45), true], [Color(0.26, 0.27, 0.29), true], [Color(0.26, 0.27, 0.29), true],
	[Color(0.62, 0.63, 0.65), true], [Color(0.62, 0.63, 0.65), true], [Color(0.025, 0.025, 0.028), false], [Color(0.025, 0.025, 0.028), false],
	[Color(0.04, 0.045, 0.05), true], [Color(0.86, 0.86, 0.85), false], [Color(0.86, 0.86, 0.85), false], [Color(0.8, 0.79, 0.76), true],
	[Color(0.06, 0.1, 0.2), true], [Color(0.12, 0.2, 0.36), true], [Color(0.45, 0.04, 0.05), true], [Color(0.62, 0.06, 0.05), false],
	[Color(0.45, 0.4, 0.33), true], [Color(0.18, 0.15, 0.12), true], [Color(0.85, 0.62, 0.05), false], [Color(0.85, 0.32, 0.06), false],
	[Color(0.14, 0.42, 0.5), false], [Color(0.3, 0.42, 0.24), true], [Color(0.1, 0.32, 0.72), true], [Color(0.55, 0.62, 0.66), false],
]

static var _cmats := {}
static var _cache := {}             # meshes partagés par gabarit / variante
static var _alarm_streams: Array = []
static var _tris := 0              # statistiques : triangles par voiture construite

var model := "citadine"
var paint_mat: StandardMaterial3D
var glass_rect: MeshInstance3D       # vitrage statique remplacé par les vitres cassables
var top_h := 1.5
var cabin := AABB()
var alarm_t := 0.0
var _blink: MeshInstance3D
var _alarm: AudioStreamPlayer3D
var _blink_ph := 0.0
var _p: Dictionary = {}              # gabarit en cours de construction


# ------------------------------------------------------------------ matériaux
static func cmat(key: String) -> Material:
	if _cmats.has(key):
		return _cmats[key]
	var r: StandardMaterial3D
	match key:
		"glass":
			r = MeshKit.std_mat(Color(0.03, 0.04, 0.05), 0.04, 0.0, 0.9)
			r.albedo_color.a = 0.58
			r.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			r.cull_mode = BaseMaterial3D.CULL_DISABLED
		"trim":
			r = MeshKit.std_mat(Color(0.035, 0.036, 0.04), 0.75, 0.0, 0.25)
		"gloss":
			r = MeshKit.std_mat(Color(0.012, 0.012, 0.014), 0.1, 0.0, 0.7)
		"chrome":
			r = MeshKit.std_mat(Color(0.75, 0.76, 0.78), 0.14, 1.0, 0.8)
		"head":
			r = MeshKit.std_mat(Color(0.8, 0.82, 0.86), 0.1, 0.35, 0.9)
			r.emission_enabled = true
			r.emission = Color(0.75, 0.8, 0.9)
			r.emission_energy_multiplier = 0.25
		"drl":
			r = MeshKit.std_mat(Color(0.9, 0.92, 0.95), 0.1, 0.0, 0.8)
		"tail":
			r = MeshKit.std_mat(Color(0.42, 0.015, 0.02), 0.1, 0.0, 0.8)
		"blink_off":
			r = MeshKit.std_mat(Color(0.62, 0.3, 0.04), 0.12, 0.0, 0.8)
		"blink_on":
			r = MeshKit.std_mat(Color(1.0, 0.6, 0.12), 0.12, 0.0, 0.8)
			r.emission_enabled = true
			r.emission = Color(1.0, 0.5, 0.06)
			r.emission_energy_multiplier = 7.0
		"well":
			r = MeshKit.std_mat(Color(0.012, 0.012, 0.012), 0.95, 0.0, 0.1)
		"tire":
			r = MeshKit.std_mat(Color(0.03, 0.03, 0.032), 0.88, 0.0, 0.25)
		"rim":
			r = MeshKit.std_mat(Color(0.66, 0.67, 0.7), 0.25, 0.9, 0.7)
		"rim_dark":
			r = MeshKit.std_mat(Color(0.07, 0.07, 0.08), 0.3, 0.7, 0.6)
		"hubcap":
			r = MeshKit.std_mat(Color(0.5, 0.51, 0.53), 0.4, 0.4, 0.5)
		"brake":
			r = MeshKit.std_mat(Color(0.22, 0.2, 0.19), 0.6, 0.6, 0.4)
		"seat_dark":
			r = MeshKit.std_mat(Color(0.05, 0.05, 0.055), 0.95, 0.0, 0.2)
		"seat_beige":
			r = MeshKit.std_mat(Color(0.4, 0.34, 0.27), 0.95, 0.0, 0.2)
		"headliner":
			r = MeshKit.std_mat(Color(0.32, 0.31, 0.3), 0.95, 0.0, 0.2)
		"plate":
			r = MeshKit.std_mat(Color(1, 1, 1), 0.45, 0.0, 0.5)
			r.albedo_texture = load("res://assets/quartier/plates.png")
		_:
			r = MeshKit.std_mat(Color(0.5, 0.5, 0.5))
	_cmats[key] = r
	return r


## Peinture (partagée entre voitures de même teinte) ; `dusty` : voiture qui n'a pas vu la pluie depuis longtemps
static func paint(c: Color, metal: bool, dusty := false) -> StandardMaterial3D:
	var key := "paint_%s_%s_%s" % [c.to_html(false), metal, dusty]
	if _cmats.has(key):
		return _cmats[key]
	var r := MeshKit.std_mat(c, 0.34 if metal else 0.3, 0.6 if metal else 0.0, 0.6)
	r.clearcoat_enabled = true
	r.clearcoat = 0.9 if not dusty else 0.25
	r.clearcoat_roughness = 0.08 if not dusty else 0.5
	if dusty:
		r.albedo_color = c.lerp(Color(0.42, 0.4, 0.36), 0.18)
		r.roughness = 0.62
	_cmats[key] = r
	return r


# ------------------------------------------------------------------ construction
## `opts` : paint (index de PAINTS), rim (0..3), roof_black, beige, steer (-1..1), plate (0..17), dusty
func build_civil(m: String, opts: Dictionary, rng: RandomNumberGenerator) -> void:
	model = m
	kind = "civil"
	civil_init(MODELS[m])
	var pc: Array = PAINTS[int(opts.get("paint", rng.randi() % PAINTS.size()))]
	paint_mat = paint(pc[0], pc[1], opts.get("dusty", false))
	_body = Node3D.new()
	_body.name = "Caisse"
	var holder := Node3D.new()
	holder.name = "Chassis"
	add_child(holder)
	holder.add_child(_body)
	var roof_black: bool = opts.get("roof_black", false) and m != "ludospace"
	var beige: bool = opts.get("beige", false)
	var bkey := "%s_%s_%s" % [m, roof_black, beige]
	if not _cache.has(bkey):
		_cache[bkey] = _build_body_meshes(roof_black, beige)
	var bm: Dictionary = _cache[bkey]
	GeoBatch.instance(bm["paint"], _body, true, 0.0, paint_mat)
	if bm["roofb"] != null:
		GeoBatch.instance(bm["roofb"], _body, true, 0.0)
	GeoBatch.instance(bm["misc"], _body, false, 70.0)
	GeoBatch.instance(bm["near"], _body, false, 38.0)
	glass_rect = GeoBatch.instance(bm["glass_rect"], _body, false, 0.0, cmat("glass"))
	GeoBatch.instance(bm["glass_fix"], _body, false, 0.0, cmat("glass"))
	_blink = GeoBatch.instance(bm["blink"], _body, false, 90.0, cmat("blink_off"))
	var steer := clampf(float(opts.get("steer", 0.0)), -1.0, 1.0)
	var rim: int = int(opts.get("rim", 0))
	var wkey := "%s_w%d_%d" % [m, rim, int(roundf(steer * 2.0))]
	if not _cache.has(wkey):
		_cache[wkey] = _build_wheels(rim, roundf(steer * 2.0) * 0.16)
	GeoBatch.instance(_cache[wkey], holder, true, 0.0)
	var pkey := "%s_plate%d" % [m, int(opts.get("plate", 0)) % 18]
	if not _cache.has(pkey):
		_cache[pkey] = _build_plates(int(opts.get("plate", 0)) % 18)
	GeoBatch.instance(_cache[pkey], _body, false, 30.0, cmat("plate"))
	_build_collision_civil()
	add_to_group("breakable")          # coup de pied du joueur (sans provoquer les CRS)
	add_to_group("civil_cars")
	damage = CivilDamage.new()
	damage.name = "Degats"
	add_child(damage)
	damage.setup(self)
	(damage as CivilDamage).pane_specs = bm["panes"]
	set_physics_process(false)


## Dimensions dérivées du gabarit (encombrement, habitacle, hauteur)
func civil_init(p: Dictionary) -> void:
	_p = p
	half = Vector2(p["hw"] + 0.03, p["L"] * 0.5)
	_hw = p["hw"]
	top_h = p["roof"]
	var wb_: float = p["hw"] - p["gin"]
	cabin = AABB(Vector3(-wb_, p["belt"], p["a0"]), Vector3(wb_ * 2.0, p["roof"] - p["belt"], p["c0"] - p["a0"]))


# --- géométrie de la caisse (repère local) ---------------------------------
func _zf() -> float:
	return -float(_p["L"]) * 0.5


func _zr() -> float:
	return float(_p["L"]) * 0.5


## Bords du pavillon vitré : demi-largeur à la ceinture, sous le toit ; hauteur sous le toit
func _wb() -> float:
	return float(_p["hw"]) - float(_p["gin"])


func _wr() -> float:
	return _wb() - float(_p["tum"])


func _yrs() -> float:
	return float(_p["roof"]) - 0.045


## Point du flanc vitré (côté sx) : z le long de la voiture, t de 0 (ceinture) à 1 (toit)
func _sp(sx: float, z: float, t: float, off := 0.0) -> Vector3:
	var y_b: float = _p["belt"]
	var p := Vector3(sx * lerpf(_wb(), _wr(), t), lerpf(y_b, _yrs(), t), z)
	return p + _side_n(sx) * off


func _side_n(sx: float) -> Vector3:
	var y_b: float = _p["belt"]
	return Vector3(sx * (_yrs() - y_b), _wb() - _wr(), 0).normalized()


func _side_v(sx: float) -> Vector3:
	var y_b: float = _p["belt"]
	return Vector3(sx * (_wr() - _wb()), _yrs() - y_b, 0)


## Montant avant / arrière du flanc à la hauteur t
func _zfront(t: float) -> float:
	return lerpf(_p["a0"], _p["a1"], t)


func _zrear(t: float) -> float:
	return lerpf(_p["c0"], _p["c1"], t)


## Pare-brise : x en mètres, t de 0 (base) à 1 (toit)
func _ws(x: float, t: float, off := 0.0) -> Vector3:
	var y_b: float = _p["belt"]
	var dy := _yrs() - y_b
	var dz: float = float(_p["a1"]) - float(_p["a0"])
	var n := Vector3(0, dz, -dy).normalized()
	return Vector3(x, lerpf(y_b, _yrs(), t), lerpf(_p["a0"], _p["a1"], t)) + n * off


func _rw(x: float, t: float, off := 0.0) -> Vector3:
	var y_b: float = _p["belt"]
	var dy := _yrs() - y_b
	var n := Vector3(0, float(_p["c0"]) - float(_p["c1"]), dy).normalized()
	return Vector3(x, lerpf(y_b, _yrs(), t), lerpf(_p["c0"], _p["c1"], t)) + n * off


## Profil de la caisse basse : [z, bas, haut, facteur de demi-largeur]
func _stations() -> Array:
	var zf := _zf()
	var zr := _zr()
	var nose: float = _p["nose"]
	var belt: float = _p["belt"]
	var deck: float = _p["deck"]
	var clr: float = _p["clr"]
	var a0: float = _p["a0"]
	var c0: float = _p["c0"]
	var st: Array = []
	# nez arrondi : le pare-chocs avance, le haut de la face recule
	st.append([zf, 0.33, lerpf(0.33, nose, 0.55), 0.72])
	st.append([zf + 0.025, 0.29, nose - 0.075, 0.84])
	st.append([zf + 0.07, 0.27, nose - 0.03, 0.92])
	st.append([zf + 0.15, clr + 0.04, nose - 0.006, 0.965])
	st.append([zf + 0.32, clr + 0.01, lerpf(nose, belt - 0.02, 0.25), 0.99])
	var n := 4
	for i in n:
		var t := float(i + 1) / float(n + 1)
		var z := lerpf(zf + 0.32, a0, t)
		st.append([z, clr, lerpf(nose, belt - 0.02, 0.25 + 0.75 * pow(t, 0.8)), 1.0])
	st.append([a0, clr, belt - 0.015, 1.0])
	var tail: String = _p["tail"]
	var cab_end := c0 if tail != "van" and tail != "wagon" else c0 - 0.05
	for i in 3:
		var z2 := lerpf(a0, cab_end, float(i + 1) / 4.0)
		st.append([z2, clr, belt, 1.0])
	if tail == "trunk":
		st.append([c0, clr, deck - 0.005, 1.0])
		st.append([lerpf(c0, zr - 0.18, 0.5), clr + 0.01, deck, 0.995])
		st.append([zr - 0.18, clr + 0.04, deck - 0.01, 0.985])
	else:
		st.append([cab_end, clr, deck, 1.0])
		st.append([zr - 0.32, clr + 0.02, deck, 0.99])
		st.append([zr - 0.13, clr + 0.08, deck - 0.004, 0.97])
	st.append([zr - 0.06, 0.31, deck - 0.03, 0.92])
	st.append([zr - 0.02, 0.33, deck - 0.075, 0.85])
	st.append([zr, 0.37, deck - 0.14, 0.76])
	return st


## Section en rectangle arrondi (28 points) : flancs légèrement rentrés en haut
func _csection(z: float, y0: float, y1: float, hw: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var h := y1 - y0
	var rt := minf(0.14, h * 0.42)
	var rb := minf(0.08, h * 0.3)
	var hw_top := hw - 0.035
	var hw_bot := hw - 0.015
	# centres des arrondis : bas droit, haut droit, haut gauche, bas gauche
	var corners := [[Vector2(hw_bot - rb, y0 + rb), rb, -PI * 0.5, 0.0], [Vector2(hw_top - rt, y1 - rt), rt, 0.0, PI * 0.5],
		[Vector2(-hw_top + rt, y1 - rt), rt, PI * 0.5, PI], [Vector2(-hw_bot + rb, y0 + rb), rb, PI, PI * 1.5]]
	var yl := y0 + rb
	var yh := y1 - rt
	for ci in 4:
		var c: Array = corners[ci]
		for k in 6:
			var a: float = lerpf(c[2], c[3], float(k) / 5.0)
			var cc: Vector2 = c[0]
			pts.append(Vector3(cc.x + cos(a) * c[1], cc.y + sin(a) * c[1], z))
		# flancs galbés : renflement bas de porte, puis épaulement marqué sous la ceinture
		if ci == 0 or ci == 2:
			var sg := 1.0 if ci == 0 else -1.0
			var lst := [[0.3, 0.012], [0.72, 0.018]]
			if ci == 2:
				lst.reverse()
			for q in lst:
				var t: float = q[0]
				var x := lerpf(hw_bot, hw_top, t) + float(q[1]) * clampf(h / 0.5, 0.0, 1.0)
				pts.append(Vector3(sg * x, lerpf(yl, yh, t), z))
	return pts


## Hauteur du dessus de caisse à l'abscisse z (capot, ceinture, coffre)
func _top_at(z: float) -> float:
	var st := _stations()
	for i in st.size() - 1:
		if z >= st[i][0] and z <= st[i + 1][0]:
			return lerpf(st[i][2], st[i + 1][2], (z - st[i][0]) / maxf(st[i + 1][0] - st[i][0], 0.001))
	return st[0][2] if z < st[0][0] else st[-1][2]


## Demi-largeur du flanc de caisse à la hauteur y (zone centrale)
func _side_x(y: float) -> float:
	var hw: float = _p["hw"]
	var clr: float = _p["clr"]
	var belt: float = _p["belt"]
	var t := clampf((y - clr) / maxf(belt - clr, 0.01), 0.0, 1.0)
	return lerpf(hw - 0.015, hw - 0.035, t) + 0.016 * sin(clampf(t * 1.15, 0.0, 1.0) * PI) + 0.004


func _build_body_meshes(roof_black: bool, beige: bool) -> Dictionary:
	var b := GeoBatch.new()
	var pm := cmat("paint_slot")     # remplacé par la peinture de chaque voiture (material_override)
	var P := _p
	var hw: float = P["hw"]
	var belt: float = P["belt"]
	var clr: float = P["clr"]
	var nose: float = P["nose"]
	var deck: float = P["deck"]
	var a0: float = P["a0"]
	var a1: float = P["a1"]
	var c0: float = P["c0"]
	var c1: float = P["c1"]
	var bz: float = P["b"]
	var dz: float = P["d"]
	var zf := _zf()
	var zr := _zr()
	var w_b := _wb()
	var w_r := _wr()
	var yrs := _yrs()
	var tail: String = P["tail"]
	var clad: bool = P.get("clad", false)
	var r: float = P["r"]
	var axf := zf + float(P["foh"])
	var axr := axf + float(P["wb"])
	# --- caisse basse
	var rings: Array = []
	for s in _stations():
		rings.append(_csection(s[0], s[1], s[2], hw * float(s[3])))
	b.add_mesh("paint", pm, MeshKit.loft(rings, true, true))
	# --- toit bombé (débord léger au-dessus des vitres)
	var roof_m := cmat("gloss") if roof_black else pm
	var roof_key := "roofb" if roof_black else "paint"
	var rr: Array = []
	var nz := 6
	for i in nz:
		var t := float(i) / float(nz - 1)
		var z := lerpf(a1 - 0.015, c1 + 0.015, t)
		var endk := 1.0 - 0.6 * pow(absf(t * 2.0 - 1.0), 6.0)
		var ring := PackedVector3Array()
		for k in 11:
			var u := float(k) / 10.0 * 2.0 - 1.0
			var x := u * (w_r + 0.018)
			var y := yrs + 0.045 * endk * (1.0 - pow(absf(u), 2.6)) - 0.012 * pow(absf(u), 8.0)
			ring.append(Vector3(x, y, z))
		rr.append(ring)
	b.grid(roof_key, roof_m, rr, Vector3.UP)
	# ciel de toit, vu à travers les vitres
	b.quad("liner", cmat("headliner"), Vector3(-w_r, yrs - 0.006, a1), Vector3(w_r, yrs - 0.006, a1), Vector3(w_r, yrs - 0.006, c1), Vector3(-w_r, yrs - 0.006, c1))
	# --- vitrage : flancs
	var sail := 0.05            # largeur des montants sur le flanc
	for sx: float in [-1.0, 1.0]:
		var n := _side_n(sx)
		var t0 := 0.06
		var t1 := 0.93
		var zfa := _zfront(t1) + sail
		var front_end := bz - 0.045 if int(P["doors"]) == 4 else dz - 0.03
		# vitre de porte avant (rectangle cassable) + custode avant fixe
		_side_rect(b, sx, zfa, front_end, t0, t1, "side")
		_side_poly(b, "glass_fix", cmat("glass"), sx, [[_zfront(t0) + sail, t0], [zfa, t0], [zfa, t1]], 0.0)
		_side_poly(b, "gloss", cmat("gloss"), sx, [[zfa - 0.012, t0], [zfa + 0.012, t0], [zfa + 0.012, t1], [zfa - 0.012, t1]], 0.003)
		var z_q0 := front_end + 0.03
		if int(P["doors"]) == 4:
			# pied milieu noir et vitre de porte arrière
			_side_poly(b, "gloss", cmat("gloss"), sx, [[bz - 0.045, 0.0], [bz + 0.045, 0.0], [bz + 0.045, 1.0], [bz - 0.045, 1.0]], 0.003)
			var rear_end := minf(dz - 0.03, _zrear(t1) - 0.08)
			_side_rect(b, sx, bz + 0.045, rear_end, t0, t1, "side")
			z_q0 = rear_end + 0.03
			_side_poly(b, "gloss", cmat("gloss"), sx, [[rear_end - 0.005, t0], [rear_end + 0.025, t0], [rear_end + 0.025, t1], [rear_end - 0.005, t1]], 0.003)
		# custode arrière : vitre fixe ou tôle
		var zq_b := _zrear(t0) - 0.07
		var zq_t := _zrear(t1) - 0.07
		if zq_b > z_q0 + 0.05 or zq_t > z_q0 + 0.05:
			var pts := [[z_q0, t0], [maxf(zq_b, z_q0), t0], [maxf(zq_t, z_q0), t1], [z_q0, t1]]
			if P["quarter"] == "glass":
				_side_poly(b, "glass_fix", cmat("glass"), sx, pts, 0.0)
			else:
				_side_poly(b, "paint", pm, sx, [[z_q0 - 0.01, 0.0], [_zrear(0.0), 0.0], [_zrear(1.0), 1.0], [z_q0 - 0.01, 1.0]], 0.004)
		# joints : baguette de ceinture, joint de pavillon
		var belt_m := cmat("chrome") if P["tail"] == "trunk" else cmat("gloss")
		var belt_k := "chrome" if P["tail"] == "trunk" else "gloss"
		_side_poly(b, belt_k, belt_m, sx, [[_zfront(0.0) + 0.02, 0.0], [_zrear(0.0) - 0.02, 0.0], [_zrear(t0) - 0.02, t0], [_zfront(t0) + 0.02, t0]], 0.002)
		_side_poly(b, "gloss", cmat("gloss"), sx, [[_zfront(t1), t1], [_zrear(t1), t1], [_zrear(1.0), 1.0], [_zfront(1.0), 1.0]], 0.002)
		# montant de pare-brise (pliure flanc / pare-brise) et montant arrière
		var sk := roof_key
		var smat := roof_m
		_side_poly(b, sk, smat, sx, [[_zfront(0.0), 0.0], [_zfront(0.0) + sail, 0.0], [_zfront(1.0) + sail, 1.0], [_zfront(1.0), 1.0]], 0.005)
		b.poly_facing(sk, smat, PackedVector3Array([_ws(sx * w_b, 0.0, 0.005), _ws(sx * w_r, 1.0, 0.005), _ws(sx * (w_r - 0.065), 1.0, 0.005), _ws(sx * (w_b - 0.065), 0.0, 0.005)]), _ws_n())
		var cw := 0.09 if tail != "van" else 0.06
		_side_poly(b, sk if P["quarter"] == "glass" else "paint", smat if P["quarter"] == "glass" else pm, sx, [[_zrear(0.0) - cw, 0.0], [_zrear(0.0), 0.0], [_zrear(1.0), 1.0], [_zrear(1.0) - cw, 1.0]], 0.005)
		b.poly_facing(sk, smat, PackedVector3Array([_rw(sx * w_b, 0.0, 0.005), _rw(sx * w_r, 1.0, 0.005), _rw(sx * (w_r - 0.06), 1.0, 0.005), _rw(sx * (w_b - 0.06), 0.0, 0.005)]), _rw_n())
		# flanc arrière plein (ludospace) : tôle sur toute la custode
		if tail == "van":
			pass
	# pare-brise et lunette : rectangle cassable + coins fixes
	var wsm := 0.07
	var ws_hw := w_r - wsm
	_plane_rect(b, "ws", ws_hw, 0.03, 0.97)
	for sx: float in [-1.0, 1.0]:
		b.poly_facing("glass_fix", cmat("glass"), PackedVector3Array([_ws(sx * ws_hw, 0.03), _ws(sx * (w_b - 0.05), 0.03), _ws(sx * (w_r - 0.05), 0.97), _ws(sx * ws_hw, 0.97)]), _ws_n())
	_plane_rect(b, "rear", w_r - 0.07, 0.04, 0.95)
	for sx: float in [-1.0, 1.0]:
		b.poly_facing("glass_fix", cmat("glass"), PackedVector3Array([_rw(sx * (w_r - 0.07), 0.04), _rw(sx * (w_b - 0.05), 0.04), _rw(sx * (w_r - 0.05), 0.95), _rw(sx * (w_r - 0.07), 0.95)]), _rw_n())
	# joint noir autour du pare-brise et de la lunette (haut / bas)
	b.poly_facing("gloss", cmat("gloss"), PackedVector3Array([_ws(-w_b, 0.0, 0.002), _ws(w_b, 0.0, 0.002), _ws(w_b, 0.03, 0.002), _ws(-w_b, 0.03, 0.002)]), _ws_n())
	b.poly_facing("gloss", cmat("gloss"), PackedVector3Array([_ws(-w_r, 0.97, 0.002), _ws(w_r, 0.97, 0.002), _ws(w_r, 1.0, 0.002), _ws(-w_r, 1.0, 0.002)]), _ws_n())
	b.poly_facing("gloss", cmat("gloss"), PackedVector3Array([_rw(-w_b, 0.0, 0.002), _rw(w_b, 0.0, 0.002), _rw(w_b, 0.04, 0.002), _rw(-w_b, 0.04, 0.002)]), _rw_n())
	b.poly_facing("gloss", cmat("gloss"), PackedVector3Array([_rw(-w_r, 0.95, 0.002), _rw(w_r, 0.95, 0.002), _rw(w_r, 1.0, 0.002), _rw(-w_r, 1.0, 0.002)]), _rw_n())
	# --- intérieur : plancher sombre à la ceinture, planche de bord, sièges, volant
	var seat_m := cmat("seat_beige") if beige else cmat("seat_dark")
	var seat_k := "seat_beige" if beige else "seat_dark"
	b.quad("trim", cmat("trim"), Vector3(-w_b + 0.01, belt + 0.004, a0 + 0.02), Vector3(w_b - 0.01, belt + 0.004, a0 + 0.02), Vector3(w_b - 0.01, belt + 0.004, c0 - 0.02), Vector3(-w_b + 0.01, belt + 0.004, c0 - 0.02))
	b.box("near", cmat("trim"), Vector3(w_b * 2.0 - 0.12, 0.16, 0.5), Vector3(0, belt + 0.02, a0 + 0.3), Basis(Vector3.RIGHT, -0.12), 0.04)
	var fz := bz + 0.12 if int(P["doors"]) == 4 else bz - 0.05
	for sx: float in [-1.0, 1.0]:
		b.box("near", seat_m, Vector3(0.5, 0.42, 0.13), Vector3(sx * 0.37 * (w_b / 0.75), belt + 0.12, fz), Basis(Vector3.RIGHT, 0.22), 0.05)
		b.box("near", seat_m, Vector3(0.27, 0.17, 0.11), Vector3(sx * 0.37 * (w_b / 0.75), belt + 0.4, fz + 0.07), Basis(Vector3.RIGHT, 0.15), 0.04)
	var rz := minf(c0 - 0.3, fz + 0.85) if tail != "trunk" else c0 - 0.2
	if rz > fz + 0.45:
		b.box("near", seat_m, Vector3(w_b * 2.0 - 0.16, 0.36, 0.13), Vector3(0, belt + 0.1, rz), Basis(Vector3.RIGHT, 0.2), 0.05)
		for k in 2:
			b.box("near", seat_m, Vector3(0.24, 0.14, 0.1), Vector3((float(k) - 0.5) * 0.74 * (w_b / 0.75), belt + 0.34, rz + 0.06), Basis(Vector3.RIGHT, 0.15), 0.04)
	var wheel := TorusMesh.new()
	wheel.inner_radius = 0.16
	wheel.outer_radius = 0.19
	wheel.rings = 16
	wheel.ring_segments = 6
	b.add_mesh("near", cmat("trim"), wheel, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.45), Vector3(-0.37 * (w_b / 0.75), belt + 0.17, a0 + 0.62)))
	# --- avant : calandre, prise d'air, phares, clignotants, essuie-glaces
	var face_z := zf + 0.01
	b.box("trim", cmat("trim"), Vector3(w_b * 2.0, 0.05, 0.16), Vector3(0, belt - 0.01, a0 + 0.06), Basis(), 0.01)
	for sx: float in [-1.0, 1.0]:
		b.box("trim", cmat("trim"), Vector3(0.5, 0.018, 0.02), Vector3(sx * 0.25 - 0.1, belt + 0.03, a0 + 0.12), Basis(Vector3.UP, 0.12 * sx), 0.005)
	var grille_w := hw * (0.95 if tail == "van" else 0.82)
	var gy := nose - 0.155
	b.box("gloss", cmat("gloss"), Vector3(grille_w, 0.15, 0.1), Vector3(0, gy, zf + 0.06), Basis(Vector3.RIGHT, 0.25), 0.035)
	for k in 3:
		b.box("trim", cmat("trim"), Vector3(grille_w - 0.06, 0.012, 0.1), Vector3(0, gy - 0.045 + 0.045 * k, zf + 0.055), Basis(Vector3.RIGHT, 0.25), 0.0)
	b.box("chrome", cmat("chrome"), Vector3(grille_w + 0.02, 0.016, 0.1), Vector3(0, gy + 0.08, zf + 0.075), Basis(Vector3.RIGHT, 0.25), 0.007)
	# bouclier : prise d'air basse
	b.box("trim", cmat("trim"), Vector3(hw * 1.05, 0.1, 0.1), Vector3(0, 0.37, zf + 0.04), Basis(), 0.04)
	if clad:
		b.box("trim", cmat("trim"), Vector3(hw * 1.55, 0.09, 0.08), Vector3(0, 0.3, zf + 0.07), Basis(), 0.04)
	var hl_y := nose - 0.1
	for sx: float in [-1.0, 1.0]:
		var hb := Basis(Vector3.UP, -sx * 0.5) * Basis(Vector3.RIGHT, -0.2)
		var hx := sx * hw * 0.64
		var hz := zf + 0.13
		var hwid := 0.4 if tail != "van" else 0.3
		b.box("gloss", cmat("gloss"), Vector3(hwid + 0.03, 0.14, 0.14), Vector3(hx, hl_y, hz), hb, 0.035)
		b.box("misc_head", cmat("head"), Vector3(hwid, 0.115, 0.14), Vector3(hx, hl_y + 0.004, hz + 0.008), hb, 0.03)
		b.box("drl", cmat("drl"), Vector3(hwid * 0.8, 0.02, 0.14), Vector3(hx, hl_y - 0.045, hz + 0.012), hb, 0.007)
		b.box("blink", cmat("blink_off"), Vector3(0.08, 0.05, 0.12), Vector3(sx * hw * 0.86, hl_y + 0.01, zf + 0.26), hb, 0.02)
		# antibrouillard
		b.box("misc_head", cmat("head"), Vector3(0.1, 0.06, 0.04), Vector3(sx * hw * 0.68, 0.36, face_z + 0.04), Basis(), 0.02)
	# --- arrière : feux, hayon, pare-chocs, sortie d'échappement
	var tl_y := deck - 0.13
	for sx: float in [-1.0, 1.0]:
		var tb := Basis(Vector3.UP, sx * 0.45)
		b.box("tail", cmat("tail"), Vector3(0.3, 0.13 if tail != "van" else 0.34, 0.12), Vector3(sx * hw * 0.74, tl_y - (0.08 if tail == "van" else 0.0), zr - 0.08), tb, 0.03)
		b.box("blink", cmat("blink_off"), Vector3(0.1, 0.04, 0.1), Vector3(sx * hw * 0.74, tl_y - 0.04 - (0.16 if tail == "van" else 0.0), zr - 0.075), tb, 0.01)
		# rétroviseur
		var mz := a0 + 0.2
		var mx := sx * (w_b + 0.12)
		b.box(roof_key if roof_black else "paint", roof_m if roof_black else pm, Vector3(0.2, 0.12, 0.1), Vector3(mx, belt + 0.07, mz), Basis(Vector3.UP, sx * 0.12), 0.04)
		b.box("trim", cmat("trim"), Vector3(0.1, 0.04, 0.06), Vector3(sx * (w_b + 0.04), belt + 0.03, mz + 0.02), Basis(), 0.01)
		b.box("gloss", cmat("gloss"), Vector3(0.16, 0.09, 0.01), Vector3(mx, belt + 0.07, mz + 0.05), Basis(Vector3.UP, sx * 0.12), 0.004)
		b.box("blink", cmat("blink_off"), Vector3(0.08, 0.015, 0.03), Vector3(mx + sx * 0.06, belt + 0.03, mz - 0.03), Basis(), 0.005)
	# feu stop central (hayons)
	if tail != "trunk":
		b.box("tail", cmat("tail"), Vector3(0.3, 0.03, 0.03), _rw(0.0, 0.97, 0.03), Basis(), 0.01)
	b.box("trim", cmat("trim"), Vector3(hw * 1.7, 0.12, 0.08), Vector3(0, 0.37, zr - 0.02), Basis(), 0.04)
	b.cyl("chrome", cmat("chrome"), 0.035, 0.035, 0.16, Vector3(-hw * 0.6, 0.3, zr - 0.04), Basis(Vector3.RIGHT, PI * 0.5), 10)
	# --- flancs : passages de roues, lignes de portes, poignées, bas de caisse
	for wz: float in [axf, axr]:
		for sx: float in [-1.0, 1.0]:
			_arch(b, sx, wz, r, clr, clad, pm)
	for sx: float in [-1.0, 1.0]:
		var xs := _side_x(belt * 0.6 + clr * 0.4)
		var seams: Array = [a0 - 0.12, bz]
		if int(P["doors"]) == 4:
			seams.append(dz)
		else:
			seams = [a0 - 0.12, dz]
		for z in seams:
			var y_lo := clr + 0.06
			var y_hi := belt - 0.02
			_seam(b, sx, z, y_lo, y_hi)
		# poignées
		var handles: Array = [bz - 0.2]
		if int(P["doors"]) == 4:
			handles.append(dz - 0.2)
		else:
			handles = [dz - 0.25]
		for hz in handles:
			var yh := belt - 0.1
			b.box("chrome" if tail == "trunk" else "paint", cmat("chrome") if tail == "trunk" else pm, Vector3(0.025, 0.035, 0.16), Vector3(sx * (_side_x(yh) + 0.01), yh, hz), Basis(), 0.012)
		# bas de caisse
		if clad:
			b.quad("trim", cmat("trim"), Vector3(sx * (xs + 0.012), clr + 0.13, axf + r + 0.08), Vector3(sx * (xs + 0.012), clr + 0.13, axr - r - 0.08), Vector3(sx * (xs + 0.012), clr + 0.01, axr - r - 0.08), Vector3(sx * (xs + 0.012), clr + 0.01, axf + r + 0.08))
	# rails de toit
	if P.get("rails", false):
		for sx: float in [-1.0, 1.0]:
			b.box("chrome" if P["tail"] == "wagon" else "gloss", cmat("chrome") if P["tail"] == "wagon" else cmat("gloss"), Vector3(0.035, 0.035, c1 - a1 - 0.1), Vector3(sx * (w_r - 0.06), yrs + 0.075, (a1 + c1) * 0.5), Basis(), 0.012)
			for z in [a1 + 0.1, c1 - 0.1]:
				b.box("gloss", cmat("gloss"), Vector3(0.04, 0.06, 0.06), Vector3(sx * (w_r - 0.06), yrs + 0.05, z), Basis(), 0.01)
	# antenne requin
	b.box("gloss", cmat("gloss"), Vector3(0.06, 0.05, 0.16), Vector3(0, yrs + 0.065, c1 - 0.12), Basis(), 0.025)
	_tris = b.tri_count()
	var out := {}
	out["paint"] = b.build(["paint"])
	out["roofb"] = b.build(["roofb"]) if b.has("roofb") else null
	out["glass_rect"] = b.build(["glass_rect"])
	out["glass_fix"] = b.build(["glass_fix"])
	out["blink"] = b.build(["blink"])
	out["near"] = b.build(["near", seat_k, "liner"])
	out["misc"] = b.build(["trim", "gloss", "chrome", "misc_head", "drl", "tail", "well"])
	out["panes"] = _pane_specs
	_pane_specs = []
	return out


var _pane_specs: Array = []


func _ws_n() -> Vector3:
	var y_b: float = _p["belt"]
	return Vector3(0, float(_p["a1"]) - float(_p["a0"]), -(_yrs() - y_b)).normalized()


func _rw_n() -> Vector3:
	var y_b: float = _p["belt"]
	return Vector3(0, float(_p["c0"]) - float(_p["c1"]), _yrs() - y_b).normalized()


## Polygone posé sur le flanc vitré : points [z, t]
func _side_poly(b: GeoBatch, key: String, m: Material, sx: float, zt: Array, off: float) -> void:
	var pts := PackedVector3Array()
	for q in zt:
		pts.append(_sp(sx, q[0], q[1], off))
	b.poly_facing(key, m, pts, _side_n(sx))


## Vitre latérale rectangulaire : vitrage statique + spécification de la vitre cassable
func _side_rect(b: GeoBatch, sx: float, z0: float, z1: float, t0: float, t1: float, role: String) -> void:
	if z1 - z0 < 0.12:
		return
	_side_poly(b, "glass_rect", cmat("glass"), sx, [[z0, t0], [z1, t0], [z1, t1], [z0, t1]], 0.0)
	var v := _side_v(sx)
	var slant := v.length()
	var c := _sp(sx, (z0 + z1) * 0.5, (t0 + t1) * 0.5)
	var xa := Vector3(0, 0, 1)
	var ya := v.normalized()
	var bas := Basis(xa, ya, xa.cross(ya))
	_pane_specs.append([role, Vector2(z1 - z0, (t1 - t0) * slant), c, bas.get_euler(), 80.0, false])


## Pare-brise (« ws ») ou lunette (« rear ») : rectangle central cassable
func _plane_rect(b: GeoBatch, role: String, hwx: float, t0: float, t1: float) -> void:
	var f := _ws if role == "ws" else _rw
	var n := _ws_n() if role == "ws" else _rw_n()
	b.poly_facing("glass_rect", cmat("glass"), PackedVector3Array([f.call(-hwx, t0), f.call(hwx, t0), f.call(hwx, t1), f.call(-hwx, t1)]), n)
	var p0: Vector3 = f.call(0.0, t0)
	var p1: Vector3 = f.call(0.0, t1)
	var ya := (p1 - p0).normalized()
	var xa := Vector3(1, 0, 0)
	var bas := Basis(xa, ya, xa.cross(ya))
	if role == "ws":
		_pane_specs.append(["ws", Vector2(hwx * 2.0, p0.distance_to(p1)), (p0 + p1) * 0.5, bas.get_euler(), 125.0, true])
	else:
		_pane_specs.append(["rear", Vector2(hwx * 2.0, p0.distance_to(p1)), (p0 + p1) * 0.5, bas.get_euler(), 110.0, false])


## Passage de roue : creux sombre + lèvre (peinte ou en plastique noir) posés sur le flanc
func _arch(b: GeoBatch, sx: float, wz: float, r: float, clr: float, clad: bool, pm: Material) -> void:
	var R := r + 0.05
	var R2 := R + (0.05 if clad else 0.03)
	var x := sx * (float(_p["hw"]) - 0.012)
	var y_lo := clr - 0.005
	var wy := r
	var a_lo := asin(clampf((y_lo - wy) / R, -1.0, 1.0))
	var n := 14
	var inner := PackedVector3Array()
	var outer := PackedVector3Array()
	var a_lo2 := asin(clampf((y_lo - wy) / R2, -1.0, 1.0))
	for k in n + 1:
		var a := lerpf(a_lo, PI - a_lo, float(k) / n)
		inner.append(Vector3(x, wy + sin(a) * R, wz + cos(a) * R))
		var a2 := lerpf(a_lo2, PI - a_lo2, float(k) / n)
		outer.append(Vector3(x + sx * 0.004, wy + sin(a2) * R2, wz + cos(a2) * R2))
	b.poly_facing("well", cmat("well"), inner, Vector3(sx, 0, 0))
	var lip_k := "trim" if clad else "paint"
	var lip_m := cmat("trim") if clad else pm
	for k in n:
		var i0 := inner[k] + Vector3(sx * 0.004, 0, 0)
		var i1 := inner[k + 1] + Vector3(sx * 0.004, 0, 0)
		b.poly_facing(lip_k, lip_m, PackedVector3Array([i0, i1, outer[k + 1], outer[k]]), Vector3(sx, 0, 0))


## Joint de portière : fine ligne sombre sur le flanc
func _seam(b: GeoBatch, sx: float, z: float, y0: float, y1: float) -> void:
	var pts := PackedVector3Array()
	var x0 := _side_x(y0) + 0.003
	var x1 := _side_x(y1) + 0.003
	pts.append(Vector3(sx * x0, y0, z - 0.004))
	pts.append(Vector3(sx * x0, y0, z + 0.004))
	pts.append(Vector3(sx * x1, y1, z + 0.004))
	pts.append(Vector3(sx * x1, y1, z - 0.004))
	b.poly_facing("well", cmat("well"), pts, Vector3(sx, 0, 0))


## Quatre roues (pneus, jantes, disques) ; les roues avant braquées de `steer` rad
func _build_wheels(style: int, steer: float) -> ArrayMesh:
	var b := GeoBatch.new()
	var r: float = _p["r"]
	var w: float = _p["tw"]
	var hw: float = _p["hw"]
	var axf := _zf() + float(_p["foh"])
	var axr := axf + float(_p["wb"])
	var prof := PackedVector2Array([Vector2(r * 0.66, -w * 0.5), Vector2(r - 0.035, -w * 0.5), Vector2(r - 0.008, -w * 0.5 + 0.02),
		Vector2(r, -w * 0.3), Vector2(r, w * 0.3), Vector2(r - 0.008, w * 0.5 - 0.02), Vector2(r - 0.035, w * 0.5), Vector2(r * 0.66, w * 0.5)])
	var tire := MeshKit.lathe(prof, 22, 30.0)
	var rr := r * 0.64
	var dish := MeshKit.lathe(PackedVector2Array([Vector2(rr, w * 0.5 - 0.012), Vector2(rr * 0.9, w * 0.5 - 0.03), Vector2(rr * 0.3, w * 0.5 - 0.05), Vector2(0.001, w * 0.5 - 0.05)]), 18, 50.0, true)
	for wz: float in [axf, axr]:
		for sx: float in [-1.0, 1.0]:
			var c := Vector3(sx * (hw - w * 0.5 + 0.012), r, wz)
			var bas := Basis(Vector3.UP, steer if wz == axf else 0.0) * Basis(Vector3.BACK, -sx * PI * 0.5)
			var xf := Transform3D(bas, c)
			b.add_mesh("tire", cmat("tire"), tire, xf)
			b.cyl("brake", cmat("brake"), rr * 0.82, rr * 0.82, 0.02, xf * Vector3(0, w * 0.5 - 0.075, 0), bas, 16)
			var rim_m := cmat("rim_dark") if style == 2 else cmat("rim")
			var rim_k := "rim_dark" if style == 2 else "rim"
			match style:
				1:
					# jante tôle et enjoliveur
					b.add_mesh("hubcap", cmat("hubcap"), dish, xf)
					b.cyl("hubcap", cmat("hubcap"), rr * 0.98, rr, 0.02, xf * Vector3(0, w * 0.5 - 0.01, 0), bas, 18)
					for k in 8:
						var a := TAU * float(k) / 8.0
						b.box("tire", cmat("tire"), Vector3(0.025, 0.01, rr * 0.35), xf * Vector3(sin(a) * rr * 0.62, w * 0.5 - 0.0, cos(a) * rr * 0.62), bas * Basis(Vector3.UP, a), 0.0)
				_:
					# jante alliage : voile sombre, rayons
					b.add_mesh("well", cmat("well"), dish, xf)
					b.cyl(rim_k, rim_m, rr, rr, 0.03, xf * Vector3(0, w * 0.5 - 0.02, 0), bas, 18)
					b.cyl("well", cmat("well"), rr * 0.9, rr * 0.9, 0.032, xf * Vector3(0, w * 0.5 - 0.02, 0), bas, 18)
					var ns := 5 if style != 3 else 10
					for k in ns:
						var a := TAU * float(k) / float(ns)
						var sw := 0.07 if ns == 5 else 0.032
						b.box(rim_k, rim_m, Vector3(sw, 0.02, rr * 0.86), xf * Vector3(sin(a) * rr * 0.45, w * 0.5 - 0.012, cos(a) * rr * 0.45), bas * Basis(Vector3.UP, a), 0.006)
					b.cyl(rim_k, rim_m, rr * 0.2, rr * 0.22, 0.03, xf * Vector3(0, w * 0.5 - 0.005, 0), bas, 12)
	_tris += b.tri_count()
	return b.build()


## Plaques avant et arrière (cellule `idx` de l'atlas 2 x 9)
func _build_plates(idx: int) -> ArrayMesh:
	var b := GeoBatch.new()
	var u0 := float(idx % 2) * 0.5
	var v0 := float(idx / 2) * 112.0 / 1024.0
	var v1 := v0 + 112.0 / 1024.0
	var uvs := PackedVector2Array([Vector2(u0, v1), Vector2(u0 + 0.5, v1), Vector2(u0 + 0.5, v0), Vector2(u0, v0)])
	var zf := _zf()
	var zr := _zr()
	var w := 0.26
	var h := 0.057
	var yf := 0.47 if _p["tail"] != "van" else 0.5
	b.poly("plate", cmat("plate"), PackedVector3Array([Vector3(w, yf - h, zf - 0.006), Vector3(-w, yf - h, zf - 0.006), Vector3(-w, yf + h, zf - 0.006), Vector3(w, yf + h, zf - 0.006)]), false,
		PackedVector2Array([uvs[0], uvs[1], uvs[2], uvs[3]]))
	var yr := (0.42 + float(_p["deck"]) - 0.09) * 0.5 + 0.02
	b.poly("plate", cmat("plate"), PackedVector3Array([Vector3(-w, yr - h, zr + 0.006), Vector3(w, yr - h, zr + 0.006), Vector3(w, yr + h, zr + 0.006), Vector3(-w, yr + h, zr + 0.006)]), false, uvs)
	return b.build()


func _build_collision_civil() -> void:
	_static_body = StaticBody3D.new()
	_static_body.collision_layer = 1
	_static_body.collision_mask = 0
	add_child(_static_body)
	var clr: float = _p["clr"]
	var belt: float = _p["belt"]
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(float(_p["hw"]) * 2.0 - 0.04, belt - clr + 0.02, float(_p["L"]) - 0.06)
	cs.shape = bs
	cs.position = Vector3(0, (belt + clr) * 0.5, 0)
	_static_body.add_child(cs)
	var cs2 := CollisionShape3D.new()
	var b2 := BoxShape3D.new()
	var z0 := (float(_p["a0"]) + float(_p["a1"])) * 0.5
	var z1 := (float(_p["c0"]) + float(_p["c1"])) * 0.5
	b2.size = Vector3((_wb() + _wr()), _yrs() + 0.04 - belt, z1 - z0)
	cs2.shape = b2
	cs2.position = Vector3(0, (belt + _yrs() + 0.04) * 0.5, (z0 + z1) * 0.5)
	_static_body.add_child(cs2)
	_static_body.set_meta("vehicle", self)


## Foyers : compartiment moteur sous le capot, puis habitacle
func fire_specs() -> Array:
	var zf := _zf()
	var a0: float = _p["a0"]
	var belt: float = _p["belt"]
	var hood := _top_at((zf + a0) * 0.5)
	return [[Vector3(0, hood + 0.03, (zf + a0) * 0.5 + 0.05), Vector3(_wb() * 0.6, 0.05, (a0 - zf) * 0.35), 0.6, 1.05],
		[Vector3(0, belt + 0.05, (a0 + float(_p["c0"])) * 0.5), Vector3(_wb() * 0.5, 0.05, (float(_p["c0"]) - a0) * 0.35), 0.5, 0.9]]


func ring_radius() -> float:
	return 4.0


# ------------------------------------------------------------------ vandalisme et alarme
## Coup de pied (joueur ou PNJ) : arme les vitres, bosse la tôle, déclenche l'alarme
func kick(point: Vector3, dir: Vector3, power := 1.0) -> bool:
	if damage == null or global_position.distance_to(point) > half.y + 1.2:
		return false
	(damage as CivilDamage).arm()
	var ok := super.kick(point, dir, power)
	if ok:
		trigger_alarm()
	return ok


func bump(power: float, n := Vector3.UP) -> void:
	super.bump(power, n)
	set_physics_process(true)


func trigger_alarm() -> void:
	if damage != null and (damage.exploded or (damage.burning and damage.heat > 0.5)):
		return
	if alarm_t <= 0.0:
		_blink_ph = 0.0
		if _alarm == null:
			_alarm = AudioStreamPlayer3D.new()
			_alarm.stream = alarm_stream(int(absf(position.x * 7.0 + position.z * 3.0)) % 2)
			_alarm.unit_size = 9.0
			_alarm.max_distance = 140.0
			_alarm.volume_db = -3.0
			_alarm.bus = Settings.bus_for("car_alarm")
			_alarm.position = Vector3(0, 0.6, float(_p.get("a0", -1.0)) - 0.3)
			add_child(_alarm)
		_alarm.play()
	alarm_t = ALARM_TIME
	set_physics_process(true)


func stop_alarm() -> void:
	alarm_t = 0.0
	if _alarm != null:
		_alarm.stop()
	if _blink != null:
		_blink.material_override = cmat("blink_off")


func _physics_process(delta: float) -> void:
	_bounce_v += (-_bounce * 140.0 - _bounce_v * 9.0) * delta
	_bounce += _bounce_v * delta
	_roll_v += (-_roll * 120.0 - _roll_v * 8.0) * delta
	_roll += _roll_v * delta
	if _body:
		_body.rotation.z = _roll
		_body.position.y = _bounce - sag
	var quiet := absf(_bounce) < 0.0005 and absf(_bounce_v) < 0.003 and absf(_roll) < 0.0005 and absf(_roll_v) < 0.003
	if alarm_t > 0.0:
		alarm_t -= delta
		# les fils fondent : l'alarme s'étrangle dans l'incendie
		if damage != null and damage.burning and damage.heat > 0.55:
			alarm_t = 0.0
		_blink_ph += delta
		var on := fmod(_blink_ph, 0.8) < 0.42
		_blink.material_override = cmat("blink_on") if on else cmat("blink_off")
		if alarm_t <= 0.0:
			stop_alarm()
	elif quiet and sag <= 0.0:
		set_physics_process(false)
	if damage != null and damage.burning:
		set_physics_process(true)


## Sirène d'alarme synthétisée (boucle de 6 s) : 0 = sirène piézo modulée, 1 = klaxon et bips
static func alarm_stream(variant: int) -> AudioStreamWAV:
	if _alarm_streams.is_empty():
		_alarm_streams = [_gen_alarm(0), _gen_alarm(1)]
	return _alarm_streams[variant % 2]


static func _gen_alarm(variant: int) -> AudioStreamWAV:
	var rate := 22050
	var n := rate * 6
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	var ph2 := 0.0
	for i in n:
		var t := float(i) / rate
		var f := 0.0
		var amp := 0.0
		var s := 0.0
		if variant == 0:
			if t < 2.0:
				f = 1650.0 if fmod(t, 0.24) < 0.12 else 1150.0          # trille deux tons
				amp = 0.55
			elif t < 4.0:
				var k := fmod(t - 2.0, 0.5) / 0.5                      # balayage montant
				f = lerpf(800.0, 2300.0, k * k)
				amp = 0.55
			else:
				f = 2050.0                                              # bips rapides
				amp = 0.55 if fmod(t, 0.14) < 0.075 else 0.0
			ph += TAU * f / rate
			s = clampf(sin(ph) * 2.2, -1.0, 1.0) * 0.75 + sin(ph * 3.0) * 0.12
		else:
			if t < 3.6:
				amp = 0.6 if fmod(t, 0.6) < 0.32 else 0.0               # klaxon
				ph += TAU * 415.0 / rate
				ph2 += TAU * 520.0 / rate
				s = (fmod(ph / TAU, 1.0) * 2.0 - 1.0) * 0.5 + (fmod(ph2 / TAU, 1.0) * 2.0 - 1.0) * 0.5
				s = clampf(s * 1.6, -1.0, 1.0)
			else:
				var k2 := fmod(t, 0.3) / 0.3
				f = lerpf(1900.0, 1100.0, k2)
				amp = 0.5
				ph += TAU * f / rate
				s = clampf(sin(ph) * 2.5, -1.0, 1.0)
		# petites rampes d'attaque pour éviter les clics
		data.encode_s16(i * 2, int(clampf(s * amp, -1.0, 1.0) * 26000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


static func tris_per_car() -> int:
	return _tris
