class_name Story
extends RefCounted
## Contenu de la campagne « La Hausse » : liste ordonnée des chapitres et réglages du monde pour chacun
## (clés : docs/CAMPAGNE.md § « Réglages du monde »). Le module Scénario remplace le chapitre de démonstration
## par la vraie histoire.

const CHAPTERS := [
	{
		"id": "demo",
		"title": "Démonstration",
		"date": "Jeudi 9 mars — 18 h 40",
		"script": "res://scripts/story/ch_demo.gd",
		"tod": "crepuscule",
		"weather": "sec",
		"crowd": {"size": 12, "cortege": false, "bloc": 0, "medic": false, "press": false},
		"police": {"enabled": false, "cordon": false, "max_stage": 0},
		"civilians": {"density": 1.0},
		"tools": ["phone", "tracts"],
		"spawn": "square",
	},
	{
		"id": "demo2",
		"title": "Démonstration (suite)",
		"date": "Vendredi 10 mars — 21 h 10",
		"script": "res://scripts/story/ch_demo2.gd",
		"tod": "crepuscule",
		"weather": "sec",
		"crowd": {"size": -1},
		"police": {"enabled": true, "cordon": true, "max_stage": 2},
		"tools": ["phone", "stones"],
		"spawn": "",
	},
]


static func index_of(id: String) -> int:
	for i in CHAPTERS.size():
		if str(CHAPTERS[i].get("id", "")) == id:
			return i
	return -1
