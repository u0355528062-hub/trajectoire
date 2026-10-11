class_name ObjectiveTracker
extends CanvasLayer
## Objectifs du chapitre : création, suivi automatique (lieux, événements, zones, minuteurs, conditions d'échec),
## affichage (liste d'objectifs, repères à l'écran), aides contextuelles (hint).
## VERSION SQUELETTE : suivi complet, affichage minimal ; le module Objectifs remplace l'affichage en gardant
## l'interface publique.

signal objective_finished(o: Objective, ok: bool)

var director: ChapterDirector
var list: Array[Objective] = []
var _label: Label
var _hint: Label
var _hint_t := 0.0


func bind(d: ChapterDirector) -> void:
	director = d
	d.event.connect(_on_event)


func _ready() -> void:
	layer = 30
	_label = Label.new()
	_label.position = Vector2(24, 120)
	add_child(_label)
	_hint = Label.new()
	_hint.anchor_left = 0.3
	_hint.anchor_right = 0.7
	_hint.anchor_top = 0.7
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)


func add(id: String, text: String, spec := {}) -> Objective:
	var o := Objective.new()
	o.id = id
	o.text = text
	o.spec = spec.duplicate(true)
	o.target = int(spec.get("count", 1))
	o.optional = bool(spec.get("optional", false))
	var wp: Variant = spec.get("waypoint", spec.get("spot", null))
	if wp is String and Quartier.SPOTS.has(wp):
		o.waypoint = Quartier.spot(wp)
	elif wp is Vector3:
		o.waypoint = wp
	o.done.connect(func() -> void: _finished(o, true))
	o.failed.connect(func(_r: String) -> void: _finished(o, false))
	list.append(o)
	_refresh()
	return o


func get_objective(id: String) -> Objective:
	for o in list:
		if o.id == id:
			return o
	return null


func clear() -> void:
	for o in list:
		if o.is_active():
			o.state = "cleared"
	list.clear()
	_refresh()


func hint(text: String, sec := 5.0) -> void:
	_hint.text = text
	_hint_t = sec


## Attend la fin d'un objectif : true s'il est atteint
func wait_for(o: Objective) -> bool:
	while o.is_active():
		await director.sleep(0.1)
	return o.state == "done"


## Attend le premier objectif terminé de la liste
func wait_any(objs: Array) -> Objective:
	while true:
		for o in objs:
			if o != null and not (o as Objective).is_active():
				return o
		await director.sleep(0.1)
	return null


func _finished(o: Objective, ok: bool) -> void:
	objective_finished.emit(o, ok)
	_refresh()


func _on_event(type: String, d: Dictionary) -> void:
	for o in list:
		if not o.is_active():
			continue
		var t := str(o.spec.get("type", "manual"))
		if t == "event" and type == str(o.spec.get("event", "")):
			var f: Dictionary = o.spec.get("filter", {})
			var ok := true
			for k in f:
				if not d.has(k) or str(d[k]) != str(f[k]):
					ok = false
			if ok:
				o.add_progress(int(d.get("n", 1)))
				_refresh()
		elif t == "talk" and type == "talk" and str(d.get("who", "")) == str(o.spec.get("who", "")):
			o.complete()


func _process(delta: float) -> void:
	_hint_t -= delta
	if _hint_t <= 0.0:
		_hint.text = ""
	var p: Player = director.player if director else null
	for o in list:
		if not o.is_active():
			continue
		o.age += delta
		if Campaign.autoplay and o.age >= float(o.spec.get("autoplay_after", 0.3)):
			o.complete()
			continue
		if o.spec.has("timer") and o.age >= float(o.spec["timer"]):
			if str(o.spec.get("type", "")) == "survive":
				o.complete()
			else:
				o.fail("timer")
			continue
		var fail_if: Dictionary = o.spec.get("fail_if", {})
		if fail_if.has("tension_above") and director.tension and director.tension.value > float(fail_if["tension_above"]):
			o.fail("tension")
			continue
		var t := str(o.spec.get("type", "manual"))
		if p and (t == "reach" or t == "hold"):
			var c: Vector3 = o.waypoint if o.waypoint != Vector3.INF else Vector3.ZERO
			var inside := Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length() < float(o.spec.get("radius", 4.0))
			if t == "reach" and inside:
				o.complete()
			elif t == "hold":
				o.hold_t = o.hold_t + delta if inside else maxf(o.hold_t - delta * 0.5, 0.0)
				if o.hold_t >= float(o.spec.get("sec", 30.0)):
					o.complete()
	_refresh()


func _refresh() -> void:
	if _label == null:
		return
	var s := ""
	for o in list:
		var mark := "✓" if o.state == "done" else ("✗" if o.state == "failed" else "•")
		s += "%s %s%s\n" % [mark, o.text, (" (%d/%d)" % [o.progress, o.target]) if o.target > 1 else ""]
	_label.text = s
