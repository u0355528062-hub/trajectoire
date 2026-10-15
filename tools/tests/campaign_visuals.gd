extends SceneTree
## Module Visuels (sans affichage) : chaque combinaison moment × météo se construit sans erreur, le crépuscule sec
## garde ses réglages d'origine, puis deux vraies scènes : midi sous la pluie (lampadaires éteints, chaussée
## mouillée, pluie autour de la caméra) et crépuscule sec juste après (tout redevient sec, lampadaires allumés).
##   tools/dev/gd --headless --path . --fixed-fps 30 -s tools/tests/campaign_visuals.gd
var errors: Array[String] = []


func _initialize() -> void:
	_run()


func check(ok: bool, what: String) -> void:
	if not ok:
		errors.append(what)
		print("ÉCHEC : ", what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await frames(2)
	for tod in Lighting.TODS:
		for w in Lighting.WEATHERS:
			var host := Node3D.new()
			root.add_child(host)
			var r := Lighting.build(host, tod, w)
			await frames(3)
			var env := r["env"] as Environment
			var sun := r["sun"] as DirectionalLight3D
			var wx := r["weather"] as Weather
			check(env != null and env.sky != null, "%s/%s : environnement" % [tod, w])
			check(sun.light_energy > 0.0 and sun.light_energy < 5.0, "%s/%s : soleil %.2f" % [tod, w, sun.light_energy])
			check(Lighting.tod_now == tod and Lighting.weather_now == w, "%s/%s : moment courant" % [tod, w])
			var rains: bool = w == "bruine" or w == "pluie"
			check((wx.get_node_or_null("Gouttes") != null) == rains, "%s/%s : pluie" % [tod, w])
			check(wx.lamps_on == (tod in ["aube", "crepuscule", "nuit"]), "%s/%s : lampadaires" % [tod, w])
			if tod == "crepuscule" and w == "sec":
				check(is_equal_approx(sun.light_energy, 2.8) and is_equal_approx(env.fog_density, 0.0007)
					and is_equal_approx(env.volumetric_fog_density, 0.0022) and is_equal_approx(env.tonemap_exposure, 1.05)
					and is_equal_approx(env.ambient_light_energy, 0.85), "crépuscule sec inchangé")
			host.queue_free()
			await frames(1)
	await _scene({"tod": "midi", "weather": "pluie"}, true)
	await _scene({"tod": "crepuscule", "weather": "sec"}, false)
	print("RÉSULTAT : ", "OK" if errors.is_empty() else "ÉCHEC (%d)" % errors.size())
	quit()


func _scene(cfg: Dictionary, wet_day: bool) -> void:
	WorldSetup.sandbox = cfg
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await frames(20)
	var lamps := 0
	var lit := 0
	var road: Material = null
	var stack: Array[Node] = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is LampPost:
			lamps += 1
			if (n.get("_light") as Light3D).visible:
				lit += 1
		if n is MeshInstance3D and n.get_parent() is BusStop and (n as MeshInstance3D).mesh is BoxMesh \
				and ((n as MeshInstance3D).mesh as BoxMesh).size.x > 300.0:
			road = (n as MeshInstance3D).material_override
	check(lamps > 0, "lampadaires trouvés")
	check(lit == (0 if wet_day else lamps), "lampadaires allumés : %d / %d" % [lit, lamps])
	check(road is ShaderMaterial if wet_day else road is StandardMaterial3D, "chaussée %s" % ("mouillée" if wet_day else "sèche"))
	var bord: Variant = Streetscape._mats.get("bordure")
	if bord is StandardMaterial3D and (bord as StandardMaterial3D).has_meta("dry_rough"):
		var dry := float((bord as StandardMaterial3D).get_meta("dry_rough"))
		check(is_equal_approx((bord as StandardMaterial3D).roughness, dry) != wet_day, "bordures mouillées/sèches")
	var wx := main.get_node_or_null("Weather") as Weather
	check(wx != null, "nœud Weather")
	if wet_day and wx != null:
		var drops := wx.get_node_or_null("Gouttes") as GPUParticles3D
		check(drops != null and drops.amount > 0, "gouttes")
		Settings.set_quality(0)
		Settings.apply(self)
		var low := drops.amount
		Settings.set_quality(2)
		Settings.apply(self)
		check(low < drops.amount, "pluie allégée en qualité basse (%d < %d)" % [low, drops.amount])
	main.queue_free()
	await frames(3)
	WorldSetup.sandbox = {}
