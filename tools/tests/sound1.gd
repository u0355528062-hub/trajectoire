extends SceneTree
## Sons branchés sur les véhicules de police : sirène (deux-tons / rapide), radio de bord,
## grondement d'une voiture en feu jusqu'à l'extinction, « Libérez-le ! » de la foule.
var frame := 0
var main: Node
var pol: Police
var ten: Tension
var car: PoliceVehicle
var played := {}

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	node_added.connect(_on_added)

func _on_added(n: Node) -> void:
	if n is AudioStreamPlayer3D:
		(n as AudioStreamPlayer3D).ready.connect(func():
			var st: AudioStream = (n as AudioStreamPlayer3D).stream
			if st != null and st.resource_path != "":
				var k := st.resource_path.get_file().get_basename()
				played[k] = played.get(k, 0) + 1, CONNECT_ONE_SHOT)

func _sirens() -> String:
	var out := []
	for v in pol.vehicles:
		if is_instance_valid(v) and v._siren.playing:
			out.append("%s:%s" % [v.kind, "rapide" if v._siren.stream == AudioLib.stream("pol_siren_wail", true) else "deux-tons"])
	return str(out)

func _radios() -> int:
	var k := 0
	for v in pol.vehicles:
		if is_instance_valid(v) and v._radio.playing:
			k += 1
	return k

func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		for c in main.get_children():
			if c is Police: pol = c
			if c is Tension: ten = c
		main.player.global_position = Vector3(20, 0.05, 8)
	match frame:
		30: ten.set_value(0.4)
		60, 90, 120: print("[st2] sirènes ", _sirens())
		400: print("[st2 garé] sirènes ", _sirens(), " radios ", _radios())
		420: ten.set_value(0.7)
		450, 480, 510: print("[st3] sirènes ", _sirens())
		900:
			print("[st3 garé] sirènes ", _sirens(), " radios ", _radios())
			for v in pol.vehicles:
				if is_instance_valid(v) and v.kind == "car" and v.is_parked():
					car = v
					break
			ten.set_value(0.3)
			car.damage.ignite()
			print("feu sur ", car.kind)
	if car != null and frame > 900 and frame % 600 == 0:
		var r: AudioStreamPlayer3D = car.damage._roar
		print("[%ds feu] heat %.2f roar %s radio %s burning %s exploded %s" % [(frame - 900) / 30, car.damage.heat, ("%.1f dB" % r.volume_db) if r else "—", car._radio.playing, car.damage.burning, car.damage.exploded])
	if frame == 900 + 30 * 250:
		print("sons joués ", played)
		quit()
	return false
