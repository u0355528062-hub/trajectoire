extends ChapterScript
## Chapitre de démonstration du squelette : carton de titre, plan de caméra, dialogue à choix, objectif.


func run() -> void:
	await fade_out(0.01)
	await title_card("DÉMONSTRATION", "Jeudi 9 mars — 18 h 40", 2.0)
	spawn("nadia", "square", "player")
	cine_begin()
	await fade_in(0.8)
	await shot({"from": spot("square") + Vector3(-4, 2.2, -4), "look": "nadia", "dur": 2.5, "fov": 45})
	cine_end()
	await dialogue(DlgDemo.DLG)
	var o := objective("aller", "Rejoins la colonne Morris", {"type": "reach", "spot": "morris", "radius": 3.0})
	await complete(o)
	await say("nadia", "Bien. On se retrouve demain.")
