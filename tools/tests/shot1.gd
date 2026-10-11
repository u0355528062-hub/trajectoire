extends SceneTree
## Capture d'écran rapide du jeu : xvfb-run -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 -s tools/tests/shot1.gd -- <fichier.png> [frames]
var frame := 0
var out := "user://shot.png"
var wait := 90

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: wait = int(a[1])
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main

func _process(_d: float) -> bool:
	frame += 1
	if frame == wait:
		var img := root.get_texture().get_image()
		img.save_png(out)
		print("SHOT ", out)
		return true
	return false
