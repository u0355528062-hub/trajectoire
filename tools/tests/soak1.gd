extends SceneTree
## Endurance : 9 minutes simulées avec tension variable, coups, gaz, feux ; relève les anomalies
var frame := 0
var main: Node
var crowd: Crowd
var pol: Police
var ten: Tension
var rng := RandomNumberGenerator.new()
var since := {}        # id -> [state, frame de début]
var report := []
var max_obj := 0
var max_proc := 0.0
func _initialize() -> void:
	rng.seed = 99
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
func _process(_d: float) -> bool:
	frame += 1
	var p: Player = main.player
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if frame == 2:
		for c in main.get_children():
			if c is Crowd: crowd = c
			if c is Police: pol = c
			if c is Tension: ten = c
		p.global_position = Vector3(-34, 0.05, 14)
	# scénario de tension : montées et descentes
	var t := frame / 30.0
	if frame % 450 == 0:
		var targets := [0.1, 0.25, 0.45, 0.7, 0.9, 0.5, 0.3, 0.1, 0.0, 0.2, 0.6, 0.95]
		var k: int = (frame / 450) % targets.size()
		ten.set_value(targets[k])
	# événements aléatoires
	if frame % 120 == 0 and crowd.npcs.size() > 3:
		var n: Npc = crowd.npcs[rng.randi() % crowd.npcs.size()]
		var r := rng.randf()
		if r < 0.25:
			n.on_police_hit(["lbd", "baton", "spray", "shove"][rng.randi() % 4], Vector3(1, 0, 0), null)
		elif r < 0.4:
			get_nodes_in_group("crowd")  # no-op
			crowd.on_event("glass_break", {"pos": n.global_position, "kind": "bus", "pane": null})
		elif r < 0.5:
			n.throw_at(pol.nearest_cop(n.global_position, 60.0)) if pol.nearest_cop(n.global_position, 60.0) else null
	# surveillance des anomalies
	if frame % 30 == 0:
		for n in crowd.npcs:
			if not is_instance_valid(n):
				continue
			var gp := n.global_position
			if is_nan(gp.x) or is_nan(gp.y) or is_nan(gp.z) or absf(gp.y) > 6.0 or absf(gp.x) > 90.0 or absf(gp.z) > 60.0:
				report.append("[%ds] PNJ %d position aberrante %s état %s" % [int(t), n.idx, str(gp), n.state])
			var key := n.get_instance_id()
			var s: Array = since.get(key, ["", frame])
			var cur: String = n.state + "/" + (n.sub if n.state in ["aid", "arrested", "hit", "gassed", "feed", "watch"] else "")
			if s[0] != cur:
				since[key] = [cur, frame]
			elif frame - int(s[1]) > 30 * 70 and n.state not in ["home", "arrested"]:
				report.append("[%ds] PNJ %d bloqué %ds dans %s" % [int(t), n.idx, (frame - int(s[1])) / 30, cur])
				since[key] = [cur, frame]
		for c in pol.cops:
			if is_instance_valid(c):
				var gp2 := c.global_position
				if is_nan(gp2.x) or absf(gp2.y) > 6.0 or absf(gp2.x) > 140.0 or absf(gp2.z) > 80.0:
					report.append("[%ds] policier %d position aberrante %s état %s" % [int(t), c.idx, str(gp2), c.state])
	max_obj = maxi(max_obj, int(Performance.get_monitor(Performance.OBJECT_COUNT)))
	max_proc = maxf(max_proc, Performance.get_monitor(Performance.TIME_PROCESS))
	if frame % 1800 == 0:
		var d := {}
		for n in crowd.npcs:
			d[n.state] = d.get(n.state, 0) + 1
		print("[%3ds] st=%d ten=%.2f npcs=%d cops=%d veh=%d line_x=%.1f | %s | obj=%d mem=%.0fMB" % [int(t), pol.stage, ten.value, crowd.npcs.size(), pol.cops.size(), pol.vehicles.size(), pol.line_c.x, str(d), int(Performance.get_monitor(Performance.OBJECT_COUNT)), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	if frame == 16200:
		print("max objets ", max_obj, " | pic de TIME_PROCESS ", snappedf(max_proc * 1000.0, 0.1), " ms")
		print("anomalies: ", report.size())
		for r in report.slice(0, 40):
			print("  ", r)
		quit()
	return false
