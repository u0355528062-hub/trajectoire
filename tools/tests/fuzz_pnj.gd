extends SceneTree
## Fuzz : appels aléatoires des API de réaction des PNJ pendant 8 minutes simulées
var frame := 0
var main: Node
var crowd: Crowd
var pol: Police
var ten: Tension
var rng := RandomNumberGenerator.new()
var calls := {}
func _initialize() -> void:
	rng.seed = 7
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
func pick_npc() -> Npc:
	if crowd.npcs.is_empty():
		return null
	return crowd.npcs[rng.randi() % crowd.npcs.size()]
func note(k: String) -> void:
	calls[k] = int(calls.get(k, 0)) + 1
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
		ten.set_value(0.5)
	if frame % 450 == 0:
		ten.set_value([0.2, 0.5, 0.8, 0.95, 0.3][rng.randi() % 5])
	if frame % 15 == 0 and frame > 10:
		var n := pick_npc()
		if n == null:
			return false
		var from := n.global_position + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
		var cop: Cop = pol.nearest_cop(n.global_position, 80.0)
		match rng.randi() % 24:
			0:
				n.panic(from, rng.randf_range(0.3, 1.0)); note("panic")
			1:
				n.dodge(from, Vector3(1, 0, 0)); note("dodge")
			2:
				n.startle(from); note("startle")
			3:
				n.on_gas(rng.randf_range(0.1, 1.0), from); note("on_gas")
			4:
				n.on_police_hit(["lbd", "baton", "spray", "shove"][rng.randi() % 4], Vector3(1, 0, 0), cop); note("on_police_hit")
			5:
				if cop != null:
					n.throw_at(cop); note("throw_at")
			6:
				if cop != null:
					n.start_brawl(cop); note("start_brawl")
			7:
				if cop != null:
					n.rescue(cop); note("rescue")
			8:
				n.avoid_gas(from); note("avoid_gas")
			9:
				n.scare(rng.randf()); note("scare")
			10:
				n.enrage(rng.randf()); note("enrage")
			11:
				n.react(["cheer", "fist", "clap", "head", "film", "point", "cover"][rng.randi() % 7], 2.0, from, {"voice": "ouais"}); note("react")
			12:
				crowd.on_event("police_charge", {"pos": from}); note("ev_charge")
			13:
				crowd.on_event("police_gas", {"pos": from, "from": from}); note("ev_gas")
			14:
				crowd.on_event("burst", {"pos": from}); note("ev_burst")
			15:
				crowd.on_event("petard_boom", {"pos": from, "size": rng.randi_range(1, 2)}); note("ev_petard")
			16:
				crowd.on_event("police_stage", {"stage": rng.randi_range(1, 4), "pos": from}); note("ev_stage")
			17:
				crowd.on_event("police_retreat", {"pos": from}); note("ev_retreat")
			18:
				n.on_grabbed(cop) if cop != null else null; note("on_grabbed")
			19:
				if n.state == "arrested":
					n.on_cuffed(cop); note("on_cuffed")
			20:
				n.go_home(); note("go_home")
			21:
				n.on_aid(null); note("on_aid")
			22:
				crowd.on_event("glass_break", {"pos": from, "kind": "bus", "pane": null}); note("ev_glass")
			23:
				p.apply_gas(rng.randf()); p.apply_pepper(rng.randf()); note("player_gas")
	if frame == 13500:
		print("appels : ", calls)
		var d := {}
		for n in crowd.npcs:
			d[n.state] = d.get(n.state, 0) + 1
		print("états finaux : ", d, " npcs=", crowd.npcs.size())
		quit()
	return false
