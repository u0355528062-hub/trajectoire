extends SceneTree
## Quartier (Streetscape) : construction sans erreur, inventaire des objets (arbres, mobilier, feux), cycle des feux,
## puis un tour complet du cortège : les manifestants qui défilent ne doivent rester bloqués nulle part
## (arbres, bancs, potelets, square, métro...). Le cortège est maintenu en marche et la tension à zéro.
var frame := 0
var main: Node
var crowd: Crowd
var ten: Tension
var ss: Streetscape
var start_s := 0.0
var travelled := 0.0
var last_s := 0.0
var lag_max := 0.0
var lag_acc := 0.0
var lag_n := 0
var stuck := {}            # pnj -> secondes passées loin de sa place
var stuck_max := 0.0
var stuck_where := Vector3.ZERO
var light_states := {}
var done := false


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main


func _process(delta: float) -> bool:
	frame += 1
	if frame == 2:
		for c in main.get_children():
			if c is Crowd: crowd = c
			if c is Tension: ten = c
			if c is Streetscape: ss = c
		if ss == null:
			print("ÉCHEC : pas de Streetscape dans la scène")
			quit()
			return false
		var keys := ss.placed.keys()
		keys.sort()
		var parts: Array[String] = []
		for k in keys:
			parts.append("%s=%d" % [k, ss.placed[k]])
		print("quartier : ", ", ".join(parts))
		print("arbres (groupe trees) : ", get_nodes_in_group("trees").size(), " | obstacles de la foule : ", crowd.obstacles.size())
		var kick := 0
		for n in get_nodes_in_group("kickable"):
			if ss.is_ancestor_of(n):
				kick += 1
		print("objets frappables du quartier : ", kick)
		start_s = crowd.cortege_s
		last_s = start_s
		main.player.global_position = Vector3(-60, 0.05, 15)
	if frame < 3:
		return false
	# feux : on relève les états vus
	for l in ss.traffic:
		var t := l as TrafficLight
		light_states["car%d" % t.car_state] = true
		light_states["ped%s" % str(t.ped_green)] = true
	# cortège toujours en marche, pas de tension
	crowd._cortege_timer = 0.0
	crowd._cortege_moving = true
	if frame % 60 == 0:
		ten.set_value(0.0)
	var ds := fposmod(crowd.cortege_s - last_s, crowd._route_total)
	travelled += ds
	last_s = crowd.cortege_s
	if frame > 150:
		for n in crowd.npcs:
			if n.role != "march" or n.state != "home":
				stuck.erase(n)
				continue
			var tgt: Vector3 = crowd.march_target(n)[0]
			var d := Vector2(n.global_position.x - tgt.x, n.global_position.z - tgt.z).length()
			lag_max = maxf(lag_max, d)
			lag_acc += d
			lag_n += 1
			if d > 3.0:
				stuck[n] = float(stuck.get(n, 0.0)) + delta
				if stuck[n] > stuck_max:
					stuck_max = stuck[n]
					stuck_where = n.global_position
			else:
				stuck[n] = 0.0
	if frame % 900 == 0:
		print("[%ds] parcours %.0f / %.0f m, retard moyen %.2f m, max %.2f m, blocage max %.1f s" % [frame / 30, travelled, crowd._route_total, lag_acc / maxf(lag_n, 1), lag_max, stuck_max])
	if not done and travelled >= crowd._route_total + 2.0:
		done = true
		print("TOUR COMPLET en %d s : retard moyen %.2f m, retard max %.2f m, blocage max %.1f s (vers %s)" % [frame / 30, lag_acc / maxf(lag_n, 1), lag_max, stuck_max, stuck_where])
		print("feux vus : ", light_states.keys())
		var ok := stuck_max < 12.0 and light_states.has("car0") and light_states.has("car1") and light_states.has("car2") and light_states.has("pedtrue")
		print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
		quit()
	if frame > 30 * 900:
		print("ÉCHEC : le cortège n'a pas fini son tour (%.0f / %.0f m)" % [travelled, crowd._route_total])
		quit()
	return false
