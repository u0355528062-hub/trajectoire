extends SceneTree
## Validateur des dialogues : vérifie tous les scripts/story/dlg_*.gd (format : docs/CAMPAGNE.md § « Format des
## dialogues ») — nœuds existants pour chaque goto/else, conditions lisibles (DialogueUI.parse_cond), locuteurs
## et regards connus, gestes connus, jauges et relations connues, méthodes « call » présentes dans le script de
## chapitre correspondant (ch_<x>.gd, ou les ch_*.gd qui utilisent la classe du dialogue), clés d'étape connues.
## Avertissements (non bloquants) : nœuds jamais atteints, drapeaux testés mais jamais posés, plus de 4 options.
##   tools/dev/gd --headless --path . -s tools/check_dialogues.gd
## Sortie : « RÉSULTAT : OK » ou « RÉSULTAT : ÉCHEC (n erreurs) » (code de sortie 1).

const DIR := "res://scripts/story/"
const STEP_KEYS := ["who", "text", "anim", "look", "wait", "if", "choice", "prompt", "timer", "goto", "else", "set",
	"stats", "rel", "news", "call", "end"]
const OPTION_KEYS := ["id", "text", "say", "if", "set", "stats", "rel", "goto", "anim", "news"]

var errors := 0
var warnings := 0
var _file := ""
var _ch_sources := {}       # chemin ch_*.gd -> source
var _flags_set := {}        # drapeaux posés quelque part (dialogues ou chapitres)
var _flags_tested := {}     # drapeau -> "fichier [nœud]"


func _initialize() -> void:
	var files := _list("dlg_")
	for f in _list("ch_"):
		var src := FileAccess.get_file_as_string(DIR + f)
		_ch_sources[f] = src
		_collect_set_flags(src)
	if files.is_empty():
		print("ATTENTION : aucun scripts/story/dlg_*.gd")
	var dlgs := {}
	for f in files:
		var scr: Variant = load(DIR + f)
		if not (scr is Script):
			_err(f, "", "script illisible")
			continue
		var consts: Dictionary = (scr as Script).get_script_constant_map()
		if not consts.has("DLG") or not (consts["DLG"] is Dictionary):
			_err(f, "", "constante DLG (Dictionary) absente")
			continue
		dlgs[f] = consts["DLG"]
		for k in consts["DLG"]:
			for st in (consts["DLG"][k] if consts["DLG"][k] is Array else []):
				if st is Dictionary:
					_collect_dict_flags(st)
					for o in (st.get("choice", []) if st.get("choice", []) is Array else []):
						if o is Dictionary:
							_collect_dict_flags(o)
	for f in dlgs:
		_file = f
		_check(f, dlgs[f], FileAccess.get_file_as_string(DIR + f))
	for fl in _flags_tested:
		if not _flags_set.has(fl):
			_warn(str(_flags_tested[fl]), "drapeau « %s » testé mais jamais posé (set / set_flag)" % fl)
	print("dialogues vérifiés : %d fichier(s), %d erreur(s), %d avertissement(s)" % [dlgs.size(), errors, warnings])
	print("RÉSULTAT : OK" if errors == 0 else "RÉSULTAT : ÉCHEC (%d erreurs)" % errors)
	quit(0 if errors == 0 else 1)


func _list(prefix: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for f in d.get_files():
		if f.begins_with(prefix) and f.ends_with(".gd"):
			out.append(f)
	out.sort()
	return out


func _err(f: String, where: String, msg: String) -> void:
	errors += 1
	print("ERREUR %s%s : %s" % [f, (" [" + where + "]") if where != "" else "", msg])


func _warn(where: String, msg: String) -> void:
	warnings += 1
	print("ATTENTION %s : %s" % [where, msg])


func _collect_set_flags(src: String) -> void:
	var re := RegEx.new()
	re.compile("set_flag\\(\\s*\"([A-Za-z0-9_]+)\"")
	for m in re.search_all(src):
		_flags_set[m.get_string(1)] = true
	var re2 := RegEx.new()
	re2.compile("\"set\"\\s*:\\s*\\{([^}]*)\\}")
	var re3 := RegEx.new()
	re3.compile("\"([A-Za-z0-9_]+)\"\\s*:")
	for m in re2.search_all(src):
		for m2 in re3.search_all(m.get_string(1)):
			_flags_set[m2.get_string(1)] = true


func _collect_dict_flags(d: Dictionary) -> void:
	if d.get("set", null) is Dictionary:
		for k in d["set"]:
			_flags_set[str(k)] = true


## Scripts de chapitre où chercher les méthodes « call » : ch_<x>.gd, sinon ceux qui citent la classe du dialogue
func _chapter_scripts(f: String, src: String) -> Array:
	var base := f.trim_prefix("dlg_")
	if _ch_sources.has("ch_" + base):
		return ["ch_" + base]
	var out: Array = []
	var re := RegEx.new()
	re.compile("class_name\\s+([A-Za-z0-9_]+)")
	var m := re.search(src)
	if m:
		var cls := m.get_string(1)
		for c in _ch_sources:
			if (_ch_sources[c] as String).contains(cls):
				out.append(c)
	return out


func _methods_of(ch_files: Array) -> Dictionary:
	var out := {}
	for c in ch_files:
		var scr: Variant = load(DIR + str(c))
		if scr is Script:
			for m in (scr as Script).get_script_method_list():
				out[str(m["name"])] = true
	return out


func _check(f: String, dlg: Dictionary, src: String) -> void:
	if not dlg.has("_id") or not (dlg["_id"] is String) or str(dlg["_id"]) == "":
		_err(f, "", "clé « _id » (id du chapitre, dossier des voix) absente ou vide")
	var speakers := {}
	for k in CastLooks.LOOKS:
		speakers[k] = true
	speakers["sam"] = true
	speakers["narrateur"] = true
	var nodes := {}
	for k in dlg:
		if k != "_id":
			nodes[str(k)] = true
	var ch_files := _chapter_scripts(f, src)
	var methods := _methods_of(ch_files)
	var refs := {}        # nœuds atteints par un goto
	for n in nodes:
		var steps: Variant = dlg[n]
		if not (steps is Array):
			_err(f, n, "le nœud doit être une liste d'étapes")
			continue
		if (steps as Array).is_empty():
			_warn("%s [%s]" % [f, n], "nœud vide")
		for i in (steps as Array).size():
			var s: Variant = steps[i]
			var w := "%s#%d" % [n, i]
			if not (s is Dictionary):
				_err(f, w, "étape qui n'est pas un dictionnaire")
				continue
			var st: Dictionary = s
			for key in st:
				if not STEP_KEYS.has(str(key)):
					_err(f, w, "clé d'étape inconnue « %s »" % key)
			if st.has("if"):
				_check_cond(f, w, st["if"])
			if st.has("text"):
				var who := str(st.get("who", "narrateur"))
				if not speakers.has(who):
					_err(f, w, "locuteur inconnu « %s »" % who)
				if not (st["text"] is String) or str(st["text"]).strip_edges() == "":
					_err(f, w, "réplique vide")
				if st.has("anim") and not StoryActor.GESTURES.has(str(st["anim"])):
					_err(f, w, "geste inconnu « %s »" % st["anim"])
				if st.has("look"):
					var lk := str(st["look"])
					if not speakers.has(lk) and lk != "player" and not Quartier.SPOTS.has(lk):
						_err(f, w, "cible de regard inconnue « %s »" % lk)
			elif st.has("who"):
				_err(f, w, "« who » sans « text »")
			if st.has("wait") and not (st["wait"] is float or st["wait"] is int):
				_err(f, w, "« wait » doit être un nombre")
			if st.has("choice"):
				_check_choice(f, w, st, nodes, refs)
			if st.has("goto"):
				_check_goto(f, w, st["goto"], nodes, refs)
				if st.has("else"):
					_check_goto(f, w, st["else"], nodes, refs)
			elif st.has("else"):
				_err(f, w, "« else » sans « goto »")
			if st.has("call"):
				var m := str(st["call"])
				if ch_files.is_empty():
					_err(f, w, "« call » %s : aucun script de chapitre (ch_*.gd) n'utilise ce dialogue" % m)
				elif not methods.has(m):
					_err(f, w, "méthode « %s » absente de %s" % [m, ", ".join(ch_files)])
			_check_effects(f, w, st)
	# nœuds jamais atteints : ni « start », ni cible d'un goto, ni cité par un script de chapitre
	var ch_all := ""
	for c in _ch_sources:
		ch_all += str(_ch_sources[c])
	for n in nodes:
		if n != "start" and not refs.has(n) and not ch_all.contains("\"%s\"" % n):
			_warn("%s [%s]" % [f, n], "nœud jamais atteint")


func _check_choice(f: String, w: String, st: Dictionary, nodes: Dictionary, refs: Dictionary) -> void:
	var ch: Variant = st["choice"]
	if not (ch is Array) or (ch as Array).is_empty():
		_err(f, w, "« choice » doit être une liste d'options non vide")
		return
	if (ch as Array).size() > 9:
		_err(f, w, "plus de 9 options")
	elif (ch as Array).size() > 4:
		_warn("%s [%s]" % [f, w], "plus de 4 options (touches 1-4)")
	if st.has("timer") and not (st["timer"] is float or st["timer"] is int):
		_err(f, w, "« timer » doit être un nombre")
	var ids := {}
	for k in (ch as Array).size():
		var o: Variant = ch[k]
		var wo := "%s option %d" % [w, k + 1]
		if not (o is Dictionary):
			_err(f, wo, "option qui n'est pas un dictionnaire")
			continue
		var od: Dictionary = o
		for key in od:
			if not OPTION_KEYS.has(str(key)):
				_err(f, wo, "clé d'option inconnue « %s »" % key)
		if not (od.get("text", null) is String) or str(od.get("text", "")).strip_edges() == "":
			_err(f, wo, "texte du bouton manquant")
		if od.has("id"):
			if ids.has(str(od["id"])):
				_err(f, wo, "id d'option en double « %s »" % od["id"])
			ids[str(od["id"])] = true
		if od.has("if"):
			_check_cond(f, wo, od["if"])
		if od.has("goto"):
			_check_goto(f, wo, od["goto"], nodes, refs)
		if od.has("anim") and not StoryActor.GESTURES.has(str(od["anim"])):
			_err(f, wo, "geste inconnu « %s »" % od["anim"])
		_check_effects(f, wo, od)
	if st.has("timer") and (ch as Array).size() > 0 and (ch[0] is Dictionary) and (ch[0] as Dictionary).has("if"):
		_warn("%s [%s]" % [f, w], "choix minuté dont l'option 0 (par défaut) est conditionnelle")


func _check_goto(f: String, w: String, target: Variant, nodes: Dictionary, refs: Dictionary) -> void:
	var t := str(target)
	if not nodes.has(t):
		_err(f, w, "goto vers un nœud inexistant « %s »" % t)
	refs[t] = true


func _check_cond(f: String, w: String, c: Variant) -> void:
	if c is Array:
		for x in c:
			_check_cond(f, w, x)
		return
	if c is bool:
		return
	if not (c is String):
		_err(f, w, "condition qui n'est ni un texte ni une liste")
		return
	var p := DialogueUI.parse_cond(c)
	if p.has("error"):
		_err(f, w, "condition illisible : %s" % p["error"])
		return
	match str(p["kind"]):
		"stat":
			if not Campaign.STAT_DEFAULTS.has(str(p["key"])):
				_err(f, w, "jauge inconnue « %s »" % p["key"])
		"rel":
			if not Campaign.CAST.has(str(p["key"])):
				_err(f, w, "relation inconnue « %s »" % p["key"])
		"flag", "flagcmp":
			if not _flags_tested.has(str(p["key"])):
				_flags_tested[str(p["key"])] = "%s [%s]" % [f, w]


func _check_effects(f: String, w: String, d: Dictionary) -> void:
	if d.has("set") and not (d["set"] is Dictionary):
		_err(f, w, "« set » doit être un dictionnaire")
	if d.has("stats"):
		if not (d["stats"] is Dictionary):
			_err(f, w, "« stats » doit être un dictionnaire")
		else:
			for k in d["stats"]:
				if not Campaign.STAT_DEFAULTS.has(str(k)):
					_err(f, w, "jauge inconnue « %s »" % k)
				elif not (d["stats"][k] is float or d["stats"][k] is int):
					_err(f, w, "variation de jauge non numérique « %s »" % k)
	if d.has("rel"):
		if not (d["rel"] is Dictionary):
			_err(f, w, "« rel » doit être un dictionnaire")
		else:
			for k in d["rel"]:
				if not Campaign.CAST.has(str(k)):
					_err(f, w, "relation inconnue « %s »" % k)
	if d.has("news") and not (d["news"] is String):
		_err(f, w, "« news » doit être un texte")
