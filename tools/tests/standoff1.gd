extends SceneTree
## Face-à-face : formation de la foule selon le stade de police
var frame := 0
var main: Node
var crowd: Crowd
var pol: Police
var ten: Tension

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main

func report(tag: String) -> void:
	var so := crowd.standoff
	var subs := {}
	var rows := {}
	var dists := []
	var lag := []
	var rear_n := 0
	var sit_n := 0
	for n in crowd.npcs:
		if n.role in ["march", "bloc"]:
			subs[n._home_sub if n.state == "home" else n.state] = subs.get(n._home_sub if n.state == "home" else n.state, 0) + 1
			if so.slots.has(n):
				rows[so.row_of(n)] = rows.get(so.row_of(n), 0) + 1
				var sp: Vector3 = so.slots[n]
				lag.append(snappedf(Vector2(sp.x - n.global_position.x, sp.z - n.global_position.z).length(), 0.1))
			dists.append(snappedf(pol.line_c.x - n.global_position.x, 0.1))
			if n.stance == "sit":
				sit_n += 1
		if so.is_rear(n):
			rear_n += 1
	print("[%s] st=%d line_x=%.1f active=%s gap=%.1f rows=%s rear=%d sit=%d" % [tag, pol.stage, pol.line_c.x, so.active, so.gap, str(rows), rear_n, sit_n])
	print("   subs ", subs)
	print("   dist_to_line ", dists)
	print("   slot_lag ", lag)
	var moods := []
	for n in crowd.npcs:
		if n.role in ["march", "bloc"]:
			moods.append("%d:%.1f/%.1f" % [n.idx, n.fear, n.anger])
	print("   fear/anger ", " ".join(moods))

func _process(_d: float) -> bool:
	frame += 1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if frame == 2:
		for c in main.get_children():
			if c is Crowd: crowd = c
			if c is Police: pol = c
			if c is Tension: ten = c
		main.player.global_position = Vector3(-30, 0.05, 12)
	match frame:
		30: report("start")
		60: ten.set_value(0.4)
		300: report("10s stage2")
		900: report("30s")
		1500: report("50s")
		1560: ten.set_value(0.7)
		2100: report("stage3 +18s")
		2700: report("stage3 +38s")
		2760: ten.set_value(0.0)
		4200: report("calm +48s")
		4300: quit()
	return false
