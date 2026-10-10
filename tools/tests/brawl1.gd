extends SceneTree
var frame := 0
var main: Node
var crowd: Crowd
var pol: Police
var ten: Tension
var maxbrawl := 0
var seen := {}
func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
func _process(_d: float) -> bool:
	frame += 1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if frame == 2:
		for c in main.get_children():
			if c is Crowd: crowd = c
			if c is Police: pol = c
			if c is Tension: ten = c
		main.player.global_position = Vector3(-34, 0.05, 14)
		ten.set_value(0.9)
	if frame % 15 == 0 and crowd != null:
		for n in crowd.npcs:
			if n.bold > 0.55:
				n.anger = maxf(n.anger, 0.8)
				n.fear = minf(n.fear, 0.2)
	if crowd == null:
		return false
	var b := 0
	for n in crowd.npcs:
		if n.state == "brawl":
			b += 1
			seen[n.idx] = int(seen.get(n.idx, 0)) + 1
	maxbrawl = maxi(maxbrawl, b)
	if frame % 300 == 0:
		var cs := {}
		for c in pol.cops:
			cs[c.state] = cs.get(c.state, 0) + 1
		print("[%ds] st=%d brawl=%d (max %d) distinct=%d cops=%s line=%.1f" % [frame / 30, pol.stage, b, maxbrawl, seen.size(), str(cs), pol.line_c.x])
	if frame == 3600:
		quit()
	return false
