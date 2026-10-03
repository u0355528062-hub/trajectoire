class_name Voices
extends RefCounted
## Répliques enregistrées (synthèse vocale neuronale) : un fichier par
## phrase, retrouvé par l'empreinte MD5 du texte prononcé.
## assets/voices/<locuteur>/<md5>.ogg  +  env.json (enveloppe pour les lèvres)

const DIR := "res://assets/voices/"

static var _env_cache: Dictionary = {}


static func key(text: String) -> String:
	return Cases.speech_text(text).md5_text()


static func stream(speaker: String, text: String) -> AudioStream:
	var p := "%s%s/%s.ogg" % [DIR, speaker, key(text)]
	if ResourceLoader.exists(p):
		return load(p)
	return null


static func envelope(speaker: String, text: String) -> PackedFloat32Array:
	if not _env_cache.has(speaker):
		var path := "%s%s/env.json" % [DIR, speaker]
		var data := {}
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if typeof(parsed) == TYPE_DICTIONARY:
				data = parsed
		_env_cache[speaker] = data
	var d: Dictionary = _env_cache[speaker]
	var arr = d.get(key(text), [])
	var out := PackedFloat32Array()
	for v in arr:
		out.append(float(v) / 100.0)
	return out


## Liste de toutes les répliques du jeu (pour la génération des voix).
static func all_lines() -> Array:
	var out: Array = []
	for cid in Cases.CASES.keys():
		var c: Dictionary = Cases.CASES[cid]
		var p: Dictionary = c["patient"]
		var comp: Dictionary = c.get("companion", {})
		var texts: Array = [c.get("greeting", "")]
		for q in Cases.QUESTIONS:
			texts.append(Cases.answer(c, q["id"]))
		for e in c.get("extra_questions", []):
			texts.append(e["answer"])
		for t in texts:
			var sp: Array = Cases.split_speaker(t)
			if sp[0] == "La mère" and not comp.is_empty():
				out.append({"speaker": cid + "_mere", "voice": comp["voice"], "pitch": comp["pitch"], "text": t})
			else:
				out.append({"speaker": cid, "voice": p["voice"], "pitch": p["pitch"], "text": t})
		for g in Cases.GENERIC.values():
			out.append({"speaker": cid, "voice": p["voice"], "pitch": p["pitch"], "text": g})
		if not comp.is_empty():
			for g2 in ["hello", "ok", "bye", "which"]:
				out.append({"speaker": cid + "_mere", "voice": comp["voice"], "pitch": comp["pitch"], "text": Cases.GENERIC[g2]})
	for sid in Cases.LINES.keys():
		var cast: Dictionary = Cases.CAST[sid]
		for t in Cases.LINES[sid].values():
			out.append({"speaker": sid, "voice": cast["voice"], "pitch": cast["pitch"], "text": t, "phone": sid == "regulateur"})
	# Annonces de Camille pour chaque patient.
	var cam: Dictionary = Cases.CAST["camille"]
	for cid in Cases.CASES.keys():
		var r := PatientRecord.new()
		r.case_id = cid
		r.data = Cases.CASES[cid]
		for t in [arrival_line(r, false), arrival_line(r, true), call_line(r)]:
			out.append({"speaker": "camille", "voice": cam["voice"], "pitch": cam["pitch"], "text": t})
	return out


static func arrival_line(r: PatientRecord, walk_in: bool) -> String:
	if r.is_urgent():
		return Cases.LINES["camille"]["urgent"]
	if walk_in:
		if r.is_child():
			return "Docteur, %s et sa maman se présentent sans rendez-vous. Il a de la fièvre." % r.first_name()
		return "Docteur, %s se présente sans rendez-vous." % r.title_name().replace("M.", "monsieur").replace("Mme", "madame")
	return "%s est arrivé%s pour son rendez-vous." % [r.title_name().replace("M.", "Monsieur").replace("Mme", "Madame"), "e" if r.is_female() else ""]


static func call_line(r: PatientRecord) -> String:
	if r.is_child():
		return "%s, c'est à toi !" % r.first_name()
	return "%s, c'est à vous !" % r.title_name().replace("M.", "Monsieur").replace("Mme", "Madame")
