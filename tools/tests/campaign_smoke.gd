extends SceneTree
## Campagne en pilote automatique : enchaîne tous les chapitres de Story.CHAPTERS (dialogues, choix, cinématiques
## et objectifs se déroulent seuls), avec rechargement de la scène entre les chapitres, jusqu'à une fin.
## Arguments optionnels : -- <politique de choix : first | last | random:<graine>> <chapitre de départ>
## Échec : erreur de script, chapitre raté, ou pas de fin au bout du temps imparti.
var frame := 0
var last_ch := -1
var seen: Array = []
var limit_s := 600.0
var t := 0.0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	Campaign.autoplay = true
	Campaign.autoplay_policy = a[0] if a.size() > 0 else "first"
	Campaign.new_game()
	if a.size() > 1:
		Campaign.chapter = clampi(int(a[1]), 0, Story.CHAPTERS.size() - 1)
		Campaign.begin_chapter()
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	print("campagne : %d chapitres, choix « %s »" % [Story.CHAPTERS.size(), Campaign.autoplay_policy])


func _process(delta: float) -> bool:
	frame += 1
	t += delta
	if Campaign.chapter != last_ch and Campaign.active:
		last_ch = Campaign.chapter
		seen.append(str(Campaign.chapter_def().get("id", "?")))
		print("[%5.1fs] chapitre %d : %s" % [t, Campaign.chapter, seen[-1]])
	var fails := Campaign.journal.filter(func(e): return str(e.get("kind", "")) == "echec")
	if not fails.is_empty():
		print("ÉCHEC : chapitre raté en pilote automatique : ", fails[0])
		quit(1)
		return true
	if not Campaign.active and Campaign.ending != "":
		print("fin atteinte : « %s » ; opinion %.1f, mobilisation %.0f ; chapitres vus : %s" % [Campaign.ending, Campaign.stat("opinion"), Campaign.stat("mobilisation"), str(seen)])
		print("RÉSULTAT : OK" if seen.size() == Story.CHAPTERS.size() else "ÉCHEC : chapitres manquants")
		quit()
		return true
	if t > limit_s:
		print("ÉCHEC : pas de fin au bout de %d s (chapitre %d)" % [int(limit_s), Campaign.chapter])
		quit(1)
		return true
	return false
