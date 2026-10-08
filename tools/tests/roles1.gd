extends SceneTree
## Médic, reporter, entraide : tests logiques
var frame := 0
var main: Node
var crowd: Crowd
var pol: Police
var ten: Tension
var medic: Npc
var press: Npc
var victim: Npc
func _initialize() -> void:
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
		for n in crowd.npcs:
			if n.role == "medic": medic = n
			if n.role == "press": press = n
		print("npcs ", crowd.npcs.size(), " medic ", medic != null, " press ", press != null)
		victim = crowd.npcs[5]
	if frame == 120:
		print("[4s] medic ", medic.state, "/", medic._home_sub, " pos ", medic.global_position.snapped(Vector3(0.1, 0.1, 0.1)), " | press ", press.state, "/", press._home_sub, " kind ", press.data.get("press_kind", "-"), " pos ", press.global_position.snapped(Vector3(0.1, 0.1, 0.1)))
		victim.on_police_hit("lbd", Vector3(1, 0, 0), null)
		print("victim hit: ", victim.state, "/", victim.sub, " at ", victim.global_position.snapped(Vector3(0.1, 0.1, 0.1)))
	if frame > 120 and frame <= 420 and frame % 30 == 0:
		print("[%.1fs] victim %s/%s fall %.2f | medic %s/%s sub=%s | pairs %d | medic dist %.1f" % [frame / 30.0, victim.state, victim.sub, victim.human.fall, medic.state, medic._home_sub, medic.sub, crowd.aid_pairs.size(), medic.global_position.distance_to(victim.global_position)])
	if frame == 450:
		p.pepper_level = 1.0
		p.global_position = Vector3(0, 0.05, 0)
		print("player sprayed; medic dist ", medic.global_position.distance_to(p.global_position))
	if frame > 450 and frame <= 750 and frame % 30 == 0:
		print("[%.1fs] player pepper %.2f | medic %s/%s sub=%s dist %.1f" % [frame / 30.0, p.pepper_level, medic.state, medic._home_sub, medic.sub, medic.global_position.distance_to(p.global_position)])
	if frame == 780:
		ten.set_value(0.4)
		print("stage 2 for press test")
	if frame > 780 and frame % 150 == 0 and frame < 2100:
		print("[%.1fs] press %s/%s kind=%s spot=%s pos=%s act=%s" % [frame / 30.0, press.state, press._home_sub, press.data.get("press_kind", "-"), str(press.data.get("press_spot", "-")), str(press.global_position.snapped(Vector3(0.1, 0.1, 0.1))), press.act])
	if frame == 2200:
		quit()
	return false
