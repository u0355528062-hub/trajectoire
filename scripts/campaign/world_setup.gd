class_name WorldSetup
extends RefCounted
## Réglages du monde pour la partie en cours, lus par main.gd au moment de construire la scène :
## chapitre de campagne (Story.CHAPTERS[i]), bac à sable configuré au menu, ou jeu d'origine (DEFAULT).
## Clés (toutes optionnelles, fusionnées avec DEFAULT) — voir docs/CAMPAGNE.md § « Réglages du monde ».

const TOOLS_ORIGINAL := ["mortar", "stones", "igniter", "flare", "petards_small", "petards_medium"]
const TOOLS_CAMPAIGN := ["phone", "tracts", "posters", "megaphone", "spray"]
const DEFAULT := {
	"tod": "crepuscule",          # matin | midi | aprem | crepuscule | nuit | aube
	"weather": "sec",             # sec | bruine | pluie | brume
	"crowd": {"size": -1, "cortege": true, "bloc": -1, "medic": true, "press": true, "theme": "origine"},
	"police": {"enabled": true, "cordon": true, "line_x": 54.0, "max_stage": 4, "start_tension": 0.0,
		"tension_frozen": false, "patrol": true},
	"civilians": {"density": 1.0},
	"residents": true,
	"tools": ["mortar", "stones", "igniter", "flare", "petards_small", "petards_medium"],
	"spawn": "",                   # id de lieu (Quartier.SPOTS) ; "" = position d'origine
}

## Réglages choisis dans le menu « Bac à sable » (vide = jeu d'origine)
static var sandbox: Dictionary = {}


## Réglages effectifs de la partie qui démarre
static func config() -> Dictionary:
	var over: Dictionary = Campaign.chapter_def() if Campaign.active else sandbox
	return merge(DEFAULT, over)


## Fusion récursive : les clés de `over` remplacent celles de `base` (les sous-dictionnaires sont fusionnés)
static func merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in over:
		if out.has(k) and out[k] is Dictionary and over[k] is Dictionary:
			out[k] = merge(out[k], over[k])
		else:
			out[k] = over[k] if not (over[k] is Dictionary or over[k] is Array) else over[k].duplicate(true)
	return out


static func tool_allowed(cfg: Dictionary, id: String) -> bool:
	return (cfg.get("tools", []) as Array).has(id)
