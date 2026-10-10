extends SceneTree
## Réponse graduée d'un CRS de ligne au contact du joueur selon son attitude :
## immobile, mains en l'air, doigt d'honneur. Compte avertissements, poussées, coups de matraque.
var frame := 0
var main: Node
var pol: Police
var ten: Tension
var phase := ""
var res := {}
var prev := {}
var cop: Cop
var ACTS := {"neutre": "", "mains": "emote_hands", "doigt": "emote_finger"}

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main

func _process(_d: float) -> bool:
	frame += 1
	var p: Player = main.player
	if frame == 2:
		for c in main.get_children():
			if c is Police: pol = c
			if c is Tension: ten = c
	if frame == 30:
		ten.set_value(0.45)
	if frame > 30 and ten.value < 0.43:
		ten.set_value(0.45)
	# trois phases de 25 s collé à la ligne, une fois celle-ci arrêtée (limite d'avance)
	var t := frame - 1500
	var ph: String = "" if t < 0 else (["neutre", "mains", "doigt"][mini(t / 750, 2)] if t < 2250 else "fin")
	if ph != phase:
		if phase in ACTS and ACTS[phase] != "":
			Input.action_release(ACTS[phase])
		phase = ph
		p.wanted = 0.0
		if phase in ACTS and ACTS[phase] != "":
			Input.action_press(ACTS[phase])
		cop = null
	if phase in ACTS:
		if cop == null or not is_instance_valid(cop):
			var bd := 99.0
			for c in pol.cops:
				if is_instance_valid(c) and c.role == "line" and c.loadout == "shield" and c.state == "hold":
					var d := c.global_position.distance_to(pol.line_c)
					if d < bd:
						bd = d
						cop = c
		if cop:
			if p.arrest_phase == "":
				p.global_position = cop.global_position + cop.line_dir * 1.0
				p.velocity = Vector3.ZERO
			var r: Dictionary = res.get(phase, {})
			var s: bool = cop.state == "strike"
			if s and not prev.get("s", false):
				r[cop._strike_kind] = int(r.get(cop._strike_kind, 0)) + 1
			prev["s"] = s
			var w: bool = cop._warn_t > 0.0
			if w and not prev.get("w", false):
				r["avertissement"] = int(r.get("avertissement", 0)) + 1
			prev["w"] = w
			res[phase] = r
	if phase == "fin":
		print("stade ", pol.stage, " — réponses du CRS : ", res)
		quit()
	return false
