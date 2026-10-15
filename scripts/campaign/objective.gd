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
var fail_reason := ""           # raison de l'échec ("timer", "tension"…)
var follow := ""                # id de personnage suivi par le repère (objectif « talk » sans repère fixe)


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
	fail_reason = reason
	failed.emit(reason)


func set_waypoint(p: Vector3) -> void:
	waypoint = p
	follow = ""


## Type d'objectif (spec["type"], "manual" par défaut)
func kind() -> String:
	return str(spec.get("type", "manual"))


## Secondes restantes avant l'expiration du minuteur (-1 : pas de minuteur)
func time_left() -> float:
	if not spec.has("timer"):
		return -1.0
	return maxf(float(spec["timer"]) - age, 0.0)


## Avancement 0..1 (compteur, temps tenu dans la zone, ou temps écoulé pour « survive »)
func ratio() -> float:
	if state == "done":
		return 1.0
	match kind():
		"hold":
			return clampf(hold_t / maxf(float(spec.get("sec", 30.0)), 0.01), 0.0, 1.0)
		"survive":
			return clampf(age / maxf(float(spec.get("timer", 1.0)), 0.01), 0.0, 1.0)
	return clampf(float(progress) / float(maxi(target, 1)), 0.0, 1.0)
