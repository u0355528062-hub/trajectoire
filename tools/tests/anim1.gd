extends SceneTree
## Nouvelles actions des manifestants : danse, tambour sur poubelle, chaîne humaine, doigt d'honneur au premier
## rang, réconfort, renvoi des grenades lacrymogènes. Compte leurs apparitions.
var frame := 0
var main: Node
var crowd: Crowd
var pol: Police
var ten: Tension
var stats := {}
var prev := {}

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main

func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		for c in main.get_children():
			if c is Crowd: crowd = c
			if c is Police: pol = c
			if c is Tension: ten = c
		main.player.global_position = Vector3(-30, 0.05, 12)
	if frame == 1500:
		ten.set_value(0.4)
	if frame == 3000:
		ten.set_value(0.75)
	if crowd == null:
		return false
	for n in crowd.npcs:
		var key: String = n.state + ":" + n.act
		if key != prev.get(n, ""):
			for a in ["dance", "drum", "link", "finger", "comfort"]:
				if n.act == a:
					stats[a] = int(stats.get(a, 0)) + 1
			if n.state == "throwback" and not String(prev.get(n, "")).begins_with("throwback"):
				stats["renvoi_grenade"] = int(stats.get("renvoi_grenade", 0)) + 1
		prev[n] = key
	if frame % 900 == 0:
		print("[%ds] st=%d %s" % [frame / 30, pol.stage, str(stats)])
	if frame == 30 * 170:
		quit()
	return false
