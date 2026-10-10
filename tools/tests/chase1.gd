extends SceneTree
## Poursuite du joueur : les CRS sprintent, ne lâchent pas au bout de quelques secondes, frappent quand ils
## rattrapent. Le joueur court en ligne droite (sans être blessé il peut s'échapper, blessé il est rattrapé).
var frame := 0
var main: Node
var pol: Police
var ten: Tension
var maxv := 0.0
var strikes := 0
var hits := 0
var prev := {}
var chasers_at_10s := 0
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
		p.hurt.connect(func(_k): hits += 1)
	if frame == 30:
		ten.set_value(0.45)
	if frame == 600:
		p.global_position = pol.line_c + pol.line_dir * 5.0
		p.wanted = 0.9
		for c in pol._free_cops(["shield"], ["line"]).slice(0, 2):
			c.charge(p, 6.0)
	if frame > 600 and frame < 1500:
		# fuite : on court vers -X (loin de la ligne)
		Input.action_press("move_forward")
		Input.action_press("run")
		p._yaw = PI * 0.5
	if frame > 600:
		var n := 0
		for c in pol.cops:
			if is_instance_valid(c) and c.state in ["charge", "strike"] and c.target == p:
				n += 1
				maxv = maxf(maxv, Vector2(c.vel.x, c.vel.z).length())
				var s: bool = c.state == "strike"
				if s and not prev.get(c, false):
					strikes += 1
				prev[c] = s
		if frame == 900:
			chasers_at_10s = n
	if frame == 1500:
		print("vitesse max CRS=%.2f m/s, poursuivants après 10 s=%d, coups tentés=%d, coups reçus=%d, joueur à %.1f m de la ligne" % [maxv, chasers_at_10s, strikes, hits, p.global_position.distance_to(pol.line_c)])
		quit()
	return false
