extends SceneTree
## Tags à la bombe : des manifestants écrivent des slogans (chaussée, panneaux, fourgons) ; nombre limité.
var frame := 0
var main: Node
var crowd: Crowd
var ten: Tension
var started := 0
var prev := {}
func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		for c in main.get_children():
			if c is Crowd: crowd = c
			if c is Tension: ten = c
	if frame == 900:
		ten.set_value(0.4)
	if crowd:
		crowd._tag_cd = minf(crowd._tag_cd, 3.0)
		for n in crowd.npcs:
			if n.state == "tag" and prev.get(n, "") != "tag":
				started += 1
			prev[n] = n.state
	if frame % 900 == 0:
		var texts := []
		for l in crowd._tags:
			if is_instance_valid(l):
				texts.append(l.text + "@" + str(l.global_position.snapped(Vector3(0.1, 0.1, 0.1))))
		print("[%ds] tags commencés=%d gardés=%d %s" % [frame / 30, started, crowd._tags.size(), str(texts.slice(0, 4))])
	if frame == 30 * 120:
		quit()
	return false
