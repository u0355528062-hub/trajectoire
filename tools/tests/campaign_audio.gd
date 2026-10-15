extends SceneTree
## Audio de la campagne (StoryAudio) : chaque id de music()/ambience() des chapitres (scripts/story/ch_*.gd) et de la
## BIBLE se résout en fichiers présents ; fondus enchaînés (anciens lecteurs libérés, niveau cible atteint), ouverture
## puis boucle (JT), écrans du JT (bilan, échec, fin), pluie de Weather (pas de doublon, étouffée en intérieur),
## ville générique (Ambient) coupée puis rendue, pause de l'arbre, ids inconnus, libération en plein fondu et
## seconde instance propre (rechargement). Directeur de chapitre minimal (sans carte).

var fails: Array = []
var limit := 0


func _initialize() -> void:
	Campaign.reset()
	Campaign.active = true
	Campaign.autoplay = true
	Campaign.chapter = 0
	Campaign.begin_chapter()
	_run()


func _process(_d: float) -> bool:
	limit += 1
	if limit > 30 * 240:
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


func seconds(s: float) -> void:
	await create_timer(s, true).timeout


## Ids appelés par les chapitres : music("x") / ambience("x") dans le source
func used_ids(kind: String) -> Array:
	var re := RegEx.new()
	re.compile(kind + "\\(\"([a-z_]*)\"\\)")
	var out: Array = []
	var dir := DirAccess.open("res://scripts/story")
	for f in dir.get_files():
		if not f.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string("res://scripts/story/" + f)
		for m in re.search_all(src):
			var id := m.get_string(1)
			if not out.has(id):
				out.append(id)
	return out


func players(a: StoryAudio) -> Array:
	return a.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer and not n.is_queued_for_deletion())


func make_director() -> Array:
	var main := Node3D.new()
	main.name = "MainTest"
	root.add_child(main)
	var amb := Ambient.new()
	main.add_child(amb)
	var d := ChapterDirector.new()
	d.def = Campaign.chapter_def()
	d.main = main
	main.add_child(d)
	var news := NewsFeed.new()
	d.add_child(news)
	news.bind(d)
	d.news = news
	var a := StoryAudio.new()
	d.add_child(a)
	a.bind(d)
	d.audio = a
	return [main, d, a, amb]


func _run() -> void:
	await frames(2)
	# ---------------------------------------------------------------- résolution des ids
	var mus := used_ids("music")
	var amb := used_ids("ambience")
	check(mus.size() >= 5 and amb.size() >= 5, "ids trouvés dans les chapitres : musiques %s, ambiances %s" % [mus, amb])
	for id in mus:
		check(StoryAudio.has_music(id), "musique « %s » résolue" % id)
	for id in amb:
		check(StoryAudio.has_ambience(id), "ambiance « %s » résolue" % id)
	for id in StoryAudio.MUSIC:
		check(StoryAudio.has_music(id), "musique déclarée « %s » présente" % id)
	for id in StoryAudio.AMBIENCE:
		check(StoryAudio.has_ambience(id), "ambiance déclarée « %s » présente" % id)
	for id in ["theme", "matin", "espoir", "marche", "tension", "nasse", "aube", "fin"]:
		check(StoryAudio.MUSIC.has(id), "musique de la BIBLE « %s »" % id)
	for id in ["rue_matin", "cafe", "square", "supermarche", "cortege", "pluie_nuit", "blocage", "rue_nuit", "pluie", "tv", "foule"]:
		check(StoryAudio.AMBIENCE.has(id), "ambiance attendue « %s »" % id)
	for e in StoryAudio.ENDING_MUSIC:
		check(NewsTexts.ENDINGS.has(e) and StoryAudio.has_music(StoryAudio.ENDING_MUSIC[e]), "musique de la fin « %s »" % e)
	for e in NewsTexts.ENDINGS:
		check(StoryAudio.ENDING_MUSIC.has(e), "fin « %s » a une musique" % e)
	var st := StoryAudio.get_stream("mus_theme")
	check(st is AudioStreamOggVorbis and (st as AudioStreamOggVorbis).loop and st.get_length() > 20.0, "boucle de musique (Ogg, en boucle, > 20 s)")
	check(StoryAudio.get_stream("absent_xyz") == null, "fichier absent -> flux nul, sans erreur")

	# ---------------------------------------------------------------- fondus
	var parts := make_director()
	var d: ChapterDirector = parts[1]
	var a: StoryAudio = parts[2]
	var city: Ambient = parts[3]
	await frames(3)
	var city_db0 := (city.get_child(0) as AudioStreamPlayer).volume_db
	a.music("matin")
	a.ambience("rue_matin")
	await frames(2)
	check(players(a).size() == 2, "musique + ambiance : 2 lecteurs (%d)" % players(a).size())
	for p in players(a):
		check((p as AudioStreamPlayer).bus == &"Ambiance" and (p as AudioStreamPlayer).playing, "lecteur sur le bus Ambiance, en lecture")
	await seconds(3.0)
	var m0: AudioStreamPlayer = null
	for e in a._mix:
		if e["kind"] == "music":
			m0 = e["p"]
	check(m0 != null and absf(m0.volume_db - StoryAudio.MUSIC_DB) < 0.1, "musique arrivée à son niveau après le fondu")
	check((city.get_child(0) as AudioStreamPlayer).volume_db < city_db0 - 40.0, "ville générique coupée sous une ambiance de l'histoire")
	a.music("matin")
	await frames(2)
	check(players(a).size() == 2, "même musique : pas de redémarrage")
	a.music("espoir")
	a.ambience("cafe")
	await frames(2)
	check(players(a).size() == 4, "fondu enchaîné : anciens et nouveaux lecteurs ensemble (%d)" % players(a).size())
	await seconds(3.2)
	check(players(a).size() == 2 and not is_instance_valid(m0), "anciens lecteurs libérés après le fondu (%d)" % players(a).size())
	check(a.music_id == "espoir" and a.ambience_id == "cafe", "ids courants")

	# ---------------------------------------------------------------- pluie de Weather
	var rain := StoryAudio.rain_player(1.0)
	parts[0].add_child(rain)
	await frames(2)
	check(rain.is_in_group("rain_sound") and rain.stream != null and rain.playing, "pluie de Weather : lecteur en boucle")
	var rain_db0 := rain.volume_db
	a.ambience("pluie_nuit")
	await frames(2)
	var files: Array = []
	for e in a._mix:
		if e["kind"] == "amb" and float(e["to"]) > 0.0:
			files.append(e["file"])
	check(files == ["amb_rue_nuit"], "pluie_nuit avec Weather pluvieux : pas de pluie en double (%s)" % [files])
	a.ambience("cafe")
	await seconds(2.2)
	check(rain.volume_db < rain_db0 - 9.0, "pluie étouffée en intérieur (%.1f -> %.1f dB)" % [rain_db0, rain.volume_db])
	a.ambience("rue_nuit")
	await seconds(2.2)
	check(absf(rain.volume_db - rain_db0) < 0.05, "pluie rendue dehors")
	rain.queue_free()
	await frames(2)
	a.ambience("pluie")
	await frames(2)
	check(a._has_kind("amb"), "pluie sans Weather pluvieux : jouée par StoryAudio")

	# ---------------------------------------------------------------- ouverture + boucle, pause
	paused = true
	a.music("jt")
	await seconds(0.6)
	var intro_seen := false
	for e in a._mix:
		if e["kind"] == "music" and is_instance_valid(e["p"]) and not ((e["p"] as AudioStreamPlayer).stream as AudioStreamOggVorbis).loop:
			intro_seen = true
	check(intro_seen, "JT : ouverture jouée (arbre en pause)")
	await seconds(3.2)
	var loop_on := false
	for e in a._mix:
		if e["kind"] == "music" and float(e["to"]) > 0.0 and is_instance_valid(e["p"]) and ((e["p"] as AudioStreamPlayer).stream as AudioStreamOggVorbis).loop:
			loop_on = true
	check(loop_on, "JT : boucle lancée après l'ouverture, pendant la pause")
	paused = false
	a.stop_music(0.5)
	await seconds(1.0)
	check(not a._has_kind("music") and a.music_id == "", "stop_music : musique éteinte")

	# ---------------------------------------------------------------- écrans du JT
	await d.news.show_bilan("ok")
	check(a.music_id == "jt" and a.ambience_id == "ecran", "bilan : musique du JT, ambiance coupée")
	await d.news.show_failure("arrested")
	check(a.music_id == "echec", "échec : musique d'échec")
	Campaign.ending = "recul"
	await d.news.show_ending("recul")
	check(a.music_id == "fin", "fin « recul » : musique de fin")
	await d.news.show_ending("essoufflement")
	check(a.music_id == "fin_sombre", "fin « essoufflement » : musique sombre")
	a.ambience("silence")
	await seconds(2.2)
	check(absf((city.get_child(0) as AudioStreamPlayer).volume_db - city_db0) < 0.05, "silence : ville générique rendue")

	# ---------------------------------------------------------------- ids inconnus, libération en plein fondu
	a.music("inexistante")
	a.ambience("inexistante")
	check(a.music_id == "fin_sombre", "id inconnu ignoré")
	a.music("tension")
	a.ambience("foule")
	await frames(3)
	parts[0].queue_free()
	await frames(5)
	check(not is_instance_valid(a), "scène libérée en plein fondu")
	var parts2 := make_director()
	var a2: StoryAudio = parts2[2]
	await frames(2)
	a2.music("nasse")
	a2.ambience("blocage")
	await seconds(0.5)
	check(players(a2).size() == 2, "seconde instance (rechargement) : lecteurs neufs")
	parts2[0].queue_free()
	await frames(3)

	print("RÉSULTAT : OK" if fails.is_empty() else "RÉSULTAT : ÉCHEC (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
