class_name Quartier
extends RefCounted
## Plan du petit quartier (données partagées par les immeubles, le mobilier, les voitures et les passants).
## Repère monde : X le long du boulevard (la police arrive par +X), Z en travers (nord = +Z).
##
##   z = 19      ───── façades nord ─────────────┐   ┌──────────── (rue adjacente nord, x -56..-44)
##   z -3.9..19  promenade nord (le cortège y passe vers z = 6 ; square, métro, kiosque au-delà de z = 10)
##   z -10.9..-3.9  chaussée du boulevard (2 voies, bus côté sud)
##   z -26..-10.9   trottoir sud (abribus z=-13, parking, Vélib, fontaine)
##   z = -26     ───── façades sud ──────────┐   ┌──────────────── (rue adjacente sud, x -82..-72)
##
## Le boulevard est fermé à chaque bout (x = ±BLVD_END) par un front d'immeubles percé pour la chaussée.

# --- boulevard
const NORTH_Z := 19.0                 # façades nord (tournées vers -Z)
const SOUTH_Z := -26.0                # façades sud (tournées vers +Z)
const ROAD_Z0 := -10.9                # chaussée : bord sud
const ROAD_Z1 := -3.9                 # chaussée : bord nord
const ROAD_Z := -7.4                  # axe de la chaussée
const BLVD_END := 105.0               # fronts d'immeubles qui ferment la perspective
const CURB_H := 0.12                  # hauteur de bordure (visuelle : le sol reste plat pour la physique)

# --- rues adjacentes (perpendiculaires au boulevard) : [x0, x1, z_far] ; la chaussée fait 6 m au milieu
const SIDE_NORTH := [-56.0, -44.0, 75.0]
const SIDE_SOUTH := [-82.0, -72.0, -80.0]
const SIDE_ROAD_W := 6.0

# --- zones réservées (rectangles x0, z0, x1, z1) : chacun ne construit que dans les siennes
const SQUARE := Rect2(-34.0, 10.5, 20.0, 7.0)          # square parisien (pelouse, haies, bancs, arbres)
const PARKING := Rect2(-37.5, -24.6, 21.0, 10.4)      # parking à ciel ouvert (côté sud-ouest)
const VELIB := Rect2(13.0, -16.2, 10.0, 1.6)          # station de vélos en libre-service
const METRO := Vector3(15.0, 0.0, 12.5)                # entrée de métro (édicule Guimard)
const KIOSK := Vector3(28.0, 0.0, 13.5)               # kiosque à journaux
const MORRIS := Vector3(-6.0, 0.0, 14.0)              # colonne Morris
const WALLACE := Vector3(6.5, 0.0, -18.5)             # fontaine Wallace
const CROSSWALKS := [-50.0, -10.0, 30.0]              # passages piétons en travers du boulevard (x)
const TREE_ROWS := [-2.3, -12.2]                      # alignements de platanes (z), un arbre tous les ~9 m
const TREE_SKIP := [Vector2(-3.5, 3.5), Vector2(40.0, 60.0)]   # pas d'arbre : devant l'abribus, au barrage de police

# --- lieux nommés de l'histoire (campagne) : ids stables utilisés par les chapitres (scripts/story/*.gd).
# Positions au sol, sur le trottoir devant la bonne façade (vitrines : voir MapStory.STOREFRONTS, à ~3 m de la façade),
# toujours praticables (grille de navigation, hors obstacles : tools/tests/campaign_map.gd).
const SPOTS := {
	"depart": Vector3(0.0, 0.0, 0.0),            # point de départ d'origine du joueur
	"square": Vector3(-24.0, 0.0, 14.0),         # square des Tanneurs (rassemblement des premiers jours)
	"metro": Vector3(15.0, 0.0, 8.6),            # sortie du métro (devant l'édicule, pas dans la trémie)
	"kiosque": Vector3(28.0, 0.0, 11.5),
	"morris": Vector3(-6.0, 0.0, 12.0),          # colonne Morris (affiches)
	"wallace": Vector3(6.5, 0.0, -17.0),
	"abribus": Vector3(0.0, 0.0, -15.0),
	"parking": Vector3(-29.0, 0.0, -17.2),          # allée du parking, devant les places
	"velib": Vector3(18.0, 0.0, -14.0),
	"bar_qg": Vector3(-10.8, 0.0, 16.5),         # café-bar « Le Zinc » de Jo (QG), entre les tables de sa terrasse
	"boulangerie": Vector3(11.7, 0.0, 16.0),
	"supermarche": Vector3(40.0, 0.0, -23.0),    # supérette « Le Panier du Coin » (étiquettes de prix en vitrine)
	"banque": Vector3(-3.5, 0.0, -23.0),         # Banque Hexa
	"pharmacie": Vector3(17.9, 0.0, 16.0),
	"carrefour_ouest": Vector3(-50.0, 0.0, -7.4),
	"rue_nord": Vector3(-50.0, 0.0, 40.0),       # rue adjacente nord (rue des Cerisiers)
	"rue_nord_fond": Vector3(-50.0, 0.0, 70.0),
	"rue_sud": Vector3(-78.0, 0.0, -45.0),       # rue adjacente sud (rue de la Forge)
	"rue_sud_fond": Vector3(-78.0, 0.0, -75.0),
	"station_service": Vector3(-85.0, 0.0, -63.0), # station Carbura (rue de la Forge, côté ouest) : piste devant les pompes
	"cordon": Vector3(54.0, 0.0, -7.4),          # ligne de police d'origine (en travers du boulevard)
	"parvis_mairie": Vector3(96.0, 0.0, 8.3),    # parvis de la mairie (bout est du boulevard, côté nord)
	"mairie": Vector3(102.5, 0.0, 8.3),          # devant la porte de la mairie (façade x = BLVD_END)
}

# --- station-service Carbura : terrain ouvert côté ouest de la rue de la Forge (x0, z0, largeur, profondeur)
const STATION := Rect2(-96.0, -80.0, 14.0, 28.0)
# --- mairie d'arrondissement : façade tournée vers -X en x = BLVD_END, de z = MAIRIE_Z0 à NORTH_Z
const MAIRIE_Z0 := -2.4

# --- sol praticable (piétons) : boulevard, rues adjacentes, station, prolongements derrière les fronts transversaux
const WALK_RECTS := [Rect2(-105.0, -26.0, 210.0, 45.0), Rect2(-56.0, 19.0, 12.0, 56.0), Rect2(-82.0, -80.0, 10.0, 54.0),
	Rect2(-96.0, -80.0, 14.0, 28.0), Rect2(105.0, -12.4, 60.0, 10.0), Rect2(-165.0, -12.4, 60.0, 10.0)]
const ROOF_H := 27.0                  # au-dessus, plus aucun immeuble (caméra libre)


## Position d'un lieu nommé (erreur explicite si l'id n'existe pas)
static func spot(id: String) -> Vector3:
	if not SPOTS.has(id):
		push_error("Quartier.spot : lieu inconnu « %s »" % id)
		return Vector3.ZERO
	return SPOTS[id]


# --- stationnement le long de la chaussée (voitures garées) : [x0, x1, z]
const PARK_LANES := [[-100.0, -60.0, -4.9], [-100.0, -60.0, -9.9], [62.0, 100.0, -4.9]]


## Bornes en Z accessibles aux piétons à l'abscisse x (pied des façades, ou fond d'une rue adjacente)
static func z_limits(x: float) -> Vector2:
	var lo := SOUTH_Z + 0.35
	var hi := NORTH_Z - 0.35
	if x > SIDE_NORTH[0] + 0.3 and x < SIDE_NORTH[1] - 0.3:
		hi = SIDE_NORTH[2]
	if x > SIDE_SOUTH[0] + 0.3 and x < SIDE_SOUTH[1] - 0.3:
		lo = SIDE_SOUTH[2]
	return Vector2(lo, hi)


## Le point est-il dans une zone réservée (pour éviter d'y poser autre chose) ?
static func reserved(p: Vector3, margin := 0.5) -> bool:
	var q := Vector2(p.x, p.z)
	for r in [SQUARE, PARKING, VELIB]:
		if (r as Rect2).grow(margin).has_point(q):
			return true
	for c in [METRO, KIOSK, MORRIS, WALLACE]:
		if Vector2((c as Vector3).x, (c as Vector3).z).distance_to(q) < 2.5 + margin:
			return true
	return false


## Le point (au sol) est-il sur le sol praticable du quartier (rue, trottoir, station) ?
static func walkable(p: Vector3, margin := 0.0) -> bool:
	var q := Vector2(p.x, p.z)
	for r in WALK_RECTS:
		if (r as Rect2).grow(-margin).has_point(q):
			return true
	return false


## Le point est-il à l'air libre (pas dans un immeuble) ? Au-dessus des toits, tout est libre.
static func open_air(p: Vector3, margin := 0.3) -> bool:
	return p.y > ROOF_H or walkable(p, margin)


## Ramène un point au sol praticable le plus proche (personnages scriptés : rues adjacentes, station, mairie)
static func walk_clamp(p: Vector3, margin := 0.35) -> Vector3:
	if walkable(p, margin):
		return p
	var best := p
	var bd := INF
	for r in WALK_RECTS:
		var g := (r as Rect2).grow(-margin)
		var q := Vector3(clampf(p.x, g.position.x, g.end.x), p.y, clampf(p.z, g.position.y, g.end.y))
		var d := Vector2(q.x - p.x, q.z - p.z).length_squared()
		if d < bd:
			bd = d
			best = q
	return best


## Point de caméra autour d'une cible qui ne tombe jamais dans un immeuble : un plan prévu « derrière » une façade
## est pris en miroir de l'autre côté de la cible (même distance, même hauteur, on filme la façade de face) ; à défaut,
## la caméra se rapproche de la cible jusqu'à l'air libre.
static func camera_point(target: Vector3, p: Vector3) -> Vector3:
	if open_air(p):
		return below_trees(p, target)
	var off := p - target
	for m in [Vector3(off.x, off.y, -off.z), Vector3(-off.x, off.y, off.z), Vector3(-off.x, off.y, -off.z)]:
		var q: Vector3 = target + m
		if open_air(q) and open_air(target + m * 0.5):
			return below_trees(q, target)
	for i in range(1, 20):
		var q := target + off * (1.0 - float(i) / 20.0)
		if open_air(q):
			return below_trees(q, target)
	return target + Vector3(0.0, maxf(off.y, 1.6), 0.0)


## Une caméra dans le feuillage des platanes du boulevard (alignements TREE_ROWS) passe sous les branches, ou
## au-dessus des houppiers pour un plan déjà haut ; sous les branches, on s'écarte de l'alignement des troncs.
static func below_trees(p: Vector3, target := Vector3.ZERO) -> Vector3:
	if p.y > 3.4 and p.y < 27.5 and absf(p.x) < BLVD_END:
		for row in TREE_ROWS:
			var dz := p.z - float(row)
			if absf(dz) < 4.5:
				if p.y >= 12.0:
					p.y = 28.0
				else:
					p.y = 3.2
					if absf(dz) < 1.6:
						p.z = float(row) + (1.6 if target.z > p.z else -1.6)
				break
	return p


## Itinéraire de la patrouille de passage (Police.patrol_pass). Sans cordon : elle entre par l'est et repart par
## l'ouest. Un cordon barre la chaussée (`cordon_x` < 112) : elle descend la rue des Cerisiers, remonte le boulevard
## (voie vers +X) jusqu'à `stop_x` (toujours devant la ligne), fait demi-tour sur la largeur de la chaussée (au pas :
## rayon de braquage ~2,2 m) et repart vers l'ouest. À l'ouest de x = -58, des voitures sont garées des deux côtés :
## on y roule au milieu de la chaussée. Renvoie {"start", "yaw", "leg1", "park_yaw", "leg2", "leg2_k" (vitesse)}.
static func patrol_route(stop_x: float, cordon_x: float, lane_in: float) -> Dictionary:
	var mid_w := -48.0                 # à l'ouest de x = -60 : voitures garées des deux côtés
	var out_leg: Array[Vector3] = []
	if cordon_x >= 112.0:
		stop_x = clampf(stop_x, -40.0, 80.0)
		out_leg.append(Vector3(mid_w, 0.0, lane_in))
		out_leg.append(Vector3(mid_w - 10.0, 0.0, ROAD_Z))
		out_leg.append(Vector3(-125.0, 0.0, ROAD_Z))
		var in_leg: Array[Vector3] = [Vector3(stop_x + 6.0, 0.0, lane_in), Vector3(stop_x, 0.0, lane_in)]
		return {"start": Vector3(118.0, 0.0, lane_in), "yaw": PI / 2.0, "park_yaw": PI / 2.0, "leg2_k": 1.6,
			"leg1": in_leg, "leg2": out_leg}
	var lane_out := ROAD_Z1 - 1.75     # voie vers +X (côté nord)
	var sx: float = (SIDE_NORTH[0] + SIDE_NORTH[1]) * 0.5 + 1.5
	stop_x = maxf(minf(stop_x, cordon_x - 16.0), sx + 14.0)
	var leg1: Array[Vector3] = [Vector3(sx, 0.0, 30.0), Vector3(sx, 0.0, ROAD_Z1 + 2.5), Vector3(sx + 4.0, 0.0, lane_out),
		Vector3(stop_x - 6.0, 0.0, lane_out), Vector3(stop_x, 0.0, lane_out)]
	var c := Vector3(stop_x + 7.0, 0.0, ROAD_Z + 0.15)
	var r := 2.45
	out_leg.append(Vector3(stop_x + 3.5, 0.0, c.z + r - 0.35))
	for i in 5:
		var t := PI * float(i) / 4.0
		out_leg.append(c + Vector3(sin(t) * r, 0.0, cos(t) * r))
	out_leg.append(Vector3(c.x - 4.0, 0.0, lane_in))
	out_leg.append(Vector3(mid_w, 0.0, lane_in))
	out_leg.append(Vector3(mid_w - 10.0, 0.0, ROAD_Z))
	out_leg.append(Vector3(-125.0, 0.0, ROAD_Z))
	return {"start": Vector3(sx, 0.0, float(SIDE_NORTH[2]) - 4.0), "yaw": 0.0, "park_yaw": -PI / 2.0, "leg2_k": 0.8,
		"leg1": leg1, "leg2": out_leg}
