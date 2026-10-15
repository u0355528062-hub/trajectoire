extends SceneTree
## Objectifs & interface : suivi des objectifs (événement filtré, conversation, minuteur, survie, zone, pilote
## automatique), minuteurs suspendus en cinématique, liste animée (lignes, repli), interface masquée pendant les
## cinématiques, aides contextuelles, repères à l'écran (dans le champ / flèche au bord), clear().
## Directeur de chapitre minimal (sans carte) : seuls les services testés sont branchés.

var d: ChapterDirector
var tr: ObjectiveTracker
var cam: Camera3D
var fails: Array = []
var limit := 0
var finished: Array = []


func _initialize() -> void:
	Campaign.reset()
	Campaign.active = true
	Campaign.autoplay = false
	d = ChapterDirector.new()
	root.add_child(d)
	d.cine = Cinematics.new()
	d.add_child(d.cine)
	d.cine.bind(d)
	tr = ObjectiveTracker.new()
	d.add_child(tr)
	tr.bind(d)
	d.objectives = tr
	tr.objective_finished.connect(func(o: Objective, ok: bool) -> void: finished.append([o.id, ok]))
	var n3 := Node3D.new()
	root.add_child(n3)
	cam = Camera3D.new()
	n3.add_child(cam)
	_run()


func _process(_d: float) -> bool:
	limit += 1
	if limit > 30 * 120:
		print("ÉCHEC : délai du test dépassé")
		quit(1)
		return true
	return false


func check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)
		print("ÉCHEC : ", what)
	else:
		print("  ok  ", what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await frames(2)
	cam.current = true
	cam.global_position = Vector3(0, 1.6, 0)
	# --- événement filtré, progression
	var prog: Array = []
	var o := tr.add("tracts", "Distribue des tracts", {"type": "event", "event": "tract_given", "count": 3, "filter": {"by": "player"}})
	o.progressed.connect(func(v: int, t: int) -> void: prog.append([v, t]))
	d.on_event("tract_given", {"by": "player"})
	d.on_event("tract_given", {"by": "crowd"})
	check(o.progress == 1 and prog.size() == 1, "filtre d'événement respecté (1/3)")
	d.on_event("tract_given", {"by": "player"})
	d.on_event("tract_given", {"by": "player"})
	check(o.state == "done" and o.ratio() == 1.0, "objectif d'événement atteint (3/3)")
	check(finished.has(["tracts", true]), "signal objective_finished(o, true)")
	# --- conversation : le repère suit la personne (id), atteint sur l'événement talk
	var t := tr.add("nadia", "Parle à Nadia", {"type": "talk", "who": "nadia"})
	check(t.follow == "nadia", "objectif talk : repère qui suit le personnage")
	d.on_event("talk", {"who": "karim"})
	check(t.is_active(), "talk : autre personne ignorée")
	d.on_event("talk", {"who": "nadia"})
	check(t.state == "done", "talk : atteint")
	# --- minuteur (échec), survie (réussite), facultatif
	var tm := tr.add("vite", "Rejoins le square", {"type": "manual", "timer": 0.5, "waypoint": Vector3(0, 0, -20)})
	var sv := tr.add("tenir", "Tiens bon", {"type": "survive", "timer": 0.4})
	var opt := tr.add("bonus", "Colle une affiche", {"type": "manual", "optional": true, "spot": "morris"})
	check(opt.optional and opt.waypoint != Vector3.INF, "facultatif avec repère sur un lieu")
	check(tm.time_left() > 0.0 and tm.time_left() <= 0.5, "time_left() du minuteur")
	await frames(30)
	check(tm.state == "failed" and tm.fail_reason == "timer", "minuteur expiré : échec « timer »")
	check(sv.state == "done", "survive : atteint à l'expiration")
	check(finished.has(["vite", false]), "signal objective_finished(o, false)")
	# --- liste : une ligne par objectif, facultatif en fin de liste
	var lst: ObjectiveList = _find(tr, "ObjectiveList")
	check(lst != null, "liste d'objectifs construite")
	if lst:
		var rows := _rows(lst)
		check(rows.size() >= 4, "lignes de la liste (%d)" % rows.size())
		var last_main := -1
		var first_opt := 999
		for i in rows.size():
			var r: ObjectiveList.Row = rows[i]
			if r.o.optional:
				first_opt = mini(first_opt, i)
			else:
				last_main = maxi(last_main, i)
		check(last_main < first_opt, "objectifs facultatifs rangés après les principaux")
	# --- repères : dans le champ, puis derrière la caméra (flèche au bord)
	var mk: ObjectiveMarkers = _find(tr, "ObjectiveMarkers")
	check(mk != null, "calque des repères construit")
	if mk:
		var a: Array = mk.project(cam, Vector3(0, 1.5, -15))
		check(bool(a[1]) and not bool(a[2]), "repère devant la caméra : à l'écran")
		var b: Array = mk.project(cam, Vector3(0, 1.5, 15))
		check(not bool(b[1]) and bool(b[2]), "repère derrière la caméra : flèche au bord")
		var c: Array = mk.project(cam, Vector3(200, 1.5, -5))
		check(not bool(c[1]), "repère hors champ latéral : flèche au bord")
	# --- cinématique : interface masquée, minuteur suspendu
	var held := tr.add("cine_timer", "Attends", {"type": "manual", "timer": 0.3})
	d.cine.active = true
	await frames(25)
	check(not tr.shown(), "interface masquée pendant la cinématique")
	check(held.is_active() and held.age < 0.05, "minuteur suspendu pendant la cinématique")
	d.cine.active = false
	await frames(20)
	check(tr.shown(), "interface de retour après la cinématique")
	check(held.state == "failed", "minuteur repris après la cinématique")
	# --- aide contextuelle
	tr.hint("Tends un tract aux passants (E).", 1.5)
	check(tr.hint_text() == "Tends un tract aux passants (E).", "aide affichée")
	await frames(55)
	check(tr.hint_text() == "", "aide effacée après son temps")
	# --- attente asynchrone
	var w := tr.add("attente", "Fais quelque chose", {})
	_complete_later(w)
	var got: bool = await tr.wait_for(w)
	check(got, "wait_for() : true quand l'objectif est atteint")
	var x1 := tr.add("x1", "Un", {})
	var x2 := tr.add("x2", "Deux", {})
	x2.fail("raté")
	var first: Objective = await tr.wait_any([x1, x2])
	check(first == x2, "wait_any() : premier objectif terminé")
	# --- zone à tenir : avancement 0..1
	var h := tr.add("zone", "Tiens la zone", {"type": "hold", "spot": "square", "sec": 10.0})
	h.hold_t = 5.0
	check(absf(h.ratio() - 0.5) < 0.01, "hold : ratio() d'après le temps tenu")
	# --- clear : tout est retiré, les lignes se replient
	tr.clear()
	check(tr.list.is_empty() and h.state == "cleared" and x1.state == "cleared", "clear() : objectifs retirés")
	await frames(130)
	check(lst != null and _rows(lst).is_empty(), "lignes repliées puis retirées")
	# --- pilote automatique
	Campaign.autoplay = true
	var ap := tr.add("auto", "Objectif manuel", {})
	await frames(15)
	check(ap.state == "done", "pilote automatique : objectif terminé seul")
	Campaign.autoplay = false
	Campaign.active = false
	print("RÉSULTAT : OK" if fails.is_empty() else "RÉSULTAT : ÉCHEC (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


func _complete_later(o: Objective) -> void:
	await frames(5)
	o.complete()


func _rows(lst: ObjectiveList) -> Array:
	var out: Array = []
	for n in lst.find_children("*", "", true, false):
		if n is ObjectiveList.Row:
			out.append(n)
	out.sort_custom(func(a, b): return (a as Node).get_index() < (b as Node).get_index())
	return out


func _find(n: Node, cls: String) -> Node:
	for c in n.find_children("*", "", true, false):
		if (c.get_script() as Script) != null and (c.get_script() as Script).get_global_name() == cls:
			return c
	return null
