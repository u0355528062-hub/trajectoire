extends ChapterBase
## Chapitre 2 « Les prix, en vrai » (samedi après-midi, bruine) : avec Lou, filmer les étiquettes de la supérette
## et le totem de la station, la police appelée par le gérant, le témoignage de Mme Ferreira, le montage et le
## floutage. Histoire : BIBLE.md § 4.2.

const D := DlgPrix.DLG


func run() -> void:
	music("espoir")
	ambience("cafe")
	await open_chapter("Chapitre 2 — Les prix, en vrai", "Samedi 13 mars — 15 h 00")
	spawn("jo", near("bar_qg", 0.8, -1.2), "player")
	spawn("lou", near("bar_qg", -1.0, -2.0), "player")
	await fade_in(1.0)
	await shot({"from": cam("bar_qg", 12.0, 3.5, 200.0), "to": cam("bar_qg", 6.0, 2.2, 185.0), "look": "lou",
		"dur": 4.0, "fov": 48.0, "ease": "inout"})
	await frame("player", "lou")
	await dialogue(D, "lou")
	await fade_out(0.4)
	cine_end()
	await fade_in(0.5)
	follow("lou", "player")
	ambience("rue_matin")
	await _superette()
	await _station()
	await _ferreira()
	await _montage()


func _superette() -> void:
	hint("Sors ton téléphone et cadre bien les étiquettes : de près, c'est lisible.", 6.0)
	var o := clip_obj("etiquettes", "Filme les étiquettes de prix de la supérette", "prix", "supermarche", 7.0)
	await complete(o)
	clear_objectives()
	cine_begin()
	await shot({"from": cam("supermarche", 5.0, 1.8, 20.0), "look": "supermarche", "dur": 1.5, "fov": 45.0})
	await frame("player", "lou")
	await dialogue(D, "gerant")
	cine_end()
	patrol()
	var o2 := objective("trottoir", "Filme la vitrine depuis le trottoir", {"type": "survive", "timer": 10.0,
		"waypoint": "supermarche"})
	await complete(o2)
	clear_objectives()
	cine_begin()
	await shot({"from": cam("supermarche", 9.0, 2.5, 340.0), "look": "player", "dur": 2.0, "fov": 45.0})
	await frame("player", "lou", -0.6)
	await dialogue(D, "police")
	if flag("ch2_accroche"):
		Campaign.log_action("controle", "Sam contrôlé devant la supérette (filmé par Lou)", 0.5)
	cine_end()


func _station() -> void:
	var o := objective("station", "Va à la station-service de la rue de la Forge", {"type": "reach",
		"spot": "station_service", "radius": 9.0})
	await complete(o)
	clear_objectives()
	cine_begin()
	await shot({"from": cam("station_service", 14.0, 2.0, 40.0), "to": cam("station_service", 10.0, 3.5, 20.0),
		"look": "station_service", "dur": 3.0, "fov": 45.0})
	await frame("player", "lou")
	await dialogue(D, "station")
	cine_end()
	var o2 := clip_obj("totem", "Filme le totem des prix et les gens à la pompe", "prix", "station_service", 10.0)
	await complete(o2)
	clear_objectives()
	bark("lou", "Celui-là, le monsieur qui s'arrête à vingt euros pile… C'est le plan.")


func _ferreira() -> void:
	spawn("mme_ferreira", near("pharmacie", -0.8, -1.4), near("pharmacie", -0.8, -6.0))
	gesture("mme_ferreira", "warm", 30.0)
	var o := talk_obj("ferreira", "Va voir Mme Ferreira (au-dessus de la pharmacie)", "mme_ferreira")
	await complete(o)
	clear_objectives()
	face("mme_ferreira", "player")
	cine_begin()
	await frame("player", "mme_ferreira", 0.6, 40.0)
	await dialogue(D, "ferreira")
	cine_end()
	if not flag("ch2_ferreira_ok"):
		return
	hint("Filme-la de près, à hauteur de visage. Laisse-la parler.", 6.0)
	var t := tool_obj("temoignage", "Filme le témoignage de Mme Ferreira", {"type": "event", "event": "testimony",
		"count": 1, "filter": {"who": "mme_ferreira"}, "waypoint": pos_of("mme_ferreira")}, "phone_tool", "mme_ferreira", 3.0)
	await complete(t)
	clear_objectives()
	cine_begin()
	await shot({"from": cam("mme_ferreira", 1.6, 1.6, 200.0), "to": cam("mme_ferreira", 1.2, 1.6, 190.0),
		"look": "mme_ferreira", "dur": 1.0, "fov": 35.0, "dof": 1.4})
	await dialogue(D, "temoignage")
	set_flag("temoignage_ferreira", true)
	rel_add("mme_ferreira", 5)
	Campaign.log_action("temoignage", "Mme Ferreira, 74 ans, témoigne : 812 € de pension, le chauffage coupé", 2.0)
	await fade_out(0.4)
	cine_end()
	await fade_in(0.4)


func _montage() -> void:
	var o := objective("zinc", "Retourne au Zinc avec Lou pour le montage", {"type": "reach", "spot": "bar_qg", "radius": 4.0})
	await complete(o)
	clear_objectives()
	follow("lou", null)
	ambience("cafe")
	await fade_out(0.5)
	spawn("lou", near("bar_qg", -1.0, -2.0), "player")
	cine_begin()
	await fade_in(0.8)
	await title_card("", "Deux heures plus tard", 2.0)
	await frame("player", "lou")
	await dialogue(D, "montage")
	set_flag("ch2_publiee", true)
	add_stat("mobilisation", 6.0 + (5.0 if flag("temoignage_ferreira") else 0.0), "vidéo « Les prix, en vrai »")
	add_stat("opinion", 2.0 + (2.0 if flag("temoignage_ferreira") else 0.0), "vidéo « Les prix, en vrai »")
	Campaign.count("videos")
	Campaign.log_action("video", "Lou publie « Les prix, en vrai »", 3.0)
	await frame("jo", "lou", 0.6)
	await dialogue(D, "publie")
	if flag("ch2_video", "") == "nette":
		news("« Les prix, en vrai » : la vidéo d'une retraitée parisienne dépasse 400 000 vues.")
	else:
		news("« Les prix, en vrai » : une vidéo sur la vie chère partagée 30 000 fois dans la soirée.")
	music("theme")
	await shot({"from": cam("bar_qg", 4.0, 2.0, 190.0), "to": cam("bar_qg", 18.0, 10.0, 200.0), "look": "bar_qg",
		"dur": 5.0, "fov": 45.0, "fov_to": 55.0})
	await fade_out(1.2)
	cine_end()
