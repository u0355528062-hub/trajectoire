class_name Campaign
extends RefCounted
## État de la campagne « La Hausse » (histoire en chapitres) : chapitre courant, jauges (opinion, mobilisation,
## répression, notoriété), relations avec les personnages, drapeaux posés par les choix, compteurs du chapitre et
## journal des actions marquantes (repris par le JT et le bilan). Tout est statique : l'état survit au rechargement
## de la scène entre deux chapitres. Sauvegarde : user://campagne.json.
## Hors campagne (`active == false`), le jeu est le bac à sable d'origine (voir WorldSetup).
## Contrat complet : docs/CAMPAGNE.md.

const PATH := "user://campagne.json"
const VERSION := 1
## Jauges de départ. opinion : % de la population qui soutient le mouvement ; mobilisation : nombre de gens prêts
## à descendre dans la rue (donne la taille de la foule des chapitres suivants) ; repression : dureté de la réponse
## de l'État (0..1) ; notoriete : à quel point la police connaît le joueur (0..1).
const STAT_DEFAULTS := {"opinion": 18.0, "mobilisation": 12.0, "repression": 0.15, "notoriete": 0.0}
const STAT_RANGE := {"opinion": Vector2(0.0, 100.0), "mobilisation": Vector2(0.0, 400.0), "repression": Vector2(0.0, 1.0), "notoriete": Vector2(0.0, 1.0)}
## Personnages dont on suit la relation (-100..100)
const CAST := ["nadia", "karim", "ines", "lou", "jo", "mme_ferreira"]

static var active := false               # une campagne est en cours
static var autoplay := false             # tests : dialogues, choix, cinématiques et objectifs se déroulent seuls
static var autoplay_policy := "first"    # choix automatiques : "first", "last" ou "random:<graine>"
static var chapter := 0                  # index dans Story.CHAPTERS
static var stats: Dictionary = STAT_DEFAULTS.duplicate()
static var rel: Dictionary = {}
static var flags: Dictionary = {}
static var journal: Array = []           # [{ch, kind, text, d}] actions marquantes
static var counters: Dictionary = {}     # compteurs du chapitre en cours (tracts, affiches, vitres, vidéos…)
static var ending := ""                  # fin atteinte ("" tant que la campagne continue)
static var _snapshot: Dictionary = {}    # état au début du chapitre (« Recommencer le chapitre »)
static var _rng := RandomNumberGenerator.new()
static var _rng_for := ""


## Nouvelle partie : tout à zéro, chapitre 0
static func new_game() -> void:
	reset()
	active = true
	begin_chapter()


static func reset() -> void:
	chapter = 0
	stats = STAT_DEFAULTS.duplicate()
	rel = {}
	for c in CAST:
		rel[c] = 0
	flags = {}
	journal = []
	counters = {}
	ending = ""
	_snapshot = {}


static func chapter_def() -> Dictionary:
	if Story.CHAPTERS.is_empty():
		return {}
	return Story.CHAPTERS[clampi(chapter, 0, Story.CHAPTERS.size() - 1)]


static func is_last_chapter() -> bool:
	return chapter >= Story.CHAPTERS.size() - 1


# ------------------------------------------------------------------ jauges
static func stat(k: String) -> float:
	return float(stats.get(k, 0.0))


static func add_stat(k: String, delta: float, why := "") -> void:
	set_stat(k, stat(k) + delta, why, delta)


static func set_stat(k: String, v: float, why := "", delta := 0.0) -> void:
	var r: Vector2 = STAT_RANGE.get(k, Vector2(-1e9, 1e9))
	var old := stat(k)
	stats[k] = clampf(v, r.x, r.y)
	var d := float(stats[k]) - old
	if absf(d) > 0.0001:
		_notify("on_campaign_stat", [k, float(stats[k]), d if delta == 0.0 else delta, why])


# ------------------------------------------------------------------ drapeaux, relations, compteurs, journal
static func flag(k: String, def: Variant = false) -> Variant:
	return flags.get(k, def)


static func set_flag(k: String, v: Variant = true) -> void:
	flags[k] = v
	_notify("on_campaign_flag", [k, v])


static func rel_get(who: String) -> int:
	return int(rel.get(who, 0))


static func rel_add(who: String, d: int) -> void:
	rel[who] = clampi(rel_get(who) + d, -100, 100)
	_notify("on_campaign_rel", [who, int(rel[who]), d])


static func count(k: String, n := 1) -> int:
	counters[k] = int(counters.get(k, 0)) + n
	return int(counters[k])


static func counter(k: String) -> int:
	return int(counters.get(k, 0))


static func log_action(kind: String, text: String, d := 0.0) -> void:
	journal.append({"ch": chapter, "kind": kind, "text": text, "d": d})
	if journal.size() > 400:
		journal.pop_front()


## Entrées du journal pour un chapitre (-1 : le chapitre en cours)
static func journal_of(ch := -1) -> Array:
	var want := chapter if ch < 0 else ch
	return journal.filter(func(e): return int(e.get("ch", -1)) == want)


# ------------------------------------------------------------------ déroulé
## Début de chapitre : compteurs à zéro, photo de l'état (pour recommencer le chapitre)
static func begin_chapter() -> void:
	counters = {}
	_snapshot = {"stats": stats.duplicate(true), "rel": rel.duplicate(true), "flags": flags.duplicate(true),
		"journal": journal.duplicate(true), "chapter": chapter}


## « Recommencer le chapitre » : on revient à l'état du début du chapitre
static func restart_chapter() -> void:
	if _snapshot.is_empty():
		return
	stats = (_snapshot["stats"] as Dictionary).duplicate(true)
	rel = (_snapshot["rel"] as Dictionary).duplicate(true)
	flags = (_snapshot["flags"] as Dictionary).duplicate(true)
	journal = (_snapshot["journal"] as Array).duplicate(true)
	chapter = int(_snapshot["chapter"])
	counters = {}


## Chapitre suivant ; false s'il n'y en a plus (la campagne est finie)
static func next_chapter() -> bool:
	if is_last_chapter():
		return false
	chapter += 1
	begin_chapter()
	save()
	return true


## Choix automatique (tests) parmi n options
static func auto_pick(n: int) -> int:
	if n <= 0:
		return -1
	if autoplay_policy == "last":
		return n - 1
	if autoplay_policy.begins_with("random"):
		if _rng_for != autoplay_policy:
			_rng_for = autoplay_policy
			var parts := autoplay_policy.split(":")
			_rng.seed = int(parts[1]) if parts.size() > 1 else 1
		return _rng.randi_range(0, n - 1)
	return 0


# ------------------------------------------------------------------ sauvegarde
static func save() -> bool:
	if autoplay:
		return true                   # les tests n'écrasent pas la sauvegarde du joueur
	var data := {"version": VERSION, "chapter": chapter, "stats": stats, "rel": rel, "flags": flags,
		"journal": journal, "snapshot": _snapshot, "ending": ending}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	return true


static func has_save() -> bool:
	return FileAccess.file_exists(PATH)


static func load_save() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return false
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or int((data as Dictionary).get("version", 0)) != VERSION:
		return false
	reset()
	chapter = clampi(int(data.get("chapter", 0)), 0, maxi(Story.CHAPTERS.size() - 1, 0))
	for k in STAT_DEFAULTS:
		stats[k] = float((data.get("stats", {}) as Dictionary).get(k, STAT_DEFAULTS[k]))
	for k in (data.get("rel", {}) as Dictionary):
		rel[k] = int(data["rel"][k])
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	journal = (data.get("journal", []) as Array).duplicate(true)
	ending = str(data.get("ending", ""))
	active = true
	begin_chapter()
	return true


static func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


static func _notify(method: String, args: Array) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var all := [&"campaign", StringName(method)]
	all.append_array(args)
	tree.callv("call_group", all)
