extends SceneTree
## Barricade : des manifestants portent des barrières en travers de la rue devant la police ;
## la ligne s'arrête devant, des CRS les renversent puis l'avancée reprend.
var frame := 0
var main: Node
var crowd: Crowd
var pol: Police
var ten: Tension
var counts := {}
var max_up := 0
var drops := 0
var carried_before := {}

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main

func _barriers() -> Array:
	return get_nodes_in_group("barriers")

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
	if frame > 30 and ten.value < 0.38:
		ten.set_value(0.4)
	if crowd == null:
		return false
	var builders := 0
	for n in crowd.npcs:
		if n.state == "barricade":
			builders += 1
	var up := 0
	for b in _barriers():
		var bb := b as Barrier
		if bb.barricade and not bb.is_down():
			up += 1
		var was: bool = carried_before.get(bb, false)
		if was and bb.carrier == null and not bb.barricade:
			drops += 1
		carried_before[bb] = bb.carrier != null
	max_up = maxi(max_up, up)
	if frame % 300 == 0:
		var subs := {}
		for n in crowd.npcs:
			if n.state == "barricade":
				subs[n.sub] = subs.get(n.sub, 0) + 1
		var charging := 0
		for c in pol.cops:
			if is_instance_valid(c) and c.target is Barrier and c.state in ["charge", "strike"]:
				charging += 1
		print("[%ds] st=%d line_x=%.1f barricade_x=%.1f debout=%d (max %d) bâtisseurs=%s lâchées=%d crs_sur_barricade=%d" % [frame / 30, pol.stage, pol.line_c.x, crowd.barricade_x, up, max_up, str(subs), drops, charging])
	if frame == 30 * 240:
		quit()
	return false
