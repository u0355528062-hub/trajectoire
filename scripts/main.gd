extends Node3D
## Monde : sol du quartier (plat), ciel de crépuscule, lumière & post-traitement.

var player: Player
var cfg: Dictionary                  # réglages du monde de cette partie (WorldSetup.config())
var director: ChapterDirector        # déroulé du chapitre (campagne uniquement)


func _ready() -> void:
	Settings.load_all()
	Settings.ensure_buses()
	cfg = WorldSetup.config()
	Lighting.build(self, str(cfg["tod"]), str(cfg["weather"]))
	add_child(Ambient.new())
	_build_ground()
	var bus := BusStop.new()
	add_child(bus)
	bus.position = Vector3(0, 0, -13)
	player = Player.new()
	add_child(player)
	player.position = Vector3(0, 0.05, 0)
	_build_props_world()
	var tension := Tension.new()
	tension.name = "Tension"
	add_child(tension)
	var crowd := Crowd.new()
	crowd.setup(player, bus)
	add_child(crowd)
	Furniture.populate(self, crowd)
	var street := ParisStreet.new()
	street.name = "ParisStreet"
	street.crowd = crowd
	add_child(street)
	Streetscape.build(self, crowd)
	# reflets du boulevard (vitres, carrosseries, sol mouillé) : une sonde calculée une fois, projection en boîte
	var probe := ReflectionProbe.new()
	probe.size = Vector3(230.0, 36.0, 46.0)
	probe.position = Vector3(0.0, 14.0, -3.5)
	probe.origin_offset = Vector3(0.0, -12.0, 0.0)
	probe.box_projection = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.intensity = 0.8
	probe.max_distance = 260.0
	probe.interior = false
	add_child(probe)
	var parking := Parking.new()          # voitures garées, parking, station de vélos (vandalisables)
	parking.name = "Parking"
	parking.crowd = crowd
	add_child(parking)
	var police := Police.new()
	police.name = "Police"
	police.setup(crowd, player, tension)
	add_child(police)
	# la ville autour : passants sur les trottoirs, habitants aux fenêtres et aux balcons
	var civilians := Civilians.new()
	civilians.name = "Civilians"
	civilians.setup(crowd, police, player)
	add_child(civilians)
	var residents := Residents.new()
	residents.name = "Residents"
	residents.setup(crowd, police, player)
	add_child(residents)
	var hud := preload("res://scripts/hud.gd").new()
	add_child(hud)
	hud.bind(player)
	var hudfx := HudFx.new()
	hudfx.add_to_group("hud")
	add_child(hudfx)
	hudfx.bind(player, tension)
	var pause := PauseMenu.new()
	pause.name = "PauseMenu"
	add_child(pause)
	pause.bind(player, tension, police, crowd)
	Settings.apply(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# campagne : le directeur de chapitre met en scène l'histoire (dialogues, cinématiques, objectifs)
	if Campaign.active:
		director = ChapterDirector.new()
		director.name = "ChapterDirector"
		add_child(director)
		director.bind(self)


## Deux poubelles à roulettes et des déchets (cartons, planches, journaux) éparpillés
func _build_props_world() -> void:
	var a := TrashBin.new()
	a.body_color = Color(0.11, 0.25, 0.16)
	a.lid_color = Color(0.11, 0.25, 0.16)
	add_child(a)
	a.position = Vector3(3.4, 0.0, -2.3)
	a.rotation.y = 0.35
	var b := TrashBin.new()
	b.body_color = Color(0.3, 0.31, 0.33)
	b.lid_color = Color(0.85, 0.68, 0.08)
	add_child(b)
	b.position = Vector3(-7.2, 0.0, -12.5)
	b.rotation.y = -0.4
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var piles := [[Vector3(5.6, 0, -0.6), ["box", "box", "plank", "box", "plank", "paper"]],
		[Vector3(-9.0, 0, -13.4), ["box", "plank", "box", "paper", "plank"]],
		[Vector3(-3.0, 0, 3.5), ["box", "paper"]], [Vector3(10.5, 0, -4.0), ["plank", "box"]]]
	for pile in piles:
		var c: Vector3 = pile[0]
		for k in (pile[1] as Array):
			var it := Burnable.make(k)
			add_child(it)
			it.position = c + Vector3(rng.randf_range(-0.7, 0.7), 0.25 + rng.randf() * 0.3, rng.randf_range(-0.7, 0.7))
			it.rotation = Vector3(0, rng.randf() * TAU, 0)


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Baseplate"
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2400, 2400)
	mi.mesh = plane
	mi.material_override = Streetscape.ground_material()
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2400, 2.0, 2400)
	cs.shape = box
	cs.position.y = -1.0
	body.add_child(cs)
	add_child(body)
