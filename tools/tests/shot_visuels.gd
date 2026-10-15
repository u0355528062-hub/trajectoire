extends SceneTree
## Captures du module Visuels (rendu) : plusieurs vues par combinaison moment × météo, en une seule exécution.
##   tools/dev/gd --render --path . --resolution 1280x720 -s tools/tests/shot_visuels.gd -- <dossier> nuit:pluie aube:sec ...
## Vues : rue (le long du boulevard), facades (commerces nord), haut (vue large avec le ciel), sol (chaussée),
## perso (visage d'un personnage, pour juger la teinte de la peau).
var out := "/tmp/vis"
var cam: Camera3D


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("captures ignorées : pas de rendu (lancer avec --render)")
		quit()
		return
	var a := OS.get_cmdline_user_args()
	var combos: Array[String] = []
	for i in a.size():
		if i == 0:
			out = a[0]
		else:
			combos.append(a[i])
	if combos.is_empty():
		combos.append("crepuscule:sec")
	_run(combos)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func view(from: Vector3, to: Vector3, fov := 60.0) -> void:
	cam.fov = fov
	cam.global_position = from
	cam.look_at(to)
	cam.current = true


func shot(tag: String, name: String, wait := 6) -> void:
	await frames(wait)
	root.get_texture().get_image().save_png("%s/%s_%s.png" % [out, tag, name])
	print("SHOT ", tag, " ", name)


func _run(combos: Array[String]) -> void:
	for combo in combos:
		var parts := combo.split(":")
		WorldSetup.sandbox = {"tod": parts[0], "weather": parts[1] if parts.size() > 1 else "sec"}
		Settings.set_quality(int(parts[2].substr(1)) if parts.size() > 2 else 2)   # « nuit:pluie:q0 » : qualité basse
		var tag := combo.replace(":", "_")
		var main: Node = load("res://main.tscn").instantiate()
		root.add_child(main)
		current_scene = main
		await frames(12)
		for c in main.get_children():
			if c is CanvasLayer:
				(c as CanvasLayer).visible = false
		cam = Camera3D.new()
		cam.far = 600.0
		main.add_child(cam)
		view(Vector3(-30, 1.7, -2.0), Vector3(40, 3.5, -7.4))
		await shot(tag, "rue", 14)
		view(Vector3(4, 1.7, 3.0), Vector3(10, 3.2, 17.5))
		await shot(tag, "facades")
		view(Vector3(-46, 9.0, -22.0), Vector3(10, 6.0, 6.0), 70.0)
		await shot(tag, "haut")
		view(Vector3(2, 1.3, -2.5), Vector3(-14, 0.0, -8.0))
		await shot(tag, "sol")
		var p := main.get("player") as Node3D
		if p != null:
			var at := p.global_position + Vector3(0, 1.6, 0)
			view(at + Vector3(0.9, 0.05, -1.3), at - Vector3(0, 0.08, 0), 40.0)
			await shot(tag, "perso")
		main.queue_free()
		await frames(4)
	quit()
