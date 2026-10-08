extends SceneTree
## Coût des scripts (headless) : moyenne par image selon la situation
var frame := 0
var main: Node
var ten: Tension
var acc := {}
var cnt := {}
var phase := "calm"
func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
func _process(_d: float) -> bool:
	frame += 1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if frame == 2:
		for c in main.get_children():
			if c is Tension: ten = c
		main.player.global_position = Vector3(-34, 0.05, 14)
	if frame == 600:
		phase = "tendu"
		ten.set_value(0.3)
	if frame == 1500:
		phase = "emeute"
		ten.set_value(0.9)
	if frame > 120:
		var pp := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		var pr := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		acc[phase] = Vector2(acc.get(phase, Vector2.ZERO).x + pp, acc.get(phase, Vector2.ZERO).y + pr)
		cnt[phase] = int(cnt.get(phase, 0)) + 1
	if frame == 3000:
		for k in acc:
			print("%s : physique %.2f ms | process %.2f ms (moyenne sur %d images)" % [k, acc[k].x / cnt[k], acc[k].y / cnt[k], cnt[k]])
		quit()
	return false
