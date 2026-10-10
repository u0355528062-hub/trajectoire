extends SceneTree
## Captures de la police aux stades 3-4 (gaz, charge, interpellation, LBD).
## Nécessite un rendu (pas --headless) :
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . --fixed-fps 30 --resolution 1280x720 -s tools/tests/capture_police.gd -- <dossier>
## Le rendu est coupé entre deux captures pour aller vite.
var frame := 0
var main: Node
var crowd: Crowd
var pol: Police
var ten: Tension
var cam: Camera3D
var out_dir := "user://captures"
var shots := {}        # frame -> [nom, mode caméra]
var actions := {}      # frame -> Callable
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

func _focus(kind: String) -> void:
	var lc: Vector3 = pol.line_c
	match kind:
		"side":
			cam.global_position = lc + Vector3(-9.0, 4.5, 13.0)
			cam.look_at(lc + Vector3(-6.0, 1.0, 0.0))
		"front":
			cam.global_position = lc + Vector3(-20.0, 3.2, 3.5)
			cam.look_at(lc + Vector3(-2.0, 1.2, 0.0))
		"high":
			cam.global_position = lc + Vector3(-12.0, 16.0, 16.0)
			cam.look_at(lc + Vector3(-10.0, 0.0, 0.0))
		"cop":
			cam.global_position = lc + Vector3(6.0, 3.0, 4.0)
			cam.look_at(lc + Vector3(-12.0, 1.0, 0.0))

## Un policier dans l'état voulu ; de préférence en escorte (l'interpellé doit le suivre)
func _cop_with_state(st: String) -> Cop:
	var any: Cop = null
	for c in pol.cops:
		if is_instance_valid(c) and c.state == st:
			if c.sub == "escort":
				return c
			if any == null:
				any = c
	return any

func _shoot(name: String, kind: String, at: Node3D = null) -> void:
	if at != null and is_instance_valid(at):
		var p := at.global_position
		cam.global_position = p + Vector3(-5.5, 3.0, 6.5)
		cam.look_at(p + Vector3(0, 1.0, 0))
	else:
		_focus(kind)
	cam.current = true
	RenderingServer.render_loop_enabled = true
	_pending.append([frame + 3, name])

func _process(_d: float) -> bool:
	frame += 1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if frame == 2:
		for c in main.get_children():
			if c is Crowd: crowd = c
			if c is Police: pol = c
			if c is Tension: ten = c
		var p: Player = main.player
		p.global_position = Vector3(20, 0.05, 6)
		p.wanted = 0.0
		cam = Camera3D.new()
		cam.fov = 60.0
		cam.far = 2000.0
		root.add_child(cam)
	if frame == 30:
		ten.set_value(0.7)
	if frame > 30 and ten.value < 0.66 and frame < 1400:
		ten.set_value(0.7)
	match frame:
		600: _shoot("s3_vue_generale", "high")
		630: _shoot("s3_ligne_cote", "side")
		660: pol._do_gas()
		700: _shoot("s3_gaz_tir", "cop")
		760: _shoot("s3_gaz_nuage", "front")
		820: _shoot("s3_gaz_nuage_haut", "high")
		900: pol._do_charge()
		925: _shoot("s3_charge_debut", "front")
		960: _shoot("s3_charge", "side")
		1000: _shoot("s3_charge_haut", "high")
		1050: pol._do_lbd()
		1056: _shoot("s3_lbd", "cop")
		1062: _shoot("s3_lbd_front", "front")
		1100: pol._arrest_cd = 0.0; pol._do_arrest(false)
		1400: ten.set_value(0.9)
		1700: _shoot("s4_vue_generale", "high")
		1730: _shoot("s4_ligne_face", "front")
		1750: pol._do_gas()
		1810: _shoot("s4_gaz", "front")
		1850: pol._do_charge()
		1880: _shoot("s4_charge", "side")
		1900: pol._do_arrest(false)
		2200: quit()
	if frame >= 1130 and frame < 1400 and frame % 90 == 0:
		var a := _cop_with_state("arrest")
		if a != null:
			_shoot("s3_interpellation_%d" % frame, "", a)
	if frame >= 1990 and frame < 2200 and frame % 70 == 0:
		var a2 := _cop_with_state("arrest")
		if a2 != null:
			_shoot("s4_interpellation_%d" % frame, "", a2)
	for pd in _pending.duplicate():
		if frame >= pd[0]:
			var img := root.get_texture().get_image()
			img.save_png(out_dir.path_join(pd[1] + ".png"))
			print("capture ", pd[1], " cops=", pol.cops.size(), " stage=", pol.stage, " states=", _states())
			_pending.erase(pd)
	if _pending.is_empty():
		RenderingServer.render_loop_enabled = false
	return false

func _states() -> String:
	var d := {}
	for c in pol.cops:
		if is_instance_valid(c):
			d[c.state] = d.get(c.state, 0) + 1
	return str(d)
