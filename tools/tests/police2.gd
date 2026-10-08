extends SceneTree
## Police de bout en bout : paliers de tension, gaz, charges, LBD, interpellations de PNJ,
## arrestation du joueur -> écran de fin -> redémarrage. Compte les événements diffusés.
var frame := 0
var main: Node
var crowd: Crowd
var pol: Police
var ten: Tension
var counts := {}
var listener: Node
var arrest_seen := false
var phase_log := []
var restarted := false

class Spy extends Node:
	var counts: Dictionary
	func _ready() -> void:
		add_to_group("crowd")
	func on_event(type: String, _d: Dictionary) -> void:
		counts[type] = counts.get(type, 0) + 1

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var s := Spy.new()
	s.counts = counts
	root.add_child(s)

func cop_states() -> String:
	var d := {}
	for c in pol.cops:
		if is_instance_valid(c):
			d[c.state] = d.get(c.state, 0) + 1
	return str(d)

func npc_states() -> String:
	var d := {}
	for n in crowd.npcs:
		d[n.state] = d.get(n.state, 0) + 1
	return str(d)

func evs() -> String:
	var keys := ["police_gas", "gas_land", "police_lbd", "police_baton", "civil_hit", "grab", "arrest", "boarded", "cop_hit", "cop_down", "player_arrest"]
	var out := {}
	for k in keys:
		if counts.has(k):
			out[k] = counts[k]
	return str(out)

func _process(_d: float) -> bool:
	frame += 1
	var p: Player = main.player
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if frame == 2:
		for c in main.get_children():
			if c is Crowd: crowd = c
			if c is Police: pol = c
			if c is Tension: ten = c
		p.global_position = Vector3(36, 0.05, -3)
		p.arrested.connect(func(): arrest_seen = true)
	match frame:
		30:
			ten.set_value(0.7)
			p.wanted = 0.9
			print("stage ", ten.stage, " wanted ", p.wanted)
		300, 600, 900, 1200, 1500, 1800, 2100, 2400, 2700:
			print("[%ds] st=%d ten=%.2f cops=%d veh=%d line_x=%.1f %s | arrests %d | clouds %d | player phase='%s' wanted %.2f pos %s" % [frame / 30, pol.stage, ten.value, pol.cops.size(), pol.vehicles.size(), pol.line_c.x, cop_states(), pol.arrested_count, get_nodes_in_group("gas_clouds").size(), p.arrest_phase, p.wanted, str(p.global_position.snapped(Vector3(0.1, 0.1, 0.1)))])
			print("   events ", evs())
			print("   npcs ", npc_states())
		3000:
			print("arrest_seen ", arrest_seen, " phase '", p.arrest_phase, "'")
			ten.set_value(0.95)
		3600:
			print("[120s] st=%d ten=%.2f cops=%d veh=%d %s | arrests %d" % [pol.stage, ten.value, pol.cops.size(), pol.vehicles.size(), cop_states(), pol.arrested_count])
			print("   events ", evs())
			print("   npcs ", npc_states())
			print("arrest_seen ", arrest_seen, " phase '", p.arrest_phase, "'")
			quit()
	if arrest_seen and not restarted:
		restarted = true
		print("[frame %d] arrestation -> game over, rechargement de la scène" % frame)
	return false
