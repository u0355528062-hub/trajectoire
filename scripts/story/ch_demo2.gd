extends ChapterScript
## Deuxième chapitre de démonstration : un objectif « survivre » et la fin de la campagne de démonstration.


func run() -> void:
	await title_card("DÉMONSTRATION (SUITE)", "Vendredi 10 mars — 21 h 10", 2.0)
	var o := objective("tenir", "Reste dans le quartier 20 secondes", {"type": "survive", "timer": 20.0})
	await complete(o)
