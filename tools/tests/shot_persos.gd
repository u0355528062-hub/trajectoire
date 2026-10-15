extends SceneTree
## Captures des personnages (rendu) : tools/dev/gd --render --path . --resolution 1280x720 -s tools/tests/shot_persos.gd -- <préfixe>
## Vues : gros plans de visages, plans taille des personnages d'histoire, groupe de manifestants, deux CRS.
## Scène légère (sol, mur, éclairage du jeu, réverbère) : pas besoin de charger le quartier.
var prefix := "/tmp/perso"
var world: Node3D
var cam: Camera3D
var humans: Array[Human] = []
var by_id := {}


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("captures ignorées : pas de rendu (lancer avec --render)")
		quit()
		return
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		prefix = a[0]
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	Settings.load_all()
	Lighting.build(world, "crepuscule")
	_decor()
	cam = Camera3D.new()
	world.add_child(cam)
	cam.current = true
	_run()


func _decor() -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.2, 0.2, 0.21)
	gm.roughness = 0.9
	ground.material_override = gm
	world.add_child(ground)
	for x in [-24.0, 0.0, 24.0]:
		var wall := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(14, 6, 0.4)
		wall.mesh = bm
		var wm := StandardMaterial3D.new()
		wm.albedo_color = Color(0.36, 0.34, 0.31)
		wm.roughness = 0.95
		wall.material_override = wm
		wall.position = Vector3(x, 3, -4.0)
		world.add_child(wall)
		# réverbère au sodium à droite, comme dans la rue
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.78, 0.5)
		lamp.light_energy = 1.0
		lamp.omni_range = 9.0
		lamp.shadow_enabled = true
		lamp.position = Vector3(x + 4.0, 4.5, 4.0)
		world.add_child(lamp)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func spawn(variant: String, outfit: Dictionary, pos: Vector3, yaw := 0.0) -> Human:
	var h := Human.new()
	h.variant = variant
	h.outfit = outfit.duplicate(true)
	h.position = pos
	h.rotation.y = yaw
	world.add_child(h)
	h.sway_seed = pos.x
	humans.append(h)
	return h


func shot(name: String) -> void:
	await frames(4)
	var img := root.get_texture().get_image()
	img.save_png("%s_%s.png" % [prefix, name])
	print("SHOT ", name)


func aim(from: Vector3, at: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.global_position = from
	cam.look_at(at)


func _run() -> void:
	await frames(2)
	Settings.apply(self)
	# personnages d'histoire (rangée en x = 0, regard vers +Z donc vers la caméra)
	var ids := ["sam", "nadia", "karim", "ines", "lou", "jo", "mme_ferreira", "commissaire", "presentatrice"]
	for i in ids.size():
		var lk := CastLooks.look(ids[i])
		var h := spawn(str(lk["variant"]), lk.get("outfit", {}), Vector3(-3.2 + i * 0.8, 0, 0), PI)
		by_id[ids[i]] = h
	# manifestants (x = 24)
	var crowd := Crowd.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 12:
		var vr: String = Crowd.VARIANTS[(i * 4 + 1) % Crowd.VARIANTS.size()]
		var masked := "bloc" if i == 9 else ""
		var o: Dictionary = crowd._outfit(rng, vr.begins_with("female"), masked, i == 4)
		var row := i / 4
		spawn(vr, o, Vector3(24.0 - 2.1 + (i % 4) * 1.4 + row * 0.5, 0, -row * 1.1), PI + rng.randf_range(-0.4, 0.4))
	crowd.free()
	# CRS (x = -24)
	for i in 2:
		var c := spawn(Police.VARIANTS[i * 3], CopGear.outfit(rng), Vector3(-24.6 + i * 1.2, 0, 0), PI + (0.25 if i == 0 else -0.2))
		await frames(1)
		CopGear.equip(c, false)
	for k in 40:
		for h in humans:
			h.animate(1.0 / 30.0, 0.0, 0.0, true, 0.0, 0.0)
		await process_frame
	# gros plans
	for id in ["sam", "nadia", "karim", "mme_ferreira"]:
		var h: Human = by_id[id]
		var hp := h.head_world()
		aim(hp + Vector3(0.18, 0.02, 0.62), hp + Vector3(0, -0.02, 0), 30.0)
		await shot("visage_" + id)
	for id in ["nadia", "presentatrice", "jo"]:
		var h2: Human = by_id[id]
		var hp2 := h2.head_world()
		aim(hp2 + Vector3(-0.55, 0.12, 0.35), hp2 + Vector3(0, -0.03, 0), 34.0)
		await shot("profil_" + id)
	# plans taille
	var mid := ((by_id["sam"] as Human).global_position + (by_id["ines"] as Human).global_position) * 0.5
	aim(mid + Vector3(0, 1.3, 2.9), mid + Vector3(0, 1.2, 0), 42.0)
	await shot("taille_a")
	mid = ((by_id["lou"] as Human).global_position + (by_id["presentatrice"] as Human).global_position) * 0.5
	aim(mid + Vector3(0, 1.3, 3.5), mid + Vector3(0, 1.15, 0), 42.0)
	await shot("taille_b")
	aim(Vector3(24.0, 1.7, 5.5), Vector3(24.0, 1.1, -0.5), 45.0)
	await shot("groupe")
	aim(Vector3(-24.0, 1.55, 2.8), Vector3(-24.0, 1.15, 0), 45.0)
	await shot("crs")
	quit()
