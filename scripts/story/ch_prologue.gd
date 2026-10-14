extends ChapterBase
## Prologue « La note » (lundi matin) : la carte refusée à la supérette, le Zinc et la loi à la télé, Karim,
## Mme Ferreira, l'affiche de Nadia. Apprendre à marcher, regarder, parler. Histoire : BIBLE.md § 4.0.

const D := DlgPrologue.DLG


func run() -> void:
	music("matin")
	ambience("rue_matin")
	await fade_out(0.01)
	await title_card("BLOCUS", "", 2.5)
	await title_card("Prologue — La note", "Lundi 8 mars 2027 — 8 h 10", 3.0)
	cine_begin()
	await fade_in(1.4)
	# le boulevard qui se réveille, puis Sam à la caisse
	await shot({"from": cam("supermarche", 34.0, 11.0, 130.0), "to": cam("supermarche", 18.0, 4.5, 155.0),
		"look": "supermarche", "dur": 5.5, "fov": 55.0, "fov_to": 48.0, "ease": "inout"})
	await shot({"from": cam("player", 2.6, 1.75, 200.0), "to": cam("player", 1.9, 1.65, 225.0), "look": "player",
		"dur": 3.0, "fov": 40.0, "cut": true, "dof": 2.2})
	await dialogue(D, "caisse")
	await fade_out(0.5)
	cine_end()
	await fade_in(0.6)
	await _go_to_zinc()
	await _zinc()
	await _ferreira()
	await _nadia()
	await _ending()


func _go_to_zinc() -> void:
	spawn("jo", near("bar_qg", 0.8, -1.2), near("bar_qg", 0.8, -8.0))
	hint("Marche avec ZQSD (ou les flèches), regarde avec la souris.", 8.0)
	var zinc := objective("zinc", "Va au Zinc, le café de Jo", {"type": "reach", "spot": "bar_qg", "radius": 4.0})
	var ardoise := look_obj("ardoise", "En passant, regarde l'ardoise de la boulangerie", "boulangerie", 12.0)
	if ardoise:
		ardoise.optional = true
	var first := await objective_any([zinc, ardoise])
	if first == ardoise and ardoise.state == "done":
		await dialogue(D, "ardoise")
		await complete(zinc)
	clear_objectives()


func _zinc() -> void:
	face("jo", "player")
	var o := talk_obj("jo", "Parle à Jo", "jo")
	hint("Approche-toi de quelqu'un et appuie sur E pour lui parler.", 6.0)
	await complete(o)
	clear_objectives()
	cine_begin()
	ambience("cafe")
	await shot({"from": cam("bar_qg", 7.0, 2.4, 160.0), "to": cam("bar_qg", 5.0, 2.0, 175.0), "look": "jo",
		"dur": 2.5, "fov": 45.0})
	await frame("player", "jo")
	await dialogue(D, "zinc")


## Appelé par le dialogue : Karim débarque au Zinc
func karim_arrive() -> void:
	spawn("karim", near("bar_qg", 10.0, -3.5), "jo")
	await shot({"from": cam("bar_qg", 6.0, 1.8, 215.0), "look": "karim", "dur": 0.05, "fov": 45.0, "cut": true})
	await walk_to("karim", near("bar_qg", -1.0, -1.8), false, 7.0)
	face("karim", "player")
	await frame("jo", "karim", -0.6)


func _ferreira() -> void:
	spawn("mme_ferreira", near("bar_qg", -9.0, -2.8), "bar_qg")
	gesture("mme_ferreira", "carry", 8.0)
	await shot({"from": cam("bar_qg", 5.5, 1.6, 230.0), "look": "mme_ferreira", "dur": 0.05, "fov": 40.0, "cut": true})
	await walk_to("mme_ferreira", near("bar_qg", -2.0, -2.8), false, 8.0)
	face("mme_ferreira", "player")
	gesture("mme_ferreira", "pick", 1.5)
	await frame("player", "mme_ferreira")
	await dialogue(D, "ferreira")
	if flag("ch0_aide_ferreira"):
		await fade_out(0.4)
		cine_end()
		await fade_in(0.5)
		var o := objective("porter", "Raccompagne Mme Ferreira (au-dessus de la pharmacie)",
			{"type": "reach", "spot": "pharmacie", "radius": 3.5})
		walk_to("mme_ferreira", near("pharmacie", -0.8, -1.4), false, 60.0)
		_karim_leaves()
		await wait(5.0)
		bark("mme_ferreira", "Avant je prenais le bus. Maintenant je marche. C'est bon pour les jambes, qu'ils disent.")
		await complete(o)
		clear_objectives()
		face("mme_ferreira", "player")
		cine_begin()
		await frame("player", "mme_ferreira", 0.6, 38.0)
		await dialogue(D, "porte")
		await fade_out(0.5)
		despawn("mme_ferreira")
		cine_end()
		await fade_in(0.5)
	else:
		follow("jo", actor("mme_ferreira"))
		walk_to("mme_ferreira", near("pharmacie", -0.8, -1.4), false, 60.0)
		await shot({"from": cam("bar_qg", 9.0, 3.0, 200.0), "to": cam("bar_qg", 11.0, 4.0, 210.0),
			"look": "mme_ferreira", "dur": 3.0, "fov": 45.0})
		cine_end()
		_karim_leaves()


func _karim_leaves() -> void:
	bark("karim", "Je file à l'agence leur dire deux mots. Poliment. On s'appelle.")
	await walk_to("karim", "metro", false, 30.0)
	despawn("karim")


func _nadia() -> void:
	spawn("nadia", near("morris", 0.9, -0.9), "morris")
	gesture("nadia", "reach", 6.0)
	var o := talk_obj("nadia", "Quelqu'un colle une affiche sur la colonne Morris : va voir", "nadia")
	await complete(o)
	clear_objectives()
	face("nadia", "player")
	cine_begin()
	await shot({"from": cam("morris", 6.0, 2.2, 160.0), "to": cam("morris", 4.0, 1.9, 175.0), "look": "nadia",
		"dur": 2.0, "fov": 45.0})
	await frame("player", "nadia")
	await dialogue(D, "nadia")
	if flag("ch0_promesse"):
		gesture("nadia", "give", 1.5)
		Campaign.log_action("choix", "Sam a promis de venir au rassemblement")


func _ending() -> void:
	music("theme")
	await shot({"from": cam("morris", 3.0, 1.7, 200.0), "to": cam("morris", 16.0, 13.0, 205.0), "look": "morris",
		"dur": 6.0, "fov": 45.0, "fov_to": 55.0, "ease": "inout"})
	await dialogue(D, "fin")
	await fade_out(1.2)
	cine_end()
