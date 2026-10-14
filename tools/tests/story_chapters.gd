extends SceneTree
## Vérifie le contenu de la campagne (module Scénario) sans lancer le jeu :
## - Story.CHAPTERS : ids uniques, script de chapitre présent (hérite de ChapterScript), réglages du monde lisibles
##   (heure, météo, lieux, outils) ;
## - chaque scripts/story/dlg_*.gd : "_id" = un chapitre, étapes connues, locuteurs connus, sauts (goto/else) vers des
##   nœuds existants, conditions lisibles, effets sur des jauges/relations existantes, gestes connus, méthodes
##   « call » présentes dans le script du chapitre, nœuds tous atteignables (saut ou appel depuis le chapitre),
##   répliques pas trop longues ;
## - chaque nœud passé à dialogue(…, "nœud") dans un ch_*.gd existe.
## Usage : tools/dev/gd --headless --path . -s tools/tests/story_chapters.gd   →   RÉSULTAT : OK

const DIR := "res://scripts/story/"
const TODS := ["aube", "matin", "midi", "aprem", "crepuscule", "nuit"]
const WEATHERS := ["sec", "bruine", "pluie", "brume"]
const TOOLS := ["phone", "tracts", "posters", "megaphone", "spray", "stones", "igniter", "flare", "petards_small",
	"petards_medium", "mortar"]
const NEW_GESTURES := ["nod", "shake_head", "shrug", "explain", "sigh", "laugh", "hug", "sit"]
const STEP_KEYS := ["who", "text", "anim", "look", "wait", "if", "choice", "prompt", "timer", "goto", "else", "set",
	"stats", "rel", "news", "call", "end"]
const OPT_KEYS := ["id", "text", "say", "if", "set", "stats", "rel", "goto", "news"]
const MAX_LINE := 190

var errors: Array[String] = []
var lines := 0


func _initialize() -> void:
	var chapters := {}
	_check_chapters(chapters)
	var dlgs := 0
	for f in DirAccess.get_files_at(DIR):
		if f.begins_with("dlg_") and f.ends_with(".gd"):
			dlgs += 1
			_check_dlg(DIR + f, chapters)
	for id in chapters:
		if not FileAccess.file_exists(DIR + "dlg_%s.gd" % id):
			_err("chapitre %s : pas de dlg_%s.gd" % [id, id])
	print("story_chapters : %d chapitres, %d fichiers de dialogue, %d répliques" % [chapters.size(), dlgs, lines])
	for e in errors:
		print("  ✗ ", e)
	print("RÉSULTAT : OK" if errors.is_empty() else "ÉCHEC : %d problème(s)" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _err(s: String) -> void:
	errors.append(s)


# ------------------------------------------------------------------ chapitres
func _check_chapters(chapters: Dictionary) -> void:
	if Story.CHAPTERS.is_empty():
		_err("Story.CHAPTERS est vide")
	for c in Story.CHAPTERS:
		var id := str(c.get("id", ""))
		if id == "" or chapters.has(id):
			_err("chapitre sans id ou id en double : « %s »" % id)
			continue
		for k in ["title", "date", "script"]:
			if str(c.get(k, "")) == "":
				_err("chapitre %s : clé « %s » manquante" % [id, k])
		var path := str(c.get("script", ""))
		if not ResourceLoader.exists(path):
			_err("chapitre %s : script introuvable %s" % [id, path])
			continue
		var scr: Script = load(path)
		var inst: Variant = scr.new() if scr and scr.can_instantiate() else null
		if not (inst is ChapterScript):
			_err("chapitre %s : %s n'hérite pas de ChapterScript" % [id, path])
			continue
		chapters[id] = {"script": scr, "inst": inst, "src": FileAccess.get_file_as_string(path)}
		if not TODS.has(str(c.get("tod", "crepuscule"))):
			_err("chapitre %s : heure inconnue %s" % [id, c.get("tod")])
		if not WEATHERS.has(str(c.get("weather", "sec"))):
			_err("chapitre %s : météo inconnue %s" % [id, c.get("weather")])
		for t in c.get("tools", []):
			if not TOOLS.has(str(t)):
				_err("chapitre %s : outil inconnu %s" % [id, t])
		var sp := str(c.get("spawn", ""))
		if sp != "" and not Quartier.SPOTS.has(sp):
			_err("chapitre %s : lieu de départ inconnu %s" % [id, sp])
		var cr: Dictionary = c.get("crowd", {})
		if cr.has("gather") and not Quartier.SPOTS.has(str(cr["gather"])):
			_err("chapitre %s : lieu de rassemblement inconnu %s" % [id, cr["gather"]])
		var sz: Variant = cr.get("size", -1)
		if not (sz is int or str(sz) == "mobilisation"):
			_err("chapitre %s : taille de foule illisible %s" % [id, sz])
		# lieux nommés dans le script ("square", spot("x"), near("x"…)…)
		var re := RegEx.create_from_string("(?:\\b(?:spot|near|cam|wide)\\(|walk_to\\([^,()]+,|\"(?:spot|waypoint)\":)\\s*\"([a-z_]+)\"")
		for m in re.search_all(chapters[id]["src"]):
			var s := m.get_string(1)
			if not Quartier.SPOTS.has(s) and not CastLooks.LOOKS.has(s) and s != "player":
				_err("chapitre %s : lieu ou personnage inconnu « %s »" % [id, s])


# ------------------------------------------------------------------ dialogues
func _check_dlg(path: String, chapters: Dictionary) -> void:
	var scr: Script = load(path)
	if scr == null:
		_err("%s : ne se charge pas" % path)
		return
	var consts := scr.get_script_constant_map()
	if not consts.has("DLG") or not (consts["DLG"] is Dictionary):
		_err("%s : pas de const DLG" % path)
		return
	var dlg: Dictionary = consts["DLG"]
	var id := str(dlg.get("_id", ""))
	var name := path.get_file()
	if not chapters.has(id):
		_err("%s : _id « %s » ne correspond à aucun chapitre" % [name, id])
	var ch: Dictionary = chapters.get(id, {})
	var reached := {}
	for node in dlg:
		if node == "_id":
			continue
		if not (dlg[node] is Array):
			_err("%s/%s : un nœud doit être une liste d'étapes" % [name, node])
			continue
		var steps: Array = dlg[node]
		if steps.is_empty():
			_err("%s/%s : nœud vide" % [name, node])
		for i in steps.size():
			var where := "%s/%s[%d]" % [name, node, i]
			if not (steps[i] is Dictionary):
				_err(where + " : étape qui n'est pas un dictionnaire")
				continue
			var s: Dictionary = steps[i]
			for k in s:
				if not STEP_KEYS.has(str(k)):
					_err(where + " : clé inconnue « %s »" % k)
			if s.has("if"):
				_cond(where, s["if"])
			_effects(where, s)
			if s.has("text"):
				lines += 1
				var who := str(s.get("who", "narrateur"))
				if who != "sam" and who != "narrateur" and not CastLooks.LOOKS.has(who):
					_err(where + " : locuteur inconnu « %s »" % who)
				_text(where, str(s["text"]))
				if s.has("anim") and not _gesture_ok(str(s["anim"])):
					_err(where + " : geste inconnu « %s »" % s["anim"])
				if s.has("look") and str(s["look"]) != "sam" and str(s["look"]) != "player" \
						and not CastLooks.LOOKS.has(str(s["look"])) and not Quartier.SPOTS.has(str(s["look"])):
					_err(where + " : regard vers une cible inconnue « %s »" % s["look"])
			elif s.has("choice"):
				var opts: Array = s["choice"]
				if opts.size() < 2:
					_err(where + " : un choix doit proposer au moins deux options")
				var ids := {}
				var always := 0
				for k in opts.size():
					var o: Dictionary = opts[k]
					var ow := "%s option %d" % [where, k]
					for key in o:
						if not OPT_KEYS.has(str(key)):
							_err(ow + " : clé inconnue « %s »" % key)
					if str(o.get("text", "")) == "":
						_err(ow + " : texte du bouton manquant")
					if ids.has(str(o.get("id", ""))):
						_err(ow + " : id en double « %s »" % o.get("id"))
					ids[str(o.get("id", ""))] = true
					if not o.has("if"):
						always += 1
					else:
						_cond(ow, o["if"])
					if o.has("say"):
						lines += 1
						_text(ow, str(o["say"]))
					_effects(ow, o)
					if o.has("goto"):
						_target(ow, dlg, str(o["goto"]), reached)
				if always == 0:
					_err(where + " : toutes les options sont conditionnelles (le choix peut disparaître)")
			elif s.has("goto"):
				_target(where, dlg, str(s["goto"]), reached)
				if s.has("else"):
					_target(where, dlg, str(s["else"]), reached)
			elif s.has("call"):
				var m := str(s["call"])
				if ch.is_empty() or not (ch["inst"] as Object).has_method(m):
					_err(where + " : méthode « %s » absente du script du chapitre %s" % [m, id])
			elif not (s.has("wait") or s.has("end") or s.has("set") or s.has("stats") or s.has("rel") or s.has("news")):
				_err(where + " : étape sans effet")
	# nœuds appelés depuis le chapitre : dialogue(D, "nœud")
	if not ch.is_empty():
		var re := RegEx.create_from_string("dialogue\\(\\s*[A-Za-z_.]+\\s*,\\s*\"([a-z0-9_]+)\"")
		for m in re.search_all(ch["src"]):
			var n := m.get_string(1)
			reached[n] = true
			if not dlg.has(n):
				_err("%s : le chapitre joue le nœud « %s » qui n'existe pas" % [name, n])
		if RegEx.create_from_string("dialogue\\(\\s*[A-Za-z_.]+\\s*\\)").search(ch["src"]):
			reached["start"] = true
	for node in dlg:
		if node != "_id" and not reached.has(node):
			_err("%s : nœud « %s » jamais atteint (ni saut, ni appel depuis le chapitre)" % [name, node])


func _target(where: String, dlg: Dictionary, t: String, reached: Dictionary) -> void:
	reached[t] = true
	if not dlg.has(t) or t == "_id":
		_err(where + " : saut vers un nœud inexistant « %s »" % t)


func _text(where: String, t: String) -> void:
	if t.strip_edges() == "":
		_err(where + " : réplique vide")
	elif t.length() > MAX_LINE:
		_err(where + " : réplique trop longue (%d caractères)" % t.length())


func _gesture_ok(g: String) -> bool:
	return StoryActor.GESTURES.has(g) or NEW_GESTURES.has(g)


func _effects(where: String, s: Dictionary) -> void:
	for k in (s.get("stats", {}) as Dictionary):
		if not Campaign.STAT_DEFAULTS.has(k):
			_err(where + " : jauge inconnue « %s »" % k)
	for k in (s.get("rel", {}) as Dictionary):
		if not Campaign.CAST.has(k):
			_err(where + " : relation inconnue « %s »" % k)
	for k in (s.get("set", {}) as Dictionary):
		if not RegEx.create_from_string("^[a-z][a-z0-9_]*$").search(str(k)):
			_err(where + " : nom de drapeau illisible « %s »" % k)


## Condition lisible : "drapeau", "!x", "stat:k>=n", "rel:k<n", "flag:k==v" ou une liste de conditions
func _cond(where: String, c: Variant) -> void:
	if c is Array:
		if (c as Array).is_empty():
			_err(where + " : liste de conditions vide")
		for x in c:
			_cond(where, x)
		return
	if not (c is String):
		_err(where + " : condition qui n'est pas un texte")
		return
	var s := (c as String).strip_edges()
	if s.begins_with("!"):
		s = s.substr(1)
	var re_flag := RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	if not (s.begins_with("stat:") or s.begins_with("rel:") or s.begins_with("flag:")):
		if not re_flag.search(s):
			_err(where + " : condition illisible « %s »" % c)
		return
	var m := RegEx.create_from_string("^(stat|rel|flag):([a-z][a-z0-9_]*)(>=|<=|==|!=|>|<)(.+)$").search(s)
	if m == null:
		_err(where + " : condition illisible « %s »" % c)
		return
	var kind := m.get_string(1)
	var key := m.get_string(2)
	var op := m.get_string(3)
	var rhs := m.get_string(4)
	if kind == "stat" and not Campaign.STAT_DEFAULTS.has(key):
		_err(where + " : jauge inconnue dans « %s »" % c)
	if kind == "rel" and not Campaign.CAST.has(key):
		_err(where + " : relation inconnue dans « %s »" % c)
	if kind != "flag" and not rhs.is_valid_float():
		_err(where + " : nombre attendu dans « %s »" % c)
	if kind == "flag" and op != "==" and op != "!=":
		_err(where + " : un drapeau se compare avec == ou != (« %s »)" % c)
