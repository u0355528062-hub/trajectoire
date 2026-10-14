extends ChapterBase
## Chapitre 5 « Blocus » (mardi, aube puis matin) : grève générale ; blocage de la station de la rue de la Forge
## puis du boulevard ; négociation avec le commissaire Rivière ; épilogue au Zinc devant le JT. La fin dépend des
## jauges et des choix (Story.ending_for_state). Histoire : BIBLE.md § 4.5 et § 6.

const D := DlgBlocus.DLG


func run() -> void:
	music("aube")
	ambience("blocage")
	add_stat("mobilisation", 30.0 + stat("opinion") * 0.8, "appel à la grève générale")
	if flag("temoignage_ferreira") or rel("mme_ferreira") >= 15:
		set_flag("ch5_ferreira_la", true)
	await open_chapter("Chapitre 5 — Blocus", "Mardi 6 avril — 5 h 50")
	_spawn_friends(near("bar_qg", 0.0, -1.5))
	spawn("jo", near("bar_qg", 0.8, -0.6), "player")
	await fade_in(1.5)
	await shot({"from": cam("bar_qg", 30.0, 12.0, 220.0), "to": cam("bar_qg", 9.0, 2.6, 195.0), "look": "bar_qg",
		"dur": 6.0, "fov": 55.0, "fov_to": 45.0, "ease": "inout"})
	await frame("player", "jo")
	await dialogue(D, "aube")
	await fade_out(0.4)
	cine_end()
	await fade_in(0.5)
	await _station()
	await _boulevard()
	await _negociation()
	await _epilogue()


func _friends() -> Array:
	var l := ["nadia", "ines", "lou"]
	if not flag("karim_prison"):
		l.append("karim")
	if flag("ch5_ferreira_la"):
		l.append("mme_ferreira")
	return l


func _spawn_friends(at: Vector3) -> void:
	var f := _friends()
	for i in f.size():
		var a := TAU * float(i) / float(f.size())
		spawn(f[i], at + Vector3(cos(a) * 2.0, 0.0, sin(a) * 2.0), "player")


func _follow_all(on: bool) -> void:
	for f in _friends():
		follow(f, "player" if on else null)


func _station() -> void:
	_follow_all(true)
	var o := objective("station", "Va bloquer la station-service de la rue de la Forge", {"type": "reach",
		"spot": "station_service", "radius": 10.0})
	await complete(o)
	clear_objectives()
	_follow_all(false)
	cine_begin()
	await shot({"from": cam("station_service", 16.0, 5.0, 30.0), "to": cam("station_service", 11.0, 3.0, 15.0),
		"look": "station_service", "dur": 4.0, "fov": 48.0})
	await frame("player", "nadia")
	await dialogue(D, "station")
	cine_end()
	hint("Reste avec les bloqueurs. Personne ne casse rien : c'est ce qui fait tenir le blocage.", 6.0)
	var h := objective("tenir_station", "Tiens le blocage de la station", {"type": "hold", "spot": "station_service",
		"radius": 12.0, "sec": 25.0})
	await complete(h)
	clear_objectives()
	add_stat("opinion", 3.0, "station-service bloquée sans heurts")
	Campaign.log_action("blocage", "Station Carbura de la rue de la Forge bloquée à l'aube", 3.0)


func _boulevard() -> void:
	_follow_all(true)
	var o := objective("boulevard", "Rejoins le blocage du boulevard", {"type": "reach", "spot": "abribus", "radius": 10.0})
	await complete(o)
	clear_objectives()
	_follow_all(false)
	music("marche")
	var list: Array = [objective("tenir_bd", "Tiens le boulevard jusqu'à 8 h", {"type": "hold", "spot": "abribus",
		"radius": 14.0, "sec": 40.0, "fail_if": {"tension_above": 0.9}})]
	list.append(tool_obj("tracts", "Explique le blocage aux automobilistes (tracts)", {"type": "event",
		"event": "tract_given", "count": 5, "optional": true}, "tract_tool", "abribus", 14.0))
	await wait(10.0)
	cine_begin()
	await frame("player", "nadia", -0.7)
	await dialogue(D, "automobiliste")
	cine_end()
	var ok := await complete(list[0])
	clear_objectives()
	if ok:
		add_stat("opinion", 3.0, "boulevard bloqué toute la matinée")
		Campaign.log_action("blocage", "Le boulevard des Ormes bloqué par %d personnes" % int(stat("mobilisation")), 3.0)
	else:
		set_flag("ch5_boulevard_perdu", true)


func _negociation() -> void:
	spawn("commissaire", near("abribus", 14.0, 2.0), "player")
	await walk_to("commissaire", near("player", 2.0, 0.0), false, 15.0)
	face("commissaire", "player")
	set_tension(0.3)
	cine_begin()
	await shot({"from": cam("commissaire", 6.0, 1.8, 200.0), "look": "commissaire", "dur": 2.0, "fov": 42.0})
	await frame("player", "commissaire")
	await dialogue(D, "nego")
	var args := 0
	for k in ["ch5_arg_prix", "ch5_arg_theo", "ch5_arg_ferreira", "ch5_arg_nombre"]:
		if flag(k):
			args += 1
	add_stat("opinion", 1.5 * args, "négociation avec la préfecture")
	if flag("ch5_arg_ferreira"):
		add_stat("opinion", 3.0, "Mme Ferreira face au commissaire")
		Campaign.log_action("temoignage", "Mme Ferreira, 74 ans, face au commissaire : « Vous allez me gazer, moi ? »", 3.0)
	match str(flag("ch5_issue", "accord")):
		"tenir":
			await _tenir()
		"affrontement":
			await _affrontement()
		_:
			set_flag("ch5_issue", "accord")
			await dialogue(D, "accord")
			add_stat("opinion", 4.0, "accord négocié : délégation reçue en préfecture")
			add_stat("repression", -0.05, "désescalade")
			cine_end()


func _tenir() -> void:
	if stat("opinion") >= 45.0 or stat("mobilisation") >= 150.0:
		await dialogue(D, "tenir_ok")
		despawn("commissaire")
		add_stat("opinion", 6.0, "le blocage tient, la police renonce à charger")
		Campaign.log_action("blocage", "La police renonce à disperser le blocage du boulevard", 6.0)
		cine_end()
		return
	await dialogue(D, "tenir_dur")
	cine_end()
	despawn("commissaire")
	set_tension(0.7)
	hint("Restez assis. Couvre-toi le visage. Ne réponds pas.", 6.0)
	var o := objective("assis", "Reste assis sous les gaz", {"type": "survive", "timer": 25.0})
	await complete(o)
	clear_objectives()
	set_tension(0.2)
	add_stat("opinion", 4.0, "blocage pacifique dispersé de force")
	add_stat("repression", 0.08, "blocage dispersé de force")


func _affrontement() -> void:
	await dialogue(D, "affrontement")
	cine_end()
	despawn("commissaire")
	set_tension(0.85)
	add_stat("opinion", -8.0, "affrontement sur le boulevard")
	add_stat("repression", 0.15, "affrontement sur le boulevard")
	add_stat("notoriete", 0.15, "Sam mène l'affrontement")
	if stat("notoriete") >= 0.4:
		set_flag("sam_fiche", true)
	Campaign.log_action("casse", "Affrontement sur le boulevard des Ormes à la fin du blocage", -8.0)
	hint("Tu as choisi l'affrontement. Recule si tu veux éviter la garde à vue.", 6.0)
	var o := objective("chaos", "Sors du boulevard", {"type": "survive", "timer": 25.0})
	await complete(o)
	clear_objectives()
	set_tension(0.3)


func _epilogue() -> void:
	bank_casse(5 if flag("ch5_issue", "") == "affrontement" else 0)
	var ending := Story.ending_for_state()
	set_flag("fin_suggeree", ending)
	await fade_out(1.0)
	music("fin")
	ambience("cafe")
	_spawn_friends(near("bar_qg", 0.0, -1.5))
	spawn("jo", near("bar_qg", 0.8, -0.6), "player")
	cine_begin()
	await title_card("", "Le soir", 2.0)
	await fade_in(1.0)
	await frame("player", "jo")
	await dialogue(D, "jt")
	await shot({"from": cam("bar_qg", 3.0, 2.0, 180.0), "to": cam("bar_qg", 40.0, 25.0, 200.0), "look": "bar_qg",
		"dur": 8.0, "fov": 45.0, "fov_to": 60.0, "ease": "inout"})
	await fade_out(2.0)
	await title_card("BLOCUS", "", 3.0)
	cine_end()
