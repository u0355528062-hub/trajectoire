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
# Positions au sol ; le module Carte les ajuste aux bâtiments réels (voir docs/CAMPAGNE.md § « Lieux »).
const SPOTS := {
	"depart": Vector3(0.0, 0.0, 0.0),            # point de départ d'origine du joueur
	"square": Vector3(-24.0, 0.0, 14.0),         # square (rassemblement des premiers jours)
	"metro": Vector3(15.0, 0.0, 10.5),           # sortie du métro
	"kiosque": Vector3(28.0, 0.0, 11.5),
	"morris": Vector3(-6.0, 0.0, 12.0),          # colonne Morris (affiches)
	"wallace": Vector3(6.5, 0.0, -17.0),
	"abribus": Vector3(0.0, 0.0, -15.0),
	"parking": Vector3(-27.0, 0.0, -19.0),
	"velib": Vector3(18.0, 0.0, -14.0),
	"bar_qg": Vector3(-12.0, 0.0, 16.0),         # café-bar « Le Zinc » de Jo (QG)
	"boulangerie": Vector3(8.0, 0.0, 16.5),
	"supermarche": Vector3(34.0, 0.0, -23.5),    # supérette / supermarché (étiquettes de prix)
	"banque": Vector3(-4.0, 0.0, -23.5),
	"pharmacie": Vector3(22.0, 0.0, 16.5),
	"carrefour_ouest": Vector3(-50.0, 0.0, -7.4),
	"rue_nord": Vector3(-50.0, 0.0, 40.0),       # rue adjacente nord (rue des Cerisiers)
	"rue_nord_fond": Vector3(-50.0, 0.0, 70.0),
	"rue_sud": Vector3(-77.0, 0.0, -45.0),       # rue adjacente sud (rue de la Forge)
	"rue_sud_fond": Vector3(-77.0, 0.0, -75.0),
	"station_service": Vector3(-77.0, 0.0, -70.0),
	"cordon": Vector3(54.0, 0.0, -7.4),          # ligne de police d'origine (en travers du boulevard)
	"parvis_mairie": Vector3(92.0, 0.0, -7.4),   # parvis de la mairie (bout est du boulevard)
	"mairie": Vector3(102.0, 0.0, -7.4),
}


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
