class_name ChapterDirector
extends Node
## Met en scène un chapitre de la campagne. Créé par main.gd quand Campaign.active : construit les services
## (dialogues, cinématiques, personnages d'histoire, objectifs, opinion, actualités, son), lance le script du
## chapitre (Story.CHAPTERS[i]["script"], qui hérite de ChapterScript), puis enchaîne bilan → chapitre suivant
## (rechargement de la scène) ou fin de campagne. Une interpellation du joueur fait échouer le chapitre.
## Règle d'or : toute attente de l'histoire passe par un nœud du directeur (sleep, signaux des services) ;
## si la scène est rechargée ou quittée, le directeur disparaît et le script du chapitre s'arrête net.

signal event(type: String, d: Dictionary)       # relais des événements de la foule (on_event du groupe « crowd »)
signal chapter_finished(outcome: String)

var main: Node3D
var player: Player
var crowd: Crowd
var police: Police
var tension: Tension
var dialogue: DialogueUI
var cine: Cinematics
var cast: StoryCast
var objectives: ObjectiveTracker
var opinion: OpinionModel
var news: NewsFeed
var audio: StoryAudio
var script_obj: ChapterScript
var def: Dictionary = {}
var finished := false
var failures := 0                 # échecs de chapitre (statistique pour les tests)


func bind(m: Node3D) -> void:
	main = m
	player = m.get("player")
	for c in m.get_children():
		if c is Crowd:
			crowd = c
		elif c is Police:
			police = c
		elif c is Tension:
			tension = c
	def = Campaign.chapter_def()
	add_to_group("crowd")          # reçoit on_event comme la foule
	add_to_group("campaign")
	add_to_group("chapter_director")
	cast = StoryCast.new()
	cast.name = "StoryCast"
	add_child(cast)
	cast.bind(self)
	cine = Cinematics.new()
	cine.name = "Cinematics"
	add_child(cine)
	cine.bind(self)
	objectives = ObjectiveTracker.new()
	objectives.name = "Objectives"
	add_child(objectives)
	objectives.bind(self)
	opinion = OpinionModel.new()
	opinion.name = "Opinion"
	add_child(opinion)
	opinion.bind(self)
	news = NewsFeed.new()
	news.name = "News"
	add_child(news)
	news.bind(self)
	dialogue = DialogueUI.new()
	dialogue.name = "Dialogue"
	add_child(dialogue)
	dialogue.bind(self)
	audio = StoryAudio.new()
	audio.name = "StoryAudio"
	add_child(audio)
	audio.bind(self)
	if player:
		player.arrested.connect(_on_player_arrested)
	_start.call_deferred()


func _start() -> void:
	await sleep(0.05)
	var path := str(def.get("script", ""))
	if path == "" or not ResourceLoader.exists(path):
		push_error("ChapterDirector : script de chapitre introuvable « %s »" % path)
		return
	var scr: Script = load(path)
	script_obj = scr.new() as ChapterScript
	if script_obj == null:
		push_error("ChapterDirector : %s n'hérite pas de ChapterScript" % path)
		return
	script_obj.setup(self)
	await script_obj.run()
	if not finished:
		end_chapter("ok")


## Relais des événements de la foule vers les services et le script (wait_event)
func on_event(type: String, d: Dictionary) -> void:
	event.emit(type, d)


## Attente « possédée » par le directeur : ne reprend jamais si la scène disparaît entre-temps
func sleep(sec: float) -> void:
	var t := Timer.new()
	t.one_shot = true
	add_child(t)
	t.start(maxf(sec, 0.001))
	await t.timeout
	t.queue_free()


## Fin réussie du chapitre : bilan, puis chapitre suivant ou fin de la campagne
func end_chapter(outcome := "ok") -> void:
	if finished:
		return
	finished = true
	chapter_finished.emit(outcome)
	Campaign.log_action("chapitre", "%s : %s" % [str(def.get("id", "?")), outcome])
	await news.show_bilan(outcome)
	if Campaign.is_last_chapter():
		Campaign.ending = NewsFeed.pick_ending()
		Campaign.save()
		await news.show_ending(Campaign.ending)
		Campaign.active = false
		_reload(true)
	else:
		Campaign.next_chapter()
		_reload(false)


## Échec du chapitre (interpellé, objectif raté…) : écran d'échec, puis recommencer le chapitre ou menu
func fail_chapter(reason: String) -> void:
	if finished:
		return
	finished = true
	failures += 1
	Campaign.log_action("echec", reason)
	var retry: bool = await news.show_failure(reason)
	if retry:
		Campaign.restart_chapter()
		_reload(false)
	else:
		Campaign.active = false
		_reload(true)


func _on_player_arrested() -> void:
	Campaign.add_stat("notoriete", 0.15, "interpellation du joueur")
	fail_chapter("arrested")


func _reload(to_title: bool) -> void:
	if to_title:
		TitleScreen.force_show = true
	var tree := get_tree()
	tree.paused = false
	tree.reload_current_scene.call_deferred()
