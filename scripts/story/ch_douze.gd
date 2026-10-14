extends ChapterBase
## Chapitre 1 « On était douze » (jeudi, fin d'après-midi) : douze au square, tracts et affiches, Karim et la
## vitrine de la banque, une patrouille, Inès. Histoire : BIBLE.md § 4.1.

const D := DlgDouze.DLG

var _tracts: Objective
var _posters: Objective


func run() -> void:
	music("espoir")
	ambience("square")
	await open_chapter("Chapitre 1 — On était douze", "Jeudi 11 mars — 18 h 30")
	spawn("nadia", near("square", 1.5, -1.0), "player")
	spawn("karim", near("square", -1.2, -1.6), "nadia")
	await fade_in(1.0)
	await shot({"from": cam("square", 26.0, 7.0, 210.0), "to": cam("square", 14.0, 4.0, 195.0), "look": "square",
		"dur": 5.0, "fov": 50.0, "ease": "inout"})
	await shot({"from": cam("nadia", 3.5, 1.7, 160.0), "to": cam("nadia", 2.8, 1.65, 175.0), "look": "nadia",
		"dur": 2.0, "fov": 40.0, "cut": true})
	await frame("player", "nadia")
	await dialogue(D, "accueil")
	gesture("nadia", "give", 1.5)
	await fade_out(0.4)
	cine_end()
	await fade_in(0.5)
	await _tractage()
	await _banque()
	await _patrouille()
	await _ines()
	await _bilan()


func _tractage() -> void:
	follow("karim", null)
	walk_to("karim", near("morris", 1.5, 1.0), false, 30.0)
	_tracts = tool_obj("tracts", "Distribue des tracts aux passants", {"type": "event", "event": "tract_given", "count": 8,
		"waypoint": "square"}, "tract_tool", "square", 12.0)
	_posters = tool_obj("affiches", "Colle des affiches (colonne Morris, panneaux d'affichage libre)",
		{"type": "event", "event": "poster_stuck", "count": 2, "filter": {"legal": true}, "waypoint": "morris"},
		"poster_tool", "morris", 5.0)
	hint("Tends un tract aux passants (E). Beaucoup refusent : c'est normal, insiste avec le sourire.", 7.0)
	await wait(20.0)
	bark("nadia", "Demande-leur combien ils paient le gaz. Ça marche à tous les coups.")
	await objectives_all([_tracts, _posters])
	clear_objectives()


func _banque() -> void:
	walk_to("karim", near("banque", 1.5, 2.5), true, 30.0)
	bark("karim", "Sam ! Viens voir deux secondes. Devant la banque.")
	var o := talk_obj("karim", "Karim t'appelle devant la banque", "karim")
	await complete(o)
	clear_objectives()
	cine_begin()
	await shot({"from": cam("banque", 9.0, 2.0, 20.0), "to": cam("banque", 6.5, 1.8, 10.0), "look": "banque",
		"dur": 2.5, "fov": 45.0})
	await frame("player", "karim")
	await dialogue(D, "banque")
	cine_end()
	if flag("ch1_tag_banque"):
		gesture("karim", "spray", 6.0)
		var tag := tool_obj("tag", "Tague la vitrine de la banque", {"type": "event", "event": "spray_tag", "count": 1,
			"waypoint": "banque"}, "spray_tool", "banque", 4.0)
		var back := objective("renoncer", "…ou change d'avis : retourne au square",
			{"type": "reach", "spot": "square", "radius": 6.0, "optional": true, "autoplay_after": 5.0})
		var first := await objective_any([tag, back])
		clear_objectives()
		if first == back:
			set_flag("ch1_tag_banque", false)
			set_flag("ch1_tag_karim", true)
			rel_add("karim", -6)
			rel_add("nadia", 6)
			add_stat("notoriete", -0.05, "Sam renonce au tag")
			bark("karim", "Sérieux ? Tu me laisses en plan ? …Bon. Je finis tout seul.")
		else:
			Campaign.log_action("casse", "Tag sur la vitrine de la Banque Hexa", -1.0)
			add_stat("opinion", -1.0, "tag sur la banque")
			bark("karim", "Magnifique. On dirait du Banksy. En moins bien.")
	elif flag("ch1_tag_karim"):
		gesture("karim", "spray", 6.0)
		Campaign.log_action("casse", "Tag de Karim sur la vitrine de la Banque Hexa", -0.5)
		add_stat("opinion", -0.5, "tag sur la banque")
	if flag("ch1_tag"):
		await wait(5.0)
	walk_to("karim", near("square", -1.2, -1.6), false, 40.0)
	var o2 := objective("retour", "Retourne au square", {"type": "reach", "spot": "square", "radius": 6.0})
	await complete(o2)
	clear_objectives()


func _patrouille() -> void:
	var k := actor("karim")
	if k and not k.arrived(2.0):
		spawn("karim", near("square", -1.2, -1.6), "player")
	patrol()
	await wait(3.0)
	cine_begin()
	await shot({"from": cam("square", 8.0, 2.2, 200.0), "look": near("square", 0.0, -14.0), "dur": 3.0, "fov": 45.0})
	await frame("player", "nadia")
	await dialogue(D, "patrouille")
	cine_end()
	if flag("ch1_vanne"):
		Campaign.log_action("choix", "Sam a provoqué une patrouille")
	var o := objective("calme", "Laisse passer la patrouille", {"type": "survive", "timer": 12.0})
	await complete(o)
	clear_objectives()


func _ines() -> void:
	spawn("ines", near("square", 8.0, 4.0), "nadia")
	await walk_to("ines", near("square", 2.2, 0.5), false, 12.0)
	face("ines", "player")
	cine_begin()
	await shot({"from": cam("ines", 4.0, 1.7, 220.0), "look": "ines", "dur": 1.5, "fov": 42.0})
	await frame("player", "ines")
	await dialogue(D, "ines")


func _bilan() -> void:
	await frame("player", "nadia", -0.7)
	await dialogue(D, "bilan")
	var given := _tracts.progress if _tracts else 0
	var stuck := _posters.progress if _posters else 0
	add_stat("mobilisation", 4.0 + floorf(given / 3.0) + stuck, "rassemblement du square")
	bank_casse(1 if flag("ch1_tag_banque") else 0)
	music("theme")
	await shot({"from": cam("square", 4.0, 1.6, 180.0), "to": cam("square", 22.0, 14.0, 200.0), "look": "square",
		"dur": 6.0, "fov": 45.0, "fov_to": 55.0})
	await fade_out(1.2)
	cine_end()
