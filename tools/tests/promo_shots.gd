extends SceneTree
## Photos promotionnelles (sans interface) : cortège, ligne de CRS, feu de poubelle, gaz, portrait, vue large.
## Format vertical (TikTok) :
##   xvfb-run -a -s "-screen 0 1080x1920x24" godot --path . --fixed-fps 30 --resolution 1080x1920 -s tools/tests/promo_shots.gd -- <dossier>
## Le rendu est coupé entre deux photos pour aller vite.
var frame := 0
var main: Node
var crowd: Crowd
var pol: Police
var ten: Tension
var cam: Camera3D
var out_dir := "user://promo"
var _pending := []     # [frame, nom]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	RenderingServer.render_loop_enabled = false


func _hide_ui() -> void:
	for n in main.get_children():
		if n is CanvasLayer:
			(n as CanvasLayer).visible = false
	for n in root.get_children():
		if n is CanvasLayer:
			(n as CanvasLayer).visible = false


## Place la caméra : position, cible, focale, mise au point (0 = sans flou)
func _cam(pos: Vector3, look: Vector3, fov := 50.0, focus := 0.0) -> void:
	cam.global_position = pos
	cam.look_at(look)
	cam.fov = fov
	var at := CameraAttributesPractical.new()
	if focus > 0.0:
		at.dof_blur_far_enabled = true
		at.dof_blur_far_distance = focus + 3.0
		at.dof_blur_far_transition = 12.0
		at.dof_blur_amount = 0.12
	cam.attributes = at
	cam.current = true


func _shoot(name: String) -> void:
	_hide_ui()
	RenderingServer.render_loop_enabled = true
	_pending.append([frame + 4, name])


func _flare_npc() -> Npc:
	for n in crowd.npcs:
		if is_instance_valid(n) and n.flare != null and is_instance_valid(n.flare):
			return n
	return null


func _process(_d: float) -> bool:
	frame += 1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if frame == 2:
		for c in main.get_children():
			if c is Crowd: crowd = c
			if c is Police: pol = c
			if c is Tension: ten = c
		var p: Player = main.player
		p.global_position = Vector3(-60, 0.05, 15)       # le joueur hors champ
		cam = Camera3D.new()
		cam.far = 3000.0
		root.add_child(cam)
	# 1. le cortège, banderole en tête, au ras du sol
	if frame == 300:
		var c := crowd.cortege_center()
		var lead: Vector3 = crowd.leader.global_position if crowd.leader else c
		_cam(lead + Vector3(-7.5, 0.55, 2.6), lead + Vector3(0, 1.7, 0), 42.0, 8.0)
		_shoot("1_cortege")
	# on met le feu aux poubelles, la tension monte
	if frame == 320:
		for n in main.get_children():
			if n is TrashBin:
				(n as TrashBin).set_lid(true)
				(n as TrashBin).ignite()
		ten.set_value(0.42)
	# 2. portrait : manifestant au fumigène
	if frame == 900:
		var f := _flare_npc()
		if f:
			var fp := f.global_position
			var dir := (crowd.cortege_center() - fp).normalized() if fp.distance_to(crowd.cortege_center()) > 1.0 else Vector3.FORWARD
			_cam(fp + Vector3(dir.x, 0, dir.z) * 2.4 + Vector3(0, 1.55, 0) + Vector3(-dir.z, 0, dir.x) * 0.8, fp + Vector3(0, 1.55, 0), 38.0, 2.6)
		else:
			_cam(crowd.cortege_center() + Vector3(-3, 1.6, 3), crowd.cortege_center() + Vector3(0, 1.5, 0), 38.0, 4.0)
		_shoot("2_fumigene")
	# 3. feu de poubelle
	if frame == 1000:
		var bin: TrashBin = null
		for n in main.get_children():
			if n is TrashBin:
				bin = n
				break
		var b := bin.global_position
		_cam(b + Vector3(-3.2, 0.9, 3.4), b + Vector3(0, 1.1, 0), 46.0, 4.6)
		_shoot("3_feu")
	if frame == 1020:
		ten.set_value(0.7)
	# 4. la ligne de CRS, boucliers, fourgons, vue des manifestants
	if frame == 1500:
		var lc := pol.line_c
		_cam(lc + Vector3(-11.0, 1.3, 2.2), lc + Vector3(0, 1.4, 0), 40.0, 11.0)
		_shoot("4_crs")
	# 5. gaz lacrymogène : la foule recule devant la ligne
	if frame == 2100:
		var clouds := get_root().get_tree().get_nodes_in_group("gas_clouds")
		var g: Vector3 = (clouds[0] as Node3D).global_position if not clouds.is_empty() else pol.line_c + Vector3(-12, 0, 0)
		_cam(g + Vector3(-14.0, 2.2, 4.0), g + Vector3(2.0, 1.4, 0), 44.0)
		_shoot("5_gaz")
	# 6. vue large du boulevard en hauteur
	if frame == 2200:
		var c2 := crowd.cortege_center()
		_cam(c2 + Vector3(-30.0, 14.0, 10.0), c2 + Vector3(18.0, 0.0, -4.0), 55.0)
		_shoot("6_boulevard")
	for pnd in _pending.duplicate():
		if frame == pnd[0]:
			var img := root.get_texture().get_image()
			img.save_png(out_dir.path_join(str(pnd[1]) + ".png"))
			print("PHOTO ", pnd[1])
			_pending.erase(pnd)
			RenderingServer.render_loop_enabled = false
	if frame > 2210 and _pending.is_empty():
		return true
	return false
