extends SceneTree
## Opinion & actualités : barème de l'OpinionModel (terrain plafonné, vidéos dédoublonnées par `clip` et comptées
## à la publication seulement, floutage, casse, violence contre des personnes, violences policières, non-violence
## tenue, plafond du chapitre, journal), jauge d'opinion (notifications), NewsFeed (notifications, bilan JT, échec,
## fin, en pilote automatique et en interactif) et NewsFeed.pick_ending() (Story.ending_for_state, fin cachée).
## Directeur de chapitre minimal (sans carte).

var d: ChapterDirector
var model: OpinionModel
var news: NewsFeed
var fails: Array = []
var limit := 0


func _initialize() -> void:
	Campaign.reset()
	Campaign.active = true
	Campaign.autoplay = false
	Campaign.chapter = Story.index_of("cortege")
	Campaign.begin_chapter()
	d = ChapterDirector.new()
	d.def = Campaign.chapter_def()
	root.add_child(d)
	news = NewsFeed.new()
	d.add_child(news)
	news.bind(d)
	d.news = news
	model = _new_model()
	_run()


func _new_model() -> OpinionModel:
	var m := OpinionModel.new()
	d.add_child(m)
	m.bind(d)
	d.opinion = m
	return m


func _process(_d: float) -> bool:
	limit += 1
	if limit > 30 * 180:
		print("ÉCHEC : délai du test dépassé")
		quit(1)
		return true
	return false


func check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)
		print("ÉCHEC : ", what)
	else:
		print("  ok  ", what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func op() -> float:
	return Campaign.stat("opinion")


func _run() -> void:
	await frames(2)
	# --- formats
	check(NewsTexts.signed(0.44, 1) == "+0,4" and NewsTexts.signed(-2.0, 0) == "−2", "nombres signés à la française")
	check(NewsTexts.big_number(12400) == "12 400" and NewsTexts.big_number(1200000) == "1,2 million", "grands nombres")
	var p := NewsTexts.poll(37.0)
	check(int(p[0]) + int(p[1]) + int(p[2]) == 100 and int(p[0]) == 37, "sondage : 100 % au total")
	# --- terrain : tracts plafonnés, compteur exact
	var o0 := op()
	for i in 100:
		d.on_event("tract_given", {"pos": Vector3.ZERO, "by": "player"})
	check(Campaign.counter("tracts") == 100, "100 tracts comptés")
	check(op() - o0 > 1.0 and op() - o0 <= float(OpinionModel.SOURCE_CAP["tracts"]) + 0.001, "tracts : opinion + plafonnée (%.2f)" % (op() - o0))
	d.on_event("tract_refused", {"pos": Vector3.ZERO, "by": "player"})
	check(Campaign.counter("tracts_refuses") == 1, "tract refusé compté")
	# --- jauge d'opinion : notification
	await frames(2)
	check(model.hud != null and model.hud.chip_count() >= 1, "jauge d'opinion : notification +")
	# --- vidéos : enregistrement puis publication (même clip), doublon ignoré
	var o1 := op()
	var n1 := Campaign.stat("notoriete")
	d.on_event("film_clip", {"clip": 0, "sec": 14.0, "subjects": ["police_lbd", "crowd"], "score": 12.0, "published": false, "blur": false})
	check(absf(op() - o1) < 0.0001 and Campaign.counter("rushes") == 1, "vidéo enregistrée : rien tant qu'elle n'est pas publiée")
	d.on_event("film_clip", {"clip": 0, "sec": 14.0, "subjects": ["police_lbd", "crowd"], "score": 12.0, "published": true, "blur": false})
	var gain_pub := op() - o1
	check(gain_pub > 1.5, "violence policière filmée et publiée : opinion + (%.2f)" % gain_pub)
	check(Campaign.counter("videos") == 1 and Campaign.counter("rushes") == 1, "publication comptée une fois, sans nouveau rush")
	var noto_net := Campaign.stat("notoriete") - n1
	var o2 := op()
	d.on_event("film_clip", {"clip": 0, "sec": 14.0, "subjects": ["police_lbd", "crowd"], "score": 12.0, "published": true, "blur": false})
	check(absf(op() - o2) < 0.0001 and Campaign.counter("videos") == 1, "publication en double ignorée (clip identique)")
	var n2 := Campaign.stat("notoriete")
	d.on_event("film_clip", {"clip": 1, "sec": 10.0, "subjects": ["police_lbd"], "score": 12.0, "published": false, "blur": true})
	d.on_event("film_clip", {"clip": 1, "sec": 10.0, "subjects": ["police_lbd"], "score": 12.0, "published": true, "blur": true})
	check(Campaign.stat("notoriete") - n2 < noto_net * 0.5, "floutage : moins de notoriété")
	check(Campaign.journal_of().any(func(e): return str(e["kind"]) == "video"), "vidéo publiée au journal")
	check(news.history.any(func(h): return str(h["kind"]) == "phone"), "notification de téléphone (vues)")
	# --- casse : opinion −, radicaux +, journal, compteur des vitres
	var o3 := op()
	var m3 := Campaign.stat("mobilisation")
	var r3 := Campaign.stat("repression")
	d.on_event("glass_break", {"pos": Vector3(5, 1, 5), "kind": "shop"})
	check(op() < o3 and Campaign.stat("mobilisation") > m3 and Campaign.stat("repression") > r3, "vitrine brisée : opinion −, radicaux +, répression +")
	check(Campaign.counter("vitres") == 1, "vitres comptées (casse_total)")
	check(Campaign.journal_of().any(func(e): return str(e["text"]) == "Première vitrine brisée"), "première vitrine au journal")
	# --- violence contre des personnes : jamais récompensée
	var o4 := op()
	var m4 := Campaign.stat("mobilisation")
	d.on_event("civil_hit", {"pos": Vector3(5, 1, 5), "kind": "punch"})
	check(op() < o4 and absf(Campaign.stat("mobilisation") - m4) < 0.0001, "passant frappé : opinion −, aucune mobilisation")
	# --- après de la casse, la police qui recule ne rapporte rien ; cortège calme : si
	var o5 := op()
	d.on_event("police_charge", {"pos": Vector3.ZERO})
	d.on_event("police_retreat", {})
	check(absf(op() - o5) < 0.0001, "pas de prime de non-violence juste après de la casse")
	model.queue_free()
	await frames(1)
	model = _new_model()
	var o6 := op()
	d.on_event("police_charge", {"pos": Vector3.ZERO})
	d.on_event("police_retreat", {})
	check(op() - o6 >= 0.99, "la police recule devant un cortège pacifique : opinion +")
	# non-violence tenue dans la durée (foule présente)
	var cr := Crowd.new()
	for i in 6:
		cr.npcs.append(Npc.new())
	d.crowd = cr
	var o7 := op()
	d.on_event("police_stage", {"stage": 3, "pos": Vector3.ZERO})
	for i in 4:
		model._process(16.0)
	check(op() - o7 >= 1.5 and model.tenue_t >= 60.0, "non-violence tenue face à la police : opinion + (%.2f)" % (op() - o7))
	check(Campaign.journal_of().any(func(e): return str(e["kind"]) == "non_violence"), "non-violence au journal")
	d.on_event("glass_break", {"pos": Vector3.ZERO})
	var t_before := model.tenue_t
	model._process(16.0)
	check(model.tenue_t == t_before, "la casse interrompt la non-violence")
	d.crowd = null
	for n in cr.npcs:
		n.free()
	cr.free()
	# --- plafond du chapitre (cortège)
	var cap := float(OpinionModel.CHAPTER_CAP["cortege"].x)
	for i in 40:
		model.gain("videos", 1.0, "test")
	check(model.up <= cap + 0.001, "plafond du chapitre respecté (%.1f ≤ %.1f)" % [model.up, cap])
	# --- fin de chapitre : terrain au journal
	d.chapter_finished.emit("ok")
	check(Campaign.journal_of().any(func(e): return str(e["kind"]) == "terrain" and str(e["text"]).begins_with("100 tracts")), "terrain du chapitre au journal")
	# --- actualités pendant le jeu
	news.push("Tir de LBD sur un lycéen : les images font le tour du pays.")
	news.push_social("Lou", "La vidéo dépasse 400 000 vues.")
	await frames(3)
	check(news.ticker.shown_count() >= 2, "bandeau d'actualité et notification affichés")
	# --- bilan : données
	var bd := news.bilan_data("ok")
	check(str(bd["headline"]) != "" and (bd["lines"] as Array).size() >= 2 and (bd["highlights"] as Array).size() >= 1, "bilan : titre, présentatrice, faits")
	check((bd["posts"] as Array).size() == 2 and str(bd["next"]).begins_with("Prochain"), "bilan : réseaux sociaux, chapitre suivant")
	check(float(bd["opinion_start"]) == 18.0, "bilan : opinion au début du chapitre")
	# --- écrans interactifs (réponse simulée)
	_answer_later(0)
	await news.show_bilan("ok")
	check(news.screen == null, "bilan JT affiché puis fermé")
	_answer_later(1)
	var retry: bool = await news.show_failure("arrested")
	check(not retry, "échec : « Menu principal » → false")
	_answer_later(0)
	retry = await news.show_failure("timer")
	check(retry, "échec : « Recommencer le chapitre » → true")
	_answer_later(0)
	await news.show_ending("recul")
	check(news.screen == null, "écran de fin affiché puis fermé")
	# --- pilote automatique : validés seuls
	Campaign.autoplay = true
	await news.show_bilan("ok")
	retry = await news.show_failure("arrested")
	check(retry, "pilote automatique : échec → recommencer")
	await news.show_ending("greve")
	Campaign.autoplay = false
	# --- choix de la fin
	Campaign.flags.erase("fin_suggeree")
	Campaign.stats["opinion"] = 62.0
	Campaign.set_flag("docu_lou", true)
	Campaign.set_flag("temoignage_ferreira", true)
	Campaign.set_flag("casse_total", 2)
	check(NewsFeed.pick_ending() == "greve" and Story.ending_for_state() == "greve", "fin cachée « grève » atteignable")
	Campaign.set_flag("docu_lou", false)
	check(NewsFeed.pick_ending() == Story.ending_for_state() and NewsFeed.pick_ending() == "recul", "pick_ending() = Story.ending_for_state()")
	Campaign.stats["opinion"] = 20.0
	check(NewsFeed.pick_ending() == "essoufflement", "opinion basse : essoufflement")
	Campaign.set_flag("fin_suggeree", "amere")
	check(NewsFeed.pick_ending() == "amere", "fin annoncée par l'épilogue conservée")
	for id in ["greve", "recul", "amere", "essoufflement"]:
		var e := NewsTexts.ending(id)
		check((e["lines"] as Array).size() == 3 and (e["fates"] as Array).size() >= 4, "textes de la fin « %s »" % id)
	Campaign.active = false
	print("RÉSULTAT : OK" if fails.is_empty() else "RÉSULTAT : ÉCHEC (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


## Clique sur le bouton `i` de l'écran ouvert, une fois les apparitions passées
func _answer_later(i: int) -> void:
	await frames(25)
	if news.screen == null:
		print("ÉCHEC : écran absent")
		fails.append("écran absent")
		return
	var btns: Array = []
	for n in news.screen.find_children("*", "Button", true, false):
		btns.append(n)
	if i >= btns.size():
		print("ÉCHEC : bouton %d absent" % i)
		fails.append("bouton absent")
		return
	(btns[i] as Button).pressed.emit()
