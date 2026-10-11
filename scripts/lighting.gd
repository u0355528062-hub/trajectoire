class_name Lighting
extends RefCounted
## Lumière et atmosphère du quartier selon le moment de la journée et la météo : ciel, environnement
## (tonemapping, SSAO/SSIL/SSR, glow, brouillard volumétrique, étalonnage), soleil/lune et lumière de remplissage.
## `build` ajoute WorldEnvironment et lumières comme enfants directs de `parent` (Settings.apply les y retrouve).
## Pour l'instant seul « crepuscule » est réglé : les autres moments retombent dessus (voir docs/CAMPAGNE.md, module Visuels).

const TODS := ["aube", "matin", "midi", "aprem", "crepuscule", "nuit"]
const WEATHERS := ["sec", "bruine", "pluie", "brume"]


## Construit l'éclairage ; renvoie {"world_env", "env", "sun", "fill"}
static func build(parent: Node3D, tod := "crepuscule", weather := "sec") -> Dictionary:
	if not TODS.has(tod):
		push_warning("Lighting : moment inconnu « %s », crépuscule utilisé" % tod)
	if not WEATHERS.has(weather):
		push_warning("Lighting : météo inconnue « %s », temps sec utilisé" % weather)
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
	env.fog_light_color = Color(0.56, 0.52, 0.52)
	env.fog_light_energy = 1.0
	env.fog_density = 0.0007
	env.fog_sun_scatter = 0.1
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0022
	env.volumetric_fog_albedo = Color(0.8, 0.8, 0.82)
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
	parent.add_child(we)

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
	parent.add_child(sun)

	# lumière froide du ciel opposée (remplissage, sans ombre)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35.0, 145.0, 0.0)
	fill.light_color = Color(0.35, 0.5, 1.0)
	fill.light_energy = 0.35
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	parent.add_child(fill)
	return {"world_env": we, "env": env, "sun": sun, "fill": fill}
