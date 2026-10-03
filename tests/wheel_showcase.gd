extends Node3D
## Captures : roue des outils et instruments en main.

var out_dir := "user://showcase"
var cam: Camera3D
var vm: Viewmodel
var wheel: ToolWheel


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.settings["quality"] = 1
	var clinic := Clinic.new()
	add_child(clinic)
	clinic.build()
	clinic.secretary.visible = false
	cam = Camera3D.new()
	cam.fov = 75
	cam.near = 0.03
	add_child(cam)
	cam.current = true
	vm = Viewmodel.new()
	cam.add_child(vm)

	var lucas := Character.new()
	add_child(lucas)
	lucas.setup("lucas_bernard", "m")
	lucas.place_seated(Clinic.PATIENT_SEAT, Vector3.FORWARD, 0.0)
	lucas.look_target = cam

	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme = UITheme.get_theme()
	layer.add_child(ui)
	wheel = ToolWheel.new()
	ui.add_child(wheel)

	cam.global_position = Vector3(2.45, 1.45, 1.55)
	cam.look_at(Vector3(2.48, 1.25, 2.6))
	await get_tree().create_timer(1.0).timeout

	# 1. Roue ouverte sur le stéthoscope
	wheel.open("mains")
	wheel.feed_motion(Vector2(60, -40))
	await get_tree().create_timer(0.6).timeout
	await _shot("w1_roue_outils")
	wheel.close()
	# 2. Stéthoscope en main, visée du cœur
	vm.equip("stethoscope")
	await get_tree().create_timer(0.8).timeout
	await _shot("w2_stethoscope")
	vm.set_use(1.0)
	await get_tree().create_timer(0.6).timeout
	await _shot("w3_stethoscope_geste")
	vm.set_use(0.0)
	# 3. Otoscope vers l'oreille
	vm.equip("otoscope")
	cam.global_position = Vector3(2.15, 1.45, 2.05)
	cam.look_at(Vector3(2.47, 1.33, 2.55))
	await get_tree().create_timer(0.9).timeout
	await _shot("w4_otoscope")
	# 4. Thermomètre
	vm.equip("thermometre")
	cam.global_position = Vector3(2.45, 1.5, 1.7)
	cam.look_at(Vector3(2.48, 1.4, 2.6))
	await get_tree().create_timer(0.9).timeout
	vm.set_display("37,6")
	await _shot("w5_thermometre")
	# 5. Mains (palpation)
	vm.equip("mains")
	await get_tree().create_timer(0.9).timeout
	await _shot("w6_mains")
	get_tree().quit()


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(n + ".png"))
	print("capture : ", n)
