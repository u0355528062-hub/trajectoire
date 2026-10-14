class_name Story
extends RefCounted
## Contenu de la campagne « La Hausse » : liste ordonnée des chapitres et réglages du monde pour chacun
## (clés : docs/CAMPAGNE.md § « Réglages du monde »), et fin suggérée selon l'état de la campagne.
## Histoire, personnages, drapeaux : scripts/story/BIBLE.md.

const CHAPTERS := [
	{
		"id": "prologue",
		"title": "La note",
		"date": "Lundi 8 mars 2027 — 8 h 10",
		"script": "res://scripts/story/ch_prologue.gd",
		"tod": "matin",
		"weather": "sec",
		"crowd": {"size": 0, "cortege": false, "bloc": 0, "medic": false, "press": false, "theme": "prix"},
		"police": {"enabled": false, "cordon": false, "max_stage": 0, "patrol": false},
		"civilians": {"density": 0.8},
		"residents": true,
		"tools": [],
		"spawn": "supermarche",
	},
	{
		"id": "douze",
		"title": "On était douze",
		"date": "Jeudi 11 mars — 18 h 30",
		"script": "res://scripts/story/ch_douze.gd",
		"tod": "aprem",
		"weather": "sec",
		"crowd": {"size": 12, "cortege": false, "bloc": 0, "medic": false, "press": false, "theme": "prix",
			"gather": "square", "calm": true},
		"police": {"enabled": true, "cordon": false, "max_stage": 1, "start_tension": 0.0, "tension_frozen": true,
			"patrol": true},
		"civilians": {"density": 1.1},
		"residents": true,
		"tools": ["phone", "tracts", "posters", "spray"],
		"spawn": "bar_qg",
	},
	{
		"id": "prix",
		"title": "Les prix, en vrai",
		"date": "Samedi 13 mars — 15 h 00",
		"script": "res://scripts/story/ch_prix.gd",
		"tod": "aprem",
		"weather": "bruine",
		"crowd": {"size": 4, "cortege": false, "bloc": 0, "medic": false, "press": false, "theme": "prix",
			"gather": "square", "calm": true},
		"police": {"enabled": true, "cordon": false, "max_stage": 1, "start_tension": 0.0, "tension_frozen": true,
			"patrol": true},
		"civilians": {"density": 1.3},
		"residents": true,
		"tools": ["phone", "tracts"],
		"spawn": "bar_qg",
	},
	{
		"id": "cortege",
		"title": "Premier cortège",
		"date": "Mardi 16 mars — 19 h 40",
		"script": "res://scripts/story/ch_cortege.gd",
		"tod": "crepuscule",
		"weather": "sec",
		"crowd": {"size": "mobilisation", "cortege": true, "bloc": 0, "medic": true, "press": false, "theme": "prix",
			"gather": "square", "calm": false},
		"police": {"enabled": true, "cordon": true, "line_x": 84.0, "max_stage": 2, "start_tension": 0.1,
			"tension_frozen": false, "patrol": false},
		"civilians": {"density": 0.9},
		"residents": true,
		"tools": ["phone", "megaphone", "tracts"],
		"spawn": "square",
	},
]


static func index_of(id: String) -> int:
	for i in CHAPTERS.size():
		if str(CHAPTERS[i].get("id", "")) == id:
			return i
	return -1


## Fin suggérée par l'histoire (BIBLE.md § 6) : "greve" (cachée), "recul", "amere" ou "essoufflement"
static func ending_for_state() -> String:
	var op := Campaign.stat("opinion")
	var casse := int(Campaign.flag("casse_total", 0))
	var scars := bool(Campaign.flag("karim_prison", false)) or bool(Campaign.flag("sam_fiche", false))
	var clash := str(Campaign.flag("ch5_issue", "")) == "affrontement"
	if bool(Campaign.flag("docu_lou", false)) and bool(Campaign.flag("temoignage_ferreira", false)) \
			and op >= 55.0 and casse <= 6 and not clash:
		return "greve"
	if op >= 60.0 and casse <= 10 and not scars and not clash:
		return "recul"
	if op >= 45.0:
		return "amere"
	return "essoufflement"
