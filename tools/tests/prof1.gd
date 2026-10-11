extends SceneTree
## Profilage détaillé (headless) : coût par image de la logique de foule, de la réflexion, du déplacement et de
## l'animation des personnages, au calme puis en émeute. Nombre de personnages et d'animations par image.
var frame := 0
var main: Node
var ten: Tension
var crowd: Crowd
var phase := "calme"
var snap := {}
var t_phys := 0.0
var n_fr := 0
func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
func _report() -> void:
	var line := "%s : %d persos, physique %.2f ms/img |" % [phase, crowd.actors.size(), t_phys / n_fr]
	for k in ["crowd_logic", "think", "move", "anim", "a_tronc", "a_jambes", "a_mains", "a_bras", "props", "police", "joueur"]:
		line += " %s %.2f ms" % [k, float(Actor.prof_acc.get(k, 0)) / 1000.0 / n_fr]
	line += " | animations/img %.1f" % (float(Actor.prof_acc.get("anim_n", 0)) / n_fr)
	var rb := 0
	var stat := 0
	for nd in root.find_children("*", "RigidBody3D", true, false):
		rb += 1
		if (nd as RigidBody3D).sleeping:
			stat += 1
	line += " | corps rigides %d (%d endormis) | boutiques ouvertes %d" % [rb, stat, get_nodes_in_group("shops").filter(func(x): return x.is_open()).size()]
	line += " | particules %d" % root.find_children("*", "GPUParticles3D", true, false).size()
	print(line)
	Actor.prof_acc.clear()
	t_phys = 0.0
	n_fr = 0
func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		for c in main.get_children():
			if c is Tension: ten = c
			if c is Crowd: crowd = c
		main.player.global_position = Vector3(-6, 0.05, 2)
	if frame == 200:
		Actor.prof = true
		Actor.prof_acc.clear()
	if frame > 200:
		t_phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		n_fr += 1
	if frame == 800:
		_report()
		phase = "émeute"
		ten.set_value(0.9)
	if frame == 1700:
		_report()
		quit()
	return false
