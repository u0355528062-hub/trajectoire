extends SceneTree
## Captures du kit du joueur (rendu) : tools/dev/gd --render --path . --resolution 1280x720 -s tools/tests/shot_kit.gd -- <préfixe>
## Vues : téléphone levé, tract tendu, collage sur la colonne Morris, affiche posée, mégaphone, tag, barre d'outils.
var main: Node
var p: Player
var cam: Camera3D
var prefix := "/tmp/kit"


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("captures ignorées : pas de rendu (lancer avec --render)")
		quit()
		return
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		prefix = a[0]
	WorldSetup.sandbox = {"tools": WorldSetup.TOOLS_ORIGINAL + WorldSetup.TOOLS_CAMPAIGN, "tod": "aprem"}
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	_run()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func stand(pos: Vector3, look: Vector3) -> void:
	p.place_at(pos + Vector3(0, 0.05, 0))
	var d := look - pos
	p._yaw = atan2(-d.x, -d.z)
	p._pitch = 0.0
	p.human.rotation.y = p._yaw
	await frames(4)


## Caméra de face (ou de trois quarts) sur le joueur
func view(side: float, dist := 2.3, h := 1.45, at := Vector3.ZERO) -> void:
	var f := Basis(Vector3.UP, p._yaw) * Vector3(0, 0, -1)
	var r := Basis(Vector3.UP, p._yaw) * Vector3(1, 0, 0)
	var tgt := p.global_position + Vector3(0, 1.25, 0) if at == Vector3.ZERO else at
	cam.global_position = p.global_position + f * dist * cos(side) + r * dist * sin(side) + Vector3(0, h, 0)
	cam.look_at(tgt)
	cam.current = true


func shot(name: String) -> void:
	await frames(3)
	var img := root.get_texture().get_image()
	img.save_png("%s_%s.png" % [prefix, name])
	print("SHOT ", name)


func _run() -> void:
	await frames(30)
	p = main.player
	cam = Camera3D.new()
	cam.fov = 50.0
	main.add_child(cam)
	var mo := Quartier.MORRIS
	# téléphone levé (on filme)
	await stand(mo + Vector3(2.5, 0, -2.5), mo + Vector3(8, 1.5, -6))
	p.select_item(7)
	await frames(25)
	p.phone.start_film()
	await frames(20)
	view(0.6)
	await shot("phone")
	p.phone.stop_film()
	# collage sur la colonne Morris (en cours), puis affiche posée
	p.select_item(9)
	await stand(mo + Vector3(0, 0, -1.3), mo + Vector3(0, 1.6, 0))
	await frames(25)
	p.posters.use()
	await frames(36)
	view(1.2, 2.4, 1.5)
	await shot("poster_pose")
	await frames(45)
	p.select_item(0)
	await stand(mo + Vector3(0.6, 0, -2.6), mo + Vector3(0, 1.6, 0))
	view(0.0, 1.3, 1.6, mo + Vector3(0, 1.6, -0.6))
	cam.global_position = mo + Vector3(0.3, 1.65, -1.6)
	cam.look_at(mo + Vector3(0, 1.6, -0.6))
	await frames(10)
	await shot("poster_morris")
	# tag sur un mur
	var lim := Quartier.z_limits(6.0)
	var wall := Vector3(6.0, 0, lim.y - 0.9)
	p.select_item(11)
	await stand(wall, wall + Vector3(0, 1.4, 3))
	await frames(25)
	p.spray.paint_now()
	await frames(70)
	cam.global_position = wall + Vector3(-1.8, 1.6, -1.6)
	cam.look_at(wall + Vector3(0, 1.4, 0.8))
	cam.current = true
	await shot("spray")
	await frames(40)
	# mégaphone
	p.select_item(10)
	await stand(wall + Vector3(3, 0, -4), wall + Vector3(3, 1.5, -10))
	await frames(25)
	p.megaphone.use()
	await frames(20)
	view(0.5)
	await shot("megaphone")
	await frames(90)
	# tract tendu à un passant
	p.select_item(8)
	var civ: Civilians = null
	for c in main.get_children():
		if c is Civilians:
			civ = c
	var sp := Quartier.spot("boulangerie") + Vector3(0, 0, -2.0)
	await stand(sp, sp + Vector3(0, 0, 1))
	await frames(25)
	for w in civ.walkers:
		if is_instance_valid(w) and not w.done and w.lead == null:
			w.global_position = sp + Vector3(0, 0, 1.15)
			w.stop_move()
			await frames(4)
			p.tracts.offer(w)
			break
	await frames(12)
	view(1.4, 2.6)
	await shot("tract")
	# barre d'outils (vue du joueur)
	await frames(40)
	p.select_item(7)
	p.camera.current = true
	await frames(30)
	await shot("hud")
	quit()
