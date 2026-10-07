extends Node3D
## Monde : baseplate grise plate, ciel de crépuscule, lumière & post-traitement.

var player: Player


func _ready() -> void:
	Settings.load_all()
	Settings.ensure_buses()
	_build_environment()
	add_child(Skyline.new())
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
	var police := Police.new()
	police.name = "Police"
	police.setup(crowd, player, tension)
	add_child(police)
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


func _build_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.50, 0.53, 0.62)
	env.ambient_light_energy = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0

	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssil_enabled = true
	env.ssil_intensity = 0.8
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0

	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_strength = 1.1
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.25
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.8)
	env.set_glow_level(5, 0.6)

	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.50, 0.48)
	env.fog_light_energy = 1.0
	env.fog_density = 0.0007
	env.fog_sun_scatter = 0.1
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0022
	env.volumetric_fog_albedo = Color(0.85, 0.82, 0.82)
	env.volumetric_fog_emission = Color(0.02, 0.025, 0.05)
	env.volumetric_fog_emission_energy = 0.5
	env.volumetric_fog_anisotropy = 0.3
	env.volumetric_fog_length = 80.0
	env.volumetric_fog_gi_inject = 1.0

	env.adjustment_enabled = true
	env.adjustment_contrast = 1.07
	env.adjustment_saturation = 1.04

	var we := WorldEnvironment.new()
	we.environment = env
	we.camera_attributes = CameraAttributesPractical.new()
	add_child(we)

	# soleil bas, chaud, ombres longues et douces
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-13.0, 28.0, 0.0)
	sun.light_color = Color(1.0, 0.6, 0.36)
	sun.light_energy = 2.8
	sun.light_angular_distance = 0.8
	sun.shadow_enabled = true
	sun.shadow_blur = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 120.0
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.2
	sun.directional_shadow_split_3 = 0.5
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.5
	add_child(sun)

	# lumière froide du ciel opposée (remplissage, sans ombre)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35.0, 145.0, 0.0)
	fill.light_color = Color(0.35, 0.5, 1.0)
	fill.light_energy = 0.35
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill)


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
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/baseplate.gdshader")
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2400, 2.0, 2400)
	cs.shape = box
	cs.position.y = -1.0
	body.add_child(cs)
	add_child(body)
