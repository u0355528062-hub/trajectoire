extends ChapterBase
## Chapitre 3 « Premier cortège » (mardi, crépuscule) : Sam au mégaphone mène le cortège du square au parvis de
## la mairie ; cordon du commissaire Rivière ; sit-in ou forcer le cordon ; Karim interpellé. BIBLE.md § 4.3.

const D := DlgCortege.DLG
const FRIENDS := ["nadia", "karim", "ines", "lou"]


func run() -> void:
	music("marche")
	ambience("cortege")
	await open_chapter("Chapitre 3 — Premier cortège", "Mardi 16 mars — 19 h 40")
	spawn("nadia", near("square", 1.6, -1.0), "player")
	spawn("karim", near("square", -1.4, -1.4), "player")
	spawn("ines", near("square", 2.4, 1.2), "player")
	spawn("lou", near("square", -2.6, 0.8), "player")
	gesture("lou", "film", 20.0)
	await fade_in(1.2)
	await shot({"from": cam("square", 6.0, 14.0, 180.0), "to": cam("square", 18.0, 8.0, 230.0), "look": "square",
		"dur": 6.0, "fov": 55.0, "fov_to": 48.0, "ease": "inout"})
	await frame("player", "nadia")
	await dialogue(D, "depart")
	await fade_out(0.4)
	cine_end()
	await fade_in(0.5)
	await _marche()
	await _cordon()
	await _arrestation()
	await _apres()


func _marche() -> void:
	for f in FRIENDS:
		follow(f, "player")
	var list: Array = []
	var march := objective("parvis", "Mène le cortège jusqu'au parvis de la mairie", {"type": "reach",
		"spot": "parvis_mairie", "radius": 14.0})
	list.append(march)
	if flag("ch3_megaphone"):
		list.append(tool_obj("slogans", "Lance des slogans au mégaphone", {"type": "event", "event": "megaphone",
			"count": 3}, "megaphone_tool", "player", 50.0))
		hint("Le cortège te suit. Un slogan court, et laisse les gens le reprendre.", 7.0)
	else:
		hint("Le cortège te suit. Avance au pas, sans courir.", 6.0)
	_march_barks(march)
	await objectives_all(list)
	clear_objectives()


func _march_barks(o: Objective) -> void:
	var lines := [["karim", "Regarde les fenêtres. Y a des gens qui filment. Y en a qui applaudissent !"],
		["nadia", "Pas trop vite devant ! Les derniers décrochent !"],
		["ines", "Un monsieur m'a demandé si c'était pour les retraites. J'ai dit : pour tout."],
		["lou", "Sam, retourne-toi deux secondes. Regarde derrière toi. …Voilà. Ça, c'est vous."]]
	for l in lines:
		await wait(14.0)
		if not o.is_active():
			return
		bark(l[0], l[1])


func _cordon() -> void:
	for f in FRIENDS:
		follow(f, null)
	set_tension(0.15)
	spawn("commissaire", near("parvis_mairie", -5.0, 3.0), "player")
	cine_begin()
	await shot({"from": cam("parvis_mairie", 22.0, 1.2, 270.0), "to": cam("parvis_mairie", 17.0, 1.4, 262.0),
		"look": "parvis_mairie", "dur": 3.5, "fov": 40.0})
	await shot({"from": cam("commissaire", 3.0, 1.5, 250.0), "look": "commissaire", "dur": 1.5, "fov": 35.0, "cut": true})
	await frame("player", "nadia")
	await dialogue(D, "cordon")
	if flag("ch3_choix", "") == "forcer":
		await _forcer()
	else:
		await _sitin()


func _sitin() -> void:
	await dialogue(D, "sitin")
	for f in ["nadia", "ines", "karim"]:
		gesture(f, "sit", 40.0)
	cine_end()
	freeze_tension(true)
	hint("Assieds-toi avec les autres et ne bouge plus. Ne réponds pas aux provocations.", 6.0)
	var o := objective("sitin", "Tiens le sit-in devant le cordon", {"type": "hold", "waypoint": pos_of("player"),
		"radius": 7.0, "sec": 30.0, "fail_if": {"tension_above": 0.85}})
	var ok := await complete(o)
	clear_objectives()
	if ok:
		add_stat("opinion", 5.0, "sit-in pacifique devant la mairie")
		add_stat("mobilisation", 10.0, "sit-in devant la mairie")
		Campaign.log_action("sitin", "Sit-in pacifique de 40 personnes devant le cordon de la mairie", 5.0)
	else:
		set_flag("ch3_sitin_rompu", true)
		add_stat("opinion", 1.0, "sit-in interrompu")
		add_stat("mobilisation", 6.0, "sit-in devant la mairie")
	cine_begin()


func _forcer() -> void:
	await dialogue(D, "forcer")
	cine_end()
	freeze_tension(false)
	set_tension(0.65)
	add_stat("opinion", -4.0, "cordon forcé devant la mairie")
	add_stat("repression", 0.08, "cordon forcé devant la mairie")
	add_stat("mobilisation", 4.0, "les plus radicaux suivent")
	Campaign.log_action("heurts", "Heurts devant la mairie : le cortège tente de forcer le cordon", -4.0)
	hint("Gaz : recule, couvre-toi le visage. Rester au contact, c'est risquer l'interpellation.", 7.0)
	var o := objective("tenir", "Tiens bon… ou recule", {"type": "survive", "timer": 20.0})
	await complete(o)
	clear_objectives()
	set_tension(0.3)
	freeze_tension(true)
	cine_begin()


func _arrestation() -> void:
	await walk_to("karim", near("commissaire", -3.0, -1.0), false, 6.0)
	await shot({"from": cam("karim", 5.0, 2.2, 220.0), "look": "karim", "dur": 1.5, "fov": 40.0, "shake": 0.4})
	gesture("karim", "surrender", 6.0)
	await dialogue(D, "arrestation")
	match str(flag("ch3_karim", "")):
		"libere":
			await walk_to("karim", near("player", -1.2, -1.0), false, 6.0)
			face("karim", "player")
		"filme":
			add_stat("opinion", 3.0, "interpellation filmée et diffusée")
			Campaign.count("videos")
			Campaign.log_action("video", "L'interpellation de Karim filmée : le policier pousse le premier", 3.0)
			await fade_out(0.4)
			despawn("karim")
			await fade_in(0.4)
		_:
			set_flag("ch3_karim", "gav")
			add_stat("notoriete", 0.02, "ami interpellé")
			Campaign.log_action("interpellation", "Karim Haddad placé en garde à vue", -1.0)
			await fade_out(0.4)
			despawn("karim")
			await fade_in(0.4)


func _apres() -> void:
	set_tension(0.05)
	if flag("riviere_connait_sam") or flag("ch2_accroche"):
		await frame("player", "commissaire", 0.6, 40.0)
	else:
		await frame("player", "nadia")
	await dialogue(D, "apres")
	bank_casse(2 if flag("ch3_choix", "") == "forcer" else 0)
	music("theme")
	await shot({"from": cam("parvis_mairie", 16.0, 3.0, 270.0), "to": cam("parvis_mairie", 34.0, 16.0, 275.0),
		"look": "parvis_mairie", "dur": 6.0, "fov": 45.0, "fov_to": 55.0})
	await fade_out(1.2)
	cine_end()
