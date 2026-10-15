class_name MapStory
extends RefCounted
## Les lieux de l'histoire posés sur le quartier (module Carte) : vitrines nommées (supérette « Le Panier du Coin »,
## café « Le Zinc » de Jo, Banque Hexa, pharmacie, boulangerie) choisies parmi les boutiques des immeubles, et ce que
## le kit du joueur attend du décor : étiquettes de prix filmables (groupe « price_tags »), piles de tracts au QG
## (groupe « tract_stacks »), panneaux d'affichage libre (groupe « affichage_libre »). Les lieux nommés eux-mêmes
## sont dans Quartier.SPOTS (à ~3 m devant ces vitrines).

## Vitrines de l'histoire : abscisse voulue de la boutique et côté du boulevard (la plus proche ouverture de
## l'immeuble qui couvre cette abscisse devient la vraie boutique). Clé = id du lieu (Quartier.SPOTS).
const STOREFRONTS := {
	"bar_qg": {"kind": "cafe", "name": "Le Zinc", "x": -10.8, "north": true, "awning": true,
		"color": Color(0.32, 0.05, 0.06), "awning_color": Color(0.55, 0.08, 0.08)},
	"boulangerie": {"kind": "boulangerie", "name": "Boulangerie des Tanneurs", "x": 11.7, "north": true},
	"pharmacie": {"kind": "pharmacie", "name": "Pharmacie des Ormes", "x": 17.9, "north": true},
	"supermarche": {"kind": "superette", "name": "Le Panier du Coin", "x": 40.0, "north": false,
		"color": Color(0.1, 0.42, 0.24)},
	"banque": {"kind": "banque", "name": "Banque Hexa", "x": -3.5, "north": false},
}
## Étiquettes de la supérette (prix au 1er mars : la hausse) et ardoise de l'étal
const PRICES := [["LAIT 1 L", "1,39 €"], ["PÂTES 500 g", "1,89 €"], ["HUILE 1 L", "4,99 €"], ["CAFÉ 250 g", "5,49 €"],
	["ŒUFS × 12", "4,29 €"], ["BEURRE 250 g", "3,19 €"]]
const SLATE := ["PROMOS", "Pommes 3,90 €/kg", "Tomates 4,50 €/kg", "Pain de mie 2,35 €"]
## Panneaux d'affichage libre : position au sol (x, z) et lacet (le panneau regarde son +Z local)
const BOARDS := [[Vector2(-39.0, 17.7), PI], [Vector2(27.0, -24.9), 0.0], [Vector2(-45.0, 30.0), -PI * 0.5]]

## Commerces uniques dans l'histoire : ailleurs, une boutique tirée au sort de ce type devient un autre commerce
const UNIQUE := ["pharmacie", "banque", "superette"]
const PLAIN := ["tabac", "fleuriste", "librairie", "opticien", "primeur", "coiffeur", "boutique"]


static func plain_kind(k: String, sv: int) -> String:
	return PLAIN[absi(sv) % PLAIN.size()] if k in UNIQUE else k


static func mat(c: Color, rough := 0.7, emit := 0.0) -> StandardMaterial3D:
	return Shop.col_mat(c, rough, emit)


static func _mesh(parent: Node3D, m: Mesh, mt: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mt
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, mt: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(parent, b, mt, pos, rot)


static func label(parent: Node3D, text: String, px: float, col: Color, pos: Vector3, size := 64, serif := false) -> Label3D:
	var lab := Shop._lab(text, ParisBuilding.serif() if serif else ParisBuilding.sans(), size, px, col)
	lab.position = pos
	lab.visibility_range_end = 45.0
	parent.add_child(lab)
	return lab


## Étiquette de prix filmable : carton coloré, produit et prix (groupe « price_tags », vu par le téléphone)
static func price_card(parent: Node3D, product: String, price: String, pos: Vector3, bg := Color(1.0, 0.86, 0.1)) -> Node3D:
	var n := Node3D.new()
	n.name = "Prix"
	n.position = pos
	n.add_to_group("price_tags")
	parent.add_child(n)
	var q := QuadMesh.new()
	q.size = Vector2(0.34, 0.24)
	var card := _mesh(n, q, mat(bg, 0.8, 0.12), Vector3.ZERO)
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label(n, product, 0.0021, Color(0.08, 0.08, 0.1), Vector3(0, 0.065, 0.004), 40)
	label(n, price, 0.0042, Color(0.75, 0.04, 0.04), Vector3(0, -0.035, 0.004), 48)
	return n


# ------------------------------------------------------------------ habillage des vitrines de l'histoire
## Appelé par la boutique (Shop._ready) quand elle porte un lieu de l'histoire. Repère de la boutique : façade en
## z = 0, trottoir vers +Z, intérieur vers -Z, ouverture centrée en x = 0.
static func dress_shop(shop: Shop, id: String) -> void:
	match id:
		"supermarche":
			_superette(shop)
		"bar_qg":
			_zinc(shop)
		"banque":
			_bank(shop)


static func _superette(shop: Shop) -> void:
	var hw := shop.width * 0.5
	var root := Node3D.new()
	root.name = "Etiquettes"
	shop.add_child(root)
	# bandeau « nos prix au 1er mars » et étiquettes jaunes collées derrière la vitrine (lisibles du trottoir)
	var top := shop.height - 0.95
	box(root, Vector3(shop.width - 0.5, 0.26, 0.01), mat(Color(0.96, 0.96, 0.94), 0.8, 0.1), Vector3(0, top, -0.26))
	label(root, "NOS PRIX AU 1er MARS", 0.0034, Color(0.1, 0.42, 0.24), Vector3(0, top, -0.25), 56)
	var cols := 3
	for i in PRICES.size():
		var cx := (float(i % cols) - (cols - 1) * 0.5) * minf(0.95, (shop.width - 0.6) / cols)
		var cy := top - 0.42 - float(i / cols) * 0.34
		price_card(root, PRICES[i][0], PRICES[i][1], Vector3(cx, cy, -0.25))
	# chevalet sur le trottoir : ardoise des promos (prix au kilo)
	var ch := Node3D.new()
	ch.name = "Chevalet"
	ch.position = Vector3(hw + 0.9, 0, 1.0)
	ch.rotation.y = -0.35
	ch.add_to_group("price_tags")
	shop.add_child(ch)
	var wood := mat(Color(0.36, 0.24, 0.13), 0.8)
	for s in [-1.0, 1.0]:
		box(ch, Vector3(0.62, 1.0, 0.03), wood, Vector3(0, 0.5, s * 0.17), Vector3(s * 0.33, 0, 0))
	box(ch, Vector3(0.54, 0.74, 0.012), mat(Color(0.08, 0.09, 0.09), 0.9), Vector3(0, 0.56, 0.19), Vector3(-0.33, 0, 0))
	for k in SLATE.size():
		var lab := label(ch, SLATE[k], 0.0026 if k == 0 else 0.0019, Color(0.95, 0.95, 0.9), Vector3(0, 0.82 - k * 0.13, 0.27 - k * 0.043), 44)
		lab.rotation.x = -0.33
	# étal de fruits (cagettes renversables)
	for i in 2:
		shop._item(Vector3(-hw + 0.5 + float(i) * 0.85, 0, 0.95), Vector3(0.75, 0.8, 0.55), Color(0.62, 0.48, 0.3),
			[Color(0.85, 0.12, 0.1), Color(0.95, 0.65, 0.1), Color(0.35, 0.62, 0.18)], false, true, "crate")


static func _zinc(shop: Shop) -> void:
	var hw := shop.width * 0.5
	# terrasse de part et d'autre de la porte (le passage devant l'entrée reste libre)
	for sx in [-1.0, 1.0]:
		for k in 2:
			var ox: float = sx * (hw + 0.95 + float(k) * 1.6)
			var oz := 1.15 + float(k) * 0.9
			shop._item(Vector3(ox, 0, oz), Vector3(0.6, 0.74, 0.6), Color(0.75, 0.72, 0.65), [], false, true, "table")
			for side in [-1.0, 1.0]:
				var c := shop._item(Vector3(ox + side * 0.55, 0, oz), Vector3(0.42, 0.88, 0.42), Color(0.55, 0.4, 0.25), [], false, true, "chair")
				c.rotation.y = side * PI * 0.5 + randf_range(-0.3, 0.3)
	# ardoise du café (les prix aussi ont bougé) contre le trumeau
	var sl := Node3D.new()
	sl.name = "Ardoise"
	sl.position = Vector3(hw + 0.42, 1.15, 0.12)
	shop.add_child(sl)
	box(sl, Vector3(0.56, 0.78, 0.04), mat(Color(0.3, 0.2, 0.1), 0.8), Vector3.ZERO)
	box(sl, Vector3(0.48, 0.7, 0.01), mat(Color(0.07, 0.08, 0.08), 0.9), Vector3(0, 0, 0.022))
	var lines := ["LE ZINC", "Café 1,30", "Crème 2,60", "Demi 3,80", "Plat du jour 12,50"]
	for k in lines.size():
		label(sl, lines[k], 0.0024 if k == 0 else 0.0017, Color(0.95, 0.94, 0.88), Vector3(0, 0.25 - k * 0.12, 0.03), 44)
	# piles de tracts du comité : caisse à vin posée contre la façade, près de la porte (on s'y réapprovisionne)
	var st := Node3D.new()
	st.name = "PileTracts"
	st.position = Vector3(-hw - 0.3, 0, 0.3)
	st.add_to_group("tract_stacks")
	shop.add_child(st)
	box(st, Vector3(0.5, 0.32, 0.36), mat(Color(0.55, 0.38, 0.2), 0.85), Vector3(0, 0.16, 0))
	var paper := mat(Color(0.95, 0.94, 0.9), 0.9)
	box(st, Vector3(0.21, 0.16, 0.3), paper, Vector3(-0.11, 0.4, 0), Vector3(0, 0.08, 0))
	box(st, Vector3(0.21, 0.11, 0.3), mat(Color(0.98, 0.85, 0.2), 0.9), Vector3(0.12, 0.375, 0), Vector3(0, -0.05, 0))
	box(st, Vector3(0.21, 0.004, 0.297), mat(Color(0.75, 0.1, 0.1), 0.9), Vector3(-0.11, 0.482, 0), Vector3(0, 0.08, 0))


static func _bank(shop: Shop) -> void:
	# distributeur de billets encastré à côté de la vitrine
	var hw := shop.width * 0.5
	var atm := Node3D.new()
	atm.name = "Distributeur"
	atm.position = Vector3(hw - 0.55, 0, 0.02)
	shop.add_child(atm)
	box(atm, Vector3(0.7, 0.9, 0.1), mat(Color(0.16, 0.17, 0.2), 0.4), Vector3(0, 1.3, 0))
	box(atm, Vector3(0.36, 0.26, 0.02), mat(Color(0.2, 0.55, 0.85), 0.3, 0.9), Vector3(0, 1.48, 0.055))
	box(atm, Vector3(0.4, 0.12, 0.12), mat(Color(0.35, 0.36, 0.4), 0.5), Vector3(0, 1.16, 0.08), Vector3(0.5, 0, 0))
	label(atm, "RETRAIT 24/24", 0.0018, Color(0.95, 0.95, 0.95), Vector3(0, 1.67, 0.06), 40)


# ------------------------------------------------------------------ panneaux d'affichage libre
## Panneaux d'affichage libre (légal : affiches et tracts autorisés) : tôle verte sur deux poteaux, bandeau titre.
## Chaque panneau est un StaticBody3D du groupe « affichage_libre » (poster_tool / kit_tool.classify).
static func build_boards(parent: Node3D, crowd: Crowd, place: Callable) -> void:
	var green := mat(Color(0.12, 0.27, 0.19), 0.55)
	var sheet := mat(Color(0.2, 0.36, 0.27), 0.7)
	var paper := [Color(0.92, 0.9, 0.84), Color(0.95, 0.75, 0.2), Color(0.85, 0.3, 0.25), Color(0.6, 0.75, 0.9)]
	var i := 0
	for bd in BOARDS:
		var at: Variant = place.call(bd[0], 0.9)
		if at == null:
			continue
		var p: Vector2 = at
		var b := StaticBody3D.new()
		b.name = "AffichageLibre%d" % i
		b.collision_layer = 1
		b.add_to_group("affichage_libre")
		b.position = Vector3(p.x, 0, p.y)
		b.rotation.y = bd[1]
		parent.add_child(b)
		for s in [-1.0, 1.0]:
			var pole := CylinderMesh.new()
			pole.top_radius = 0.035
			pole.bottom_radius = 0.035
			pole.height = 2.3
			_mesh(b, pole, green, Vector3(s * 0.72, 1.15, 0))
		box(b, Vector3(1.6, 1.1, 0.04), sheet, Vector3(0, 1.45, 0))
		box(b, Vector3(1.66, 0.2, 0.06), green, Vector3(0, 2.1, 0))
		label(b, "AFFICHAGE LIBRE", 0.0028, Color(0.95, 0.95, 0.9), Vector3(0, 2.1, 0.032), 48)
		var back := label(b, "AFFICHAGE LIBRE", 0.0028, Color(0.95, 0.95, 0.9), Vector3(0, 2.1, -0.032), 48)
		back.rotation.y = PI
		# restes d'affiches déchirées
		for k in 3:
			var q := QuadMesh.new()
			q.size = Vector2(0.32 + 0.1 * k, 0.42)
			var mi := _mesh(b, q, mat(paper[(i + k) % paper.size()], 0.95), Vector3(-0.5 + k * 0.48, 1.4 + 0.08 * (k % 2), 0.022), Vector3(0, 0, 0.04 * (k - 1)))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(1.6, 1.25, 0.08)
		cs.shape = sh
		cs.position = Vector3(0, 1.45, 0)
		b.add_child(cs)
		for s in [-1.0, 1.0]:
			var pc := CollisionShape3D.new()
			var ps := BoxShape3D.new()
			ps.size = Vector3(0.1, 0.9, 0.1)
			pc.shape = ps
			pc.position = Vector3(s * 0.72, 0.45, 0)
			b.add_child(pc)
		if crowd:
			crowd.add_obstacle(b, Vector2(0.85, 0.12))
		i += 1
