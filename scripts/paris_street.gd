class_name ParisStreet
extends Node3D
## Le petit quartier bâti : deux fronts continus le long du boulevard (percés de deux rues adjacentes), des
## immeubles d'angle à deux façades, et des fronts transversaux qui ferment la perspective aux deux bouts, avec un
## bout de rue au-delà. Immeubles de styles, largeurs et hauteurs variés (voir ParisBuilding) ; deux sur trois,
## dans la zone de jeu du boulevard, ont des boutiques envahissables. Le plan général est dans Quartier.

const NORTH_Z := Quartier.NORTH_Z
const SOUTH_Z := Quartier.SOUTH_Z
const SHOP_ZONE := 80.0
const DEPTH := 12.0
const GAP_Z0 := -12.4          # rue dans le prolongement du boulevard, au-delà des fronts transversaux
const GAP_Z1 := -2.4
const END_X := 165.0           # fond de ces bouts de rue
const BLVD := "BOULEVARD DES ORMES"
const SIDE_N_NAME := "RUE DES CERISIERS"
const SIDE_S_NAME := "RUE DE LA FORGE"

var crowd: Crowd
var buildings: Array = []
var _rng := RandomNumberGenerator.new()
var _num := {}


func _ready() -> void:
	_rng.seed = 1871
	NavGrid.open_rects.clear()
	var sn: Array = Quartier.SIDE_NORTH
	var ss: Array = Quartier.SIDE_SOUTH
	var e := Quartier.BLVD_END
	# --- boulevard, côté sud (façades vers +Z, on avance vers +X), coupé par la rue adjacente sud
	_row(Vector3(-e, 0, SOUTH_Z), Vector3.RIGHT, ss[0] + e, {"street": BLVD, "corner_end": true, "blvd": true, "odd": true})
	_row(Vector3(ss[1], 0, SOUTH_Z), Vector3.RIGHT, e - ss[1], {"street": BLVD, "corner_start": true, "blvd": true, "odd": true})
	# --- boulevard, côté nord (façades vers -Z, on avance vers -X), coupé par la rue adjacente nord
	_row(Vector3(e, 0, NORTH_Z), Vector3.LEFT, e - sn[1], {"street": BLVD, "corner_end": true, "blvd": true})
	_row(Vector3(sn[0], 0, NORTH_Z), Vector3.LEFT, sn[0] + e, {"street": BLVD, "corner_start": true, "blvd": true})
	# --- fronts transversaux aux deux bouts (percés pour la chaussée) et bouts de rue au-delà
	for sx in [1.0, -1.0]:
		var x: float = sx * e
		if sx > 0.0:
			_row(Vector3(x, 0, SOUTH_Z), Vector3.BACK, GAP_Z0 - SOUTH_Z, {"corner_end": true, "far": true})
			# (z GAP_Z1..NORTH_Z : la mairie, construite en dernier pour ne pas décaler le tirage des autres)
		else:
			_row(Vector3(x, 0, NORTH_Z), Vector3.FORWARD, NORTH_Z - GAP_Z1, {"corner_end": true, "far": true})
			_row(Vector3(x, 0, GAP_Z0), Vector3.FORWARD, GAP_Z0 - SOUTH_Z, {"corner_start": true, "far": true})
		var x0: float = sx * (e + DEPTH)
		var x1: float = sx * END_X
		if sx > 0.0:
			_row(Vector3(x0, 0, GAP_Z0), Vector3.RIGHT, x1 - x0, {"far": true})
			_row(Vector3(x1, 0, GAP_Z1), Vector3.LEFT, x1 - x0, {"far": true})
			_row(Vector3(x1, 0, GAP_Z0), Vector3.BACK, GAP_Z1 - GAP_Z0, {"far": true, "fixed": true})
		else:
			_row(Vector3(x1, 0, GAP_Z0), Vector3.RIGHT, x0 - x1, {"far": true})
			_row(Vector3(x0, 0, GAP_Z1), Vector3.LEFT, x0 - x1, {"far": true})
			_row(Vector3(x1, 0, GAP_Z1), Vector3.FORWARD, GAP_Z1 - GAP_Z0, {"far": true, "fixed": true})
	# --- rue adjacente nord (x sn0..sn1, de z = 19 à z_far)
	var zn0 := NORTH_Z + DEPTH
	var zn1: float = sn[2]
	_row(Vector3(sn[0], 0, zn1), Vector3.FORWARD, zn1 - zn0, {"street": SIDE_N_NAME})                 # côté ouest, façades vers +X
	_row(Vector3(sn[1], 0, zn0), Vector3.BACK, zn1 - zn0, {"street": SIDE_N_NAME, "odd": true})       # côté est, façades vers -X
	_row(Vector3(sn[1], 0, zn1), Vector3.LEFT, sn[1] - sn[0], {"fixed": true})                        # fond de rue
	# --- rue adjacente sud (x ss0..ss1, de z = -26 à z_far) ; côté ouest, la station-service Carbura
	var zs0 := SOUTH_Z - DEPTH
	var zs1: float = ss[2]
	var st: Rect2 = Quartier.STATION
	_row(Vector3(ss[0], 0, zs0), Vector3.FORWARD, zs0 - st.end.y, {"street": SIDE_S_NAME})          # côté ouest, façades vers +X
	_row(Vector3(ss[0], 0, st.position.y), Vector3.FORWARD, st.position.y - zs1, {"street": SIDE_S_NAME})
	_row(Vector3(ss[1], 0, zs1), Vector3.BACK, zs0 - zs1, {"street": SIDE_S_NAME, "odd": true})       # côté est, façades vers -X
	_row(Vector3(ss[0], 0, zs1), Vector3.RIGHT, ss[1] - ss[0], {"fixed": true})                       # fond de rue
	add_child(MapStation.new())
	# --- mairie d'arrondissement : ferme la perspective du boulevard côté nord (façade vers -X), parvis devant
	_row(Vector3(e, 0, Quartier.MAIRIE_Z0), Vector3.BACK, NORTH_Z - Quartier.MAIRIE_Z0, {"corner_start": true,
		"fixed": true, "style": "haussmann", "mairie": true})
	var mairie := MapMairie.new()
	mairie.building = buildings[buildings.size() - 1]
	add_child(mairie)


## Une rangée d'immeubles mitoyens de `start` sur `length` mètres, dans la direction `dir` (axe X local des
## immeubles ; leur façade regarde dir × UP). opts : street, corner_start, corner_end, blvd, far, fixed, odd
func _row(start: Vector3, dir: Vector3, length: float, opts: Dictionary) -> void:
	if length < 4.0:
		return
	var specs: Array = []
	var styles: Array = []
	var acc := 0.0
	var prev := ""
	while acc < length - 0.01:
		var st: String = opts.get("style", "")
		if st == "":
			st = _pick_style(prev, opts)
		var sp := ParisBuilding.spec(st, _rng)
		if opts.get("fixed", false):
			sp["width"] = length
		var rest := length - acc
		if rest - float(sp["width"]) < 6.0:
			sp["width"] = rest            # le dernier remplit le reste (ou celui-ci s'élargit pour ne pas laisser de miette)
		specs.append(sp)
		styles.append(st)
		acc += float(sp["width"])
		prev = st
	var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
	var x := 0.0
	var key: String = opts.get("street", "")
	for i in specs.size():
		var sp: Dictionary = specs[i]
		var b := ParisBuilding.new()
		b.style = styles[i]
		b.apply_spec(sp)
		b.depth = DEPTH
		b.seed_v = _rng.randi()
		b.crowd = crowd
		var pos := start + dir * x
		var mid := pos + dir * b.width * 0.5
		b.lod_far = opts.get("far", false) or Vector2(mid.x, mid.z + 5.0).length() > 80.0 and not opts.get("mairie", false)
		b.left_h = ParisBuilding.top_h(specs[i - 1]) if i > 0 else 0.0
		b.right_h = ParisBuilding.top_h(specs[i + 1]) if i < specs.size() - 1 else 0.0
		b.corner_l = i == 0 and opts.get("corner_start", false)
		b.corner_r = i == specs.size() - 1 and opts.get("corner_end", false)
		if b.corner_l or b.corner_r:
			b.street_name = key
		if opts.get("blvd", false) and absf(mid.x) < SHOP_ZONE and buildings.size() % 3 != 2:
			b.shops = 1 if b.width < 15.0 else 2
		b.shop_ok = opts.get("blvd", false) or _rng.randf() < 0.5 and not opts.get("mairie", false)
		if key != "":
			var n: int = _num.get(key + str(opts.get("odd", false)), 1 if opts.get("odd", false) else 2)
			b.number = n
			_num[key + str(opts.get("odd", false))] = n + 2
		b.transform = Transform3D(basis, pos)
		add_child(b)
		buildings.append(b)
		x += b.width


func _pick_style(prev: String, opts: Dictionary) -> String:
	for i in 6:
		var r := _rng.randf()
		var st := "haussmann"
		if r < 0.34:
			st = "haussmann"
		elif r < 0.6:
			st = "faubourg"
		elif r < 0.74:
			st = "belle_epoque"
		elif r < 0.87:
			st = "brique"
		else:
			st = "deco"
		if opts.get("fixed", false) and st == "faubourg":
			continue
		if st != prev or st == "haussmann" and _rng.randf() < 0.4:
			return st
	return "haussmann"
