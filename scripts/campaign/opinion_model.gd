class_name OpinionModel
extends Node
## Opinion publique : traduit ce qui se passe dans la rue (événements de la foule, vidéos publiées, violences
## policières filmées, casse…) en variations des jauges de campagne (opinion, mobilisation, répression, notoriété)
## et note les faits marquants dans le journal (repris par le JT du bilan).
## VERSION SQUELETTE : quelques correspondances ; le module Opinion & actualités la remplace (barème complet,
## témoins, caméras, plafonds par chapitre) en gardant l'interface publique.

var director: ChapterDirector


func bind(d: ChapterDirector) -> void:
	director = d
	d.event.connect(on_event)


func on_event(type: String, d: Dictionary) -> void:
	match type:
		"glass_break":
			Campaign.add_stat("opinion", -0.4, "vitrine brisée")
			Campaign.count("vitres")
		"car_burn":
			Campaign.add_stat("opinion", -2.0, "véhicule incendié")
			Campaign.count("voitures")
		"cop_hit":
			Campaign.add_stat("opinion", -0.3, "projectile sur la police")
		"tract_given":
			Campaign.add_stat("opinion", 0.15, "tract distribué")
			Campaign.count("tracts")
		"poster_stuck":
			Campaign.add_stat("opinion", 0.1, "affiche collée")
			Campaign.count("affiches")
		"film_clip":
			Campaign.count("videos")
