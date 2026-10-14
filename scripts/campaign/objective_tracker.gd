class_name ObjectiveTracker
extends CanvasLayer
## Objectifs du chapitre : création, suivi automatique (lieux, événements, zones, minuteurs, conditions d'échec),
## affichage (liste animée ObjectiveList, repères à l'écran ObjectiveMarkers) et aides contextuelles (ObjectiveHint).
## Tout se masque pendant les cinématiques ; les minuteurs y sont suspendus (sauf en pilote automatique).
## Types et clés des objectifs : docs/CAMPAGNE.md § 5.5.

signal objective_finished(o: Objective, ok: bool)

var director: ChapterDirector
var list: Array[Objective] = []
var _root: Control
var _panel: ObjectiveList
var _markers: ObjectiveMarkers
var _hint: ObjectiveHint
var _shown := 1.0


func bind(d: ChapterDirector) -> void:
	director = d
	d.event.connect(_on_event)


func _ready() -> void:
	layer = 30
	_root = Control.new()
	_root.name = "ObjectivesUI"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_markers = ObjectiveMarkers.new()
	_markers.tracker = self
	_root.add_child(_markers)
	_panel = ObjectiveList.new()
	_root.add_child(_panel)
	_hint = ObjectiveHint.new()
	_root.add_child(_hint)


func add(id: String, text: String, spec := {}) -> Objective:
	var o := Objective.new()
	o.id = id
	o.text = text
	o.spec = spec.duplicate(true)
	o.target = maxi(int(spec.get("count", 1)), 1)
	o.optional = bool(spec.get("optional", false))
	var wp: Variant = spec.get("waypoint", spec.get("spot", null))
	if wp is String and Quartier.SPOTS.has(wp):
		o.waypoint = Quartier.spot(wp)
	elif wp is Vector3:
		o.waypoint = wp
	elif str(spec.get("type", "")) == "talk" and str(spec.get("who", "")) not in ["", "passant"]:
		o.follow = str(spec["who"])          # le repère suit la personne à qui parler
	o.done.connect(func() -> void: _finished(o, true))
	o.failed.connect(func(_r: String) -> void: _finished(o, false))
	list.append(o)
	if _panel:
		_panel.add_objective(o)
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
	if _panel:
		_panel.clear_all()


func hint(text: String, sec := 5.0) -> void:
	if _hint:
		_hint.show_text(text, sec)


## Texte de l'aide affichée ("" s'il n'y en a pas)
func hint_text() -> String:
	return _hint.current() if _hint else ""


## Interface visible (hors cinématique)
func shown() -> bool:
	return _root != null and _root.visible


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


## Position d'un repère (personnage suivi ou point fixe), Vector3.INF s'il n'y en a pas
func marker_pos(o: Objective) -> Vector3:
	if o.follow != "" and director and director.cast:
		var a := director.cast.get_actor(o.follow)
		if a != null and is_instance_valid(a) and a.is_inside_tree():
			return a.global_position
		return Vector3.INF
	return o.waypoint


func _finished(o: Objective, ok: bool) -> void:
	objective_finished.emit(o, ok)


func _cine() -> bool:
	return director != null and director.cine != null and director.cine.active


func _on_event(type: String, d: Dictionary) -> void:
	for o in list:
		if not o.is_active():
			continue
		var t := o.kind()
		if t == "event" and type == str(o.spec.get("event", "")):
			var f: Dictionary = o.spec.get("filter", {})
			var ok := true
			for k in f:
				if not d.has(k) or str(d[k]) != str(f[k]):
					ok = false
			if ok:
				o.add_progress(maxi(int(d.get("n", 1)), 1))
		elif t == "talk" and type == "talk" and str(d.get("who", "")) == str(o.spec.get("who", "")):
			o.complete()


func _process(delta: float) -> void:
	var cine := _cine()
	_shown = UiStyle.damp(_shown, 0.0 if cine else 1.0, 9.0, delta)
	_root.modulate.a = _shown
	_root.visible = _shown > 0.01
	var p: Player = director.player if director else null
	for o in list:
		if not o.is_active():
			continue
		# les minuteurs ne tournent pas pendant une cinématique (le joueur ne peut rien faire)
		if not cine or Campaign.autoplay or not o.spec.has("timer"):
			o.age += delta
		if o.follow != "":
			var fp := marker_pos(o)
			if fp != Vector3.INF:
				o.waypoint = fp
		if Campaign.autoplay and o.age >= float(o.spec.get("autoplay_after", 0.3)):
			o.complete()
			continue
		if o.spec.has("timer") and o.age >= float(o.spec["timer"]):
			if o.kind() == "survive":
				o.complete()
			else:
				o.fail("timer")
			continue
		var fail_if: Dictionary = o.spec.get("fail_if", {})
		if fail_if.has("tension_above") and director and director.tension \
				and director.tension.value > float(fail_if["tension_above"]):
			o.fail("tension")
			continue
		var t := o.kind()
		if p and is_instance_valid(p) and (t == "reach" or t == "hold"):
			var c: Vector3 = o.waypoint if o.waypoint != Vector3.INF else Vector3.ZERO
			var inside := Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length() < float(o.spec.get("radius", 4.0))
			if t == "reach" and inside:
				o.complete()
			elif t == "hold":
				o.hold_t = o.hold_t + delta if inside else maxf(o.hold_t - delta * 0.5, 0.0)
				if o.hold_t >= float(o.spec.get("sec", 30.0)):
					o.complete()
