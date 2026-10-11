class_name CastLooks
extends RefCounted
## Apparence et identité des personnages d'histoire : nom affiché, corps (assets/character/<variant>.glb), tenue
## (clés de Human.DEFAULT_OUTFIT), voix des sons génériques (m1/m2/f1), couleur du nom dans les sous-titres.
## Le module Personnages remplace les corps génériques par des modèles dédiés et enrichit les tenues.

const LOOKS := {
	"sam": {"name": "Sam", "variant": "male_a", "voice": "m1", "color": Color(0.95, 0.95, 0.95),
		"outfit": {"top": "hoodie", "top_color": Color(0.17, 0.19, 0.24), "head": "", "backpack": true}},
	"nadia": {"name": "Nadia", "variant": "female_c", "voice": "f1", "color": Color(0.98, 0.55, 0.45),
		"outfit": {"top": "jacket", "top_color": Color(0.42, 0.12, 0.12), "head": "", "vest": false}},
	"karim": {"name": "Karim", "variant": "male_c", "voice": "m2", "color": Color(0.55, 0.8, 1.0),
		"outfit": {"top": "hoodie", "top_color": Color(0.08, 0.08, 0.09), "head": "cap", "head_color": Color(0.1, 0.1, 0.1)}},
	"ines": {"name": "Inès", "variant": "female_a", "voice": "f1", "color": Color(0.6, 0.95, 0.6),
		"outfit": {"top": "hoodie", "top_color": Color(0.85, 0.85, 0.82), "vest": true, "head": "", "backpack": true}},
	"lou": {"name": "Lou", "variant": "female_b", "voice": "f1", "color": Color(1.0, 0.85, 0.4),
		"outfit": {"top": "jacket", "top_color": Color(0.25, 0.3, 0.22), "head": "beanie", "head_color": Color(0.5, 0.15, 0.1)}},
	"jo": {"name": "Jo", "variant": "male_e", "voice": "m1", "color": Color(0.85, 0.75, 0.6),
		"outfit": {"top": "tshirt", "top_color": Color(0.3, 0.3, 0.32), "head": ""}},
	"mme_ferreira": {"name": "Mme Ferreira", "variant": "female_d", "voice": "f1", "color": Color(0.8, 0.7, 0.95),
		"outfit": {"top": "jacket", "top_color": Color(0.3, 0.25, 0.35), "head": ""}},
	"commissaire": {"name": "Commissaire Rivière", "variant": "male_d", "voice": "m2", "color": Color(0.6, 0.7, 0.95),
		"outfit": {"top": "jacket", "top_color": Color(0.12, 0.14, 0.2), "head": ""}},
	"presentatrice": {"name": "Présentatrice", "variant": "female_b", "voice": "f1", "color": Color(0.9, 0.9, 1.0),
		"outfit": {"top": "jacket", "top_color": Color(0.1, 0.12, 0.25), "head": ""}},
	"narrateur": {"name": "", "variant": "male_a", "voice": "m1", "color": Color(0.85, 0.85, 0.85), "outfit": {}},
}


static func look(id: String) -> Dictionary:
	return LOOKS.get(id, {"name": id.capitalize(), "variant": "male_b", "voice": "m1", "color": Color(0.9, 0.9, 0.9), "outfit": {}})
