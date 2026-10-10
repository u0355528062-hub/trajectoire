extends SceneTree
## Vague de foule : l'appel (G) près de l'abribus avec beaucoup de monde -> les manifestants secouent l'abribus
## jusqu'à l'effondrer. On force la vague (excitation au maximum) et on compte.
var frame := 0
var main: Node
var crowd: Crowd
var collapsed_at := -1
func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
func _process(_d: float) -> bool:
	frame += 1
	var p: Player = main.player
	if frame == 2:
		for c in main.get_children():
			if c is Crowd: crowd = c
	if frame == 200:
		p.global_position = crowd.bus.global_position + Vector3(0, 0.05, 4.0)
		crowd.excitement = 1.0
	if frame == 220:
		var tries := 0
		while not crowd.surge and tries < 20:
			crowd.on_event("call", {"pos": p.global_position})
			tries += 1
		print("vague=", crowd.surge, " après ", tries, " appel(s)")
	if frame > 220 and frame % 90 == 0 and collapsed_at < 0:
		var sh := 0
		for n in crowd.npcs:
			if n.state == "rally" and n.sub == "shake":
				sh += 1
		print("[%ds] secoueurs=%d secousse=%.1f effondré=%s" % [frame / 30, sh, crowd.bus._shake, crowd.bus.collapsed])
	if crowd and crowd.bus.collapsed and collapsed_at < 0:
		collapsed_at = frame
		print("EFFONDRÉ à %ds" % (frame / 30))
	if frame == 30 * 50 or (collapsed_at > 0 and frame > collapsed_at + 120):
		quit()
	return false
