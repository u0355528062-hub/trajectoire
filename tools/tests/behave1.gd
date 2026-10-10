extends SceneTree
## Comportements : réponse graduée des CRS au contact (rien / avertissement / poussée / matraque),
## provocations de la foule, attaques spontanées de voitures, prudence de la police sous les obus.
var frame := 0
var main: Node
var crowd: Crowd
var pol: Police
var ten: Tension
var stats := {}
var prev_strike := {}
var prev_warn := {}
var prev_npc := {}
var prev_act := {}
var charges_calm := 0
var charges_fire := 0

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main

func bump(k: String, n := 1) -> void:
	stats[k] = int(stats.get(k, 0)) + n

func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		for c in main.get_children():
			if c is Crowd: crowd = c
			if c is Police: pol = c
			if c is Tension: ten = c
		main.player.global_position = Vector3(-30, 0.05, 12)
	if frame == 30:
		ten.set_value(0.4)
	if frame == 1800:
		ten.set_value(0.75)
	if frame > 30 and frame < 1800 and ten.value < 0.38:
		ten.set_value(0.4)
	if crowd == null:
		return false
	# CRS : transitions vers une frappe / un avertissement
	for c in pol.cops:
		if not is_instance_valid(c):
			continue
		var s: bool = c.state == "strike"
		if s and not prev_strike.get(c, false):
			bump("crs_" + c._strike_kind + ("_ligne" if c._pending_state in ["hold", "advance"] else "_charge"))
		prev_strike[c] = s
		var w: bool = c._warn_t > 0.0
		if w and not prev_warn.get(c, false):
			bump("crs_avertissement")
		prev_warn[c] = w
		if c.act != prev_act.get(c, "") and c.act in ["cop_bang", "cop_kneel", "cop_point", "cop_signal", "cop_help", "cop_gloves", "cop_neck"]:
			bump(c.act)
		prev_act[c] = c.act
		if c.state == "charge" and c.state_t < 0.04:
			if pol.danger > 0.65:
				charges_fire += 1
			else:
				charges_calm += 1
	for n in crowd.npcs:
		var key := n.state + ("/" + n.act if n.state == "react" and n.act in ["finger", "fist"] else "")
		if key != prev_npc.get(n, ""):
			if key in ["react/finger", "react/fist", "carattack", "throwcop", "brawl", "barricade", "feed", "vandal"]:
				bump("pnj_" + key)
		prev_npc[n] = key
	# phase « sous le feu » : obus près de la ligne toutes les 3 s entre 100 et 130 s
	if frame > 3000 and frame < 3900 and frame % 90 == 0:
		call_group("crowd", "on_event", "burst", {"pos": pol.line_c + Vector3(-3.0, 3.0, 0.0)})
	if frame % 600 == 0:
		print("[%ds] st=%d danger=%.2f line_x=%.1f mode=%s %s" % [frame / 30, pol.stage, pol.danger, pol.line_c.x, pol.mode, str(stats)])
	if frame == 30 * 160:
		print("charges hors danger=%d, sous le feu=%d" % [charges_calm, charges_fire])
		quit()
	return false
