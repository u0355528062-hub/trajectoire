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
