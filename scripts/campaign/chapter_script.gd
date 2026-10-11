class_name ChapterScript
extends RefCounted
## Base des scripts de chapitre (scripts/story/ch_*.gd) : l'API d'écriture de l'histoire. Un chapitre surcharge
## `run()` et l'écrit comme un scénario linéaire, avec `await` devant chaque étape qui prend du temps :
##
##   func run() -> void:
##       await title_card("JOUR 1", "Jeudi 9 mars — 18 h 40")
##       var nadia := spawn("nadia", "square")
##       await dialogue(Dlg.DLG, "accueil")
##       var o := objective("tracts", "Distribue des tracts aux passants", {"type": "event", "event": "tract_given", "count": 8})
##       await complete(o)
##
## Si la scène disparaît (chapitre fini, échec, retour au menu), toute attente en cours ne reprend jamais :
## le script s'arrête net, sans erreur. Hors attente, ne garder aucune référence à des nœuds d'une scène à l'autre.
## Mode test (Campaign.autoplay) : attentes ÷10, dialogues/choix/cinématiques/objectifs se déroulent seuls.
## Contrat détaillé : docs/CAMPAGNE.md § « API des chapitres ».

signal _never                     # jamais émis : sert à suspendre définitivement un script dont la scène a disparu

var director: ChapterDirector
var main: Node3D
var player: Player
var crowd: Crowd
var police: Police
var tension: Tension


func setup(d: ChapterDirector) -> void:
	director = d
	main = d.main
	player = d.player
	crowd = d.crowd
	police = d.police
	tension = d.tension


## À surcharger : le scénario du chapitre (coroutine). Quand il se termine, le chapitre est réussi.
func run() -> void:
	pass


## Le chapitre est-il toujours en cours (scène vivante, pas encore fini) ?
func alive() -> bool:
	return is_instance_valid(director) and not director.finished


# ================================================================== temps
func wait(sec: float) -> void:
	if not alive():
		await _never
		return
	await director.sleep(sec * (0.1 if Campaign.autoplay else 1.0))


## Attend que `cond.call()` soit vrai (vérifié 10 fois par seconde). Renvoie false si `timeout` (s) expire.
func until(cond: Callable, timeout := -1.0) -> bool:
	var t := 0.0
	while true:
		if not alive():
			await _never
			return false
		if cond.call():
			return true
		if timeout >= 0.0 and t >= timeout:
			return false
		await director.sleep(0.1)
		t += 0.1
	return false


## Attend le prochain événement de la foule de ce type (voir docs/CAMPAGNE.md § « Événements ») ;
## renvoie ses données, ou {} si `timeout` expire.
func wait_event(type: String, timeout := -1.0) -> Dictionary:
	var box := {"d": null}
	var cb := func(t: String, d: Dictionary) -> void:
		if t == type and box["d"] == null:
			box["d"] = d
	if not alive():
		await _never
		return {}
	director.event.connect(cb)
	var ok := await until(func() -> bool: return box["d"] != null, timeout)
	if is_instance_valid(director) and director.event.is_connected(cb):
		director.event.disconnect(cb)
	return box["d"] if ok else {}


# ================================================================== lieux
func spot(id: String) -> Vector3:
	return Quartier.spot(id)


## Position d'une cible : id de lieu, id de personnage d'histoire, "player", Vector3 ou Node3D
func pos_of(target: Variant) -> Vector3:
	if target is Vector3:
		return target
	if target is Node3D and is_instance_valid(target):
		return (target as Node3D).global_position
	if target is String:
		if target == "player" and is_instance_valid(player):
			return player.global_position
		if Quartier.SPOTS.has(target):
			return Quartier.spot(target)
		var a := actor(target)
		if a:
			return a.global_position
	push_error("ChapterScript.pos_of : cible inconnue %s" % str(target))
	return Vector3.ZERO


# ================================================================== personnages (StoryCast / StoryActor)
## Personnage d'histoire déjà présent (null sinon)
func actor(id: String) -> StoryActor:
	if not alive():
		return null
	return director.cast.get_actor(id)


## Fait apparaître un personnage d'histoire (look : CastLooks) à un lieu / une position, tourné vers `facing`
func spawn(id: String, at: Variant, facing: Variant = null) -> StoryActor:
	if not alive():
		return null
	var a := director.cast.spawn(id, pos_of(at))
	if a and facing != null:
		a.face_target(pos_of(facing))
	return a


func despawn(id: String) -> void:
	if alive():
		director.cast.despawn(id)


## Fait marcher (ou courir) un personnage jusqu'à une cible ; renvoie false s'il n'y est pas arrivé à temps
func walk_to(who: Variant, to: Variant, run := false, timeout := 40.0) -> bool:
	if not alive():
		await _never
		return false
	var a := _who(who)
	if a == null:
		return false
	return await director.cast.walk_to(a, pos_of(to), run, timeout)


func face(who: Variant, target: Variant) -> void:
	var a := _who(who)
	if a:
		a.face_target(pos_of(target))


## Geste joué par un personnage (noms : docs/CAMPAGNE.md § « Gestes »)
func gesture(who: Variant, name: String, sec := 2.0) -> void:
	var a := _who(who)
	if a:
		a.gesture(name, sec)


## Le personnage suit une cible (null : il s'arrête)
func follow(who: Variant, target: Variant) -> void:
	var a := _who(who)
	if a:
		a.follow_target(target if target is Node3D else (player if str(target) == "player" else null))


func _who(who: Variant) -> StoryActor:
	if who is StoryActor:
		return who if is_instance_valid(who) else null
	return actor(str(who))


# ================================================================== dialogues (DialogueUI)
## Une réplique sous-titrée (bloquante jusqu'à la fin de la réplique). opts : {"anim": geste, "look": cible, "wait": s}
func say(who: String, text: String, opts := {}) -> void:
	if not alive():
		await _never
		return
	await director.dialogue.play_line(who, text, opts)


## Réplique courte non bloquante (dans le monde, sous-titre discret)
func bark(who: String, text: String) -> void:
	if alive():
		director.dialogue.bark(who, text)


## Joue un arbre de dialogue (format : docs/CAMPAGNE.md § « Format des dialogues ») à partir du nœud `node`.
## Renvoie l'"id" du dernier choix fait ("" si aucun).
func dialogue(dlg: Dictionary, node := "start") -> String:
	if not alive():
		await _never
		return ""
	return await director.dialogue.run(dlg, node)


## Choix simple hors dialogue ; renvoie l'index choisi. timer > 0 : choix par défaut (0) à l'expiration.
func choose(prompt: String, options: Array, timer := 0.0) -> int:
	if not alive():
		await _never
		return 0
	return await director.dialogue.choose(prompt, options, timer)


# ================================================================== cinématiques (Cinematics)
func cine_begin() -> void:
	if alive():
		director.cine.begin()


func cine_end() -> void:
	if alive():
		director.cine.end()


## Plan de caméra (spec : docs/CAMPAGNE.md § « Plans »)
func shot(spec: Dictionary) -> void:
	if not alive():
		await _never
		return
	await director.cine.shot(spec)


func fade_out(sec := 0.6) -> void:
	if not alive():
		await _never
		return
	await director.cine.fade_out(sec)


func fade_in(sec := 0.6) -> void:
	if not alive():
		await _never
		return
	await director.cine.fade_in(sec)


## Carton de titre plein écran (« JOUR 1 », « Jeudi 9 mars — 18 h 40 »)
func title_card(title: String, subtitle := "", sec := 3.5) -> void:
	if not alive():
		await _never
		return
	await director.cine.title_card(title, subtitle, sec)


# ================================================================== objectifs (ObjectiveTracker)
## Nouvel objectif affiché au joueur (spec : docs/CAMPAGNE.md § « Objectifs »)
func objective(id: String, text: String, spec := {}) -> Objective:
	if not alive():
		return null
	return director.objectives.add(id, text, spec)


## Attend qu'un objectif soit atteint (true) ou raté (false)
func complete(o: Objective) -> bool:
	if not alive() or o == null:
		await _never
		return false
	return await director.objectives.wait_for(o)


## Attend que tous soient atteints ; false dès que l'un d'eux est raté
func objectives_all(list: Array) -> bool:
	for o in list:
		if not await complete(o):
			return false
	return true


## Attend le premier objectif terminé (atteint ou raté) de la liste et le renvoie
func objective_any(list: Array) -> Objective:
	if not alive():
		await _never
		return null
	return await director.objectives.wait_any(list)


func clear_objectives() -> void:
	if alive():
		director.objectives.clear()


# ================================================================== campagne
func stat(k: String) -> float:
	return Campaign.stat(k)


func add_stat(k: String, d: float, why := "") -> void:
	Campaign.add_stat(k, d, why)


func flag(k: String, def: Variant = false) -> Variant:
	return Campaign.flag(k, def)


func set_flag(k: String, v: Variant = true) -> void:
	Campaign.set_flag(k, v)


func rel(who: String) -> int:
	return Campaign.rel_get(who)


func rel_add(who: String, d: int) -> void:
	Campaign.rel_add(who, d)


## Notification d'actualité (bandeau / téléphone)
func news(text: String) -> void:
	if alive():
		director.news.push(text)


## Aide contextuelle à l'écran
func hint(text: String, sec := 5.0) -> void:
	if alive():
		director.objectives.hint(text, sec)


func music(id: String) -> void:
	if alive():
		director.audio.music(id)


func ambience(id: String) -> void:
	if alive():
		director.audio.ambience(id)


# ================================================================== monde
func set_tension(v: float) -> void:
	if alive() and director.tension:
		director.tension.set_value(v)


func freeze_tension(on: bool) -> void:
	if alive() and director.tension:
		director.tension.frozen = on


func end_chapter(outcome := "ok") -> void:
	if alive():
		director.end_chapter(outcome)


func fail_chapter(reason: String) -> void:
	if alive():
		director.fail_chapter(reason)
