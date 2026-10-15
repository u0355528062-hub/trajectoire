class_name CastLooks
extends RefCounted
## Apparence et identité des personnages d'histoire : nom affiché, corps (assets/character/<variant>.glb), tenue
## (clés de Human.DEFAULT_OUTFIT), voix des sons génériques (m1/m2/f1), couleur du nom dans les sous-titres.
## Les personnages principaux ont un corps dédié (male_f..i, female_e..f : âge, origine, coupe, barbe cohérents
## avec la bible) ; la tenue utilise aussi "vest_style", "camera", "sash", "eyes" (voir Human).

const LOOKS := {
	# Sam Diallo, 24 ans, livreur à vélo : sweat marine, jean, baskets blanches, sac à dos de livraison
	"sam": {"name": "Sam", "variant": "male_f", "voice": "m1", "color": Color(0.95, 0.95, 0.95),
		"outfit": {"top": "hoodie", "top_color": Color(0.11, 0.14, 0.21), "head": "", "backpack": true,
			"bag_color": Color(0.05, 0.3, 0.3), "pants_tex": true, "pants_color": Color(0.85, 0.85, 0.85),
			"shoe_color": Color(0.88, 0.88, 0.86)}},
	# Nadia Benali, 45 ans, aide-soignante, déléguée : doudoune bordeaux, pantalon noir, chignon
	"nadia": {"name": "Nadia", "variant": "female_e", "voice": "f1", "color": Color(0.98, 0.55, 0.45),
		"outfit": {"top": "jacket", "top_color": Color(0.36, 0.08, 0.1), "head": "", "vest": false,
			"pants_tex": false, "pants_color": Color(0.06, 0.06, 0.07), "shoe_color": Color(0.08, 0.07, 0.07)}},
	# Karim Haddad, 23 ans, intérimaire : sweat noir, casquette noire, jean délavé
	"karim": {"name": "Karim", "variant": "male_g", "voice": "m2", "color": Color(0.55, 0.8, 1.0),
		"outfit": {"top": "hoodie", "top_color": Color(0.06, 0.06, 0.065), "head": "cap", "head_color": Color(0.08, 0.08, 0.09),
			"pants_tex": true, "pants_color": Color(1.15, 1.15, 1.15), "shoe_color": Color(0.06, 0.06, 0.06)}},
	# Inès Morel, 26 ans, interne, street medic : sweat gris clair, gilet blanc à croix rouges, sac
	"ines": {"name": "Inès", "variant": "female_a", "voice": "f1", "color": Color(0.6, 0.95, 0.6),
		"outfit": {"top": "hoodie", "top_color": Color(0.55, 0.56, 0.57), "vest": true, "vest_style": "medic", "head": "",
			"backpack": true, "bag_color": Color(0.08, 0.08, 0.09), "pants_tex": false, "pants_color": Color(0.1, 0.1, 0.12),
			"shoe_color": Color(0.2, 0.21, 0.25)}},
	# Lou Garnier, 31 ans, vidéaste : parka kaki, bonnet rouille, caméra en bandoulière
	"lou": {"name": "Lou", "variant": "female_b", "voice": "f1", "color": Color(1.0, 0.85, 0.4),
		"outfit": {"top": "jacket", "top_color": Color(0.22, 0.25, 0.16), "head": "beanie", "head_color": Color(0.45, 0.16, 0.08),
			"camera": true, "pants_tex": true, "pants_color": Color(0.35, 0.35, 0.38), "shoe_color": Color(0.1, 0.09, 0.08)}},
	# Jo Lemaire, 62 ans, patron du Zinc, ancien docker : pull marine, pantalon de toile, barbe grise
	"jo": {"name": "Jo", "variant": "male_h", "voice": "m1", "color": Color(0.85, 0.75, 0.6),
		"outfit": {"top": "sweater", "top_color": Color(0.1, 0.13, 0.2), "head": "", "pants_tex": false,
			"pants_color": Color(0.24, 0.21, 0.16), "shoe_color": Color(0.16, 0.1, 0.06)}},
	# Maria Ferreira, 74 ans : gilet de laine prune, pantalon gris, cheveux blancs bouclés
	"mme_ferreira": {"name": "Mme Ferreira", "variant": "female_f", "voice": "f1", "color": Color(0.8, 0.7, 0.95),
		"outfit": {"top": "sweater", "top_color": Color(0.3, 0.17, 0.27), "head": "", "pants_tex": false,
			"pants_color": Color(0.3, 0.3, 0.32), "shoe_color": Color(0.12, 0.08, 0.06)}},
	# Commissaire Rivière, 52 ans : blouson sombre, écharpe tricolore (sommations), tempes grises
	"commissaire": {"name": "Commissaire Rivière", "variant": "male_i", "voice": "m2", "color": Color(0.6, 0.7, 0.95),
		"outfit": {"top": "jacket", "top_color": Color(0.05, 0.06, 0.09), "head": "", "sash": true, "pants_tex": false,
			"pants_color": Color(0.05, 0.06, 0.09), "shoe_color": Color(0.03, 0.03, 0.03)}},
	# présentatrice de Canal Continu : pull fin bleu nuit, carré net
	"presentatrice": {"name": "Présentatrice", "variant": "female_c", "voice": "f1", "color": Color(0.9, 0.9, 1.0),
		"outfit": {"top": "sweater", "top_color": Color(0.08, 0.1, 0.22), "head": "", "pants_tex": false,
			"pants_color": Color(0.06, 0.06, 0.07), "shoe_color": Color(0.03, 0.03, 0.03)}},
	"narrateur": {"name": "", "variant": "male_a", "voice": "m1", "color": Color(0.85, 0.85, 0.85), "outfit": {}},
}


static func look(id: String) -> Dictionary:
	return LOOKS.get(id, {"name": id.capitalize(), "variant": "male_b", "voice": "m1", "color": Color(0.9, 0.9, 0.9), "outfit": {}})
