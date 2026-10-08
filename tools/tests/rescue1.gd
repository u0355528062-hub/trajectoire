extends SceneTree
var frame := 0
var main: Node
var crowd: Crowd
var pol: Police
var ten: Tension
var freed := false
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
		ten.set_value(0.45)
	if frame == 900:
		# 30 s plus tard : la foule est en place, le joueur se fait remarquer près de la ligne
		p.global_position = Vector3(pol.line_c.x - 7.0, 0.05, pol.line_c.z)
		p.wanted = 1.0
		print("player at ", p.global_position, " line ", pol.line_c)
	if frame > 900 and frame % 30 == 0 and frame < 2400:
		var resc := 0
		for n in crowd.npcs:
			if n.state == "rescue":
				resc += 1
		print("[%ds] phase='%s' struggle=%.2f rescuers=%d invuln=%.1f pos=%s" % [(frame - 900) / 30, p.arrest_phase, p.struggle, resc, p.invuln_t, str(p.global_position.snapped(Vector3(0.1,0.1,0.1)))])
		if p.arrest_phase == "grabbed":
			Input.action_press("jump") if frame % 60 == 0 else Input.action_release("jump")
	if frame == 2400:
		quit()
	return false
