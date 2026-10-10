extends SceneTree
## Fuzz du joueur : touches et clics aléatoires, téléportations vers les lieux d'action
var frame := 0
var main: Node
var crowd: Crowd
var pol: Police
var ten: Tension
var rng := RandomNumberGenerator.new()
var acts := ["move_forward", "move_back", "move_left", "move_right", "run", "jump", "kick", "slot_1", "slot_2", "slot_3", "slot_4", "slot_5", "slot_6",
	"interact", "call_crowd", "crouch", "emote_fist", "emote_clap", "emote_hands", "emote_finger", "emote_wheel", "reload_cheat", "aim", "fire", "toggle_view"]
var held := {}
var calls := {}
func _initialize() -> void:
	rng.seed = 11
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
		ten.set_value(0.45)
	if frame % 700 == 0:
		ten.set_value([0.3, 0.6, 0.85, 0.5][rng.randi() % 4])
		# lieux d'action : abribus, poubelle, voiture de police, ligne de police, barrière, foule
		var spots := [Vector3(0, 0.05, -9.0), Vector3(2.5, 0.05, -10.0), Vector3(pol.line_c.x - 8.0, 0.05, pol.line_c.z), Vector3(-9.0, 0.05, -3.0), Vector3(10.0, 0.05, 2.0)]
		for v in pol.vehicles:
			if is_instance_valid(v) and v.kind == "car":
				spots.append(v.global_position + Vector3(-3.0, 0.05, 0.0))
		p.global_position = spots[rng.randi() % spots.size()]
		p.velocity = Vector3.ZERO
	if frame % 8 == 0:
		var a: String = acts[rng.randi() % acts.size()]
		if held.has(a):
			Input.action_release(a)
			held.erase(a)
		else:
			Input.action_press(a)
			held[a] = true
			calls[a] = int(calls.get(a, 0)) + 1
		# les touches de déplacement/visée ne restent pas appuyées indéfiniment
		if held.size() > 6:
			var k: String = held.keys()[0]
			Input.action_release(k)
			held.erase(k)
	if frame % 5 == 0:
		var mm := InputEventMouseMotion.new()
		mm.relative = Vector2(rng.randf_range(-40, 40), rng.randf_range(-12, 12))
		Input.parse_input_event(mm)
	# si on est arrêté, on se remet debout pour continuer à tester
	if p.arrest_phase == "cuffed" and frame % 100 == 0:
		p.arrest_phase = ""
		p._over_sent = false
		p.invuln_t = 8.0
		p.kneel_reset() if p.has_method("kneel_reset") else null
		p.human.kneel = 0.0
	if frame == 21000:
		print("actions : ", calls)
		print("joueur : item ", p.current_item, " phase '", p.arrest_phase, "' pos ", p.global_position.snapped(Vector3(0.1, 0.1, 0.1)))
		quit()
	return false
