class_name Objective
extends RefCounted
## Un objectif de chapitre affiché au joueur. Créé par ObjectiveTracker.add(id, texte, spec).
## Types (spec["type"]) : "manual" (le script le termine), "reach" (aller à un lieu), "talk" (parler à quelqu'un),
## "event" (compter des événements de la foule), "hold" (tenir une zone), "survive" (tenir un temps).
## Détail : docs/CAMPAGNE.md § « Objectifs ».

signal done
signal failed(reason: String)
signal progressed(value: int, target: int)

var id := ""
var text := ""
var spec: Dictionary = {}
var state := "active"           # active | done | failed
var progress := 0
var target := 1
var waypoint := Vector3.INF     # repère à l'écran (Vector3.INF : aucun)
var optional := false
var age := 0.0                  # secondes depuis la création
var hold_t := 0.0               # temps passé dans la zone (type « hold »)


func is_active() -> bool:
	return state == "active"


func add_progress(n := 1) -> void:
	if not is_active():
		return
	progress = mini(progress + n, target)
	progressed.emit(progress, target)
	if progress >= target:
		complete()


func complete() -> void:
	if not is_active():
		return
	state = "done"
	progress = target
	done.emit()


func fail(reason := "") -> void:
	if not is_active():
		return
	state = "failed"
	failed.emit(reason)


func set_waypoint(p: Vector3) -> void:
	waypoint = p
